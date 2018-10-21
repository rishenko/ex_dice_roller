defmodule ExDiceRoller.ExpressionBuilder do
  @moduledoc """
  Builds randomized ExDiceRoller dice roll expressions. Does not include
  exponentiation.
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

  @lowercase for n <- ?a..?z, do: <<n::utf8>>
  @uppercase for n <- ?A..?Z, do: <<n::utf8>>
  @possible_vars @lowercase -- (["d"] ++ @uppercase)

  @doc """
  Generates a random ExDiceRoller roll expression, including nesting expressions
  up to a maximum depth of `max_depth`. `vars?` determines whether or not the
  expression can potentially include variables.
  """
  @spec randomize(integer, boolean) :: String.t()
  def randomize(max_depth, vars?) do
    do_randomize(max_depth, fg(vars?), vars?)
  end

  def add(l, r), do: l <> " + " <> r
  def sub(l, r), do: l <> " - " <> r
  def mul(l, r), do: l <> " * " <> r
  def div(l, r), do: l <> " / " <> r
  def mod(l, r), do: l <> " % " <> r
  def sep(l, r), do: l <> "," <> r
  def roll(l, r), do: l <> "d" <> r
  def group(expr), do: "(" <> expr <> ")"

  def var do
    Enum.random(@possible_vars)
  end

  def int, do: to_string(Enum.random(1..20))

  def float do
    float = Enum.random(1..20) + 1 / Enum.random(5..103)

    float
    |> Float.round(3)
    |> to_string()
  end

  defp fg(false) do
    Enum.random([:fun, :group, :fun, :fun])
  end

  defp fg(true) do
    Enum.random([:fun, :group, :var, :fun, :fun])
  end

  defp do_randomize(0, _, false), do: Enum.random(@numbers).()
  defp do_randomize(0, _, true), do: Enum.random([&__MODULE__.var/0] ++ @numbers).()
  defp do_randomize(_, :var, _), do: var()

  defp do_randomize(max_depth, :group, vars?) do
    group(do_randomize(max_depth - 1, fg(vars?), vars?))
  end

  defp do_randomize(max_depth, :fun, vars?) do
    Enum.random(@funcs).(
      do_randomize(max_depth - 1, fg(vars?), vars?),
      do_randomize(max_depth - 1, fg(vars?), vars?)
    )
  end
end
