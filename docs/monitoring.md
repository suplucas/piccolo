# Observabilidade

Stack de monitoramento **como código** (configuração versionada no git):

| Serviço | Função | Acesso (só VPN NetBird) | Imagem |
|---------|--------|-------------------------|--------|
| **Gatus** | Uptime/health checks declarativos (YAML) | `http://100.90.38.203:8081` | `twinproduction/gatus` |
| **Beszel** | Métricas de host e containers | `http://100.90.38.203:8090` | `henrygd/beszel` + `beszel-agent` |
| **Dozzle** | Logs dos containers em tempo real | `http://100.90.38.203:8082` | `amir20/dozzle` |

> Os três **não têm autenticação** e ficam **fora do túnel**: sem Public Hostname,
> publicados somente na interface NetBird (`100.90.38.203`). Veja `cloudflare.md`.

## Gatus

Arquivo: `network/monitoring/gatus/config/config.yaml`.

- Checks HTTP a cada 1 minuto contra os serviços na rede `proxy_net`
  (Jellyfin `/health`, Radarr `/ping`, Vaultwarden `/alive`, etc.).
- Histórico em SQLite (`/config/gatus.db`).
- Página de status em `http://100.90.38.203:8081` (só VPN).

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
2. Acesse `http://100.90.38.203:8090`, crie a conta de admin.
3. **Add System** → copie `KEY` e `TOKEN` para
   `network/monitoring/beszel/.env` (veja `.env.example`) e recrie o agente:

```bash
cp .env.example .env   # preencha BESZEL_KEY e BESZEL_TOKEN
docker compose up -d
```

## Dozzle

- Logs de todos os containers em tempo real, somente leitura
  (`/var/run/docker.sock:ro`).
- Monta um volume em **`/data`** (`dozzle_data`) para persistir configurações —
  sem ele, o Dozzle mostra *"`/data` is not mounted, so this can't be saved"*.
- Sem configuração adicional.

> ⚠️ **Segurança**: o Dozzle tem acesso equivalente a **root** no host (via
> `docker.sock`). Nunca exponha sem autenticação — use **Cloudflare Access**
> (veja `cloudflare.md`) ou habilite `DOZZLE_AUTH_PROVIDER=simple` (users.yml).
> Mantenha `DOZZLE_ENABLE_ACTIONS`/`DOZZLE_ENABLE_SHELL` desligados se não precisar.

## Segurança

- **Gatus**, **Beszel** e **Dozzle** não têm auth forte por padrão — por isso
  ficam **só na VPN NetBird** (sem Public Hostname no túnel). As portas são
  publicadas**somente** na interface `100.90.38.203`.
- Se quiser expor algum publicamente no futuro, use **Cloudflare Access**
  (veja `cloudflare.md`) ou, no Gatus, basic auth (`security.basic`).

## Acesso na VPN

Publicação das portas (somente na interface NetBird):

```yaml
# network/monitoring/gatus/docker-compose.yml
ports: ["100.90.38.203:8081:8080/tcp"]
```

```yaml
# network/monitoring/dozzle/docker-compose.yml
ports: ["100.90.38.203:8082:8080/tcp"]
```

```yaml
# network/monitoring/beszel/docker-compose.yml
ports: ["100.90.38.203:8090:8090/tcp"]
```

Registre o IP do host no NetBird (`ip addr show wt0`) e acesse pelo IP da VPN.
