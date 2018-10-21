defmodule ExDiceRoller.ExpressionBuilder do
  @moduledoc """
  Builds randomized ExDiceRoller dice roll expressions. Does not include
  variables nor exponentiation.
  """

  @numbers [&__MODULE__.int/0, &__MODULE__.float/0, &__MODULE__.int/0, &__MODULE__.int/0]

  @funcs [
    &__MODULE__.add/2,
    &__MODULE__.sub/2,
    &__MODULE__.mul/2,
    &__MODULE__.div/2,
    &__MODULE__.mod/2,
    &__MODULE__.sep/2,
    &__MODULE__.roll/2
  ]

  def fg, do: Enum.random([:fun, :group, :fun, :fun])

  def randomize(max_depth) do
    randomize(max_depth, fg())
  end

  def randomize(0, _), do: Enum.random(@numbers).()

  def randomize(max_depth, :group) do
    group(randomize(max_depth - 1, fg()))
  end

  def randomize(max_depth, :fun) do
    Enum.random(@funcs).(randomize(max_depth - 1, fg()), randomize(max_depth - 1, fg()))
  end

  def add(l, r), do: l <> " + " <> r
  def sub(l, r), do: l <> " - " <> r
  def mul(l, r), do: l <> " * " <> r
  def div(l, r), do: l <> " / " <> r
  def mod(l, r), do: l <> " % " <> r
  def sep(l, r), do: l <> "," <> r
  def roll(l, r), do: l <> "d" <> r
  def group(expr), do: "(" <> expr <> ")"

  def int, do: to_string(Enum.random(1..20))

  def float do
    float = Enum.random(1..20) + 1 / Enum.random(5..103)

    float
    |> Float.round(3)
    |> to_string()
  end
end
