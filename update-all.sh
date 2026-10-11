#!/usr/bin/env bash
set -euo pipefail

# Diretório raiz do repositório (onde este script está localizado)
HOMELAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="proxy_net"

# Opções: --no-pull pula o 'git pull' | --no-prune pula a limpeza de imagens
DO_GIT_PULL=1
DO_PRUNE=1
for arg in "$@"; do
  case "$arg" in
    --no-pull)  DO_GIT_PULL=0 ;;
    --no-prune) DO_PRUNE=0 ;;
    *) echo "Argumento desconhecido: $arg"; exit 1 ;;
  esac
done

echo "=========================================="
echo " Atualizando stacks do Homelab: $(date)"
echo " Raiz: $HOMELAB_DIR"
echo "=========================================="

# 1. Atualiza o repositório (baixa as últimas alterações de config)
if [ "$DO_GIT_PULL" -eq 1 ] && [ -d "$HOMELAB_DIR/.git" ]; then
  echo ""
  echo "--> git pull (atualizando o repositório)"
  git -C "$HOMELAB_DIR" pull --ff-only
fi

# 2. Garante a rede global compartilhada
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "--> Criando rede compartilhada: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
else
  echo "--> Rede $NETWORK_NAME já existe"
fi

# 3. Para cada stack: baixa imagens novas e recria os containers
find "$HOMELAB_DIR" -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) \
  -not -path "*/.git/*" | sort | while read -r compose_file; do
  dir="$(dirname "$compose_file")"

  echo ""
  echo "------------------------------------------"
  echo " Stack: $dir"
  echo "------------------------------------------"

  (
    cd "$dir"
    if docker compose config -q >/dev/null 2>&1; then
      # Baixa imagens novas; ignora falhas (ex.: imagens buildadas localmente)
      docker compose pull --quiet 2>/dev/null || docker compose pull 2>/dev/null || true
      # Recria somente o que mudou
      docker compose up -d --remove-orphans || echo " ERRO: falha ao subir a stack em $dir"
    else
      echo " WARNING: Falha na validação da stack em $dir. Pulando..."
    fi
  )
done

# 4. Limpeza opcional de imagens órfãs (não remove as em uso)
if [ "$DO_PRUNE" -eq 1 ]; then
  echo ""
  echo "--> Limpando imagens sem uso"
  docker image prune -f
fi

echo ""
echo "=========================================="
echo " Todas as stacks foram atualizadas!"
echo "=========================================="
