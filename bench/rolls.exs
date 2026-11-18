# Times the main ways of rolling. Run from the project root with:
#
#     MIX_ENV=prod mix run bench/rolls.exs
#
# Each case runs in a fresh process: 1,000 warm-up calls, then 7 timed batches
# with no results kept. It prints the median batch in nanoseconds per call,
# then roll throughput on one process and on one process per scheduler.
import ExDiceRoller.Sigil

defmodule ExDiceRoller.Bench.Rolls do
  import ExDiceRoller.Roller
  defroll d20, "1d20+5"
  defroll d20x, "1d20+x"
  defroll kh3, "4d6kh3"
  defroll complex, "(1d4)d(6*y)-(2/3+1dx)+4d6kh3"
end

defmodule ExDiceRoller.Bench do
  def loop(_f, 0), do: :ok

  def loop(f, n) do
    f.()
    loop(f, n - 1)
  end

  def time(label, n, setup) do
    task =
      Task.async(fn ->
        f = setup.()
        loop(f, 1_000)
        for _ <- 1..7, do: elem(:timer.tc(fn -> loop(f, n) end), 0) * 1000 / n
      end)

    times = task |> Task.await(:infinity) |> Enum.sort()
    IO.puts("#{String.pad_trailing(label, 40)} #{round(Enum.at(times, 3))} ns")
  end

  def throughput(label, fun, procs, per \\ 2_000_000) do
    {us, _} =
      :timer.tc(fn ->
        1..procs
        |> Enum.map(fn _ -> Task.async(fn -> loop(fn -> fun.([]) end, per) end) end)
        |> Enum.each(&Task.await(&1, :infinity))
      end)

    rate = procs * per / (us / 1_000_000) / 1_000_000

    IO.puts(
      "#{String.pad_trailing("#{label}, #{procs} process(es)", 40)} #{Float.round(rate, 1)} M rolls/s"
    )
  end
end

alias ExDiceRoller.Bench
n = 200_000
complex = "(1d4)d(6*y)-(2/3+1dx)+4d6kh3"

IO.puts("Per call:")
Bench.time(":rand.uniform(20) + 5 (baseline)", n, fn -> fn -> :rand.uniform(20) + 5 end end)

Bench.time("compiled 1d20+5, fun.([])", n, fn ->
  f = ExDiceRoller.compile!("1d20+5")
  fn -> f.([]) end
end)

Bench.time("compiled 1d20+5, execute!/2", n, fn ->
  f = ExDiceRoller.compile!("1d20+5")
  fn -> ExDiceRoller.execute!(f) end
end)

Bench.time("defroll 1d20+5, d20()", n, fn -> fn -> ExDiceRoller.Bench.Rolls.d20() end end)
Bench.time("defroll 1d20+x, d20x(x: 5)", n, fn -> fn -> ExDiceRoller.Bench.Rolls.d20x(x: 5) end end)

Bench.time("~a/1d20+5/r", n, fn -> fn -> ~a/1d20+5/r end end)

Bench.time("roll!(\"1d20+5\", cache: true)", n, fn ->
  fn -> ExDiceRoller.roll!("1d20+5", cache: true) end
end)

Bench.time("roll!(\"1d20+5\")", n, fn -> fn -> ExDiceRoller.roll!("1d20+5") end end)

Bench.time("compiled 4d6kh3", n, fn ->
  f = ExDiceRoller.compile!("4d6kh3")
  fn -> f.([]) end
end)

Bench.time("defroll 4d6kh3, kh3()", n, fn -> fn -> ExDiceRoller.Bench.Rolls.kh3() end end)

Bench.time("complex: compile/1", 20_000, fn -> fn -> ExDiceRoller.compile(complex) end end)

Bench.time("complex: compiled, fun.(x: 4, y: 3)", 20_000, fn ->
  f = ExDiceRoller.compile!(complex)
  fn -> f.(x: 4, y: 3) end
end)

Bench.time("complex: defroll, complex(x: 4, y: 3)", 20_000, fn ->
  fn -> ExDiceRoller.Bench.Rolls.complex(x: 4, y: 3) end
end)

Bench.time("complex: roll(cache: true)", 20_000, fn ->
  fn -> ExDiceRoller.roll(complex, x: 4, y: 3, cache: true) end
end)

IO.puts("\nThroughput:")
schedulers = System.schedulers_online()

for expr <- ["1d20+5", "4d6kh3"], procs <- Enum.uniq([1, schedulers]) do
  Bench.throughput(expr, ExDiceRoller.compile!(expr), procs)
end

for procs <- Enum.uniq([1, schedulers]) do
  Bench.throughput("defroll 1d20+5", fn _ -> ExDiceRoller.Bench.Rolls.d20() end, procs)
end
