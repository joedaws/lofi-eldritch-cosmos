defmodule Cosmos.Metrics do
  @moduledoc """
  The application environment variable :monitor_metrics is "true" or "false" (strings).
  If true then metrics are collected, otherwise, they are not collected.
  The default is set to "true".
  """
  require Logger

  def get() do
    Logger.info("#{inspect(collect_metrics())}")
  end

  defp collect_metrics() do
    [
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count)
    ]
  end
end
