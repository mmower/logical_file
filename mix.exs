defmodule LogicalFile.MixProject do
  use Mix.Project

  @name "LogicalFile"
  @version "1.0.0"
  @source_url "http://www.apache.org/licenses/LICENSE-2.0"
  @description """
  An Elixir library for working with logical files that appear as a contiguous
  text but are represented by one or more sections representing backing files.
  """

  def project do
    [
      app: :logical_file,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      name: @name,
      source_url: @source_url,
      description: @description,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application, do: []

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: :dev}
    ]
  end

  def package() do
    [
      maintainers: ["Matt Mower"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
