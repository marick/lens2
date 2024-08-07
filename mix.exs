defmodule Lens2.MixProject do
  use Mix.Project

  def project do
    [
      app: :lens2,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:typedstruct, "~> 0.5.2"},
      {:bimap, "~> 1.3"},
      {:private, "> 0.0.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]


  defp description do
    "A library for working with nested data structures."
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
               "mostly_words/for_access_novices.md",
               "mostly_words/are_lenses_for_you.md",
               "mostly_words/migrating.md",
               "mostly_words/tutorial01-pointers.md",
               "mostly_words/tutorial02-nested.md",
               "mostly_words/tutorial04-missing.md",
               "mostly_words/tutorial04-non-list.md",
               "mostly_words/tutorial06-information-hiding.md",
               "mostly_words/tutorial05-combining.md",
               "mostly_words/implementation01-intro.md",
               "mostly_words/implementation02-continuation-passing.md",
               "mostly_words/implementation02-get_all.md",
               "mostly_words/implementation03-update.md",
               "mostly_words/implementation04-get_and_update.md",
               "mostly_words/implementation05-access.md",
               "mostly_words/implementation06-into.md",
               "mostly_words/implementation07-const.md",
               "mostly_words/implementation08-some-makers.md",
               "mostly_words/draft_popping.md",
               "mostly_words/draft_into.md",
      ],
      groups_for_extras: [
        "Tutorial": Path.wildcard("mostly_words/tutorial??-*.md"),
        "Debugging Pipelines / Defining Makers": Path.wildcard("mostly_words/implementation??-*.md"),
        "Drafts": Path.wildcard("mostly_words/draft*.md")
      ],

      groups_for_modules: [
        "Lens Makers": ~r/Lens2.Lenses.*/
      ],
      assets: %{
        "mostly_words/pics" => "pics",
      },
      markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true},
      before_closing_head_tag: &before_closing_head_tag/1,
    ]
  end

  # Footnotes in Earmark markdown are badly/not styled without this kludge.

  defp before_closing_head_tag(:html) do
  """
  <style>
    a.reversefootnote {
      display: inline-block;
      text-indent: -9999px;
      line-height: 0;
    }

    a.reversefootnote:after {
      content: ' ↩'; /* or any other text you want */
      text-indent: 0;
      display: block;
      line-height: initial;
    }

    a.footnote {
      font-size: 0.7em;
      vertical-align: super;
    }
  </style>
  """
  end

  defp before_closing_head_tag(_), do: ""
end
