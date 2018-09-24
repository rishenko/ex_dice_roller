defmodule DiceRollerTest do
  @moduledoc """
  Tests around tokenizing, parsing, and rolling.

  Note that test setup seeds the randomizer for each test, which allows for
  predictable test results.
  """

  use ExUnit.Case
  doctest DiceRoller

  setup do
    # This is called to make doctests predictable.
    :rand.seed(:exsplus, {5, 7, 13})
    :ok
  end

  describe "tokenizing" do
    test "digit" do
      assert {:ok, [{:digit, 1, '2'}]} == DiceRoller.tokenize("2")
    end

    test "roll" do
      expected = [
        {:digit, 1, '1'},
        {:roll, 1, 'd'},
        {:digit, 1, '4'}
      ]

      assert {:ok, expected} == DiceRoller.tokenize("1d4")
    end

    test "operator" do
      expected = [
        {:digit, 1, '1'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '2'}
      ]

      assert {:ok, expected} == DiceRoller.tokenize("1+2")

      expected = [
        {:digit, 1, '1'},
        {:basic_operator, 1, '-'},
        {:digit, 1, '2'}
      ]

      assert {:ok, expected} == DiceRoller.tokenize("1-2")

      expected = [
        {:digit, 1, '1'},
        {:complex_operator, 1, '*'},
        {:digit, 1, '2'}
      ]

      assert {:ok, expected} == DiceRoller.tokenize("1*2")

      expected = [
        {:digit, 1, '1'},
        {:complex_operator, 1, '/'},
        {:digit, 1, '2'}
      ]

      assert {:ok, expected} == DiceRoller.tokenize("1/2")
    end

    test "subexpressions" do
      expected = [
        {:"(", 1, '('},
        {:digit, 1, '78'},
        {:complex_operator, 1, '*'},
        {:digit, 1, '5'},
        {:")", 1, ')'}
      ]

      assert {:ok, expected} == DiceRoller.tokenize("(78*5)")
    end

    test "errors" do
      assert {:error, {:tokenizing_failed, {:illegal, 'g'}}} = DiceRoller.tokenize("g")
      assert {:error, {:tokenizing_failed, {:illegal, 'x'}}} = DiceRoller.tokenize("1d4+x")
      assert {:error, {:tokenizing_failed, {:illegal, '$'}}} = DiceRoller.tokenize("1-3+$")
    end
  end

  describe "parsing" do
    test "digit" do
      assert {:ok, {:digit, '1'}} == DiceRoller.parse([{:digit, 1, '1'}])
    end

    test "roll" do
      tokens = [
        {:digit, 1, '1'},
        {:roll, 1, 'd'},
        {:digit, 1, '4'}
      ]

      expected = {:roll, {:digit, '1'}, {:digit, '4'}}
      assert {:ok, expected} == DiceRoller.parse(tokens)
    end

    test "operator" do
      tokens = [
        {:digit, 1, '1'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '2'}
      ]

      expected = {{:operator, '+'}, {:digit, '1'}, {:digit, '2'}}
      assert {:ok, expected} == DiceRoller.parse(tokens)
    end

    test "subexpressions" do
      tokens = [
        {:"(", 1, '('},
        {:digit, 1, '78'},
        {:complex_operator, 1, '*'},
        {:digit, 1, '5'},
        {:")", 1, ')'}
      ]

      expected = {
        {:operator, '*'},
        {:digit, '78'},
        {:digit, '5'}
      }

      assert {:ok, expected} == DiceRoller.parse(tokens)
    end

    test "parses token with bad value" do
      assert {:ok, {:digit, 'a'}} = DiceRoller.parse([{:digit, 1, 'a'}])
    end

    test "parsing error" do
      assert {:error, {:token_parsing_failed, _}} =
               DiceRoller.parse([{{:basic_operator, 1, '%'}, {:digit, 1, '1'}, {:digit, 1, '3'}}])
    end

    test "raised errors" do
      assert_raise(ArgumentError, fn -> DiceRoller.parse('x') end)
      assert_raise(FunctionClauseError, fn -> DiceRoller.parse({:basic_operator, 1, '&'}) end)
    end
  end

  describe "complex parsing" do
    test "subexpr roll subexpr" do
      tokens = [
        {:"(", 1, '('},
        {:digit, 1, '78'},
        {:complex_operator, 1, '*'},
        {:digit, 1, '5'},
        {:")", 1, ')'},
        {:roll, 1, 'd'},
        {:"(", 1, '('},
        {:digit, 1, '4'},
        {:complex_operator, 1, '/'},
        {:digit, 1, '6'},
        {:")", 1, ')'}
      ]

      expected = {
        :roll,
        {{:operator, '*'}, {:digit, '78'}, {:digit, '5'}},
        {{:operator, '/'}, {:digit, '4'}, {:digit, '6'}}
      }

      assert {:ok, expected} == DiceRoller.parse(tokens)
    end

    test "kitchen sink" do
      {:ok, tokens} = DiceRoller.tokenize("((1+4*5)d(9*7+4/3))+(10/1d4-7)")

      expected =
        {{:operator, '+'},
         {:roll,
          {{:operator, '+'}, {:digit, '1'}, {{:operator, '*'}, {:digit, '4'}, {:digit, '5'}}},
          {{:operator, '+'}, {{:operator, '*'}, {:digit, '9'}, {:digit, '7'}},
           {{:operator, '/'}, {:digit, '4'}, {:digit, '3'}}}},
         {{:operator, '-'},
          {{:operator, '/'}, {:digit, '10'}, {:roll, {:digit, '1'}, {:digit, '4'}}},
          {:digit, '7'}}}

      assert {:ok, expected} == DiceRoller.parse(tokens)
    end
  end

  describe "rolls" do
    test "basic" do
      1 = DiceRoller.roll("1")
      2 = DiceRoller.roll("1+1")
      1 = DiceRoller.roll("1d4")
      8 = DiceRoller.roll("2d6")
      6 = DiceRoller.roll("1d12+2")
    end

    test "unary" do
      -1 = DiceRoller.roll("-1")
      3 = DiceRoller.roll("-1*-3")
      -3 = DiceRoller.roll("-1*+3")
      4 = DiceRoller.roll("1--3")
      4 = DiceRoller.roll("1-(-3)")
      -2 = DiceRoller.roll("-3/2")
    end

    test "complex" do
      25 = DiceRoller.roll("(1/3*6)d(6d4+3-4) + (4*3d5-18)")
      16_298 = DiceRoller.roll("2d5d6d7d8d9d10")
      -24 = DiceRoller.roll("1d7d(9/8)+(5-6d8)")
      1 = DiceRoller.roll("1d8+(-3/2)")
      3 = DiceRoller.roll("-3/2+2d4")
    end

    test "variations of expressions" do
      4 = DiceRoller.roll("(1d4)d(2d8)")
      13 = DiceRoller.roll("1d4 + 2d8")
      9 = DiceRoller.roll("1d4 - 2d8")
      14 = DiceRoller.roll("1d4 * 2d8")
      14 = DiceRoller.roll("1d4 / 2d8")
      2 = DiceRoller.roll("1d4 + 1")
      -3 = DiceRoller.roll("1d4 - 4")
      6 = DiceRoller.roll("1d4 * 2")
      1 = DiceRoller.roll("1d4 / 3")
    end

    test "with spaces" do
      5 = DiceRoller.roll("1 d 4 - 2+ (50+1 ) / 2d5")
    end

    test "with newlines" do
      expr = """
        1 +
        2 *9-
        1d4-1
        *8
      """

      10 = DiceRoller.roll(expr)
    end

    test "that error on a negative number of dice" do
      assert_raise(ArgumentError, fn -> DiceRoller.roll("-1d4") end)
    end

    test "returns tokenizing error" do
      assert {:error, _} = DiceRoller.roll("1dx")
    end
  end

  describe "compiling" do
    test "a basic expression" do
      {:ok, compiled} = DiceRoller.compile("1d4+1")
      2 = DiceRoller.execute(compiled)
    end

    test "error" do
      assert {:error, _} = DiceRoller.compile("1d6+x")
    end
  end
end
