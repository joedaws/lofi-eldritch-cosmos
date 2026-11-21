defmodule Eldritch.SimulationTest do
  use ExUnit.Case

  alias Eldritch.Being.Actions
  alias Eldritch.Entities

  setup do
    Eldritch.Genesis.reset()
    :ok
  end

  defp node!(attrs \\ %{}) do
    Eldritch.Node.Builder.build({:new, :node}, Map.merge(%{"resource_type" => "bone"}, attrs))
  end

  defp being!(attrs \\ %{}) do
    id = Eldritch.Being.Builder.build({:new, :being, :standard}, attrs)
    Eldritch.Genesis.flush()
    id
  end

  defp vals(id) do
    Eldritch.Genesis.flush()
    id |> Cosmos.Entity.Cache.server_process() |> Entities.values()
  end

  test "moving a being keeps node occupants consistent" do
    a = node!()
    b = node!()
    being = being!(%{"at_node" => a})

    assert MapSet.member?(vals(a)["occupants"], being)

    :ok = Actions.move_to_node(being, b)
    assert vals(being)["at_node"] == b
    refute MapSet.member?(vals(a)["occupants"], being)
    assert MapSet.member?(vals(b)["occupants"], being)
  end

  test "moving to an unknown node fails without side effects" do
    a = node!()
    being = being!(%{"at_node" => a})
    assert {:error, :unknown_node} = Actions.move_to_node(being, "no-such-node")
    assert vals(being)["at_node"] == a
  end

  test "unknown ids do not create phantom beings" do
    assert Eldritch.Being.fetch("no-such-being") == :error
    assert Cosmos.Entity.Cache.lookup("no-such-being") == nil
  end

  test "the beings query only lists beings" do
    node!()
    being = being!()
    assert Eldritch.query("beings") == %{"being_ids" => [being]}
  end

  test "landscape is connected and laid out on rings" do
    ids = Eldritch.Landscape.generate(rings: [4, 7])
    assert length(ids) == 12
    Eldritch.Genesis.flush()

    graph = Entities.node_map()
    assert Enum.all?(Map.values(graph), &is_map(&1["position"]))

    # breadth first search from any node reaches every node
    [start | _] = ids

    reached =
      Stream.iterate({[start], MapSet.new([start])}, fn {frontier, seen} ->
        next =
          frontier
          |> Enum.flat_map(&Enum.to_list(graph[&1]["neighbors"]))
          |> Enum.reject(&MapSet.member?(seen, &1))
          |> Enum.uniq()

        {next, Enum.reduce(next, seen, &MapSet.put(&2, &1))}
      end)
      |> Enum.find(fn {frontier, _} -> frontier == [] end)
      |> elem(1)

    assert MapSet.size(reached) == length(ids)
  end

  test "harvest depletes the node reserve and fills the inventory" do
    n = node!(%{"resource_yield" => 5, "reserve" => 7})
    being = being!(%{"at_node" => n})

    Eldritch.System.Harvest.update_components(Eldritch.System.Harvest)
    Eldritch.System.Harvest.update_components(Eldritch.System.Harvest)

    assert get_in(vals(being), ["inventory", "resources", "bone"]) == 7
    assert get_in(vals(n), ["reserve", "amount"]) == 0
  end

  test "hungry beings consume what they carry" do
    n = node!()
    being = being!(%{"at_node" => n, "ichor" => 20, "desire" => "blood"})
    Actions.give_resource(Cosmos.Entity.Cache.server_process(being), "bone", 5)
    Eldritch.Genesis.flush()

    Eldritch.System.Volition.update_components(Eldritch.System.Volition)

    v = vals(being)
    assert v["ichor"] == 20 + 3 * 3
    assert get_in(v, ["inventory", "resources", "bone"]) == 2
    assert get_in(v, ["volition", "intent"]) == "consume"
  end

  test "beings without ichor fade and leave their node" do
    n = node!()
    being = being!(%{"at_node" => n, "ichor" => 0})

    Eldritch.System.Volition.update_components(Eldritch.System.Volition)

    assert vals(being)["status"] == "faded"
    refute MapSet.member?(vals(n)["occupants"], being)
  end

  test "beings travel toward known nodes holding their desire" do
    a = node!(%{"resource_type" => "bone"})
    b = node!(%{"resource_type" => "bone"})
    c = node!(%{"resource_type" => "blood"})
    Eldritch.Node.Actions.connect_nodes(a, b)
    Eldritch.Node.Actions.connect_nodes(b, c)
    being = being!(%{"at_node" => a, "desire" => "blood"})

    Cosmos.Entity.Server.update_component(
      Cosmos.Entity.Cache.server_process(being),
      "observations",
      fn comp -> %{comp | value: %{"nodes" => %{c => "blood"}, "visited" => %{}}} end
    )

    Eldritch.Genesis.flush()
    Eldritch.System.Volition.update_components(Eldritch.System.Volition)
    assert vals(being)["at_node"] == b
    Eldritch.System.Volition.update_components(Eldritch.System.Volition)
    assert vals(being)["at_node"] == c
  end

  test "communion: beings meet, share knowledge and answer demands" do
    n = node!()
    giver = being!(%{"at_node" => n, "desire" => "bone"})
    receiver = being!(%{"at_node" => n, "desire" => "blood"})
    Actions.give_resource(Cosmos.Entity.Cache.server_process(giver), "blood", 5)

    Cosmos.Entity.Server.update_component(
      Cosmos.Entity.Cache.server_process(giver),
      "observations",
      fn comp -> %{comp | value: %{"nodes" => %{"far-away" => "obsidian"}, "visited" => %{}}} end
    )

    Eldritch.Genesis.flush()

    # demands are not made every time two beings meet
    Enum.reduce_while(1..30, nil, fn _, _ ->
      Eldritch.System.Communion.update_components(Eldritch.System.Communion)

      if get_in(vals(receiver), ["inventory", "resources", "blood"]),
        do: {:halt, :ok},
        else: {:cont, nil}
    end)

    g = vals(giver)
    r = vals(receiver)
    received = get_in(r, ["inventory", "resources", "blood"]) || 0
    assert received > 0
    assert received + (get_in(g, ["inventory", "resources", "blood"]) || 0) == 5
    assert r["bonds"][giver] > 0 and g["bonds"][receiver] > 0
    assert get_in(r, ["observations", "nodes", "far-away"]) == "obsidian"

    kinds = Eldritch.Chronicle.recent(50) |> Enum.map(& &1["kind"])
    assert "meet" in kinds and "gift" in kinds
  end

  test "spaced repetition: whisper, recall, promote and demote" do
    being = being!(%{"incantation" => %{"front" => "7 × 8", "back" => "56"}})
    pid = Cosmos.Entity.Cache.server_process(being)

    assert {:error, :not_awaiting, _} = Eldritch.Being.recall(being, "56")

    make_due = fn ->
      Cosmos.Entity.Server.update_component(pid, "incantation", fn comp ->
        %{comp | value: %{comp.value | "due_at" => 0}}
      end)

      Eldritch.System.Remind.update_components(Eldritch.System.Remind)
      assert get_in(vals(being), ["incantation", "awaiting"])
    end

    make_due.()
    ichor = vals(being)["ichor"]
    assert {:ok, %{"correct" => true, "box" => 2, "ichor_gain" => 15}} = Eldritch.Being.recall(being, " 56 ")
    assert vals(being)["ichor"] == ichor + 15

    make_due.()
    assert {:ok, %{"correct" => false, "box" => 1, "expected" => "56"}} = Eldritch.Being.recall(being, "54")
  end

  test "a correct recall calls a faded being back" do
    n = node!()
    being = being!(%{"at_node" => n, "ichor" => 0, "incantation" => %{"front" => "Breathe", "back" => ""}})
    Eldritch.System.Volition.update_components(Eldritch.System.Volition)
    assert vals(being)["status"] == "faded"

    pid = Cosmos.Entity.Cache.server_process(being)

    Cosmos.Entity.Server.update_component(pid, "incantation", fn comp ->
      %{comp | value: %{comp.value | "due_at" => 0}}
    end)

    Eldritch.System.Remind.update_components(Eldritch.System.Remind)
    assert {:ok, %{"correct" => true}} = Eldritch.Being.recall(being, "ok")

    v = vals(being)
    assert v["status"] == "alive"
    assert v["ichor"] > 0
    assert MapSet.member?(vals(n)["occupants"], being)
  end

  test "seeded worlds snapshot to JSON" do
    Eldritch.Genesis.seed(rings: [3, 5], beings: 4)
    world = Eldritch.World.snapshot()
    assert length(world["nodes"]) == 9
    assert length(world["beings"]) == 4
    assert is_binary(Poison.encode!(world))
  end

  test "the simulation runs every system and ticks" do
    Eldritch.Genesis.seed(rings: [3, 5], beings: 4)
    Eldritch.Simulation.set_tick_ms(100)
    Eldritch.Simulation.start()
    Process.sleep(700)
    Eldritch.Simulation.stop()

    assert Eldritch.Simulation.tick_count() > 2

    for system <- Eldritch.Simulation.systems() do
      assert %{cycles: cycles} = Cosmos.System.status(system)
      assert cycles > 0, "#{inspect(system)} never cycled"
    end
  end
end
