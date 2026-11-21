defmodule Eldritch.HistoryTest do
  use ExUnit.Case

  alias Eldritch.{Chronicle, History}
  alias Eldritch.Being.Owned

  setup do
    Eldritch.Genesis.reset()
    History.forget(1)
    History.forget(2)
    Eldritch.Landscape.generate(rings: [3, 5])
    Eldritch.Genesis.flush()
    :ok
  end

  defp make_due(id) do
    Eldritch.Genesis.flush()

    Cosmos.Entity.Server.update_component(Cosmos.Entity.Cache.server_process(id), "deck", fn c ->
      %{c | value: %{"cards" => Enum.map(c.value["cards"], &%{&1 | "due_at" => 0})}}
    end)

    Eldritch.System.Remind.update_components(Eldritch.System.Remind)
    Eldritch.Genesis.flush()
  end

  defp restart_chronicle() do
    History.sync()
    :ok = Supervisor.terminate_child(Eldritch.Supervisor, Chronicle)
    {:ok, _} = Supervisor.restart_child(Eldritch.Supervisor, Chronicle)
  end

  test "the chronicle survives a restart and keeps counting" do
    Chronicle.record(:meet, "A meets B.", %{"beings" => ["a", "b"]})
    Chronicle.record(:gift, "B gifts A.", %{"beings" => ["b", "a"]})
    Process.sleep(50)
    [%{"seq" => last} | _] = Chronicle.recent(1)

    restart_chronicle()

    assert [%{"text" => "B gifts A.", "seq" => ^last}, %{"text" => "A meets B."} | _] =
             Chronicle.recent(5)

    Chronicle.record(:meet, "C meets D.")
    Process.sleep(50)
    assert [%{"seq" => next} | _] = Chronicle.recent(1)
    assert next == last + 1
  end

  test "events can be found by the beings they involve" do
    Chronicle.record(:gift, "X gifts Y.", %{"beings" => ["x", "y"]})
    Chronicle.record(:meet, "Z alone.", %{"beings" => ["z"]})
    Process.sleep(50)
    assert [%{"text" => "X gifts Y."}] = History.being_events("y")
  end

  test "unmaking the cosmos forgets the chronicle but not people's study records" do
    {:ok, id} = Owned.summon(1, %{})
    Chronicle.record(:meet, "Before the end.")
    Eldritch.Genesis.reset()
    assert History.recent_chronicle(10) |> Enum.all?(&(&1["text"] != "Before the end."))
    assert [%{"kind" => "summoned", "being_id" => ^id}] = History.interactions(1)
  end

  test "a person's actions are recorded, newest first" do
    {:ok, id} =
      Owned.summon(1, %{
        "name" => "Gor Lop~Tome",
        "cards" => [%{"front" => "capital of Peru", "back" => "Lima"}]
      })

    {:ok, card} = Owned.add_card(1, "7 × 8", "56")
    {:ok, _} = Owned.update_card(1, card["id"], "7 × 9", "63")
    {:ok, _} = Owned.delete_card(1, card["id"])
    {:ok, _} = Owned.set_temperament(1, %{"generosity" => 80})
    here = Eldritch.Entities.values(Cosmos.Entity.Cache.server_process(id))["at_node"]
    :ok = Owned.beckon(1, Eldritch.query("nodes")["node_ids"] |> List.delete(here) |> hd())

    make_due(id)
    {:ok, _} = Eldritch.Being.recall(id, "Cusco", 1)

    kinds = History.interactions(1) |> Enum.map(& &1["kind"])

    assert kinds == ~w(answer beckon temperament card_burned card_rewritten card_added summoned)

    [answer | _] = History.interactions(1)
    assert answer["being_id"] == id

    assert %{
             "front" => "capital of Peru",
             "expected" => "Lima",
             "answer" => "Cusco",
             "correct" => false,
             "box_before" => 1,
             "box_after" => 1
           } = answer["data"]

    [_, _, temperament | _] = History.interactions(1)
    assert temperament["data"]["before"]["generosity"] == 50
    assert temperament["data"]["after"]["generosity"] == 80

    # paging
    [newest] = History.interactions(1, limit: 1)
    assert [%{"kind" => "beckon"}] = History.interactions(1, limit: 1, before: newest["id"])

    # nobody else sees them
    assert History.interactions(2) == []
  end

  test "answers to the commons are part of the answerer's record; the replay's are not" do
    commons =
      Eldritch.Being.Builder.build({:new, :being, :standard}, %{
        "incantation" => %{"front" => "d/dx e^x", "back" => "e^x"}
      })

    make_due(commons)
    {:ok, %{"correct" => true}} = Eldritch.Being.recall(commons, "e^x", 2)

    assert [%{"kind" => "answer", "being_id" => ^commons, "data" => %{"correct" => true}}] =
             History.interactions(2)

    make_due(commons)
    Eldritch.Being.recall(commons, "e^x")
    assert length(History.interactions(2)) == 1
  end

  test "the export holds a person's interactions and their being's events, in time order" do
    {:ok, id} = Owned.summon(1, %{"name" => "Exported One"})
    {:ok, _} = Owned.add_card(1, "front", "back")
    Process.sleep(5)
    Chronicle.record(:gift, "Someone gifts Exported One.", %{"beings" => ["someone", id]})
    Chronicle.record(:meet, "Unrelated.", %{"beings" => ["q"]})
    Process.sleep(50)

    records = History.export(1)
    assert Enum.map(records, & &1["at"]) == Enum.sort(Enum.map(records, & &1["at"]))

    texts = for %{"type" => "event", "text" => t} <- records, do: t
    assert "Someone gifts Exported One." in texts
    refute "Unrelated." in texts
    assert Enum.any?(texts, &(&1 =~ "Exported One is summoned"))

    kinds = for %{"type" => "interaction", "kind" => k} <- records, do: k
    assert kinds == ["summoned", "card_added"]
    assert History.export(2) == []
  end
end
