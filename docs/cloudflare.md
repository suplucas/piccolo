# Cloudflare Tunnel + Access

O acesso externo é feito por um **Cloudflare Tunnel** (`cloudflared`), que
conecta a borda da Cloudflare ao `caddy` na rede `proxy_net`. O TLS é terminado
na Cloudflare; o túnel fala **HTTP** com o Caddy (por isso o `Caddyfile` só tem
blocos `http://`).

## 1. Public Hostnames (túnel)

Em **Zero Trust → Networks → Tunnels → (seu túnel) → Public Hostnames**, crie um
hostname para cada serviço apontando para o Caddy:

| Subdomínio     | Domínio          | Tipo | URL do serviço   |
|----------------|------------------|------|------------------|
| `dash`         | `piccollo.stream`| HTTP | `http://caddy:80`|
| `jellyfin`     | `piccollo.stream`| HTTP | `http://caddy:80`|
| `seerr`        | `piccollo.stream`| HTTP | `http://caddy:80`|
| `radarr`       | `piccollo.stream`| HTTP | `http://caddy:80`|
| `prowlarr`     | `piccollo.stream`| HTTP | `http://caddy:80`|
| `qbittorrent`  | `piccollo.stream`| HTTP | `http://caddy:80`|
| `immich`       | `piccollo.stream`| HTTP | `http://caddy:80`|
| `adguard`      | `piccollo.stream`| HTTP | `http://caddy:80`|
| `vault`        | `piccollo.stream`| HTTP | `http://caddy:80`|
| `portainer`    | `piccollo.stream`| HTTP | `http://caddy:80`|

> Se o `cloudflared` rodar como **serviço systemd no host** (em vez de container),
> use `http://localhost:80` como URL de serviço — o systemd não resolve o DNS
> interno do Docker.

Os registros **CNAME** (`<subdomínio> → <tunnel-id>.cfargotunnel.com`) são criados
automaticamente pela Cloudflare ao adicionar cada Public Hostname.

## 2. Proteger Radarr e Prowlarr com Cloudflare Access

Radarr/Prowlarr **não têm autenticação forte** — não devem ficar abertos na
internet. Use o **Cloudflare Access** para exigir login antes de chegar no túnel.

Em **Zero Trust → Access → Applications → Add an application → Self-hosted**:

1. **Application**
   - Name: `Radarr`
   - Public hostname: `radarr.piccollo.stream`
2. **Policies**
   - Name: `Allow team`
   - Action: `Allow`
   - Include: e-mail(s) autorizados (ou grupo, ou IdP Google/GitHub)
3. **Authentication**
   - Session duration: ex. `24h`
   - IdP: One-time PIN por e-mail (mais simples) ou Google/GitHub.

Repita para `prowlarr.piccollo.stream`.

### Alternativa: manter só na VPN

Se preferir, **não crie** os Public Hostnames de `radarr`/`prowlarr` e acesse-os
apenas pela rede **NetBird** (IP `100.x.x.x` do host + porta do serviço). Assim
eles nunca ficam expostos publicamente.

## 3. NetBird (VPN)

O `netbird` roda com `network_mode: host` e usa `NB_SETUP_KEY` (do `.env`).
Clientes entram na rede com `sudo netbird up` e alcançam os serviços pelo IP
NetBird do host, sem depender do túnel.
