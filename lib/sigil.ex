defmodule ExDiceRoller.Sigil do
  @moduledoc """
  Han dles the sigil `~a` for dice rolling. If no options are specified, the
  sigil will return the compiled function based on the provided roll.

  The following options are available:

  * `r`: Compiles and invokes the roll. Variables are not supported with this.
  * `e`: Allows dice to explode. Can only be used alongside option `r`.
  * `h`: If the dice roll contains any separators `,`, select the highest of the calculated values. Can only be used alongside option `r`.
  * `l`: If the dice roll contains any separators `,`, select the lowest of the calculated values. Can only be used alongside option `r`.

  ## Example

      iex> import ExDiceRoller.Sigil
      ExDiceRoller.Sigil
      iex> fun = ~a/1+1/
      iex> fun.([], [])
      2

      iex> import ExDiceRoller.Sigil
      iex> fun = ~a/1d4/
      iex> fun.([], [])
      1
      iex> fun.([], [])
      4

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d6+1/r
      4
      iex> ~a/1d2/re
      7

      iex> import ExDiceRoller.Sigil
      iex> ~a/1d2/e
      {:error, :explode_allowed_only_with_roll}

  """

  @spec sigil_a(String.t(), charlist) :: function | integer | float

  def sigil_a(_, [mod]) when mod == ?e, do: {:error, :explode_allowed_only_with_roll}

  def sigil_a(roll_string, opts) do
    binary_opts = :binary.list_to_bin(opts)

    with {:ok, translated_opts} <- translate_opts(binary_opts, []),
         {:ok, fun} = ExDiceRoller.compile(roll_string) do
      case :execute in translated_opts do
        false ->
          {:ok, fun} = ExDiceRoller.compile(roll_string)
          fun

        true ->
          fun.([], translated_opts -- [:execute])
      end
    else
      {:error, rest} -> {:error, {:invalid_option, rest}}
    end
  end

  @spec translate_opts(binary, list(atom)) :: {:ok, list(atom)} | {:error, any}
  defp translate_opts(<<?r, t::binary>>, acc), do: translate_opts(t, [:execute | acc])
  defp translate_opts(<<?e, t::binary>>, acc), do: translate_opts(t, [:explode | acc])
  defp translate_opts(<<?h, t::binary>>, acc), do: translate_opts(t, [:highest | acc])
  defp translate_opts(<<?l, t::binary>>, acc), do: translate_opts(t, [:lowest | acc])
  defp translate_opts(<<>>, acc), do: {:ok, acc}
  defp translate_opts(rest, _acc), do: {:error, rest}
end
