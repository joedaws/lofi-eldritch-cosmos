defmodule Eldritch.Node.Resource do
  @resource_types [
    "bone",
    "blood",
    "peat_moss",
    "tomb_mold",
    "sea_foam",
    "obsidian",
    "papyrus",
    "lotus_root",
    "soap_stone",
    "birch_bark",
    "uncanny_coal"
  ]

  @resource_units %{
    "bone" => {"chunk", "chunks"},
    "blood" => {"vial", "vials"},
    "peat_moss" => {"clump", "clumps"},
    "tomb_mold" => {"box", "boxes"},
    "sea_foam" => {"flask", "flasks"},
    "obsidian" => {"flake", "flakes"},
    "papyrus" => {"scroll", "scrolls"},
    "lotus_root" => {"can", "cans"},
    "soap_stone" => {"block", "blocks"},
    "birch_bark" => {"bundle", "bundles"},
    "uncanny_coal" => {"lump", "lumps"}
  }

  @max_resource_yield 10

  def valid_resource_type?(resource_type) do
    resource_type in get_resource_types()
  end

  def valid_resource_yield?(resource_yield) do
    resource_yield > 0 and resource_yield <= @max_resource_yield
  end

  def get_resource_types() do
    @resource_types
  end

  def get_resource_unit(resource_type, amount \\ :plural) do
    {singular_unit, plural_unit} = Map.get(@resource_units, resource_type)

    case amount do
      :plural -> plural_unit
      :singular -> singular_unit
    end
  end

  def get_random_resource_type() do
    resources = get_resource_types()
    Enum.random(resources)
  end
end
