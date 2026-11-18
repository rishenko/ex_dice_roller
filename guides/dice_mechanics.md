# Dice Mechanics

There are a large number of dice mechanics in use across video-games, text-based
games, tabletop games, role-playing games, and more. This guide shows how to
replicate various dice mechanics using ExDiceRoller. Where possible, the
examples show the use of both `ExDiceRoller.roll!/2` and the `~a` sigil, as
detailed in `ExDiceRoller.Sigil`.


## Relationship Matrix

The following relationship matrix shows how each of the dice mechanics can be combined with the others.

 MECHANIC    | ST   | K   | CKHL | M   | ED  | DLH | DABN | RR
------------ | ---- | --- | ---- | --- | --- | --- | ---- | ---
 **ST**      | -    | -   | x    | x   | x   | x   | -    | x
 **K**       | -    | -   | x    | x   | x   | x   | x    | x
 **CKHL**    | x    | x   | -    | x   | x   | x   | x    | x
 **M**       | x    | x   | x    | -   | x   | x   | x    | x
 **ED**      | x    | x   | x    | x   | -   | x   | x    | x
 **DLH**     | x    | x   | x    | x   | x   | -   | x    | x
 **DABN**    | -    | x   | x    | x   | x   | x   | -    | x
 **RR**      | x    | x   | x    | x   | x   | x   | x    | -

DABN filters individual dice only when the dice are kept (K); on a summed
total it filters the total itself.

Acronyms:
* ST: Roll and Sum Total
* K: Roll and Keep
* CKHL: Roll Multiple Dice, Compare and Keep Only the Highest/Lowest Values
* M: Roll Multiple Dice With Modifiers
* ED: Exploding Dice
* DLH: Roll Multiple Dice and Drop Lowest/Highest
* DABN: Roll Multiple Dice and Drop Any Number Above/Below a Specified Number
* RR: Reroll Dice


## Roll and Sum Total (ST)

A player needs to roll three six-sided dice (3d6) and total their amounts. Upon
rolling, they get a 3, 2, and a 6. They add each individual die together,
getting a final total of 11.

* Real World: Rolling 3d6 results in 3, 2, and 6, which add up to 11.
* ExDiceRoller: `ExDiceRoller.roll!("3d6")` returns any integer between `3` and `18`.
* Sigil: `~a/3d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll!("3d6")
11
iex> import ExDiceRoller.Sigil
iex> ~a/3d6/r
7
```

## Roll Multiple Dice With Modifiers (M)

A player needs to roll a skill die and add their trait modifier to it. They have a twelve-sided die (1d12) for their skill roll, and receive a +2 modifier for the roll. They roll an 11 and record the result. They then add 2 to the result for a final value of 13.

* Real World: Rolling 1d12 results in 11. 2 is added to 11 for a final result of 13.
* ExDiceRoller: `ExDiceRoller.roll!("1d12+2")` returns an integer between `3` and `14`.
* Sigil: `~a/1d12+2/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll!("1d12+2")
9
iex> import ExDiceRoller.Sigil
iex> ~a/1d12+2/r
5
```

A list of possible modifiers, in the form of math operators, can be found in `ExDiceRoller.Compilers.Math`.


## Roll and Keep (K)

A player needs to roll six ten-sided dice (6d10) at once, and keep the result of each die. Upon rolling, they get a 2, 1, 7, 10, 4, 4. They record each individual die result.

* Real World: Rolling 6d10 results in 2, 1, 7, 10, 4, and 4, all of which are saved.
* ExDiceRoller: `ExDiceRoller.roll!("6d10", opts: :keep)` returns a list of six integers where each integer is between 1 and 10, such as `[1, 10, 4, 2, 1, 6]`
* Sigil: `~a/6d10/k` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll!("6d10", opts: [:keep])
[4, 10, 8, 5, 10, 7]
iex> import ExDiceRoller.Sigil
ExDiceRoller.Sigil
iex> ~a/6d10/k
[9, 9, 4, 7, 3, 1]
```

More information about keeping dice can be found in `ExDiceRoller.Compilers.Roll`.


## Roll Multiple Dice, Compare and Keep Only the Highest/Lowest Values (CKHL)

A player needs to roll an eight-sided die (1d8) and a six-sided die (1d6) at once and keep the highest die roll. They roll a 7 and 4. Seven is the highest die, so they record that result.

* Real World: Rolling 1d8 and 1d6 results in 7 and 4. 7, being the highest, is kept.
* ExDiceRoller: `ExDiceRoller.roll!("1d8,1d6")` returns the higher of the two dice, a number between `1` and `8`.
* Sigil: `~a/1d8,1d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll!("1d8,1d6")
4
iex> import ExDiceRoller.Sigil
iex> ~a/1d8,1d6/r
7
iex> ExDiceRoller.roll!("2d8,2d6,2d10")
12
```

The exact same logic as above applies to keeping the lowest of all rolls.

* Real World: Rolling 1d8 and 1d6 results in 7 and 4. 4, being the lowest, is kept.
* ExDiceRoller: `ExDiceRoller.roll!("1d8,1d6", opts: [:lowest])` returns the lower of the two dice, a number between `1` and `6`.
* Sigil: `~a/1d8,1d6/rl` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll!("1d8,1d6", opts: [:lowest])
4
iex> import ExDiceRoller.Sigil
iex> ~a/1d8,1d6/rl
2
```

This can also be used when comparing rolls and single values:

```elixir
iex> ExDiceRoller.roll!("1d6,1d8,5")
7
iex> import ExDiceRoller.Sigil
iex> ~a/1d6,1d8,5/r
5
```

When all the dice are the same kind, the keep modifiers do the same job.
Rolling with advantage keeps the higher of 2d20 (`2d20kh`, or `2d20k`), and
disadvantage keeps the lower (`2d20kl`):

```elixir
iex> ExDiceRoller.roll!("2d20kh+5")
21
iex> import ExDiceRoller.Sigil
iex> ~a/2d20kl/r
6
```

More information about the comparison operator `,` can be found in `ExDiceRoller.Compilers.Separator`.


## Roll Multiple Dice and Drop the Lowest/Highest (DLH)

A player needs to roll four six-sided dice (4d6) and drop the lowest. The player rolls the dice and gets a 4, 5, 3, and 6. Three, being the lowest roll of the group, is dropped. The player is left with a 4, 5, and 6.

* Real World: Rolling 4d6 results in 4, 5, 3, and 6. Three is the lowest and is set aside. The only dice kept are 4, 5, and 6.
* ExDiceRoller: `ExDiceRoller.roll!("4d6dl1")` returns the total of the three highest dice, between `3` and `18`; `ExDiceRoller.roll!("4d6dl1", opts: :keep)` returns the three dice. `4d6kh3` does the same.
* Sigil: `~a/4d6dl1/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll!("4d6dl1")
15
iex> ExDiceRoller.roll!("4d6dl1", opts: :keep)
[4, 5, 6]
iex> ExDiceRoller.roll!("5d10dh2dl1", opts: :keep)
[3, 7]
iex> import ExDiceRoller.Sigil
iex> ~a/4d6kh3/r
12
```

The `drop_lowest: true`, `drop_highest: true`, and `drop_highest_lowest: true` filters also drop one die, but they apply to the final result and always return a list, so use them with `opts: :keep`:

```elixir
iex> ExDiceRoller.roll!("4d6", drop_lowest: true, opts: :keep)
[3, 3, 5]
iex> ExDiceRoller.roll!("xd6", drop_highest: true, x: [1, 1, 1])
[5, 1]
```

The keep and drop modifiers are described in `ExDiceRoller.Compilers.Roll`, and the filters in `ExDiceRoller.Filters`.


## Roll Multiple Dice and Drop Any Number Above/Below a Specified Number (DABN)

A player needs to roll eight six-sided dice (8d6), and only keep dice with values equal to or higher than 4. The player rolls the dice and gets a 3, 5, 4, 6, 5, 1, 1, 2. They set aside all dice that are below 4 and keep the rest. The player is left with 5, 4, 6, and 5.

* Real World: Rolling 8d6 results in 3, 5, 4, 6, 5, 1, 1, 2. All dice below 4 are dropped. The only dice kept are 5, 4, 6, and 5.
* ExDiceRoller: `ExDiceRoller.roll!("8d6", >=: 4,  opts: :keep)` returns a variable sized list of integers, filtering out any integers below `4`.
* Sigil: This feature is currently not implemented in the sigil.

```elixir
iex> ExDiceRoller.roll!("8d6", >=: 4,  opts: :keep)
[5, 5, 4, 6]
iex> ExDiceRoller.roll!("xd6", <=: 8,  x: [2, 2, 3, 2, 2, 3])
[7, 6, 6]
```

A list of possible filters can be found in `ExDiceRoller.Filters`.


## Exploding Dice (ED)

A player needs to roll a six-sided die (1d6). Should the result be a six, the player records it and rolls the die again. This is repeated until the player rolls something other than a six. When that happens, the player adds all of the die rolls together and records the final value.

* Real World: Rolling 1d6 results in 6. The next roll is also a 6. The final roll is a 3. All rolls are added together for a final result of 15.
* ExDiceRoller: `ExDiceRoller.roll!("1d6!")` or `ExDiceRoller.roll!("1d6", opts: :explode)` returns an integer of 1 or more; it is never a multiple of 6, since the last roll is never a 6.
* Sigil: `~a/1d6!/r` or `~a/1d6/e`

```elixir
iex> ExDiceRoller.roll!("1d6!")
16
iex> ExDiceRoller.roll!("1d6", opts: [:explode])
3
iex> import ExDiceRoller.Sigil
iex> ~a/1d6/e
10
```

The `!` modifier applies to one roll; the `:explode` option applies to every roll in the expression.


## Reroll Dice (RR)

A player rolls a twenty-sided die (1d20) but may reroll any 1. Some games reroll until the die is no longer a 1; others allow a single reroll and keep the second result even if it is another 1.

* Real World: Rolling 1d20 results in 1. The player rolls again and gets 14.
* ExDiceRoller: `ExDiceRoller.roll!("1d20r1")` rerolls until the die is not a 1, so it returns a number between `2` and `20`. `ExDiceRoller.roll!("1d20ro1")` rerolls once, so it can still return `1`.
* Sigil: `~a/1d20r1/r`

```elixir
iex> ExDiceRoller.roll!("1d20r1")
14
iex> ExDiceRoller.roll!("2d6ro<3", opts: :keep)
[5, 2]
iex> ExDiceRoller.roll!("4d6r1kh3")
14
```

Rerolls accept `=`, `<`, `>`, `<=`, and `>=` (`r<3` rerolls 1s and 2s). More information is in `ExDiceRoller.Compilers.Roll`.