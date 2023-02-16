defmodule CosmosTest do
  use ExUnit.Case
  doctest Cosmos

  test "get application variable" do
    assert Cosmos.get_data_path() != nil
  end
end
