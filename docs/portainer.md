# Portainer atrás do Caddy (domínio público)

O Portainer serve **HTTPS** na `9443` com **certificado self-signed**, e HTTP na
`9000`. Ao colocá-lo atrás do Caddy há três detalhes que causam erro se
ignorados: o **scheme**, os **cookies `Secure`** e o **CSRF/Origin**.

## Caddyfile

```caddy
http://portainer.piccollo.stream {
	# Portainer serve HTTPS (self-signed) na 9443
	reverse_proxy https://portainer:9443 {
		header_up X-Forwarded-Proto https
		transport http {
			tls_insecure_skip_verify
		}
	}
}
```

Por que:

- **`https://portainer:9443` + `tls_insecure_skip_verify`**: a 9443 é TLS com
  cert self-signed; sem isso o Caddy tenta HTTP e falha, ou não valida o cert.
- **`header_up X-Forwarded-Proto https`**: o túnel Cloudflare fala HTTP com o
  Caddy, então por padrão o Caddy mandaria `X-Forwarded-Proto: http` — mas o
  browser está em HTTPS. Deixar explícito como `https` mantém a visão do
  Portainer igual à do browser (evita logout/`401` por cookie `Secure`).

> Alternativa: habilitar o HTTP do Portainer (`--http-enabled`, porta 9000) e
> fazer `reverse_proxy portainer:9000`. Mais simples, porém o cookie não fica
> `Secure`. A abordagem TLS acima é a recomendada.

## docker-compose

```yaml
command:
  - --trusted-origins=https://portainer.piccollo.stream
```

- **`--trusted-origins`**: evita o erro **"Origin invalid"** (proteção CSRF)
  quando o `Origin` do browser (`https://portainer.piccollo.stream`) é comparado
  com o `Host` encaminhado.

> ⚠️ **`--trusted-proxies` não existe no Portainer 2.45.x (tag `:lts`)** — usar
> esse flag faz o container falhar com `unknown long flag`. Ele serve apenas
> para mostrar o IP real na aba *Authentication logs*; sem ele, aparece o IP do
> proxy. Só use se a sua versão do Portainer suportar (`--help` para conferir).

## Observações

- **CSP / iframe**: o Portainer envia `frame-ancestors 'none'` por padrão — ele
  **não pode ser embutido em iframe**. No Glance, o link abre em nova aba (ok).
- **Porta 8000**: é o túnel de **Edge Agents**. Se você não usa Edge, pode
  remover `8000:8000`.
- **Segurança**: proteja o `portainer.piccollo.stream` no **Cloudflare Access**
  (veja `cloudflare.md`), já que o Portainer dá controle total sobre os
  containers.
