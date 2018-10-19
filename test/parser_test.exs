defmodule ExDiceRoller.ParserTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Parser

  alias ExDiceRoller.Parser

  describe "basic parsing" do
    test "int" do
      assert {:ok, 1} == Parser.parse([{:int, 1, '1'}])
    end

    test "float" do
      assert {:ok, 2.56987} == Parser.parse([{:float, 1, '2.56987'}])
    end

    test "roll" do
      tokens = [
        {:int, 1, '1'},
        {:roll, 1, 'd'},
        {:int, 1, '4'}
      ]

      expected = {:roll, 1, 4}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "operator" do
      tokens = [
        {:int, 1, '1'},
        {:basic_operator, 1, '+'},
        {:int, 1, '2'}
      ]

      expected = {{:operator, '+'}, 1, 2}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "separator" do
      tokens = [
        {:int, 1, '2'},
        {:roll, 1, 'd'},
        {:int, 1, '4'},
        {:",", 1, ','},
        {:int, 1, '1'},
        {:roll, 1, 'd'},
        {:int, 1, '6'}
      ]

      expected = {:sep, {:roll, 2, 4}, {:roll, 1, 6}}

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "variable" do
      tokens = [
        {:int, 1, '1'},
        {:roll, 1, 'd'},
        {:int, 1, '4'},
        {:basic_operator, 1, '+'},
        {:var, 1, 'x'}
      ]

      expected = {{:operator, '+'}, {:roll, 1, 4}, {:var, 'x'}}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "subexpressions" do
      tokens = [
        {:"(", 1, '('},
        {:int, 1, '78'},
        {:complex_operator, 1, '*'},
        {:int, 1, '5'},
        {:")", 1, ')'}
      ]

      expected = {
        {:operator, '*'},
        78,
        5
      }

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "parses token with bad value" do
      assert {:ok, :error} = Parser.parse([{:int, 1, 'a'}])
    end

    test "parsing error" do
      assert {:error, {:token_parsing_failed, _}} =
               Parser.parse([
                 {{:basic_operator, 1, '%'}, {:int, 1, '1'}, {:int, 1, '3'}}
               ])
    end

    test "raised errors" do
      assert_raise(ArgumentError, fn -> Parser.parse('x') end)
      assert_raise(FunctionClauseError, fn -> Parser.parse({:basic_operator, 1, '&'}) end)
    end
  end

  describe "complex parsing" do
    test "subexpr roll subexpr" do
      tokens = [
        {:"(", 1, '('},
        {:int, 1, '78'},
        {:complex_operator, 1, '*'},
        {:int, 1, '5'},
        {:")", 1, ')'},
        {:roll, 1, 'd'},
        {:"(", 1, '('},
        {:int, 1, '4'},
        {:complex_operator, 1, '/'},
        {:int, 1, '6'},
        {:")", 1, ')'}
      ]

      expected = {
        :roll,
        {{:operator, '*'}, 78, 5},
        {{:operator, '/'}, 4, 6}
      }

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "kitchen sink" do
      {:ok, tokens} = ExDiceRoller.tokenize("((1+4*5)d(9*7+4/3))+(10/1d4-7)")

      expected =
        {{:operator, '+'},
         {:roll, {{:operator, '+'}, 1, {{:operator, '*'}, 4, 5}},
          {{:operator, '+'}, {{:operator, '*'}, 9, 7}, {{:operator, '/'}, 4, 3}}},
         {{:operator, '-'}, {{:operator, '/'}, 10, {:roll, 1, 4}}, 7}}

      assert {:ok, expected} == Parser.parse(tokens)
    end
  end
end
