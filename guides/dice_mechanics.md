# Dice Mechanics

There are a large number of dice mechanics in use across video-games, text-based
games, tabletop games, role-playing games, and more. This guide shows how to
replicate various dice mechanics using ExDiceRoller. Where possible, the
examples show the use of both `ExDiceRoller.roll/3` and the `~a` sigil, as
detailed in `ExDiceRoller.Sigil`.

## Relationship Matrix

The following relationship matrix shows how each of the dice mechanics can be combined with the others.

 MECHANIC    | RST  | RK  | RMDK  | RMDM  | ED  
------------ | ---- | --- | ----- | ----- | --- 
 **RST**     | -    | x   | x     | x     | x   
 **RK**      | x    | -   | x     | x     | x   
 **RMDK**    | x    | x   | -     | x     | x   
 **RMDM**    | x    | x   | x     | -     | x   
 **ED**      | x    | x   | x     | x     | -  

Acronyms:
* RST: Roll and Sum Total
* RK: Roll and Keep
* RMDK: Roll Multiple Dice, Keep Only the Highest/Lowest
* RMDM: Roll Multiple Dice With Modifiers
* ED: Exploding Dice


## Roll and Sum Total (RST)

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


## Roll and Keep (RK)

A player needs to roll six ten-sided dice (6d10) at once, and keep the result of each die. Upon rolling, they get a 2, 1, 7, 10, 4, 4. They record each individual die result.

* Real World: Rolling 6d10 results in 2, 1, 7, 10, 4, and 4, all of which are saved.
* ExDiceRoller: `ExDiceRoller.roll("6d10", [], [:keep])` returns a list of six integers where each integer is between 1 and 10, such as `[1, 10, 4, 2, 1, 6]`
* Sigil: `~a/6d10/k` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("6d10", [], [:keep])
[4, 10, 8, 5, 10, 7]
iex> import ExDiceRoller.Sigil
ExDiceRoller.Sigil
iex> ~a/6d10/k
[9, 9, 4, 7, 3, 1]
```


## Roll Multiple Dice, Keep Only the Highest/Lowest (RMDK)

A player needs to roll and eight-sided die, a six-sided die at once and keep the highest die roll. They roll a 7 and 4. Seven is the highest die, so they record that result.

* Real World: Rolling 3d8 results in 7 and 4. 7, being the highest, is kept.
* ExDiceRoller: `ExDiceRoller.roll("1d8,1d6")` returns the highest roll out of the three dice where the result is any number between `1` and `8`.
* Sigil: `~a/1d8,1d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("1d8,1d6")
4
iex> import ExDiceRoller.Sigil
iex> ~a/1d8,1d6/r
7
```

The exact same logic as above applies to keeping the lowest of all rolls.

* Real World: Rolling 3d8 results in 7 and 4. 4, being the lowest, is kept.
* ExDiceRoller: `ExDiceRoller.roll("1d8,1d6")` returns the lowest roll out of the three dice where the result is any number between `1` and `8`.
* Sigil: `~a/1d8,1d6/r` returns the same as ExDiceRoller above.

```elixir
iex> ExDiceRoller.roll("1d8,1d6", [], [:lowest])
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


## Roll Multiple Dice With Modifiers (RMDM)

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

Note that any expression can be used as a modifier, whether it is adding, subtracting, multiplying, or other math operators, or even another dice roll.


## Exploding Dice (ED)

A player needs to roll a six-sided die. Should the result be a six, the player records it and rolls the die again. This is repeated until the player rolls something other than a six. When that happens, the player adds all of the die rolls together and records the final value.

* Real World: Rolling 1d6 results in 6. The next roll is also a 6. The final roll is a 3. All rolls are added together for a final result of 15.
* ExDiceRoller: `ExDiceRoller.roll("1d6", [], [:explode])` returns an integer between `1` and any multiple of `6` plus the final roll.
* Sigil: `~a/1d6/e`

```elixir
iex> ExDiceRoller.roll("1d6", [], [:explode])
16
iex> import ExDiceRoller.Sigil
iex> ~a/1d6/e
10
```