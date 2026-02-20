defmodule Polyjuice.MixProject do
  use Mix.Project

  def project do
    [
      app: :polyjuice,
      version: "0.2.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      config_path: "config/config.exs",
      source_url: "https://github.com/edisonywh/polyjuice"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "🧬 Embed polymorphic schemas in your Ecto schema"
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/edisonywh/polyjuice"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ecto, ">= 3.5.0"},
      {:ecto_sql, "~> 3.0", only: :test},
      {:ecto_sqlite3, "~> 0.9", only: :test},
      {:jason, "~> 1.4", only: :test}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
