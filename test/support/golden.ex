defmodule ExDiceRoller.Golden do
  @moduledoc """
  Golden-master harness. Replays a fixed corpus of roll expressions under
  several option sets with fixed RNG seeds, and renders each case as one line
  of text. `test/golden/results.tsv` holds the lines recorded from the
  original 2018 code; `ExDiceRoller.GoldenTest` checks that the current code
  still produces them.

  Each line is `<expr index>/<option set index>`, the inspected expression,
  then three results:

  1. `ExDiceRoller.roll/2`
  2. `ExDiceRoller.roll/2` with `cache: true` (same seed)
  3. `ExDiceRoller.compile/1`, reduced to `:ok` or `:error`

  Exceptions are rendered as `RAISE <module>`. `ArgumentError` messages come
  from ExDiceRoller itself, so they are kept; other messages come from Elixir
  or OTP internals and vary between versions, so they are dropped.

  To re-record after an intentional behavior change, run
  `MIX_ENV=test mix run test/golden/record.exs` and review the diff.
  """

  @dir Path.expand("../golden", __DIR__)
  @expressions_path Path.join(@dir, "expressions.exs")
  @results_path Path.join(@dir, "results.tsv")

  # every single-letter variable except `d`, with values 1..5
  @vars for c <- ?a..?z, c != ?d, do: {List.to_atom([c]), rem(c, 5) + 1}

  @option_sets [
    [],
    [opts: :explode],
    [opts: :keep],
    [opts: [:keep, :lowest]],
    [opts: [:highest]],
    [opts: :keep, drop_lowest: true, >=: 2]
  ]

  def results_path, do: @results_path

  @spec expressions() :: [String.t()]
  def expressions do
    {exprs, _} = Code.eval_file(@expressions_path)
    exprs
  end

  @spec recorded() :: [String.t()]
  def recorded do
    @results_path |> File.read!() |> String.split("\n", trim: true)
  end

  @doc "Runs the whole corpus and returns one line per case."
  @spec run() :: [String.t()]
  def run do
    _ = ExDiceRoller.Cache.start_link()
    :ok = ExDiceRoller.Cache.clear()

    for {expr, i} <- Enum.with_index(expressions()),
        {opts, j} <- Enum.with_index(@option_sets) do
      args = @vars ++ opts
      :rand.seed(:exsss, {i, j, 7})
      direct = render(fn -> ExDiceRoller.roll(expr, args) end)
      :rand.seed(:exsss, {i, j, 7})
      cached = render(fn -> ExDiceRoller.roll(expr, args ++ [cache: true]) end)
      compiled = render(fn -> expr |> ExDiceRoller.compile() |> elem(0) end)
      Enum.join(["#{i}/#{j}", inspect(expr), direct, cached, compiled], "\t")
    end
  end

  defp render(fun) do
    inspect(fun.(), limit: :infinity)
  rescue
    e in ArgumentError -> "RAISE ArgumentError " <> Exception.message(e)
    e -> "RAISE " <> inspect(e.__struct__)
  end
end
