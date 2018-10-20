defmodule ExDiceRoller.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_dice_roller,
      version: "0.5.0-alpha",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "ExDiceRoller",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
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
    "Adds simple or complex dice roll calculations to your application."
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
      {:excoveralls, "~> 0.10", only: [:test]},
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.18.0", only: :dev, runtime: false}
    ]
  end
end
