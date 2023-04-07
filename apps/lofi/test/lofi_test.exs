defmodule LofiTest do
  use ExUnit.Case
  doctest Lofi

  test "greets the world" do
    assert Lofi.hello() == :world
  end
end
