defmodule DiceRollerTest do
  use ExUnit.Case
  doctest DiceRoller

  test "greets the world" do
    assert DiceRoller.hello() == :world
  end
end
