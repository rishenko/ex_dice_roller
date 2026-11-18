# Used by "mix format"
locals_without_parens = [defroll: 2]

[
  inputs: ["mix.exs", "{bench,config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  # lets projects that depend on ex_dice_roller write `defroll name, "1d6"`
  # without parentheses: add `import_deps: [:ex_dice_roller]` to their
  # .formatter.exs
  export: [locals_without_parens: locals_without_parens]
]
