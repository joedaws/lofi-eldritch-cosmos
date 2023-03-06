defmodule Cosmos.Entity.ServerTest do
  use ExUnit.Case

  test "add_component" do
    {:ok, server} = Cosmos.Entity.Server.start()
    comp1 = Cosmos.Entity.Component.new("name", :static, "jorsa")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    Cosmos.Entity.Server.add_component(server, comp1)
    Cosmos.Entity.Server.add_component(server, comp2)

    entity = Cosmos.Entity.Server.get(server)

    assert length(Cosmos.Entity.components(entity)) == 2
  end
end
