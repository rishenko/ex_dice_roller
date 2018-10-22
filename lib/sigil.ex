defmodule ExDiceRoller.Sigil do
  @moduledoc """
  Han dles the sigil `~a` for dice rolling. If no options are specified, the
  sigil will return the compiled function based on the provided roll. Note that
  variables cannot be present in the expression when invoking a roll directly
  from the sigil.

  Also note that if you wish to use the `/` operator with the sigil, you will
  need to use a different delimeter. Example being `~a|1d4+4d6/2d4`.

  The following options are available, with each invoking a roll:

  * `r`: Compiles and invokes the roll. Variables are not supported with this.
  * `e`: Turns on the exploding dice mechanic.
  * `h`: Select the highest of the calculated values when using the `,`
  separator.
  * `l`: Select the highest of the calculated values when using the `,`
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

  @spec sigil_a(String.t(), charlist) :: Compiler.compiled_val()

  def sigil_a(roll_string, opts) do
    binary_opts = :binary.list_to_bin(opts)

    with {:ok, translated_opts} <- translate_opts(binary_opts, []),
         {:ok, fun} = ExDiceRoller.compile(roll_string) do
      case length(translated_opts) > 0 do
        false ->
          {:ok, fun} = ExDiceRoller.compile(roll_string)
          fun

        true ->
          fun.(opts: translated_opts -- [:execute])
      end
    else
      {:error, reason} -> {:error, {:invalid_option, reason}}
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
