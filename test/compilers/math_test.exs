defmodule ExDiceRoller.Compilers.MathTest do
  @moduledoc false

  use ExDiceRoller.Case
  doctest ExDiceRoller.Compilers.Math

  test "divide by 0" do
    assert_raise ArgumentError, "the divisor cannot be 0", fn -> ExDiceRoller.roll("1/0") end
    assert_raise ArgumentError, "the divisor cannot be 0", fn -> ExDiceRoller.roll("1/0.0") end
    assert_raise ArgumentError, "the divisor cannot be 0", fn -> ExDiceRoller.roll("1%0") end
    assert_raise ArgumentError, "the divisor cannot be 0", fn -> ExDiceRoller.roll("1%0.0") end
  end
end
