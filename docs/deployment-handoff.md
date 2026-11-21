# Deployment handoff: running the cosmos on the Hetzner server

Status: **waiting on two decisions** (domain, how new versions get deployed).
Everything else is planned and can be built as soon as those are made.

## What we found

The Hetzner server already runs the wish list (`joedaws/wishlist`, see its
`docs/deployment-plan.md` and `infra/`):

- Hetzner CX23 (2 vCPU, 4 GB RAM), Ubuntu 24.04 LTS
- Cloudflare (DNS, proxy) → nginx (Let's Encrypt via certbot) → the app on `127.0.0.1:4000`
- The app is a `mix release` in `/opt/wish_list`, run by **systemd** (`wish_list.service`)
  as the `deploy` user, with secrets in `/etc/wish_list.env`
- Deploys: GitHub Actions on a published GitHub release → test → build the release on
  Ubuntu 24.04 (OTP 27.3.4.19) → rsync to the server → migrate → `systemctl restart`

The server has plenty of room: the cosmos needs roughly 200–300 MB of RAM and little CPU,
and it uses SQLite files, so no database server is needed. Extra cost: about $0 (plus a
domain if we buy one; login emails fit in Resend's free plan).

## The plan: a second systemd service beside the wish list

Same pattern as the wish list, nothing fancy: **systemd keeps the cosmos running**
(starts it on boot, restarts it if it crashes, collects its logs in the journal), and nginx
forwards its domain to it.

| | wish list (existing) | cosmos (new) |
| --- | --- | --- |
| systemd unit | `wish_list.service` | `lofi.service` |
| release | `/opt/wish_list` | `/opt/lofi` |
| port (localhost only) | 4000 | 4100 |
| secrets | `/etc/wish_list.env` | `/etc/lofi.env` |
| data | PostgreSQL | SQLite files in `/var/lib/lofi-eldritch-cosmos` (cosmos, accounts, history) |
| nginx site | `wishlistpalace` | its own site + certificate |
| logs | `journalctl -u wish_list` | `journalctl -u lofi` |

`/etc/lofi.env` will hold: `SECRET_KEY_BASE`, `PHX_HOST`, `PHX_SERVER=true`, `PORT=4100`,
`XDG_DATA_HOME=/var/lib` (puts the data in `/var/lib/lofi-eldritch-cosmos`), and the
Resend API key for login emails.

Backups: Hetzner snapshots cover the whole server; on top of that, a nightly systemd
timer will copy the three SQLite databases safely (`sqlite3 .backup`) to a backups folder.

The wish list is untouched apart from sharing nginx and getting a few more sudo rules for
the `deploy` user (`systemctl restart|start|stop lofi`).

## Decision 1: the domain

Where should the cosmos live?

- **A new domain** (about $10–15/year), e.g. something with "eldritch" or "cosmos" in it.
  Its own identity, independent of the wish list.
- **A subdomain of a domain you already own**, e.g. `cosmos.wishlistpalace.com`.
  Free and quick (one Cloudflare DNS record), but ties the two projects together.

Either way the steps are the same: a Cloudflare DNS record pointing at the server, an nginx
site, and a certbot certificate. The domain becomes `PHX_HOST` and the address in login emails.

## Decision 2: how new versions get to the server

systemd manages the running process in every option; the question is only how a new
build arrives and when `systemctl restart lofi` happens.

1. **GitHub Actions on a published release** (what the wish list does). Tests run, a
   release is built on GitHub's Ubuntu 24.04 machines, rsynced to `/opt/lofi`, and the
   service restarted. Deploys are deliberate: nothing ships until you publish a release.
   Needs the server's IP and a deploy SSH key as GitHub secrets (the same ones as the
   wish list can be reused).
2. **GitHub Actions on every push to `main`.** Same as 1, but automatic. Fastest, and
   every merge goes live.
3. **Build on the server itself, run by systemd.** A small `lofi-deploy.service` (started
   by hand with `sudo systemctl start lofi-deploy`, or by a systemd timer that checks for
   new commits) pulls the repo, builds the release on the server and restarts `lofi`.
   Everything lives on the server and nothing needs GitHub secrets, but the server needs
   Elixir/Erlang installed to build, and builds use the server's CPU while the wish list
   is running.

Recommendation: **1**, since it matches the wish list and keeps the server free of build
tools. If you would rather keep everything on the server under systemd, **3** works well
too; it is a little more to set up once.

## Once decided, what happens

I write, in this repo:

- release configuration (`mix release lofi`)
- `infra/systemd/lofi.service` (and `lofi-backup.service` + `.timer`; plus
  `lofi-deploy.service` if option 3)
- `infra/nginx/lofi.conf`, `infra/lofi.env.example`
- `infra/RUNBOOK.md`: the one-time server steps in the same style as the wish list's guide
- `.github/workflows/deploy.yml` (options 1 or 2)

You do, once:

- buy or pick the domain and add the Cloudflare DNS record
- create a Resend account, verify the domain, and get an API key
- run the runbook's server steps (create folders, install the units, add the nginx site,
  run certbot, fill in `/etc/lofi.env`)
- add the GitHub secrets (options 1 and 2)
