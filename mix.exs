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
      main: "readme",
      extras: ["README.md"],
      source_url_pattern: "https://github.com/marick/lens2/blob/master/%{path}#L%{line}"
    ]
  end


end
