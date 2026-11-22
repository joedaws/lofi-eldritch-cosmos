# Runbook: the cosmos on the Hetzner server

One-time setup for running the Lofi Eldritch Cosmos **beside the wish list** on the
existing Hetzner server. It reuses what is already there (the `deploy` user, nginx,
certbot, ufw, Cloudflare; see the wish list's `docs/deployment-plan.md`) and adds:

| | |
| --- | --- |
| systemd unit | `lofi.service` (plus `lofi-backup.timer`) |
| release | `/opt/lofi` (scripts in `/opt/lofi-infra`) |
| data | `/var/lib/lofi-eldritch-cosmos` (`cosmos`, `accounts`, `history` `.sqlite3`) |
| backups | `/var/backups/lofi/<date>/`, nightly, 14 days kept |
| secrets | `/etc/lofi.env` |
| port | `127.0.0.1:4100` (nginx in front; never opened in ufw) |
| logs | `journalctl -u lofi` |

Wherever you see `COSMOS_DOMAIN`, use the real domain (not decided yet).
Deploys happen on every push to `main` (`.github/workflows/deploy.yml`).

## Before you start

- Pick the domain (see `docs/deployment-handoff.md`).
- Create a [Resend](https://resend.com) account (free plan: 3,000 emails/month). Login links
  are emailed from it.

## 1. DNS

In Cloudflare, add an `A` record for `COSMOS_DOMAIN` pointing at the server's IP
(and `AAAA` for IPv6 if the wish list has one). Leave it **DNS only (grey cloud)** until
the certificate is issued in step 7, as for the wish list.

## 2. Packages

```bash
ssh wishlistpalace            # the server (your existing ssh alias)
sudo apt update && sudo apt install -y sqlite3   # used by the nightly backup
```

No Erlang/Elixir is needed on the server: the release brings its own runtime.

## 3. Folders

```bash
sudo mkdir -p /opt/lofi /opt/lofi-infra /var/lib/lofi-eldritch-cosmos /var/backups/lofi
sudo chown deploy:deploy /opt/lofi /opt/lofi-infra /var/lib/lofi-eldritch-cosmos /var/backups/lofi
sudo chmod 750 /var/lib/lofi-eldritch-cosmos /var/backups/lofi
```

## 4. Secrets and settings

Copy `infra/lofi.env.example` from this repo to the server:

```bash
scp infra/lofi.env.example wishlistpalace:/tmp/lofi.env     # from your machine
ssh wishlistpalace
sudo mv /tmp/lofi.env /etc/lofi.env
sudo chown root:root /etc/lofi.env && sudo chmod 600 /etc/lofi.env
sudo nano /etc/lofi.env
```

Fill in:

- `SECRET_KEY_BASE`: `head -c 48 /dev/urandom | base64` (or `mix phx.gen.secret`)
- `PHX_HOST`: the domain
- `RESEND_API_KEY` and `MAIL_FROM`: see step 9 (the app runs without them, but nobody
  can log in until they are set)

## 5. Let `deploy` restart the cosmos

```bash
sudo visudo -f /etc/sudoers.d/lofi
```

```
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart lofi, /usr/bin/systemctl start lofi, /usr/bin/systemctl stop lofi
```

## 6. systemd units

```bash
scp infra/systemd/lofi.service infra/systemd/lofi-backup.service infra/systemd/lofi-backup.timer wishlistpalace:/tmp/
ssh wishlistpalace
sudo mv /tmp/lofi.service /tmp/lofi-backup.service /tmp/lofi-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable lofi                       # start on boot (first start comes with the first deploy)
sudo systemctl enable --now lofi-backup.timer    # nightly backups at ~03:30
```

## 7. nginx and the certificate

Replace `COSMOS_DOMAIN` in `infra/nginx/lofi.conf`, then:

```bash
scp infra/nginx/lofi.conf wishlistpalace:/tmp/
ssh wishlistpalace
sudo mv /tmp/lofi.conf /etc/nginx/sites-available/lofi
sudo ln -s /etc/nginx/sites-available/lofi /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d COSMOS_DOMAIN
```

Certbot adds the https block and the http → https redirect. The wish list's site is
untouched; nginx chooses the site by `server_name`.

Then in Cloudflare, switch the record to **Proxied (orange cloud)**. SSL/TLS mode should
already be **Full (strict)** from the wish list's setup.

## 8. GitHub secrets and the first deploy

In this repo: **Settings → Secrets and variables → Actions**, add

- `VPS_IP`: the server's IP
- `SSH_PRIVATE_KEY`: a key whose public half is in `/home/deploy/.ssh/authorized_keys`
  (the wish list's deploy key can be reused)

Then push to `main`, or run **Actions → Deploy → Run workflow**. It tests, builds the
release, syncs it to `/opt/lofi` (and `infra/` to `/opt/lofi-infra`), restarts `lofi` and
checks that it answers.

```bash
systemctl status lofi
curl http://127.0.0.1:4100/ping
journalctl -u lofi -f
```

## 9. Login emails (Resend)

In Resend: add the domain (or a subdomain like `mail.COSMOS_DOMAIN`) and add the DNS
records it shows (SPF/DKIM) in Cloudflare; wait until it shows **Verified**. Create an
API key with sending access. In `/etc/lofi.env`:

```
RESEND_API_KEY=re_...
MAIL_FROM="Lofi Eldritch Cosmos <login@COSMOS_DOMAIN>"
```

```bash
sudo systemctl restart lofi
```

## 10. Become the keeper, then open the doors

**Register first, before telling anyone about the site**: the first account becomes the
keeper (admin) who alone can start, pause, speed up and reseed the cosmos.

1. Open `https://COSMOS_DOMAIN`, **Register**, follow the emailed link.
2. The empty cosmos shows **Begin genesis**: seed it. The simulation starts on its own
   (and again after every restart, `ELDRITCH_AUTOSTART=true`).
3. Summon your own being in **My being**.

## Day to day

| | |
| --- | --- |
| logs | `journalctl -u lofi -f` |
| restart | `sudo systemctl restart lofi` |
| a console in the running cosmos | `sudo -u deploy bash -c 'set -a; . /etc/lofi.env; exec /opt/lofi/bin/lofi remote'` |
| run a backup now | `sudo systemctl start lofi-backup` then `ls /var/backups/lofi` |
| memory | `systemctl status lofi` (expect a few hundred MB) |

### Restoring a backup

```bash
sudo systemctl stop lofi
cd /var/lib/lofi-eldritch-cosmos
sudo -u deploy rm -f *.sqlite3-wal *.sqlite3-shm
sudo -u deploy cp /var/backups/lofi/<date>/*.sqlite3 .
sudo systemctl start lofi
```

### Unmaking the cosmos (keeps accounts and people's histories)

From the page as the keeper (**New cosmos**), or:

```bash
sudo -u deploy bash -c 'set -a; . /etc/lofi.env; /opt/lofi/bin/lofi rpc "Eldritch.Genesis.reset()"'
```
