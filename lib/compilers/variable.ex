defmodule ExDiceRoller.Compilers.Variable do
  @moduledoc "Handles compiling expressions that use variables."

  @behaviour ExDiceRoller.Compiler
  alias ExDiceRoller.{Compiler, Tokenizer, Parser}

  @impl true
  def compile({:var, _} = var), do: compile_var(var)

  @spec compile_var({:var, charlist}) :: Compiler.compiled_fun()
  defp compile_var({:var, var}), do: fn args, opts -> var_final(var, args, opts) end

  @spec var_final(charlist, Compiler.args(), Compiler.opts()) :: number
  defp var_final(var, args, opts) do
    key = var |> to_string() |> String.to_atom()

    args
    |> Keyword.get(key)
    |> var_final_arg(var, opts)
  end

  @spec var_final_arg(any, charlist, Compiler.opts()) :: number
  defp var_final_arg(nil, var, _),
    do: raise(ArgumentError, "no variable #{inspect(var)} was found in the arguments")

  defp var_final_arg(val, _, _) when is_integer(val), do: val
  defp var_final_arg(val, _, opts) when is_function(val), do: val.([], opts)

  defp var_final_arg(val, var, opts) when is_bitstring(val) do
    {:ok, tokens} = Tokenizer.tokenize(val)
    {:ok, parsed} = Parser.parse(tokens)
    compiled_arg = Compiler.delegate(parsed)

    var_final_arg(compiled_arg, var, opts)
  end
end
