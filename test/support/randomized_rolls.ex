defmodule ExDiceRoller.RandomizedRolls do
  @moduledoc """
  Generates and executes randomized ExDiceRoller roll expressions via
  `ExDiceRoller.ExpressionBuilder.randomize/2`.
  """

  alias ExDiceRoller.{Compiler, ExpressionBuilder}

  @type error_keyword :: [err: any, expr: String.t(), var_values: Keyword.t(), stacktrace: list]

  @var_value_types [:number, :list, :expression, :function]
  @timeout_error %RuntimeError{message: "roll task timed out"}

  @doc """
  Generates and rolls `num_expressions` number of expressions, where each
  expression has a maximum nested depth of `max_depth`. Returns a list of
  `t:error_keyword/0`.

  A list of expected error messages can be passed in, preventing those errors
  from being returned in the final error list.
  """
  @spec run(integer, integer, list(String.t())) :: list(error_keyword)
  def run(num_expressions, max_depth, known_errors) do
    {:ok, pid} = Task.Supervisor.start_link()

    Enum.reduce(1..num_expressions, [], fn _, acc ->
      do_run(pid, max_depth, known_errors, acc)
    end)
  end

  @doc "Handles processing errors generated while executing dice roll expressions."
  @spec handle_error(any, list(String.t()), String.t(), Keyword.t(), list(any)) :: list(any)
  def handle_error(%{message: msg} = err, known_errors, expr, args, acc) do
    case msg in known_errors do
      true -> acc
      false -> [create_error_list(err, expr, args)] ++ acc
    end
  end

  def handle_error(err, _, expr, args, acc) do
    [create_error_list(err, expr, args)] ++ acc
  end

  defp do_run(pid, max_depth, known_errors, acc) do
    expr = ExpressionBuilder.randomize(Enum.random(1..max_depth), true)
    var_values = build_variable_values(expr, max_depth)
    args = var_values ++ [opts: options()] ++ filters()

    try do
      task = Task.Supervisor.async_nolink(pid, roll_func(expr, args), trap_exit: true)

      case Task.yield(task, 1000) || Task.shutdown(task) do
        {:ok, :ok} -> acc
        {:ok, err} -> handle_error(err, known_errors, expr, args, acc)
        nil -> handle_error(@timeout_error, known_errors, expr, args, acc)
      end
    rescue
      err -> handle_error(err, known_errors, expr, args, acc)
    end
  end

  # the roll function used in the async task
  @spec roll_func(String.t(), Keyword.t()) :: :ok | any
  defp roll_func(expr, args) do
    fn ->
      try do
        ExDiceRoller.roll(expr, args)
        :ok
      rescue
        err -> err
      end
    end
  end

  # randomly selects whether or not to use filters, and which to use
  @spec filters() :: Keyword.t()
  defp filters do
    case Enum.random(1..2) do
      1 ->
        []

      2 ->
        Enum.random([
          [>=: Enum.random(1..10)],
          [<=: Enum.random(1..10)],
          [=: Enum.random(1..10)],
          [!=: Enum.random(1..10)],
          [>: Enum.random(1..10)],
          [<: Enum.random(1..10)],
          [drop_highest: true],
          [drop_lowest: true],
          [drop_highest_lowest: true]
        ])
    end
  end

  # randomly selects whether or not to use options, and which to use
  @spec options() :: Keyword.t()
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

  @spec create_error_list(any, String.t(), Keyword.t()) :: Keyword.t()
  defp create_error_list(err, expr, args) do
    [err: err, expr: expr, args: args, stacktrace: System.stacktrace()]
  end

  @spec build_variable_values(String.t(), integer) :: Keyword.t()
  defp build_variable_values(expr, max_depth) do
    ~r/[aAbBcCe-zE-Z]/
    |> Regex.scan(expr)
    |> List.flatten()
    |> Enum.uniq()
    |> generate_var_values(max_depth - 1)
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
