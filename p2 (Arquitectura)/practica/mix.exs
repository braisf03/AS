defmodule KahootClone.MixProject do
  use Mix.Project

  def project do
    [
      app: :kahoot_clone,
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "KahootClone",
      docs: [main: "KahootClone.CLI"]
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
