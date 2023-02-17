defmodule Cosmos.Entity.Component do
  @enforce_keys [:name, :type, :value]
  defstruct [:name, :type, :value, :id]

  @component_types [
    :static,
    :temporal_decay
  ]

  def new(name, type, value) do
    {:ok, type} = validate_type!(type)
    %__MODULE__{name: name, type: type, value: value}
  end

  # raise error if type is not in allowed list
  defp validate_type!(type) do
    case is_atom(type) && type in @component_types do
      true ->
        {:ok, type}

      false ->
        :error
    end
  end
end
