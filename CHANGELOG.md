# Changelog

## Unreleased

* Bug fixes
  * Dice counts that round to 0 roll no dice. `(1/3)d6` used to roll 2 dice,
    because `1..0` counts down. The same goes for `0.0` and for 0 or negative
    counts inside variable lists, which are now checked per element.
  * Side counts that round to 0 give 0 instead of crashing in `:rand`.
  * With `:keep`, zero dice return `[]`, and N zero-sided dice return N zeros
    (one entry per die).
  * Adding or comparing two empty lists returns `[]` instead of raising
    `ArithmeticError`. List pairing also uses `Enum.zip_with/3` now, so it is
    no longer O(n²).
  * Tokenizer errors after the first line of input are returned as
    `{:error, {:tokenizing_failed, _}}` instead of raising `WithClauseError`.
  * `roll/2` with `cache: true` returns the parse error for an invalid
    expression instead of raising `FunctionClauseError`.
  * `opts: [:cache]`, as shown in the docs, now uses the cache (before, only
    `cache: true` did).
  * An invalid expression in a variable value, or in the `~a` sigil, raises an
    `ArgumentError` that names the expression, instead of a `MatchError`.
  * `%` accepts floats with whole-number values, such as the result of `6/2`.
  * Calling `start_cache/1` again while the table exists is a no-op instead of
    raising.

* Build and tooling
  * Requires Elixir 1.15+ (tested on 1.15 to 1.18, OTP 26 and 27).
  * Updated dev/test dependencies (credo 1.7, ex_doc 0.34, excoveralls 0.18);
    the old versions no longer compile on current OTP.
  * Replaced Travis CI with GitHub Actions.
  * Replaced `Mix.Config` with `Config`, and declared the leex and yecc
    compilers explicitly.
  * The cache table name is read with `Application.compile_env/3` and now
    defaults to `ExDiceRoller.Cache`, so a project using the library no
    longer has to set `:cache_table` itself.
* Compatibility fixes (no change in roll behavior)
  * Division and modulo by `-0.0` raise "the divisor cannot be 0" again.
    OTP 27 stopped matching `-0.0` against a `0.0` pattern.
  * The missing-variable error message is back to `'x'`; newer Elixir
    versions printed it as `~c"x"`.
  * Charlists in code and docs use the `~c` sigil.
  * `Compiler.fun_info/1` docs note that function names and child order
    depend on the OTP release.


## v1.0.0-rc.2

* Enhancements
  * Replaced Enum.random/1 calls with erlang's rand:uniform/1, greatly
    increasing speed for equations with dice rolls.
  * Fixed an issue with exponent operator precedence.

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