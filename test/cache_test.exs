defmodule ExDiceRoller.CacheTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Cache

  alias ExDiceRoller.Cache

  setup do
    :rand.seed(:exsplus, {5, 7, 13})
    :ok
  end

  test "starting with no name" do
    cache = Application.fetch_env!(:ex_dice_roller, :cache_table)
    {:ok, ^cache} = Cache.start_link()
  end

  test "starting with name" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
  end

  test "put" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
    roll_1 = "1d6"
    {:ok, fun_1} = ExDiceRoller.compile(roll_1)
    :ok = Cache.put(CacheTest, roll_1, fun_1)
    ^fun_1 = Cache.obtain(CacheTest, roll_1)
  end

  test "obtain" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
    fun = Cache.obtain(CacheTest, "1d6")
    assert is_function(fun)
  end

  test "errors on obtain" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
    {:error, _} = Cache.obtain(CacheTest, "1&")
    {:error, _} = Cache.obtain(CacheTest, :not_a_string)
  end

  test "all" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
    roll_1 = "1d6"
    roll_2 = "1d8+10-5d8"
    fun_1 = Cache.obtain(CacheTest, roll_1)
    fun_2 = Cache.obtain(CacheTest, roll_2)
    ^fun_1 = Cache.obtain(CacheTest, roll_1)

    funs = Cache.all(CacheTest)
    assert length(funs) == 2
    assert {^roll_1, ^fun_1} = Enum.find(funs, &(roll_1 == elem(&1, 0)))
    assert {^roll_2, ^fun_2} = Enum.find(funs, &(roll_2 == elem(&1, 0)))
  end

  test "clear" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
    _ = Cache.obtain(CacheTest, "1d6")
    _ = Cache.obtain(CacheTest, "1d8+10-5d8")

    assert 2 == CacheTest |> Cache.all() |> length()
    :ok = Cache.clear(CacheTest)
    assert 0 == CacheTest |> Cache.all() |> length()
  end

  test "delete" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)
    roll_1 = "1d6"
    roll_2 = "1d4+110-5d8 + 1d4/5"
    _ = Cache.obtain(CacheTest, roll_1)
    _ = Cache.obtain(CacheTest, roll_2)

    assert 2 == CacheTest |> Cache.all() |> length()
    :ok = Cache.delete(CacheTest, roll_1)
    assert 1 == CacheTest |> Cache.all() |> length()
    _ = Cache.obtain(CacheTest, roll_1)
    assert 2 == CacheTest |> Cache.all() |> length()
  end

  test "delete with no cache named" do
    {:ok, Cache} = Cache.start_link()
    roll_1 = "1d6"
    roll_2 = "1d4+110-5d8 + 1d4/5"
    _ = Cache.obtain(roll_1)
    _ = Cache.obtain(roll_2)

    assert 2 == Cache.all() |> length()
    :ok = Cache.delete(roll_1)
    assert 1 == Cache.all() |> length()
    _ = Cache.obtain(roll_1)
    assert 2 == Cache.all() |> length()
  end

  test "delete errors with bad rollstring" do
    {:ok, CacheTest} = Cache.start_link(CacheTest)

    {:error, {:invalid_roll_key, :not_a_roll_string}} =
      Cache.delete(CacheTest, :not_a_roll_string)
  end
end
