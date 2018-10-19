defmodule ExDiceRoller.TokenizerTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Tokenizer

  alias ExDiceRoller.Tokenizer

  test "int" do
    assert {:ok, [{:int, 1, '2'}]} == Tokenizer.tokenize("2")
  end

  test "float" do
    assert {:ok, [{:float, 1, '3.1459'}]} == Tokenizer.tokenize("3.1459")
  end

  test "roll" do
    expected = [
      {:int, 1, '1'},
      {:roll, 1, 'd'},
      {:int, 1, '4'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1d4")
  end

  test "operator" do
    expected = [
      {:int, 1, '1'},
      {:basic_operator, 1, '+'},
      {:int, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1+2")

    expected = [
      {:int, 1, '1'},
      {:basic_operator, 1, '-'},
      {:int, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1-2")

    expected = [
      {:int, 1, '1'},
      {:complex_operator, 1, '*'},
      {:int, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1*2")

    expected = [
      {:int, 1, '1'},
      {:complex_operator, 1, '/'},
      {:int, 1, '2'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("1/2")
  end

  test "subexpressions" do
    expected = [
      {:"(", 1, '('},
      {:int, 1, '78'},
      {:complex_operator, 1, '*'},
      {:int, 1, '5'},
      {:")", 1, ')'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("(78*5)")
  end

  test "separator" do
    expected = [
      {:int, 1, '5'},
      {:",", 1, ','},
      {:int, 1, '6'},
      {:",", 1, ','},
      {:int, 1, '7'}
    ]

    assert {:ok, expected} == Tokenizer.tokenize("5,6,7")
  end

  test "variables" do
    assert {:ok, [{:var, 1, 'x'}]} = Tokenizer.tokenize("x")

    assert {:ok,
            [
              {:int, 1, '1'},
              {:roll, 1, 'd'},
              {:int, 1, '4'},
              {:basic_operator, 1, '+'},
              {:var, 1, 'x'}
            ]} = Tokenizer.tokenize("1d4+x")
  end

  test "errors" do
    assert {:error, {:tokenizing_failed, {:illegal, '$'}}} = Tokenizer.tokenize("1-3+$")
  end
end
