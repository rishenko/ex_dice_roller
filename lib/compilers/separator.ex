defmodule ExDiceRoller.Compilers.Separator do
  @moduledoc """
  Handles the `,` separator for rolls.
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @error_both_sides "separator can only be used when both sides are a list or both sides are a number"

  @impl true
  def compile({:sep, left_expr, right_expr}) do
    compile_sep(Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @spec compile_sep(Compiler.compiled_val(), Compiler.compiled_val()) :: Compiler.compiled_val()
  defp compile_sep(l, r) when is_function(l) and is_function(r),
    do: fn args, opts -> high_low(l.(args, opts), r.(args, opts), opts) end

  defp compile_sep(l, r) when is_function(l),
    do: fn args, opts -> high_low(l.(args, opts), r, opts) end

  defp compile_sep(l, r) when is_function(r),
    do: fn args, opts -> high_low(l, r.(args, opts), opts) end

  defp compile_sep(l, r), do: fn _args, opts -> high_low(l, r, opts) end

  @spec high_low(Compiler.calculated_val(), Compiler.calculated_val(), :highest | :lowest) ::
          Compiler.calculated_val()
  defp high_low(l, l, _), do: l

  defp high_low(l, r, opts) when is_list(opts) do
    case Enum.find(opts, &(&1 in [:highest, :lowest])) do
      :highest -> high_low(l, r, :highest)
      :lowest -> high_low(l, r, :lowest)
      _ -> high_low(l, r, :highest)
    end
  end

  defp high_low(l, r, level) when is_list(l) and is_list(r) do
    if length(l) != length(r) do
      raise ArgumentError, "cannot use separator on lists of differing lengths"
    end

    Enum.map(0..(length(l) - 1), &high_low(Enum.at(l, &1), Enum.at(r, &1), level))
  end

  defp high_low(l, _, _) when is_list(l), do: raise(ArgumentError, @error_both_sides)
  defp high_low(_, r, _) when is_list(r), do: raise(ArgumentError, @error_both_sides)
  defp high_low(l, r, :highest) when l > r, do: l
  defp high_low(_, r, :highest), do: r
  defp high_low(l, r, :lowest) when l < r, do: l
  defp high_low(_, r, :lowest), do: r
end
