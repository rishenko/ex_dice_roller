# Changelog

## v1.0.0-rc.1

* Documentation changes
  * added CONTRIBUTING.md for contribution guidelines
  * added cache configure to README
  * updated package description

## v1.0.0-rc.0

* Architectural Changes
  * consolidated dice rolling calls across the library, moving:
    * from `roll.(args, options)`where args are a Keyword, and options a list
      of atoms
    * to `roll.(args)` where args is a Keyword with an `opts: [] | :atom`
      argument
  * modified yecc script to:
    * return numbers as numbers and not `{:digit, String.t()}` tuples
    * return strings as strings and not charlists

* Enhancements
  * added float as possible value in expressions and variable values
  * consolidated improved list comprehension code to
    `ExDiceRoller.ListComprehension`
  * added lists as possible variable values
  * added a randomized expression builder (with variable expression depth) and
    roll tester for testing large numbers of expression permutations
    * this led to finding various edge case bugs and their subsequent fixes
  * added final result list filtering via `ExDiceRoller.Filters`
    * allows dropping highest/lowest/both rolls from dice rolls with multiple
      values
    * filtering values that are above/below a numerical threshold
  * overhauled and improved documentation across all modules and README, as well
    as adding _Dice Mechanics_ and _Overview_ guides to documentation

* Bugfixes
  * numerous major and minor fixes that came out of automated large-volume
    randomized roll testing and new features

## v0.5.0-alpha

* Enhancements
  * adds modulo `%` and exponent `^` support
  * adds `,` to dice rolls, allowing for choosing highest/lowest of the values
    on either side
  * adds `h` and `l` to sigil to allow selection or highest or lowest of
    calculated values on either side of `,`
  * adds `:keep` option to retain the result of each die roll
  * adds list comprehension rules for dice rolls utilizing `:keep`
  * major refactoring of `ExDiceRoller.Compiler`, extracting logic into modules
    found under ExDiceRoller.Compilers.*
  * additional documentation and doctests across the board

## v0.4.0-alpha

* Enhancements
  * added a new sigil `~a` in `ExDiceRoller.Sigil` for compiling functions
    and/or performing rolls
  * added exploding dice logic to the dice roller and sigil
  * added optional caching support `ExDiceRoller.Cache` for compiled dice rolls
    generated during runtime
  * added `ExDiceRoller.Compiler.fun_info/1` to inspect the compiled function
    hierarchy, closure values, and relationships of a compiled dice roll
  * a significant increase in documentation and doctests, which led to further
    minor fixes/adjustments
    * compiled functions can now be passed as values for variables
* Bugfixes
  * dice roll invocations now consistently return integers as the final value,
    instead of `ExDiceRoller.execute/3` potentially returning a float


## v0.3.0-alpha

* Enhancements
  * adds variables to dice roll expressions
  * includes refactoring of tokenizing and parsing code to their own modules
  * adds `ExDiceRoller.Compiler.fun_info/1` which details the tree of functions
    and values in a compiled dice roll
  * added TravisCI and coveralls.io integration
* Bugfixes
  * corrected issues with math operator calculations


## v0.2.0-alpha

Contains all basic features. Includes full testing coverage. Though it should be
fine for production, will continue keeping it alpha and vetting any potential
edge cases.