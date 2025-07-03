#!/usr/bin/env bash
set -euo pipefail

# Parámetros globales
min_files=1; max_files=10
min_lines=1; max_lines=5
misiones=(ORBONE CLNM TMRS GALXONE UNKN)
device_types=(satellite ship suit vehicle)
statuses=(excellent good warning faulty killed unknown)

# ── Funciones ────────────────────────────────────────────────────────

simular() {
  # Genera los archivos .log bajo devices/
  local num_files=$(( RANDOM % (max_files - min_files + 1) + min_files ))
  echo "→ Simulando $num_files archivo(s)…"
  mkdir -p devices
  local n_misiones=${#misiones[@]}
  local n_types=${#device_types[@]}
  local n_status=${#statuses[@]}

  for ((i=1; i<=num_files; i++)); do
    local mission=${misiones[RANDOM % n_misiones]}
    local id=$(printf "%05d" "$i")
    local file="devices/APL-${mission}-${id}.log"
    local n_lines=$(( RANDOM % (max_lines - min_lines + 1) + min_lines ))

    {
      printf "date\tmission\tdevice_type\tdevice_status\thash\n"
      for ((j=1; j<=n_lines; j++)); do
        ts=$(date +"%d%m%y%H%M%S")
        dt=${device_types[RANDOM % n_types]}
        ds=${statuses[RANDOM % n_status]}
        if [[ "$mission" != "UNKN" ]]; then
          raw="${ts}${mission}${dt}${ds}"
          hash=$(echo -n "$raw" | md5sum | cut -d' ' -f1)
        else
          hash="unknown"
        fi
        printf "%s\t%s\t%s\t%s\t%s\n" "$ts" "$mission" "$dt" "$ds" "$hash"
      done
    } > "$file"

    echo "  • $file ($n_lines registros)"
  done
}

consolidar() {
  # Consolida todos los .log existentes y los mueve a backups
  local ts=$(date +"%d%m%y%H%M%S")
  local out="devices/APLSTATS-CONSOLIDATION-${ts}.log"
  # Creamos un subdirectorio de backups con el mismo timestamp
  local backup_dir="devices/backups/${ts}"
  echo "→ Consolidando en $out…"
  mkdir -p "$backup_dir"
  local first; first=$(ls devices/APL-*.log | head -n1)

  # Header
  head -n1 "$first" > "$out"
  # Datos y mover cada log al subbackup
  for f in devices/APL-*.log; do
    tail -n +2 "$f" >> "$out"
    mv "$f" "$backup_dir/"
  done

  echo "  • Registros consolidados: $(( $(wc -l < "$out") - 1 ))"
  echo "  • Archivos originales movidos a $backup_dir/"
}


usage() {
  cat <<EOF
Uso: $0 <comando>
Comandos disponibles:
  simular       Genera los archivos de simulación
  consolidar    Consolida y respalda los logs
  todo          Ejecuta simular + consolidar (y luego reportes)
  help          Muestra esta ayuda
EOF
}

# ── Dispatcher ───────────────────────────────────────────────────────

case "${1-}" in
  simular)   simular ;;
  consolidar)consolidar ;;
  todo)      simular; consolidar ;;
  help|*)    usage; exit 1 ;;
esac
