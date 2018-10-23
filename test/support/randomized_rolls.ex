defmodule ExDiceRoller.RandomizedRolls do
  @moduledoc """
  Generates and executes randomized ExDiceRoller roll expressions via
  `ExDiceRoller.ExpressionBuilder.randomize/2`.
  """

  alias ExDiceRoller.{Compiler, ExpressionBuilder}

  @type error_keyword :: [err: any, expr: String.t(), var_values: Keyword.t(), stacktrace: list]

  @var_value_types [:number, :list, :expression, :function]

  @doc """
  Generates and rolls `num_expressions` number of expressions, where each
  expression has a maximum nested depth of `max_depth`. Returns a list of
  `t:error_keyword/0`.

  A list of expected error messages can be passed in, preventing those errors
  from being returned in the final error list.
  """
  @spec run(integer, integer, list(String.t())) :: list(error_keyword)
  def run(num_expressions, max_depth, acceptable_errors) do
    Enum.reduce(1..num_expressions, [], fn _, acc ->
      do_run(max_depth, acceptable_errors, acc)
    end)
  end

  def handle_error(
        %ArgumentError{message: message} = err,
        acceptable_errors,
        expr,
        args,
        acc
      ) do
    case message in acceptable_errors do
      true -> acc
      false -> [create_error_list(err, expr, args)] ++ acc
    end
  end

  def handle_error(err, _, expr, args, acc) do
    [create_error_list(err, expr, args)] ++ acc
  end

  defp do_run(max_depth, acceptable_errors, acc) do
    expr = ExpressionBuilder.randomize(Enum.random(1..max_depth), true)

    var_values =
      ~r/[abce-z]/
      |> Regex.scan(expr)
      |> List.flatten()
      |> generate_var_values(max_depth - 1)

    args = var_values ++ [opts: options()] ++ filters()

    try do
      ExDiceRoller.roll(expr, args)
      acc
    rescue
      err -> handle_error(err, acceptable_errors, expr, args, acc)
    end
  end

  defp filters do
    case Enum.random(1..2) do
      1 ->
        []

      2 ->
        Enum.random([
          [>=: Enum.random(1..10)],
          [<=: Enum.random(1..10)],
          [=: Enum.random(1..10)],
          [>: Enum.random(1..10)],
          [<: Enum.random(1..10)]
        ])
    end
  end

  defp options do
    case Enum.random(1..2) do
      1 ->
        []

      2 ->
        options = [:keep, :explode, :highest, :lowest]
        len = length(options)
        max = Enum.random(1..(len + 2))

        1..max
        |> Enum.map(fn _ -> Enum.random(options) end)
        |> Enum.uniq()
    end
  end

  defp create_error_list(err, expr, args) do
    [err: err, expr: expr, args: args, stacktrace: System.stacktrace()]
  end

  @spec generate_var_values(list(String.t()), integer) :: Keyword.t()
  defp generate_var_values(var_names, max_depth) do
    Enum.map(
      var_names,
      fn name ->
        key = String.to_atom(name)
        {key, do_generate_var_value(Enum.random(@var_value_types), max_depth)}
      end
    )
  end

  @spec do_generate_var_value(atom, integer) :: Compiler.compiled_val() | String.t()
  defp do_generate_var_value(_, n) when n <= 0 do
    do_generate_var_value(:number, 1)
  end

  defp do_generate_var_value(:number, _) do
    case Enum.random(1..2) do
      1 -> ExpressionBuilder.int()
      2 -> ExpressionBuilder.float()
    end
  end

  defp do_generate_var_value(:list, max_depth) do
    max = Enum.random(1..5)

    Enum.map(1..max, fn _ ->
      do_generate_var_value(Enum.random(@var_value_types), max_depth - 2)
    end)
  end

  defp do_generate_var_value(:expression, max_depth) do
    ExpressionBuilder.randomize(Enum.random(1..(max_depth - 1)), false)
  end

  defp do_generate_var_value(:function, max_depth) do
    :expression
    |> do_generate_var_value(max_depth - 1)
    |> ExDiceRoller.compile()
    |> elem(1)
  end
end
