defmodule ExDiceRoller.Sigil do
  @moduledoc """
  Handles the sigil `~a` for dice rolling. If no options are specified, the
  sigil will return the compiled function based on the provided roll. Note that
  variables cannot be present in the expression when invoking a roll directly
  from the sigil.

  Also note that if you wish to use the `/` operator with the sigil, you will
  need to use a different delimeter. Example: `~a|1d4+4d6/2d4|`.

  The sigil returns bare values, not `{:ok, _}` tuples. An invalid expression
  or option, or a failed roll, raises `ExDiceRoller.Error`.

  The following options are available, with each invoking a roll:

  * `r`: Compiles and invokes the roll. Variables are not supported with this.
  * `e`: Turns on the exploding dice mechanic.
  * `h`: Select the highest of the calculated values when using the `,`
  separator.
  * `l`: Select the lowest of the calculated values when using the `,`
  separator.
  * `k`: Keeps the value for each dice roll and returns it as a list.

  ## Examples

      iex> import ExDiceRoller.Sigil
      ExDiceRoller.Sigil
      iex> fun = ~a/1+1/
      iex> fun.([])
      2

      iex> import ExDiceRoller.Sigil
      iex> fun = ~a/1d4/
      iex> fun.([])
      1
      iex> fun.([])
      4

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d6+1/r
      4
      iex> ~a/1d2/re
      7

  """

  alias ExDiceRoller.{Compiler, Error}

  @spec sigil_a(String.t(), charlist) :: Compiler.compiled_fun() | Compiler.calculated_val()

  def sigil_a(roll_string, opts) do
    binary_opts = :binary.list_to_bin(opts)

    case translate_opts(binary_opts, []) do
      {:ok, translated_opts} ->
        fun = compile!(roll_string)

        case translated_opts do
          [] -> fun
          _ -> ExDiceRoller.execute!(fun, opts: translated_opts -- [:execute])
        end

      {:error, rest} ->
        raise Error, reason: :invalid_option, details: rest
    end
  end

  # names the expression in the message, since a sigil has no other context
  @spec compile!(String.t()) :: Compiler.compiled_fun()
  defp compile!(roll_string) do
    case ExDiceRoller.compile(roll_string) do
      {:ok, fun} ->
        fun

      {:error, %Error{} = err} ->
        raise %{
          err
          | message: "invalid dice expression #{inspect(roll_string)}: #{Exception.message(err)}"
        }
    end
  end

  @spec translate_opts(binary, list(atom)) :: {:ok, list(atom)} | {:error, any}
  defp translate_opts(<<?r, t::binary>>, acc), do: translate_opts(t, [:execute | acc])
  defp translate_opts(<<?e, t::binary>>, acc), do: translate_opts(t, [:explode | acc])
  defp translate_opts(<<?h, t::binary>>, acc), do: translate_opts(t, [:highest | acc])
  defp translate_opts(<<?l, t::binary>>, acc), do: translate_opts(t, [:lowest | acc])
  defp translate_opts(<<?k, t::binary>>, acc), do: translate_opts(t, [:keep | acc])
  defp translate_opts(<<>>, acc), do: {:ok, acc}
  defp translate_opts(rest, _acc), do: {:error, rest}
end
