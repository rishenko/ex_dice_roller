defmodule ExDiceRoller.Compiler do
  @moduledoc """
  Provides functionality for compiling expressions into ready-to-execute
  functions.

  Compiler's main job is to perform the following:

  * takes a concrete parse tree, generally outputted by `ExDiceRoller.Parser`,
  and recursively navigates the tree
  * each expression is delegated to an appropriate module that implements the
  `compile/1` callback, which then
    * leaves number literals as numbers
    * converts every other expression (math, rolls, variables, separators)
    into a compiled anonymous function. Constant math such as `1+2` is not
    folded at compile time; it is calculated when the function runs.
    * sends sub-expressions back to Compiler to be delegated appropriately
  * wraps the nested set of compiled functions with an anonymous function that
  also:
    * applies any `ExDiceRoller.Filters` present in the arguments
    * rounds and returns the final value

  Note that all compiled functions outputted by Compiler accept a single
  keyword list holding both variable values (such as `x: 3`) and `opts`.
  Variable values replace variables. Options affect the behavior of the anonymous functions and include
  concepts such as exploding dice, choosing highest or lowest values, and more.

  More information about the different types of expression compilers and their
  function can be found in the individual `ExDiceRoller.Compilers.*` modules.

  ## Example

      > parsed =
        {{:operator, ~c"+"},
        {{:operator, ~c"-"}, {:roll, 1, 4},
          {{:operator, ~c"/"}, {:roll, 3, 6}, 2}},
        {:roll, {:roll, 1, 4},
          {:roll, 1, 6}}}

      > fun = ExDiceRoller.Compiler.compile(parsed)
      #Function<0.39667494/1 in ExDiceRoller.Compiler.build_final_function/1>

      > fun.([])
      11

      > ExDiceRoller.Compiler.fun_info(fun)
      {#Function<0.46256084/1 in ExDiceRoller.Compilers.Math.compile_add/2>,
       :"-compile_add/2-fun-0-",
       [
         {#Function<4.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
          :"-compile_roll/3-fun-0-",
          [
            [],
            {#Function<7.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
             :"-compile_roll/3-fun-3-", [[], 6, 1]},
            {#Function<7.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
             :"-compile_roll/3-fun-3-", [[], 4, 1]}
          ]},
         {#Function<20.46256084/1 in ExDiceRoller.Compilers.Math.compile_sub/2>,
          :"-compile_sub/2-fun-0-",
          [
            {#Function<5.46256084/1 in ExDiceRoller.Compilers.Math.compile_div/2>,
             :"-compile_div/2-fun-1-",
             [
               2,
               {#Function<7.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
                :"-compile_roll/3-fun-3-", [[], 6, 3]}
             ]},
            {#Function<7.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
             :"-compile_roll/3-fun-3-", [[], 4, 1]}
          ]}
       ]}

  The output above is from Elixir 1.18 / OTP 27; see `fun_info/1` for why it
  varies.

  """

  alias ExDiceRoller.{Args, Filters, Parser}
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
        {:int, 1, ~c"1"},
        {:roll, 1, ~c"d"},
        {:int, 1, ~c"2"},
        {:basic_operator, 1, ~c"+"},
        {:var, 1, ~c"x"}
      ]}
      iex> {:ok, parsed} = ExDiceRoller.Parser.parse(tokens)
      {:ok, {{:operator, ~c"+"}, {:roll, 1, 2}, {:var, ~c"x"}}}
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
    expression
    |> delegate()
    |> wrap_compiled_expression()
    |> build_final_function()
  end

  @doc """
  Delegates expression compilation to an appropriate module that implements
  `ExDiceRoller.Compiler` behaviours.
  """
  @spec delegate(Parser.expression()) :: compiled_val
  def delegate({:roll, _, _} = expr), do: Roll.compile(expr)
  def delegate({:roll, _, _, _} = expr), do: Roll.compile(expr)
  def delegate({{:operator, _}, _, _} = expr), do: Math.compile(expr)
  def delegate({:sep, _, _} = expr), do: Separator.compile(expr)
  def delegate({:var, _} = var), do: Variable.compile(var)
  def delegate(compiled_val) when is_number(compiled_val), do: compiled_val

  @doc """
  Shows the nested functions and relationships of a compiled function. The
  structure of the fun_info result is `{<function>, <atom with name, arity, and
  ordered function #>, [<recursive info about child functions>]}`.

  The function names and the order of child entries come from the BEAM and
  differ between OTP releases (on OTP 27 the children appear in reverse, and
  each roll lists its modifiers first), so treat this output as a debugging aid
  rather than a stable format.

      > {:ok, fun} = ExDiceRoller.compile("1d8+(1-x)d(2*y)")
      {:ok, #Function<0.39667494/1 in ExDiceRoller.Compiler.build_final_function/1>}

      > ExDiceRoller.Compiler.fun_info(fun)
      {#Function<0.46256084/1 in ExDiceRoller.Compilers.Math.compile_add/2>,
       :"-compile_add/2-fun-0-",
       [
         {#Function<4.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
          :"-compile_roll/3-fun-0-",
          [
            [],
            {#Function<18.46256084/1 in ExDiceRoller.Compilers.Math.compile_mul/2>,
             :"-compile_mul/2-fun-2-",
             [
               {#Function<0.19101679/1 in ExDiceRoller.Compilers.Variable.compile_var/1>,
                :"-compile_var/1-fun-0-", [:y]},
               2
             ]},
            {#Function<22.46256084/1 in ExDiceRoller.Compilers.Math.compile_sub/2>,
             :"-compile_sub/2-fun-2-",
             [
               {#Function<0.19101679/1 in ExDiceRoller.Compilers.Variable.compile_var/1>,
                :"-compile_var/1-fun-0-", [:x]},
               1
             ]}
          ]},
         {#Function<7.18758502/1 in ExDiceRoller.Compilers.Roll.compile_roll/3>,
          :"-compile_roll/3-fun-3-", [[], 8, 1]}
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

  @spec do_fun_info(function | number | atom | list) :: function | number | atom | list

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
  defp do_fun_info(atom) when is_atom(atom), do: atom
  defp do_fun_info(str) when is_list(str), do: str

  @spec wrap_compiled_expression(compiled_val) :: function
  defp wrap_compiled_expression(compiled) do
    case is_function(compiled) do
      false -> fn _args -> compiled end
      true -> compiled
    end
  end

  @spec build_final_function(function) :: compiled_fun
  defp build_final_function(compiled) do
    fn args when is_list(args) ->
      args = Args.sanitize(args)

      {filters, args} = Args.get_filters(args)

      args
      |> compiled.()
      |> round_val()
      |> Filters.filter(filters)
    end
  end
end
