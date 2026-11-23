defmodule Lofi.Portrait.Svg do
  @moduledoc """
  Procedural portraits, drawn as SVG in black-and-white ink inside a classic
  Mac OS window.

  Every being is the **same figure**: a dark hooded robe filling the frame,
  its face a black hollow. What tells beings apart is the **mask** over that
  hollow, in bare bone against the dark:

    * its **outline** (skull, oval, beak, shield, moon, slab, lantern, visor),
      the first thing you read at a glance;
    * its **eye holes**, one per part of the name, in one of a few shapes,
      with pale pupils glinting in the black;
    * a **mouth** (stitches, a grille, a slit, teeth, a smile, or none) and a
      **mark** (a stripe, tears, runes, a split, dots);
    * what **crowns** it: horns, antlers, a crown, a halo, spikes, ears that
      break the hood's outline, or nothing;
    * the hood (round, peaked, deep) and what it stands before (manga focus
      lines, a hatched megastructure, rain, or the void).

  **Mood** shows in how the mask sits and what surrounds the figure: a mask
  slipping askew when starved, blazing eyes when full, wide pupils with
  lack, cracks for the Real, a ring of runes for the Symbolic, a double for
  the Imaginary, a tear in mourning, an open hand when generous, a staff
  when it wanders, and a grey robe and empty eyes once it has faded.

  Everything random is a hash of the name's seed and a label (`rand/2`), so a
  name always gives the same mask. `silhouette: true` draws only the figure
  and the mask's outline, for judging whether masks read and differ.
  """
  @behaviour Lofi.Portrait.Renderer

  @w 200
  @h 260
  # the picture, inside the window (the window's title bar sits above it)
  @art {8, 8, 184, 214}
  @bottom 222
  @title 26

  @paper "#ebe9e4"
  @bone "#f8f7f3"
  @light "#cfccc5"
  @mid "#8f8b84"
  @darkest "#2a2926"
  @black "#111110"
  @platinum "#d4d1ca"

  # per mask: top edge, eye row, mouth row and mouth half-width (nil: no mouth),
  # in units of the mask's half-width, y down
  @masks %{
    "skull" => %{top: -1.25, eyes: -0.2, mouth: {0.9, 0.3}},
    "oval" => %{top: -1.2, eyes: -0.15, mouth: {0.68, 0.3}},
    "beak" => %{top: -1.15, eyes: -0.35, mouth: nil},
    "shield" => %{top: -1.1, eyes: -0.2, mouth: {0.72, 0.32}},
    "moon" => %{top: -1.0, eyes: -0.1, mouth: {0.55, 0.3}},
    "slab" => %{top: -1.3, eyes: -0.25, mouth: {0.82, 0.34}},
    "lantern" => %{top: -1.35, eyes: -0.15, mouth: {0.75, 0.3}},
    "visor" => %{top: -0.8, eyes: -0.24, mouth: nil}
  }

  @impl true
  def render(%{"anatomy" => a} = features, opts) do
    m = Map.get(features, "mood") || Lofi.Portrait.Features.mood(%{})
    name = Map.get(features, "name")
    frame? = Keyword.get(opts, :frame, true) and name != nil
    seed = a["seed"]
    id = "p#{seed}"
    r = rig(a, m)
    {ax, ay, aw, ah} = @art

    picture =
      if Keyword.get(opts, :silhouette, false) do
        [
          ~s|<rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}" fill="#{@paper}"/>|,
          use(id, "shape", @black),
          ~s|<g transform="#{tilt(r)}"><path d="#{mask_d(r)}" fill="#{@paper}"/></g>|
        ]
      else
        layers(a, m, r, id)
      end

    art = [~s|<g clip-path="url(##{id}-art)">|, picture, "</g>"]

    svg = [
      ~s|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="#{if frame?, do: "0 0 #{@w} #{@h}", else: "#{ax} #{ay} #{aw} #{ah}"}" width="#{if frame?, do: @w, else: aw}" height="#{if frame?, do: @h, else: ah}" role="img" aria-label="#{esc(Lofi.Portrait.prompt(features))}">|,
      defs(r, m, id, seed),
      if(frame?,
        do: [window(name), ~s|<g transform="translate(0 #{@title})">|, art, "</g>"],
        else: art
      ),
      "</svg>"
    ]

    {:ok, svg, "image/svg+xml"}
  end

  # ---------- the rig: where everything is ----------

  defp rig(a, m) do
    s = a["seed"]
    j = fn key, lo, hi -> lo + (hi - lo) * rand(s, key) end
    k = j.(:scale, 0.95, 1.05)
    hx = 100 + j.(:ox, -6, 6)
    hood = a["hood"] || "round"
    faded = m["faded"] == true
    starved = not faded and (m["vigor"] || 2) <= 1

    {hw, top, deep} =
      case hood do
        "peaked" -> {44 * k, 10, 0}
        "deep" -> {51 * k, 24, 6}
        _ -> {46 * k, 20, 0}
      end

    fy = 84 + deep
    droop = if rand(s, :droop) > 0.5, do: 1, else: -1

    tilt =
      cond do
        m["register"] == "imaginary" -> 0.0
        faded -> droop * 14.0
        starved -> droop * 8.0
        true -> j.(:tilt, -3, 3)
      end

    mask = if Map.has_key?(@masks, a["mask"]), do: a["mask"], else: "oval"

    %{
      seed: s,
      hood: hood,
      hx: hx,
      hw: hw,
      top: top,
      base: 132,
      sw: j.(:sw, 64, 72) * k,
      tip: hx + j.(:tip, -7, 7),
      face: {hx, fy, 30 * k * if(deep > 0, do: 1.06, else: 1.0), 39 * k},
      mx: hx,
      my: fy + 2 + if(starved or faded, do: 4, else: 0),
      mw: 23.5 * k,
      tilt: tilt,
      light: if(a["light"] == "left", do: -1, else: 1),
      ground: a["ground"] || "focus",
      mask: mask,
      meta: @masks[mask],
      crest: a["crest"] || "none",
      faded: faded
    }
  end

  # a point on the mask, in units of its half-width (before it is tilted)
  defp pt(r, u, v), do: {r.mx + u * r.mw, r.my + v * r.mw}
  defp tilt(r), do: "rotate(#{n(r.tilt)} #{n(r.mx)} #{n(r.my)})"
  defp head(r), do: {r.hx, r.top + 52, r.hw}

  # ---------- defs ----------

  defp defs(r, m, id, seed) do
    {ax, ay, aw, ah} = @art
    lx = r.light

    [
      "<defs>",
      ~s|<clipPath id="#{id}-art"><rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}"/></clipPath>|,
      ~s|<clipPath id="#{id}-face"><path d="#{mask_d(r)}"/></clipPath>|,
      ~s|<g id="#{id}-shape">|,
      body_shapes(r),
      "</g>",
      mask(id, "body", [use(id, "shape", "#fff")]),
      # the far side from the light; and deeper still, its core
      mask(id, "shade", [
        use(id, "shape", "#fff"),
        use(id, "shape", "#000", "translate(#{lx * 13} -12)")
      ]),
      mask(id, "core", [
        use(id, "shape", "#fff"),
        use(id, "shape", "#000", "translate(#{lx * 7} -7)")
      ]),
      mask(id, "lit", [use(id, "shape", "#fff", "translate(#{lx * 13} -12)")]),
      # a sliver of bare paper on the near side
      mask(id, "rim", [
        use(id, "shape", "#fff"),
        use(id, "shape", "#000", "translate(#{-lx * 2.4} 2.4)")
      ]),
      # the outer outline only
      mask(id, "outline", [
        ~s|<g stroke="#fff" stroke-width="#{if m["vigor"] >= 4, do: 5.6, else: 4.4}">|,
        use(id, "shape", "#fff"),
        "</g>",
        use(id, "shape", "#000")
      ]),
      # screentones and hatching
      pattern(id, "tone1", 3.0, 30, ~s|<circle cx="1.5" cy="1.5" r=".62" fill="#{@black}"/>|),
      pattern(id, "ptone", 3.0, 30, ~s|<circle cx="1.5" cy="1.5" r=".8" fill="#{@paper}"/>|),
      pattern(id, "tone2", 3.0, 30, ~s|<circle cx="1.5" cy="1.5" r="1.02" fill="#{@black}"/>|),
      pattern(
        id,
        "hatch",
        3.2,
        45 - lx * 10,
        ~s|<rect x="0" y="0" width="3.2" height=".75" fill="#{@black}"/>|
      ),
      pattern(
        id,
        "xhatch",
        3.0,
        45 + lx * 10,
        ~s|<rect x="0" y="0" width="3" height=".8" fill="#{@black}"/><rect x="0" y="0" width=".8" height="3" fill="#{@black}"/>|
      ),
      pattern(
        id,
        "rain",
        5.0,
        70,
        ~s|<rect x="0" y="0" width="5" height=".55" fill="#{@black}"/>|
      ),
      pattern(
        id,
        "vlines",
        2.4,
        0,
        ~s|<rect x="0" y="0" width=".7" height="2.4" fill="#{@black}"/>|
      ),
      # the classic 50% desktop pattern
      ~s|<pattern id="#{id}-dither" width="2" height="2" patternUnits="userSpaceOnUse"><rect width="1" height="1" fill="#{@black}"/><rect x="1" y="1" width="1" height="1" fill="#{@black}"/></pattern>|,
      ~s|<filter id="#{id}-grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="#{rem(seed, 997)}" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 0.07 0 0 0 0 0.07 0 0 0 0 0.07 0 0 0 -1.6 1.05"/></filter>|,
      "</defs>"
    ]
  end

  defp mask(id, name, body), do: [~s|<mask id="#{id}-#{name}">|, body, "</mask>"]

  defp pattern(id, name, size, angle, body) do
    ~s|<pattern id="#{id}-#{name}" width="#{size}" height="#{size}" patternUnits="userSpaceOnUse" patternTransform="rotate(#{n(angle)})">#{body}</pattern>|
  end

  defp use(id, what, colour, transform \\ nil, extra \\ "") do
    t = if transform, do: ~s| transform="#{transform}"|, else: ""

    ~s|<use href="##{id}-#{what}" xlink:href="##{id}-#{what}" fill="#{colour}" color="#{colour}"#{t}#{extra}/>|
  end

  defp fill_rect(id, fill, mask, extra \\ "") do
    ~s|<rect x="0" y="0" width="#{@w}" height="#{@h}" fill="#{fill}" mask="url(##{id}-#{mask})"#{extra}/>|
  end

  # ---------- the layers ----------

  defp layers(a, m, r, id) do
    void = r.ground == "void"
    line = if void, do: @paper, else: @black

    [
      ground(r, id),
      halo(r, line),
      staff(m, r, line),
      ring(m, r, line),
      ghost(m, id, line),
      body_ink(r, id),
      robe_lines(r, id),
      fill_rect(id, @paper, "rim", ~s| opacity=".9"|),
      face_hollow(r),
      fill_rect(id, line, "outline"),
      ~s|<g transform="#{tilt(r)}">|,
      crest_behind(r),
      the_mask(a, m, r, id),
      crest_front(r),
      "</g>",
      hand(m, r),
      signs(m, r, line),
      ~s|<rect x="0" y="0" width="#{@w}" height="#{@h}" filter="url(##{id}-grain)" opacity=".28"/>|
    ]
  end

  # ---------- ground ----------

  defp ground(r, id) do
    {ax, ay, aw, ah} = @art
    {hx, hy, hr} = head(r)
    s = r.seed
    base = if r.ground == "void", do: @black, else: @paper

    detail =
      case r.ground do
        "focus" ->
          # manga focus lines converging on the head, leaving it a clear field
          for i <- 0..89 do
            t = 2 * :math.pi() * (i + rand(s, {:fl, i}) * 0.8) / 90
            r0 = hr * (1.6 + 0.9 * rand(s, {:fl0, i}))
            r1 = 320
            w = 0.6 + 2.6 * rand(s, {:flw, i})
            {cx, cy} = {hx + r0 * :math.cos(t), hy + r0 * :math.sin(t)}
            {ox, oy} = {hx + r1 * :math.cos(t), hy + r1 * :math.sin(t)}
            {nx, ny} = {-:math.sin(t) * w, :math.cos(t) * w}

            ~s|<path d="M#{n(cx)} #{n(cy)} L#{n(ox + nx)} #{n(oy + ny)} L#{n(ox - nx)} #{n(oy - ny)}Z" fill="#{@black}"/>|
          end

        "structure" ->
          # a megastructure: tall hatched pillars with ledges, receding upward
          slabs =
            for i <- 0..6 do
              x = ax - 10 + (aw + 20) * rand(s, {:slab, i})
              w = 12 + 34 * rand(s, {:slab_w, i})
              top = ay - 10 + 70 * rand(s, {:slab_t, i})
              lean = (x - 100) * 0.08

              fill =
                Enum.at(
                  ["url(##{id}-vlines)", "url(##{id}-tone2)", @light, "url(##{id}-dither)"],
                  rem(i, 4)
                )

              ledges =
                for k <- 1..6 do
                  y = top + k * (24 + 10 * rand(s, {:ledge, i, k}))

                  ~s|<path d="M#{n(x + lean * (1 - (y - ay) / ah))} #{n(y)} h#{n(w)}" stroke="#{@black}" stroke-width="1.1"/>|
                end

              [
                ~s|<path d="M#{n(x + lean)} #{n(top)} h#{n(w * 0.86)} L#{n(x + w)} #{@bottom} H#{n(x)}Z" fill="#{fill}" opacity=".42" stroke="#{@black}" stroke-width=".9"/>|,
                ledges
              ]
            end

          [
            slabs,
            ~s|<circle cx="#{n(hx)}" cy="#{n(hy)}" r="#{n(hr * 1.6)}" fill="#{@paper}" opacity=".85"/>|
          ]

        "rain" ->
          [
            ~s|<rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}" fill="url(##{id}-rain)" opacity=".5"/>|,
            ~s|<circle cx="#{n(hx + r.light * hr * 0.5)}" cy="#{n(hy - hr * 0.3)}" r="#{n(hr * 1.8)}" fill="url(##{id}-tone1)" opacity=".7"/>|
          ]

        "void" ->
          ~s|<circle cx="#{n(hx)}" cy="#{n(hy)}" r="#{n(hr * 2.2)}" fill="#{@darkest}"/>|
      end

    floor =
      if r.ground == "void",
        do: "",
        else:
          ~s|<rect x="#{ax}" y="#{@bottom - 30}" width="#{aw}" height="30" fill="url(##{id}-dither)" opacity=".35"/>|

    [~s|<rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}" fill="#{base}"/>|, detail, floor]
  end

  # ---------- the figure ----------

  # the hood and the robe below it: always the same figure, in a few cuts
  defp body_shapes(r) do
    %{hx: hx, hw: hw, top: top, base: base, sw: sw} = r

    hood =
      case r.hood do
        "peaked" ->
          ~s|M#{n(hx - hw)} #{base} C#{n(hx - hw - 7)} #{base - 55} #{n(hx - hw * 0.6)} #{top + 24} #{n(r.tip)} #{top} C#{n(hx + hw * 0.6)} #{top + 24} #{n(hx + hw + 7)} #{base - 55} #{n(hx + hw)} #{base}Z|

        _ ->
          ~s|M#{n(hx - hw)} #{base} C#{n(hx - hw - 6)} #{base - 50} #{n(hx - hw * 0.78)} #{top} #{n(hx)} #{top} C#{n(hx + hw * 0.78)} #{top} #{n(hx + hw + 6)} #{base - 50} #{n(hx + hw)} #{base}Z|
      end

    robe =
      ~s|M#{n(hx - hw * 0.8)} #{base - 14} C#{n(hx - sw * 0.7)} #{base - 6} #{n(hx - sw)} #{base + 8} #{n(hx - sw - 2)} #{base + 40} L#{n(hx - sw - 14)} 240 L#{n(hx + sw + 14)} 240 L#{n(hx + sw + 2)} #{base + 40} C#{n(hx + sw)} #{base + 8} #{n(hx + sw * 0.7)} #{base - 6} #{n(hx + hw * 0.8)} #{base - 14}Z|

    ears =
      if r.crest == "ears" do
        tip = max(top - 22, 12)

        for side <- [-1, 1] do
          ~s|<path d="M#{n(hx + side * hw * 0.78)} #{top + 24} L#{n(hx + side * hw * 1.02)} #{tip} L#{n(hx + side * hw * 0.22)} #{top + 5}Z"/>|
        end
      else
        []
      end

    [~s|<path d="#{robe}"/>|, ~s|<path d="#{hood}"/>|, ears]
  end

  defp body_ink(%{faded: true}, id) do
    # faded: the robe goes grey
    [
      use(id, "shape", @light),
      fill_rect(id, "url(##{id}-tone2)", "body", ~s| opacity=".75"|),
      fill_rect(id, "url(##{id}-hatch)", "shade"),
      fill_rect(id, "url(##{id}-xhatch)", "core")
    ]
  end

  defp body_ink(_r, id) do
    [
      use(id, "shape", @darkest),
      fill_rect(id, @black, "core"),
      # what light there is falls in screentone on the near side
      ~s|<g mask="url(##{id}-body)">#{fill_rect(id, "url(##{id}-ptone)", "lit", ~s| opacity=".28"|)}</g>|
    ]
  end

  # folds of the hood and robe, and the robe's crossed front
  defp robe_lines(r, id) do
    %{hx: hx, hw: hw, top: top, base: base, sw: sw} = r
    {colour, opacity} = if r.faded, do: {@black, ".7"}, else: {@mid, ".6"}
    stroke = ~s|fill="none" stroke="#{colour}" stroke-linecap="round"|

    folds =
      for x <- [-0.84, -0.5, 0.5, 0.84] do
        bend = 6 * rand(r.seed, {:fold, x}) - 3

        ~s|<path d="M#{n(hx + x * sw)} #{base + 26} Q#{n(hx + x * sw * 1.06 + bend)} 196 #{n(hx + x * sw * 1.14)} 240" #{stroke} stroke-width="1.1"/>|
      end

    hood =
      for side <- [-1, 1] do
        ~s|<path d="M#{n(hx + side * hw * 0.5)} #{top + 12} Q#{n(hx + side * hw * 0.9)} #{base - 44} #{n(hx + side * hw * 0.72)} #{base - 4}" #{stroke} stroke-width="1.1"/>|
      end

    front = [
      ~s|<path d="M#{n(hx - hw * 0.55)} #{base - 6} Q#{n(hx - 4)} 168 #{n(hx + 18)} 240" #{stroke} stroke-width="1.5"/>|,
      ~s|<path d="M#{n(hx + hw * 0.55)} #{base - 6} Q#{n(hx + 8)} 150 #{n(hx + 2)} 180" #{stroke} stroke-width="1.5"/>|
    ]

    [~s|<g mask="url(##{id}-body)" opacity="#{opacity}">|, folds, hood, front, "</g>"]
  end

  # the black hollow in the hood the mask is set in
  defp face_hollow(r) do
    {fx, fy, rx, ry} = r.face

    [
      ~s|<ellipse cx="#{n(fx)}" cy="#{n(fy)}" rx="#{n(rx + 3)}" ry="#{n(ry + 3)}" fill="none" stroke="#{@mid}" stroke-width="1.2" opacity=".5"/>|,
      ~s|<ellipse cx="#{n(fx)}" cy="#{n(fy)}" rx="#{n(rx)}" ry="#{n(ry)}" fill="#{@black}"/>|
    ]
  end

  # ---------- the mask ----------

  defp mask_d(r) do
    ops =
      case r.mask do
        "skull" ->
          [
            {:m, -0.5, 1.2},
            {:l, -0.5, 0.6},
            {:c, -0.95, 0.5, -1.05, 0.0, -1.0, -0.4},
            {:c, -0.95, -1.05, -0.45, -1.25, 0.0, -1.25},
            {:c, 0.45, -1.25, 0.95, -1.05, 1.0, -0.4},
            {:c, 1.05, 0.0, 0.95, 0.5, 0.5, 0.6},
            {:l, 0.5, 1.2}
          ]

        "oval" ->
          ellipse(0.0, 0.0, 0.82, 1.2)

        "beak" ->
          [
            {:m, 0.0, -1.15},
            {:c, 0.6, -1.15, 0.95, -0.7, 0.92, -0.1},
            {:c, 0.9, 0.3, 0.5, 0.45, 0.28, 0.6},
            {:l, 0.0, 1.95},
            {:l, -0.28, 0.6},
            {:c, -0.5, 0.45, -0.9, 0.3, -0.92, -0.1},
            {:c, -0.95, -0.7, -0.6, -1.15, 0.0, -1.15}
          ]

        "shield" ->
          [
            {:m, -0.9, -1.1},
            {:l, 0.9, -1.1},
            {:l, 0.9, 0.2},
            {:c, 0.9, 0.8, 0.4, 1.1, 0.0, 1.35},
            {:c, -0.4, 1.1, -0.9, 0.8, -0.9, 0.2}
          ]

        "moon" ->
          ellipse(0.0, 0.0, 1.0, 1.0)

        "slab" ->
          poly([
            {-0.6, -1.3},
            {0.6, -1.3},
            {0.72, -1.18},
            {0.72, 1.18},
            {0.6, 1.3},
            {-0.6, 1.3},
            {-0.72, 1.18},
            {-0.72, -1.18}
          ])

        "lantern" ->
          poly([{0.0, -1.35}, {0.9, -0.7}, {0.9, 0.7}, {0.0, 1.35}, {-0.9, 0.7}, {-0.9, -0.7}])

        "visor" ->
          [
            {:m, -1.08, -0.62},
            {:c, -0.4, -0.92, 0.4, -0.92, 1.08, -0.62},
            {:l, 0.96, 0.3},
            {:c, 0.4, 0.12, -0.4, 0.12, -0.96, 0.3}
          ]
      end

    path(r, ops)
  end

  defp ellipse(cu, cv, ru, rv) do
    kk = 0.5523

    [
      {:m, cu, cv - rv},
      {:c, cu + kk * ru, cv - rv, cu + ru, cv - kk * rv, cu + ru, cv},
      {:c, cu + ru, cv + kk * rv, cu + kk * ru, cv + rv, cu, cv + rv},
      {:c, cu - kk * ru, cv + rv, cu - ru, cv + kk * rv, cu - ru, cv},
      {:c, cu - ru, cv - kk * rv, cu - kk * ru, cv - rv, cu, cv - rv}
    ]
  end

  defp poly([{u0, v0} | rest]), do: [{:m, u0, v0} | for({u, v} <- rest, do: {:l, u, v})]

  defp path(r, ops) do
    p = fn u, v ->
      {x, y} = pt(r, u, v)
      "#{n(x)} #{n(y)}"
    end

    Enum.map_join(ops, fn
      {:m, u, v} -> "M" <> p.(u, v)
      {:l, u, v} -> "L" <> p.(u, v)
      {:c, u1, v1, u2, v2, u, v} -> "C#{p.(u1, v1)} #{p.(u2, v2)} #{p.(u, v)}"
    end) <> "Z"
  end

  defp the_mask(a, m, r, id) do
    d = mask_d(r)
    lx = r.light
    {_, ty} = pt(r, 0, r.meta.top)
    {sx, sy} = pt(r, -lx * 1.0, 0.15)

    [
      ~s|<path d="#{d}" fill="#{if r.faded, do: @light, else: @bone}"/>|,
      if(a["ink"] == "ash",
        do: ~s|<path d="#{d}" fill="url(##{id}-tone1)" opacity=".5"/>|,
        else: ""
      ),
      ~s|<g clip-path="url(##{id}-face)">|,
      # the far side in hatching, and the hood's shadow across the brow
      ~s|<ellipse cx="#{n(sx)}" cy="#{n(sy)}" rx="#{n(r.mw * 0.6)}" ry="#{n(r.mw * 1.6)}" fill="url(##{id}-hatch)"/>|,
      if(r.mask == "visor",
        do: "",
        else:
          ~s|<ellipse cx="#{n(r.mx)}" cy="#{n(ty - r.mw * 0.25)}" rx="#{n(r.mw * 1.4)}" ry="#{n(r.mw * 0.5)}" fill="url(##{id}-hatch)" opacity=".7"/>|
      ),
      marks(a, r, id),
      if(r.faded or m["register"] == "real", do: cracks(r), else: ""),
      "</g>",
      mask_details(r),
      ~s|<path d="#{d}" fill="none" stroke="#{@black}" stroke-width="#{if m["vigor"] >= 4, do: 2.3, else: 1.8}" stroke-linejoin="round"/>|,
      mouth(a, m, r),
      eyes(a, m, r)
    ]
  end

  defp mask_details(r) do
    line = fn {u0, v0}, {u1, v1}, w ->
      {x0, y0} = pt(r, u0, v0)
      {x1, y1} = pt(r, u1, v1)

      ~s|<path d="M#{n(x0)} #{n(y0)} L#{n(x1)} #{n(y1)}" stroke="#{@black}" stroke-width="#{w}"/>|
    end

    case r.mask do
      "beak" -> [line.({0, 0.15}, {0, 1.85}, 1.0), line.({-0.12, 0.62}, {0.12, 0.62}, 1.0)]
      "lantern" -> [line.({-0.9, -0.7}, {0.9, -0.7}, 1.0), line.({-0.9, 0.7}, {0.9, 0.7}, 1.0)]
      "slab" -> line.({0, -1.3}, {0, -0.75}, 0.9)
      _ -> ""
    end
  end

  # where the eye holes are, as {x, y, radius}
  defp eye_spots(a, r) do
    count = a["eyes"] || 2
    ev = r.meta.eyes

    spots =
      if r.mask == "visor" do
        rr = min(0.24, 1.0 / count)

        for i <- 0..(count - 1),
            do: {if(count == 1, do: 0.0, else: -0.72 + 1.44 * i / (count - 1)), 0.0, rr}
      else
        layout(count)
      end

    for {u, dv, rr} <- spots do
      {x, y} = pt(r, u, ev + dv)
      {x, y, rr * r.mw}
    end
  end

  defp layout(1), do: [{0.0, 0.0, 0.3}]
  defp layout(2), do: [{-0.42, 0.0, 0.24}, {0.42, 0.0, 0.24}]
  defp layout(3), do: [{-0.42, 0.0, 0.21}, {0.42, 0.0, 0.21}, {0.0, -0.55, 0.16}]

  defp layout(4),
    do: [{-0.42, 0.0, 0.19}, {0.42, 0.0, 0.19}, {-0.2, -0.55, 0.14}, {0.2, -0.55, 0.14}]

  defp layout(count) do
    upper = count - 3

    [{-0.5, 0.0, 0.15}, {0.0, 0.0, 0.15}, {0.5, 0.0, 0.15}] ++
      for i <- 0..(upper - 1) do
        {if(upper == 1, do: 0.0, else: -0.45 + 0.9 * i / (upper - 1)), -0.5, 0.11}
      end
  end

  defp eyes(a, m, r) do
    spots = eye_spots(a, r)
    shape = a["eye_shape"] || "round"
    wide = (m["lack"] || 0) >= 3
    gaze = -0.18 * r.light

    for {{x, y, rr}, i} <- Enum.with_index(spots) do
      hole =
        case shape do
          "hollow" ->
            ~s|<ellipse cx="#{n(x)}" cy="#{n(y)}" rx="#{n(rr * 1.15)}" ry="#{n(rr * 1.3)}" fill="#{@black}"/>|

          "slit" ->
            ~s|<ellipse cx="#{n(x)}" cy="#{n(y)}" rx="#{n(rr * 1.25)}" ry="#{n(rr * 0.45)}" fill="#{@black}"/>|

          "almond" ->
            ~s|<path d="M#{n(x - rr * 1.25)} #{n(y)} Q#{n(x)} #{n(y - rr * 0.95)} #{n(x + rr * 1.25)} #{n(y)} Q#{n(x)} #{n(y + rr * 0.95)} #{n(x - rr * 1.25)} #{n(y)}Z" fill="#{@black}"/>|

          "ring" ->
            [
              ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(rr)}" fill="#{@black}"/>|,
              if(r.faded,
                do: "",
                else: ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(rr * 0.62)}" fill="#{@bone}"/>|
              )
            ]

          _ ->
            ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(rr)}" fill="#{@black}"/>|
        end

      pupil =
        cond do
          r.faded ->
            ""

          shape == "ring" ->
            ~s|<circle cx="#{n(x + gaze * rr)}" cy="#{n(y)}" r="#{n(rr * if(wide, do: 0.45, else: 0.28))}" fill="#{@black}"/>|

          true ->
            pr = rr * if(wide, do: 0.42, else: 0.26)
            pr = if shape == "slit", do: min(pr, rr * 0.34), else: pr

            ~s|<circle cx="#{n(x + gaze * rr)}" cy="#{n(y)}" r="#{n(pr)}" fill="#{@bone}"/>|
        end

      # full of ichor, the eyes blaze
      rays =
        if m["vigor"] >= 4 and not r.faded do
          for k <- 0..5 do
            t = :math.pi() * (k / 3 + 1 / 6)
            {c, s} = {:math.cos(t), :math.sin(t)}

            ~s|<path d="M#{n(x + c * rr * 1.6)} #{n(y + s * rr * 1.6)} L#{n(x + c * rr * 2.2)} #{n(y + s * rr * 2.2)}" stroke="#{@black}" stroke-width="1.1" stroke-linecap="round"/>|
          end
        else
          []
        end

      tear =
        if i == 0 and m["mourning"] and not r.faded do
          ~s|<path d="M#{n(x)} #{n(y + rr * 1.4)} q-#{n(rr * 0.5)} #{n(rr * 1.1)} 0 #{n(rr * 1.4)} q#{n(rr * 0.5)} -#{n(rr * 0.3)} 0 -#{n(rr * 1.4)}Z" fill="#{@paper}" stroke="#{@black}" stroke-width="1.1"/>|
        else
          ""
        end

      [hole, pupil, rays, tear]
    end
  end

  defp mouth(a, m, r) do
    case r.meta.mouth do
      nil ->
        ""

      {mv, mhw} ->
        {x, y} = pt(r, 0, mv)
        w = mhw * r.mw
        h = r.mw

        case a["mouth"] do
          "stitches" ->
            [
              ~s|<path d="M#{n(x - w)} #{n(y)} H#{n(x + w)}" stroke="#{@black}" stroke-width="1.6" stroke-linecap="round"/>|,
              for k <- 0..4 do
                sx = x - w * 0.8 + w * 0.4 * k

                ~s|<path d="M#{n(sx)} #{n(y - h * 0.12)} V#{n(y + h * 0.12)}" stroke="#{@black}" stroke-width="1.3"/>|
              end
            ]

          "grille" ->
            [
              ~s|<rect x="#{n(x - w)}" y="#{n(y - h * 0.16)}" width="#{n(w * 2)}" height="#{n(h * 0.32)}" fill="#{@black}"/>|,
              for k <- 1..4 do
                ~s|<path d="M#{n(x - w + w * 0.4 * k)} #{n(y - h * 0.16)} v#{n(h * 0.32)}" stroke="#{@bone}" stroke-width="1"/>|
              end
            ]

          "slit" ->
            ~s|<path d="M#{n(x - w)} #{n(y)} H#{n(x + w)}" stroke="#{@black}" stroke-width="2.4" stroke-linecap="round"/>|

          "teeth" ->
            [
              ~s|<rect x="#{n(x - w)}" y="#{n(y - h * 0.15)}" width="#{n(w * 2)}" height="#{n(h * 0.3)}" fill="#{@black}"/>|,
              for k <- 0..4 do
                ~s|<rect x="#{n(x - w + w * 0.4 * k + 0.7)}" y="#{n(y - h * 0.15 + 0.7)}" width="#{n(w * 0.4 - 1.4)}" height="#{n(h * 0.3 - 1.4)}" fill="#{@bone}"/>|
              end
            ]

          "smile" ->
            depth = if r.faded or m["vigor"] <= 1, do: 0.02, else: 0.3

            ~s|<path d="M#{n(x - w)} #{n(y - h * 0.08)} Q#{n(x)} #{n(y + h * depth)} #{n(x + w)} #{n(y - h * 0.08)}" fill="none" stroke="#{@black}" stroke-width="1.8" stroke-linecap="round"/>|

          _ ->
            ""
        end
    end
  end

  defp marks(a, r, id) do
    mw = r.mw
    {_, top} = pt(r, 0, r.meta.top)
    {_, ey} = pt(r, 0, r.meta.eyes)
    few = (a["eyes"] || 2) <= 2

    case a["mark"] do
      "stripe" ->
        ~s|<rect x="#{n(r.mx - mw * 0.12)}" y="#{n(r.my - mw * 2)}" width="#{n(mw * 0.24)}" height="#{n(mw * 4)}" fill="#{@black}"/>|

      "tears" ->
        for {x, y, rr} <- eye_spots(a, r) do
          [
            ~s|<path d="M#{n(x)} #{n(y + rr)} V#{n(y + rr + mw * 0.7)}" stroke="#{@black}" stroke-width="1.3"/>|,
            ~s|<circle cx="#{n(x)}" cy="#{n(y + rr + mw * 0.75)}" r="1.6" fill="#{@black}"/>|
          ]
        end

      "runes" ->
        spots =
          if few,
            do: for(k <- -1..1, do: {r.mx + k * mw * 0.35, top + mw * 0.42}),
            else: for(k <- 0..2, do: {r.mx + r.light * mw * 0.62, ey + mw * (0.38 + 0.3 * k)})

        for {{x, y}, i} <- Enum.with_index(spots) do
          s = mw * 0.09

          glyph =
            Enum.at(
              [
                "M#{n(x)} #{n(y - s)} V#{n(y + s)} M#{n(x - s)} #{n(y - s)} L#{n(x)} #{n(y)}",
                "M#{n(x - s)} #{n(y + s)} L#{n(x)} #{n(y - s)} L#{n(x + s)} #{n(y + s)}",
                "M#{n(x - s)} #{n(y - s)} H#{n(x + s)} M#{n(x)} #{n(y - s)} V#{n(y + s)}",
                "M#{n(x + s)} #{n(y - s)} L#{n(x - s)} #{n(y)} L#{n(x + s)} #{n(y + s)}"
              ],
              rem(:erlang.phash2({r.seed, :rune, i}), 4)
            )

          ~s|<path d="#{glyph}" fill="none" stroke="#{@black}" stroke-width="1.1" stroke-linecap="round"/>|
        end

      "split" ->
        side = if rand(r.seed, :split) > 0.5, do: 1, else: -1

        ~s|<rect x="#{n(if side > 0, do: r.mx, else: r.mx - mw * 1.3)}" y="#{n(r.my - mw * 2)}" width="#{n(mw * 1.3)}" height="#{n(mw * 4)}" fill="url(##{id}-tone2)"/>|

      "dots" ->
        cheeks =
          for side <- [-1, 1],
              do:
                ~s|<circle cx="#{n(r.mx + side * mw * 0.6)}" cy="#{n(ey + mw * 0.5)}" r="#{n(mw * 0.07)}" fill="#{@black}"/>|

        brow =
          if few,
            do:
              ~s|<circle cx="#{n(r.mx)}" cy="#{n(top + mw * 0.4)}" r="#{n(mw * 0.08)}" fill="#{@black}"/>|,
            else: ""

        [cheeks, brow]

      _ ->
        ""
    end
  end

  defp cracks(r) do
    {_, top} = pt(r, 0, r.meta.top)

    for i <- 1..2 do
      x = r.mx - r.mw * 0.6 + r.mw * 1.2 * rand(r.seed, {:crack, i})
      y = top - 1
      s = r.mw / 20

      ~s|<polyline points="#{n(x)} #{n(y)} #{n(x + 6 * s)} #{n(y + 12 * s)} #{n(x - 2 * s)} #{n(y + 22 * s)} #{n(x + 4 * s)} #{n(y + 34 * s)}" fill="none" stroke="#{@black}" stroke-width="1.3"/>|
    end
  end

  # ---------- what crowns it ----------

  defp crest_ink(r), do: ~s|fill="#{if r.faded, do: @light, else: @bone}" stroke="#{@black}"|

  # horns, antlers and spikes grow from behind the mask
  defp crest_behind(%{crest: "horns"} = r) do
    t = r.meta.top

    for side <- [-1, 1] do
      d =
        limb(
          pt(r, side * 0.5, t + 0.4),
          pt(r, side * 1.7, t - 0.1),
          pt(r, side * 1.45, t - 1.6),
          r.mw * 0.27,
          r.mw * 0.03
        )

      ~s|<path d="#{d}" #{crest_ink(r)} stroke-width="1.4" stroke-linejoin="round"/>|
    end
  end

  defp crest_behind(%{crest: "antlers"} = r) do
    t = r.meta.top
    q = fn u, v -> pt(r, u, v) |> then(fn {x, y} -> "#{n(x)} #{n(y)}" end) end

    d =
      for side <- [-1, 1] do
        "M#{q.(side * 0.45, t + 0.3)} Q#{q.(side * 1.4, t - 0.2)} #{q.(side * 1.5, t - 1.7)}" <>
          " M#{q.(side * 1.05, t - 0.3)} L#{q.(side * 0.8, t - 1.15)}" <>
          " M#{q.(side * 1.42, t - 0.95)} L#{q.(side * 2.0, t - 1.35)}"
      end
      |> Enum.join(" ")

    [
      ~s|<path d="#{d}" fill="none" stroke="#{@black}" stroke-width="5.6" stroke-linecap="round"/>|,
      ~s|<path d="#{d}" fill="none" stroke="#{if r.faded, do: @light, else: @bone}" stroke-width="3" stroke-linecap="round"/>|
    ]
  end

  defp crest_behind(%{crest: "spikes"} = r) do
    hh = -r.meta.top

    for i <- 0..8 do
      t = :math.pi() * (1.1 + 0.8 * i / 8)
      w = 0.12
      base = fn dt -> pt(r, :math.cos(t + dt) * 0.95, :math.sin(t + dt) * hh * 0.95) end
      {x0, y0} = base.(-w)
      {x1, y1} = base.(w)
      {x2, y2} = pt(r, :math.cos(t) * 1.7, :math.sin(t) * (hh + 0.7))

      ~s|<path d="M#{n(x0)} #{n(y0)} L#{n(x2)} #{n(y2)} L#{n(x1)} #{n(y1)}Z" #{crest_ink(r)} stroke-width="1.2" stroke-linejoin="round"/>|
    end
  end

  defp crest_behind(_r), do: ""

  # a crown sits on the mask's brow
  defp crest_front(%{crest: "crown"} = r) do
    t = r.meta.top
    b = t + 0.2

    pts =
      for i <- 0..10 do
        u = -0.8 + 1.6 * i / 10

        if rem(i, 2) == 0,
          do: pt(r, u, b),
          else: pt(r, u, t - if(i == 5, do: 0.8, else: 0.55))
      end

    {x0, y0} = pt(r, 0.8, b + 0.22)
    {x1, y1} = pt(r, -0.8, b + 0.22)

    points =
      (pts ++ [{x0, y0}, {x1, y1}]) |> Enum.map_join(" ", fn {x, y} -> "#{n(x)},#{n(y)}" end)

    ~s|<polygon points="#{points}" #{crest_ink(r)} stroke-width="1.4" stroke-linejoin="round"/>|
  end

  defp crest_front(_r), do: ""

  # a halo stands behind the whole figure
  defp halo(%{crest: "halo"} = r, line) do
    {hx, hy, hw} = head(r)

    [
      ~s|<circle cx="#{n(hx)}" cy="#{n(hy - 6)}" r="#{n(hw * 1.38)}" fill="none" stroke="#{line}" stroke-width="2.4"/>|,
      ~s|<circle cx="#{n(hx)}" cy="#{n(hy - 6)}" r="#{n(hw * 1.24)}" fill="none" stroke="#{line}" stroke-width="3" stroke-dasharray="1.5 4"/>|
    ]
  end

  defp halo(_r, _line), do: ""

  # ---------- temperament ----------

  # a wanderer leans on a staff
  defp staff(%{"wanderlust" => 2}, r, line) do
    x = r.hx - r.light * (r.sw - 4)
    y = r.top + 10

    [
      ~s|<path d="M#{n(x)} 240 V#{n(y)} q0 -12 #{n(r.light * 10)} -12 q#{n(r.light * 9)} 0 #{n(r.light * 9)} 10" fill="none" stroke="#{line}" stroke-width="5.4" stroke-linecap="round"/>|,
      ~s|<path d="M#{n(x)} 240 V#{n(y)} q0 -12 #{n(r.light * 10)} -12 q#{n(r.light * 9)} 0 #{n(r.light * 9)} 10" fill="none" stroke="#{@mid}" stroke-width="2.4" stroke-linecap="round"/>|
    ]
  end

  defp staff(_m, _r, _line), do: ""

  # a generous one holds out an open hand
  defp hand(%{"generosity" => 2}, %{faded: false} = r) do
    {px, py} = {r.hx + r.light * r.sw * 0.42, 192}

    fingers =
      for k <- 0..3 do
        t = -:math.pi() / 2 + (k - 1.5) * 0.32
        {fx, fy} = {px + :math.cos(t) * 13, py + :math.sin(t) * 13}
        "M#{n(px + :math.cos(t) * 4)} #{n(py + :math.sin(t) * 4)} L#{n(fx)} #{n(fy)}"
      end
      |> Enum.join(" ")

    thumb = "M#{n(px + r.light * 5)} #{n(py)} L#{n(px + r.light * 13)} #{n(py - 5)}"

    [
      ~s|<ellipse cx="#{n(px)}" cy="#{n(py + 9)}" rx="13" ry="6" fill="#{@black}"/>|,
      ~s|<path d="#{fingers} #{thumb}" fill="none" stroke="#{@black}" stroke-width="5.4" stroke-linecap="round"/>|,
      ~s|<ellipse cx="#{n(px)}" cy="#{n(py + 1)}" rx="8.6" ry="6.6" fill="#{@bone}" stroke="#{@black}" stroke-width="1.4"/>|,
      ~s|<path d="#{fingers} #{thumb}" fill="none" stroke="#{@bone}" stroke-width="2.8" stroke-linecap="round"/>|
    ]
  end

  defp hand(_m, _r), do: ""

  # ---------- mood signs ----------

  # the Symbolic as a ring of runes about the head; a loosened knot breaks it
  defp ring(m, r, line) do
    {hx, hy, hw} = head(r)

    cond do
      m["unknotted"] ->
        ~s|<circle cx="#{n(hx)}" cy="#{n(hy)}" r="#{n(hw * 1.5)}" fill="none" stroke="#{line}" stroke-width="2.4" stroke-dasharray="38 12 5 20"/>|

      m["register"] == "symbolic" ->
        ~s|<circle cx="#{n(hx)}" cy="#{n(hy)}" r="#{n(hw * 1.5)}" fill="none" stroke="#{line}" stroke-width="4" stroke-dasharray="1.5 5"/>|

      true ->
        ""
    end
  end

  # the Imaginary: a double, slightly shifted
  defp ghost(m, id, line) do
    if m["register"] == "imaginary" and not m["faded"] do
      ~s|<use href="##{id}-shape" xlink:href="##{id}-shape" fill="none" stroke="#{line}" color="#{line}" stroke-width="1.2" stroke-dasharray="3 2" transform="translate(9 -7)" opacity=".7"/>|
    else
      ""
    end
  end

  defp signs(m, r, line) do
    {ax, ay, aw, ah} = @art

    [
      # what it longs for, as a little label
      if(m["desire"],
        do: label(ax + 5, ay + ah - 17, String.replace(m["desire"], "_", " ")),
        else: ""
      ),
      if(m["objet_a"],
        do:
          ~s|<path d="M#{ax + aw - 16} #{ay + 6} l6 8 -6 8 -6 -8Z" fill="#{@black}" stroke="#{@paper}" stroke-width="1.4"/>|,
        else: ""
      ),
      if(m["whispering"] and not m["faded"],
        do:
          for k <- 1..3 do
            x = r.hx + r.light * (r.hw + 4 + 6 * k)
            y = r.my + r.mw * 0.4
            sweep = if r.light > 0, do: 1, else: 0

            ~s|<path d="M#{n(x)} #{n(y - 6 * k)} a#{6 * k} #{6 * k} 0 0 #{sweep} 0 #{12 * k}" fill="none" stroke="#{line}" stroke-width="2.2" stroke-linecap="round" opacity="#{n(1 - k * 0.2)}"/>|
          end,
        else: ""
      )
    ]
  end

  defp label(x, y, text) do
    w = String.length(text) * 5.4 + 8

    [
      ~s|<rect x="#{x}" y="#{y}" width="#{n(w)}" height="12" fill="#{@paper}" stroke="#{@black}" stroke-width="1"/>|,
      ~s|<rect x="#{x + 1.5}" y="#{y + 12}" width="#{n(w)}" height="1.5" fill="#{@black}"/>|,
      ~s|<text x="#{x + 4}" y="#{y + 9}" font-family="'IBM Plex Mono', ui-monospace, monospace" font-size="8.5" fill="#{@black}">#{esc(text)}</text>|
    ]
  end

  # a classic Mac OS window: platinum, a striped title bar with a close box
  defp window(name) do
    # an SVG shown as an image cannot load web fonts: size for a plain monospace
    shown = if String.length(name) > 18, do: String.slice(name, 0, 17) <> "…", else: name
    tw = String.length(shown) * 8.5 + 14
    fit = if tw > 150, do: ~s| textLength="136" lengthAdjust="spacingAndGlyphs"|, else: ""
    tw = min(tw, 150)

    stripes =
      for k <- 0..5,
          do: ~s|<path d="M5 #{n(6.5 + k * 2.6)} H195" stroke="#{@black}" stroke-width=".9"/>|

    [
      ~s|<rect x="1" y="1" width="198" height="258" fill="#{@platinum}" stroke="#{@black}" stroke-width="2"/>|,
      ~s|<rect x="2" y="2" width="196" height="1.2" fill="#fff" opacity=".7"/>|,
      stripes,
      ~s|<rect x="10" y="6" width="13" height="13" fill="#{@platinum}" stroke="#{@black}" stroke-width="1.2"/>|,
      ~s|<rect x="#{n(100 - tw / 2)}" y="4" width="#{n(tw)}" height="17" fill="#{@platinum}"/>|,
      ~s|<text x="100" y="17" text-anchor="middle" font-family="Monaco, Menlo, 'DejaVu Sans Mono', monospace" font-size="14" font-weight="bold" fill="#{@black}"#{fit}>#{esc(shown)}</text>|,
      ~s|<path d="M1 #{@title - 1} H199" stroke="#{@black}" stroke-width="1.5"/>|,
      ~s|<rect x="7" y="#{@title + 7}" width="186" height="216" fill="none" stroke="#{@black}" stroke-width="1.5"/>|
    ]
  end

  # ---------- geometry ----------

  # points along a curve with its half-width as a normal vector
  defp spine({x0, y0}, {qx, qy}, {x1, y1}, w0, w1, steps) do
    for k <- 0..steps do
      t = k / steps
      u = 1 - t
      x = u * u * x0 + 2 * u * t * qx + t * t * x1
      y = u * u * y0 + 2 * u * t * qy + t * t * y1
      dx = 2 * u * (qx - x0) + 2 * t * (x1 - qx)
      dy = 2 * u * (qy - y0) + 2 * t * (y1 - qy)
      len = max(:math.sqrt(dx * dx + dy * dy), 0.001)
      w = w0 * (1 - t) + w1 * t
      {x, y, -dy / len * w, dx / len * w}
    end
  end

  defp limb(from, ctrl, tip, w0, w1) do
    points = spine(from, ctrl, tip, w0, w1, 14)
    left = for {x, y, nx, ny} <- points, do: {x + nx, y + ny}
    right = for {x, y, nx, ny} <- Enum.reverse(points), do: {x - nx, y - ny}
    polygon(left ++ right)
  end

  # ---------- helpers ----------

  @doc false
  # a stable number in [0, 1) for a seed and a label
  def rand(seed, label), do: :erlang.phash2({seed, label}, 1_000_000) / 1_000_000

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
