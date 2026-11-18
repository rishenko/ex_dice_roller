defmodule ExDiceRoller.Roller do
  @moduledoc """
  Defines roll functions from dice expressions at compile time.

  `defroll/2` turns an expression into an ordinary named function in your
  module. It gives the same results as `ExDiceRoller.compile!/1` with the same
  arguments, including the same rolls from the same random seed, but runs
  faster, because the expression becomes plain Elixir code instead of a chain
  of closures.

      defmodule MyGame.Dice do
        import ExDiceRoller.Roller

        defroll attack, "1d20+x"
        defroll damage, "2d6+3"
      end

      MyGame.Dice.damage()
      #=> 9
      MyGame.Dice.attack(x: 5)
      #=> 17
      MyGame.Dice.damage(opts: [:keep])
      #=> [4, 8]

  The generated function takes the same keyword list as a compiled function:
  variable values, `opts`, and filters. It returns a bare value and raises
  `ExDiceRoller.Error` when a roll fails, as a compiled function called
  directly does. A malformed expression is a compile error.

  Calls without arguments, such as `damage()`, take a faster path: with no
  options or variables, every value is a number, so the generated code is
  plain arithmetic and small rolls such as `2d6` become direct calls to
  `:rand.uniform/1`. See the performance guide for measurements.

  Use `defroll` for expressions fixed in your code. For expressions that
  arrive as strings at run time, use `ExDiceRoller.compile/1` or the cache.
  """

  alias ExDiceRoller.{Args, Compiler, Filters, Parser, Sigil}
  alias ExDiceRoller.Compilers.{Math, Roll, Separator, Variable}

  # rolls of at most this many literal dice are unrolled into
  # `:rand.uniform/1` calls
  @unroll_limit 8

  @doc """
  Defines `name(args \\\\ [])`, which rolls `expression`.

  `expression` must be a string literal. It is parsed when the module
  compiles, and a malformed expression raises `ExDiceRoller.Error` then.
  """
  defmacro defroll(name, expression) do
    name = fun_name!(name)
    tree = Sigil.__parse__!(literal!(expression))

    args = Macro.var(:args, __MODULE__)
    filters = Macro.var(:filters, __MODULE__)

    general_ctx = %{
      fast: false,
      args: args,
      keep: Macro.var(:keep?, __MODULE__),
      explode: Macro.var(:explode?, __MODULE__),
      mode: Macro.var(:mode, __MODULE__)
    }

    fast_ctx = %{fast: true, args: [], keep: false, explode: false, mode: :highest}

    # variables only, no options or filters: the arguments as the general
    # clause would see them are `[opts: [] | args]`
    plain_ctx = %{general_ctx | keep: false, explode: false, mode: :highest}
    has_vars? = :var in features(tree, MapSet.new())

    quote do
      def unquote(name)(args \\ [])

      def unquote(name)([]) do
        value = unquote(gen(tree, fast_ctx))
        Kernel.round(value)
      end

      def unquote(name)(unquote(args)) when is_list(unquote(args)) do
        if Args.plain?(unquote(args)) do
          unquote(
            if has_vars?,
              do: quote(do: unquote(args) = [{:opts, []} | unquote(args)]),
              else: quote(do: _ = unquote(args))
          )

          value = unquote(gen(tree, plain_ctx))
          Compiler.round_val(value)
        else
          unquote(general_body(tree, general_ctx, filters))
        end
      end
    end
  end

  defp general_body(tree, ctx, filters) do
    args = ctx.args

    quote do
      unquote(args) = Args.sanitize(unquote(args))
      {unquote(filters), unquote(args)} = Args.get_filters(unquote(args))
      unquote_splicing(option_bindings(tree, ctx))
      value = unquote(gen(tree, ctx))

      value
      |> Compiler.round_val()
      |> Filters.filter(unquote(filters))
    end
  end

  defp fun_name!({name, _, ctx}) when is_atom(name) and is_atom(ctx), do: name
  defp fun_name!(name) when is_atom(name), do: name

  defp fun_name!(other),
    do: raise(ArgumentError, "defroll expects a function name, got: #{Macro.to_string(other)}")

  defp literal!(expr) when is_binary(expr), do: expr

  defp literal!(other) do
    raise ArgumentError,
          "defroll expects a string literal expression, got: #{Macro.to_string(other)}"
  end

  # Reads only the options the expression uses. Each is read once per call;
  # the closures read them at every roll or separator, which gives the same
  # values because the arguments don't change during a call.
  defp option_bindings(tree, ctx) do
    features = features(tree, MapSet.new())

    rolls =
      if :roll in features do
        [
          quote(do: unquote(ctx.keep) = Args.has_option?(unquote(ctx.args), :keep)),
          quote(do: unquote(ctx.explode) = Args.has_option?(unquote(ctx.args), :explode))
        ]
      else
        []
      end

    seps =
      if :sep in features,
        do: [quote(do: unquote(ctx.mode) = Separator.mode(unquote(ctx.args)))],
        else: []

    vars = if :var in features, do: [], else: [quote(do: _ = unquote(ctx.args))]
    rolls ++ seps ++ vars
  end

  defp features({:roll, n, s}, acc), do: features(s, features(n, MapSet.put(acc, :roll)))
  defp features({:roll, n, s, _}, acc), do: features({:roll, n, s}, acc)
  defp features({{:operator, _}, l, r}, acc), do: features(r, features(l, acc))
  defp features({:sep, l, r}, acc), do: features(r, features(l, MapSet.put(acc, :sep)))
  defp features({:var, _}, acc), do: MapSet.put(acc, :var)
  defp features(n, acc) when is_number(n), do: acc

  @spec gen(Parser.expression(), map) :: Macro.t()
  defp gen(n, _ctx) when is_number(n), do: n

  defp gen({:var, var}, ctx) do
    key = List.to_atom(var)
    quote do: Variable.__value__(unquote(key), unquote(ctx.args))
  end

  # The left side is evaluated before the right, the order the compiled
  # closures use, so both draw random numbers in the same sequence.
  defp gen({{:operator, op}, l, r}, ctx), do: bind(l, r, ctx, &math(op, &1, &2, ctx.fast))

  defp gen({:sep, l, r}, %{fast: true} = ctx) do
    bind(l, r, ctx, fn a, b ->
      quote do: if(unquote(a) > unquote(b), do: unquote(a), else: unquote(b))
    end)
  end

  defp gen({:sep, l, r}, ctx) do
    bind(l, r, ctx, fn a, b ->
      quote do: Separator.__high_low__(unquote(a), unquote(b), unquote(ctx.mode))
    end)
  end

  defp gen({:roll, n, s}, ctx), do: gen({:roll, n, s, []}, ctx)

  defp gen({:roll, n, s, mods}, ctx),
    do: bind(n, s, ctx, &roll(&1, &2, unrolled(n, s, mods), mods, ctx))

  # with no options every value is a number; otherwise check, and fall back to
  # the list-aware path
  defp math(op, a, b, true), do: op |> operator(a, b) |> elem(0)

  defp math(op, a, b, false) do
    {fast, fun} = operator(op, a, b)
    numbers_or(a, b, fast, quote(do: Math.__apply__(unquote(a), unquote(b), unquote(fun))))
  end

  defp roll(_a, _b, plain, _mods, %{fast: true}) when plain != nil, do: plain
  defp roll(a, b, nil, mods, %{fast: true} = ctx), do: roll_call(:__roll_dice__, a, b, mods, ctx)

  defp roll(a, b, plain, mods, ctx) do
    checked =
      numbers_or(
        a,
        b,
        roll_call(:__roll_dice__, a, b, mods, ctx),
        roll_call(:__roll__, a, b, mods, ctx)
      )

    unrolled_unless_options(plain, checked, ctx)
  end

  defp unrolled_unless_options(nil, checked, _ctx), do: checked

  defp unrolled_unless_options(plain, checked, ctx) do
    quote do
      if unquote(ctx.keep) or unquote(ctx.explode), do: unquote(checked), else: unquote(plain)
    end
  end

  defp roll_call(fun, a, b, mods, ctx) do
    quote do
      Roll.unquote(fun)(
        unquote(a),
        unquote(b),
        unquote(ctx.explode),
        unquote(ctx.keep),
        unquote(Macro.escape(mods))
      )
    end
  end

  defp numbers_or(a, b, numbers, otherwise) do
    quote do
      if is_number(unquote(a)) and is_number(unquote(b)),
        do: unquote(numbers),
        else: unquote(otherwise)
    end
  end

  # `n` plain dice with `s` sides, summed, as `:rand.uniform/1` calls; `nil`
  # unless both are small positive integer literals and there are no modifiers
  defp unrolled(n, s, [])
       when is_integer(n) and is_integer(s) and n > 0 and n <= @unroll_limit and s > 0 do
    1..n
    |> Enum.map(fn _ -> quote(do: :rand.uniform(unquote(s))) end)
    |> Enum.reduce(fn die, acc -> quote(do: unquote(acc) + unquote(die)) end)
  end

  defp unrolled(_, _, _), do: nil

  # Evaluates two subexpressions, left first, then builds the node from them.
  # Number literals are used directly.
  defp bind(l, r, ctx, build) do
    {a, a_code} = operand(l, ctx, :l)
    {b, b_code} = operand(r, ctx, :r)
    {:__block__, [], a_code ++ b_code ++ [build.(a, b)]}
  end

  defp operand(n, _ctx, _) when is_number(n), do: {n, []}

  defp operand(expr, ctx, name) do
    var = Macro.unique_var(name, __MODULE__)
    {var, [quote(do: unquote(var) = unquote(gen(expr, ctx)))]}
  end

  # {code for two numbers, function for `Math.__apply__/3`}
  defp operator(~c"+", a, b), do: {quote(do: unquote(a) + unquote(b)), quote(do: &Kernel.+/2)}
  defp operator(~c"-", a, b), do: {quote(do: unquote(a) - unquote(b)), quote(do: &Kernel.-/2)}
  defp operator(~c"*", a, b), do: {quote(do: unquote(a) * unquote(b)), quote(do: &Kernel.*/2)}

  defp operator(~c"/", a, b),
    do: {quote(do: Math.divide(unquote(a), unquote(b))), quote(do: &Math.divide/2)}

  defp operator(~c"%", a, b),
    do: {quote(do: Math.modulo(unquote(a), unquote(b))), quote(do: &Math.modulo/2)}

  defp operator(~c"^", a, b),
    do: {quote(do: :math.pow(unquote(a), unquote(b))), quote(do: &:math.pow/2)}
end
