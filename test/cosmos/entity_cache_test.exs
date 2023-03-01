defmodule Cosmos.EntityCacheTest do
  use ExUnit.Case

  test "server process for new being" do
    {:ok, cache} = Cosmos.EntityCache.start()

    server = Cosmos.EntityCache.server_process(cache)
    entity_id = Cosmos.EntityServer.get(server).id

    assert server == Cosmos.EntityCache.server_process(cache, entity_id)
  end
end
