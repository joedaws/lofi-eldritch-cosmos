defmodule Eldritch.Node.NameGenerator do
  use GenServer, restart: :permanent
  require Logger

  def start_link([]) do
    name_list = Eldritch.Node.Name.all_names_list()
    GenServer.start_link(__MODULE__, name_list, name: __MODULE__)
  end

  def next() do
    GenServer.call(__MODULE__, :next)
  end

  @impl true
  def init(name_list) do
    Logger.info("starting node name generator")
    {:ok, {name_list, 0}}
  end

  @impl true
  def handle_call(:next, _from, {name_list, auto_idx}) do
    name = Enum.at(name_list, auto_idx)

    {:reply, name, {name_list, rem(auto_idx + 1, length(name_list))}}
  end
end
