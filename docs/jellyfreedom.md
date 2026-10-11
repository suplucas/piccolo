# JellyFreedom — assistir enquanto baixa

O **Seerr + Radarr** só colocam o filme no Jellyfin **após o download terminar**
(o Radarr importa apenas arquivos completos). Para o caso "clico e assisto
enquanto baixa", a camada indicada é o **JellyFreedom**.

> Fonte: <https://moontheripper.github.io/JellyFreedom/> ·
> <https://github.com/MoonTheRipper/JellyFreedom>

## O que é

Um serviço que busca torrents nas fontes que **você** configura, faz o título
**aparecer no Jellyfin na hora** e faz **streaming sob demanda** — mantendo em
memória (com limite de tamanho) apenas o trecho sendo assistido. O disco não
enche.

- ✅ Integra direto no Jellyfin (TV, celular, navegador).
- ✅ Streaming enquanto baixa, sem ocupar disco.
- ⚠️ Tem **catálogo próprio** (não é o catálogo do Seerr).
- ⚠️ Exige um arquivo **WireGuard** de VPN (o tráfego só sai pelo túnel).
- ⚠️ É instalado como **serviço systemd** (não é Docker).

## Requisitos

- Um provedor de **VPN WireGuard** (arquivo `.conf`) — sem ele nada transfere.
- Porta `1990` para o dashboard (ajustável).

## Instalação (no servidor)

Debian/Ubuntu:

```bash
curl -fsSL https://github.com/MoonTheRipper/JellyFreedom/releases/latest/download/get.sh | sudo bash
```

Depois:

1. Abra `http://<host>:1990/dashboard/` e crie a conta de admin.
2. Faça upload do arquivo **WireGuard** de VPN.
3. Configure as **fontes** (indexadores) e aponte para o **Jellyfin**.
4. (Opcional) Exponha via Caddy — adicione ao `Caddyfile`:

```caddy
http://jelly.piccollo.stream {
	reverse_proxy <host>:1990
}
```

> Como roda como serviço no host (não em `proxy_net`), o Caddy precisa alcançar
> o host. Use o IP do host na rede Docker ou `host.docker.internal` conforme o
> seu setup.

## Como convive com o Seerr

- **Seerr + Radarr**: catálogo/requests → biblioteca permanente (arquivo baixado).
- **JellyFreedom**: "assistir agora" sob demanda, para o que ainda não está na
  biblioteca.

Os dois usam o mesmo Jellyfin; cada um no seu papel.

## Observações

- Sem VPN configurada, o JellyFreedom **não transfere nada** (por design).
- É um projeto independente, não afiliado ao Jellyfin.
