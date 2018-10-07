defmodule ExDiceRoller.Parser do
  @moduledoc """
  Functionality for parsing `t:ExDiceRoller.Tokenizer.tokens/0`.

      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize("2d3+9-(ydz)d(31+x)/(3d8+2)")
      {:ok,
      [
        {:digit, 1, '2'},
        {:roll, 1, 'd'},
        {:digit, 1, '3'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '9'},
        {:basic_operator, 1, '-'},
        {:"(", 1, '('},
        {:var, 1, 'y'},
        {:roll, 1, 'd'},
        {:var, 1, 'z'},
        {:")", 1, ')'},
        {:roll, 1, 'd'},
        {:"(", 1, '('},
        {:digit, 1, '31'},
        {:basic_operator, 1, '+'},
        {:var, 1, 'x'},
        {:")", 1, ')'},
        {:complex_operator, 1, '/'},
        {:"(", 1, '('},
        {:digit, 1, '3'},
        {:roll, 1, 'd'},
        {:digit, 1, '8'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '2'},
        {:")", 1, ')'}
      ]}
      iex> ExDiceRoller.Parser.parse(tokens)
      {:ok,
      {{:operator, '-'},
        {{:operator, '+'}, {:roll, {:digit, '2'}, {:digit, '3'}}, {:digit, '9'}},
        {{:operator, '/'},
        {:roll, {:roll, {:var, 'y'}, {:var, 'z'}},
          {{:operator, '+'}, {:digit, '31'}, {:var, 'x'}}},
        {{:operator, '+'}, {:roll, {:digit, '3'}, {:digit, '8'}}, {:digit, '2'}}}}}

  """

  alias ExDiceRoller.Tokenizer

  @type expression ::
          {:digit, list}
          | {{:operator, list}, expression, expression}
          | {:roll, expression, expression}
          | {:var, String.t()}

  @doc """
  Converts a series of tokens provided by `tokenize/1` and parses them into
  an expression structure. This expression structure is what's used by the
  dice rolling functions to calculate rolls. The BNF grammar definition
  file is located at `src/dice_parser.yrl`.

      iex> {:ok, tokens} = ExDiceRoller.tokenize("2d8 + (1+2)")
      {:ok,
      [
        {:digit, 1, '2'},
        {:roll, 1, 'd'},
        {:digit, 1, '8'},
        {:basic_operator, 1, '+'},
        {:"(", 1, '('},
        {:digit, 1, '1'},
        {:basic_operator, 1, '+'},
        {:digit, 1, '2'},
        {:")", 1, ')'}
      ]}
      iex> {:ok, _} = ExDiceRoller.parse(tokens)
      {:ok,
      {{:operator, '+'}, {:roll, {:digit, '2'}, {:digit, '8'}},
        {{:operator, '+'}, {:digit, '1'}, {:digit, '2'}}}}

  """
  @spec parse(Tokenizer.tokens()) :: {:ok, expression}
  def parse(tokens) do
    case :dice_parser.parse(tokens) do
      {:ok, _} = resp -> resp
      {:error, {_, :dice_parser, reason}} -> {:error, {:token_parsing_failed, reason}}
    end
  end
end
