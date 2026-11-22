defmodule LofiWeb.WorldChannel do
  @moduledoc """
  Pushes the cosmos to the page as it changes.

  `LofiWeb.WorldBroadcaster` builds one snapshot per tick for everyone; each
  channel tailors it to its viewer before pushing it as a `"world"` message.
  Joining replies with a full snapshot (with the recent chronicle).
  """
  use Phoenix.Channel

  @impl true
  def join("world", _params, socket) do
    Phoenix.PubSub.subscribe(Lofi.PubSub, LofiWeb.WorldBroadcaster.topic())
    LofiWeb.WorldBroadcaster.watch(self())
    {:ok, LofiWeb.WorldView.for_viewer(socket.assigns.user_id), socket}
  end

  @impl true
  def handle_info({:world, world}, socket) do
    push(socket, "world", LofiWeb.WorldView.personalise(world, socket.assigns.user_id))
    {:noreply, socket}
  end
end
