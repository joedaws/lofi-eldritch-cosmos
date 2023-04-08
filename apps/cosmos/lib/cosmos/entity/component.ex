defmodule Cosmos.Entity.Component do
  @enforce_keys [:name, :system, :value]
  defstruct [:name, :system, :value, :id]

  def new(name, system, value) do
    {:ok, system} = Cosmos.System.validate_system!(system)
    %__MODULE__{name: name, system: system, value: value}
  end

  @doc """
  used to increase a numeric valued component
  """
  def update_numeric_value(comp, amount) when is_number(amount) do
    %{comp | value: comp.value + amount}
  end
end

defimpl String.Chars, for: Cosmos.Entity.Component do
  def to_string(%Cosmos.Entity.Component{id: id, name: name, system: system, value: value}) do
    cond do
      is_integer(value) ->
        "Component[id=#{id}, name=#{name}, system=#{system}, value=#{value}]"

      is_bitstring(value) ->
        "Component[id=#{id}, name=#{name}, system=#{system}, value=#{value}]"

      is_map(value) ->
        "Component[id=#{id}, name=#{name}, system=#{system}, map_value_size=#{length(Map.keys(value))}]"

      true ->
        "Component[id=#{id}, name=#{name}, system=#{system}, no string for value]"
    end
  end
end
