defmodule ExDiceRoller.Compilers.Math do
  @moduledoc """
  Handles compiling expressions using common mathematical operators.

      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize("1+x")
      {:ok, [{:int, 1, '1'}, {:basic_operator, 1, '+'}, {:var, 1, 'x'}]}
      iex> {:ok, parse_tree} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {{:operator, '+'}, 1, {:var, 'x'}}}
      iex> fun = ExDiceRoller.Compilers.Math.compile(parse_tree)
      iex> fun.([x: 2], [])
      3
      iex> fun.([x: 2.4], [])
      3.4

  ExDiceRoller uses [infix notation](https://en.wikipedia.org/wiki/Infix_notation)
  when working with mathematical operators. Below is the list of operators
  currently supported by ExDiceRoller:

  * `+`: adds the values on both sides of the expression
  * `-`: subtracts the value on the right from the value on the left
  * `*`: multiplies the values on both sides of the expression
  * `/`: divides, with the left value as the dividend, the right the divisor
  * `%`: [modulo](https://en.wikipedia.org/wiki/Modulo_operation), with the
  left the dividend, the right the divisor
  * `^`: exponentiation, with the left the base, the right the exponent
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Compiler, ListComprehension}

  @err_name "math operators"

  @operators [
    {'+', &Kernel.+/2, "add"},
    {'-', &Kernel.-/2, "sub"},
    {'*', &Kernel.*/2, "mul"},
    {'/', &__MODULE__.divide/2, "div"},
    {'%', &__MODULE__.modulo/2, "mod"},
    {'^', &:math.pow/2, "exp"}
  ]

  @doc "Function used for modulo calculations. Only accepts integer values."
  @spec modulo(integer, integer) :: integer

  def modulo(_, 0), do: raise(ArgumentError, "the divisor cannot be 0")

  def modulo(l, r) when is_integer(l) and is_integer(r) do
    rem(Compiler.round_val(l), Compiler.round_val(r))
  end

  def modulo(_, _), do: raise(ArgumentError, "modulo only accepts integer values")

  @doc "Function used for division calculations."
  @spec divide(Compiler.calculated_val(), Compiler.calculated_val()) :: float
  def divide(_, 0), do: raise(ArgumentError, "the divisor cannot be 0")

  def divide(l, r) do
    l / r
  end

  @impl true
  def compile({{:operator, op}, left_expr, right_expr}) do
    compile_op(op, Compiler.delegate(left_expr), Compiler.delegate(right_expr))
  end

  @spec compile_op(charlist, Compiler.compiled_val(), Compiler.compiled_val()) ::
          Compiler.compiled_val()

  for {char, _, name} <- @operators do
    defp compile_op(unquote(char), l, r), do: unquote(:"compile_#{name}")(l, r)
  end

  for {_, fun, name} <- @operators do
    @spec unquote(:"compile_#{name}")(Compiler.compiled_val(), Compiler.compiled_val()) ::
            Compiler.compiled_val()

    defp unquote(:"compile_#{name}")(l, r) when is_function(l) and is_function(r) do
      fn args, opts ->
        ListComprehension.apply(l.(args, opts), r.(args, opts), unquote(fun), @err_name, &op/3)
      end
    end

    defp unquote(:"compile_#{name}")(l, r) when is_function(l) do
      fn args, opts ->
        ListComprehension.apply(l.(args, opts), r, unquote(fun), @err_name, &op/3)
      end
    end

    defp unquote(:"compile_#{name}")(l, r) when is_function(r) do
      fn args, opts ->
        ListComprehension.apply(l, r.(args, opts), unquote(fun), @err_name, &op/3)
      end
    end

    defp unquote(:"compile_#{name}")(l, r) do
      fn _, _ ->
        ListComprehension.apply(l, r, unquote(fun), @err_name, &op/3)
      end
    end
  end

  @spec op(Compiler.calculated_val(), Compiler.calculated_val(), function) ::
          Compiler.calculated_val()
  defp op(l, r, fun), do: fun.(l, r)
end
