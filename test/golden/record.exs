# Re-records test/golden/results.tsv from the current code.
# Run with: MIX_ENV=test mix run test/golden/record.exs
# Only do this for an intentional behavior change, and review the diff.
lines = ExDiceRoller.Golden.run()
File.write!(ExDiceRoller.Golden.results_path(), Enum.join(lines, "\n") <> "\n")
IO.puts("wrote #{length(lines)} cases to #{ExDiceRoller.Golden.results_path()}")
