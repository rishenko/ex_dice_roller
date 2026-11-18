defmodule ExDiceRoller.Parser do
  @moduledoc """
  Functionality for parsing `t:ExDiceRoller.Tokenizer.tokens/0`.

      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize("2d3+9-(ydz)d(31+x)/(3d8+2)")
      {:ok,
      [
        {:int, 1, ~c"2"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"3"},
        {:basic_operator, 1, ~c"+"},
        {:int, 1, ~c"9"},
        {:basic_operator, 1, ~c"-"},
        {:"(", 1, ~c"("},
        {:var, 1, ~c"y"},
        {:roll, 1, ~c"d"},
        {:var, 1, ~c"z"},
        {:")", 1, ~c")"},
        {:roll, 1, ~c"d"},
        {:"(", 1, ~c"("},
        {:int, 1, ~c"31"},
        {:basic_operator, 1, ~c"+"},
        {:var, 1, ~c"x"},
        {:")", 1, ~c")"},
        {:complex_operator, 1, ~c"/"},
        {:"(", 1, ~c"("},
        {:int, 1, ~c"3"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"8"},
        {:basic_operator, 1, ~c"+"},
        {:int, 1, ~c"2"},
        {:")", 1, ~c")"}
      ]}
      iex> ExDiceRoller.Parser.parse(tokens)
      {:ok,
      {{:operator, ~c"-"},
        {{:operator, ~c"+"}, {:roll, 2, 3}, 9},
        {{:operator, ~c"/"},
        {:roll, {:roll, {:var, ~c"y"}, {:var, ~c"z"}},
          {{:operator, ~c"+"}, 31, {:var, ~c"x"}}},
        {{:operator, ~c"+"}, {:roll, 3, 8}, 2}}}}

  """

  alias ExDiceRoller.Tokenizer

  @type expression ::
          number
          | {{:operator, charlist}, expression, expression}
          | {:roll, expression, expression}
          | {:roll, expression, expression, [ExDiceRoller.Tokenizer.modifier()]}
          | {:var, charlist}
          | {:sep, expression, expression}

  @doc """
  Converts a series of tokens provided by `tokenize/1` and parses them into
  an expression structure. This expression structure is what's used by the
  dice rolling functions to calculate rolls. The BNF grammar definition
  file is located at `src/dice_parser.yrl`.

      iex> {:ok, tokens} = ExDiceRoller.tokenize("2d8 + (1+2)")
      {:ok,
      [
        {:int, 1, ~c"2"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"8"},
        {:basic_operator, 1, ~c"+"},
        {:"(", 1, ~c"("},
        {:int, 1, ~c"1"},
        {:basic_operator, 1, ~c"+"},
        {:int, 1, ~c"2"},
        {:")", 1, ~c")"}
      ]}
      iex> {:ok, _} = ExDiceRoller.parse(tokens)
      {:ok,
      {{:operator, ~c"+"}, {:roll, 2, 8},
        {{:operator, ~c"+"}, 1, 2}}}

  """
  @spec parse(Tokenizer.tokens()) :: {:ok, expression} | {:error, ExDiceRoller.Error.t()}
  def parse(tokens) do
    case :dice_parser.parse(tokens) do
      {:ok, _} = resp ->
        resp

      {:error, {_, :dice_parser, reason}} ->
        {:error, ExDiceRoller.Error.exception(reason: :token_parsing_failed, details: reason)}
    end
  end
end
