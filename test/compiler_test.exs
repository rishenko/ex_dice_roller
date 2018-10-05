defmodule ExDiceRoller.CompilerTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Compiler

  alias ExDiceRoller.Compiler

  setup do
    # This is called to make doctests predictable.
    :rand.seed(:exsplus, {5, 7, 13})
    :ok
  end

  test "basic expression" do
    {:ok, compiled} = ExDiceRoller.compile("1d4+1")
    2 = ExDiceRoller.execute(compiled)
  end

  test "error" do
    assert {:error, _} = ExDiceRoller.compile("1d6+$")
  end

  describe "function info/relationships" do
    test "simple" do
      result =
        "1d4+x"
        |> ExDiceRoller.compile()
        |> elem(1)
        |> Compiler.fun_info()

      assert {_, :"-compile_op/5-fun-0-",
              [
                {_, :"-compile/1-fun-0-", ['x']},
                {_, :"-compile_roll/4-fun-3-", [4, 1]}
              ]} = result
    end

    test "complex" do
      result =
        "1d4+(1dy)d(5 * x+2)"
        |> ExDiceRoller.compile()
        |> elem(1)
        |> Compiler.fun_info()

      assert {_, :"-compile_op/5-fun-0-",
              [
                {_, :"-compile_roll/4-fun-0-",
                 [
                   {_, :"-compile_op/5-fun-4-",
                    [2, {_, :"-compile_op/5-fun-10-", [{_, :"-compile/1-fun-0-", ['x']}, 5]}]},
                   {_, :"-compile_roll/4-fun-2-", [{_, :"-compile/1-fun-0-", ['y']}, 1]}
                 ]},
                {_, :"-compile_roll/4-fun-3-", [4, 1]}
              ]} = result
    end
  end
end
