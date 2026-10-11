# Observabilidade

Stack de monitoramento **como código** (configuração versionada no git):

| Serviço | Função | Domínio | Imagem |
|---------|--------|---------|--------|
| **Gatus** | Uptime/health checks declarativos (YAML) | `status.piccollo.stream` | `twinproduction/gatus` |
| **Beszel** | Métricas de host e containers | `beszel.piccollo.stream` | `henrygd/beszel` + `beszel-agent` |
| **Dozzle** | Logs dos containers em tempo real | `logs.piccollo.stream` | `amir20/dozzle` |

## Gatus

Arquivo: `network/monitoring/gatus/config/config.yaml`.

- Checks HTTP a cada 1 minuto contra os serviços na rede `proxy_net`
  (Jellyfin `/health`, Radarr `/ping`, Vaultwarden `/alive`, etc.).
- Histórico em SQLite (`/config/gatus.db`).
- Página de status em `status.piccollo.stream`.

### Adicionar um novo check

```yaml
endpoints:
  - name: MeuServico
    group: Media
    url: "http://meu-container:porta/health"
    interval: 1m
    conditions:
      - "[STATUS] == 200"
```

### Alertas (opcional)

No próprio `config.yaml`, descomente a seção `alerting`:

```yaml
alerting:
  discord:
    webhook-url: "${DISCORD_WEBHOOK}"
  telegram:
    token: "${TELEGRAM_TOKEN}"
    id: "${TELEGRAM_CHAT_ID}"
```

## Beszel

Hub + agente (mesma máquina, via socket unix).

- Hub: `beszel` (porta 8090), dados em `./beszel_data`.
- Agente: `beszel-agent` (`network_mode: host`), monta o socket do Docker.

### Setup

1. Suba a stack: `cd network/monitoring/beszel && docker compose up -d`.
2. Acesse `http://<host>:8090`, crie a conta de admin.
3. **Add System** → copie `KEY` e `TOKEN` para
   `network/monitoring/beszel/.env` (veja `.env.example`) e recrie o agente:

```bash
cp .env.example .env   # preencha BESZEL_KEY e BESZEL_TOKEN
docker compose up -d
```

## Dozzle

- Logs de todos os containers em tempo real, somente leitura
  (`/var/run/docker.sock:ro`).
- Sem configuração adicional.

## Segurança

- **Gatus**, **Beszel** e **Dozzle** não têm auth forte por padrão.
  Proteja-os no **Cloudflare Access** (veja `cloudflare.md`) ou mantenha só na
  **VPN NetBird**.
- Alternativamente, Gatus suporta basic auth (`security.basic` no `config.yaml`).

## Rotas

Adicionadas ao `Caddyfile`:

```caddy
http://status.piccollo.stream { reverse_proxy gatus:8080 }
http://beszel.piccollo.stream { reverse_proxy beszel:8090 }
http://logs.piccollo.stream   { reverse_proxy dozzle:8080 }
```

Crie os Public Hostnames correspondentes no Cloudflare Tunnel
(`status.`, `beszel.`, `logs.` → `http://caddy:80`).
