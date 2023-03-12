defmodule Cosmos.Entity.BuilderTest do
  use ExUnit.Case

  test "build standard" do
    entity =
      Cosmos.Entity.Builder.build(:standard, %{
        "name" => "jorsa",
        "ichor" => 100,
        "orichalcum" => 33
      })

    # first component is name
    assert entity.components |> Map.get(1) |> Map.get(:name) == "name"
    assert entity.components |> Map.get(1) |> Map.get(:value) == "jorsa"

    assert Cosmos.Entity.components(entity, "ichor") |> Enum.at(0) |> Map.get(:value) == 100
    assert Cosmos.Entity.components(entity, "orichalcum") |> Enum.at(0) |> Map.get(:value) == 33
  end
end
