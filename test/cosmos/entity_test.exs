defmodule Cosmos.EntityTest do
  use ExUnit.Case
  doctest Cosmos

  test "Create new Entity" do
    entity = Cosmos.Entity.new()
    assert entity.id != nil
  end
end
