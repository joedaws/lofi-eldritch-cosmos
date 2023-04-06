defmodule Cosmos.Metrics do
  @moduledoc """
  The application environment variable :monitor_metrics is "true" or "false" (strings).
  If true then metrics are collected, otherwise, they are not collected.
  The default is set to "true".
  """
  use Task
  require Logger

  def start_link(_arg), do: Task.start_link(&loop/0)

  def on do
    Application.put_env(:cosmos, :monitor_metrics, "true")
  end

  def off do
    Application.put_env(:cosmos, :monitor_metrics, "false")
  end

  defp loop() do
    Process.sleep(:timer.seconds(10))

    Logger.info("#{inspect(collect_metrics())}")

    if Application.get_env(:cosmos, :monitor_metrics, "true") == "true" do
      loop()
    end
  end

  defp collect_metrics() do
    [
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count)
    ]
  end
end
