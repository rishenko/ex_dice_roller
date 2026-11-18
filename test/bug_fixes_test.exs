defmodule ExDiceRoller.BugFixesTest do
  @moduledoc "Regression tests for bugs fixed after 1.0.0-rc.2."

  use ExDiceRoller.Case

  import ExDiceRoller.Sigil
  alias ExDiceRoller.Cache

  describe "dice counts and sides that round to 0" do
    test "a fractional count that rounds to 0 rolls no dice" do
      for _ <- 1..50, do: assert(0 == ExDiceRoller.roll("(1/3)d6"))
      assert [] == ExDiceRoller.roll("(1/3)d6", opts: :keep)
      assert 0 == ExDiceRoller.roll("0.0d6")
    end

    test "zero dice with :keep returns an empty list" do
      assert [] == ExDiceRoller.roll("0d6", opts: :keep)
      assert 0 == ExDiceRoller.roll("0d6")
    end

    test "zero-sided dice show 0, one entry per die when kept" do
      assert 0 == ExDiceRoller.roll("1d(1/3)")
      assert [0, 0, 0] == ExDiceRoller.roll("3d0", opts: :keep)
    end

    test "counts from variable lists are checked per element" do
      result = ExDiceRoller.roll("xd6", x: [0, 2], opts: :keep)
      assert length(result) == 2

      assert_raise ArgumentError, ~r/less than 0/, fn ->
        ExDiceRoller.roll("xd6", x: [1, -2])
      end
    end
  end

  describe "tokenizer errors" do
    test "errors after the first line are returned, not raised" do
      assert {:error, {:tokenizing_failed, {:illegal, ~c"$"}}} = ExDiceRoller.roll("1d6\n+$")
      assert {:error, {:tokenizing_failed, _}} = ExDiceRoller.compile("1d6\n\n+$")
    end
  end

  describe "cache" do
    test "an invalid expression returns an error and is not cached" do
      {:ok, _} = ExDiceRoller.start_cache()
      :ok = Cache.clear()
      assert {:error, {:token_parsing_failed, _}} = ExDiceRoller.roll("1d6+", cache: true)
      assert [] == Cache.all()
    end

    test "opts: [:cache] uses the cache" do
      {:ok, _} = ExDiceRoller.start_cache()
      :ok = Cache.clear()
      ExDiceRoller.roll("1d6+1", opts: [:cache])
      assert [{"1d6+1", _}] = Cache.all()
      ExDiceRoller.roll("1d4", opts: :cache)
      assert length(Cache.all()) == 2
    end

    test "starting the cache twice is a no-op" do
      assert {:ok, ExDiceRoller.Cache} = ExDiceRoller.start_cache()
      assert {:ok, ExDiceRoller.Cache} = ExDiceRoller.start_cache()
    end
  end

  describe "invalid expressions in variables and sigils" do
    test "a variable holding an invalid expression raises ArgumentError" do
      assert_raise ArgumentError, ~r/invalid expression "1d6\$" for variable 'x'/, fn ->
        ExDiceRoller.roll("1+x", x: "1d6$")
      end
    end

    test "the sigil raises ArgumentError for an invalid expression" do
      assert_raise ArgumentError, ~r/invalid dice expression "1d6\+"/, fn ->
        sigil_a("1d6+", [])
      end

      assert_raise ArgumentError, ~r/invalid dice expression/, fn -> sigil_a("1d6+", ~c"r") end
    end
  end

  describe "modulo" do
    test "accepts floats with whole-number values" do
      assert 1 == ExDiceRoller.roll("(6/2)%2")
      assert 2 == ExDiceRoller.roll("2^3%3")
    end

    test "still rejects fractional values" do
      assert_raise ArgumentError, "modulo operator only accepts integer values", fn ->
        ExDiceRoller.roll("2.5%2")
      end
    end
  end

  describe "list arithmetic" do
    test "two empty lists combine to an empty list" do
      assert [] == ExDiceRoller.roll("x+y", x: [], y: [])
      assert [] == ExDiceRoller.roll("(0d6)+(0d4)", opts: :keep)
    end

    test "equal-length lists still combine element by element" do
      assert [11, 22] == ExDiceRoller.roll("x+y", x: [1, 2], y: [10, 20])
    end
  end
end
