defmodule ExDiceRoller.TokenizerTest do
  @moduledoc false

  use ExDiceRoller.Case
  doctest ExDiceRoller.Tokenizer

  alias ExDiceRoller.Tokenizer

  test "int" do
    assert {:ok, [{:int, 1, ~c"2"}]} == Tokenizer.tokenize("2")
  end

  test "float" do
    assert {:ok, [{:float, 1, ~c"3.1459"}]} == Tokenizer.tokenize("3.1459")
  end

  test "roll" do
    expected = [
      {:int, 1, ~c"1"},
      {:roll, 1, ~c"d"},
      {:int, 1, ~c"4"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1d4")
  end

  test "operator" do
    expected = [
      {:int, 1, ~c"1"},
      {:basic_operator, 1, ~c"+"},
      {:int, 1, ~c"2"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1+2")

    expected = [
      {:int, 1, ~c"1"},
      {:basic_operator, 1, ~c"-"},
      {:int, 1, ~c"2"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1-2")

    expected = [
      {:int, 1, ~c"1"},
      {:complex_operator, 1, ~c"*"},
      {:int, 1, ~c"2"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1*2")

    expected = [
      {:int, 1, ~c"1"},
      {:complex_operator, 1, ~c"/"},
      {:int, 1, ~c"2"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1/2")
  end

  test "subexpressions" do
    expected = [
      {:"(", 1, ~c"("},
      {:int, 1, ~c"78"},
      {:complex_operator, 1, ~c"*"},
      {:int, 1, ~c"5"},
      {:")", 1, ~c")"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("(78*5)")
  end

  test "separator" do
    expected = [
      {:int, 1, ~c"5"},
      {:",", 1, ~c","},
      {:int, 1, ~c"6"},
      {:",", 1, ~c","},
      {:int, 1, ~c"7"}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("5,6,7")
  end

  test "variables" do
    assert {:ok, [{:var, 1, ~c"x"}]} = Tokenizer.tokenize("x")

    assert {:ok,
            [
              {:int, 1, ~c"1"},
              {:roll, 1, ~c"d"},
              {:int, 1, ~c"4"},
              {:basic_operator, 1, ~c"+"},
              {:var, 1, ~c"x"}
            ]} = Tokenizer.tokenize("1d4+x")
  end

  test "errors" do
    assert {:error, %ExDiceRoller.Error{reason: :tokenizing_failed, details: {:illegal, ~c"$"}}} =
             Tokenizer.tokenize("1-3+$")
  end
end
