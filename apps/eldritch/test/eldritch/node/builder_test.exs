defmodule Eldritch.Node.BuilderTest do
  use ExUnit.Case

  test "build standard" do
    node_id =
      Eldritch.Node.Builder.build(
        {:new, :node},
        %{
          "name" => "lost moss valley"
        }
      )

    # first component is name
    entity_server = Cosmos.Entity.Cache.server_process(node_id)
    entity = Cosmos.Entity.Server.get(entity_server)
    assert entity.components |> Map.get(1) |> Map.get(:name) == "name"
    assert entity.components |> Map.get(1) |> Map.get(:value) == "lost moss valley"
  end
end
