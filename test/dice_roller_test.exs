defmodule DiceRollerTest do
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
      tokens =
        "((1+4*5)d(9*7+4/3))+(10/1d4-7)"
        |> DiceRoller.tokenize()
        |> elem(1)

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
end
