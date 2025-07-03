#!/usr/bin/env bash
set -euo pipefail

#
# apollo-11.sh
#
# Simula generación de logs de misiones espaciales, consolida datos,
# genera reportes y organiza todo por ejecución en carpetas independientes.
#
# Uso general:
#   ./apollo-11.sh [--min-files N] [--max-files M] [--min-lines L] [--max-lines K] \
#                  [--interval S] [--base-dir DIR] <comando>
#
# Opciones (antes del comando):
#   --min-files N    Mínimo de archivos a simular (por defecto 1)
#   --max-files M    Máximo de archivos a simular (por defecto 10)
#   --min-lines L    Mínimo de registros por archivo (por defecto 1)
#   --max-lines K    Máximo de registros por archivo (por defecto 5)
#   --interval S     Intervalo en segundos para bucle automático (por defecto 20)
#   --base-dir DIR   Carpeta raíz para ejecuciones (por defecto "runs")
#
# Comandos:
#   simular         Genera los archivos de simulación
#   consolidar      Consolida y respalda los logs
#   events          Genera el reporte de eventos
#   disconnections  Genera el reporte de desconexiones (unknown)
#   killed          Genera el reporte de inoperables (killed)
#   percentages     Genera el reporte de porcentajes por misión y dispositivo
#   reports         Ejecuta todos los reportes anteriores
#   todo            Ejecuta simular, consolidar y todos los reportes
#   loop            Ejecuta “todo” en bucle cada <interval> segundos
#   help            Muestra esta ayuda
#

# ── Valores por defecto ──────────────────────────────────────────────────
min_files=1; max_files=10
min_lines=1; max_lines=5
interval=20
base_dir="runs"

# ── Parseo de opciones globales ──────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --min-files)    min_files=$2; shift 2 ;;
    --max-files)    max_files=$2; shift 2 ;;
    --min-lines)    min_lines=$2; shift 2 ;;
    --max-lines)    max_lines=$2; shift 2 ;;
    --interval)     interval=$2; shift 2 ;;
    --base-dir)     base_dir=$2; shift 2 ;;
    --)             shift; break ;;
    -*)
      echo "Opción desconocida: $1"; exit 1 ;;
    *) break ;;
  esac
done

# Carpeta y timestamp inicial (se usa para simular/consolidar fuera de loop)
ts=$(date +"%d%m%y%H%M%S")
run_dir="${base_dir}/${ts}"

# Arrays de valores posibles
misiones=(ORBONE CLNM TMRS GALXONE UNKN)
device_types=(satellite ship suit vehicle)
statuses=(excellent good warning faulty killed unknown)

# Crear estructura de carpetas base para la ejecución inicial
mkdir -p "${run_dir}/devices" "${run_dir}/backups" "${run_dir}/reports"

# ── Funciones ───────────────────────────────────────────────────────────

simular() {
  # Genera archivos .log en run_dir/devices/
  local num_files=$(( RANDOM % (max_files - min_files + 1) + min_files ))
  echo "→ Simulando $num_files archivo(s)…"
  local n_misiones=${#misiones[@]}

  for ((i=1; i<=num_files; i++)); do
    local mission=${misiones[RANDOM % n_misiones]}
    local id=$(printf "%05d" "$i")
    local file="${run_dir}/devices/APL-${mission}-${id}.log"
    local n_lines=$(( RANDOM % (max_lines - min_lines + 1) + min_lines ))

    {
      # Header único
      printf "date\tmission\tdevice_type\tdevice_status\thash\n"
      for ((j=1; j<=n_lines; j++)); do
        ts_line=$(date +"%d%m%y%H%M%S")
        # Si misión = UNKN, todos los campos unknown
        if [[ "$mission" == "UNKN" ]]; then
          device_type="unknown"
          device_status="unknown"
          hash="unknown"
        else
          device_type=${device_types[RANDOM % ${#device_types[@]}]}
          device_status=${statuses[RANDOM % ${#statuses[@]}]}
          raw="${ts_line}${mission}${device_type}${device_status}"
          hash=$(echo -n "$raw" | md5sum | cut -d' ' -f1)
        fi
        printf "%s\t%s\t%s\t%s\t%s\n" \
          "$ts_line" "$mission" "$device_type" "$device_status" "$hash"
      done
    } > "$file"

    echo "  • $file ($n_lines registros)"
  done
}

consolidar() {
  # Consolida y respalda logs de run_dir/devices/
  local in_dir="${run_dir}/devices"
  local out="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"
  echo "→ Consolidando en $out…"

  # Si no hay archivos, avisar y salir
  shopt -s nullglob
  files=("$in_dir"/APL-*.log)
  if (( ${#files[@]} == 0 )); then
    echo "  ¡No hay archivos para consolidar!"
    return
  fi

  # Header del primer archivo
  head -n1 "${files[0]}" > "$out"
  # Añadir datos y mover al backup
  for f in "${files[@]}"; do
    tail -n +2 "$f" >> "$out"
    mv "$f" "${run_dir}/backups/"
  done

  echo "  • Registros consolidados: $(( $(wc -l < "$out") - 1 ))"
  echo "  • Originales movidos a ${run_dir}/backups/"
}

report_events() {
  # Conteo por misión, estado y dispositivo
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"
  local out="${run_dir}/reports/APLSTATS-EVENTS-${ts}.log"
  {
    printf "mission\tdevice_status\tdevice_type\tcount\n"
    awk -F'\t' 'NR>1 { key=$2"\t"$4"\t"$3; c[key]++ }
      END { for (k in c) print k"\t"c[k] }' "$in"
  } > "$out"
}

report_disconnections() {
  # Dispositivos con status “unknown”
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"
  local out="${run_dir}/reports/APLSTATS-DISCONNECTIONS-${ts}.log"
  {
    printf "mission\tdevice_type\tunknown_count\n"
    awk -F'\t' 'NR>1 && $4=="unknown" { key=$2"\t"$3; c[key]++ }
      END { for (k in c) print k"\t"c[k] }' "$in"
  } > "$out"
}

report_killed() {
  # Dispositivos inoperables (status “killed”)
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"
  local out="${run_dir}/reports/APLSTATS-KILLED-${ts}.log"
  {
    printf "mission\tkilled_count\n"
    awk -F'\t' 'NR>1 && $4=="killed" { c[$2]++ }
      END { for (m in c) print m"\t"c[m] }' "$in"
  } > "$out"
}

report_percentages() {
  # Porcentaje de registros por misión y dispositivo
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"
  local out="${run_dir}/reports/APLSTATS-PERCENTAGES-${ts}.log"
  {
    printf "mission\tdevice_type\tpercent\n"
    total=$(awk 'END{print NR-1}' "$in")
    awk -F'\t' -v tot="$total" 'NR>1 { key=$2"\t"$3; c[key]++ }
      END {
        for (k in c) printf "%s\t%.2f%%\n", k, (c[k]/tot*100)
      }' "$in"
  } > "$out"
}

report_all() {
  report_events
  report_disconnections
  report_killed
  report_percentages
}

usage() {
  cat <<EOF
Uso: $0 [opciones] <comando>
Opciones:
  --min-files N    Mín de archivos (por defecto $min_files)
  --max-files M    Máx de archivos (por defecto $max_files)
  --min-lines L    Mín de líneas (por defecto $min_lines)
  --max-lines K    Máx de líneas (por defecto $max_lines)
  --interval S     Intervalo para 'loop' (por defecto $interval s)
  --base-dir DIR   Carpeta raíz de ejecuciones (por defecto $base_dir)

Comandos:
  simular         Genera los archivos de simulación
  consolidar      Consolida y respalda los logs
  events          Genera el reporte de eventos
  disconnections  Genera el reporte de desconexiones (unknown)
  killed          Genera el reporte de inoperables (killed)
  percentages     Genera el reporte de porcentajes
  reports         Ejecuta todos los reportes
  
  todo            simular, consolidar y luego reportes
  loop            Ejecuta 'todo' en bucle cada <interval> segundos,
                  creando una nueva carpeta run por ciclo
  help            Muestra esta ayuda
EOF
}

# ── Dispatcher ────────────────────────────────────────────────────────
case "${1-:-}" in
  simular)       simular ;;
  consolidar)    consolidar ;;
  events)        report_events ;;
  disconnections)report_disconnections ;;
  killed)        report_killed ;;
  percentages)   report_percentages ;;
  reports)       report_all ;;
  todo)          simular; consolidar; report_all ;;
  loop)          # Bucle de ejecuciones periódicas: nueva run por iteración
                 while true; do
                   ts=$(date +"%d%m%y%H%M%S")
                   run_dir="${base_dir}/${ts}"
                   mkdir -p "${run_dir}/devices" "${run_dir}/backups" "${run_dir}/reports"
                   simular
                   consolidar
                   report_all
                   sleep "$interval"
                 done ;;
  help|*)        usage; exit 1 ;;
esac
