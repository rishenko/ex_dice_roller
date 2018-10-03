defmodule ExDiceRoller.Tokenizer do
  @moduledoc "Provides functionality around tokenizing dice roll strings."

  @type tokens :: [token, ...]
  @type token :: {token_type, integer, list}
  @type token_type :: :digit | :basic_operator | :complex_operator | :roll | :"(" | :")"

  @doc """
  Converts a roll-based string into tokens using leex. The input definition
  file is located at `src/dice_lexer.xrl`. See `t:token_type/0`, `t:token/0`,
  and `t:tokens/0` for the possible return values.

      iex> ExDiceRoller.tokenize("2d8+3")
      {:ok,
      [
        {:digit, 1, '2'},
        {:roll, 1, 'd'},
        {:digit, 1, '8'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '3'}
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
