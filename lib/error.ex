defmodule ExDiceRoller.Error do
  @moduledoc """
  The error returned (as `{:error, %ExDiceRoller.Error{}}`) or raised by
  ExDiceRoller.

  Functions without a `!` return `{:error, error}`; `ExDiceRoller.roll!/2`,
  `ExDiceRoller.compile!/1`, `ExDiceRoller.execute!/2`, the `~a` sigil, and
  compiled roll functions called directly raise it.

  Fields:

  * `:reason`: an atom naming the kind of error (see `t:reason/0`)
  * `:details`: extra data for the error, or `nil`
  * `:message`: a human-readable description

  Reasons:

  * `:tokenizing_failed`: the expression contains characters ExDiceRoller
  does not recognize. `:details` is the leex error.
  * `:token_parsing_failed`: the expression is not valid syntax. `:details` is
  the yecc error.
  * `:cannot_compile_roll`: `ExDiceRoller.compile/1` was given something other
  than a string or parsed expression. `:details` is the value.
  * `:negative_dice`: a dice count or side count is negative.
  * `:divide_by_zero`: the divisor of `/` or `%` is 0.
  * `:non_integer_modulo`: an operand of `%` is not a whole number.
  * `:list_length_mismatch`: two kept-roll lists of different lengths were
  combined.
  * `:missing_variable`: no value was given for a variable. `:details` is the
  variable name as an atom.
  * `:invalid_variable`: a variable's string value is not a valid expression.
  `:details` is `{variable, error}`.
  * `:arithmetic_error`: the calculation failed in Erlang, for example a float
  overflow from `^`. `:details` is the original `ArithmeticError`.
  * `:invalid_modifier`: reroll modifiers that can never stop, such as
  `1d6r<7`, or that leave only the highest face while exploding.
  `:details` is the list of reroll conditions.
  * `:invalid_option`: the `~a` sigil was given an unknown flag. `:details` is
  the unrecognized part.
  * `:invalid_roll_key`: `ExDiceRoller.Cache.delete/2` was given a key that is
  not a string. `:details` is the key.

      iex> {:error, error} = ExDiceRoller.roll("1/0")
      iex> error.reason
      :divide_by_zero
      iex> Exception.message(error)
      "the divisor cannot be 0"
  """

  @type reason ::
          :tokenizing_failed
          | :token_parsing_failed
          | :cannot_compile_roll
          | :negative_dice
          | :divide_by_zero
          | :non_integer_modulo
          | :list_length_mismatch
          | :missing_variable
          | :invalid_variable
          | :arithmetic_error
          | :invalid_option
          | :invalid_modifier
          | :invalid_roll_key

  @type t :: %__MODULE__{reason: reason, details: any, message: String.t()}

  defexception [:reason, :details, :message]

  @impl true
  def exception(opts) do
    reason = Keyword.fetch!(opts, :reason)
    details = Keyword.get(opts, :details)
    message = Keyword.get_lazy(opts, :message, fn -> default_message(reason, details) end)
    %__MODULE__{reason: reason, details: details, message: message}
  end

  defp default_message(:tokenizing_failed, details),
    do: "could not tokenize the expression: #{inspect(details)}"

  defp default_message(:token_parsing_failed, details),
    do: "could not parse the expression: #{format_parse_error(details)}"

  defp default_message(:cannot_compile_roll, details),
    do: "cannot compile #{inspect(details)}; expected a string or parsed expression"

  defp default_message(:invalid_option, details),
    do: "invalid sigil option(s) #{inspect(details)}"

  defp default_message(:invalid_roll_key, details),
    do: "cache keys must be strings, got #{inspect(details)}"

  defp default_message(reason, nil), do: "#{reason}"
  defp default_message(reason, details), do: "#{reason}: #{inspect(details)}"

  # yecc errors are iolists such as ['syntax error before: ', ["x"]]
  defp format_parse_error(details) do
    IO.chardata_to_string(details)
  rescue
    _ -> inspect(details)
  end
end
