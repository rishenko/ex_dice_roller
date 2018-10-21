defmodule ExDiceRoller.RandomizedExpressionTest do
  @moduledoc false

  use ExDiceRoller.Case

  alias ExDiceRoller.ExpressionBuilder

  test "randomized expression testing" do
    acceptable_errors = [
      "neither number of dice nor number of sides can be less than 0",
      "the divisor cannot be 0",
      "the right hand expression in a filter must evaluate to a number",
      "cannot use math operators on lists of differing lengths",
      "cannot use separator on lists of differing lengths",
      "modulo only accepts integer values"
    ]

    errors = random_expression_testing(5_000, 5, acceptable_errors)
    assert errors == []
  end

  defp random_expression_testing(num_expressions, max_depth, acceptable_errors) do
    Enum.reduce(1..num_expressions, [], fn _, acc ->
      expr = ExpressionBuilder.randomize(Enum.random(1..max_depth))

      try do
        ExDiceRoller.roll(expr, [], build_options())
        acc
      rescue
        err ->
          case err.message in acceptable_errors do
            true -> acc
            false -> [create_error_list(err, expr)] ++ acc
          end
      end
    end)
  end

  defp build_options do
    options = [:keep, :explode, :highest, :lowest]
    len = length(options)
    max = Enum.random(1..(len + 2))

    1..max
    |> Enum.map(fn _ -> Enum.random(options) end)
    |> Enum.uniq()
  end

  defp create_error_list(err, expr) do
    [err: err, expr: expr, stacktrace: System.stacktrace()]
  end
end
