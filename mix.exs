defmodule ExDiceRoller.MixProject do
  use Mix.Project

  @version "1.0.0-rc.2"

  def project do
    [
      app: :ex_dice_roller,
      version: @version,
      elixir: "~> 1.15",
      compilers: [:leex, :yecc] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "ExDiceRoller",
      source_url: "https://github.com/rishenko/ex_dice_roller",
      test_coverage: [tool: ExCoveralls],
      docs: docs()
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def description do
    "Add a dice-rolling DSL with sigil support and reusable compiled functions to your application."
  end

  def package do
    [
      maintainers: ["Kevin McAbee"],
      licenses: ["Apache 2.0"],
      homepage_url: "https://github.com/rishenko/ex_dice_roller",
      source_url: "https://github.com/rishenko/ex_dice_roller",
      links: %{"GitHub" => "https://github.com/rishenko/ex_dice_roller"},
      files: ~w(lib coveralls.json src/*.xrl src/*.yrl .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.18", only: [:test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "overview",
      source_ref: "v#{@version}",
      source_url: "https://github.com/rishenko/ex_dice_roller",
      extra_section: "GUIDES",
      extras: doc_extras()
    ]
  end

  defp doc_extras do
    [
      "guides/overview.md",
      "guides/dice_mechanics.md"
    ]
  end
end
