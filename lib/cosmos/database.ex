defmodule Cosmos.Database do
  use GenServer

  def start do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def store(key, data) do
    GenServer.cast(__MODULE__, {:store, key, data})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @impl true
  def init(_) do
    persist_dir = Cosmos.get_persist_dir()
    File.mkdir_p!(persist_dir)
    {:ok, nil}
  end

  @impl true
  def handle_cast({:store, key, data}, state) do
    key
    |> file_name()
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    data =
      case File.read(file_name(key)) do
        {:ok, contents} -> :erlang.binary_to_term(contents)
        _ -> nil
      end

    {:reply, data, state}
  end

  defp file_name(key) do
    persist_dir = Cosmos.get_persist_dir()
    Path.join(persist_dir, to_string(key))
  end
end
