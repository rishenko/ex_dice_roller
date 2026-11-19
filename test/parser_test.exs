defmodule ExDiceRoller.ParserTest do
  @moduledoc false

  use ExDiceRoller.Case
  doctest ExDiceRoller.Parser

  alias ExDiceRoller.Parser

  describe "basic parsing" do
    test "int" do
      assert {:ok, 1} == Parser.parse([{:int, 1, ~c"1"}])
    end

    test "float" do
      assert {:ok, 2.56987} == Parser.parse([{:float, 1, ~c"2.56987"}])
    end

    test "roll" do
      tokens = [
        {:int, 1, ~c"1"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"4"}
      ]

      expected = {:roll, 1, 4}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "operator" do
      tokens = [
        {:int, 1, ~c"1"},
        {:basic_operator, 1, ~c"+"},
        {:int, 1, ~c"2"}
      ]

      expected = {{:operator, ~c"+"}, 1, 2}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "separator" do
      tokens = [
        {:int, 1, ~c"2"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"4"},
        {:",", 1, ~c","},
        {:int, 1, ~c"1"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"6"}
      ]

      expected = {:sep, {:roll, 2, 4}, {:roll, 1, 6}}

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "variable" do
      tokens = [
        {:int, 1, ~c"1"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"4"},
        {:basic_operator, 1, ~c"+"},
        {:var, 1, ~c"x"}
      ]

      expected = {{:operator, ~c"+"}, {:roll, 1, 4}, {:var, ~c"x"}}
      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "subexpressions" do
      tokens = [
        {:"(", 1, ~c"("},
        {:int, 1, ~c"78"},
        {:complex_operator, 1, ~c"*"},
        {:int, 1, ~c"5"},
        {:")", 1, ~c")"}
      ]

      expected = {
        {:operator, ~c"*"},
        78,
        5
      }

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "parses token with bad value" do
      assert {:ok, :error} = Parser.parse([{:int, 1, ~c"a"}])
    end

    test "parsing error" do
      assert {:error, %ExDiceRoller.Error{reason: :token_parsing_failed, details: _}} =
               Parser.parse([
                 {{:basic_operator, 1, ~c"%"}, {:int, 1, ~c"1"}, {:int, 1, ~c"3"}}
               ])
    end

    test "raised errors" do
      assert_raise(ArgumentError, fn -> Parser.parse(~c"x") end)
      assert_raise(FunctionClauseError, fn -> Parser.parse({:basic_operator, 1, ~c"&"}) end)
    end
  end

  describe "complex parsing" do
    test "subexpr roll subexpr" do
      tokens = [
        {:"(", 1, ~c"("},
        {:int, 1, ~c"78"},
        {:complex_operator, 1, ~c"*"},
        {:int, 1, ~c"5"},
        {:")", 1, ~c")"},
        {:roll, 1, ~c"d"},
        {:"(", 1, ~c"("},
        {:int, 1, ~c"4"},
        {:complex_operator, 1, ~c"/"},
        {:int, 1, ~c"6"},
        {:")", 1, ~c")"}
      ]

      expected = {
        :roll,
        {{:operator, ~c"*"}, 78, 5},
        {{:operator, ~c"/"}, 4, 6}
      }

      assert {:ok, expected} == Parser.parse(tokens)
    end

    test "kitchen sink" do
      {:ok, tokens} = ExDiceRoller.tokenize("((1+4*5)d(9*7+4/3))+(10/1d4-7)")

      expected =
        {{:operator, ~c"+"},
         {:roll, {{:operator, ~c"+"}, 1, {{:operator, ~c"*"}, 4, 5}},
          {{:operator, ~c"+"}, {{:operator, ~c"*"}, 9, 7}, {{:operator, ~c"/"}, 4, 3}}},
         {{:operator, ~c"-"}, {{:operator, ~c"/"}, 10, {:roll, 1, 4}}, 7}}

      assert {:ok, expected} == Parser.parse(tokens)
    end
  end
end
