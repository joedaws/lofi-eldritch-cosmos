defmodule Cosmos.EntityTest do
  use ExUnit.Case
  doctest Cosmos

  test "Create new Entity" do
    entity = Cosmos.Entity.new()
    assert entity.id != nil
  end

  test "components" do
    entity = Cosmos.Entity.new()
    comp1 = Cosmos.Entity.Component.new("name", :attribute, "jorsa")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    entity = Cosmos.Entity.add_component(entity, comp1) |> Cosmos.Entity.add_component(comp2)

    assert length(Cosmos.Entity.components(entity)) == 2
    assert Cosmos.Entity.components(entity, "name") == [Map.put(comp1, :id, 1)]
    assert Cosmos.Entity.components(entity, :temporal_decay) == [Map.put(comp2, :id, 2)]
    assert Cosmos.Entity.components(entity, 1) == [Map.put(comp1, :id, 1)]
    assert entity.auto_component_id == 3

    # when removing components, we should ensure that the auto_component ids are
    # handled correctly
    {new_entity, first_component} = Cosmos.Entity.delete_component(entity, 1)
    assert Map.get(entity.components, 1) == %{comp1 | id: 1}
    assert new_entity.auto_component_id == 2
    assert first_component.name == "name"
    assert first_component.system == :attribute
  end

  test "update component" do
    entity = Cosmos.Entity.new()
    comp1 = Cosmos.Entity.Component.new("name", :attribute, "jorsa")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    entity = Cosmos.Entity.add_component(entity, comp1) |> Cosmos.Entity.add_component(comp2)

    new_entity =
      Cosmos.Entity.update_component(entity, 1, fn comp -> %{comp | value: "gor'lop"} end)

    assert Enum.at(Cosmos.Entity.components(new_entity, "name"), 0).value == "gor'lop"
  end
end
