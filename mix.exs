defmodule Lens2.MixProject do
  use Mix.Project

  def project do
    [
      app: :lens2,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Lens 2",
      source_url: "https://github.com/marick/lens2",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flow_assertions, "~> 0.6", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:typedstruct, "~> 0.5.2", only: :test},
      {:typed_struct_lens, "~> 0.1.1", only: :test},
      {:bimap, "~> 1.3"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description do
    "A utility for working with nested data structures."
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Brian Marick"],
      links: %{"GitHub" => "https://github.com/marick/lens2"}
    ]
  end

  defp docs do
    [
      main: "rationale",
      extras: [
               "mostly_words/rationale.md",
               "mostly_words/are_lenses_for_you.md"
      ],
      groups_for_extras: [
        "Tutorial": Path.wildcard("mostly_words/tutorial/*.md"),
      ],
      assets: %{"mostly_words/pics" => "pics"},
    ]
  end
end
