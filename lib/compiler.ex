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

  ## Example

      > parsed =
        {{:operator, '+'},
        {{:operator, '-'}, {:roll, {:digit, '1'}, {:digit, '4'}},
          {{:operator, '/'}, {:roll, {:digit, '3'}, {:digit, '6'}}, {:digit, '2'}}},
        {:roll, {:roll, {:digit, '1'}, {:digit, '4'}},
          {:roll, {:digit, '1'}, {:digit, '6'}}}}

      > fun = ExDiceRoller.Compiler.compile(parsed)
      #Function<0.47893785/2 in ExDiceRoller.Compiler.compile_add/4>

      > fun.([], [])
      4

      > ExDiceRoller.Compiler.fun_info(fun)
      {#Function<0.47893785/2 in ExDiceRoller.Compiler.compile_add/4>,
        :"-compile_add/4-fun-0-",
        [
          {#Function<13.47893785/2 in ExDiceRoller.Compiler.compile_sub/4>,
            :"-compile_sub/4-fun-0-",
            [
              {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
              :"-compile_roll/4-fun-3-", [1, 4]},
              {#Function<4.47893785/2 in ExDiceRoller.Compiler.compile_div/4>,
              :"-compile_div/4-fun-1-",
              [
                {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
                  :"-compile_roll/4-fun-3-", [3, 6]},
                2
              ]}
            ]},
          {#Function<9.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
            :"-compile_roll/4-fun-0-",
            [
              {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
              :"-compile_roll/4-fun-3-", [1, 4]},
              {#Function<12.47893785/2 in ExDiceRoller.Compiler.compile_roll/4>,
              :"-compile_roll/4-fun-3-", [1, 6]}
            ]}
        ]}

  """

  alias ExDiceRoller.Parser
  alias ExDiceRoller.Compilers.{Math, Roll, Separator, Variable}
  @type calculated_val :: number | list(integer)
  @type compiled_val :: compiled_fun | calculated_val
  @type compiled_fun :: (args, opts -> calculated_val)
  @type fun_info_tuple :: {function, atom, list(any)}
  @type args :: Keyword.t()
  @type opts :: list(atom | {atom, any})

  @doc "Compiles the expression into a `t:compiled_val/0`."
  @callback compile(Parser.expression()) :: compiled_val

  @doc """
  Compiles a provided `t:Parser.expression/0` into an anonymous function.

      iex> expr = "1d2+x"
      "1d2+x"
      iex> {:ok, tokens} = ExDiceRoller.Tokenizer.tokenize(expr)
      {:ok,
      [
        {:digit, 1, '1'},
        {:roll, 1, 'd'},
        {:digit, 1, '2'},
        {:basic_operator, 1, '+'},
        {:var, 1, 'x'}
      ]}
      iex> {:ok, parsed} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {{:operator, '+'}, {:roll, {:digit, '1'}, {:digit, '2'}}, {:var, 'x'}}}
      iex> fun = ExDiceRoller.Compiler.compile(parsed)
      iex> fun.([x: 1], [:explode])
      2

  During calculation, float values are left as float for as long as possible.
  If a compiled roll is invoked with a float as the number of dice or sides,
  that value will be rounded to an integer. Finally, the return value is an
  integer. Rounding rules can be found at `Kernel.round/1`.
  """
  @spec compile(Parser.expression()) :: compiled_val
  def compile(expression) do
    compiled = delegate(expression)

    compiled =
      case is_function(compiled) do
        false -> fn _args, _opts -> compiled end
        true -> compiled
      end

    fn args, opts ->
      args
      |> compiled.(opts)
      |> round_val()
    end
  end

  @doc """
  Delegates expression compilation to an appropriate module implementing
  `ExDiceRoller.Compiler` behaviours.
  """
  @spec delegate(Parser.expression()) :: compiled_val
  def delegate({:digit, compiled_val}),
    do: compiled_val |> to_string() |> String.to_integer()

  def delegate({:roll, _, _} = expr), do: Roll.compile(expr)
  def delegate({{:operator, _}, _, _} = expr), do: Math.compile(expr)
  def delegate({:sep, _, _} = expr), do: Separator.compile(expr)
  def delegate({:var, _} = var), do: Variable.compile(var)

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
  def round_val(val) when is_list(val) do
    Enum.map(val, &round(&1))
  end

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
