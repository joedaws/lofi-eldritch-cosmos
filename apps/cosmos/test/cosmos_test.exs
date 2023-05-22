defmodule CosmosTest do
  use ExUnit.Case
  doctest Cosmos

  test "get application variable" do
    assert Cosmos.get_persist_dir() != nil
  end
end
