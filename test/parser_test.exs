defmodule ExDiceRoller.ParserTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Parser

  alias ExDiceRoller.Parser

  describe "basic parsing" do
    test "digit" do
      assert {:ok, {:digit, '1'}} == Parser.parse([{:digit, 1, '1'}])
    end

    test "roll" do
      tokens = [
        {:digit, 1, '1'},
        {:roll, 1, 'd'},
        {:digit, 1, '4'}
      ]

      expected = {:roll, {:digit, '1'}, {:digit, '4'}}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "operator" do
      tokens = [
        {:digit, 1, '1'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '2'}
      ]

      expected = {{:operator, '+'}, {:digit, '1'}, {:digit, '2'}}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "variable" do
      tokens = [
        {:digit, 1, '1'},
        {:roll, 1, 'd'},
        {:digit, 1, '4'},
        {:basic_operator, 1, '+'},
        {:var, 1, 'x'}
      ]

      expected = {{:operator, '+'}, {:roll, {:digit, '1'}, {:digit, '4'}}, {:var, 'x'}}
      assert {:ok, expected} == Parser.parse(tokens)
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

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "parses token with bad value" do
      assert {:ok, {:digit, 'a'}} = Parser.parse([{:digit, 1, 'a'}])
    end

    test "parsing error" do
      assert {:error, {:token_parsing_failed, _}} =
               Parser.parse([
                 {{:basic_operator, 1, '%'}, {:digit, 1, '1'}, {:digit, 1, '3'}}
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

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "kitchen sink" do
      {:ok, tokens} = ExDiceRoller.tokenize("((1+4*5)d(9*7+4/3))+(10/1d4-7)")

      expected =
        {{:operator, '+'},
         {:roll,
          {{:operator, '+'}, {:digit, '1'}, {{:operator, '*'}, {:digit, '4'}, {:digit, '5'}}},
          {{:operator, '+'}, {{:operator, '*'}, {:digit, '9'}, {:digit, '7'}},
           {{:operator, '/'}, {:digit, '4'}, {:digit, '3'}}}},
         {{:operator, '-'},
          {{:operator, '/'}, {:digit, '10'}, {:roll, {:digit, '1'}, {:digit, '4'}}},
          {:digit, '7'}}}

      assert {:ok, expected} == Parser.parse(tokens)
    end
  end
end
