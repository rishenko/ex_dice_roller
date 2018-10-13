defmodule ExDiceRoller.Compilers.Math do
  @moduledoc """
  Handles compiling mathematical expressions.
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.Compiler

  @impl true
  def compile({{:operator, op}, left_expr, right_expr}) do
    compile_op(op, Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @operators [
    {'+', &Kernel.+/2, "add"},
    {'-', &Kernel.-/2, "sub"},
    {'*', &Kernel.*/2, "mul"},
    {'/', &Kernel.//2, "div"},
    {'%', &Kernel.rem/2, "mod"},
    {'^', &:math.pow/2, "exp"}
  ]

  @spec compile_op(charlist, Compiler.compiled_val(), Compiler.compiled_val()) ::
          Compiler.compiled_val()

  for {char, _, name} <- @operators do
    defp compile_op(unquote(char), l, r), do: unquote(:"compile_#{name}")(l, r)
  end

  for {_, fun, name} <- @operators do
    @spec unquote(:"compile_#{name}")(Compiler.compiled_val(), Compiler.compiled_val()) ::
            Compiler.compiled_val()

    defp unquote(:"compile_#{name}")(l, r) when is_function(l) and is_function(r) do
      fn args, opts -> op(l.(args, opts), r.(args, opts), unquote(fun)) end
    end

    defp unquote(:"compile_#{name}")(l, r) when is_function(l) do
      fn args, opts -> op(l.(args, opts), r, unquote(fun)) end
    end

    defp unquote(:"compile_#{name}")(l, r) when is_function(r) do
      fn args, opts -> op(l, r.(args, opts), unquote(fun)) end
    end

    defp unquote(:"compile_#{name}")(l, r), do: op(l, r, unquote(fun))
  end

  @spec op(list | number, list | number, function) :: list | number
  defp op(l, r, fun) when is_list(l) and is_list(r) do
    if length(l) != length(r) do
      raise ArgumentError, "you cannot add two lists of different sizes"
    end

    Enum.map(0..(length(l) - 1), &fun.(Enum.at(l, &1), Enum.at(r, &1)))
  end

  defp op(l, r, fun) when is_list(l), do: Enum.map(l, &fun.(&1, r))
  defp op(l, r, fun) when is_list(r), do: Enum.map(r, &fun.(&1, l))
  defp op(l, r, fun), do: fun.(l, r)
end
