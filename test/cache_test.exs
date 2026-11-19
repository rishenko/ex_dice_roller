defmodule ExDiceRoller.CacheTest do
  @moduledoc false

  use ExDiceRoller.Case
  doctest ExDiceRoller.Cache

  alias ExDiceRoller.Cache

  test "the default cache is running when the application starts" do
    cache = Application.fetch_env!(:ex_dice_roller, :cache_table)
    assert is_pid(Process.whereis(cache))
    assert :ets.whereis(cache) != :undefined
    assert {:ok, ^cache} = ExDiceRoller.start_cache()
  end

  test "starting with name" do
    pid = start_supervised!({Cache, name: CacheTest})
    assert Process.whereis(CacheTest) == pid
    assert [] == Cache.all(CacheTest)
  end

  test "start_link/1 accepts a bare name" do
    {:ok, pid} = Cache.start_link(CacheTest)
    assert {:error, {:already_started, ^pid}} = Cache.start_link(name: CacheTest)
    GenServer.stop(pid)
  end

  test "put" do
    start_supervised!({Cache, name: CacheTest})
    roll_1 = "1d6"
    {:ok, fun_1} = ExDiceRoller.compile(roll_1)
    :ok = Cache.put(CacheTest, roll_1, fun_1)
    {:ok, ^fun_1} = Cache.obtain(CacheTest, roll_1)
  end

  test "obtain" do
    start_supervised!({Cache, name: CacheTest})
    {:ok, fun} = Cache.obtain(CacheTest, "1d6")
    assert is_function(fun)
  end

  test "errors on obtain" do
    start_supervised!({Cache, name: CacheTest})
    {:error, _} = Cache.obtain(CacheTest, "1&")
    {:error, _} = Cache.obtain(CacheTest, :not_a_string)
  end

  test "all" do
    start_supervised!({Cache, name: CacheTest})
    roll_1 = "1d6"
    roll_2 = "1d8+10-5d8"
    {:ok, fun_1} = Cache.obtain(CacheTest, roll_1)
    {:ok, fun_2} = Cache.obtain(CacheTest, roll_2)
    {:ok, ^fun_1} = Cache.obtain(CacheTest, roll_1)

    funs = Cache.all(CacheTest)
    assert length(funs) == 2
    assert {^roll_1, ^fun_1} = Enum.find(funs, &(roll_1 == elem(&1, 0)))
    assert {^roll_2, ^fun_2} = Enum.find(funs, &(roll_2 == elem(&1, 0)))
  end

  test "clear" do
    start_supervised!({Cache, name: CacheTest})
    {:ok, _} = Cache.obtain(CacheTest, "1d6")
    {:ok, _} = Cache.obtain(CacheTest, "1d8+10-5d8")

    assert 2 == CacheTest |> Cache.all() |> length()
    :ok = Cache.clear(CacheTest)
    assert 0 == CacheTest |> Cache.all() |> length()
  end

  test "delete" do
    start_supervised!({Cache, name: CacheTest})
    roll_1 = "1d6"
    roll_2 = "1d4+110-5d8 + 1d4/5"
    {:ok, _} = Cache.obtain(CacheTest, roll_1)
    {:ok, _} = Cache.obtain(CacheTest, roll_2)

    assert 2 == CacheTest |> Cache.all() |> length()
    :ok = Cache.delete(CacheTest, roll_1)
    assert 1 == CacheTest |> Cache.all() |> length()
    {:ok, _} = Cache.obtain(CacheTest, roll_1)
    assert 2 == CacheTest |> Cache.all() |> length()
  end

  test "delete with no cache named" do
    :ok = Cache.clear()
    roll_1 = "1d6"
    roll_2 = "1d4+110-5d8 + 1d4/5"
    {:ok, _} = Cache.obtain(roll_1)
    {:ok, _} = Cache.obtain(roll_2)

    assert 2 == Cache.all() |> length()
    :ok = Cache.delete(roll_1)
    assert 1 == Cache.all() |> length()
    {:ok, _} = Cache.obtain(roll_1)
    assert 2 == Cache.all() |> length()
  end

  test "delete errors with bad rollstring" do
    start_supervised!({Cache, name: CacheTest})

    {:error, %ExDiceRoller.Error{reason: :invalid_roll_key, details: :not_a_roll_string}} =
      Cache.delete(CacheTest, :not_a_roll_string)
  end

  describe "ownership" do
    test "a cache outlives the process that started it" do
      name = :cache_ownership_test
      on_exit(fn -> stop_cache(name) end)

      task =
        Task.async(fn ->
          {:ok, ^name} = ExDiceRoller.start_cache(name)
          {:ok, _} = Cache.obtain(name, "1d6")
        end)

      Task.await(task)
      refute Process.alive?(task.pid)
      assert [{"1d6", _}] = Cache.all(name)
    end

    test "start_cache/1 is idempotent and keeps the entries" do
      name = :cache_idempotent_test
      on_exit(fn -> stop_cache(name) end)
      {:ok, ^name} = ExDiceRoller.start_cache(name)
      {:ok, _} = Cache.obtain(name, "1d6")
      {:ok, ^name} = ExDiceRoller.start_cache(name)
      assert [{"1d6", _}] = Cache.all(name)
    end

    test "a crashed cache is restarted empty" do
      name = :cache_restart_test
      on_exit(fn -> stop_cache(name) end)
      {:ok, ^name} = ExDiceRoller.start_cache(name)
      {:ok, _} = Cache.obtain(name, "1d6")
      pid = Process.whereis(name)
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      new_pid = wait_for_restart(name, pid)
      assert new_pid != pid
      assert [] == Cache.all(name)
      assert {:ok, _} = Cache.obtain(name, "1d6")
      assert [{"1d6", _}] = Cache.all(name)
    end

    test "rolls with cache: true work with no setup" do
      :ok = Cache.clear()
      assert {:ok, 3} = ExDiceRoller.roll("1+2", cache: true)
      assert [{"1+2", _}] = Cache.all()
    end
  end

  defp stop_cache(name) do
    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(ExDiceRoller.CacheSupervisor, pid)
    end
  end

  defp wait_for_restart(name, old_pid, tries \\ 50) do
    case Process.whereis(name) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ when tries > 0 ->
        Process.sleep(10)
        wait_for_restart(name, old_pid, tries - 1)
    end
  end

  describe "string variables with cache: true" do
    setup do
      Cache.clear()
      :ok
    end

    @exprs ["1d20+x", "xdy", "x,y", "(x+y)d4kh1", "x*y-1"]
    @arg_sets [
      [x: "1d6", y: "2d4!"],
      [x: ["1d4", "3"], y: "1/3"],
      [x: "2d6kh1", y: ["1d4", "1d2"]],
      [x: "1d6", y: "1d8", opts: [:keep]],
      [x: "4d6dl1", y: 3, opts: [:explode, :lowest]]
    ]

    test "give the same results and draws as without the cache" do
      for expr <- @exprs, args <- @arg_sets, cache <- [[cache: true], [opts: [:cache]]] do
        fun = ExDiceRoller.compile!(expr)
        cached_args = merge_cache(args, cache)

        for seed <- 1..3 do
          expected = outcome(fn -> fun.(args) end, seed)
          # twice: the first call fills the cache, the second reads it
          assert outcome(fn -> fun.(cached_args) end, seed) == expected
          assert outcome(fn -> fun.(cached_args) end, seed) == expected

          assert outcome(fn -> ExDiceRoller.roll(expr, cached_args) end, seed) ==
                   outcome(fn -> ExDiceRoller.roll(expr, args) end, seed)
        end
      end
    end

    test "are cached only when asked" do
      {:ok, _} = ExDiceRoller.roll("1d20+x", x: "1d6")
      {:ok, _} = ExDiceRoller.compile!("1d20+x") |> ExDiceRoller.execute(x: "1d6")
      assert [] = :ets.lookup(ExDiceRoller.Cache, {:variable, "1d6"})
    end

    test "are stored apart from expressions, and cleared with them" do
      {:ok, _} = ExDiceRoller.roll("1d20+x", x: "1d6", cache: true)

      assert [{"1d20+x", _}] = Cache.all()
      assert [{_, _}] = :ets.lookup(ExDiceRoller.Cache, {:variable, "1d6"})

      Cache.clear()
      assert [] = :ets.lookup(ExDiceRoller.Cache, {:variable, "1d6"})
    end

    test "an invalid string raises the same error and is not cached" do
      fun = ExDiceRoller.compile!("1+x")
      plain = assert_raise ExDiceRoller.Error, fn -> fun.(x: "1d") end
      cached = assert_raise ExDiceRoller.Error, fn -> fun.(x: "1d", cache: true) end

      assert cached == plain
      assert cached.reason == :invalid_variable
      assert [] = :ets.lookup(ExDiceRoller.Cache, {:variable, "1d"})
    end

    defp merge_cache(args, cache: true), do: args ++ [cache: true]

    defp merge_cache(args, opts: [:cache]) do
      Keyword.update(args, :opts, [:cache], &[:cache | List.wrap(&1)])
    end

    defp outcome(fun, seed) do
      :rand.seed(:exsss, {seed, 4, 4})

      result =
        try do
          fun.()
        rescue
          e -> {:raise, e}
        end

      {result, :rand.export_seed()}
    end
  end
end
