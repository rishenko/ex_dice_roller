defmodule DiceRoller.Compiler do
  @moduledoc """
  Provides functionality for compiling expressions into ready-to-execute functions.
  """

  @type intermediary_value :: compiled_function | integer | float
  @type compiled_function :: (() -> integer | float)

  @doc "Compiles a provided `t:DiceRoller.expression/0` into an anonymous function."
  @spec compile(DiceRoller.expression()) :: intermediary_value
  def compile({:digit, intermediary_value}),
    do: intermediary_value |> to_string() |> String.to_integer()

  def compile({:roll, left_expr, right_expr}) do
    num = compile(left_expr)
    sides = compile(right_expr)

    compile_roll(num, is_function(num), sides, is_function(sides))
  end

  def compile({{:operator, op}, left_expr, right_expr}) do
    left_expr = compile(left_expr)
    right_expr = compile(right_expr)

    compile_op(op, left_expr, is_function(left_expr), right_expr, is_function(right_expr))
  end

  @spec compile_roll(intermediary_value, boolean, intermediary_value, boolean) ::
          compiled_function
  defp compile_roll(num, true, sides, true), do: fn -> roll_final(num.(), sides.()) end
  defp compile_roll(num, true, sides, false), do: fn -> roll_final(num.(), sides) end
  defp compile_roll(num, false, sides, true), do: fn -> roll_final(num, sides.()) end
  defp compile_roll(num, false, sides, false), do: fn -> roll_final(num, sides) end

  @spec roll_final(integer | float, integer | float) :: integer
  defp roll_final(0, _), do: 0

  defp roll_final(num, sides) when num >= 0 and sides >= 0 do
    num = round(num)
    sides = round(sides)
    Enum.reduce(1..num, 0, fn _, total -> Enum.random(1..sides) + total end)
  end

  defp roll_final(_, _),
    do: raise(ArgumentError, "neither number of dice nor number of sides cannot be less than 0")

  @spec compile_op(list, intermediary_value, boolean, intermediary_value, boolean) ::
          intermediary_value
  defp compile_op('+', l, true, r, true), do: fn -> l.() + r.() end
  defp compile_op('-', l, true, r, true), do: fn -> l.() + r.() end
  defp compile_op('*', l, true, r, true), do: fn -> l.() + r.() end
  defp compile_op('/', l, true, r, true), do: fn -> l.() + r.() end
  defp compile_op('+', l, true, r, false), do: fn -> l.() + r end
  defp compile_op('-', l, true, r, false), do: fn -> l.() - r end
  defp compile_op('*', l, true, r, false), do: fn -> l.() * r end
  defp compile_op('/', l, true, r, false), do: fn -> l.() / r end
  defp compile_op('+', l, false, r, true), do: fn -> l + r.() end
  defp compile_op('-', l, false, r, true), do: fn -> l - r.() end
  defp compile_op('*', l, false, r, true), do: fn -> l * r.() end
  defp compile_op('/', l, false, r, true), do: fn -> l / r.() end

  defp compile_op('+', l, false, r, false), do: l + r
  defp compile_op('-', l, false, r, false), do: l - r
  defp compile_op('*', l, false, r, false), do: l * r
  defp compile_op('/', l, false, r, false), do: l / r
end
