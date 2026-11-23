# Portraits for the ad: c0..c15 (16 beings), m0..m4 (one being in five moods),
# t0..t5 (a name as it is typed). Usage: mix run --no-start portraits.exs <dir>
dir = hd(System.argv())
names = ["Gor Lop~Tome", "Ulth", "Brine Mother", "Kol", "Xa'Vemoth Ghul", "Pell~Orr Nim Saa", "Ithikka", "Morrow Drae", "Qeb~Seth", "Vrin Vrin Vrin~Vo", "Ommadawn~Lir", "Sable Wick", "Tanch Me~Mo", "Hask", "Oik Ty~Lulp", "Yn Ku~Llach"]
for {name, i} <- Enum.with_index(names) do
  f = Lofi.Portrait.features(%{"name" => name, "ichor" => 140, "desire" => "blood"})
  {:ok, svg, _} = Lofi.Portrait.Svg.render(f, [])
  File.write!(Path.join(dir, "c#{i}.svg"), svg)
end
moods = [
  %{"ichor" => 130},
  %{"ichor" => 190, "psyche" => %{"lack" => 95}, "incantation" => %{"awaiting" => true}, "desire" => "blood"},
  %{"ichor" => 90, "psyche" => %{"lack" => 50, "registers" => %{"real" => 0.65, "symbolic" => 0.2, "imaginary" => 0.15}, "unknotted" => "real"}, "temperament" => %{"generosity" => 5}},
  %{"ichor" => 15, "psyche" => %{"lack" => 40, "symptom" => %{}}, "desire" => "papyrus"},
  %{"status" => "faded", "ichor" => 0}
]
for {mood, i} <- Enum.with_index(moods) do
  {:ok, svg, _} = Lofi.Portrait.Svg.render(Lofi.Portrait.features(Map.put(mood, "name", "Ulth")), [])
  File.write!(Path.join(dir, "m#{i}.svg"), svg)
end
name = "Gor Lop~Tome"
for {len, i} <- Enum.with_index([1, 3, 5, 7, 9, 12]) do
  f = Lofi.Portrait.features(String.slice(name, 0, len))
  {:ok, svg, _} = Lofi.Portrait.Svg.render(f, [])
  File.write!(Path.join(dir, "t#{i}.svg"), svg)
end
