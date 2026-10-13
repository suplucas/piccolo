#!/bin/sh
# Retenção estrita do Beszel: remove estatísticas com mais de RETENTION_DAYS.
# Roda como sidecar (root) para poder escrever no data.db (root-owned) e usa
# WAL do SQLite, então é seguro com o hub em execução.
#
# O built-in do Beszel só "agrega" (tiers até 30d), não apaga; este prune
# garante o teto de 14 dias pedido.
set -eu

RETENTION_DAYS="${RETENTION_DAYS:-14}"
INTERVAL="${PRUNE_INTERVAL:-86400}"   # 1x/dia
DB_DIR="${DB_DIR:-/data}"
DB="$DB_DIR/data.db"

apk add --no-cache sqlite >/dev/null 2>&1 || true

prune() {
  [ -f "$DB" ] || { echo "prune: $DB ainda não existe"; return 0; }
  echo "prune: removendo registros com mais de ${RETENTION_DAYS}d"
  # 'created' é TEXT no formato 'YYYY-MM-DD HH:MM:SS.mmmZ' (UTC) => comparação
  # lexicográfica por data funciona. Cutoff calculado pelo SQLite (evita
  # dependência de `date -d`, ausente no busybox do Alpine).
  sqlite3 "$DB" <<SQL
DELETE FROM system_stats          WHERE created < strftime('%Y-%m-%d %H:%M:%S','now','-${RETENTION_DAYS} days');
DELETE FROM container_stats       WHERE created < strftime('%Y-%m-%d %H:%M:%S','now','-${RETENTION_DAYS} days');
DELETE FROM alerts_history        WHERE created < strftime('%Y-%m-%d %H:%M:%S','now','-${RETENTION_DAYS} days');
DELETE FROM network_monitor_stats WHERE created < strftime('%Y-%m-%d %H:%M:%S','now','-${RETENTION_DAYS} days');
PRAGMA wal_checkpoint(TRUNCATE);
SQL
  echo "prune: concluído"
}

# roda imediatamente no start e depois a cada INTERVAL
while true; do
  prune || echo "prune: falhou (seguindo)"
  sleep "$INTERVAL"
done
