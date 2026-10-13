# Design: Dashboards Grafana v2 (clients + completude + correções)

Data: 2026-10-13
Status: aprovado (implementar)

## Intenção
Deixar os dashboards do Grafana **mais completos**, mostrar **clients do Jellyfin
(com IP)** e **corrigir dois problemas** de leitura.

## Achados (recon)
- **"Memory" (Server) sem dados** = bug: dois alvos com `refId` repetido ("A").
  Grafana descarta refId duplicado. (Correção trivial.)
- **"Network (bits/s)" vazio** = o `node_exporter` roda no netns do container
  (vê só `lo`/`eth0`). Precisa ler `procfs`/`sysfs` do host.
- **Clients/IP**: existem na **API do Jellyfin** (`/Sessions` → `RemoteEndPoint`,
  `DeviceName`, `Client`), mas **não** no `jellyfin-exporter`. Solução: datasource
  **Infinity** (plugin Grafana) lendo `/Sessions` → tabela no Grafana.

## Objetivos
1. Corrigir o painel Memory (refIds únicos).
2. Fazer o node_exporter enxergar as interfaces do host.
3. Tabela **Clients** (Media): User, Device, Client/App, IP, Now Playing, progresso.
4. Enriquecer os 3 dashboards com as métricas de alto valor hoje não mostradas.
5. Legibilidade: no disco, mostrar **total** e **livre** além do %.

## Não-objetivos
- Alertas. - Nova TSDB. - Substituir Beszel/Jellyfin.

## Chamadas do builder
- Infinity provisionado via `GF_INSTALL_PLUGINS=yesoreyeram-infinity-datasource`
  + provisioning YAML (aponta p/ `http://jellyfin:8096`, header `Authorization:
  MediaBrowser Token=<JELLYFIN_TOKEN>`). Fallback se o plugin não instalar:
  `json_exporter` expondo `/Sessions`.
- node_exporter: `--path.procfs=/host/proc --path.sysfs=/host/sys
  --path.rootfs=/host` + mounts `/proc` e `/sys` (mantém scrape interno).

## Mudanças por dashboard
### Server
- Corrigir Memory (refIds).
- **Disk usage**: tabela com `Mount | Used % (gauge) | Total | Free`.
- Novos painéis: **Pressure (PSI)** cpu/mem/io; **Disk latency & IOPS**
  (`node_disk_*_time_seconds_total`, `*_completed_total`); **TCP errors/retrans**
  (`Tcp_RetransSegs`, `Tcp_InErrs`, `Tcp_OutRsts`, `TCPSynRetrans`) e **TIME_WAIT**
  (`node_sockstat_TCP_tw`); **NTP sync** (`node_timex_sync_status`); **NVMe used**;
  **CPU frequency**.
### Services
- **Network por serviço** (`container_network_receive/transmit_bytes_total`).
- **OOM kills** (`container_oom_events_total`).
- **TLS cert expiry** (`gatus_results_certificate_expiration_seconds`).
- **HTTP codes** (`gatus_results_code_total`).
### Media
- **Clients** (tabela Infinity do `/Sessions`) com IP.
- **Now playing**: progresso/restante (`jellyfin_now_playing_progress/remaining`).
- **Library**: counts por tipo (`jellyfin_media_count`), `jellyfin_user_active`.

## O que fica para o builder
- Reescrever o gerador dos dashboards com **refIds únicos automáticos**.
- Provisionar Infinity + datasource + painel.
- Ajustar compose do node_exporter e validar `device` = eno2/wt0.
- Validar tudo e atualizar `docs/observability.md`.