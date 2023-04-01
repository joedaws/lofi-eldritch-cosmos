defmodule Cosmos.Entity.Component do
  @enforce_keys [:name, :system, :value]
  defstruct [:name, :system, :value, :id]

  def new(name, system, value) do
    {:ok, system} = Cosmos.System.validate_system!(system)
    %__MODULE__{name: name, system: system, value: value}
  end
end
