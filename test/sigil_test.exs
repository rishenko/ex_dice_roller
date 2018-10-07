defmodule ExDiceRoller.SigilTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExDiceRoller.Sigil
  import ExDiceRoller.Sigil
  alias ExDiceRoller.Cache

  setup do
    # This is called to make doctests predictable.
    :rand.seed(:exsplus, {5, 7, 13})
    {:ok, _} = Cache.start_link()
    :ok
  end

  describe "using no options" do
    test "basic" do
      fun = ~a/1+1/
      assert is_function(fun)
      assert 2 == ExDiceRoller.execute(fun)
    end

    test "rolls" do
      fun = ~a/1d20/
      assert is_function(fun)
      assert 9 == ExDiceRoller.execute(fun)
    end

    test "complex" do
      fun = ~a|1d20+(2d4)d(3d10)/5|
      assert is_function(fun)
      assert 17.2 == ExDiceRoller.execute(fun)
    end

    test "variables" do
      fun = ~a/3d6+x-y/
      assert is_function(fun)
      assert 14 == ExDiceRoller.execute(fun, x: 5, y: 2)
    end

    test "errors when using variables but missing values" do
      fun = ~a/3d6+x-y/
      assert is_function(fun)

      assert_raise(ArgumentError, "no variable 'x' was found in the arguments", fn ->
        ExDiceRoller.execute(fun)
      end)

      assert_raise(ArgumentError, "no variable 'y' was found in the arguments", fn ->
        ExDiceRoller.execute(fun, x: 5)
      end)

      assert_raise(ArgumentError, "no variable 'x' was found in the arguments", fn ->
        ExDiceRoller.execute(fun, y: 2)
      end)
    end
  end

  describe "executing rolls with option `r`" do
    test "basic" do
      assert 2 == ~a/1+1/r
    end

    test "roll" do
      assert 12 == ~a/1d10+3/r
    end

    test "complex" do
      assert 27.25 == ~a|1d(5d4+3)+(2d6)d(5d4)/4-2|r
    end

    test "with exploding dice" do
      assert 5 = ~a/1d3/re
      assert 4 = ~a/1d3/re
      assert 2 = ~a/1d3/re
    end

    test "fails when using variables" do
      assert_raise(ArgumentError, "no variable 'b' was found in the arguments", fn ->
        ~a/1d4+b/r
      end)
    end
  end
end
