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
| `status`       | `piccollo.stream`| HTTP | `http://caddy:80`|
| `beszel`       | `piccollo.stream`| HTTP | `http://caddy:80`|
| `logs`         | `piccollo.stream`| HTTP | `http://caddy:80`|

> Se o `cloudflared` rodar como **serviço systemd no host** (em vez de container),
> use `http://localhost:80` como URL de serviço — o systemd não resolve o DNS
> interno do Docker.

Os registros **CNAME** (`<subdomínio> → <tunnel-id>.cfargotunnel.com`) são criados
automaticamente pela Cloudflare ao adicionar cada Public Hostname.

## 2. Proteger serviços com Cloudflare Access

Vários serviços **não têm autenticação forte** (ou nenhuma) e não devem ficar
abertos na internet. Use o **Cloudflare Access** para exigir login antes de
chegar ao túnel.

Serviços recomendados para proteger:

| Serviço        | Hostname                     | Motivo                                   |
|----------------|------------------------------|------------------------------------------|
| Radarr         | `radarr.piccollo.stream`     | Sem auth forte / expõe API               |
| Prowlarr       | `prowlarr.piccollo.stream`   | Sem auth forte / expõe API               |
| Gatus          | `status.piccollo.stream`     | Uptime sem auth por padrão               |
| Beszel         | `beszel.piccollo.stream`     | Métricas (host/containers) sem auth      |
| Dozzle         | `logs.piccollo.stream`       | **Logs** de todos os containers          |
| qBittorrent    | `qbittorrent.piccollo.stream`| WebUI / acesso a downloads               |

Em **Zero Trust → Access → Applications → Add an application → Self-hosted**,
repita para cada hostname acima:

1. **Application**
   - Name: `Radarr` (ou o serviço)
   - Public hostname: `radarr.piccollo.stream`
2. **Policies**
   - Name: `Allow team`
   - Action: `Allow`
   - Include: e-mail(s) autorizados (ou grupo, ou IdP Google/GitHub)
3. **Authentication**
   - Session duration: ex. `24h`
   - IdP: One-time PIN por e-mail (mais simples) ou Google/GitHub.

> Dica: em vez de criar uma aplicação por hostname, use **wildcards**
> (`*.piccollo.stream`) com policies separadas, ou agrupe os hostnames de
> administração numa única aplicação.

### Alternativa: manter só na VPN

Se preferir, **não crie** os Public Hostnames desses serviços e acesse-os apenas
pela rede **NetBird** (IP `100.x.x.x` do host + porta do serviço). Assim eles
nunca ficam expostos publicamente. É a opção mais segura para `logs`/`beszel`.

## 3. NetBird (VPN)

O `netbird` roda com `network_mode: host` e usa `NB_SETUP_KEY` (do `.env`).
Clientes entram na rede com `sudo netbird up` e alcançam os serviços pelo IP
NetBird do host, sem depender do túnel.
