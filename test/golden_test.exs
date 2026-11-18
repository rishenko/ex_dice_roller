defmodule ExDiceRoller.GoldenTest do
  @moduledoc false
  use ExUnit.Case

  alias ExDiceRoller.Golden

  @moduletag timeout: 300_000

  test "roll results match the recorded golden master" do
    expected = Golden.recorded()
    actual = Golden.run()

    assert length(actual) == length(expected),
           "case count changed: #{length(expected)} recorded, #{length(actual)} now"

    mismatches =
      expected
      |> Enum.zip(actual)
      |> Enum.reject(fn {e, a} -> e == a end)

    assert mismatches == [],
           "#{length(mismatches)} of #{length(expected)} cases differ; first ones:\n" <>
             (mismatches
              |> Enum.take(10)
              |> Enum.map_join("\n", fn {e, a} -> "  recorded: #{e}\n  now:      #{a}" end))
  end
end
