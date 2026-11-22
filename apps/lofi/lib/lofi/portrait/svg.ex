defmodule Lofi.Portrait.Svg do
  @moduledoc """
  Procedural portraits, drawn as SVG in the look of the page: flat muted
  inks, bold outlines, paper grain, a putty frame with a name plate.

  Everything random is a hash of the name's seed and a label (`rand/2`), so
  a name always gives the same creature. Layers, back to front: ground,
  halo or rune ring, limbs, body (shade, then lit face, then markings),
  eyes, mouth, signs of mood, frame.
  """
  @behaviour Lofi.Portrait.Renderer

  @w 200
  @h 260
  # the picture inside the frame
  @art {8, 8, 184, 214}

  @palettes %{
    "verdigris" => %{
      bg: "#16302e",
      body: "#7fa99b",
      shade: "#4c786d",
      ink: "#0d1a18",
      eye: "#ece5cf",
      glow: "#d9b45a"
    },
    "oxblood" => %{
      bg: "#2a1215",
      body: "#b0585a",
      shade: "#73302f",
      ink: "#160a0b",
      eye: "#efe2c6",
      glow: "#e0a86a"
    },
    "ochre" => %{
      bg: "#33281a",
      body: "#c99c4c",
      shade: "#8a6a2f",
      ink: "#1d160b",
      eye: "#f2ead2",
      glow: "#a8323f"
    },
    "dusk" => %{
      bg: "#221d31",
      body: "#9d8dba",
      shade: "#655a82",
      ink: "#110e19",
      eye: "#ece6f2",
      glow: "#b9d9a3"
    },
    "seaglass" => %{
      bg: "#132831",
      body: "#8cc0c4",
      shade: "#4f8790",
      ink: "#0a1519",
      eye: "#f4efdc",
      glow: "#e98f6f"
    },
    "moss" => %{
      bg: "#1c2716",
      body: "#8ea35a",
      shade: "#5b6d36",
      ink: "#0e140a",
      eye: "#ede7cf",
      glow: "#c45f4a"
    },
    "bone" => %{
      bg: "#2a2824",
      body: "#d6cdb6",
      shade: "#9f9680",
      ink: "#17130e",
      eye: "#fbf6e6",
      glow: "#7c1d2a"
    },
    "ember" => %{
      bg: "#151414",
      body: "#67615c",
      shade: "#3c3733",
      ink: "#080808",
      eye: "#f0c36a",
      glow: "#e4572e"
    }
  }

  @resource_colors %{
    "bone" => "#e8dcc0",
    "blood" => "#d9434f",
    "peat_moss" => "#7fa83a",
    "tomb_mold" => "#86c79a",
    "sea_foam" => "#7fd6d0",
    "obsidian" => "#8b78c9",
    "papyrus" => "#d9b56a",
    "lotus_root" => "#e88fb8",
    "soap_stone" => "#9aa7b0",
    "birch_bark" => "#cbbf94",
    "uncanny_coal" => "#ff7a3a"
  }

  @frame "#d6cdb6"

  @impl true
  def render(%{"anatomy" => a} = features, opts) do
    m = Map.get(features, "mood") || Lofi.Portrait.Features.mood(%{})
    name = Map.get(features, "name")
    frame? = Keyword.get(opts, :frame, true) and name != nil
    p = Map.fetch!(@palettes, a["palette"])
    seed = a["seed"]
    body = body_shape(a, m)
    {ax, ay, aw, ah} = @art
    id = "p#{seed}"

    figure = [
      limbs(a, m, body, p),
      body_svg(a, m, body, p, id),
      eyes(a, m, body, p),
      mouth(a, m, body, p),
      signs(m, body, p, seed)
    ]

    svg = [
      ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{if frame?, do: "0 0 #{@w} #{@h}", else: "#{ax} #{ay} #{aw} #{ah}"}" width="#{if frame?, do: @w, else: aw}" height="#{if frame?, do: @h, else: ah}" role="img" aria-label="#{esc(Lofi.Portrait.prompt(features))}">|,
      "<defs>",
      ~s|<clipPath id="#{id}-art"><rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}"/></clipPath>|,
      ~s|<filter id="#{id}-grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="#{rem(seed, 997)}" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 -1.4 1"/></filter>|,
      ~s|<filter id="#{id}-dim"><feColorMatrix type="saturate" values="#{saturation(m)}"/></filter>|,
      ~s|<filter id="#{id}-glow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="5"/></filter>|,
      "</defs>",
      if(frame?, do: ~s|<rect width="#{@w}" height="#{@h}" fill="#{@frame}"/>|, else: ""),
      ~s|<g clip-path="url(##{id}-art)">|,
      ground(m, body, p, seed),
      ~s|<g filter="url(##{id}-dim)">|,
      figure,
      "</g>",
      ~s|<rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}" filter="url(##{id}-grain)" opacity=".16"/>|,
      "</g>",
      if(frame?, do: frame(name, p), else: ""),
      "</svg>"
    ]

    {:ok, svg, "image/svg+xml"}
  end

  # ---------- the body ----------

  # centre, radii, and how the outline is bent
  defp body_shape(a, m) do
    {cx, cy, rx, ry, taper} =
      case a["form"] do
        "bulb" -> {100, 122, 54, 56, 0.0}
        "spire" -> {100, 124, 40, 72, 0.4}
        "maw" -> {100, 132, 66, 44, 0.0}
        "cluster" -> {100, 128, 44, 46, 0.0}
        "veil" -> {100, 122, 50, 64, -0.35}
      end

    %{
      cx: cx,
      cy: cy,
      rx: rx,
      ry: ry,
      taper: taper,
      seed: a["seed"],
      symmetric: a["symmetric"] or m["register"] == "imaginary",
      jagged: m["register"] == "real",
      veil: a["form"] == "veil"
    }
  end

  defp outline(b, cx, cy, rx, ry, salt) do
    n = if b.jagged, do: 30, else: 18

    points =
      for i <- 0..(n - 1) do
        t = 2 * :math.pi() * i / n
        psi = t + :math.pi() / 2

        wobble =
          for k <- 2..4, reduce: 1.0 do
            acc ->
              amp = 0.03 + 0.06 * rand(b.seed, {salt, :amp, k})

              phase =
                if b.symmetric, do: 0.0, else: 2 * :math.pi() * rand(b.seed, {salt, :phase, k})

              acc + amp * :math.cos(k * psi + phase)
          end

        spike = if b.jagged, do: if(rem(i, 2) == 0, do: 1.07, else: 0.9), else: 1.0
        s = :math.sin(t)
        x_scale = 1 - b.taper * max(0.0, -s) + if(b.veil, do: 0.25 * max(0.0, s), else: 0.0)
        y = cy + ry * s * wobble * spike
        y = if b.veil, do: min(y, cy + ry * 0.82), else: y
        {cx + rx * :math.cos(t) * wobble * spike * x_scale, y}
      end

    if b.jagged, do: polygon(points), else: smooth(points)
  end

  defp body_svg(a, m, b, p, id) do
    main = outline(b, b.cx, b.cy, b.rx, b.ry, :body)
    lit = outline(b, b.cx - 5, b.cy - 6, b.rx * 0.9, b.ry * 0.9, :body)

    orbs =
      if a["form"] == "cluster" do
        for {side, i} <- [{-1, 1}, {1, 2}] do
          r = 22 + 8 * rand(b.seed, {:orb, i})
          ox = b.cx + side * (b.rx + r * 0.45)
          oy = b.cy + 18 - 20 * rand(b.seed, {:orb_y, i})

          ~s|<path d="#{outline(b, ox, oy, r, r, {:orb, i})}" fill="#{p.body}" stroke="#{p.ink}" stroke-width="2.5"/>| <>
            ~s|<circle cx="#{n(ox - 4)}" cy="#{n(oy - 5)}" r="#{n(r * 0.25)}" fill="#{p.eye}" opacity=".35"/>|
        end
      else
        []
      end

    glow =
      if m["vigor"] >= 4 and not m["faded"],
        do:
          ~s|<path d="#{main}" fill="none" stroke="#{p.glow}" stroke-width="10" opacity=".55" filter="url(##{id}-glow)"/>|,
        else: ""

    ghost =
      if m["register"] == "imaginary",
        do:
          ~s|<path d="#{main}" fill="none" stroke="#{p.glow}" stroke-width="1.5" opacity=".45" transform="translate(7 -5)"/>|,
        else: ""

    [
      orbs,
      glow,
      ghost,
      ~s|<clipPath id="#{id}-body"><path d="#{main}"/></clipPath>|,
      ~s|<path d="#{main}" fill="#{p.shade}"/>|,
      ~s|<g clip-path="url(##{id}-body)">|,
      ~s|<path d="#{lit}" fill="#{p.body}"/>|,
      markings(a, b, p),
      if(m["faded"], do: cracks(b, p), else: ""),
      "</g>",
      ~s|<path d="#{main}" fill="none" stroke="#{p.ink}" stroke-width="2.6" stroke-linejoin="round"/>|
    ]
  end

  defp markings(a, b, p) do
    s = b.seed

    box = fn salt ->
      {b.cx - b.rx + 2 * b.rx * rand(s, {salt, :x}),
       b.cy - b.ry * 0.1 + 1.1 * b.ry * rand(s, {salt, :y})}
    end

    case a["markings"] do
      "rings" ->
        for i <- 1..2 do
          {x, y} = box.({:ring, i})

          for k <- 1..3,
              do:
                ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{4 * k + 2}" fill="none" stroke="#{p.shade}" stroke-width="1.6"/>|
        end

      "dots" ->
        for i <- 1..16 do
          {x, y} = box.({:dot, i})

          ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(1.4 + 2.2 * rand(s, {:dot_r, i}))}" fill="#{p.shade}"/>|
        end

      "runes" ->
        for i <- 1..7 do
          {x, y} = box.({:rune, i})
          d = for j <- 0..2, do: "#{n(x + 9 * rand(s, {:rx, i, j}) - 4)} #{n(y + 4 * j)}"

          ~s|<polyline points="#{Enum.join(d, " ")}" fill="none" stroke="#{p.shade}" stroke-width="1.8" stroke-linecap="round"/>|
        end

      "veins" ->
        for i <- 1..4 do
          x0 = b.cx - b.rx * 0.6 + b.rx * 1.2 * rand(s, {:vein, i})
          y0 = b.cy + b.ry

          ~s|<path d="M#{n(x0)} #{n(y0)} Q#{n(x0 + 30 * rand(s, {:vq, i}) - 15)} #{n(b.cy + b.ry * 0.3)} #{n(x0 + 24 * rand(s, {:ve, i}) - 12)} #{n(b.cy - b.ry * 0.05)}" fill="none" stroke="#{p.shade}" stroke-width="2" stroke-linecap="round"/>|
        end
    end
  end

  defp cracks(b, p) do
    for i <- 1..3 do
      x = b.cx - b.rx * 0.5 + b.rx * rand(b.seed, {:crack, i})
      y = b.cy - b.ry

      ~s|<polyline points="#{n(x)} #{n(y)} #{n(x + 8)} #{n(y + 22)} #{n(x - 3)} #{n(y + 38)} #{n(x + 5)} #{n(y + 58)}" fill="none" stroke="#{p.ink}" stroke-width="1.6"/>|
    end
  end

  # ---------- limbs, behind the body ----------

  defp limbs(%{"limbs" => "none"}, _m, _b, _p), do: ""

  defp limbs(%{"limbs" => kind, "limb_count" => count}, m, b, p) do
    s = b.seed

    for i <- 1..count do
      frac = if count == 1, do: 0.5, else: (i - 1) / (count - 1)

      case kind do
        "tentacles" ->
          t = :math.pi() * (0.18 + 0.64 * frac)
          {x0, y0} = {b.cx + b.rx * 0.7 * :math.cos(t), b.cy + b.ry * 0.7 * :math.sin(t)}
          len = 46 + 18 * m["wanderlust"] + 14 * rand(s, {:tl, i})
          # outward, but mostly down
          out = 0.55 * t + 0.45 * (:math.pi() / 2)
          {x1, y1} = {x0 + len * :math.cos(out), y0 + len * :math.sin(out)}
          curl = (rand(s, {:curl, i}) - 0.5) * 50
          ctrl = {(x0 + x1) / 2 + curl, (y0 + y1) / 2 - abs(curl) * 0.2}

          ~s|<path d="#{tentacle({x0, y0}, ctrl, {x1, y1}, 8.5)}" fill="#{p.shade}" stroke="#{p.ink}" stroke-width="2.2" stroke-linejoin="round"/>|

        "horns" ->
          t = :math.pi() * (1.22 + 0.56 * frac)
          {x0, y0} = {b.cx + b.rx * 0.8 * :math.cos(t), b.cy + b.ry * 0.8 * :math.sin(t)}
          len = 34 + 18 * rand(s, {:hl, i})
          out = t + (frac - 0.5) * 0.6
          {tx, ty} = {x0 + len * :math.cos(out), y0 + len * :math.sin(out)}
          bend = if frac < 0.5, do: -14, else: 14
          {nx, ny} = {-:math.sin(t) * 7.5, :math.cos(t) * 7.5}

          ~s|<path d="M#{n(x0 - nx)} #{n(y0 - ny)} Q#{n((x0 + tx) / 2 + bend)} #{n((y0 + ty) / 2)} #{n(tx)} #{n(ty)} Q#{n((x0 + tx) / 2 + bend * 0.4)} #{n((y0 + ty) / 2 + 4)} #{n(x0 + nx)} #{n(y0 + ny)}Z" fill="#{p.eye}" stroke="#{p.ink}" stroke-width="2.2" stroke-linejoin="round"/>|

        "antlers" ->
          t = :math.pi() * (1.25 + 0.5 * frac)
          {x0, y0} = {b.cx + b.rx * 0.85 * :math.cos(t), b.cy + b.ry * 0.85 * :math.sin(t)}
          len = 34 + 12 * rand(s, {:al, i})
          {tx, ty} = {x0 + len * :math.cos(t), y0 + len * :math.sin(t) - 6}
          {mx, my} = {(x0 + tx) / 2, (y0 + ty) / 2}
          side = if :math.cos(t) < 0, do: -1, else: 1

          d =
            "M#{n(x0)} #{n(y0)} L#{n(tx)} #{n(ty)} M#{n(mx)} #{n(my)} l#{side * 12} -6 M#{n((mx + tx) / 2)} #{n((my + ty) / 2)} l#{-side * 9} -9"

          [
            ~s|<path d="#{d}" fill="none" stroke="#{p.ink}" stroke-width="6" stroke-linecap="round"/>|,
            ~s|<path d="#{d}" fill="none" stroke="#{p.eye}" stroke-width="2.6" stroke-linecap="round"/>|
          ]

        "fronds" ->
          t = :math.pi() * (1.15 + 0.7 * frac)
          {x0, y0} = {b.cx + b.rx * 0.9 * :math.cos(t), b.cy + b.ry * 0.9 * :math.sin(t)}
          deg = t * 180 / :math.pi()

          ~s|<ellipse cx="#{n(x0 + 14 * :math.cos(t))}" cy="#{n(y0 + 14 * :math.sin(t))}" rx="18" ry="6" transform="rotate(#{n(deg)} #{n(x0 + 14 * :math.cos(t))} #{n(y0 + 14 * :math.sin(t))})" fill="#{p.glow}" stroke="#{p.ink}" stroke-width="2"/>|
      end
    end
  end

  # a limb that tapers from `width` at its root to a point, along a curve
  defp tentacle({x0, y0}, {qx, qy}, {x1, y1}, width) do
    steps = 14

    spine =
      for k <- 0..steps do
        t = k / steps
        u = 1 - t
        x = u * u * x0 + 2 * u * t * qx + t * t * x1
        y = u * u * y0 + 2 * u * t * qy + t * t * y1
        # direction of travel, for the normal
        dx = 2 * u * (qx - x0) + 2 * t * (x1 - qx)
        dy = 2 * u * (qy - y0) + 2 * t * (y1 - qy)
        len = max(:math.sqrt(dx * dx + dy * dy), 0.001)
        w = width * (1 - t) + 0.8
        {x, y, -dy / len * w, dx / len * w}
      end

    left = for {x, y, nx, ny} <- spine, do: {x + nx, y + ny}
    right = for {x, y, nx, ny} <- Enum.reverse(spine), do: {x - nx, y - ny}
    polygon(left ++ right)
  end

  # ---------- face ----------

  defp eyes(a, m, b, p) do
    scale = min(b.rx, b.ry) / 52
    center = if rem(a["eyes"], 2) == 1, do: [{0.0, -0.1, 14}], else: []

    pairs =
      [{0.42, -0.34, 10}, {0.36, 0.14, 8}, {0.7, -0.06, 6.5}] |> Enum.take(div(a["eyes"], 2))

    # with an even count and no centre eye, the first pair moves in and grows
    pairs =
      if center == [] and pairs != [],
        do: List.update_at(pairs, 0, fn _ -> {0.34, -0.18, 12} end),
        else: pairs

    spots =
      center ++
        Enum.flat_map(pairs, fn {dx, dy, r} -> [{-dx, dy, r}, {dx, dy, r}] end)

    gaze = {rand(b.seed, :gaze_x) * 2 - 1, rand(b.seed, :gaze_y) * 2 - 1}

    for {{dx, dy, r}, i} <- Enum.with_index(spots) do
      jitter = if b.symmetric, do: 0.0, else: (rand(b.seed, {:eye, i}) - 0.5) * 4
      x = b.cx + dx * b.rx + jitter
      y = b.cy + dy * b.ry + jitter
      eye(x, y, r * scale, m, p, gaze)
    end
  end

  defp eye(x, y, r, %{"faded" => true}, p, _gaze) do
    ~s|<path d="M#{n(x - r)} #{n(y)} Q#{n(x)} #{n(y + r * 0.7)} #{n(x + r)} #{n(y)}" fill="none" stroke="#{p.ink}" stroke-width="2.2" stroke-linecap="round"/>|
  end

  defp eye(x, y, r, m, p, {gx, gy}) do
    open = if m["sociability"] == 0, do: 0.62, else: 0.85
    pupil = r * (0.2 + 0.08 * m["lack"])
    {px, py} = {x + gx * r * 0.22, y + gy * r * 0.15}

    [
      ~s|<ellipse cx="#{n(x)}" cy="#{n(y)}" rx="#{n(r)}" ry="#{n(r * open)}" fill="#{p.eye}" stroke="#{p.ink}" stroke-width="2"/>|,
      ~s|<circle cx="#{n(px)}" cy="#{n(py)}" r="#{n(min(r * 0.6, r * open - 1))}" fill="#{p.glow}"/>|,
      ~s|<circle cx="#{n(px)}" cy="#{n(py)}" r="#{n(pupil)}" fill="#{p.ink}"/>|,
      ~s|<circle cx="#{n(px - pupil * 0.5)}" cy="#{n(py - pupil * 0.6)}" r="#{n(max(1.0, r * 0.12))}" fill="#{p.eye}"/>|
    ]
  end

  defp mouth(a, m, b, p) do
    y = b.cy + b.ry * 0.5
    x = b.cx
    hungry = m["vigor"] <= 1 and not m["faded"]

    cond do
      a["form"] == "maw" ->
        w = b.rx * 0.75

        teeth =
          for i <- 0..6,
              do:
                "#{n(x - w + i * w / 3.5)} #{n(y - 2)} #{n(x - w + (i + 0.5) * w / 3.5)} #{n(y + 7)}"

        open = if hungry, do: 16, else: 10

        [
          ~s|<path d="M#{n(x - w)} #{n(y - 2)} Q#{n(x)} #{n(y + open * 2)} #{n(x + w)} #{n(y - 2)}Z" fill="#{p.ink}"/>|,
          ~s|<polyline points="#{Enum.join(teeth, " ")}" fill="none" stroke="#{p.eye}" stroke-width="2" stroke-linejoin="round"/>|
        ]

      hungry ->
        ~s|<ellipse cx="#{x}" cy="#{n(y)}" rx="7" ry="9" fill="#{p.ink}"/>|

      true ->
        ~s|<path d="M#{n(x - 12)} #{n(y)} q6 4 12 0 t12 0" fill="none" stroke="#{p.ink}" stroke-width="2.2" stroke-linecap="round"/>|
    end
  end

  # ---------- ground and signs of mood ----------

  defp ground(m, b, p, seed) do
    {ax, ay, aw, ah} = @art

    stars =
      for i <- 1..14 do
        ~s|<circle cx="#{n(ax + aw * rand(seed, {:star, i}))}" cy="#{n(ay + ah * 0.6 * rand(seed, {:star_y, i}))}" r="#{n(0.6 + 1.2 * rand(seed, {:star_r, i}))}" fill="#{p.eye}" opacity=".5"/>|
      end

    ring_r = max(b.rx, b.ry) + 20

    ring =
      cond do
        m["register"] == "symbolic" or m["unknotted"] ->
          dash = if m["unknotted"], do: "40 14 6 22", else: "2 5"

          ~s|<circle cx="#{b.cx}" cy="#{b.cy}" r="#{ring_r}" fill="none" stroke="#{p.glow}" stroke-width="#{if m["unknotted"], do: 3, else: 5}" stroke-dasharray="#{dash}" opacity=".8"/>|

        true ->
          ~s|<circle cx="#{b.cx}" cy="#{b.cy - 6}" r="#{ring_r}" fill="#{p.shade}" opacity=".22"/>|
      end

    [~s|<rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}" fill="#{p.bg}"/>|, stars, ring]
  end

  defp signs(m, b, p, _seed) do
    {ax, ay, aw, ah} = @art

    [
      # it longs for: a token of the desired resource, bottom left
      if(m["desire"],
        do:
          ~s|<circle cx="#{ax + 16}" cy="#{ay + ah - 16}" r="7" fill="#{res(m["desire"])}" stroke="#{p.ink}" stroke-width="2"/>|,
        else: ""
      ),
      # the objet a, once anxiety has revealed it, floats above
      if(m["objet_a"],
        do:
          ~s|<path d="M#{ax + aw - 20} #{ay + 12} l7 9 -7 9 -7 -9Z" fill="#{res(m["objet_a"])}" stroke="#{p.ink}" stroke-width="2"/>|,
        else: ""
      ),
      if(m["mourning"] and not m["faded"],
        do:
          ~s|<path d="M#{n(b.cx - b.rx * 0.42)} #{n(b.cy - b.ry * 0.1)} q-5 10 0 13 q5 -3 0 -13Z" fill="#7fd6d0" stroke="#{p.ink}" stroke-width="1.4"/>|,
        else: ""
      ),
      # whispering: sound rising beside its head
      if(m["whispering"] and not m["faded"],
        do:
          for(
            k <- 1..3,
            do:
              ~s|<path d="M#{n(b.cx + b.rx + 4 + 6 * k)} #{n(b.cy - b.ry * 0.5 - 8 * k)} a#{6 * k} #{6 * k} 0 0 1 0 #{12 * k}" fill="none" stroke="#{p.glow}" stroke-width="2.4" stroke-linecap="round" opacity="#{n(1 - k * 0.2)}"/>|
          ),
        else: ""
      )
    ]
  end

  defp frame(name, p) do
    {_ax, ay, _aw, ah} = @art
    top = ay + ah
    shown = if String.length(name) > 22, do: String.slice(name, 0, 21) <> "…", else: name

    fit =
      if String.length(shown) > 15,
        do: ~s| textLength="170" lengthAdjust="spacingAndGlyphs"|,
        else: ""

    [
      ~s|<rect x="8" y="8" width="184" height="214" fill="none" stroke="#{p.ink}" stroke-width="2"/>|,
      ~s|<rect x="1" y="1" width="198" height="258" fill="none" stroke="#{p.ink}" stroke-width="2"/>|,
      ~s|<text x="100" y="#{top + 25}" text-anchor="middle" font-family="VT323, 'IBM Plex Mono', ui-monospace, monospace" font-size="22" fill="#{p.ink}"#{fit}>#{esc(shown)}</text>|
    ]
  end

  # ---------- helpers ----------

  defp saturation(%{"faded" => true}), do: "0"
  defp saturation(%{"vigor" => v}) when v <= 1, do: "0.45"
  defp saturation(_), do: "1"

  defp res(resource), do: Map.get(@resource_colors, resource, "#bbbbbb")

  @doc false
  # a stable number in [0, 1) for a seed and a label
  def rand(seed, label), do: :erlang.phash2({seed, label}, 1_000_000) / 1_000_000

  # a closed Catmull-Rom curve through the points, as cubic Béziers
  defp smooth(points) do
    pts = List.to_tuple(points)
    count = tuple_size(pts)
    at = fn i -> elem(pts, rem(i + count, count)) end
    {x0, y0} = at.(0)

    segments =
      for i <- 0..(count - 1) do
        {ax, ay} = at.(i - 1)
        {bx, by} = at.(i)
        {cx, cy} = at.(i + 1)
        {dx, dy} = at.(i + 2)

        "C#{n(bx + (cx - ax) / 6)} #{n(by + (cy - ay) / 6)} #{n(cx - (dx - bx) / 6)} #{n(cy - (dy - by) / 6)} #{n(cx)} #{n(cy)}"
      end

    "M#{n(x0)} #{n(y0)}" <> Enum.join(segments) <> "Z"
  end

  defp polygon([{x0, y0} | rest]) do
    "M#{n(x0)} #{n(y0)}" <> Enum.map_join(rest, fn {x, y} -> "L#{n(x)} #{n(y)}" end) <> "Z"
  end

  defp n(x) when is_integer(x), do: Integer.to_string(x)
  defp n(x), do: :erlang.float_to_binary(x / 1, decimals: 1)

  defp esc(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
