defmodule ExDiceRoller.Compiler do
  @moduledoc """
  Provides functionality for compiling expressions into ready-to-execute
  functions.

  Compiler's main job is to perform the following:

  * takes a concrete parse tree, generally outputted by `ExDiceRoller.Parser`,
  and recursively navigates the tree
  * each expression is delegated to an appropriate module that implements the
  `compile/1` callback, which then
    * converts each expression that results in an invariable value into a number
    * converts each expression containing variability, or randomness, into a
    compiled anonymous function
    * sends sub-expressions back to Compiler to be delegated appropriately
  * wraps the nested set of compiled functions with an anonymous function that
  also rounds the final value

  Note that all compiled functions outputted by Compiler accept both arguments
  and options. Arguments are used exclusively for replacing variables with
  values. Options affect the behavior of the anonymous functions and include
  concepts such as exploding dice, choosing highest or lowest values, and more.

  More information about the different types of expression compilers and their
  function can be found in the individual `ExDiceRoller.Compiler.*` modules.

  ## Example

      > parsed =
        {{:operator, '+'},
        {{:operator, '-'}, {:roll, 1, 4},
          {{:operator, '/'}, {:roll, 3, 6}, 2}},
        {:roll, {:roll, 1, 4},
          {:roll, 1, 6}}}

      > fun = ExDiceRoller.Compiler.compile(parsed)
      #Function<1.51809653/1 in ExDiceRoller.Compiler.compile/1>

      > fun.([])
      11

      > ExDiceRoller.Compiler.fun_info(fun)
      {#Function<0.102777967/1 in ExDiceRoller.Compilers.Math.compile_add/2>,
      :"-compile_add/2-fun-1-",
      [
        {#Function<20.102777967/1 in ExDiceRoller.Compilers.Math.compile_sub/2>,
          :"-compile_sub/2-fun-1-",
          [
            {#Function<3.31405244/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
            :"-compile_roll/2-fun-3-", [1, 4]},
            {#Function<5.102777967/1 in ExDiceRoller.Compilers.Math.compile_div/2>,
            :"-compile_div/2-fun-3-",
            [
              {#Function<3.31405244/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
                :"-compile_roll/2-fun-3-", [3, 6]},
              2
            ]}
          ]},
        {#Function<0.31405244/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
          :"-compile_roll/2-fun-0-",
          [
            {#Function<3.31405244/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
            :"-compile_roll/2-fun-3-", [1, 4]},
            {#Function<3.31405244/1 in ExDiceRoller.Compilers.Roll.compile_roll/2>,
            :"-compile_roll/2-fun-3-", [1, 6]}
          ]}
      ]}

  """

  alias ExDiceRoller.{Filters, Parser}
  alias ExDiceRoller.Compilers.{Math, Roll, Separator, Variable}

  @type compiled_val :: compiled_fun | calculated_val
  @type compiled_fun :: (args -> calculated_val)
  @type calculated_val :: number | list(number)
  @type fun_info_tuple :: {function, atom, list(any)}
  @type args :: Keyword.t()

  @doc "Compiles the expression into a `t:compiled_val/0`."
  @callback compile(Parser.expression()) :: compiled_val

  @doc """
  Compiles a provided `t:Parser.expression/0` into an anonymous function.

      iex> expr = "1d2+x"
      "1d2+x"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok,
      [
        {:int, 1, '1'},
        {:roll, 1, 'd'},
        {:int, 1, '2'},
        {:basic_operator, 1, '+'},
        {:var, 1, 'x'}
      ]}
      iex> {:ok, parsed} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {{:operator, '+'}, {:roll, 1, 2}, {:var, 'x'}}}
      iex> fun = ExDiceRoller.Compiler.compile(parsed)
      iex> fun.([x: 1, opts: [:explode]])
      2

  During calculation, float values are left as float for as long as possible.
  If a compiled roll is invoked with a float as the number of dice or sides,
  that value will be rounded to an integer. Finally, the return value is a
  rounded integer. Rounding rules can be found at `Kernel.round/1`.
  """
  @spec compile(Parser.expression()) :: compiled_val
  def compile(expression) do
    compiled = delegate(expression)

    compiled =
      case is_function(compiled) do
        false -> fn _args -> compiled end
        true -> compiled
      end

    fn args when is_list(args) ->
      args =
        case args[:opts] do
          val when val == nil or is_list(val) -> args
          val -> Keyword.put(args, :opts, [val])
        end

      {filters, args} = Filters.get_filters(args)

      args
      |> compiled.()
      |> round_val()
      |> Filters.filter(filters)
    end
  end

  @doc """
  Delegates expression compilation to an appropriate module that implements
  `ExDiceRoller.Compiler` behaviours.
  """
  @spec delegate(Parser.expression()) :: compiled_val
  def delegate({:roll, _, _} = expr), do: Roll.compile(expr)
  def delegate({{:operator, _}, _, _} = expr), do: Math.compile(expr)
  def delegate({:sep, _, _} = expr), do: Separator.compile(expr)
  def delegate({:var, _} = var), do: Variable.compile(var)
  def delegate(compiled_val) when is_number(compiled_val), do: compiled_val

  @doc """
  Shows the nested functions and relationships of a compiled function. The
  structure of the fun_info result is `{<function>, <atom with name, arity, and
  ordered function #>, [<recursive info about child functions>]}`.

      > {:ok, fun} = ExDiceRoller.compile("1d8+(1-x)d(2*y)")
      #=> {:ok, #Function<0.84780260/1 in ExDiceRoller.Compiler.compile_add/4>}

      > ExDiceRoller.Compiler.fun_info fun
      #=> {#Function<0.16543174/1 in ExDiceRoller.Compiler.compile_add/4>,
      :"-compile_add/4-fun-0-",
      [
        {#Function<12.16543174/1 in ExDiceRoller.Compiler.compile_roll/4>,
          :"-compile_roll/4-fun-3-", [1, 8]},
        {#Function<9.16543174/1 in ExDiceRoller.Compiler.compile_roll/4>,
          :"-compile_roll/4-fun-0-",
          [
            {#Function<15.16543174/1 in ExDiceRoller.Compiler.compile_sub/4>,
            :"-compile_sub/4-fun-2-",
            [
              1,
              {#Function<16.16543174/1 in ExDiceRoller.Compiler.compile_var/1>,
                :"-compile_var/1-fun-0-", ['x']}
            ]},
            {#Function<8.16543174/1 in ExDiceRoller.Compiler.compile_mul/4>,
            :"-compile_mul/4-fun-2-",
            [
              2,
              {#Function<16.16543174/1 in ExDiceRoller.Compiler.compile_var/1>,
                :"-compile_var/1-fun-0-", ['y']}
            ]}
          ]}
      ]}

  """
  @spec fun_info(compiled_fun) :: fun_info_tuple
  def fun_info(fun) do
    info = :erlang.fun_info(fun)
    info[:env] |> hd() |> do_fun_info()
  end

  @doc "Performs rounding on both numbers and lists of numbers."
  @spec round_val(calculated_val | float) :: calculated_val

  def round_val([]), do: []
  def round_val(val) when is_list(val), do: Enum.map(val, &round_val(&1))

  def round_val(val) when is_number(val), do: Kernel.round(val)

  @spec do_fun_info(function | number | charlist) :: function | number | charlist

  defp do_fun_info(fun) when is_function(fun) do
    info = :erlang.fun_info(fun)

    {fun, info[:name],
     info[:env]
     |> Enum.reverse()
     |> Enum.map(fn child ->
       do_fun_info(child)
     end)}
  end

  defp do_fun_info(num) when is_number(num), do: num
  defp do_fun_info(str) when is_list(str), do: str
end
