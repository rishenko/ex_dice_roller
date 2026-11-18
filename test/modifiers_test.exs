defmodule ExDiceRoller.ModifiersTest do
  @moduledoc """
  Dice modifier syntax: keep/drop (`kh`, `kl`, `dh`, `dl`), rerolls (`r`,
  `ro`), explode (`!`), and case-insensitive `D`.

  Without rerolls, a modified roll draws the same random numbers as the plain
  roll, so most semantic tests roll both from the same seed and compute the
  expected result from the plain roll's dice.
  """
  use ExUnit.Case

  alias ExDiceRoller.Error

  defp parse(expr) do
    with {:ok, tokens} <- ExDiceRoller.tokenize(expr), do: ExDiceRoller.parse(tokens)
  end

  defp seeded(seed, expr, args) do
    :rand.seed(:exsss, seed)
    ExDiceRoller.roll!(expr, args)
  end

  defp seeds, do: for(i <- 1..200, do: {i, i * 7, 13})

  describe "syntax" do
    test "keep and drop, with counts defaulting to 1" do
      assert {:ok, {:roll, 4, 6, [{:keep, :highest, 3}]}} = parse("4d6kh3")
      assert {:ok, {:roll, 4, 6, [{:keep, :highest, 3}]}} = parse("4d6k3")
      assert {:ok, {:roll, 2, 20, [{:keep, :highest, 1}]}} = parse("2d20kh")
      assert {:ok, {:roll, 2, 20, [{:keep, :lowest, 1}]}} = parse("2d20kl")
      assert {:ok, {:roll, 4, 6, [{:drop, :lowest, 1}]}} = parse("4d6dl")
      assert {:ok, {:roll, 4, 6, [{:drop, :highest, 2}]}} = parse("4d6dh2")
    end

    test "rerolls and explode" do
      assert {:ok, {:roll, 1, 20, [{:reroll, :always, :==, 1}]}} = parse("1d20r1")
      assert {:ok, {:roll, 1, 20, [{:reroll, :once, :<, 3}]}} = parse("1d20ro<3")

      for {cmp, atom} <- [{"=", :==}, {"<", :<}, {">", :>}, {"<=", :<=}, {">=", :>=}] do
        assert {:ok, {:roll, 1, 6, [{:reroll, :always, ^atom, 2}]}} = parse("1d6r#{cmp}2")
      end

      assert {:ok, {:roll, 3, 6, [:explode]}} = parse("3d6!")
    end

    test "modifiers combine in the order written" do
      assert {:ok, {:roll, 4, 6, [{:reroll, :always, :==, 1}, :explode, {:keep, :highest, 3}]}} =
               parse("4d6r1!kh3")
    end

    test "uppercase works for D and every modifier" do
      assert {:ok, {:roll, 1, 6}} = parse("1D6")

      assert parse("4d6kh3r1ro2dl!") == parse("4D6KH3R1RO2DL!")
      assert parse("4d6kl1dh1") == parse("4D6Kl1dH1")
    end

    test "modifiers bind to the roll, after the roll and before other operators" do
      assert {:ok, {{:operator, ~c"+"}, {:roll, 4, 6, [{:keep, :highest, 3}]}, 2}} =
               parse("4d6kh3+2")

      assert {:ok, {{:operator, ~c"*"}, 2, {:roll, 4, 6, [{:keep, :highest, 3}]}}} =
               parse("2*4d6kh3")

      assert {:ok, {:roll, {:roll, 1, 4}, 6, [{:keep, :highest, 1}]}} = parse("1d4d6kh1")
      assert {:ok, {:roll, 1, {:roll, 2, 6, [{:keep, :highest, 1}]}}} = parse("1d(2d6kh1)")
      assert {:ok, {:roll, {:var, ~c"x"}, {:var, ~c"y"}, [{:keep, :highest, 2}]}} = parse("xdyk2")
    end

    test "letters outside modifier position are still variables" do
      assert {:ok, {{:operator, ~c"+"}, {:var, ~c"k"}, {:var, ~c"r"}}} = parse("k+r")
      assert {:ok, {:roll, 2, {:var, ~c"h"}}} = parse("2dh")
      assert {:ok, {:roll, {:var, ~c"k"}, {:var, ~c"l"}}} = parse("kdl")
      assert 7 == ExDiceRoller.roll!("k+r+h+l+o", k: 1, r: 1, h: 2, l: 2, o: 1)
    end

    test "invalid placements" do
      assert {:error, %Error{reason: :token_parsing_failed}} = parse("(1d6)kh1")
      assert {:error, %Error{reason: :token_parsing_failed}} = parse("1d6r")

      assert {:error, %Error{reason: :tokenizing_failed, details: {:illegal, ~c"!"}}} =
               parse("3!")

      assert {:error, %Error{reason: :tokenizing_failed, details: {:illegal, ~c">"}}} =
               parse("1d6!>3")
    end
  end

  describe "keep and drop" do
    test "keep the highest or lowest dice, in rolled order" do
      for seed <- seeds(), n <- [1, 4, 7], count <- [0, 1, 3, 9] do
        dice = seeded(seed, "#{n}d6", opts: :keep)

        assert seeded(seed, "#{n}d6kh#{count}", opts: :keep) == keep(dice, count, :highest)
        assert seeded(seed, "#{n}d6kl#{count}", opts: :keep) == keep(dice, count, :lowest)
        assert seeded(seed, "#{n}d6dh#{count}", opts: :keep) == drop(dice, count, :highest)
        assert seeded(seed, "#{n}d6dl#{count}", opts: :keep) == drop(dice, count, :lowest)
      end
    end

    test "without :keep the kept dice are summed" do
      for seed <- seeds() do
        kept = seeded(seed, "4d6kh3", opts: :keep)
        assert seeded(seed, "4d6kh3", []) == Enum.sum(kept)
        assert length(kept) == 3
      end
    end

    test "uppercase rolls the same dice" do
      for seed <- Enum.take(seeds(), 20) do
        assert seeded(seed, "4D6KH3", opts: :keep) == seeded(seed, "4d6kh3", opts: :keep)
      end
    end

    test "modifiers apply in order" do
      for seed <- Enum.take(seeds(), 50) do
        dice = seeded(seed, "6d6", opts: :keep)

        expected = dice |> keep(4, :highest) |> drop(1, :lowest)
        assert seeded(seed, "6d6kh4dl1", opts: :keep) == expected
      end
    end

    test "each die group from a list variable is kept separately" do
      for seed <- Enum.take(seeds(), 20) do
        [a, b] = seeded(seed, "xd6kh1", x: [3, 4], opts: :keep)
        assert a in 1..6 and b in 1..6
      end
    end

    test "no dice and zero-sided dice" do
      assert 0 == ExDiceRoller.roll!("0d6kh1")
      assert [] == ExDiceRoller.roll!("0d6kh1", opts: :keep)
      assert [0] == ExDiceRoller.roll!("9d0kh3", opts: :keep)
      assert 0 == ExDiceRoller.roll!("4d6kh0")
    end
  end

  describe "explode" do
    test "! rolls the same as the :explode option" do
      for seed <- seeds() do
        assert seeded(seed, "5d6!", opts: :keep) == seeded(seed, "5d6", opts: [:keep, :explode])
        assert seeded(seed, "3d4!", []) == seeded(seed, "3d4", opts: :explode)
      end
    end

    test "a one-sided die does not explode" do
      assert [1, 1] == ExDiceRoller.roll!("2d1!", opts: :keep)
    end
  end

  describe "rerolls" do
    test "r rerolls until the condition no longer matches" do
      :rand.seed(:exsss, {1, 2, 3})
      dice = for _ <- 1..2000, do: ExDiceRoller.roll!("1d6r<3")
      assert Enum.all?(dice, &(&1 in 3..6))
      assert Enum.uniq(dice) |> Enum.sort() == [3, 4, 5, 6]

      dice = for _ <- 1..2000, do: ExDiceRoller.roll!("1d20r1r>=19")
      assert Enum.all?(dice, &(&1 in 2..18))
    end

    test "ro rerolls once and keeps the second result" do
      :rand.seed(:exsss, {1, 2, 3})
      n = 20_000
      ones = Enum.count(1..n, fn _ -> ExDiceRoller.roll!("1d2ro1") == 1 end)
      # P(1) = 1/2 * 1/2
      assert_in_delta ones / n, 0.25, 0.02
    end

    test "ro draws a second die only when the first matches" do
      for seed <- seeds() do
        :rand.seed(:exsss, seed)
        first = :rand.uniform(6)
        second = :rand.uniform(6)
        expected = if first == 1, do: second, else: first
        assert seeded(seed, "1d6ro1", []) == expected
      end
    end

    test "rerolls apply to explosions too" do
      :rand.seed(:exsss, {4, 5, 6})
      dice = for _ <- 1..2000, do: ExDiceRoller.roll!("1d4r1!")
      # every draw is 2..4, and a 4 adds another draw, so 1 and 4 itself never total
      refute Enum.any?(dice, &(&1 in [1, 4]))
    end

    test "reroll conditions that can never stop raise :invalid_modifier" do
      for expr <- ["1d6r<7", "1d6r<=6", "1d1r1", "1d6r>0", "1d6r<3r>=3"] do
        assert {:error, %Error{reason: :invalid_modifier}} = ExDiceRoller.roll(expr), expr
      end

      assert {:error, %Error{reason: :invalid_modifier} = e} = ExDiceRoller.roll("1d6r<6!")
      assert e.message =~ "explode forever"
      assert {:ok, _} = ExDiceRoller.roll("1d6r<6")
      assert {:ok, _} = ExDiceRoller.roll("1d6r<5!")
    end
  end

  defp keep(dice, count, which) do
    chosen = ranked(dice, which) |> Enum.take(count) |> MapSet.new()
    for {v, i} <- Enum.with_index(dice), i in chosen, do: v
  end

  defp drop(dice, count, which) do
    dropped = ranked(dice, which) |> Enum.take(count) |> MapSet.new()
    for {v, i} <- Enum.with_index(dice), i not in dropped, do: v
  end

  # indexes from highest (or lowest) value; the sort is stable, so ties go to
  # the die rolled first
  defp ranked(dice, which) do
    dice
    |> Enum.with_index()
    |> Enum.sort_by(&elem(&1, 0), if(which == :highest, do: :desc, else: :asc))
    |> Enum.map(&elem(&1, 1))
  end
end
