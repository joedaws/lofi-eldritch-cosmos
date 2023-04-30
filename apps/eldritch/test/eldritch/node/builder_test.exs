defmodule Eldritch.Node.BuilderTest do
  use ExUnit.Case

  test "build standard with name" do
    node_id =
      Eldritch.Node.Builder.build(
        {:new, :node},
        %{
          "name" => "lost moss valley",
          "resource_type" => "bone",
          "resource_yield" => 10
        }
      )

    # first component is name
    entity_server = Cosmos.Entity.Cache.server_process(node_id)
    entity = Cosmos.Entity.Server.get(entity_server)
    assert Cosmos.Entity.component(entity, "name") |> Map.get(:name) == "name"
    assert Cosmos.Entity.component(entity, "name") |> Map.get(:value) == "lost moss valley"
    assert Cosmos.Entity.component(entity, "resource_type") |> Map.get(:value) == "bone"
    assert Cosmos.Entity.component(entity, "resource_yield") |> Map.get(:value) == 10
  end
end
