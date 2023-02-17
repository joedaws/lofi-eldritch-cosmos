defmodule Cosmos.EntityServerTest do
  use ExUnit.Case

  test "add_component" do
    {:ok, server} = Cosmos.EntityServer.start()
    comp1 = Cosmos.Entity.Component.new("name", :static, "jorsa")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    Cosmos.EntityServer.add_component(server, comp1)
    Cosmos.EntityServer.add_component(server, comp2)

    entity = Cosmos.EntityServer.get(server)

    assert length(Cosmos.Entity.components(entity)) == 2
  end
end
