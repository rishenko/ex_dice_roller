defmodule ExDiceRoller.Compilers.Math do
  @moduledoc "Handles compiling mathematical expressions. "

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @impl true
  def compile({{:operator, op}, left_expr, right_expr}) do
    left_expr = Compiler.delegate(left_expr)
    right_expr = Compiler.delegate(right_expr)
    compile_op(op, left_expr, is_function(left_expr), right_expr, is_function(right_expr))
  end

  @spec compile_op(list, Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_op('+', l, l_fun?, r, r_fun?), do: compile_add(l, l_fun?, r, r_fun?)
  defp compile_op('-', l, l_fun?, r, r_fun?), do: compile_sub(l, l_fun?, r, r_fun?)
  defp compile_op('*', l, l_fun?, r, r_fun?), do: compile_mul(l, l_fun?, r, r_fun?)
  defp compile_op('/', l, l_fun?, r, r_fun?), do: compile_div(l, l_fun?, r, r_fun?)
  defp compile_op('%', l, l_fun?, r, r_fun?), do: compile_mod(l, l_fun?, r, r_fun?)
  defp compile_op('^', l, l_fun?, r, r_fun?), do: compile_exp(l, l_fun?, r, r_fun?)

  @spec compile_add(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_add(l, true, r, true), do: fn args, opts -> l.(args, opts) + r.(args, opts) end
  defp compile_add(l, true, r, false), do: fn args, opts -> l.(args, opts) + r end
  defp compile_add(l, false, r, true), do: fn args, opts -> l + r.(args, opts) end
  defp compile_add(l, false, r, false), do: l + r

  @spec compile_sub(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_sub(l, true, r, true), do: fn args, opts -> l.(args, opts) - r.(args, opts) end
  defp compile_sub(l, true, r, false), do: fn args, opts -> l.(args, opts) - r end
  defp compile_sub(l, false, r, true), do: fn args, opts -> l - r.(args, opts) end
  defp compile_sub(l, false, r, false), do: l - r

  @spec compile_mul(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_mul(l, true, r, true), do: fn args, opts -> l.(args, opts) * r.(args, opts) end
  defp compile_mul(l, true, r, false), do: fn args, opts -> l.(args, opts) * r end
  defp compile_mul(l, false, r, true), do: fn args, opts -> l * r.(args, opts) end
  defp compile_mul(l, false, r, false), do: l * r

  @spec compile_div(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_div(l, true, r, true), do: fn args, opts -> l.(args, opts) / r.(args, opts) end
  defp compile_div(l, true, r, false), do: fn args, opts -> l.(args, opts) / r end
  defp compile_div(l, false, r, true), do: fn args, opts -> l / r.(args, opts) end
  defp compile_div(l, false, r, false), do: l / r

  @spec compile_mod(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_mod(l, true, r, true), do: fn args, opts -> rem(l.(args, opts), r.(args, opts)) end
  defp compile_mod(l, true, r, false), do: fn args, opts -> rem(l.(args, opts), r) end
  defp compile_mod(l, false, r, true), do: fn args, opts -> rem(l, r.(args, opts)) end
  defp compile_mod(l, false, r, false), do: rem(l, r)

  @spec compile_exp(Compiler.compiled_val(), boolean, Compiler.compiled_val(), boolean) ::
          Compiler.compiled_val()
  defp compile_exp(l, true, r, true),
    do: fn args, opts -> :math.pow(l.(args, opts), r.(args, opts)) end

  defp compile_exp(l, true, r, false), do: fn args, opts -> :math.pow(l.(args, opts), r) end
  defp compile_exp(l, false, r, true), do: fn args, opts -> :math.pow(l, r.(args, opts)) end
  defp compile_exp(l, false, r, false), do: :math.pow(l, r)
end
