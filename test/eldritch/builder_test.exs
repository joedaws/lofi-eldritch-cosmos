defmodule Cosmos.BuilderTest do
  use ExUnit.Case

  test "build standard" do
    Cosmos.ProcessRegistry.start_link()
    Cosmos.SystemRegistry.start_link()
    Cosmos.Database.start_link()
    Cosmos.Entity.Cache.start_link()

    being_id =
      Eldritch.Being.Builder.build(
        {:new, :being, :standard},
        %{
          "name" => "jorsa",
          "ichor" => 100,
          "orichalcum" => 33
        }
      )

    # first component is name
    entity_server = Cosmos.Entity.Cache.server_process(being_id)
    entity = Cosmos.Entity.Server.get(entity_server)
    assert entity.components |> Map.get(1) |> Map.get(:name) == "name"
    assert entity.components |> Map.get(1) |> Map.get(:value) == "jorsa"

    assert Cosmos.Entity.components(entity, "ichor") |> Enum.at(0) |> Map.get(:value) == 100
    assert Cosmos.Entity.components(entity, "orichalcum") |> Enum.at(0) |> Map.get(:value) == 33
  end
end
