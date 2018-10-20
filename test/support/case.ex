defmodule ExDiceRoller.Case do
  @moduledoc "Helper functions and more for ExDiceRoller unit test cases."

  use ExUnit.CaseTemplate

  setup do
    :rand.seed(:exsplus, {5, 7, 13})
    :ok
  end
end
