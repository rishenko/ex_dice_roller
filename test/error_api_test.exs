defmodule ExDiceRoller.ErrorApiTest do
  @moduledoc """
  The 2.0 error API: `{:ok, _} | {:error, %ExDiceRoller.Error{}}` from the
  non-bang functions, and bare values or a raised `ExDiceRoller.Error` from
  the bang functions, the sigil, and compiled functions.
  """
  use ExUnit.Case
  import ExDiceRoller.Sigil

  alias ExDiceRoller.{Cache, Error}

  # expression => expected reason; each fails at roll time, after compiling
  @runtime_errors [
    {"-1d4", :negative_dice},
    {"1d(0-4)", :negative_dice},
    {"1/0", :divide_by_zero},
    {"1%0.0", :divide_by_zero},
    {"2.5%2", :non_integer_modulo},
    {"10.0^400", :arithmetic_error},
    {"1+z", :missing_variable}
  ]

  @syntax_errors [
    {"1d6+$", :tokenizing_failed},
    {"1d6++", :token_parsing_failed},
    {"1d6\n+$", :tokenizing_failed}
  ]

  describe "roll/2" do
    test "returns {:ok, result} for strings and compiled functions" do
      assert {:ok, 7} = ExDiceRoller.roll("3+4")
      assert {:ok, 7} = ExDiceRoller.roll("3+x", x: 4)
      assert {:ok, [2, 2]} = ExDiceRoller.roll("2d1+1", opts: :keep)
      assert {:ok, 7} = ExDiceRoller.roll(~a/3+4/)
    end

    test "returns {:error, %Error{}} for each runtime failure" do
      for {expr, reason} <- @runtime_errors do
        assert {:error, %Error{reason: ^reason}} = ExDiceRoller.roll(expr), expr
      end
    end

    test "returns {:error, %Error{}} for each syntax error" do
      for {expr, reason} <- @syntax_errors do
        assert {:error, %Error{reason: ^reason, details: details}} = ExDiceRoller.roll(expr)
        assert details != nil
      end
    end

    test "returns list-length and variable errors" do
      assert {:error, %Error{reason: :list_length_mismatch}} =
               ExDiceRoller.roll("2d4+1d8", opts: :keep)

      assert {:error, %Error{reason: :list_length_mismatch}} =
               ExDiceRoller.roll("2d4,1d8", opts: :keep)

      assert {:error, %Error{reason: :missing_variable, details: :z}} =
               ExDiceRoller.roll("1+z")

      assert {:error, %Error{reason: :invalid_variable, details: {:x, inner}}} =
               ExDiceRoller.roll("1+x", x: "1d6$")

      assert %Error{reason: :tokenizing_failed} = inner
    end

    test "cached rolls return the same shapes" do
      {:ok, _} = ExDiceRoller.start_cache()
      :ok = Cache.clear()
      assert {:ok, 5} = ExDiceRoller.roll("2+3", cache: true)
      assert {:error, %Error{reason: :divide_by_zero}} = ExDiceRoller.roll("1/0", cache: true)

      assert {:error, %Error{reason: :token_parsing_failed}} =
               ExDiceRoller.roll("1+", cache: true)

      assert ["1/0", "2+3"] == Cache.all() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    end

    test "does not swallow exceptions that are not ExDiceRoller errors" do
      assert_raise RuntimeError, fn ->
        ExDiceRoller.roll(fn _ -> raise "boom" end)
      end
    end
  end

  describe "roll!/2" do
    test "returns bare results" do
      assert 7 == ExDiceRoller.roll!("3+4")
      assert 7 == ExDiceRoller.roll!(~a/3+x/, x: 4)
    end

    test "raises ExDiceRoller.Error with the same reason roll/2 returns" do
      for {expr, reason} <- @runtime_errors ++ @syntax_errors do
        error = assert_raise Error, fn -> ExDiceRoller.roll!(expr) end
        assert error.reason == reason
      end
    end

    test "keeps the messages from 1.x" do
      assert_raise Error, "the divisor cannot be 0", fn -> ExDiceRoller.roll!("1/0") end

      assert_raise Error, "no variable 'z' was found in the arguments", fn ->
        ExDiceRoller.roll!("1+z")
      end
    end
  end

  describe "compile, execute and calculate" do
    test "compile/1 and compile!/1" do
      assert {:ok, fun} = ExDiceRoller.compile("1+2")
      assert 3 == fun.([])
      assert is_function(ExDiceRoller.compile!("1+2"))

      assert {:error, %Error{reason: :cannot_compile_roll, details: :foo}} =
               ExDiceRoller.compile(:foo)

      assert_raise Error, ~r/could not parse/, fn -> ExDiceRoller.compile!("1+") end
    end

    test "execute/2 and execute!/2" do
      fun = ExDiceRoller.compile!("6/x")
      assert {:ok, 3} = ExDiceRoller.execute(fun, x: 2)
      assert {:error, %Error{reason: :divide_by_zero}} = ExDiceRoller.execute(fun, x: 0)
      assert 3 == ExDiceRoller.execute!(fun, x: 2)
      assert_raise Error, fn -> ExDiceRoller.execute!(fun, x: 0) end
    end

    test "a compiled function called directly raises" do
      fun = ExDiceRoller.compile!("1/x")
      assert_raise Error, "the divisor cannot be 0", fn -> fun.(x: 0) end
    end

    test "calculate/2" do
      {:ok, tokens} = ExDiceRoller.tokenize("1+x")
      {:ok, expr} = ExDiceRoller.parse(tokens)
      assert {:ok, 3} = ExDiceRoller.calculate(expr, x: 2)
      assert {:error, %Error{reason: :missing_variable}} = ExDiceRoller.calculate(expr, [])
    end
  end

  describe "sigil" do
    test "raises for an invalid option instead of returning a tuple" do
      error = assert_raise Error, fn -> sigil_a("1d6", ~c"rz") end
      assert error.reason == :invalid_option
      assert error.details == "z"
    end

    test "raises for a failed roll" do
      assert_raise Error, "the divisor cannot be 0", fn -> sigil_a("1/0", ~c"r") end
    end

    test "names the expression when it does not parse" do
      error =
        assert_raise Error, ~r/invalid dice expression "1d6\+"/, fn -> sigil_a("1d6+", []) end

      assert error.reason == :token_parsing_failed
    end
  end

  describe "Cache" do
    test "obtain/2 returns tuples" do
      {:ok, _} = ExDiceRoller.start_cache()
      :ok = Cache.clear()
      assert {:ok, fun} = Cache.obtain("1d6")
      assert {:ok, ^fun} = Cache.obtain("1d6")
      assert {:error, %Error{reason: :tokenizing_failed}} = Cache.obtain("1$")
    end

    test "delete/2 with a non-string key" do
      assert {:error, %Error{reason: :invalid_roll_key, details: :x}} = Cache.delete(:x)
    end
  end

  test "parse error messages are readable" do
    {:error, error} = ExDiceRoller.roll("1d6++")
    assert Exception.message(error) =~ "could not parse the expression: syntax error before"
  end
end
