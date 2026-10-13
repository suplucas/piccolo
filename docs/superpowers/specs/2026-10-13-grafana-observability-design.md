# Design: Observabilidade no Grafana (dashboards separados)

Data: 2026-10-13
Status: aguardando aprovação

## Intenção / por quê
Ter uma **visão de observabilidade do homelab no Grafana** (gráficos mais
avançados que o Beszel), em **dashboards separados**, para dois momentos de uso:

1. **Visão geral** — saber rapidamente se o servidor está saudável.
2. **Foco em um serviço** — enquanto usa algo (ex.: assistindo no Jellyfin),
   entender o que aquele serviço está consumindo e o que a rede está fazendo.

O valor central é **entender cada serviço** (uptime, latência) e, além dele, o
**host**: temperatura, CPU, CPU por serviço, conexões ativas, rede (in/out).

Motivação adicional: o Beszel **apaga os dados de 1 minuto após 1 hora** (job
horário), então a view "1 hour" dele é a mais frágil. O Prometheus/Grafana já
no ar guarda dados crus por 14 dias — resolvendo isso.

## Objetivos
- 3 dashboards separados: **Servidor**, **Serviços**, **Mídia**.
- Uptime e latência **por serviço** no Grafana.
- CPU/memória **por serviço (container)**.
- Visão do host: CPU/load, memória, temperatura, disco/I-O, rede (in/out,
  pacotes, erros) e **conexões ativas**.
- Tudo acessível **só via VPN NetBird** (como o resto do stack).
- Provisionado como código (JSON versionado), igual ao dashboard do Beyla.

## Não-objetivos
- **Não** substituir o Beszel (ele continua como está, com seu dashboard).
- **Não** criar um segundo agente de métricas além do necessário.
- **Não** expor nada publicamente (sem Cloudflare/Public Hostname).

## Anti-objetivos
- Quebrar o stack atual (`beszel`, `observability`) ou a rede VPN.
- Coletar métricas de altíssima cardinalidade sem necessidade.

## Restrições e estado atual
- Já existe o stack `network/monitoring/observability/` com **Prometheus**
  (retenção 14d, bind VPN `:9090`), **Grafana** (`:3001`, admin via `.env`) e
  **Beyla** (eBPF → `/metrics` em `:9400`). Datasource "Prometheus" (uid
  `prometheus`) e o dashboard **Beyla RED Metrics** já provisionados.
- **Gatus** roda em `network/monitoring/gatus/` com checks de serviço, mas o
  endpoint `/metrics` está **desligado**.
- **Não há** `node_exporter` nem `cAdvisor`.
- **Immich** expõe `/metrics` (200). Caddy/AdGuard/qBittorrent/Jellyfin/NetBird
  **não** têm Prometheus nativo.
- Host: Ubuntu, i7-9700T, iGPU Intel UHD 630, NVMe + SATA. Docker.

## Decisões já tomadas (pelo usuário)
- Usar o **Grafana** que já subimos (lendo do Prometheus existente).
- Construir **dashboards separados** (não uma única página com abas).

## Chamadas do builder (minhas, sujeitas a revisão)
- Adicionar **node_exporter** (host) e **cAdvisor** (containers) ao stack
  `observability`, raspados pelo Prometheus existente.
- **Ligar métricas do Gatus** (`metrics: true`). Para o Prometheus alcançar
  `gatus:8080` **sem editar o stack do Gatus** (anti-objetivo), o Prometheus
  entra também na rede externa `proxy_net` e raspa `gatus:8080/metrics`.
- **Limitar a cardinalidade do cAdvisor**: drop de métricas ruidosas via
  `metric_relabel_configs` (ex.: `container_*_blkio_*`, `*_labels`), mantendo
  CPU/mem/rede. Evita inflar o volume de 14d (anti-objetivo).
- **Não publicar portas** de node_exporter/cAdvisor (scrape interno); Grafana/
  Prometheus seguem VPN-only.
- Dashboards como **JSON provisionado** em `grafana/dashboards/`, numa pasta
  "Observability", com datasource uid `prometheus`.
- Manter o dashboard **Beyla** existente; **adicionar** os 3 novos.

## Fontes de dados (Prometheus scrape jobs)
| Job | Fonte | Métricas-chave |
|---|---|---|
| `node` | node_exporter (`:9100`) | `node_cpu_*`, `node_memory_*`, `node_load*`, `node_filesystem_*`, `node_disk_*`, `node_network_*`, `node_netstat_*`, `node_sockstat_*`, `node_nf_conntrack_entries`, `node_hwmon_temp_celsius`, `node_boot_time_seconds` |
| `cadvisor` | cAdvisor (`:8080`) | `container_cpu_usage_seconds_total`, `container_memory_*`, `container_network_*`, `container_start_time_seconds` |
| `gatus` | Gatus (`:8080/metrics`) | `gatus_results_*` (sucesso/uptime + tempo de resposta por endpoint) |
| `immich` | Immich (`:2283/metrics`) | métricas do app (ex.: jobs, uploads) |
| `jellyfin` | Jellyfin exporter (`:9594`) | sessões/streams ativos, transcodes |
| `beyla` | Beyla (`:9400`) | `http_server_request_duration_seconds_*` (RED) — já existe |

## Dashboards (painéis propostos)
### 1. Servidor (Visão geral)
- CPU: uso %, por modo, load1/5/15.
- Temperatura: `node_hwmon_temp_celsius` (package/cores, acpitz, iGPU, NVMe).
- Memória: usada/disponível/cache, swap.
- Disco: uso por mount (`node_filesystem_avail_bytes`), I/O (`node_disk_read/write_bytes`, latência).
- Rede: throughput in/out, pacotes, erros/drops, por interface (`eno2`, `wt0`).
- Conexões: TCP estabelecidas (`node_netstat_Tcp_CurrEstab`), sockets em uso, conntrack.
- Uptime do host.

### 2. Serviços
- **Uptime por serviço** (Gatus) + **latência** (tempo de resposta por endpoint), com variável de serviço.
- **CPU/mem por serviço**, **agrupado por serviço lógico** (Immich = server+db+redis somados; Nextcloud = app+db somados; etc.) via `cAdvisor`, com variável de serviço + top consumidores.
- Reinícios/estado dos containers (cAdvisor uptime).

### 3. Mídia (foco Jellyfin/streaming)
- Jellyfin: CPU/mem do container (cAdvisor) + **sessões/streams e transcodes** (Jellyfin exporter).
- Rede do host durante streaming (throughput in/out).
- *(iGPU util/temp descartados a pedido — o UHD 630 não expõe temp de iGPU via hwmon.)*

## Decisões finais do usuário
1. **iGPU**: **não** quer utilização/temperatura de iGPU → dashboard Mídia fica
   com container + rede + métricas do Jellyfin (via exporter).
2. **CPU/mem por serviço**: **agrupado por serviço lógico**.
3. **Exporters opcionais**: **incluir ambos** — Immich (nativo) e Jellyfin (exporter).

## Agrupamento "por serviço lógico" (chamada do builder)
Derivar um label `service` no Prometheus via `metric_relabel_configs` a partir do
nome do container (regex: `immich_*`→`immich`, `nextcloud*`→`nextcloud`, etc.) e
agregar `sum by (service)`. Map de prefixos fica no `prometheus.yml`.

## Resolvido como chamada do builder (não precisa do usuário)
- cAdvisor: filtra métricas (cardinalidade/disco).
- Gatus: Prometheus entra em `proxy_net` para raspar `gatus:8080`.
- Portas de node_exporter/cAdvisor: internas (sem publicar).

## O que fica para o builder (planejamento)
- Escolher imagens/versões e flags exatas (node_exporter com `--path.rootfs=/host`
  e mounts `/:/host:ro,rslave`; cAdvisor privileged + mounts).
- Escrever os jobs de scrape no `prometheus.yml` e reorganizar se preciso.
- Habilitar métricas do Gatus no `config.yaml`.
- Escrever os 3 JSONs e o provider já existente deve pegá-los.
- Validar (targets `up`, painéis com dados) e documentar em `docs/`.