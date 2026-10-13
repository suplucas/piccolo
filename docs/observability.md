# Observabilidade (Grafana + Prometheus + Beyla)

Stack em `network/monitoring/observability/`. Tudo acessível **só via VPN NetBird**.

## Serviços
| Serviço | Imagem | Função | Porta |
|---|---|---|---|
| Prometheus | `prom/prometheus` | TSDB (retenção **14d**) + scrape | `100.90.38.203:9090` |
| Grafana | `grafana/grafana` | Dashboards | `100.90.38.203:3001` (admin via `.env`) |
| Beyla | `grafana/beyla` | RED HTTP/gRPC via eBPF (pid host, privileged) | interno `:9400` |
| node_exporter | `prom/node-exporter` | Host: CPU/mem/temp/disco/rede/conexões (**`network_mode: host`**) | host `:9100` |
| cAdvisor | `gcr.io/cadvisor/cadvisor` | CPU/mem/rede por container | interno `:8080` |
| jellyfin-exporter | `rebelcore/jellyfin-exporter` | Sessões/streams/transcodes | interno `:9594` |

> O **node_exporter** roda em `network_mode: host` (precisa do netns do host para
> ver `eno2`/`wt0`); o Prometheus o raspa via `host.docker.internal:9100`.

## Datasources
- **Prometheus** (uid `prometheus`, `http://prometheus:9090`).
- **Jellyfin** (Infinity, uid `jellyfin`) — consulta a API REST `/Sessions` (clients
  com IP/Device/App). Plugin `yesoreyeram-infinity-datasource`, header
  `Authorization: MediaBrowser Token=<JELLYFIN_TOKEN>`. Grafana está na `proxy_net`
  para alcançar `jellyfin:8096`.

Prometheus também entra na rede `proxy_net` para raspar o **Gatus** (`gatus:8080/metrics`)
sem alterar o stack do Gatus.

## Scrape jobs (`prometheus/prometheus.yml`)
`prometheus`, `node`, `cadvisor` (com `metric_relabel_configs` que **agrupam por
serviço lógico** no label `service` e descartam métricas ruidosas), `gatus`,
`jellyfin`, `beyla`.

> Immich v3 **não** expõe Prometheus (só a SPA em `/metrics`), por isso não há job.

## Dashboards (`grafana/dashboards/`, provisionados como JSON)
- **Server** (`uid: servidor`) — CPU/load, temperatura, memória, **pressure (PSI)**,
  **NTP sync**, **CPU freq**, **disk usage (com Total/Free)**, disk I/O, rede
  (in/out, erros), **TCP retrans/TIME_WAIT**, conexões/sockets, uptime.
- **Services** (`uid: servicos`) — uptime/latência por serviço e **HTTP codes** (Gatus);
  **TLS cert expiry**, **OOM kills**; CPU/mem/**rede por serviço** (cAdvisor,
  agrupado por serviço lógico); containers (memória/uptime).
- **Media** (`uid: midia`) — **Clients (IP/Device/App via `/Sessions`)**; streams,
  transcodes, **progresso/restante**; CPU/mem do Jellyfin; rede do host; library counts.
- **Beyla RED Metrics** — dashboard oficial (HTTP/gRPC RED).

## Operação
- Subir/atualizar: `docker compose up -d` (na pasta do stack).
- O `jellyfin-exporter` usa `JELLYFIN_TOKEN` (API key admin do Jellyfin) do `.env`.
- Gatus: `metrics: true` no `network/monitoring/gatus/config/config.yaml`.
- Retenção (Prometheus) e prune do Beszel: **14 dias**.
