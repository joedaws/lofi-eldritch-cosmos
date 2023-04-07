defmodule Cosmos.Entity.ComponentTest do
  use ExUnit.Case

  test "componet String.chars protocol" do
    comp_integer = Cosmos.Entity.Component.new("test_int", :attribute, 3)
    comp_string = Cosmos.Entity.Component.new("test_string", :attribute, "yo")
    comp_map = Cosmos.Entity.Component.new("test_map", :attribute, %{"whoa" => "a map"})

    assert is_bitstring(to_string(comp_integer))
    assert is_bitstring(to_string(comp_string))
    assert is_bitstring(to_string(comp_map))
  end
end
