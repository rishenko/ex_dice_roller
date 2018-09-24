defmodule DiceRoller.MixProject do
  use Mix.Project

  def project do
    [
      app: :dice_roller,
      version: "0.2.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "DiceRoller",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def description do
    "Adds simple or complex dice roll calculations to your application."
  end

  def package do
    [
      maintainers: ["Kevin McAbee"],
      licenses: ["MIT"],
      homepage_url: "https://github.com/rishenko/dice_roller",
      source_url: "https://github.com/rishenko/dice_roller"
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
