defmodule Cosmos.EntityTest do
  use ExUnit.Case
  doctest Cosmos

  test "Create new Entity" do
    entity = Cosmos.Entity.new()
    assert entity.id != nil
  end

  test "components" do
    entity = Cosmos.Entity.new()
    comp1 = Cosmos.Entity.Component.new("name", :static, "jorsa")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    entity = Cosmos.Entity.add_component(entity, comp1) |> Cosmos.Entity.add_component(comp2)

    assert length(Cosmos.Entity.components(entity)) == 2
    assert Cosmos.Entity.components(entity, "name") == [Map.put(comp1, :id, 1)]
    assert Cosmos.Entity.components(entity, :temporal_decay) == [Map.put(comp2, :id, 2)]
    assert Cosmos.Entity.components(entity, 1) == [Map.put(comp1, :id, 1)]

    # when removing components, we should ensure that the auto_component ids are
    # handled correctly
    assert Map.get(Cosmos.Entity.delete_component(entity, 1).components, 1) == %{comp2 | id: 1}
    assert Cosmos.Entity.delete_component(entity, 1).auto_component_id == 2
  end
end
