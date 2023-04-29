defmodule Eldritch.Node.Name do
  require Logger

  @templates %{
    "warped_nature_1" => ["spooky_adjective", "ecosystem"],
    "warped_nature_2" => ["ecosystem", "prepositional_phrase"],
    "warped_nature_3" => ["spooky_adjective", "ecosystem", "prepositional_phrase"],
    "human_built_1" => ["architectural_adjective", "structure_type", "room_in_structure"],
    "human_built_2" => ["structure_type", "room_in_structure", "prepositional_phrase"],
    "human_built_3" => ["spooky_adjective", "structure_type"],
    "dream_place_1" => ["spooky_adjective", "mythological_place"],
    "dream_place_2" => ["architectural_adjective", "mythological_place", "prepositional_phrase"]
  }

  @template_components %{
    "ecosystem" => [
      "Waterfall",
      "Canyon",
      "Bog",
      "Cave",
      "Glacier",
      "Rainforest",
      "Desert",
      "Coral Reef",
      "Volcano",
      "Geyser",
      "Mountain",
      "River",
      "Fjord",
      "Mangrove Swamp",
      "Lake",
      "Island",
      "Tundra",
      "Crag",
      "Oasis",
      "Estuary",
      "Lagoon",
      "Glen"
    ],
    "spooky_adjective" => [
      "Haunted",
      "Eerie",
      "Creepy",
      "Ghostly",
      "Spooky",
      "Shadowy",
      "Grim",
      "Macabre",
      "Sinister",
      "Gothic",
      "Mysterious",
      "Dark",
      "Ominous",
      "Supernatural",
      "Otherworldly",
      "Cursed",
      "Enchanted",
      "Spectral",
      "Phantasmal",
      "Ghastly",
      "Horrifying",
      "Petrifying",
      "Bone-chilling",
      "Terrifying",
      "Menacing",
      "Frightening",
      "Unearthly",
      "Uncanny",
      "Disturbing",
      "Chilling",
      "Cryptic",
      "Demonic",
      "Diabolical",
      "Evil",
      "Fearful",
      "Ghoulish",
      "Hair-raising",
      "Hallowing",
      "Hellish",
      "Horror-stricken",
      "Appalling",
      "Blood-curdling",
      "Dreadful",
      "Emanating",
      "Fear-inducing",
      "Freakish",
      "Frightful",
      "Gory",
      "Grisly",
      "Inexplicable",
      "Macaronic",
      "Malevolent",
      "Nightmarish",
      "Occult",
      "Outlandish",
      "Phantasmagoric",
      "Scaring",
      "Scary",
      "Shadowed",
      "Shocking",
      "Spellbinding",
      "Strange",
      "Tenebrous",
      "Unnatural",
      "Weird",
      "Wicked",
      "Cimmerian",
      "Daunting",
      "Deathly",
      "Direful",
      "Dismaying",
      "Elusive",
      "Enigmatic",
      "Esoteric",
      "Foreboding",
      "Ghostlike",
      "Ghoul-ridden",
      "Grave",
      "Gristly",
      "Haunting",
      "Hazy",
      "Impenetrable",
      "Insidious",
      "Invoking",
      "Lurid",
      "Melancholy",
      "Misty",
      "Morbid",
      "Nebulous",
      "Nefarious",
      "Nightmaric",
      "Obscure",
      "Omnipresent",
      "Paranormal",
      "Perilous",
      "Shivery",
      "Supernormal",
      "Suspenseful",
      "Vengeful"
    ],
    "prepositional_phrase" => [
      "In the Haunted Forest",
      "Through the Misty Graveyard",
      "Beneath the Ancient Ruins",
      "Atop the Haunted Tower",
      "Along the Winding Path",
      "Beside the Forgotten Well",
      "Amidst the Eerie Mist",
      "Inside the Haunted Mansion",
      "Within the Dark Catacombs",
      "Between the Gnarled Trees",
      "Across the Haunted Moor",
      "Underneath the Murky Water",
      "Beyond the Rusted Gate",
      "Around the Cursed Boulder",
      "Among the Twisted Vines",
      "Above the Foggy Valley",
      "Behind the Cold Stone Wall",
      "Near the Abandoned Village",
      "Over the Creaky Bridge",
      "Past the Overgrown Thicket",
      "Through the Shadowy Tunnel",
      "Toward the Looming Castle",
      "Upon the Haunted Hill",
      "Behind the Ivy-covered Gate",
      "With the Howling Winds"
    ],
    "architectural_adjective" => [
      "Majestic",
      "Imposing",
      "Monumental",
      "Ornate",
      "Grandiose",
      "Stately",
      "Timeless",
      "Intricate",
      "Majestic",
      "Awe-inspiring"
    ],
    "structure_type" => [
      "Pyramids",
      "Temples",
      "Amphitheaters",
      "Colosseum",
      "Aqueducts",
      "Stonehenge",
      "Henges",
      "Ziggurats",
      "Tombs",
      "Palaces",
      "City Walls",
      "Monoliths",
      "Obelisks",
      "Stelae",
      "Megaliths",
      "Cairns",
      "Barrows",
      "Menhirs",
      "Dolmens",
      "Towers",
      "Crypt",
      "Mausolem"
    ],
    "room_in_structure" => [
      "Chapel",
      "Library",
      "Chamber",
      "Hypostyle Hall",
      "Antechamber",
      "Cellar",
      "Vestry",
      "Refectory"
    ],
    "mythological_place" => [
      "Aetheria",
      "Nebulon",
      "Everpeak",
      "Glimmertide",
      "Moonspire"
    ]
  }

  def template_names() do
    Map.keys(@templates)
  end

  def generate_name() do
    template_name = Enum.random(template_names())
    generate_name(template_name)
  end

  def generate_name(template_name) do
    template = Map.get(@templates, template_name)

    for(part <- template, do: Enum.random(Map.get(@template_components, part))) |> Enum.join(" ")
  end

  def all_names_list do
    templates = template_names()

    {_, all_names} =
      Enum.map_reduce(templates, [], fn x, acc -> {x, acc ++ all_names_list(x)} end)

    Enum.shuffle(all_names)
  end

  def all_names_list(template_name) do
    template = Map.get(@templates, template_name)

    word_lists = for part <- template, do: Map.get(@template_components, part)

    all_word_combos(word_lists)
  end

  def all_word_combos([list1, list2]) do
    for w1 <- list1, w2 <- list2, do: Enum.join([w1, w2], " ")
  end

  def all_word_combos([list1, list2, list3]) do
    for w1 <- list1, w2 <- list2, w3 <- list3, do: Enum.join([w1, w2, w3], " ")
  end
end
