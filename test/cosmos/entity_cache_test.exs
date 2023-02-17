defmodule Cosmos.EntityCacheTest do
  use ExUnit.Case

  test "server_process" do
    {:ok, cache} = Cosmos.EntityCache.start()
    jorsa_pid = Cosmos.EntityCache.server_process(cache, "jorsa")

    assert jorsa_pid != Cosmos.EntityCache.server_process(cache, "jorp")
    assert jorsa_pid == Cosmos.EntityCache.server_process(cache, "jorsa")
  end
end
