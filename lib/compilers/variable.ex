defmodule ExDiceRoller.Compilers.Variable do
  @moduledoc """
  Handles compiling expressions that use variables.

  Variables can be used to replace single letters in an expression with a
  value, such as a number or a compiled roll function. Any letter except `d`
  and `D` (the roll operator) can be a variable. Letters written directly after
  a roll's sides are read as dice modifiers instead (see
  `ExDiceRoller.Compilers.Roll`), so `4d6k` keeps a die, while `4d6+k` adds the
  variable `k`.

  Acceptable variable values include:

  * integers
  * floats
  * compiled functions matching `t:Compiler.compiled_fun/2`
  * strings that can be parsed by ExDiceRoller (parsed on every roll, or once
  with `cache: true`)
  * lists composed of any of the above
  * lists of lists

  Note that an error will be raised if values are not supplied for all variables
  in an expression.

  ### Examples

      iex> import ExDiceRoller.Sigil
      ExDiceRoller.Sigil
      iex> ExDiceRoller.roll!(~a/1+x/, [x: 5])
      6
      iex> ExDiceRoller.roll!("xdy+z", x: 5, y: 10, z: 50)
      82
      iex> ExDiceRoller.roll!("xdy+z", [x: 5, y: 10, z: ~a/15d100/])
      739
      iex> ExDiceRoller.roll!("xdy+z", x: [1, 2, 3], y: 1, z: 5, opts: [:keep])
      [6, 6, 6, 6, 6, 6]
      iex> ExDiceRoller.roll!("xdy+z", [x: 1, y: [1, 10, 100], z: -6, opts: [:keep]])
      [-5, -4, 66]
      iex> ExDiceRoller.roll!("xdy+z", x: [~a/1d2/, "1d4+1"], y: ["3,4d20/2", ~a/1d6/], z: 2, opts: [:keep])
      [8, 8, 3, 3, 3, 10, 4, 7, 6, 3, 5, 4, 4, 4, 3]

      iex> ExDiceRoller.roll!("1+x")
      ** (ExDiceRoller.Error) no variable 'x' was found in the arguments
  """

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Args, Cache, Compiler, Error, Parser, Tokenizer}

  @impl true
  def compile({:var, _} = var), do: compile_var(var)

  @spec compile_var({:var, charlist}) :: Compiler.compiled_fun()
  # the argument key is computed once here, not on every call
  defp compile_var({:var, var}) do
    key = List.to_atom(var)
    fn args -> __value__(key, args) end
  end

  @doc false
  # The value of variable `key` in `args`. Used by compiled closures and by
  # `ExDiceRoller.Roller`.
  @spec __value__(atom, Keyword.t()) :: Compiler.calculated_val()
  def __value__(key, args) do
    args
    |> Args.get_var(key)
    |> var_final_arg(key, args)
  end

  @spec var_final_arg(any, atom, Keyword.t()) :: number
  defp var_final_arg(nil, var, _) do
    raise Error,
      reason: :missing_variable,
      details: var,
      message: "no variable '#{var}' was found in the arguments"
  end

  defp var_final_arg(val, _, _) when is_number(val), do: val

  defp var_final_arg(val, var, args) when is_function(val) do
    chain = enter(var, args)

    try do
      val.(args)
    after
      leave(chain)
    end
  end

  defp var_final_arg(val, var, args) when is_binary(val) do
    compiled =
      if Args.use_cache?(args),
        do: Cache.obtain_variable(val),
        else: compile_value(val)

    case compiled do
      {:ok, compiled_arg} ->
        var_final_arg(compiled_arg, var, args)

      {:error, %Error{} = err} ->
        raise Error,
          reason: :invalid_variable,
          details: {var, err},
          message:
            "invalid expression #{inspect(val)} for variable '#{var}': #{Exception.message(err)}"
    end
  end

  defp var_final_arg(val, var, args) when is_list(val) do
    Enum.map(val, &var_final_arg(&1, var, args))
  end

  # The variables whose values are being evaluated in this process, innermost
  # first, with the arguments they were looked up in. Only string and
  # function values can refer to other variables, so only they are tracked;
  # plain numbers cost nothing. Evaluating a value always evaluates all of it
  # (there are no conditionals), so meeting the same variable with the same
  # arguments again means the value can never be resolved. A function value
  # that starts a new roll with other arguments is not a cycle.
  @resolving {__MODULE__, :resolving}

  # records `var` as being resolved and returns the previous chain
  defp enter(var, args) do
    case Process.get(@resolving) do
      nil ->
        Process.put(@resolving, [{var, args}])
        nil

      chain ->
        if {var, args} in chain, do: recursive!(var, chain)
        Process.put(@resolving, [{var, args} | chain])
        chain
    end
  end

  defp leave(nil), do: Process.delete(@resolving)
  defp leave(chain), do: Process.put(@resolving, chain)

  defp recursive!(var, chain) do
    names = Enum.reverse([var | Enum.map(chain, &elem(&1, 0))])

    raise Error,
      reason: :recursive_variable,
      details: names,
      message:
        "variable '#{var}' refers to itself (#{Enum.map_join(names, " -> ", &to_string/1)})"
  end

  @doc false
  # Compiles an expression given as a variable's value. The result is not
  # rounded or filtered: it is part of the enclosing roll.
  @spec compile_value(String.t()) :: {:ok, Compiler.compiled_val()} | {:error, Error.t()}
  def compile_value(string) do
    with {:ok, tokens} <- Tokenizer.tokenize(string),
         {:ok, parsed} <- Parser.parse(tokens) do
      {:ok, Compiler.delegate(parsed)}
    end
  end
end
