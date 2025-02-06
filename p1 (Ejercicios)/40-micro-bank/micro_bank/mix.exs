defmodule MicroBank.MixProject do
  use Mix.Project

  def project do
    [
      app: :micro_bank,
      version: "1.0.0",
      start_permanent: Mix.env() == :prod
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger] #Los logs del supervisor los gestiona logger
    ]
  end

end
