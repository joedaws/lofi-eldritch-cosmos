defmodule Cosmos.EntityCacheTest do
  use ExUnit.Case

  test "server process for new being" do
    {:ok, cache} = Cosmos.EntityCache.start()

    server = Cosmos.EntityCache.server_process(cache)
    entity_id = Cosmos.EntityServer.get(server).id

    assert server == Cosmos.EntityCache.server_process(cache, entity_id)
  end

  test "server process for existing being" do
    {:ok, cache} = Cosmos.EntityCache.start()

    # create a new being and store it
    server = Cosmos.EntityCache.server_process(cache)
    comp1 = Cosmos.Entity.Component.new("name", :static, "johnson")
    comp2 = Cosmos.Entity.Component.new("ichor", :temporal_decay, 100)
    entity = Cosmos.EntityServer.get(server)

    entity_created =
      Cosmos.Entity.add_component(entity, comp1) |> Cosmos.Entity.add_component(comp2)

    # ensure that new server is the same
    new_server = Cosmos.EntityCache.server_process(cache, entity_created.id)
    assert new_server == server
  end
end
