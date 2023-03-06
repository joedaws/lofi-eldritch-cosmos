defmodule Cosmos.Entity.CacheTest do
  use ExUnit.Case

  test "server process for new being" do
    Cosmos.Entity.Cache.start_link([])

    server = Cosmos.Entity.Cache.server_process()
    entity_id = Cosmos.Entity.Server.get(server).id

    assert server == Cosmos.Entity.Cache.server_process(entity_id)
  end

  test "server process for existing being" do
    Cosmos.Entity.Cache.start_link([])

    # create a new being and store it
    server = Cosmos.Entity.Cache.server_process()
    comp1 = Cosmos.Entity.Component.new("name", :static, "johnson")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    entity = Cosmos.Entity.Server.get(server)

    entity_created =
      Cosmos.Entity.add_component(entity, comp1) |> Cosmos.Entity.add_component(comp2)

    # ensure that new server is the same
    new_server = Cosmos.Entity.Cache.server_process(entity_created.id)
    assert new_server == server
  end
end
