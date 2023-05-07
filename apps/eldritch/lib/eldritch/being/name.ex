defmodule Eldritch.Being.Name do
  @templates %{
    Enum.at(Eldritch.Being.Grimoire.grimoires(), 0) => [
      "shell_name",
      "core_prefix",
      "core_name"
    ]
  }

  @template_components %{
    "shell_name" => [
      "Shu",
      "Jhum",
      "Pnuc",
      "Tanch",
      "Gahn",
      "Walm",
      "Bynk",
      "Miw",
      "Cryk",
      "Nlyn",
      "Hysh",
      "Yn",
      "Oik",
      "Veq"
    ],
    "core_prefix" => [
      "Do~",
      "Lo~",
      "Me~",
      "Ce~",
      "Ku~",
      "Pu~",
      "Wo~",
      "Ro~",
      "Ty~",
      "A~",
      ""
    ],
    "core_name" => [
      "Ga",
      "Um",
      "Mo",
      "Xo",
      "Lulp",
      "Tur",
      "Llach",
      "Vom",
      "Qak",
      "Wol"
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

    [w1, w2, w3] = for(part <- template, do: Enum.random(Map.get(@template_components, part)))
    Enum.join([w1, w2 <> w3], " ")
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
    for w1 <- list1, w2 <- list2, w3 <- list3, do: Enum.join([w1, w2 <> w3], " ")
  end
end
