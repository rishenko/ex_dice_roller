defmodule DiceRoller do
  @moduledoc """
  Converts strings into dice rolls and returns expected results.

  ## Examples

      iex> DiceRoller.roll("1")
      1

      iex> DiceRoller.roll("1d8")
      1

      iex> DiceRoller.roll("2d20+5")
      34

      iex> DiceRoller.roll("(1d4)d(6*5)-(2/3+1)")
      18
  """

  @type tokens :: [token, ...]
  @type token :: {token_type, integer, list}
  @type token_type :: :digit | :basic_operator | :complex_operator | :roll | :"(" | :")"

  @type expression ::
          {:digit, list}
          | {{:operator, list}, expression, expression}
          | {:roll, expression, expression}

  @doc """
  Processes a given string as a dice roll and returns the final result. Note
  that the final result is a rounded integer.
  """
  @spec roll(String.t()) :: integer
  def roll(roll_string) do
    {:ok, tokens} = tokenize(roll_string)
    {:ok, parsed_tokens} = parse(tokens)

    parsed_tokens
    |> calculate()
    |> round()
  end

  @doc """
  Converts a roll-based string into tokens using leex. The input definition
  file is located at `src/dice_lexer.xrl`. See `t:token_type/0`, `t:token/0`,
  and `t:tokens/0` for the possible return values.

      iex> DiceRoller.tokenize("2d8+3")
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
    {:ok, tokens, _} =
      roll_string
      |> String.to_charlist()
      |> :dice_lexer.string()

    {:ok, tokens}
  end

  @doc """
  Converts a series of tokens provided by `tokenize/1` and parses them into
  an expression structure. This expression structure is what's used by the
  dice rolling functions to calculate rolls. The BNF grammar definition
  file is located at `src/dice_parser.yrl`.

      iex> {:ok, tokens} = DiceRoller.tokenize("2d8+(1+2)")
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
      iex> {:ok, _} = DiceRoller.parse(tokens)
      {:ok,
      {{:operator, '+'}, {:roll, {:digit, '2'}, {:digit, '8'}},
        {{:operator, '+'}, {:digit, '1'}, {:digit, '2'}}}}

  """
  @spec parse(tokens) :: {:ok, expression}
  def parse(tokens) do
    :dice_parser.parse(tokens)
  end

  @doc """
  Takes a given AST expression from `parse/1`, calculates the values, and
  returns an integer or float.
  """
  @spec calculate(expression) :: integer | float
  def calculate(expression) do
    do_roll(expression)
  end

  @spec do_roll(expression) :: integer

  defp do_roll({:digit, val}), do: val |> to_string() |> String.to_integer()

  defp do_roll({:roll, left_expr, right_expr}) do
    num_dice = left_expr |> do_roll() |> round()
    die_type = right_expr |> do_roll() |> round()

    1..num_dice
    |> Enum.reduce(0, fn _, total -> Enum.random(1..die_type) + total end)
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
