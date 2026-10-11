# Stack de mídia: Jellyfin + Seerr + *arr

Fluxo de catálogo, requisições e download automático.

```
Usuário → Seerr (catálogo/request)
              │  (API)
              ▼
           Radarr ─── Prowlarr (indexadores)
              │  (download client)
              ▼
          qBittorrent ──► /homelab/media/downloads
              │  (import / hardlink)
              ▼
     /homelab/media/biblioteca/movies ──► Jellyfin (assiste)
```

## Componentes

| Container    | Função                                   | Porta |
|--------------|------------------------------------------|-------|
| `seerr`      | Catálogo (TMDB) + requisições            | 5055  |
| `radarr`     | Automação de filmes                       | 7878  |
| `prowlarr`   | Gerenciamento de indexadores/trackers    | 9696  |
| `qbittorrent`| Download client                           | 8080  |
| `jellyfin`   | Servidor de mídia                         | 8096  |

## Caminhos (path consistency)

Para que **hardlinks** e **atomic moves** funcionem (sem copiar arquivos), os
containers precisam ver os mesmos caminhos:

| Container    | Host                                  | Container    |
|--------------|---------------------------------------|--------------|
| `qbittorrent`| `/homelab/media/downloads`            | `/downloads` |
| `radarr`     | `/homelab/media/downloads`            | `/downloads` |
| `radarr`     | `/homelab/media/biblioteca/movies`    | `/movies`    |
| `jellyfin`   | `/homelab/media/biblioteca`           | `/media/biblioteca:ro` |

> Downloads e biblioteca devem estar no **mesmo filesystem** para o hardlink.

## Configuração (ordem)

1. **Prowlarr** (`prowlarr.piccollo.stream`)
   - Adicione seus indexadores (trackers).
   - Settings → Apps → adicione **Radarr** (URL `http://radarr:7878` + API key).
2. **Radarr** (`radarr.piccollo.stream`)
   - Settings → Media Management → Root Folder: `/movies`.
   - Settings → Download Clients → **qBittorrent**
     (`http://qbittorrent:8080`, usuário/senha).
3. **Seerr** (`seerr.piccollo.stream`)
   - Login com admin do **Jellyfin** (URL interna `http://jellyfin:8096`).
   - Settings → General: **TMDB API key** + Application URL
     `https://seerr.piccollo.stream`.
   - Settings → Services → **Radarr** (`http://radarr:7878`, API key, root
     `/movies`, quality profile).
4. **Jellyfin**: garanta que a biblioteca aponta para
   `/media/biblioteca/movies` (dentro do container).

## Redes

Cada stack tem seu **próprio projeto/nome** (não compartilhe `name:` entre stacks —
senão o `up --remove-orphans` de uma remove os containers da outra).

- **Immich**: o `immich-server` fica em `proxy_net` (para o Caddy) **e** em
  `immich_internal` (rede interna, isolada). `database`, `redis` e
  `immich-machine-learning` ficam **só** em `immich_internal`.
  > Se você colocar só o `immich-server` numa rede e o `database` na default,
  > o server não resolve `database` (`getaddrinfo EAI_AGAIN database`).

## Uso

- O usuário busca/requisita no **Seerr**.
- O Radarr manda para o **qBittorrent**; ao concluir, importa para `/movies`.
- O **Jellyfin** detecta e o título aparece na biblioteca.

> Para **assistir enquanto baixa**, veja [`jellyfreedom.md`](jellyfreedom.md).
