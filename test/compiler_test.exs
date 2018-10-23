defmodule ExDiceRoller.CompilerTest do
  @moduledoc false

  use ExDiceRoller.Case
  doctest ExDiceRoller.Compiler

  alias ExDiceRoller.Compiler

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

    test "filters" do
      assert [4] == ExDiceRoller.roll("6d6", =: 4, opts: :keep)
      assert [4, 4, 2] == ExDiceRoller.roll("3d8", <: 5, opts: :keep)
      assert [6, 8, 8] == ExDiceRoller.roll("5d8", >: 4, opts: :keep)
      assert [7, 5] == ExDiceRoller.roll("5d8", >=: 4, opts: :keep)
      assert [4, 4, 1] == ExDiceRoller.roll("5d8", <=: 4, opts: :keep)
    end
  end
end
