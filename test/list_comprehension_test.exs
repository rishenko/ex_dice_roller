defmodule ExDiceRoller.ListComprehensionTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.ListComprehension

  setup do
    # This is called to make doctests predictable.
    :rand.seed(:exsplus, {5, 7, 13})
    :ok
  end
end
