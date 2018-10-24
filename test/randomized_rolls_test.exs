defmodule ExDiceRoller.RandomizedRollsTest do
  @moduledoc false

  use ExUnit.Case
  require Logger
  alias ExDiceRoller.RandomizedRolls

  test "randomized expression testing" do
    acceptable_errors = [
      "neither number of dice nor number of sides can be less than 0",
      "the divisor cannot be 0",
      "the right hand expression in a filter must evaluate to a number",
      "cannot use math operators on lists of differing lengths",
      "cannot use separator on lists of differing lengths",
      "modulo operator only accepts integer values",
      "roll task timed out"
    ]

    errors = RandomizedRolls.run(10_000, 5, acceptable_errors)

    case length(errors) do
      0 ->
        :ok

      num ->
        Logger.error(
          "randomized rolls test found #{num} errors. Errors: #{inspect(errors, pretty: true)}"
        )

        raise RuntimeError, "errors were found by randomized rolls test"
    end
  end

  test "handle unexpected non-ArgumentError error" do
    RandomizedRolls.handle_error(
      %ArithmeticError{message: "bad argument in arithmetic expression"},
      [],
      "1/0",
      [],
      []
    )
  end

  test "handle unexpected ArgumentError error" do
    acceptable_errors = ["acceptable error"]

    RandomizedRolls.handle_error(
      %ArgumentError{message: "unexpected error"},
      acceptable_errors,
      "1/0",
      [],
      []
    )
  end

  test "intentionally fail a task" do
    {:ok, pid} = Task.Supervisor.start_link()

    RandomizedRolls.execute_roll(
      pid,
      "100d100d100d10000, 100d100d100d100d10000",
      [opts: :keep],
      [],
      []
    )
  end
end
