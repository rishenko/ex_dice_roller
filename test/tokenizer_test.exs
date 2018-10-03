defmodule ExDiceRoller.TokenizerTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Tokenizer

  alias ExDiceRoller.Tokenizer

  test "digit" do
    assert {:ok, [{:digit, 1, '2'}]} == Tokenizer.tokenize("2")
  end

  test "roll" do
    expected = [
      {:digit, 1, '1'},
      {:roll, 1, 'd'},
      {:digit, 1, '4'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1d4")
  end

  test "operator" do
    expected = [
      {:digit, 1, '1'},
      {:basic_operator, 1, '+'},
      {:digit, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1+2")

    expected = [
      {:digit, 1, '1'},
      {:basic_operator, 1, '-'},
      {:digit, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1-2")

    expected = [
      {:digit, 1, '1'},
      {:complex_operator, 1, '*'},
      {:digit, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1*2")

    expected = [
      {:digit, 1, '1'},
      {:complex_operator, 1, '/'},
      {:digit, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1/2")
  end

  test "subexpressions" do
    expected = [
      {:"(", 1, '('},
      {:digit, 1, '78'},
      {:complex_operator, 1, '*'},
      {:digit, 1, '5'},
      {:")", 1, ')'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("(78*5)")
  end

  test "variables" do
    assert {:ok, [{:var, 1, 'x'}]} = Tokenizer.tokenize("x")

    assert {:ok,
            [
              {:digit, 1, '1'},
              {:roll, 1, 'd'},
              {:digit, 1, '4'},
              {:basic_operator, 1, '+'},
              {:var, 1, 'x'}
            ]} = Tokenizer.tokenize("1d4+x")
  end

  test "errors" do
    assert {:error, {:tokenizing_failed, {:illegal, '$'}}} = Tokenizer.tokenize("1-3+$")
  end
end
