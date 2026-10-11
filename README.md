# Homelab (piccolo)

Infraestrutura de homelab orquestrada com **Docker Compose**, exposta por um
**Caddy** (proxy reverso) atrás de um **Cloudflare Tunnel**, e acessível
remotamente pela VPN **NetBird**.

## Estrutura

```
piccolo/
├── core/portainer/        # Gestão de containers
├── glance/                # Dashboard / homepage
├── media/
│   ├── jellyfin/          # Servidor de mídia
│   ├── seerr/             # Catálogo + requisições (Overseerr/Jellyseerr)
│   ├── radarr/            # Filmes (automação)
│   ├── prowlarr/          # Indexadores
│   ├── qbittorrent/       # Download client
│   └── immich/            # Fotos
├── network/
│   ├── proxy/             # Caddy + Cloudflare Tunnel + NetBird
│   ├── dns/adguardhome/   # DNS / WebUI
│   └── monitoring/        # Gatus + Beszel + Dozzle
├── storage/
│   ├── nextcloud/         # Nuvem própria
│   └── vaultwarden/       # Gerenciador de senhas
├── start-all.sh           # Sobe todas as stacks
└── update-all.sh          # Atualiza (git pull + pull + up -d)
```

Todos os serviços entram na rede externa **`proxy_net`**, e o Caddy roteia por
nome de host. O TLS é terminado na Cloudflare (o túnel fala HTTP com o Caddy).

## Serviços e domínios

| Serviço        | Domínio                          | Alvo no Caddy          |
|----------------|----------------------------------|------------------------|
| Glance         | `dash.piccollo.stream`           | `glance:8080`          |
| Jellyfin       | `jellyfin.piccollo.stream`       | `jellyfin:8096`        |
| Seerr          | `seerr.piccollo.stream`          | `seerr:5055`           |
| Radarr         | `radarr.piccollo.stream`         | `radarr:7878`          |
| Prowlarr       | `prowlarr.piccollo.stream`       | `prowlarr:9696`        |
| qBittorrent    | `qbittorrent.piccollo.stream`    | `qbittorrent:8080`     |
| Immich         | `immich.piccollo.stream`         | `immich_server:2283`   |
| AdGuard Home   | `adguard.piccollo.stream`        | `adguardhome:3000`     |
| Vaultwarden    | `vault.piccollo.stream`          | `vaultwarden:80`       |
| Portainer      | `portainer.piccollo.stream`      | `portainer:9443`       |
| Gatus (status) | `status.piccollo.stream`         | `gatus:8080`           |
| Beszel         | `beszel.piccollo.stream`         | `beszel:8090`          |
| Dozzle (logs)  | `logs.piccollo.stream`           | `dozzle:8080`          |

> Radarr e Prowlarr devem ficar **protegidos** — veja `docs/cloudflare.md`.

## Deploy

```bash
# Sobe tudo (sincroniza com o origin antes)
./start-all.sh

# Atualização massiva (git pull + docker compose pull + up -d)
./update-all.sh

# Pular o git pull / a limpeza de imagens
./update-all.sh --no-pull
./update-all.sh --no-prune
```

Os scripts varrem todas as subpastas com `docker-compose.yml`, criam a rede
`proxy_net` se não existir e sobem cada stack.

### Variáveis de ambiente (`.env`)

Arquivos `.env` **não são versionados** (veja `.gitignore`). Cada serviço que
precisa deles deve tê-los no servidor:

- `network/proxy/.env` → `TUNNEL_TOKEN`, `NB_SETUP_KEY`
- `glance/.env`
- `media/immich/.env` → `UPLOAD_LOCATION`, `DB_*`
- `storage/vaultwarden/.env` → `VAULTWARDEN_ADMIN_TOKEN`
- `network/monitoring/beszel/.env` → `BESZEL_KEY`, `BESZEL_TOKEN` (veja `.env.example`)

## Documentação

- [`docs/cloudflare.md`](docs/cloudflare.md) — túnel, hostnames e Cloudflare Access
- [`docs/media-stack.md`](docs/media-stack.md) — Jellyfin + Seerr + *arr (fluxo completo)
- [`docs/jellyfreedom.md`](docs/jellyfreedom.md) — assistir enquanto baixa (streaming sob demanda)
- [`docs/monitoring.md`](docs/monitoring.md) — Gatus + Beszel + Dozzle
