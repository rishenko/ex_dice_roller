defmodule ExDiceRollerTest do
  @moduledoc """
  Tests around tokenizing, parsing, and rolling.

  Note that test setup seeds the randomizer for each test, which allows for
  predictable test results.
  """

  use ExUnit.Case
  doctest ExDiceRoller

  require Logger
  alias ExDiceRoller.Compiler

  setup do
    # This is called to make doctests predictable.
    :rand.seed(:exsplus, {5, 7, 13})
    :ok
  end

  describe "rolls" do
    test "basic" do
      1 = ExDiceRoller.roll("1")
      2 = ExDiceRoller.roll("1+1")
      1 = ExDiceRoller.roll("1d4")
      8 = ExDiceRoller.roll("2d6")
      6 = ExDiceRoller.roll("1d12+2")
    end

    test "unary" do
      -1 = ExDiceRoller.roll("-1")
      3 = ExDiceRoller.roll("-1*-3")
      -3 = ExDiceRoller.roll("-1*+3")
      4 = ExDiceRoller.roll("1--3")
      4 = ExDiceRoller.roll("1-(-3)")
      -2 = ExDiceRoller.roll("-3/2")
    end

    test "variables" do
      4 = ExDiceRoller.roll("1d8+x", x: 3)
      2 = ExDiceRoller.roll("1dy", y: 6)
      8 = ExDiceRoller.roll("1+y", y: 7)
      10 = ExDiceRoller.roll("1+z", z: "1d6+3")
      5 = ExDiceRoller.roll("1+x", x: "1+3")
    end

    test "complex" do
      25 = ExDiceRoller.roll("(1/3*6)d(6d4+3-4) + (4*3d5-18)")
      16_298 = ExDiceRoller.roll("2d5d6d7d8d9d10")
      -24 = ExDiceRoller.roll("1d7d(9/8)+(5-6d8)")
      1 = ExDiceRoller.roll("1d8+(-3/2)")
      3 = ExDiceRoller.roll("-3/2+2d4")
    end

    test "variations of expressions" do
      4 = ExDiceRoller.roll("(1d4)d(2d8)")
      13 = ExDiceRoller.roll("1d4 + 2d8")
      -1 = ExDiceRoller.roll("1d4 - 2d8")
      24 = ExDiceRoller.roll("1d4 * 2d8")
      0 = ExDiceRoller.roll("1d4 / 2d8")
      2 = ExDiceRoller.roll("1d4 + 1")
      -3 = ExDiceRoller.roll("1d4 - 4")
      6 = ExDiceRoller.roll("1d4 * 2")
      1 = ExDiceRoller.roll("1d4 / 3")
    end

    test "basic arithmetic with variables" do
      22 = ExDiceRoller.roll("x+15", x: 7)
      7 = ExDiceRoller.roll("x+y", x: 3, y: 4)
      10 = ExDiceRoller.roll("x+x", x: 5)
      -65 = ExDiceRoller.roll("x+x-y*y", x: 8, y: 9)
      250 = ExDiceRoller.roll("x/y", x: 1000, y: 4)
      3 = ExDiceRoller.roll("x+x/y", x: 2, y: 4)
      4 = ExDiceRoller.roll("x/y", x: 15, y: 4)
    end

    test "with spaces" do
      5 = ExDiceRoller.roll("1 d 4 - 2+ (50+1 ) / 2d5")
    end

    test "with newlines" do
      expr = """
        1 +
        2 *9-
        1d4-1
        *8
      """

      10 = ExDiceRoller.roll(expr)
    end

    test "that error on a negative number of dice" do
      assert_raise(ArgumentError, fn -> ExDiceRoller.roll("-1d4") end)
    end

    test "that error on values" do
      assert_raise(ArgumentError, ~s/no variable 'z' was found in the arguments/, fn ->
        ExDiceRoller.roll("1dz")
      end)

      assert_raise(ArgumentError, ~s/no variable 'z' was found in the arguments/, fn ->
        ExDiceRoller.roll("1dz", z: nil)
      end)
    end

    test "that error during tokenizing" do
      assert {:error, {:tokenizing_failed, _}} = ExDiceRoller.roll("1d6+$")
    end

    test "that error during parsing" do
      assert {:error, {:token_parsing_failed, _}} = ExDiceRoller.roll("1d6++")
    end
  end

  describe "compiling" do
    test "a basic expression" do
      {:ok, compiled} = ExDiceRoller.compile("1d4+1")
      2 = ExDiceRoller.execute(compiled)
    end

    test "error" do
      assert {:error, _} = ExDiceRoller.compile("1d6+$")
    end

    test "function relationships" do
      result =
        "1d4+(1d6)d(5 * x+2)"
        |> ExDiceRoller.compile()
        |> elem(1)
        |> Compiler.fun_info()

      result |> inspect(pretty: true) |> Logger.warn()
    end
  end
end
