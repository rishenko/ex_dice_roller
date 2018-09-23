defmodule DiceRoller do
  @moduledoc """
  Functionality around dice rolling.
  """
  def roll(roll_string) do
    {:ok, tokens, _} = tokenize(roll_string)
    {:ok, parsed_tokens} = parse(tokens)
    do_roll(parsed_tokens)
  end

  defp do_roll({:digit, val}), do: val |> to_string() |> String.to_integer()

  defp do_roll({:roll, left_expr, right_expr}) do
    num_dice = do_roll(left_expr)
    die_type = do_roll(right_expr)

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

  def tokenize(roll_string) do
    roll_string
    |> String.to_charlist()
    |> :dice_lexer.string()
  end

  def parse(tokens) do
    :dice_parser.parse(tokens)
  end
end
