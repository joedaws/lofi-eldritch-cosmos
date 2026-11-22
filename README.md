# Lofi Eldritch beings to study with
Simulation of a cosmos of eldritch beings trying to learn cooperation and social organization.

- The `Cosmos` application is an implementation of an
  entity component system (ECS) which is responsible for managing the data related to
  the simulation.

- The `Eldritch` library application is used to construct and interact with specific
  kinds of entities such as `Being` or `Node` entity.

- The `Lofi` application is a Phoenix app: accounts (generated with `mix phx.gen.auth`),
  the JSON api and the visualization. It talks only to `Eldritch`.

The toolchain is pinned in `.mise.toml` (Elixir 1.18, Erlang/OTP 27).

# Running the simulation

```bash
mix deps.get
mix cosmos.seed            # dream a landscape and awaken beings (asks before wiping old data)
mix phx.server             # start the cosmos and the web server (mix run --no-halt works too)
```

Then open **http://localhost:5454**. Anyone can watch; to take part,
**register** (top of the side panel). Registration asks for an email (to log in with)
and a display name (shown to others in the cosmos). You then log in with a one-time
link sent by email; in development no mail is sent and the link appears at
**http://localhost:5454/dev/mailbox**. In **Settings** you can add a password.

The **first account to register becomes the keeper** (admin): only the keeper sees
**▶ Stir** / speed / **New cosmos**, and seeds an empty cosmos from the page. The simulation
can also start on boot with `ELDRITCH_AUTOSTART=true mix run --no-halt`.

`mix cosmos.seed` options: `--yes` (wipe without asking), `--keep` (seed on top of
existing data), `--beings 12`, `--rings 6,10,14` (places on each ring of the landscape).

To clear the simulation use the destroy script (which will ask before destroying)

``` elixir
mix cosmos.destroy
```

## Your being

Each person may summon **one being** (the **My being** tab):

- **Name** it (or take one from the grimoire) and choose where it awakens. Its cause of
  desire (objet a) stays hidden, even from you, until the being shows anxiety about it.
- Give it a **deck of incantations** (up to 30 flash cards). Each card climbs the Leitner
  boxes on its own schedule; the being whispers one due card at a time. **Only you can
  answer your being's whispers**, so your remembering is what keeps it alive, and what
  calls it back if it fades. Others see that it whispers, never what.
- Set its **temperament** (0–100, 50 is how the beings of the commons behave). Traits bias
  its choices; it stays autonomous:
  - *generosity*: how readily it gives when others demand (0 never, 50 gives 3, 100 gives 6)
  - *wanderlust*: above 50 it sometimes leaves its desire's place to explore; below 50 it
    sometimes stays put instead of wandering
  - *sociability*: how strongly it seeks bonded beings next door
  - *conformity*: whether its next desire follows the big Other or its own chain
- **Beckon** it to a place, once an hour (`config :eldritch, :beckon_cooldown_ms`).
- **Keep it alive by remembering.** Your being never dies of old age. Each answer you give
  it buys 3 days of grace (`:devotion_grace_ms`), during which it cannot starve: when its
  ichor runs low it endures. Leave it unanswered longer and it withers and fades; one
  answer calls it back. Faded owned beings never crumble away.

- Your **journal** (in *My being*) shows your recent answers and changes, how well you
  remember each card (weakest first) and what befell your being. **Download my whole
  history** gives everything as JSON Lines: one object per line, either an `interaction`
  (`answer`, `summoned`, `card_added`, `card_rewritten`, `card_burned`, `temperament`,
  `beckon`, with its data) or an `event` from the chronicle about a being you owned or tended.
  Nobody else can read your history.

### Connect your learning agent

If you study with an AI assistant, let it follow your being. In **Settings → Learning agents**
create a token (shown once; revoke it any time), then point your agent at the built-in
**MCP server**:

```bash
claude mcp add --transport http lofi-cosmos https://COSMOS_DOMAIN/mcp \
  --header "Authorization: Bearer lofi_agent_..."
```

Tools: `my_being`, `my_cards`, `whispering_now`, `card_accuracy`, `recent_history`,
`what_befell_my_being`, `cosmos_overview`, `explain` (the cosmos's concepts), and for the deck
`add_card`, `rewrite_card`, `burn_card`. An agent sees only its person's being, cards and
history plus the public life of the cosmos. It **cannot answer whispers**: only the person's own
answers keep their being alive, so the agent quizzes them instead. Edits it makes show in the
journal as made by your agent. The same tools are plain JSON under `/api/agent/…` (see below).

Beings nobody owns (the seeded ones and their children) are **the commons**: anyone signed
in may answer their whispers.

## The visualization

- Places (nodes) glow in the colour of their resource; the filled core and the arc
  around them show how much of their reserve is left.
- Beings orbit the place they dwell in. Their size is their ichor; their eye looks where
  they are going. Faded beings linger as grey husks where they fell.
- A pulsing golden halo means a being is **whispering an incantation**. If it is yours (or
  of the commons), select it and answer. A true answer feeds it ichor and can even call a
  faded being back from the void. Your own being wears a dashed gold frame.
- Click a being to follow it and see its owner, thoughts, desire, psyche, inventory, bonds,
  lineage and incantation. **Beckon…** then click a place to draw your being there.
- Click a place to see who is there (the keeper can also summon beings of the commons).
- Every being has a **portrait** (see below): in its card, on the My being tab, as a
  thumbnail in the Beings list, and as a live preview while you choose a name to summon.
- **Bonds** draws the strong bonds between all beings (green: affinity, red: rivalry).
- The keeper's speed slider sets the tick duration (100ms – 3s). **New cosmos** unmakes and reseeds.

## Static demo (GitHub Pages)

`docs/` holds a static, read-only replay of a recorded cosmos for GitHub Pages
(Settings → Pages → Deploy from a branch → `/docs`). Rebuild it with

```bash
mix cosmos.replay            # --ticks 1600 --every 2 --beings 14 --rings 6,10,14 --seed 7
```

The recorder runs a fresh cosmos in its own data directory (your cosmos is untouched),
steps every system tick by tick with a simulated player answering some incantations,
and writes `docs/replay.json` plus the visualization in replay mode (`docs/index.html`).
Re-run it whenever `apps/lofi/priv/static/index.html` changes so the demo picks up the change.

## How the cosmos works

Every being is an entity whose components subscribe it to systems
(see `Eldritch.Simulation` for pacing):

| System | What it does |
| --- | --- |
| `Volition` | each tick a being ages and performs its highest priority action whose preconditions hold: **Consume** (eat when hungry; the desired resource nourishes most), **ShiftDesire** (once enough is hoarded it is devoured, and desire slides on to something else), **Forage** (starving), **Linger** (gather the desired resource), **MoveToResource** (walk the shortest path toward a known source of desire), **SeekKin** (join a bonded being), **Explore** / wander. Beings past their lifespan wither; beings with no ichor fade. |
| `Observation` | beings remember the place they stand in and glimpse the resources of neighbouring places |
| `Harvest` | beings gather their place's resource, depleting its reserve (they can carry at most 40 units) |
| `Regrowth` | places slowly replenish their reserves |
| `TemporalDecay` | ichor drains over time |
| `Communion` | beings sharing a place meet, share what they know of the landscape, gift what the other desires, quarrel over dwindling resources they both want, share ichor with fading friends, and — when deeply bonded and vigorous — **summon** a new being (up to `max_population`) |
| `Remind` | spaced repetition (Leitner boxes, 20s → 1d): when an incantation comes due the being whispers it |

### Computational Lacanian dynamics

Every being has a **psyche** (`Eldritch.Lacan`) that shapes its decisions:

- **Need, demand, desire.** Need (hunger) is answered by eating. Demand is addressed to
  another being: a lacking being *demands* what it desires of one who holds it. A gift answers
  the demand (it strengthens the bond and the Symbolic) but barely touches desire. Desire is what
  remains: it is never satisfied.
- **Objet petit a.** Each being has a hidden cause of desire, a resource it never desires directly.
  Holding too much of it produces **anxiety** (the lack of lack): the being casts it away.
- **Lack and metonymy.** Lack grows over time and eases while a being gathers its object. When the
  object is attained the being devours its hoard (jouissance), lack drops, and desire *slides* to a
  new object, pushing the old one onto its **signifying chain**.
- **Desire is the desire of the Other.** The next object is chosen by weighing what the whole cosmos
  desires and exchanges (**the big Other**, Symbolic), what the being it identifies with desires
  (**the semblable**, Imaginary), old signifiers returning from its chain (repetition, Real) and what
  lies beside it (contiguity). Fads emerge as desire spreads.
- **The registers.** Each psyche weights the Real, Symbolic and Imaginary. Gifts strengthen the
  Symbolic; mirroring, refusal and rivalry the Imaginary; loss and starvation the Real. When one
  dominates, the **knot loosens**: an Imaginary being refuses every demand and quarrels harder, a
  Real one is ruled by repetition. The registers drift back toward balance and the knot reties.
- **Identification.** A being leaning toward the Imaginary may see itself in a stronger being it
  meets, and starts to desire what it desires, and to rival it.
- **Trauma and repetition.** When a bonded being fades, its mourners gain a **symptom**: they are
  drawn back to the place of loss (more strongly the more the Real weighs) until they work it through.
- **Beyond the pleasure principle.** A being overwhelmed by lack neglects its hunger to chase its
  desire, until it is truly starving.
- **The paternal chain.** A summoned child's chain begins with its parents' desires; its cause of
  desire is its own.

### Time

The map moves every tick (about a second), but lives run on the clock so the cosmos keeps
the pace of the people who visit it:

- beings of the commons live **1 to 4 days** (`config :eldritch, :lifespan_ms`), then wither;
- their husks crumble to dust a day after fading (`:husk_ms`);
- when fewer than 8 beings live (`:min_population`), the Heart of the Cosmos dreams a new
  being every 60 ticks (`:dream_interval_ticks`), so the cosmos cannot die out;
- owned beings are kept by their owner's remembering (see *Your being*).

The replay recorder shortens lifespans to minutes so recordings still show generations.

Noteworthy happenings are written to the **chronicle** (`Eldritch.Chronicle`) shown in the side panel.

## Persistence

History lives in `history.sqlite3` (`Eldritch.History`): the whole chronicle (so the cosmos
remembers its past across restarts; events older than 30 days are pruned,
`:chronicle_retention_ms`), indexed by the beings each event involves, and every person's
interactions. Unmaking the cosmos clears the chronicle but keeps people's study records.

Accounts live in their own SQLite database, `accounts.sqlite3`, next to the cosmos
(migrations run automatically on start; `DATABASE_PATH` overrides its location).

Entities are stored in SQLite at `$XDG_DATA_HOME/lofi-eldritch-cosmos/cosmos.sqlite3`
(usually `~/.local/share/...`), one row per entity (`id`, `kind`, `data`, `updated_at`).
`Cosmos.Database` batches writes: changes collect in memory and are committed in one
transaction every 500ms (`config :cosmos, flush_interval_ms: 500`), so an entity that changes
many times between flushes is written once. Reads see pending writes. A crash loses at most
one flush interval. On shutdown, after seeding, and on `Cosmos.Database.sync/0`, everything is flushed.

Data saved by the older one-file-per-entity store is imported automatically on start up;
the original files are moved to `legacy-files-backup/` next to the database (only files that
decode as entities are touched). Beings saved with a single incantation get a deck holding it.

Rough capacity (4 cores, 1s tick): ~2,000 beings. Births stop at `config :eldritch, :max_population`
(default 40). Above a few hundred beings the browser's `/world` poll gets large (~0.8 KB per being).

## Live updates

The page connects to `/socket` and joins the `world` channel (`LofiWeb.WorldChannel`).
`LofiWeb.WorldBroadcaster` builds one world snapshot per tick, only while someone is
watching, and each channel tailors it to its viewer (their being, their cards, what they
may answer) before pushing it; messages are compressed. If no push arrives for 3 seconds
the page falls back to polling `GET /world`.

## Portraits

`Lofi.Portrait` draws every being from its *features* (`Lofi.Portrait.Features`):

- **Anatomy comes from the name alone**, so a being keeps its face all its life and a name
  can be previewed before summoning. The number of parts in the name (`Gor Lop~Tome` → 3)
  is its number of eyes; a hash of the name picks its form (bulb, spire, maw, cluster,
  veil), limbs (tentacles, horns, antlers, fronds), markings, palette and symmetry.
- **Mood comes from its state**, in a few coarse levels so the portrait changes only when
  something meaningful does: ichor (pale and open-mouthed when starving, glowing when
  full), lack (pupils widen), the dominant register (Real: a jagged outline; Symbolic: a
  ring of runes; Imaginary: mirror symmetry and a shimmering double), a loosened knot (the
  ring breaks), mourning (a tear), whispering (rising sound), its desire and revealed
  objet a (tokens in the corners), wanderlust (longer limbs), and fading (grey, cracked,
  eyes closed).

Renderers implement `Lofi.Portrait.Renderer`. The default, `Lofi.Portrait.Svg`, draws in
code (about 0.3 ms and 8 KB per portrait). `Lofi.Portrait.ImageModel` is the scaffold for
an AI image model: it turns features into a prompt (`Lofi.Portrait.Prompt`), calls a
function you configure, keeps each result on disk, and falls back to the SVG:

```elixir
config :lofi, Lofi.Portrait, renderer: Lofi.Portrait.ImageModel
config :lofi, Lofi.Portrait.ImageModel, generate: {MyImageApi, :generate}  # (prompt, seed) -> {:ok, png}
```

Every being in a world snapshot carries `portrait`, a URL whose `?v=` tag changes with
the portrait, so browsers cache each one for a day.

## HTTP API

Writes use the browser session and need the CSRF token from `GET /api/me`
(sent as the `x-csrf-token` header).

| Method & path | Who | Body | |
| --- | --- | --- | --- |
| `GET /` | anyone | | the visualization |
| `GET /world?since=SEQ` | anyone | | places, beings (as you may see them), simulation status, chronicle after `SEQ` |
| `GET /beings`, `GET /nodes`, `GET /being?id=ID` | anyone | | ids / one being (its deck reduced to a count) |
| `GET /api/me` | anyone | | you, your being with its deck, the CSRF token |
| `GET /portraits/:id` | anyone | | a being's portrait as it is now (SVG; `?frame=0` without frame and name) |
| `GET /portraits/preview?name=` | anyone | | the body a name would give |
| `GET /portraits/:id/features` | anyone | | what the portrait shows, and the prompt for an image model |
| `POST /api/my/being` | signed in | `name`, `at_node`, `cards: [{front, back}]`, `temperament` | summon your one being |
| `PUT /api/my/temperament` | signed in | `generosity`, `wanderlust`, `sociability`, `conformity` | |
| `POST /api/my/cards` · `PUT`/`DELETE /api/my/cards/:id` | signed in | `front`, `back` | edit your deck |
| `GET /api/my/history` | signed in | `limit`, `before` | your recent interactions, accuracy per card, your being's events |
| `GET /api/my/history/export` | signed in | | your whole history as JSON Lines |
| `POST /mcp` | agent token | JSON-RPC | the MCP server for learning agents (`initialize`, `tools/list`, `tools/call`) |
| `GET /api/agent/being` · `cards` · `whispering` · `accuracy` · `history` · `events` · `overview` · `explain?topic=` | agent token | | the same tools as plain JSON |
| `POST /api/agent/cards` · `PUT`/`DELETE /api/agent/cards/:id` | agent token | `front`, `back` | edit the deck |
| `POST /being/recall` | owner (or anyone, for the commons) | `id`, `answer` | answer a whisper (409 if none) |
| `POST /being/beckon` | owner (hourly) · keeper | `id`, `node_id` | 429 while cooling down |
| `POST /being`, `POST /being/incantation` | keeper | | beings of the commons |
| `POST /simulation/start` · `stop` · `speed` | keeper | `tick_ms` | |
| `POST /cosmos/seed` · `reset` | keeper | `beings`, `rings`, `reset` | |

## Deploying

The cosmos runs as a release (`MIX_ENV=prod mix release lofi`) under systemd behind nginx,
beside the wish list on the Hetzner server. Every push to `main` is tested and deployed by
`.github/workflows/deploy.yml`. One-time server setup: [infra/RUNBOOK.md](infra/RUNBOOK.md);
status and decisions: [docs/deployment-handoff.md](docs/deployment-handoff.md).

Production settings (in `/etc/lofi.env`, see `infra/lofi.env.example`): `SECRET_KEY_BASE`,
`PHX_HOST`, `PHX_SERVER=true`, `PORT`, `XDG_DATA_HOME` (where the databases live),
`ELDRITCH_AUTOSTART=true`, and `RESEND_API_KEY` + `MAIL_FROM` for login emails.

# Release Road map

## Release Gamigin 

- [x] Computational Lacanian dynamics
- [x] Start up script making a being and node
- [x] Script to destory the cosmos so that one can start over
- [x] Start up script making the landscape
- [x] Beings that act, cooperate, compete, reproduce and fade
- [x] Spaced repetition of incantations
- [x] Visualization
- [x] Accounts: each person owns one being with a deck of incantations and a temperament

## Next: opening the cosmos to people

- [x] Push live changes to the page (Phoenix Channels): one world snapshot per tick for all
  viewers, tailored per viewer, compressed; polling only as a fallback
- [ ] Send each viewer only the region in view, and only what changed (for large cosmoses)
- [x] Store the chronicle so history survives restarts
- [x] Keep each person's history (every answer, card edit, temperament change, beckon),
  with a journal and a JSON Lines download
- [x] Lives on the clock: commons beings live days, owned beings live by their owner's
  remembering, a dwindling cosmos dreams new beings, husks crumble
- [ ] Ranks or roles, toward social organization
- [x] Portraits of beings, drawn from their names and moods (SVG), with a scaffold for an
  AI image model
- [ ] Portraits: an image model behind `Lofi.Portrait.ImageModel` (generated in the
  background), portraits on the map on hover, and in the static demo
- [ ] Deploy (one server, SQLite with backups) with a mail provider for login links:
  planned beside the wish list on the Hetzner server under systemd, deploying on every
  push to `main`; waiting on the domain. See [docs/deployment-handoff.md](docs/deployment-handoff.md)

## After launch

- [ ] **Export your interactions to your own learning agent.** Let a person send what
  happens between them and their being to an agent they run that helps them learn (for
  example an AI tutor that sees which cards they keep missing and drills them).
  - What to export: every answer to an incantation (card, answer given, right or wrong,
    box before and after, time), card edits, temperament changes, beckons, and chronicle
    events about their being (fading, revival, gifts, mourning).
  - Done: the per-person history (`Eldritch.History`), a JSON Lines download, personal
    revocable agent tokens, and a built-in MCP server (`/mcp`) plus JSON api (`/api/agent`)
    through which an agent reads the person's being, deck and history and edits the deck
    (never answers whispers).
  - Next: webhooks pushed to the agent when something happens (a whisper, a fading).
  - Earlier ideas: a personal, revocable
    API token for a read-only feed the agent polls; webhooks pushed to the agent; an MCP
    server so agents can ask questions like "which cards did I miss this week?"
  - Only the owner can export their own history, and tokens can be revoked at any time.
  - When account deletion is added, it must call `Eldritch.History.forget/1`.

# Starting the Cosmos ECS application

The `Cosmos` application can be started using
``` bash 
mix run --no-halt
```

This will start the various processes required to build entities, start 
systems, and begin a simulation.

## Basic interaction with the lofi-eldritch-cosmos

Anyone can read the cosmos over http:

``` bash
curl http://localhost:5454/beings      # {"being_ids": [...]}
curl "http://localhost:5454/being?id=2enp3IaLemeeiMDZYj3oJ0ukJ9U"
curl http://localhost:5454/world
```

Creating and tending beings needs an account (see *Your being* above).

# Using the Eldritch library application 

## Creating entities

Entities can be created using the a builder module. 
For example, the `Eldritch.Being.Builder` module can be used to create a
new being entity, with some of the standard attributes, use the build function
with argument `{:new, :being, :standard}`. For example, after the Cosmos supervisor
has been started one can run
``` elixir
being_entity_id = Eldritch.Being.Builder.build({:new, :being, :standard}, %{"name" => "Gor'lop"})
```
to create and spawn an entity worker for a being entity named "Gor'lop". The being's
`entity_id` is returned so that we can fetch it's worker process using
`Cosmos.Entity.Cache.server_process(being_entity_id)`.
The build function called in this way adds the standard components for a being.

The second argument can overwrite the default values used to create the standard
components of an entity.

## Systems acting on entities

Each entity is comprised of components each of which have a attribute `system` whose
value is an atom corresponding to one of the implemented systems in the Cosmos ECS.
When adding or removing a component, the entity is subscribed or unsubscribed respectively
from the associated system. For example, in the previous section a being with standard
components whose name is "Gor'lop" was created. This being has the form:

``` elixir
%Cosmos.Entity{
  id: "2NzPp7iRNFaaC10VMTpAgWvLxPK",
  components: %{
    1 => %Cosmos.Entity.Component{
      name: "name",
      system: :attribute,
      value: "Gor'lop",
      id: 1
    },
    2 => %Cosmos.Entity.Component{
      name: "ichor",
      system: :temporal_decay,
      value: 100,
      id: 2
    },
    3 => %Cosmos.Entity.Component{
      name: "orichalcum",
      system: :quantity,
      value: 100,
      id: 3
    }
  },
  auto_component_id: 4
}
```

Since this being has a component with the `:temporal_decay` system, it is subscribed
to that system and the value `ichor` will decrease at a specified interval in time whenever
the `:temporal_decay` system is turned on. 

## Starting and stopping systems

Systems are controlled by `GenServers` (see `Cosmos.System.TemporalDecay` for an example).
The GenServer that powers each system is started when the Cosmos application starts up, 
but will not act on components of entities until being turned on.
Systems can be started or stopped using `Cosmos.System.on/1` and `Cosmos.System.off/1`
where the argument is the system atom (e.g. `:temporal_decay`).

# Dependencies
- [quantum](https://hexdocs.pm/quantum/readme.html) is used for systems that need
  to be run at intervals of minutes or hours (such as full backups and health checks).
- [phoenix](https://hexdocs.pm/phoenix) with [bandit](https://hexdocs.pm/bandit) for the web,
  accounts generated by `mix phx.gen.auth` (bcrypt, Ecto + SQLite)
- [exqlite](https://hexdocs.pm/exqlite) for the cosmos store

# Testing

```bash
mix test
```

Tests persist entities under `$XDG_DATA_HOME/lofi-eldritch-cosmos-test`, never in the
real cosmos.

## Testing database workers

Launch the elixir REPL with
``` shell
iex -S mix
```

Then run something like to make sure that database workers
are behaving as expected.
``` elixir
iex(1)> Cosmos.Entity.Cache.start_link()
{:ok, #PID<0.215.0>}
iex(2)> server = Cosmos.Entity.Server.start_link("jorsa")
{:ok, #PID<0.221.0>}
iex(3)> {_, server} = server
{:ok, #PID<0.221.0>}
iex(4)> entity = Cosmos.Entity.Server.get(server)
%Cosmos.Entity{
  id: "2MXHjNmnZAfLUZToIExXE5xrXiL",
  components: %{},
  auto_component_id: 1
}
iex(5)> comp = Cosmos.Entity.Component.new("name", :attribute, "johnson")
%Cosmos.Entity.Component{name: "name", system: :attribute, value: "johnson", id: nil}
iex(6)> Cosmos.Entity.Server.add_component(server, comp)
:ok
#PID<0.217.0> was chosen
```

# Appendix

## Naming convention for releases
Release names can be chosen from 
[marquises from Ars Geotia](https://en.wikipedia.org/wiki/List_of_demons_in_the_Ars_Goetia#Marquises)
