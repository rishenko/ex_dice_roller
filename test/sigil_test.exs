defmodule ExDiceRoller.SigilTest do
  @moduledoc false

  use ExDiceRoller.Case
  doctest ExDiceRoller.Sigil
  import ExDiceRoller.Sigil

  setup do
    {:ok, _} = ExDiceRoller.start_cache()
    :ok
  end

  describe "using no options" do
    test "basic" do
      fun = ~a/1+1/
      assert is_function(fun)
      assert 2 == ExDiceRoller.execute!(fun)
    end

    test "rolls" do
      fun = ~a/1d20/
      assert is_function(fun)
      assert 9 == ExDiceRoller.execute!(fun)
    end

    test "keep" do
      [9, 20, 14, 16, 3] = ~a/5d20/rk
    end

    test "choose highest/lowest" do
      fun = ~a/5d1,6d1/
      assert is_function(fun)
      assert 6 == ExDiceRoller.execute!(fun)
      assert 6 == ~a/5d1,6d1/rh
      assert 5 == ~a/5d1,6d1/rl
      assert 5 == ~a/5d1,5d1/r
    end

    test "complex" do
      fun = ~a|1d20+(2d4)d(3d10)/5|
      assert is_function(fun)
      assert 17 == ExDiceRoller.execute!(fun)
    end

    test "variables" do
      fun = ~a/3d6+x-y/
      assert is_function(fun)
      assert 14 == ExDiceRoller.execute!(fun, x: 5, y: 2)
    end

    test "errors when using variables but missing values" do
      fun = ~a/3d6+x-y/
      assert is_function(fun)

      assert_raise(ExDiceRoller.Error, "no variable 'x' was found in the arguments", fn ->
        ExDiceRoller.execute!(fun)
      end)

      assert_raise(ExDiceRoller.Error, "no variable 'y' was found in the arguments", fn ->
        ExDiceRoller.execute!(fun, x: 5)
      end)

      assert_raise(ExDiceRoller.Error, "no variable 'x' was found in the arguments", fn ->
        ExDiceRoller.execute!(fun, y: 2)
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
      assert 27 == ~a|1d(5d4+3)+(2d6)d(5d4)/4-2|r
    end

    test "with exploding dice" do
      assert 5 = ~a/1d3/re
      assert 4 = ~a/1d3/re
      assert 2 = ~a/1d3/re
    end

    test "fails when using variables" do
      assert_raise(ExDiceRoller.Error, "no variable 'b' was found in the arguments", fn ->
        ~a/1d4+b/r
      end)
    end
  end

  describe "compile-time sigil" do
    test "a malformed expression or flag fails when the code compiles, not when it runs" do
      code = fn body ->
        """
        defmodule ExDiceRoller.SigilTest.Never do
          import ExDiceRoller.Sigil
          def never, do: #{body}
        end
        """
      end

      assert_raise ExDiceRoller.Error, ~r/invalid dice expression/, fn ->
        Code.compile_string(code.("~a/1d6+/"))
      end

      assert_raise ExDiceRoller.Error, ~r/invalid sigil option/, fn ->
        Code.compile_string(code.("~a/1d6/z"))
      end

      refute Code.ensure_loaded?(ExDiceRoller.SigilTest.Never)
    end

    test "the compiled function is built once and stored in :persistent_term" do
      {:ok, tokens} = ExDiceRoller.tokenize("3d7+19")
      {:ok, tree} = ExDiceRoller.parse(tokens)
      key = {ExDiceRoller.Sigil, tree}
      :persistent_term.erase(key)

      fun = ~a/3d7+19/
      assert :persistent_term.get(key) === fun
      assert ~a/3d7+19/ === fun
    end

    test "rolls the same as roll!/2 from the same seed" do
      for i <- 1..50 do
        :rand.seed(:exsss, {i, 2, 3})
        expected = ExDiceRoller.roll!("4d6kh3+1d8", opts: [:explode])
        :rand.seed(:exsss, {i, 2, 3})
        assert ~a/4d6kh3+1d8/re == expected
      end
    end

    test "an interpolated expression is parsed at run time" do
      n = 3
      assert [1, 1, 1] == ~a/#{n}d1/k
      assert 3 == ExDiceRoller.execute!(~a/#{n}d1/)

      bad = "+"

      assert_raise ExDiceRoller.Error, ~r/invalid dice expression "1d6\+"/, fn ->
        ~a/1d6#{bad}/r
      end
    end
  end
end
