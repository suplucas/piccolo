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
| `jellyfin`     | `piccollo.stream`| HTTP | `http://caddy:80`|
| `seerr`        | `piccollo.stream`| HTTP | `http://caddy:80`|
| `radarr`       | `piccollo.stream`| HTTP | `http://caddy:80`|
| `prowlarr`     | `piccollo.stream`| HTTP | `http://caddy:80`|
| `qbittorrent`  | `piccollo.stream`| HTTP | `http://caddy:80`|
| `immich`       | `piccollo.stream`| HTTP | `http://caddy:80`|
| `adguard`      | `piccollo.stream`| HTTP | `http://caddy:80`|
| `vault`        | `piccollo.stream`| HTTP | `http://caddy:80`|
| `cloud`        | `piccollo.stream`| HTTP | `http://caddy:80`|
| `portainer`    | `piccollo.stream`| HTTP | `http://caddy:80`|

> Glance (`dash`), Gatus (`status`), Beszel (`beszel`) e Dozzle (`logs`) **não têm
> Public Hostname** — ficam só na VPN NetBird (seção 3).

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
| qBittorrent    | `qbittorrent.piccollo.stream`| WebUI / acesso a downloads               |

> Gatus (`status`), Beszel (`beszel`) e Dozzle (`logs`) **não têm auth** — em vez
> de Access, ficam **só na VPN NetBird** (seção 3), sem Public Hostname.

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

Quem preferir, pode mover **qualquer** serviço para a VPN (sem Public Hostname),
trocando a publicação de porta para a interface `100.90.38.203` — veja a seção 3.

## 3. NetBird (VPN)

O `netbird` roda com `network_mode: host` e usa `NB_SETUP_KEY` (do `.env`).
Clientes entram na rede e alcançam os serviços pelo IP NetBird do host, sem
depender do túnel. É também o caminho recomendado para **streaming** (`Jellyfin`),
já que o túnel da Cloudflare limita/trava vídeo no plano grátis.

### Como conectar de fora

1. Instale o **cliente NetBird** no dispositivo: app **NetBird** (Android/iOS)
   ou CLI para desktop (`netbird`) — https://app.netbird.io.
2. Entre com a conta da organização do servidor e conecte (`netbird up`).
3. Descubra o IP do host dentro da VPN (na máquina servidor):

   ```bash
   ip addr show wt0     # ex.: inet 100.90.38.203/16
   ```

4. Acesse os serviços pelo IP (`100.x.x.x`) em vez do domínio.

### Serviços publicados apenas na VPN

Serviços **sem autenticação** (ou muito sensíveis) ficam **só na VPN NetBird**,
sem Public Hostname no túnel:

| Serviço  | URL (dentro da VPN)           | Motivo                 |
|----------|-------------------------------|------------------------|
| Jellyfin | `http://100.90.38.203:8096`  | Streaming fora do túnel |
| Glance   | `http://100.90.38.203:8080`  | Dashboard (sem login)   |
| Gatus    | `http://100.90.38.203:8081`  | Uptime sem auth         |
| Dozzle   | `http://100.90.38.203:8082`  | **Logs** sem auth       |
| Beszel   | `http://100.90.38.203:8090`  | Métricas sem auth       |

Cada um publica a porta **somente** na interface `100.90.38.203`, ex.:

```yaml
# network/monitoring/dozzle/docker-compose.yml
ports:
  - "100.90.38.203:8082:8080/tcp"
```
