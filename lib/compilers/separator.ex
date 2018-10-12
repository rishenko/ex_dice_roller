defmodule ExDiceRoller.Compilers.Separator do
  @moduledoc "Handles the `,` separator for rolls."

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @impl true
  def compile({:sep, left_expr, right_expr}) do
    left_expr = Compiler.delegate(left_expr)
    right_expr = Compiler.delegate(right_expr)
    compile_sep(left_expr, is_function(left_expr), right_expr, is_function(right_expr))
  end

  @spec compile_sep(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_sep(l, true, r, true),
    do: fn args, opts -> choose_high_low(l.(args, opts), r.(args, opts), opts) end

  defp compile_sep(l, true, r, false),
    do: fn args, opts -> choose_high_low(l.(args, opts), r, opts) end

  defp compile_sep(l, false, r, true),
    do: fn args, opts -> choose_high_low(l, r.(args, opts), opts) end

  defp compile_sep(l, false, r, false), do: fn _args, opts -> choose_high_low(l, r, opts) end

  @spec choose_high_low(number, number, :highest | :lowest) :: number
  defp choose_high_low(l, l, _), do: l

  defp choose_high_low(l, r, opts) when is_list(opts) do
    case Enum.find(opts, &(&1 in [:highest, :lowest])) do
      :highest -> choose_high_low(l, r, :highest)
      :lowest -> choose_high_low(l, r, :lowest)
      _ -> choose_high_low(l, r, :highest)
    end
  end

  defp choose_high_low(l, r, :highest) when l > r, do: l
  defp choose_high_low(_, r, :highest), do: r
  defp choose_high_low(l, r, :lowest) when l < r, do: l
  defp choose_high_low(_, r, :lowest), do: r
end
