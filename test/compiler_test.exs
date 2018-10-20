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

      assert {_, :"-compile_add/2-fun-1-",
              [
                {_, :"-compile_roll/2-fun-3-", [1, 4]},
                {_, :"-compile_var/1-fun-0-", ['x']}
              ]} = result
    end

    test "complex" do
      result =
        "1d4 + (1dy)d(5*x + 2)"
        |> ExDiceRoller.compile()
        |> elem(1)
        |> Compiler.fun_info()

      assert {_, :"-compile_add/2-fun-1-",
              [
                {_, :"-compile_roll/2-fun-3-", [1, 4]},
                {_, :"-compile_roll/2-fun-0-",
                 [
                   {_, :"-compile_roll/2-fun-2-", [1, {_, :"-compile_var/1-fun-0-", ['y']}]},
                   {_, :"-compile_add/2-fun-3-",
                    [{_, :"-compile_mul/2-fun-5-", [5, {_, :"-compile_var/1-fun-0-", ['x']}]}, 2]}
                 ]}
              ]} = result
    end
  end
end
