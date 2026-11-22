defmodule LofiWeb.WorldChannelTest do
  # the cosmos is shared state, so these run one at a time
  use LofiWeb.ChannelCase, async: false

  import Lofi.AccountsFixtures

  alias LofiWeb.{UserSocket, WorldBroadcaster}

  setup do
    Eldritch.History.reset()
    Eldritch.Genesis.reset()
    Eldritch.Landscape.generate(rings: [2, 4])
    Eldritch.Genesis.flush()
    # the broadcaster reads display names from the accounts db
    Ecto.Adapters.SQL.Sandbox.allow(Lofi.Repo, self(), Process.whereis(WorldBroadcaster))
    _keeper = user_fixture()
    owner = user_fixture()
    {:ok, being} = Eldritch.Being.Owned.summon(owner.id, %{"cards" => [%{"front" => "secret", "back" => "s"}]})
    Eldritch.Genesis.flush()
    %{owner: owner, being: being}
  end

  defp being_in(world, id), do: Enum.find(world["beings"], &(&1["id"] == id))

  test "anyone may watch; an owner's cards stay hidden", %{being: being, owner: owner} do
    {:ok, world, _socket} = UserSocket |> socket(nil, %{user_id: nil}) |> subscribe_and_join(LofiWeb.WorldChannel, "world")

    assert length(world["nodes"]) == 7
    b = being_in(world, being)
    assert b["owner"] == owner.display_name
    refute b["mine"] or b["can_answer"]
    assert b["incantation"]["front"] == nil
    refute Map.has_key?(b, "owner_id")
  end

  test "the owner is pushed their own being, with its cards", %{being: being, owner: owner} do
    {:ok, world, _socket} =
      UserSocket |> socket(nil, %{user_id: owner.id}) |> subscribe_and_join(LofiWeb.WorldChannel, "world")

    b = being_in(world, being)
    assert b["mine"] and b["can_answer"]
    assert b["incantation"]["front"] == "secret"

    # one broadcast, tailored by each channel
    assert WorldBroadcaster.watchers() >= 1
    send(WorldBroadcaster, :broadcast)
    assert_push "world", pushed, 2_000
    assert being_in(pushed, being)["incantation"]["front"] == "secret"
    refute Enum.any?(pushed["beings"], &Map.has_key?(&1, "owner_id"))
  end

  test "a stranger's pushes never carry the owner's cards", %{being: being} do
    stranger = user_fixture()

    {:ok, _world, _socket} =
      UserSocket |> socket(nil, %{user_id: stranger.id}) |> subscribe_and_join(LofiWeb.WorldChannel, "world")

    send(WorldBroadcaster, :broadcast)
    assert_push "world", pushed, 2_000
    b = being_in(pushed, being)
    refute b["mine"] or b["can_answer"]
    assert b["incantation"]["front"] == nil
  end

  test "new chronicle events are pushed once" do
    {:ok, _world, _socket} = UserSocket |> socket(nil, %{user_id: nil}) |> subscribe_and_join(LofiWeb.WorldChannel, "world")
    Eldritch.Chronicle.record(:meet, "Something new happens.")
    Process.sleep(20)
    send(WorldBroadcaster, :broadcast)

    # the broadcaster's own timer pushes too: find the push carrying the event
    assert_receive_event = fn assert_receive_event ->
      assert_push "world", pushed, 2_000
      texts = Enum.map(pushed["events"], & &1["text"])
      if "Something new happens." in texts, do: :ok, else: assert_receive_event.(assert_receive_event)
    end

    assert_receive_event.(assert_receive_event)

    # and it is never sent again
    send(WorldBroadcaster, :broadcast)
    assert_push "world", later, 2_000
    refute Enum.any?(later["events"], &(&1["text"] == "Something new happens."))
  end

  test "the socket recognises the signed-in person from their session", %{owner: owner} do
    token = Lofi.Accounts.generate_user_session_token(owner)
    assert {:ok, socket} = connect(UserSocket, %{}, connect_info: %{session: %{"user_token" => token}})
    assert socket.assigns.user_id == owner.id

    assert {:ok, socket} = connect(UserSocket, %{}, connect_info: %{session: %{}})
    assert socket.assigns.user_id == nil
  end
end
