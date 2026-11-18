defmodule ExDiceRoller.RollerTest.Defs do
  import ExDiceRoller.Roller
  defroll(damage, "2d6+3")
  defroll(roll, "1d6")
end

defmodule ExDiceRoller.RollerTest do
  use ExUnit.Case

  alias ExDiceRoller.{Error, Golden}
  alias ExDiceRoller.RollerTest.{Corpus, Defs}

  @moduletag timeout: 600_000

  # beyond the golden corpus, which has no modifiers
  @extra [
    "4d6kh3",
    "2d20kl",
    "2d20kh",
    "4d6dl1+2",
    "6d6kh4dl1",
    "1d20r1",
    "3d6r<3",
    "2d6ro1",
    "3d6!",
    "2d6!r1",
    "1d1!",
    "1d6r<7",
    "1d6!r>1",
    "xd6kh2",
    "(1d4)d6kh1",
    "4d6kh3,4d6kl3",
    "0d6kh1",
    "3d0kh1",
    "1D6+1d6",
    "x,y,z",
    "(x,2)*3",
    "10^1000",
    "2.5d3.5",
    "9d6",
    "8d6",
    "1d6+1d6+1d6+1d6",
    "(1d6)d(1d1000)"
  ]

  # every single-letter variable except `d`, as in the golden harness
  @vars for c <- ?a..?z, c != ?d, do: {List.to_atom([c]), rem(c, 5) + 1}

  @arg_sets [
    [],
    [opts: :explode],
    [opts: []],
    @vars,
    @vars ++ [opts: :explode],
    @vars ++ [opts: :keep],
    @vars ++ [opts: [:keep, :lowest]],
    @vars ++ [opts: [:highest]],
    @vars ++ [opts: [:lowest, :explode]],
    @vars ++ [opts: :keep, drop_lowest: true, >=: 2],
    [x: [1, 2, 3], y: 2.5, z: "1d4", opts: [:keep]],
    [x: [1, 2], y: [3, 4], z: 1],
    [x: "2d6", y: :fun, z: [0.5, 1.5]],
    [x: -1, y: 0, z: 3],
    [cache: true, x: 2, y: :args, z: 4],
    [x: 2, y: :args, opts: :keep],
    [x: 3, y: 2, z: 1, drop_lowest: false],
    [y: :args, z: 2, >=: 3],
    [y: :args, z: 2, drop_highest: false],
    [x: 4, y: 3, z: 2, <: 5]
  ]

  # a function variable value, which a module attribute can't hold
  defp arg_sets do
    Enum.map(@arg_sets, fn args ->
      Enum.map(args, fn
        {k, :fun} -> {k, &ExDiceRoller.compile!("1d4+x").(Keyword.put(&1, :x, 1))}
        # depends on the exact arguments a function variable receives
        {k, :args} -> {k, &(:erlang.phash2(&1, 6) + 1)}
        pair -> pair
      end)
    end)
  end

  setup_all do
    exprs = Enum.uniq(Golden.expressions() ++ @extra)

    {valid, invalid} =
      exprs
      |> Enum.with_index()
      |> Enum.split_with(fn {expr, _} -> match?({:ok, _}, ExDiceRoller.compile(expr)) end)

    defs =
      for {expr, i} <- valid do
        quote do: defroll(unquote(:"r#{i}"), unquote(expr))
      end

    Code.compile_quoted(
      quote do
        defmodule ExDiceRoller.RollerTest.Corpus do
          import ExDiceRoller.Roller
          unquote_splicing(defs)
        end
      end
    )

    %{valid: valid, invalid: invalid}
  end

  test "defroll matches compiled functions over the corpus, including the RNG state",
       %{valid: valid} do
    mismatches =
      for {expr, i} <- valid,
          {args, j} <- Enum.with_index(arg_sets()),
          compiled = ExDiceRoller.compile!(expr),
          seed = {i, j, 11},
          expected = outcome(fn -> compiled.(args) end, seed),
          actual =
            outcome(fn -> apply(Corpus, :"r#{i}", [args]) end, seed),
          expected !== actual,
          do: {expr, args, expected, actual}

    assert mismatches == [],
           "#{length(mismatches)} mismatches; first: #{inspect(Enum.take(mismatches, 3))}"

    # most of the corpus parses; the rest is covered by the compile-error test
    assert length(valid) > 1_400
  end

  test "calls without arguments take the same path as an empty list" do
    :rand.seed(:exsss, {1, 2, 3})
    a = Defs.damage()
    :rand.seed(:exsss, {1, 2, 3})
    assert Defs.damage([]) == a
    :rand.seed(:exsss, {1, 2, 3})
    assert ExDiceRoller.compile!("2d6+3").([]) == a
  end

  test "an invalid expression is a compile error with the same reason as compile/1",
       %{invalid: invalid} do
    for {expr, _} <- invalid do
      {:error, %Error{reason: reason}} = ExDiceRoller.compile(expr)

      error =
        assert_raise Error, fn ->
          Code.compile_quoted(
            quote do
              defmodule ExDiceRoller.RollerTest.Invalid do
                import ExDiceRoller.Roller
                defroll(bad, unquote(expr))
              end
            end
          )
        end

      assert error.reason == reason
      assert error.message =~ "invalid dice expression"
    end

    refute Code.ensure_loaded?(ExDiceRoller.RollerTest.Invalid)
    assert invalid != []
  end

  test "defroll rejects a non-literal expression or a bad name" do
    assert_raise ArgumentError, ~r/string literal/, fn ->
      Code.eval_string("""
      defmodule ExDiceRoller.RollerTest.NotLiteral do
        import ExDiceRoller.Roller
        expr = "1d6"
        defroll bad, expr
      end
      """)
    end

    assert_raise ArgumentError, ~r/function name/, fn ->
      Code.eval_string("""
      defmodule ExDiceRoller.RollerTest.BadName do
        import ExDiceRoller.Roller
        defroll "bad", "1d6"
      end
      """)
    end
  end

  test "a non-list argument raises FunctionClauseError, as compiled functions do" do
    assert_raise FunctionClauseError, fn -> Defs.roll(:x) end
    assert_raise FunctionClauseError, fn -> ExDiceRoller.compile!("1d6").(:x) end
  end

  # the result or exception, plus the RNG state afterwards, from a fixed seed
  defp outcome(fun, seed) do
    :rand.seed(:exsss, seed)

    result =
      try do
        {:ok, fun.()}
      rescue
        e in Error -> {:raise, Error, e.reason, e.message}
        e -> {:raise, e.__struct__}
      end

    {result, :rand.export_seed()}
  end
end
