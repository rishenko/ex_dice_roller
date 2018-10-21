defmodule ExDiceRollerTest do
  @moduledoc """
  Tests around tokenizing, parsing, and rolling.

  Note that test setup seeds the randomizer for each test, which allows for
  predictable test results.
  """

  use ExDiceRoller.Case
  doctest ExDiceRoller

  alias ExDiceRoller.Cache

  describe "rolls" do
    test "basic" do
      1 = ExDiceRoller.roll("1")
      3 = ExDiceRoller.roll("3.14159")
      2 = ExDiceRoller.roll("1+1")
      1 = ExDiceRoller.roll("1d4")
      8 = ExDiceRoller.roll("2d6")
      6 = ExDiceRoller.roll("1d12+2")
      2 = ExDiceRoller.roll("1,2")
      3 = ExDiceRoller.roll("3,3")
      83 = ExDiceRoller.roll("11,5,83,42,36")
      1 = ExDiceRoller.roll("2,1", [], [:lowest])
      2 = ExDiceRoller.roll("5%3")
      8 = ExDiceRoller.roll("2^3")
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

    test "variable with list" do
      [1, 6, 9] = ExDiceRoller.roll("xdy", x: [1, 2, 3], y: 4)
      [19, 20, 19] = ExDiceRoller.roll("xdy", x: 5, y: [6, 7, 8])
      [13, 4, 10, 14, 12, 22, 24, 16, 12] = ExDiceRoller.roll("xdy", x: [3, 4, 5], y: [6, 7, 8])
    end

    test "complex" do
      25 = ExDiceRoller.roll("(1/3*6)d(6d4+3-4) + (4*3d5-18)")
      16_298 = ExDiceRoller.roll("2d5d6d7d8d9d10")
      -24 = ExDiceRoller.roll("1d7d(9/8)+(5-6d8)")
      1 = ExDiceRoller.roll("1d8+(-3/2)")
      3 = ExDiceRoller.roll("-3/2+2d4")
      6 = ExDiceRoller.roll("4d1, 6d1")
      16 = ExDiceRoller.roll("3d6+9.5678,1d4")
      0 = ExDiceRoller.roll("13%(1d4)")
      2 = ExDiceRoller.roll("(5d3)%3")
      2 = ExDiceRoller.roll("(6d4)%(2d3)")
      28_561 = ExDiceRoller.roll("13^(1d4)")
      1331 = ExDiceRoller.roll("(5d3)^3")
      50_625 = ExDiceRoller.roll("(6d4)^(2d3)")
    end

    test "variations of expressions" do
      4 = ExDiceRoller.roll("(1d4)d(2d8)")
      13 = ExDiceRoller.roll("1d4 + 2d8")
      -1 = ExDiceRoller.roll("1d4 - 2d8")
      24 = ExDiceRoller.roll("1d4 * 2d8")
      0 = ExDiceRoller.roll("1d4 / 2d8")
      3 = ExDiceRoller.roll("1d4 + 1.54")
      -3 = ExDiceRoller.roll("1d4 - 4")
      6 = ExDiceRoller.roll("1d4 * 2")
      1 = ExDiceRoller.roll("1d4 / 3")
      4 = ExDiceRoller.roll("4d1, 3.1459")
      3 = ExDiceRoller.roll("3,10d1", [], [:lowest])
      60 = ExDiceRoller.roll("5d1,3d1,60d1,10d1", [], [:highest])
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

    test "list comprehensions" do
      [3, 12] = ExDiceRoller.roll("2d4 + 2d8", [], [:keep])
      [1] = ExDiceRoller.roll("1d4 - 2", [], [:keep])
      [12, 8] = ExDiceRoller.roll("2 * 2d8", [], [:keep])
      [4, 6] = ExDiceRoller.roll("2d6,2d8", [], [:keep])
      [6, 3] = ExDiceRoller.roll("2d6, 3", [], [:keep])
      [6, 3, 3] = ExDiceRoller.roll("3, 3d6", [], [:keep])
    end

    test "errors using separator with lists" do
      assert_raise ArgumentError, fn -> ExDiceRoller.roll("2d4, 1d8", [], [:keep]) end
    end

    test "errors with lists" do
      assert_raise ArgumentError, fn -> ExDiceRoller.roll("2d4 + 1d8", [], [:keep]) end
    end

    test "errors with 0 divisors" do
      assert_raise ArgumentError, fn -> ExDiceRoller.roll("1/0") end
      assert_raise ArgumentError, fn -> ExDiceRoller.roll("2%0") end
    end

    test "keep roll values" do
      values = ExDiceRoller.roll("3d6", [], [:keep])
      require Logger
      assert length(values) == 3
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

    test "exploding dice" do
      {:ok, fun} = ExDiceRoller.compile("1d2")
      assert 1 == ExDiceRoller.execute(fun, [], [:explode])
      assert 7 == ExDiceRoller.execute(fun, [], [:explode])
      assert 9 == ExDiceRoller.execute(fun, [], [:explode])
      assert 9 == ExDiceRoller.execute(fun, [], [:explode])
      assert 1 == ExDiceRoller.execute(fun, [], [:explode])
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

    test "starting cache" do
      {:ok, ExDiceRoller.Cache.Test} = ExDiceRoller.start_cache(ExDiceRoller.Cache.Test)
      assert [] == Cache.all(ExDiceRoller.Cache.Test)
    end
  end

  describe "caching" do
    test "rolls" do
      {:ok, _} = ExDiceRoller.start_cache()
      roll = "1d20"

      assert [] == Cache.all()

      assert 9 == ExDiceRoller.roll(roll, [], [:cache])
      assert length(Cache.all()) == 1
    end

    test "variables" do
      {:ok, _} = ExDiceRoller.start_cache()
      roll = "1d6+x-y"

      assert [] == Cache.all()

      assert 6 == ExDiceRoller.roll(roll, [x: 7, y: 4], [:cache])
      assert length(Cache.all()) == 1
    end
  end
end
