defmodule ElixirMoGen.MixProject do
  use Mix.Project

  @version "0.0.1"
  @scm_url "https://github.com/lastobelus/elixir_mo_gen"

  def project do
    [
      app: :elixir_mo_gen,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [
        maintainers: [
          "Michael Johnston"
        ],
        licenses: ["MIT"],
        links: %{"GitHub" => @scm_url},
        files: ~w(lib templates mix.exs README.md)
      ],
      source_url: @scm_url,
      description: """
      More generators for Elixir/Phoenix, intended to be installed globally as an archive.

      Provides:

      - `mix mo.gen.mod` task to add a module to a project along with an associated test,
      that is aware of Phoenix conventions.
      """
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    []
  end
end
