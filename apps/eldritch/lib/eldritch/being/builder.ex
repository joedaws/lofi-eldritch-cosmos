defmodule Eldritch.Being.Builder do
  @moduledoc """
  Used to create new instances of being entities

  Not intended for use after the initialization of an entity
  (except `ensure_standard/1`, which upgrades beings persisted by
  older versions of the cosmos).
  """
  @starting_ichor 100
  @starting_orichalcum 100
  # measured in volition cycles
  @lifespan 500..900

  def default_lifespan(), do: Enum.max(@lifespan)
  def random_lifespan(), do: Enum.random(@lifespan)

  @doc """
  Builds a standard being. Every attribute may be overridden:

    * `"name"`        - defaults to the next name from the being name generator
    * `"ichor"`       - life force (default #{@starting_ichor})
    * `"orichalcum"`  - currency (default #{@starting_orichalcum})
    * `"at_node"`     - node id the being starts at (default nil)
    * `"desire"`      - resource type the being longs for (default random)
    * `"incantation"` - `%{"front" => ..., "back" => ...}`
    * `"lineage"`     - `%{"generation" => n, "parents" => [ids]}`
    * `"bonds"`       - `%{being_id => affinity}`
    * `"psyche"`      - options for `Eldritch.Lacan.new/1` (e.g. `"objet_a"`, `"chain"`)

  returns the entity id of the newly created being
  """
  def build({:new, :being, :standard}, attributes \\ %{}) do
    new_entity = Cosmos.Entity.new()
    entity_id = new_entity.id
    Cosmos.Database.store(entity_id, new_entity)
    entity_server = Cosmos.Entity.Cache.server_process(entity_id)

    Eldritch.CommonComponent.name(
      entity_server,
      Map.get_lazy(attributes, "name", &Eldritch.Being.NameGenerator.next/0)
    )

    is_being(entity_server)
    status(entity_server, "alive")
    ichor(entity_server, Map.get(attributes, "ichor", @starting_ichor))
    inventory(entity_server, Map.get(attributes, "orichalcum", @starting_orichalcum))
    at_node(entity_server, nil)
    # a new being does not start with observations, so no override is provided
    observations(entity_server)
    incantation(entity_server, Map.get(attributes, "incantation"))

    # desire is never directly for the objet a, the cause of desire
    psyche = Eldritch.Lacan.new(Map.get(attributes, "psyche", %{}))
    desire = Map.get_lazy(attributes, "desire", fn -> Eldritch.Lacan.initial_desire(psyche["objet_a"]) end)

    psyche =
      if desire == psyche["objet_a"],
        do: Eldritch.Lacan.new(Map.put(Map.get(attributes, "psyche", %{}), "objet_a", Eldritch.Lacan.initial_desire(desire))),
        else: psyche

    volition(entity_server, desire)
    psyche(entity_server, psyche)

    bonds(entity_server, Map.get(attributes, "bonds", %{}))
    lineage(
      entity_server,
      Map.merge(
        %{"generation" => 0, "parents" => [], "age" => 0, "lifespan" => random_lifespan()},
        Map.get(attributes, "lineage", %{})
      )
    )

    case Map.get(attributes, "at_node") do
      nil -> :ok
      node_id -> Eldritch.Being.Actions.move_to_node(entity_id, node_id)
    end

    entity_id
  end

  @doc """
  Adds any standard component missing from a being persisted by an
  earlier version and converts outdated component values.
  """
  def ensure_standard(entity_server) do
    entity = Cosmos.Entity.Server.get(entity_server)
    has? = fn name -> Cosmos.Entity.component(entity, name) != nil end

    unless has?.("is_being"), do: is_being(entity_server)
    unless has?.("status"), do: status(entity_server, "alive")
    unless has?.("harvest"), do: at_node(entity_server, nil)
    unless has?.("observations"), do: observations(entity_server)
    unless has?.("incantation"), do: incantation(entity_server, nil)

    unless has?.("volition"),
      do: volition(entity_server, Eldritch.Node.Resource.get_random_resource_type())

    unless has?.("bonds"), do: bonds(entity_server, %{})

    unless has?.("psyche") do
      desire = get_in(Cosmos.Entity.component(entity, "volition") || %{}, [Access.key(:value), "desire"])
      psyche = Eldritch.Lacan.new()

      psyche =
        if psyche["objet_a"] == desire,
          do: Eldritch.Lacan.new(%{"objet_a" => Eldritch.Lacan.initial_desire(desire)}),
          else: psyche

      psyche(entity_server, psyche)
    end

    unless has?.("lineage"),
      do:
        lineage(entity_server, %{
          "generation" => 0,
          "parents" => [],
          "age" => 0,
          "lifespan" => random_lifespan()
        })

    # observations used to be a MapSet of {node_id, resource_type} tuples
    case Cosmos.Entity.component(entity, "observations") do
      %{value: %{"nodes_and_resources" => old}} ->
        known = Map.new(old, fn {node_id, resource} -> {node_id, resource} end)

        Cosmos.Entity.Server.update_component(entity_server, "observations", fn comp ->
          %{comp | value: %{"nodes" => known, "visited" => Map.new(known, fn {k, _} -> {k, true} end)}}
        end)

      _ ->
        :ok
    end

    :ok
  end

  def ichor(entity_server, ichor_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("ichor", Eldritch.System.TemporalDecay, ichor_amount)
    )
  end

  def is_being(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("is_being", :is_being, true)
    )
  end

  @doc """
  "alive" or "faded"
  """
  def status(entity_server, status) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("status", :attribute, status)
    )
  end

  @doc """
  Sets the location component. Use `Eldritch.Being.Actions.move_to_node/2`
  to move an existing being so that node occupants stay consistent.
  """
  def at_node(entity_server, node_id) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("at_node", :attribute, node_id)
    )

    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("harvest", Eldritch.System.Harvest, true)
    )
  end

  def inventory(entity_server, orichalcum_amount) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("inventory", :inventory, %{
        "orichalcum" => orichalcum_amount,
        "resources" => %{}
      })
    )
  end

  @doc """
  What the being knows about the landscape:

    * `"nodes"`   - `%{node_id => resource_type}` of every node it has seen
    * `"visited"` - `%{node_id => true}` of every node it has stood in
  """
  def observations(entity_server) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("observations", Eldritch.System.Observation, %{
        "nodes" => %{},
        "visited" => %{}
      })
    )
  end

  @doc """
  The being's drives. `"desire"` is the resource it longs for; once
  attained, desire slides on to another object. `"intent"` and
  `"thought"` describe what the being is currently doing.
  """
  def volition(entity_server, desire) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("volition", Eldritch.System.Volition, %{
        "desire" => desire,
        "intent" => "awaken",
        "thought" => "..."
      })
    )
  end

  @doc """
  The being's psyche (see `Eldritch.Lacan`)
  """
  def psyche(entity_server, psyche) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("psyche", :attribute, psyche)
    )
  end

  @doc """
  `%{other_being_id => affinity}` (negative for rivals)
  """
  def bonds(entity_server, bonds) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("bonds", Eldritch.System.Communion, bonds)
    )
  end

  def lineage(entity_server, lineage) do
    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new("lineage", :attribute, lineage)
    )
  end

  @doc """
  an incantation is like a flash card, it has a front and a back.

  The user can chose wether to fill in the front or back.

  A single sided flash card is a "declarative incantation"
  A two-sided flash card is a "flash incantation"

  See `Eldritch.Being.Incantation` for the spaced repetition fields.
  """
  def incantation(entity_server, incantation \\ nil) do
    incantation = incantation || Eldritch.Being.Incantation.default()

    Cosmos.Entity.Server.add_component(
      entity_server,
      Cosmos.Entity.Component.new(
        "incantation",
        Eldritch.System.Remind,
        Eldritch.Being.Incantation.new(incantation["front"], incantation["back"])
      )
    )
  end
end
