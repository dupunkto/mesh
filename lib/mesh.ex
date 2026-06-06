defmodule Mesh do
  @readme Path.expand("../README.md", __DIR__)
  @external_resource @readme
  @moduledoc @readme
             |> File.read!()
             |> String.split("<!-- DOCS HERE -->")
             |> List.last()
             |> String.trim()

  @doc false
  @spec aggregator() :: String.t()
  def aggregator do
    Application.get_env(:mesh, :aggregator_url) || "https://mesh.dupunkto.org"
  end

  @doc false
  @spec me() :: String.t()
  def me do
    Application.get_env(:mesh, :node) || hostname()
  end

  defp hostname do
    {:ok, hostname} = :inet.gethostname()
    List.to_string(hostname)
  end
end
