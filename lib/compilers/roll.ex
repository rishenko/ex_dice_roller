defmodule ExDiceRoller.Compilers.Roll do
  @moduledoc "Handles compiling dice roll expressions. "

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @impl true
  def compile({:roll, left_expr, right_expr}) do
    num = Compiler.delegate(left_expr)
    sides = Compiler.delegate(right_expr)
    compile_roll(num, is_function(num), sides, is_function(sides))
  end

  @spec compile_roll(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_fun()

  defp compile_roll(num, true, sides, true) do
    fn args, opts -> roll_prep(num.(args, opts), sides.(args, opts), opts) end
  end

  defp compile_roll(num, true, sides, false),
    do: fn args, opts -> roll_prep(num.(args, opts), sides, opts) end

  defp compile_roll(num, false, sides, true),
    do: fn args, opts -> roll_prep(num, sides.(args, opts), opts) end

  defp compile_roll(num, false, sides, false),
    do: fn _args, opts -> roll_prep(num, sides, opts) end

  @spec roll_prep(number, number, list(atom | tuple)) :: integer
  defp roll_prep(0, _, _), do: 0
  defp roll_prep(_, 0, _), do: 0

  defp roll_prep(num, sides, opts) when num >= 0 and sides >= 0 do
    num = Compiler.round_val(num)
    sides = Compiler.round_val(sides)
    explode? = :explode in opts

    case :keep in opts do
      true ->
        keep_roll(num, sides, explode?)

      false ->
        Enum.reduce(1..num, 0, fn _, total ->
          total + roll(sides, explode?)
        end)
    end
  end

  defp roll_prep(_, _, _),
    do: raise(ArgumentError, "neither number of dice nor number of sides cannot be less than 0")

  defp keep_roll(num, sides, explode?) when is_number(num) do
    keep_roll([num], sides, explode?)
  end

  defp keep_roll(num, sides, explode?) when is_number(sides) do
    keep_roll(num, [sides], explode?)
  end

  defp keep_roll(num, sides, explode?) do
    Enum.flat_map(num, fn n ->
      Enum.flat_map(1..n, fn _ ->
        Enum.map(sides, &roll(&1, explode?))
      end)
    end)
  end

  defp roll(sides, false) do
    Enum.random(1..sides)
  end

  defp roll(sides, true) do
    result = Enum.random(1..sides)
    explode_roll(sides, result, result)
  end

  defp explode_roll(sides, sides, acc) do
    result = Enum.random(1..sides)
    explode_roll(sides, result, acc + result)
  end

  defp explode_roll(_, _, acc), do: acc
end
