# GoDesk infra

Self-hosted signaling (`hbbs`) and relay (`hbbr`) for the GoDesk client.
Per [ADR-003](../wiki/decisions.md#adr-003--self-host-signaling--relay-on-own-infra-no-third-party-rustdesk-public-servers) and [ADR-005](../wiki/decisions.md#adr-005--share-vps-with-godeskflowcom-during-mvp-split-hbbr-before-public-launch).

## Topology (MVP)

Co-located on the godeskflow.com VPS at `160.153.176.199` (GoDaddy, Phoenix AZ).
**Split `hbbr` to a dedicated VPS** before any public/signed installer ships.

## Files

- `docker-compose.yml` — defines `hbbs` (ID server) and `hbbr` (relay) containers
- `key/` — gitignored; holds the rendezvous keypair generated on first run

## First-time deploy

```bash
ssh promogeneral@160.153.176.199
cd ~/godesk-infra
docker compose pull
docker compose up -d
docker compose logs -f --tail=50
```

## Generate the rendezvous keypair (one time)

The keypair authenticates clients to the rendezvous server. Generate once,
keep the **secret** key offline; bake the **public** key into client builds
at compile time.

```bash
docker run --rm rustdesk/rustdesk-server rustdesk-utils genkeypair
# Output:
# Public Key:  <base64>
# Secret Key:  <base64>
```

Replace the `-k _` flag in `docker-compose.yml` with `-k <secret>` after
generation, then `docker compose up -d` again.

## DNS

These A records point at `160.153.176.199`:

| Hostname | Purpose |
|----------|---------|
| `id.godeskflow.com` | hbbs (signaling) |
| `relay.godeskflow.com` | hbbr (relay) |

Phase 4 split: `relay.godeskflow.com` repoints to the dedicated relay VPS.

## Firewall

Required open ports on the VPS host (cloud security group + ufw):

```
21115/tcp   hbbs ID
21116/tcp   hbbs NAT test
21116/udp   hbbs NAT test
21117/tcp   hbbr relay
21118/tcp   hbbs websocket  (optional)
21119/tcp   hbbr websocket  (optional)
```

## Updating

```bash
docker compose pull
docker compose up -d
docker compose logs -f --tail=50
```

`docker compose restart hbbs` does **not** affect the godeskflow.com Next.js
process under PM2 — graceful per [ADR-005](../wiki/decisions.md#adr-005--share-vps-with-godeskflowcom-during-mvp-split-hbbr-before-public-launch).

## Backups

The hbbs DB lives in the `godesk-hbbs-data` Docker volume (~10 MB sled DB).
Nightly snapshot recommended:

```bash
docker run --rm \
  -v godesk-hbbs-data:/source:ro \
  -v $HOME/backups/godesk:/backup \
  alpine tar czf /backup/hbbs-$(date +%F).tar.gz -C /source .
```

## Resource limits

`mem_limit: 512m` for hbbs and `1g` for hbbr keep the containers from
starving the existing PM2 processes (`godeskflow`, `loris`, `loris-collector`,
`shybloom-prerender`) on the shared VPS.
