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
    # fun_info/1 reports names and captured values straight from the BEAM. The
    # numeric suffix in names ("-fun-1-") and the order of captured values both
    # vary between OTP releases, so compare a normalized shape: numbers stripped
    # from names and children sorted.
    defp shape({_fun, name, children}) do
      name = String.replace(Atom.to_string(name), ~r/-fun-\d+-$/, "-fun-")
      {name, children |> Enum.map(&shape/1) |> Enum.sort()}
    end

    defp shape(other), do: other

    test "simple" do
      result =
        "1d4+x"
        |> ExDiceRoller.compile()
        |> elem(1)
        |> Compiler.fun_info()

      assert {"-compile_add/2-fun-",
              [
                {"-compile_roll/2-fun-", [1, 4]},
                {"-compile_var/1-fun-", [~c"x"]}
              ]} == shape(result)
    end

    test "complex" do
      result =
        "1d4 + (1dy)d(5*x + 2)"
        |> ExDiceRoller.compile()
        |> elem(1)
        |> Compiler.fun_info()

      assert {"-compile_add/2-fun-",
              [
                {"-compile_roll/2-fun-", [1, 4]},
                {"-compile_roll/2-fun-",
                 [
                   {"-compile_add/2-fun-",
                    [2, {"-compile_mul/2-fun-", [5, {"-compile_var/1-fun-", [~c"x"]}]}]},
                   {"-compile_roll/2-fun-", [1, {"-compile_var/1-fun-", [~c"y"]}]}
                 ]}
              ]} == shape(result)
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
