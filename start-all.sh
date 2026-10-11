#!/usr/bin/env bash
set -euo pipefail

# Diretório raiz do repositório (onde este script está localizado)
HOMELAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="proxy_net"

echo "=========================================="
echo " Iniciando stacks do Homelab: $(date)"
echo " Raiz: $HOMELAB_DIR"
echo "=========================================="

# 1. Garante a rede global compartilhada (usada como 'external' por todos os composes)
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "--> Criando rede compartilhada: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
else
  echo "--> Rede $NETWORK_NAME já existe"
fi

# 2. Varre todos os diretórios que possuem docker-compose.yml / compose.yml
# Ordena por caminho para respeitar nomes como 00-core, 01-dashboard, 02-media
find "$HOMELAB_DIR" -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) \
  -not -path "*/.git/*" | sort | while read -r compose_file; do
  dir="$(dirname "$compose_file")"

  echo ""
  echo "------------------------------------------"
  echo " Stack encontrada em: $dir"
  echo "------------------------------------------"

  (
    cd "$dir"
    # Valida sintaxe antes de subir
    if docker compose config -q >/dev/null 2>&1; then
      docker compose up -d --remove-orphans
    else
      echo " WARNING: Falha na validação da stack em $dir. Pulando..."
    fi
  )
done

echo ""
echo "=========================================="
echo " Todas as stacks foram processadas!"
echo "=========================================="
