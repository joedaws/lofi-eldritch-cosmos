defmodule Eldritch.OwnedTest do
  use ExUnit.Case

  alias Eldritch.Being.{Deck, Owned, Temperament}
  alias Eldritch.Entities

  setup do
    Eldritch.Genesis.reset()
    Eldritch.Landscape.generate(rings: [3, 5])
    Eldritch.Genesis.flush()
    :ok
  end

  defp vals(id) do
    Eldritch.Genesis.flush()
    id |> Cosmos.Entity.Cache.server_process() |> Entities.values()
  end

  defp make_due(id) do
    # let a freshly built being finish registering with its systems first
    Eldritch.Genesis.flush()

    Cosmos.Entity.Server.update_component(Cosmos.Entity.Cache.server_process(id), "deck", fn c ->
      %{c | value: %{"cards" => Enum.map(c.value["cards"], &%{&1 | "due_at" => 0})}}
    end)

    Eldritch.System.Remind.update_components(Eldritch.System.Remind)
    Eldritch.Genesis.flush()
  end

  test "each person summons exactly one being" do
    assert {:ok, id} =
             Owned.summon(1, %{
               "name" => "Gor Lop~Tome",
               "cards" => [%{"front" => "capital of Peru", "back" => "Lima"}],
               "temperament" => %{"generosity" => 90}
             })

    v = vals(id)
    assert v["name"] == "Gor Lop~Tome"
    assert Eldritch.Being.owner(v) == 1
    assert v["temperament"]["generosity"] == 90
    assert [%{"front" => "capital of Peru"}] = Deck.cards(v["deck"])
    assert Owned.being_of(1)["id"] == id
    assert Owned.summon(1, %{}) == {:error, :already_has_being}
    assert {:ok, _} = Owned.summon(2, %{})
  end

  test "summoning validates names, places and cards" do
    assert Owned.summon(3, %{"name" => String.duplicate("a", 40)}) == {:error, :name_too_long}
    assert Owned.summon(3, %{"at_node" => "nowhere"}) == {:error, :unknown_node}
    assert Owned.summon(3, %{"cards" => [%{"front" => ""}]}) == {:error, :empty_front}
  end

  test "temperament is clamped and merged" do
    {:ok, _} = Owned.summon(1, %{})
    assert {:ok, t} = Owned.set_temperament(1, %{"wanderlust" => 250, "sociability" => "10", "bogus" => 1})
    assert t == %{"generosity" => 50, "wanderlust" => 100, "sociability" => 10, "conformity" => 50}
    assert Owned.set_temperament(99, %{}) == {:error, :no_being}
  end

  test "the deck: add, rewrite, burn, and its limits" do
    {:ok, id} = Owned.summon(1, %{})
    assert {:ok, card} = Owned.add_card(1, "7 × 8", "56")
    assert {:ok, _} = Owned.update_card(1, card["id"], "7 × 9", "63")
    assert Enum.any?(Deck.cards(vals(id)["deck"]), &(&1["front"] == "7 × 9"))
    assert {:ok, _} = Owned.delete_card(1, card["id"])
    assert Owned.delete_card(1, card["id"]) == {:error, :no_card}
    assert Owned.add_card(1, String.duplicate("x", 201), "") == {:error, :too_long}

    for i <- 1..(Deck.max_cards() - 1), do: {:ok, _} = Owned.add_card(1, "card #{i}", "")
    assert Owned.add_card(1, "one too many", "") == {:error, :deck_full}
  end

  test "a deck whispers one card at a time" do
    {:ok, id} =
      Owned.summon(1, %{"cards" => [%{"front" => "a", "back" => "1"}, %{"front" => "b", "back" => "2"}]})

    make_due(id)
    deck = vals(id)["deck"]
    assert [%{"front" => "a"}] = Enum.filter(Deck.cards(deck), & &1["awaiting"])

    assert {:ok, %{"correct" => true}} = Eldritch.Being.recall(id, "1", 1)
    Eldritch.System.Remind.update_components(Eldritch.System.Remind)
    assert Deck.awaiting(vals(id)["deck"])["front"] == "b"
  end

  test "only the owner may answer an owned being; anyone signed in may answer the commons" do
    {:ok, id} = Owned.summon(1, %{"cards" => [%{"front" => "capital of Peru", "back" => "Lima"}]})
    make_due(id)

    assert Eldritch.Being.recall(id, "Lima", 2) == {:error, :not_yours}
    assert Eldritch.Being.recall(id, "Lima", nil) == {:error, :not_yours}
    assert {:ok, %{"correct" => true}} = Eldritch.Being.recall(id, " lima ", 1)

    commons = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"incantation" => %{"front" => "x", "back" => "y"}})
    make_due(commons)
    assert Eldritch.Being.recall(commons, "y", nil) == {:error, :not_yours}
    assert {:ok, _} = Eldritch.Being.recall(commons, "y", 2)
  end

  test "beckoning is rate limited for owners" do
    {:ok, id} = Owned.summon(1, %{})
    here = vals(id)["at_node"]
    [a, b | _] = Eldritch.query("nodes")["node_ids"] |> List.delete(here)

    assert Owned.beckon(1, a) == :ok
    assert vals(id)["at_node"] == a
    assert {:error, {:cooldown, left}} = Owned.beckon(1, b)
    assert left > 0
    assert Owned.beckon_wait(vals(id)) > 0
  end

  test "the world view hides an owner's cards from others, and the objet a until anxiety" do
    {:ok, id} = Owned.summon(1, %{"cards" => [%{"front" => "secret", "back" => "s"}]})
    view = fn viewer -> Enum.find(Eldritch.World.snapshot(viewer: viewer)["beings"], &(&1["id"] == id)) end

    mine = view.(1)
    assert mine["mine"] and mine["can_answer"]
    assert mine["incantation"]["front"] == "secret"

    theirs = view.(2)
    refute theirs["mine"] or theirs["can_answer"]
    assert theirs["incantation"]["front"] == nil
    assert view.(nil)["incantation"]["front"] == nil

    assert mine["psyche"]["objet_a"] == nil

    # anxiety reveals the cause of desire
    v = vals(id)
    a = v["psyche"]["objet_a"]
    Eldritch.Being.Actions.give_resource(Cosmos.Entity.Cache.server_process(id), a, 12)
    Eldritch.Genesis.flush()
    Eldritch.System.Volition.update_components(Eldritch.System.Volition)
    Eldritch.Genesis.flush()
    assert view.(1)["psyche"]["objet_a"] == a
  end

  test "a being without generosity never gives" do
    [n | _] = Eldritch.query("nodes")["node_ids"]
    holder = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"at_node" => n, "desire" => "bone", "temperament" => %{"generosity" => 0}})
    asker = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"at_node" => n, "desire" => "blood"})
    Eldritch.Being.Actions.give_resource(Cosmos.Entity.Cache.server_process(holder), "blood", 5)
    Eldritch.Genesis.flush()

    for _ <- 1..20, do: Eldritch.System.Communion.update_components(Eldritch.System.Communion)

    assert get_in(vals(holder), ["inventory", "resources", "blood"]) == 5
    assert get_in(vals(asker), ["inventory", "resources", "blood"]) == nil
  end

  test "temperament 50 is the commons default" do
    assert Temperament.new() == %{"generosity" => 50, "wanderlust" => 50, "sociability" => 50, "conformity" => 50}
    assert Temperament.factor(%{}, "generosity") == 1.0
  end

  test "beings saved with a single incantation get a deck when loaded" do
    id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{})
    pid = Cosmos.Entity.Cache.server_process(id)
    entity = Cosmos.Entity.Server.get(pid)

    # rewrite the being the way older versions stored it
    deck = Cosmos.Entity.component(entity, "deck")
    Cosmos.Entity.Server.delete_component(pid, deck.id)

    Cosmos.Entity.Server.add_component(
      pid,
      %Cosmos.Entity.Component{name: "incantation", system: Eldritch.System.Remind, value: %{"front" => "old", "back" => "card"}}
    )

    Eldritch.Genesis.flush()
    Eldritch.Being.Builder.ensure_standard(pid)
    v = vals(id)
    assert [%{"front" => "old", "back" => "card"}] = Deck.cards(v["deck"])
    refute Map.has_key?(v, "incantation")
    assert v["temperament"] == Temperament.new()
  end
end
