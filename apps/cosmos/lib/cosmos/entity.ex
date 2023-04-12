defmodule Cosmos.Entity do
  @moduledoc """
  An entity has
    - :id - set by this module's `generate_id` function
    - :components - a map whose keys are `component_id`
                    and whose values are Cosmos.Entity.Component struct instances
    - :auto_component_id - used to set component ids when adding and removing components
                           from the entity

  Note:
    An entity can have at most one component with a given name.
    An entity can have at most one component with an id.
  """

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

  @doc """
  Returns list of components

  An entity may have multiple components belonging to the same system
  The 2 arity version returns all components belonging to the system atom
  """
  def components(entity) do
    entity.components
    |> Enum.map(fn {_, comp} -> comp end)
  end

  def components(entity, component_system) when is_atom(component_system) do
    entity.components
    |> Stream.filter(fn {_, comp} -> comp.system == component_system end)
    |> Enum.map(fn {_, comp} -> comp end)
  end

  @doc """
  An entity has at most one components with a given name
  An entity has at most one components with a given id
  """
  def component(entity, component_name) when is_bitstring(component_name) do
    key_value_pair = Enum.find(entity.components, fn {_, v} -> v.name == component_name end)

    extract_value_from_tuple(key_value_pair)
  end

  def component(entity, component_id) when is_integer(component_id) do
    key_value_pair = Enum.find(entity.components, fn {_, v} -> v.id == component_id end)

    extract_value_from_tuple(key_value_pair)
  end

  def system_atoms(entity) do
    entity.components
    |> Enum.map(fn {_, comp} -> comp.system end)
  end

  @doc """
  Adds a component to the entity

  If the provided component has the same name as a
  component which has already been registered
  with the entity, that component is updated instead of
  added to ensure that each entity has at most one component
  with a given name.
  """
  def add_component(entity, component) do
    component_names = for {_, comp} <- entity.components, do: comp.name

    {new_auto_component_id, new_components} =
      if component.name not in component_names do
        component = Map.put(component, :id, entity.auto_component_id)
        components = Map.put(entity.components, component.id, component)
        {entity.auto_component_id + 1, components}
      else
        existing_component_id =
          Enum.filter(
            entity.components,
            fn {_, v} -> v.name == component.name end
          )
          |> Enum.at(0)
          |> elem(0)

        # new components don't have their id field set yet
        {entity.auto_component_id,
         %{entity.components | existing_component_id => %{component | id: existing_component_id}}}
      end

    %__MODULE__{
      entity
      | components: new_components,
        auto_component_id: new_auto_component_id
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
        old_component_system = old_component.system

        new_component =
          %{id: ^old_component_id, system: ^old_component_system} = updater_fun.(old_component)

        new_components = Map.put(entity.components, new_component.id, new_component)
        %__MODULE__{entity | components: new_components}
    end
  end

  def delete_component(entity, component_id) when is_integer(component_id) do
    case Map.pop(entity.components, component_id, :not_found) do
      {:not_found, _} ->
        {entity, :not_found}

      {old_component, remaining_components} ->
        id_to_replace = old_component.id

        new_components =
          for comp_tuple <- remaining_components,
              into: %{},
              do: update_component_id(id_to_replace, comp_tuple)

        {%__MODULE__{
           entity
           | components: new_components,
             auto_component_id: entity.auto_component_id - 1
         }, old_component}
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

  defp extract_value_from_tuple({_, v}) do
    v
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

defimpl String.Chars, for: Cosmos.Entity do
  def to_string(%Cosmos.Entity{id: entity_id, components: components, auto_component_id: _}) do
    "Entity[id=#{entity_id}, num_components=#{length(Map.keys(components))}]"
  end
end
