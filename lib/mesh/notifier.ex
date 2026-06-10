defmodule Mesh.Notifier do
  @moduledoc false

  alias Mesh.Store

  require Logger

  def notify(peer, status, opts \\ []) do
    if url = Application.fetch_env!(:mesh, :webhook_url) do
      body = %{content: content(peer, status, opts)}

      case Req.post(url, json: body, retry: false) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status}} ->
          Logger.error("webhook crashed :$ (HTTP #{status})")

        {:error, reason} ->
          Logger.error("webhook unreachable :$ (network error)\n\n#{inspect(reason)}")
      end
    end
  end

  defp content(peer, :up, opts) do
    case Keyword.get(opts, :downtime_since) do
      nil ->
        "🟢 `#{peer}` is reachable again from `#{Mesh.me()}`"

      since ->
        duration = format_duration(DateTime.diff(DateTime.utc_now(), since, :second))
        "🟢 `#{peer}` is reachable again from `#{Mesh.me()}` (was unreachable for #{duration})"
    end
  end

  defp content(peer, :down, _opts) do
    "🔴 `#{peer}` is unreachable from `#{Mesh.me()}`"
  end

  defp content(peer, :still_down, _opts) do
    duration = format_duration(DateTime.diff(DateTime.utc_now(), Store.get(peer).since, :second))
    "🟠 `#{peer}` is still unreachable from `#{Mesh.me()}` (#{duration})"
  end

  defp format_duration(seconds) do
    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      seconds < 86400 -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m"
      true -> "#{div(seconds, 86400)}d #{div(rem(seconds, 86400), 3600)}h"
    end
  end
end
