# Dice Mechanics

There are a large number of dice mechanics in use across video-games, text-based
games, tabletop games, role-playing games, and more. This guide shows how to
replicate various dice mechanics using ExDiceRoller. Where possible, the
examples show the use of both `ExDiceRoller.roll/2` and the `~a` sigil, as
detailed in `ExDiceRoller.Sigil`.


## Relationship Matrix

The following relationship matrix shows how each of the dice mechanics can be combined with the others.

 MECHANIC    | ST   | K   | CKHL | M   | ED  | DLH | DABN
------------ | ---- | --- | ---- | --- | --- | --- | ----
 **ST**      | -    | -   | x    | x   | x   | x   | x
 **K**       | -    | -   | x    | x   | x   | x   | x
 **CKHL**    | x    | x   | -    | x   | x   | x   | x
 **M**       | x    | x   | x    | -   | x   | x   | x
 **ED**      | x    | x   | x    | x   | -   | x   | x
 **DLH**     | x    | x   | x    | x   | x   | -   | x
 **DABN**    | x    | x   | x    | x   | x   | x   | -

Acronyms:
* ST: Roll and Sum Total
* K: Roll and Keep
* CKHL: Roll Multiple Dice, Compare and Keep Only the Highest/Lowest Values
* M: Roll Multiple Dice With Modifiers
* ED: Exploding Dice
* DLH: Roll Multiple Dice and Drop Lowest/Highest
* DABN: Roll Multiple Dice and Drop Any Number Above/Below a Specified Number


## Roll and Sum Total (ST)

A player needs to roll three six-sided dice (3d6) and total their amounts. Upon
rolling, they get a 3, 2, and a 6. They add each individual die together,
getting a final total of 11.

* Real World: Rolling 3d6 results in 3, 2, and 6, which add up to 11.
* ExDiceRoller: `ExDiceRoller.roll("3d6")` returns any integer between `3` and `18`.
* Sigil: `~a/3d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("3d6")
11
iex> import ExDiceRoller.Sigil
iex> ~a/3d6/r
7
```

## Roll Multiple Dice With Modifiers (M)

A player needs to roll a skill die and add their trait modifier to it. They have a twelve-sided die (1d12) for their skill roll, and receive a +2 modifier for the roll. They roll an 11 and record the result. They then add 2 to the result for a final value of 12.

* Real World: Rolling 1d12 results in 11. 2 is added to 11 for a final result of 13.
* ExDiceRoller: `ExDiceRoller.roll("1d12+2")` returns an integer between `3` and `14`.
* Sigil: `~a/1d12+2/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("1d12+2")
9
iex> import ExDiceRoller.Sigil
iex> ~a/1d12+2/r
5
```

A list of possible modifiers, in the form of math operators, can be found in `ExDiceRoller.Compilers.Math`.


## Roll and Keep (K)

A player needs to roll six ten-sided dice (6d10) at once, and keep the result of each die. Upon rolling, they get a 2, 1, 7, 10, 4, 4. They record each individual die result.

* Real World: Rolling 6d10 results in 2, 1, 7, 10, 4, and 4, all of which are saved.
* ExDiceRoller: `ExDiceRoller.roll("6d10", opts: :keep)` returns a list of six integers where each integer is between 1 and 10, such as `[1, 10, 4, 2, 1, 6]`
* Sigil: `~a/6d10/k` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("6d10", opts: [:keep])
[4, 10, 8, 5, 10, 7]
iex> import ExDiceRoller.Sigil
ExDiceRoller.Sigil
iex> ~a/6d10/k
[9, 9, 4, 7, 3, 1]
```

More information about keeping dice can be found in `ExDiceRoller.Compilers.Roll`.


## Roll Multiple Dice, Compare and Keep Only the Highest/Lowest Values (CKHL)

A player needs to roll an eight-sided die (1d8) and a six-sided die (1d6) at once and keep the highest die roll. They roll a 7 and 4. Seven is the highest die, so they record that result.

* Real World: Rolling 3d8 results in 7 and 4. 7, being the highest, is kept.
* ExDiceRoller: `ExDiceRoller.roll("1d8,1d6")` returns the highest roll out of the three dice where the result is any number between `1` and `8`.
* Sigil: `~a/1d8,1d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("1d8,1d6")
4
iex> import ExDiceRoller.Sigil
iex> ~a/1d8,1d6/r
7
iex> ExDiceRoller.roll("2d8,2d6,2d10")
12
```

The exact same logic as above applies to keeping the lowest of all rolls.

* Real World: Rolling 3d8 results in 7 and 4. 4, being the lowest, is kept.
* ExDiceRoller: `ExDiceRoller.roll("1d8,1d6")` returns the lowest roll out of the three dice where the result is any number between `1` and `8`.
* Sigil: `~a/1d8,1d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("1d8,1d6", opts: [:lowest])
4
iex> import ExDiceRoller.Sigil
iex> ~a/1d8,1d6/rl
2
```

This can also be used when comparing rolls and single values:

```elixir
iex> ExDiceRoller.roll("1d6,1d8,5")
7
iex> import ExDiceRoller.Sigil
iex> ~a/1d6,1d8,5/r
5
```

More information about the comparison operator `,` can found in `ExDiceRoller.Compilers.Separator`.


## Roll Multiple Dice and Drop the Lowest/Highest (DLH)

A player needs to roll four six-sided dice (4d6) and drop the lowest. The player rolls the dice and gets a 4, 5, 3, and 6. Three, being the lowest roll of the group, is dropped. The player is left with a 4, 5, and 6.

* Real World: Rolling 4d6 results in 4, 5, 3, and 6. Three is the lowest and is set aside. The only dice kept are 4, 5, and 6.
* ExDiceRoller: `ExDiceRoller.roll("4d6", drop_lowest: true, opts: :keep)` returns three integers between `1` and `6`.
* Sigil: This feature is currently not implemented in the sigil.

```elixir
iex> ExDiceRoller.roll("4d6", drop_lowest: true, :keep)
[3, 3, 5]
iex> ExDiceRoller.roll("xd6", drop_highest: true, x: [1, 1, 1])
[5, 1]
```

Note that any expression can be used as a modifier, whether it is adding, subtracting, multiplying, or other math operators, or even another dice roll.

A list of possible options can found in `ExDiceRoller.Filters`.


## Roll Multiple Dice and Drop Any Number Above/Below a Specified Number (DABN)

A player needs to roll eight six-sided dice (8d6), and only keep dice with values equal to or higher than 4. The player rolls the dice and gets a 3, 5, 7, 6, 5, 1, 1, 2. They set aside all dice that are below 4 and keep the rest. The player is left with 5, 7, 6, and 5.

* Real World: Rolling 8d6 results in 3, 5, 7, 6, 5, 1, 1, 2. All dice below 4 are dropped. The only dice kept are 5, 7, 6, and 5.
* ExDiceRoller: `ExDiceRoller.roll("8d6", >=: 4,  opts: :keep)` returns a variable sized list of integers, filtering out any integers below `4`.
* Sigil: This feature is currently not implemented in the sigil.

```elixir
iex> ExDiceRoller.roll("8d6", >=: 4,  opts: :keep)
[5, 5, 4, 6]
iex> ExDiceRoller.roll("xd6", <=: 8,  x: [2, 2, 3, 2, 2, 3])
[7, 6, 6]
```

A list of possible found filters can be found in `ExDiceRoller.Filters`.


## Exploding Dice (ED)

A player needs to roll a six-sided die (1d6). Should the result be a six, the player records it and rolls the die again. This is repeated until the player rolls something other than a six. When that happens, the player adds all of the die rolls together and records the final value.

* Real World: Rolling 1d6 results in 6. The next roll is also a 6. The final roll is a 3. All rolls are added together for a final result of 15.
* ExDiceRoller: `ExDiceRoller.roll("1d6", opts: :explode)` returns an integer between `1` and any multiple of `6` plus the final roll.
* Sigil: `~a/1d6/e`

```elixir
iex> ExDiceRoller.roll("1d6", opts: [:explode])
16
iex> import ExDiceRoller.Sigil
iex> ~a/1d6/e
10
```