#!/usr/bin/env bash
set -euo pipefail

HOMELAB_DIR="/homelab"
NETWORK_NAME="proxy-net"

echo "=========================================="
echo " Starting Homelab Stacks: $(date)"
echo "=========================================="

# 1. Garante a rede global compartilhada
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "--> Criando rede compartilhada: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
fi

# 2. Varre todos os diretórios que possuem docker-compose.yml / compose.yml
# Ignora subpastas se o arquivo compose for um sub-modulo importado por 'include' de um maestro
# Ordena por caminho para respeitar nomes como 00-core, 01-dashboard, 02-media
find "$HOMELAB_DIR" -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) | sort | while read -r compose_file; do
  dir="$(dirname "$compose_file")"
  
  # Opcional: Se for um sub-compose dentro de /media/jellyfin e já existir um maestro em /media/docker-compose.yml,
  # você pode deixar o maestro rodar ou deixar o find executar pasta a pasta.
  
  echo ""
  echo "------------------------------------------"
  echo " Stack encontrada em: $dir"
  echo "------------------------------------------"
  
  (
    cd "$dir"
    # Valida sintaxe antes de subir
    if docker compose config >/dev/null 2>&1; then
      docker compose up -d --remove-orphans
    else
      echo " WARNING: Falha na validação da stack em $dir. Pulando..."
    fi
  )
done

echo ""
echo "=========================================="
echo " All Stacks processing complete!"
echo "=========================================="
