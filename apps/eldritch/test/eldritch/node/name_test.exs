defmodule Eldritch.Node.NameTest do
  use ExUnit.Case

  test "template_names" do
    template_names = Eldritch.Node.Name.template_names()

    Enum.map(template_names, fn name -> assert is_bitstring(name) end)
  end

  test "generate_name" do
    name_1 = Eldritch.Node.Name.generate_name()
    name_2 = Eldritch.Node.Name.generate_name("warped_nature_1")

    assert is_bitstring(name_1)
    assert is_bitstring(name_2)
  end
end
