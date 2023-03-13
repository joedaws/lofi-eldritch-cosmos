defmodule Cosmos.Entity.BuilderTest do
  use ExUnit.Case

  test "build standard" do
    Cosmos.ProcessRegistry.start_link()
    Cosmos.Database.start_link()
    Cosmos.Entity.Cache.start_link()

    entity_server =
      Cosmos.Entity.Builder.build(:standard, "jorsa", %{
        "name" => "jorsa",
        "ichor" => 100,
        "orichalcum" => 33
      })

    # first component is name
    entity = Cosmos.Entity.Server.get(entity_server)
    assert entity.components |> Map.get(1) |> Map.get(:name) == "name"
    assert entity.components |> Map.get(1) |> Map.get(:value) == "jorsa"

    assert Cosmos.Entity.components(entity, "ichor") |> Enum.at(0) |> Map.get(:value) == 100
    assert Cosmos.Entity.components(entity, "orichalcum") |> Enum.at(0) |> Map.get(:value) == 33
  end
end
