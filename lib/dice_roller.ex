defmodule DiceRoller do
  @moduledoc """
  Functionality around dice rolling.
  """

  @type tokens :: [token, ...]
  @type token :: {token_type, integer, list}
  @type token_type :: :digit | :basic_operator | :complex_operator | :roll | :"(" | :")"

  @type expression ::
          {:digit, list}
          | {{:operator, list}, expression, expression}
          | {:roll, expression, expression}

  @spec roll(String.t()) :: integer | float
  def roll(roll_string) do
    {:ok, tokens} = tokenize(roll_string)
    {:ok, parsed_tokens} = parse(tokens)
    do_roll(parsed_tokens)
  end

  @spec tokenize(String.t()) :: {:ok, tokens}
  def tokenize(roll_string) do
    {:ok, tokens, _} =
      roll_string
      |> String.to_charlist()
      |> :dice_lexer.string()

    {:ok, tokens}
  end

  @spec parse(tokens) :: {:ok, expression}
  def parse(tokens) do
    :dice_parser.parse(tokens)
  end

  @spec do_roll(expression) :: integer

  defp do_roll({:digit, val}), do: val |> to_string() |> String.to_integer()

  defp do_roll({:roll, left_expr, right_expr}) do
    num_dice = left_expr |> do_roll() |> round()
    die_type = right_expr |> do_roll() |> round()

    Enum.reduce(1..num_dice, 0, fn _, total ->
      Enum.random(1..die_type) + total
    end)
  end

  defp do_roll({{:operator, op}, left_expr, right_expr}) do
    case op do
      '+' -> do_roll(left_expr) + do_roll(right_expr)
      '-' -> do_roll(left_expr) - do_roll(right_expr)
      '*' -> do_roll(left_expr) * do_roll(right_expr)
      '/' -> do_roll(left_expr) / do_roll(right_expr)
    end
  end
end
