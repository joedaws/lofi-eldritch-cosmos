defmodule Cosmos.Entity do
  @enforce_keys [:id, :components, :auto_component_id]
  defstruct [:id, :components, :auto_component_id]

  @default_auto_component_id 1

  def new() do
    %__MODULE__{components: %{}, id: generate_id(), auto_component_id: @default_auto_component_id}
  end

  @doc """
  components is a list of maps each of which is a component map
  """
  def new(components) when is_list(components) do
    Enum.reduce(
      components,
      new(),
      fn comp, entity_acc -> add_component(entity_acc, comp) end
    )
  end

  def components(entity) do
    entity.components
    |> Enum.map(fn {_, comp} -> comp end)
  end

  def components(entity, component_name) when is_bitstring(component_name) do
    entity.components
    |> Stream.filter(fn {_, comp} -> comp.name == component_name end)
    |> Enum.map(fn {_, comp} -> comp end)
  end

  def components(entity, component_type) when is_atom(component_type) do
    entity.components
    |> Stream.filter(fn {_, comp} -> comp.type == component_type end)
    |> Enum.map(fn {_, comp} -> comp end)
  end

  def components(entity, component_id) when is_integer(component_id) do
    entity.components
    |> Stream.filter(fn {_, comp} -> comp.id == component_id end)
    |> Enum.map(fn {_, comp} -> comp end)
  end

  @doc """
  components are maps which at a minumum :type as a key.

  Each component may have other keys according to their usage.
  """
  def add_component(entity, component) do
    # TODO consider having the component.name be the key
    #      and only allowing one component of each name
    component = Map.put(component, :id, entity.auto_component_id)
    new_components = Map.put(entity.components, entity.auto_component_id, component)

    %__MODULE__{
      entity
      | components: new_components,
        auto_component_id: entity.auto_component_id + 1
    }
  end

  @doc """
  The caller is expected to update the component appropriatly
  """
  def update_component(entity, component_id, updater_fun) do
    case Map.fetch(entity.components, component_id) do
      :error ->
        entity

      {:ok, old_component} ->
        old_component_id = old_component.id
        old_component_type = old_component.type

        new_component =
          %{id: ^old_component_id, type: ^old_component_type} = updater_fun.(old_component)

        new_components = Map.put(entity.components, new_component.id, new_component)
        %__MODULE__{entity | components: new_components}
    end
  end

  def delete_component(entity, component_id) when is_integer(component_id) do
    case Map.pop(entity.components, component_id, :not_found) do
      {:not_found, _} ->
        entity

      {old_component, remaining_components} ->
        id_to_replace = old_component.id

        new_components =
          for comp_tuple <- remaining_components,
              into: %{},
              do: update_component_id(id_to_replace, comp_tuple)

        %__MODULE__{
          entity
          | components: new_components,
            auto_component_id: entity.auto_component_id - 1
        }
    end
  end

  def generate_id() do
    Ksuid.generate()
  end

  defp update_component_id(id_to_replace, {id, component}) do
    cond do
      id < id_to_replace -> {id, component}
      id > id_to_replace -> {id - 1, %{component | id: id - 1}}
    end
  end
end

defimpl Collectable, for: Cosmos.Entity do
  def into(original) do
    {original, &into_callback/2}
  end

  defp into_callback(entity, {:cont, component}) do
    Cosmos.Entity.add_component(entity, component)
  end

  defp into_callback(entity, :done), do: entity
  defp into_callback(_entity, :halt), do: :ok
end
