defmodule ExDiceRoller.Tokenizer do
  @moduledoc """
  Provides functionality around tokenizing dice roll strings.

      iex> ExDiceRoller.Tokenizer.tokenize("1d4+6-(2dy)d(5*2d7-x)/3d8")
      {:ok,
      [
        {:int, 1, '1'},
        {:roll, 1, 'd'},
        {:int, 1, '4'},
        {:basic_operator, 1, '+'},
        {:int, 1, '6'},
        {:basic_operator, 1, '-'},
        {:"(", 1, '('},
        {:int, 1, '2'},
        {:roll, 1, 'd'},
        {:var, 1, 'y'},
        {:")", 1, ')'},
        {:roll, 1, 'd'},
        {:"(", 1, '('},
        {:int, 1, '5'},
        {:complex_operator, 1, '*'},
        {:int, 1, '2'},
        {:roll, 1, 'd'},
        {:int, 1, '7'},
        {:basic_operator, 1, '-'},
        {:var, 1, 'x'},
        {:")", 1, ')'},
        {:complex_operator, 1, '/'},
        {:int, 1, '3'},
        {:roll, 1, 'd'},
        {:int, 1, '8'}
      ]}
  """

  @type tokens :: [token, ...]
  @type token :: {token_type, integer, list}
  @type token_type :: :int | :basic_operator | :complex_operator | :roll | :"(" | :")"

  @doc """
  Converts a roll-based string into tokens using leex. The input definition
  file is located at `src/dice_lexer.xrl`. See `t:token_type/0`, `t:token/0`,
  and `t:tokens/0` for the possible return values.

      iex> ExDiceRoller.Tokenizer.tokenize("2d8+3")
      {:ok,
      [
        {:int, 1, '2'},
        {:roll, 1, 'd'},
        {:int, 1, '8'},
        {:basic_operator, 1, '+'},
        {:int, 1, '3'}
      ]}
  """
  @spec tokenize(String.t()) :: {:ok, tokens}
  def tokenize(roll_string) do
    with charlist <- String.to_charlist(roll_string),
         {:ok, tokens, _} <- :dice_lexer.string(charlist) do
      {:ok, tokens}
    else
      {:error, {1, :dice_lexer, reason}, 1} ->
        {:error, {:tokenizing_failed, reason}}
    end
  end
end
