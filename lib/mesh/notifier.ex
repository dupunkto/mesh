defmodule Mesh.Notifier do
  @moduledoc false

  require Logger

  def notify(peer, status) do
    if url = Application.fetch_env!(:mesh, :webhook_url) do
      body = %{content: content(peer, status)}

      case Req.post(url, json: body, retry: false) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, %{status: status}} -> Logger.error("webhook crashed :$ (HTTP #{status})")
        {:error, reason} -> Logger.error("webhook unreachable :$ (network error)\n\n#{inspect(reason)}")
      end
    end
  end

  defp content(peer, :up), do: "`#{Mesh.me()}` -> `#{peer}` is **up**"
  defp content(peer, :down), do: "`#{Mesh.me()}` -> `#{peer}` is **down**"
end