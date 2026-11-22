defmodule Lofi.Portrait.Svg do
  @moduledoc """
  Procedural portraits, drawn as SVG in black-and-white ink, in the manner of
  horror manga, inside a classic Mac OS window:

    * greys only: screentone dots for tone, hatching for shadow and
      cross-hatching for the deepest shadow, solid spotted blacks for focus;
    * **silhouette first**: a head and a torso in proportions taken from the
      name, limbs and spines that break the outline, a creature that looms
      and spills out of the frame;
    * **one hero feature** (`anatomy["hero"]`), the darkest mass or the
      brightest white, so the eye goes there first;
    * biomechanical beings grow cables, ports and segmented plates;
    * the ground behind it: manga focus lines, a hatched megastructure,
      slanting rain, or a black void that lights it only at its edges;
    * **light**: hatching on the far side, contour lines following the body,
      a rim of bare paper on the near side;
    * **expression** from mood: brows, lids and mouth.

  Everything random is a hash of the name's seed and a label (`rand/2`), so a
  name always gives the same creature. `silhouette: true` draws only the
  filled silhouette, for judging designs.
  """
  @behaviour Lofi.Portrait.Renderer

  @w 200
  @h 260
  # the picture, inside the window (the window's title bar sits above it)
  @art {8, 8, 184, 214}
  @bottom 222
  @title 26

  @paper "#ebe9e4"
  @light "#cfccc5"
  @mid "#8f8b84"
  @darkest "#2a2926"
  @black "#111110"
  @platinum "#d4d1ca"

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
          use(id, "heroback", @black),
          use(id, "shape", @black),
          use(id, "herofront", @black)
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
    head_k = %{"small" => 0.82, "medium" => 1.0, "large" => 1.2}[a["head"]] || 1.0
    lean = (%{"left" => -1, "none" => 0, "right" => 1}[a["lean"]] || 0) * j.(:lean, 8, 18)

    {torso, heads, neck, opts} =
      case a["form"] do
        "bulb" ->
          th = j.(:th, 30, 40)
          hr = j.(:hr, 48, 56) * head_k

          {{100, 226, j.(:tw, 34, 44), th}, [{100 + lean * 0.5, 226 - th - hr * 0.45, hr}], 0,
           %{}}

        "spire" ->
          {{100, 236, j.(:tw, 30, 40), j.(:th, 84, 100)},
           [{100 + lean, j.(:hy, 66, 80), j.(:hr, 25, 31) * head_k}], j.(:nw, 9, 13),
           %{taper: 0.3}}

        "maw" ->
          th = j.(:th, 64, 76)
          hr = j.(:hr, 30, 36) * head_k

          {{100, 220, j.(:tw, 74, 86), th}, [{100 + lean * 0.6, 220 - th - hr * 0.2, hr}], 0,
           %{taper: 0.15}}

        "cluster" ->
          count = 2 + rem(div(s, 11), 2)

          heads =
            for i <- 0..(count - 1) do
              t = -0.85 + 1.7 * i / (count - 1)
              rr = j.({:hr, i}, 25, 32) * head_k

              {100 + :math.sin(t) * 56 + lean * 0.4,
               128 - :math.cos(t) * 52 + j.({:hy, i}, -6, 6), rr}
            end

          {{100, 228, j.(:tw, 54, 62), j.(:th, 60, 70)}, heads, j.(:nw, 8, 11), %{taper: 0.2}}

        "veil" ->
          {{100, 244, j.(:tw, 60, 70), j.(:th, 140, 156)},
           [{100 + lean * 0.3, j.(:hy, 114, 126), j.(:hr, 26, 31) * head_k}], 0,
           %{taper: 0.55, hood: true}}
      end

    # loom: scale about the bottom centre, then keep the head(s) inside the top
    scale = if a["looming"], do: j.(:loom, 1.18, 1.32), else: j.(:scale, 0.94, 1.08)
    shift = j.(:ox, -9, 9)
    place = fn {x, y} -> {100 + (x - 100) * scale + shift, @bottom + (y - @bottom) * scale} end

    {tx, ty, trx, try_} = torso
    {tx, ty} = place.({tx, ty})

    heads =
      for {hx, hy, hr} <- heads, do: place.({hx, hy}) |> then(fn {x, y} -> {x, y, hr * scale} end)

    top = heads |> Enum.map(fn {_x, y, hr} -> y - hr end) |> Enum.min()
    down = max(0.0, 22 - top)
    heads = for {hx, hy, hr} <- heads, do: {hx, hy + down, hr}

    r = %{
      seed: s,
      hero: a["hero"],
      tone: if(m["faded"], do: "light", else: a["tone"] || "light"),
      ground: a["ground"] || "focus",
      biomech: a["biomech"] == true,
      torso: {tx, ty + down, trx * scale, try_ * scale},
      heads: heads,
      neck: neck * scale,
      taper: Map.get(opts, :taper, 0.0),
      hood: Map.get(opts, :hood, false),
      light: if(a["light"] == "left", do: -1, else: 1),
      symmetric: a["symmetric"] == true or m["register"] == "imaginary",
      jagged: m["register"] == "real",
      smooth: m["generosity"] == 2,
      spines: m["generosity"] == 0 or m["register"] == "real"
    }

    Map.put(r, :limbs, limb_specs(r, m))
  end

  # every limb and neck, as {root, control, tip, root width, tip width, layer}
  defp limb_specs(r, m) do
    {tx, ty, trx, try_} = r.torso

    necks =
      if r.neck > 0 do
        for {{hx, hy, _hr}, i} <- Enum.with_index(r.heads) do
          {fx, fy} = {tx + (hx - tx) * 0.35, ty - try_ * 0.82}
          ctrl = {(fx + hx) / 2 + (rand(r.seed, {:neck, i}) - 0.5) * 20, (fy + hy) / 2}
          {{fx, fy}, ctrl, {hx, hy}, r.neck, r.neck * 0.8, :neck}
        end
      else
        []
      end

    count = rem(div(r.seed, 7), 3) + 2

    sides =
      for i <- 0..(count - 1) do
        layer = if rem(i, 4) >= 2, do: :front, else: :behind
        side = if rem(i, 2) == 0, do: -1, else: 1
        row = div(i, 2)
        x0 = tx + side * trx * (0.78 - 0.18 * row)
        y0 = ty - try_ * (0.62 - 0.22 * row)
        len = 50 + 14 * (m["wanderlust"] || 1) + 22 * rand(r.seed, {:ll, i})

        {ctrl, tip} =
          cond do
            layer == :front ->
              {{x0 + side * len * 0.45, y0 + len * 0.35},
               {x0 + side * len * 0.15, y0 + len * 0.95}}

            rand(r.seed, {:reach, i}) > 0.5 ->
              {{x0 + side * len * 0.75, y0 + len * 0.1},
               {x0 + side * len * 0.85, y0 - len * 0.65}}

            true ->
              {{x0 + side * len * 0.55, y0 + len * 0.75},
               {x0 + side * len * 0.95, y0 + len * 0.25}}
          end

        {{x0, y0}, ctrl, tip, 9.5, 0.8, layer}
      end

    necks ++ sides
  end

  # ---------- defs ----------

  defp defs(r, m, id, seed) do
    {ax, ay, aw, ah} = @art
    lx = r.light

    [
      "<defs>",
      ~s|<clipPath id="#{id}-art"><rect x="#{ax}" y="#{ay}" width="#{aw}" height="#{ah}"/></clipPath>|,
      ~s|<g id="#{id}-shape">|,
      body_shapes(r),
      "</g>",
      ~s|<g id="#{id}-heroback">|,
      hero_back(r),
      "</g>",
      ~s|<g id="#{id}-herofront">|,
      hero_front(r, m),
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
        use(id, "heroback", "#fff"),
        "</g>",
        use(id, "shape", "#000"),
        use(id, "heroback", "#000")
      ]),
      mask(id, "behind", [
        ~s|<rect x="0" y="0" width="#{@w}" height="#{@h}" fill="#fff"/>|,
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
    {hx, hy, hr} = main_head(r)
    eyes = eye_spots(a, r)
    void = r.ground == "void"
    line = if void, do: @paper, else: @black

    [
      ground(r, id),
      # hero parts behind the body: the darkest mass (pale in the void)
      ~s|<g mask="url(##{id}-behind)">#{use(id, "heroback", if(void, do: @light, else: @black))}</g>|,
      ring(m, r, line),
      ghost(m, id, line),
      body_ink(r, id),
      contours(r, id),
      fill_rect(id, @paper, "rim", ~s| opacity=".9"|),
      markings(a, r),
      if(m["faded"], do: cracks(r), else: ""),
      hood_interior(r),
      use(
        id,
        "herofront",
        hero_ink(r),
        nil,
        ~s| stroke="#{@black}" stroke-width="1.6" stroke-linejoin="round"|
      ),
      maw_interior(a, r),
      ribs(r),
      cables(r),
      eye_whites(eyes, m),
      teeth(a, r),
      irises(eyes, m, gaze(r)),
      lids(eyes, m, r),
      # the ink line: outline, details, pupils, brows, mouth
      fill_rect(id, line, "outline"),
      hero_lines(r),
      pupils(eyes, m, gaze(r), if(r.hood or r.tone == "dark", do: @paper, else: @black)),
      brows(eyes, m, {hx, hy, hr}, if(r.tone == "dark", do: @paper, else: @black)),
      mouth(a, m, r),
      signs(m, r),
      ~s|<rect x="0" y="0" width="#{@w}" height="#{@h}" filter="url(##{id}-grain)" opacity=".28"/>|
    ]
  end

  defp main_head(r), do: hd(r.heads)
  defp maw?(a, r), do: r.hero == "maw" or a["form"] == "maw"

  # the hero in front is printed as the strongest contrast to the body
  defp hero_ink(r) do
    cond do
      r.hero == "mask" -> @paper
      r.tone == "dark" -> @paper
      true -> @black
    end
  end

  # ---------- ground ----------

  defp ground(r, id) do
    {ax, ay, aw, ah} = @art
    {hx, hy, hr} = main_head(r)
    s = r.seed
    base = if r.ground == "void", do: @black, else: @paper

    detail =
      case r.ground do
        "focus" ->
          # manga focus lines converging on the head, leaving it a clear field
          for i <- 0..89 do
            t = 2 * :math.pi() * (i + rand(s, {:fl, i}) * 0.8) / 90
            r0 = hr * (1.75 + 0.9 * rand(s, {:fl0, i}))
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

  # ---------- the body ----------

  defp body_ink(r, id) do
    case r.tone do
      "dark" ->
        [
          use(id, "shape", @darkest),
          fill_rect(id, @black, "core"),
          # what light there is falls in screentone on the near side
          ~s|<g mask="url(##{id}-body)">#{fill_rect(id, "url(##{id}-ptone)", "lit", ~s| opacity=".55"|)}</g>|
        ]

      tone ->
        [
          use(id, "shape", if(tone == "mid", do: @light, else: @paper)),
          fill_rect(
            id,
            "url(##{id}-#{if tone == "mid", do: "tone2", else: "tone1"})",
            "body",
            ~s| opacity=".75"|
          ),
          fill_rect(id, "url(##{id}-hatch)", "shade"),
          fill_rect(id, "url(##{id}-xhatch)", "core")
        ]
    end
  end

  # contour lines that follow the body's form, on its shadowed side
  defp contours(r, id) do
    {tx, ty, trx, try_} = r.torso
    colour = if r.tone == "dark", do: @paper, else: @black
    opacity = if r.tone == "dark", do: ".45", else: ".7"

    torso =
      for k <- [0.82, 0.66, 0.5] do
        ~s|<path d="#{blob(r, :torso, tx, ty, trx * k, try_ * k, taper: r.taper)}" fill="none" stroke="#{colour}" stroke-width=".9"/>|
      end

    heads =
      for {{hx, hy, hr}, i} <- Enum.with_index(r.heads), not r.hood, k <- [0.8, 0.6] do
        squash = 0.86 + 0.26 * rand(r.seed, {:squash, i})

        ~s|<path d="#{blob(r, {:head, i}, hx, hy + hr * 0.08, hr * k, hr * squash * k, [])}" fill="none" stroke="#{colour}" stroke-width=".8"/>|
      end

    [~s|<g mask="url(##{id}-shade)" opacity="#{opacity}">|, torso, heads, "</g>"]
  end

  defp body_shapes(r) do
    {tx, ty, trx, try_} = r.torso

    torso =
      blob(r, :torso, tx, ty, trx, try_, taper: r.taper, flare: if(r.hood, do: 0.25, else: 0.0))

    limb_paths = fn layer ->
      for {from, ctrl, tip, w0, w1, ^layer} <- r.limbs,
          do: ~s|<path d="#{limb(from, ctrl, tip, w0, w1)}"/>|
    end

    heads =
      if r.hood do
        []
      else
        for {{hx, hy, hr}, i} <- Enum.with_index(r.heads) do
          squash = 0.86 + 0.26 * rand(r.seed, {:squash, i})
          ~s|<path d="#{blob(r, {:head, i}, hx, hy, hr, hr * squash, [])}"/>|
        end
      end

    [
      limb_paths.(:behind),
      ~s|<path d="#{torso}"/>|,
      limb_paths.(:neck),
      heads,
      head_parts(r),
      spines(r),
      limb_paths.(:front)
    ]
  end

  # small features on the head itself (the hero feature is separate)
  defp head_parts(%{hood: true}), do: []

  defp head_parts(r) do
    {hx, hy, hr} = main_head(r)

    case rem(div(r.seed, 23), 4) do
      0 ->
        for side <- [-1, 1] do
          {bx, by} = {hx + side * hr * 0.6, hy - hr * 0.7}

          ~s|<path d="#{limb({bx, by}, {bx + side * hr * 0.5, by - hr * 0.2}, {bx + side * hr * 0.55, by - hr * 0.75}, hr * 0.13, 0.5)}"/>|
        end

      1 ->
        for side <- [-1, 1] do
          {bx, by} = {hx + side * hr * 0.9, hy - hr * 0.1}

          ~s|<path d="M#{n(bx)} #{n(by - hr * 0.25)} L#{n(bx + side * hr * 0.75)} #{n(by - hr * 0.55)} L#{n(bx + side * hr * 0.35)} #{n(by + hr * 0.25)}Z"/>|
        end

      _ ->
        []
    end
  end

  defp spines(%{spines: false}), do: []

  defp spines(r) do
    {tx, ty, trx, try_} = r.torso

    for i <- 0..6 do
      t = :math.pi() * (1.18 + 0.64 * i / 6)
      {x0, y0} = ellipse_pt(tx, ty, trx * 0.97, try_ * 0.97, t - 0.11, r.taper)
      {x1, y1} = ellipse_pt(tx, ty, trx * 0.97, try_ * 0.97, t + 0.11, r.taper)
      {px, py} = ellipse_pt(tx, ty, trx * 1.22, try_ * 1.16, t, r.taper)
      ~s|<path d="M#{n(x0)} #{n(y0)} L#{n(px)} #{n(py)} L#{n(x1)} #{n(y1)}Z"/>|
    end
  end

  defp ellipse_pt(cx, cy, rx, ry, t, taper) do
    s = :math.sin(t)
    {cx + rx * :math.cos(t) * (1 - taper * max(0.0, -s)), cy + ry * s}
  end

  # segmented plates across necks and the limbs in front
  defp ribs(%{biomech: false}), do: []

  defp ribs(r) do
    colour = if r.tone == "dark", do: @paper, else: @black

    for {from, ctrl, tip, w0, w1, layer} <- r.limbs, layer in [:neck, :front] do
      for {x, y, nx, ny} <- spine(from, ctrl, tip, w0, w1, 12) |> Enum.slice(2..10) do
        ~s|<path d="M#{n(x + nx * 0.95)} #{n(y + ny * 0.95)} L#{n(x - nx * 0.95)} #{n(y - ny * 0.95)}" stroke="#{colour}" stroke-width="1.1"/>|
      end
    end
  end

  # cables hanging from ports in its flesh
  defp cables(%{biomech: false}), do: []

  defp cables(r) do
    {tx, ty, trx, try_} = r.torso
    count = 2 + rem(div(r.seed, 31), 3)

    for i <- 0..(count - 1) do
      side = if rem(i, 2) == 0, do: -1, else: 1
      t = :math.pi() * (1.25 + 0.5 * rand(r.seed, {:cable, i}))
      {x0, y0} = ellipse_pt(tx, ty, trx * 0.8, try_ * 0.8, t, r.taper)
      x1 = x0 + side * (40 + 60 * rand(r.seed, {:cable_x, i}))
      y1 = @bottom + 10
      d = "M#{n(x0)} #{n(y0)} Q#{n((x0 + x1) / 2)} #{n(max(y0, y1) + 25)} #{n(x1)} #{n(y1)}"

      [
        ~s|<path d="#{d}" fill="none" stroke="#{@black}" stroke-width="4"/>|,
        ~s|<path d="#{d}" fill="none" stroke="#{@paper}" stroke-width="1.4"/>|,
        ~s|<circle cx="#{n(x0)}" cy="#{n(y0)}" r="3.4" fill="#{@black}"/>|,
        ~s|<circle cx="#{n(x0)}" cy="#{n(y0)}" r="1.2" fill="#{@paper}"/>|
      ]
    end
  end

  # ---------- the hero feature ----------

  defp hero_back(r) do
    {hx, hy, hr} = main_head(r)
    s = r.seed

    case r.hero do
      "crown" ->
        k = 5 + rem(div(s, 5), 3)

        for i <- 0..(k - 1) do
          f = i / (k - 1)
          t = :math.pi() * (1.15 + 0.7 * f)
          len = hr * (0.7 + 0.35 * rand(s, {:crown, i})) * (1 - 0.35 * abs(f - 0.5))
          {bx, by} = {hx + hr * 0.82 * :math.cos(t), hy + hr * 0.82 * :math.sin(t)}
          {px, py} = {bx + len * :math.cos(t), by + len * :math.sin(t)}
          {nx, ny} = {-:math.sin(t) * hr * 0.16, :math.cos(t) * hr * 0.16}
          bend = (f - 0.5) * hr * 0.3

          ~s|<path d="M#{n(bx - nx)} #{n(by - ny)} Q#{n((bx + px) / 2 + bend)} #{n((by + py) / 2)} #{n(px)} #{n(py)} Q#{n((bx + px) / 2 + bend * 0.3)} #{n((by + py) / 2 + 3)} #{n(bx + nx)} #{n(by + ny)}Z"/>|
        end

      "antlers" ->
        for side <- [-1, 1] do
          {bx, by} = {hx + side * hr * 0.55, hy - hr * 0.72}
          {ex, ey} = {bx + side * hr * 1.25, by - hr * 1.05}
          {mx, my} = {(bx + ex) / 2 + side * hr * 0.15, (by + ey) / 2 + hr * 0.1}

          tines =
            for {f, dx, dy} <- [{0.35, -0.05, -0.55}, {0.62, 0.2, -0.5}, {0.85, 0.42, -0.2}] do
              {px, py} = {bx + (ex - bx) * f, by + (ey - by) * f}
              "M#{n(px)} #{n(py)} l#{n(side * dx * hr)} #{n(dy * hr)}"
            end

          ~s|<path d="M#{n(bx)} #{n(by)} Q#{n(mx)} #{n(my)} #{n(ex)} #{n(ey)} #{Enum.join(tines, " ")}" fill="none" stroke="currentColor" stroke-width="#{n(hr * 0.17)}" stroke-linecap="round" stroke-linejoin="round"/>|
        end

      "frill" ->
        k = 13

        pts =
          for i <- 0..(2 * k - 1) do
            t = :math.pi() * (0.8 + 1.4 * i / (2 * k - 1))
            rad = if rem(i, 2) == 0, do: hr * (1.75 + 0.15 * rand(s, {:frill, i})), else: hr * 1.2
            {hx + rad * :math.cos(t), hy + rad * :math.sin(t)}
          end

        ~s|<path d="#{polygon([{hx, hy + hr * 0.2} | pts])}"/>|

      "halo_eyes" ->
        ~s|<circle cx="#{n(hx)}" cy="#{n(hy - hr * 0.1)}" r="#{n(hr * 1.5)}" fill="none" stroke="currentColor" stroke-width="#{n(hr * 0.3)}"/>|

      _ ->
        []
    end
  end

  defp hero_front(r, _m) do
    {hx, hy, hr} = main_head(r)
    s = r.seed

    case r.hero do
      "mask" ->
        ~s|<path d="#{mask_path(hx, hy + hr * 0.02, hr * 0.82, hr * 1.05)}"/>|

      "beard" ->
        k = 4 + rem(div(s, 3), 3)

        for i <- 0..(k - 1) do
          f = i / (k - 1) - 0.5
          {x0, y0} = {hx + f * hr * 1.3, hy + hr * 0.55}
          len = hr * (1.1 + 0.6 * rand(s, {:beard, i}))
          curl = (rand(s, {:bc, i}) - 0.5) * hr * 1.2

          ~s|<path d="#{limb({x0, y0}, {x0 + curl, y0 + len * 0.5}, {x0 + f * hr * 0.9 - curl * 0.4, y0 + len}, hr * 0.13, 0.5)}"/>|
        end

      "maw" ->
        {mx, my, w, h} = maw_box(r)

        ~s|<path d="M#{n(mx - w - 5)} #{n(my - 3)} Q#{n(mx)} #{n(my - h * 0.45)} #{n(mx + w + 5)} #{n(my - 3)} Q#{n(mx)} #{n(my + h * 1.55)} #{n(mx - w - 5)} #{n(my - 3)}Z"/>|

      "great_eye" ->
        [{x, y, er} | _] = eye_spots(%{"eyes" => 1}, r)
        ~s|<ellipse cx="#{n(x)}" cy="#{n(y)}" rx="#{n(er * 1.32)}" ry="#{n(er * 1.12)}"/>|

      _ ->
        []
    end
  end

  defp mask_path(cx, cy, w, h) do
    "M#{n(cx - w)} #{n(cy - h * 0.55)} Q#{n(cx)} #{n(cy - h * 1.0)} #{n(cx + w)} #{n(cy - h * 0.55)} " <>
      "L#{n(cx + w * 0.75)} #{n(cy + h * 0.35)} Q#{n(cx)} #{n(cy + h * 1.0)} #{n(cx - w * 0.75)} #{n(cy + h * 0.35)}Z"
  end

  defp maw_box(r) do
    {tx, ty, trx, try_} = r.torso
    {hx, hy, hr} = main_head(r)

    cond do
      r.hood -> {hx, hy + hr * 1.7, hr * 0.75, hr * 0.4}
      r.neck == 0 and hy + hr > ty - try_ -> {hx, hy + hr * 0.42, hr * 0.62, hr * 0.42}
      true -> {tx, ty - try_ * 0.5, trx * 0.55, try_ * 0.3}
    end
  end

  # fine detail on the hero
  defp hero_lines(r) do
    {hx, hy, hr} = main_head(r)

    case r.hero do
      "mask" ->
        cy = hy + hr * 0.02

        [
          ~s|<path d="M#{n(hx)} #{n(cy - hr * 0.95)} V#{n(cy - hr * 0.6)} M#{n(hx)} #{n(cy + hr * 0.5)} V#{n(cy + hr * 0.95)}" stroke="#{@black}" stroke-width="2.2" fill="none"/>|,
          for k <- [-1, 1] do
            ~s|<path d="M#{n(hx + k * hr * 0.25)} #{n(cy + hr * 0.55)} q#{n(k * hr * 0.15)} #{n(hr * 0.1)} #{n(k * hr * 0.3)} 0" stroke="#{@black}" stroke-width="1.2" fill="none"/>|
          end
        ]

      "frill" ->
        for i <- 0..12 do
          t = :math.pi() * (0.8 + 1.4 * i / 12)

          ~s|<path d="M#{n(hx + hr * 1.05 * :math.cos(t))} #{n(hy + hr * 1.05 * :math.sin(t))} L#{n(hx + hr * 1.62 * :math.cos(t))} #{n(hy + hr * 1.62 * :math.sin(t))}" stroke="#{@paper}" stroke-width="1.2" opacity=".8"/>|
        end

      "halo_eyes" ->
        for i <- 0..8,
            t = :math.pi() * (0.75 + 1.5 * i / 8),
            {x, y} = {hx + hr * 1.5 * :math.cos(t), hy - hr * 0.1 + hr * 1.5 * :math.sin(t)},
            y < hy + hr * 0.2 do
          er = hr * 0.12

          [
            ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(er)}" fill="#{@paper}" stroke="#{@black}" stroke-width="1.3"/>|,
            ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(er * 0.32)}" fill="#{@black}"/>|
          ]
        end

      "beard" ->
        # suckers
        k = 4 + rem(div(r.seed, 3), 3)

        for i <- 0..(k - 1), step <- [0.75, 1.0, 1.25] do
          f = i / (k - 1) - 0.5

          ~s|<circle cx="#{n(hx + f * hr * 1.3 + (rand(r.seed, {:bc, i}) - 0.5) * hr * 0.4 * step)}" cy="#{n(hy + hr * (0.55 + 0.5 * step))}" r="1.3" fill="#{if r.tone == "dark", do: @black, else: @paper}"/>|
        end

      _ ->
        []
    end
  end

  # ---------- dark places ----------

  defp hood_interior(%{hood: true} = r) do
    {hx, hy, hr} = main_head(r)

    ~s|<ellipse cx="#{n(hx)}" cy="#{n(hy)}" rx="#{n(hr * 0.95)}" ry="#{n(hr * 1.1)}" fill="#{@black}"/>|
  end

  defp hood_interior(_r), do: ""

  defp maw_interior(a, r) do
    if maw?(a, r) do
      {mx, my, w, h} = maw_box(r)

      ~s|<path d="M#{n(mx - w)} #{n(my)} Q#{n(mx)} #{n(my - h * 0.25)} #{n(mx + w)} #{n(my)} Q#{n(mx)} #{n(my + h * 1.3)} #{n(mx - w)} #{n(my)}Z" fill="#{@black}"/>|
    else
      ""
    end
  end

  defp teeth(a, r) do
    if maw?(a, r) do
      {mx, my, w, h} = maw_box(r)
      k = 7

      top =
        for i <- 0..(k - 1) do
          x = mx - w * 0.85 + i * 1.7 * w / (k - 1)
          y = my - h * 0.1 + abs(i - (k - 1) / 2) * 0.6

          ~s|<path d="M#{n(x - w * 0.1)} #{n(y)} L#{n(x)} #{n(y + h * 0.42)} L#{n(x + w * 0.1)} #{n(y)}Z" fill="#{@paper}"/>|
        end

      bottom =
        for i <- 0..(k - 2) do
          x = mx - w * 0.6 + i * 1.2 * w / (k - 2)
          y = my + h * 0.95

          ~s|<path d="M#{n(x - w * 0.08)} #{n(y)} L#{n(x)} #{n(y - h * 0.35)} L#{n(x + w * 0.08)} #{n(y)}Z" fill="#{@paper}"/>|
        end

      [top, bottom]
    else
      []
    end
  end

  # ---------- eyes ----------

  # {x, y, r} for every eye, spread over the heads; the great eye comes first
  defp eye_spots(a, r) do
    total = a["eyes"] || 1
    count = length(r.heads)
    per = for i <- 0..(count - 1), do: max(1, div(total + count - 1 - i, count))

    r.heads
    |> Enum.zip(per)
    |> Enum.with_index()
    |> Enum.flat_map(fn {{{hx, hy, hr}, k}, i} ->
      great = i == 0 and r.hero == "great_eye"
      big = if r.hood, do: 1.35, else: 1.0

      jitter = fn e ->
        if r.symmetric, do: 0.0, else: (rand(r.seed, {:eye, i, e}) - 0.5) * hr * 0.08
      end

      k
      |> layout(great)
      |> Enum.with_index()
      |> Enum.map(fn {{dx, dy, er}, e} ->
        {hx + dx * hr + jitter.(e), hy + dy * hr + jitter.(e + 9), er * hr * big}
      end)
    end)
  end

  # in head radii
  defp layout(1, false), do: [{0.0, -0.08, 0.32}]
  defp layout(1, true), do: [{0.0, -0.04, 0.5}]

  defp layout(count, true) do
    mid = (count - 2) / 2
    small = for k <- 0..(count - 2), do: {(k - mid) * 0.32, -0.74 + abs(k - mid) * 0.12, 0.12}
    [{0.0, 0.02, 0.46} | small]
  end

  defp layout(count, false) do
    centre = if rem(count, 2) == 1, do: [{0.0, -0.1, 0.27}], else: []

    pairs =
      [{0.42, -0.3, 0.21}, {0.38, 0.2, 0.16}, {0.74, -0.04, 0.12}] |> Enum.take(div(count, 2))

    pairs =
      if centre == [] and pairs != [],
        do: List.replace_at(pairs, 0, {0.34, -0.14, 0.25}),
        else: pairs

    centre ++ Enum.flat_map(pairs, fn {dx, dy, er} -> [{-dx, dy, er}, {dx, dy, er}] end)
  end

  defp openness(m), do: if(m["lack"] >= 3, do: 0.95, else: 0.78)
  defp gaze(r), do: -0.22 * r.light

  defp eye_whites(_eyes, %{"faded" => true}), do: []

  defp eye_whites(eyes, m) do
    o = openness(m)

    for {x, y, er} <- eyes,
        do:
          ~s|<ellipse cx="#{n(x)}" cy="#{n(y)}" rx="#{n(er)}" ry="#{n(er * o)}" fill="#{@paper}"/>|
  end

  defp irises(_eyes, %{"faded" => true}, _g), do: []

  defp irises(eyes, m, g) do
    o = openness(m)

    for {x, y, er} <- eyes do
      ri = er * min(0.62, o - 0.12)

      [
        ~s|<circle cx="#{n(x + g * er)}" cy="#{n(y)}" r="#{n(ri)}" fill="#{@mid}"/>|,
        # a ring of fine lines, as an inked iris
        ~s|<circle cx="#{n(x + g * er)}" cy="#{n(y)}" r="#{n(ri * 0.75)}" fill="none" stroke="#{@black}" stroke-width="#{n(max(0.5, ri * 0.5))}" stroke-dasharray="0.6 1.1" opacity=".8"/>|
      ]
    end
  end

  defp pupils(eyes, %{"faded" => true}, _g, line) do
    for {x, y, er} <- eyes do
      ~s|<path d="M#{n(x - er)} #{n(y)} Q#{n(x)} #{n(y + er * 0.6)} #{n(x + er)} #{n(y)}" fill="none" stroke="#{line}" stroke-width="2.2" stroke-linecap="round"/>|
    end
  end

  defp pupils(eyes, m, g, _line) do
    o = openness(m)
    # horror: high lack shrinks the pupil to a pinpoint
    size = if m["lack"] >= 3, do: 0.1, else: 0.24

    for {x, y, er} <- eyes do
      px = x + g * er

      [
        ~s|<ellipse cx="#{n(x)}" cy="#{n(y)}" rx="#{n(er)}" ry="#{n(er * o)}" fill="none" stroke="#{@black}" stroke-width="#{n(max(1.5, er * 0.14))}"/>|,
        ~s|<circle cx="#{n(px)}" cy="#{n(y)}" r="#{n(max(1.0, er * size))}" fill="#{@black}"/>|,
        ~s|<circle cx="#{n(px - er * 0.24)}" cy="#{n(y - er * 0.26)}" r="#{n(max(0.9, er * 0.12))}" fill="#{@paper}"/>|
      ]
    end
  end

  # heavy lids when it is starving or withdrawn
  defp lids(eyes, m, r) do
    if not m["faded"] and (m["vigor"] <= 1 or m["sociability"] == 0) do
      o = openness(m)
      fill = if r.tone == "dark", do: @darkest, else: @light

      for {x, y, er} <- eyes do
        ~s|<path d="M#{n(x - er)} #{n(y)} A#{n(er)} #{n(er * o)} 0 0 1 #{n(x + er)} #{n(y)} Q#{n(x)} #{n(y - er * 0.05)} #{n(x - er)} #{n(y)}Z" fill="#{fill}" stroke="#{@black}" stroke-width="1.4"/>|
      end
    else
      []
    end
  end

  defp brows(eyes, m, {hx, _hy, hr}, colour) do
    kind =
      cond do
        m["faded"] -> nil
        m["unknotted"] or m["register"] == "real" -> :angry
        m["mourning"] or m["vigor"] <= 1 -> :sad
        m["lack"] >= 3 -> :wide
        true -> nil
      end

    for {x, y, er} <- eyes, kind != nil, er >= hr * 0.15 do
      top = y - er * 1.3

      tilt =
        case kind do
          :angry -> er * 0.32
          :sad -> -er * 0.32
          :wide -> 0.0
        end

      {ly, ry} =
        cond do
          x < hx - 1 -> {top - tilt / 2, top + tilt / 2}
          x > hx + 1 -> {top + tilt / 2, top - tilt / 2}
          true -> {top, top}
        end

      bend = if kind == :wide, do: -er * 0.4, else: 0

      ~s|<path d="M#{n(x - er * 0.9)} #{n(ly)} Q#{n(x)} #{n((ly + ry) / 2 + bend)} #{n(x + er * 0.9)} #{n(ry)}" fill="none" stroke="#{colour}" stroke-width="#{n(max(2.0, er * 0.22))}" stroke-linecap="round"/>|
    end
  end

  defp mouth(a, m, r) do
    {hx, hy, hr} = main_head(r)
    y = hy + hr * 0.5
    ink = if r.tone == "dark", do: @paper, else: @black

    cond do
      maw?(a, r) or r.hood or r.hero in ["beard", "mask"] ->
        []

      m["faded"] ->
        ~s|<path d="M#{n(hx - hr * 0.2)} #{n(y)} h#{n(hr * 0.4)}" stroke="#{ink}" stroke-width="2" stroke-linecap="round"/>|

      m["vigor"] <= 1 ->
        ~s|<ellipse cx="#{n(hx)}" cy="#{n(y + hr * 0.02)}" rx="#{n(hr * 0.13)}" ry="#{n(hr * 0.18)}" fill="#{@black}" stroke="#{ink}" stroke-width="1"/>|

      m["whispering"] ->
        ~s|<circle cx="#{n(hx)}" cy="#{n(y)}" r="#{n(hr * 0.08)}" fill="#{@black}" stroke="#{ink}" stroke-width="1"/>|

      m["unknotted"] or m["register"] == "real" ->
        w = hr * 0.32

        pts =
          for i <- 0..6,
              do: "#{n(hx - w + i * w / 3)} #{n(y + if(rem(i, 2) == 0, do: 0, else: hr * 0.07))}"

        ~s|<polyline points="#{Enum.join(pts, " ")}" fill="none" stroke="#{ink}" stroke-width="2" stroke-linejoin="round"/>|

      m["mourning"] ->
        ~s|<path d="M#{n(hx - hr * 0.22)} #{n(y + hr * 0.08)} Q#{n(hx)} #{n(y - hr * 0.08)} #{n(hx + hr * 0.22)} #{n(y + hr * 0.08)}" fill="none" stroke="#{ink}" stroke-width="2.2" stroke-linecap="round"/>|

      m["vigor"] >= 3 ->
        ~s|<path d="M#{n(hx - hr * 0.24)} #{n(y - hr * 0.04)} Q#{n(hx)} #{n(y + hr * 0.14)} #{n(hx + hr * 0.24)} #{n(y - hr * 0.04)}" fill="none" stroke="#{ink}" stroke-width="2.2" stroke-linecap="round"/>|

      true ->
        ~s|<path d="M#{n(hx - hr * 0.2)} #{n(y)} q#{n(hr * 0.1)} #{n(hr * 0.06)} #{n(hr * 0.2)} 0 t#{n(hr * 0.2)} 0" fill="none" stroke="#{ink}" stroke-width="2" stroke-linecap="round"/>|
    end
  end

  # ---------- texture and mood ----------

  defp markings(a, r) do
    {tx, ty, trx, try_} = r.torso
    s = r.seed
    ink = if r.tone == "dark", do: @paper, else: @black

    spot = fn k ->
      {tx - trx * 0.7 + trx * 1.4 * rand(s, {k, :x}),
       ty - try_ * 0.75 + try_ * 0.6 * rand(s, {k, :y})}
    end

    marks =
      case a["markings"] do
        "rings" ->
          for i <- 1..2 do
            {x, y} = spot.({:ring, i})

            for k <- 1..2,
                do:
                  ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{4 * k + 2}" fill="none" stroke="#{ink}" stroke-width="1.3"/>|
          end

        "dots" ->
          for i <- 1..12 do
            {x, y} = spot.({:dot, i})

            ~s|<circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(1.2 + 1.8 * rand(s, {:dot_r, i}))}" fill="#{ink}"/>|
          end

        "runes" ->
          for i <- 1..5 do
            {x, y} = spot.({:rune, i})
            pts = for k <- 0..2, do: "#{n(x + 8 * rand(s, {:rx, i, k}) - 4)} #{n(y + 4 * k)}"

            ~s|<polyline points="#{Enum.join(pts, " ")}" fill="none" stroke="#{ink}" stroke-width="1.4" stroke-linecap="round"/>|
          end

        _veins ->
          for i <- 1..3 do
            x0 = tx - trx * 0.5 + trx * rand(s, {:vein, i})

            ~s|<path d="M#{n(x0)} #{n(ty)} Q#{n(x0 + 24 * rand(s, {:vq, i}) - 12)} #{n(ty - try_ * 0.4)} #{n(x0 + 18 * rand(s, {:ve, i}) - 9)} #{n(ty - try_ * 0.75)}" fill="none" stroke="#{ink}" stroke-width="1.6" stroke-linecap="round"/>|
          end
      end

    [~s|<g opacity=".4">|, marks, "</g>"]
  end

  defp cracks(r) do
    {hx, hy, hr} = main_head(r)

    for i <- 1..3 do
      x = hx - hr * 0.5 + hr * rand(r.seed, {:crack, i})
      y = hy - hr

      ~s|<polyline points="#{n(x)} #{n(y)} #{n(x + 7)} #{n(y + 18)} #{n(x - 3)} #{n(y + 32)} #{n(x + 5)} #{n(y + 48)}" fill="none" stroke="#{@black}" stroke-width="1.5"/>|
    end
  end

  # the Symbolic as a ring of runes about the head; a loosened knot breaks it
  defp ring(m, r, line) do
    {hx, hy, hr} = main_head(r)

    cond do
      m["unknotted"] ->
        ~s|<circle cx="#{n(hx)}" cy="#{n(hy)}" r="#{n(hr * 1.42)}" fill="none" stroke="#{line}" stroke-width="2.4" stroke-dasharray="38 12 5 20"/>|

      m["register"] == "symbolic" ->
        ~s|<circle cx="#{n(hx)}" cy="#{n(hy)}" r="#{n(hr * 1.42)}" fill="none" stroke="#{line}" stroke-width="4" stroke-dasharray="1.5 5"/>|

      true ->
        ""
    end
  end

  # the Imaginary: a double, slightly shifted
  defp ghost(m, id, line) do
    if m["register"] == "imaginary" and not m["faded"] do
      ~s|<use href="##{id}-shape" xlink:href="##{id}-shape" fill="none" stroke="#{line}" color="#{line}" stroke-width="1.2" stroke-dasharray="3 2" transform="translate(7 -6)" opacity=".7"/>|
    else
      ""
    end
  end

  defp signs(m, r) do
    {ax, ay, aw, ah} = @art
    {hx, hy, hr} = main_head(r)

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
      if(m["mourning"] and not m["faded"],
        do:
          ~s|<path d="M#{n(hx - hr * 0.42)} #{n(hy - hr * 0.02)} q-#{n(hr * 0.1)} #{n(hr * 0.22)} 0 #{n(hr * 0.28)} q#{n(hr * 0.1)} -#{n(hr * 0.06)} 0 -#{n(hr * 0.28)}Z" fill="#{@paper}" stroke="#{@black}" stroke-width="1.2"/>|,
        else: ""
      ),
      if(m["whispering"] and not m["faded"],
        do:
          for k <- 1..3 do
            x = hx + r.light * (hr + 4 + 6 * k)
            sweep = if r.light > 0, do: 1, else: 0
            colour = if r.ground == "void", do: @paper, else: @black

            ~s|<path d="M#{n(x)} #{n(hy - hr * 0.3 - 7 * k)} a#{6 * k} #{6 * k} 0 0 #{sweep} 0 #{12 * k}" fill="none" stroke="#{colour}" stroke-width="2.2" stroke-linecap="round" opacity="#{n(1 - k * 0.2)}"/>|
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

  defp blob(r, salt, cx, cy, rx, ry, opts) do
    n_pts = if r.jagged, do: 30, else: 18
    taper = Keyword.get(opts, :taper, 0.0)
    flare = Keyword.get(opts, :flare, 0.0)
    calm = if r.smooth, do: 0.5, else: 1.0

    points =
      for i <- 0..(n_pts - 1) do
        t = 2 * :math.pi() * i / n_pts
        psi = t + :math.pi() / 2

        wobble =
          for k <- 2..4, reduce: 1.0 do
            acc ->
              amp = (0.025 + 0.05 * rand(r.seed, {salt, :amp, k})) * calm

              phase =
                if r.symmetric, do: 0.0, else: 2 * :math.pi() * rand(r.seed, {salt, :phase, k})

              acc + amp * :math.cos(k * psi + phase)
          end

        spike = if r.jagged, do: if(rem(i, 2) == 0, do: 1.08, else: 0.92), else: 1.0
        s = :math.sin(t)
        x_scale = 1 - taper * max(0.0, -s) + flare * max(0.0, s)
        {cx + rx * :math.cos(t) * wobble * spike * x_scale, cy + ry * s * wobble * spike}
      end

    if r.jagged, do: polygon(points), else: smooth(points)
  end

  # points along a limb's curve with its half-width as a normal vector
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
