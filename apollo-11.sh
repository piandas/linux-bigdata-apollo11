#!/usr/bin/env bash
set -euo pipefail

# Timestamp para esta ejecución y carpeta raíz
ts=$(date +"%d%m%y%H%M%S")
run_dir="runs/${ts}"

# Parámetros globales
min_files=1; max_files=10
min_lines=1; max_lines=5
misiones=(ORBONE CLNM TMRS GALXONE UNKN)
device_types=(satellite ship suit vehicle)
statuses=(excellent good warning faulty killed unknown)

# Crear estructura de carpetas base para la ejecución
mkdir -p "${run_dir}/devices" "${run_dir}/backups" "${run_dir}/reports"

# ── Funciones ────────────────────────────────────────────────────────

simular() {
  # Genera los archivos .log bajo run_dir/devices/
  local num_files=$(( RANDOM % (max_files - min_files + 1) + min_files ))
  echo "→ Simulando $num_files archivo(s)…"
  local n_misiones=${#misiones[@]}
  local n_types=${#device_types[@]}
  local n_status=${#statuses[@]}

  for ((i=1; i<=num_files; i++)); do
    local mission=${misiones[RANDOM % n_misiones]}
    local id=$(printf "%05d" "$i")
    local file="${run_dir}/devices/APL-${mission}-${id}.log"
    local n_lines=$(( RANDOM % (max_lines - min_lines + 1) + min_lines ))

    {
      printf "date\tmission\tdevice_type\tdevice_status\thash\n"
      for ((j=1; j<=n_lines; j++)); do
        ts_line=$(date +"%d%m%y%H%M%S")
        dt=${device_types[RANDOM % n_types]}
        ds=${statuses[RANDOM % n_status]}
        if [[ "$mission" != "UNKN" ]]; then
          raw="${ts_line}${mission}${dt}${ds}"
          hash=$(echo -n "$raw" | md5sum | cut -d' ' -f1)
        else
          hash="unknown"
        fi
        printf "%s\t%s\t%s\t%s\t%s\n" "$ts_line" "$mission" "$dt" "$ds" "$hash"
      done
    } > "$file"

    echo "  • $file ($n_lines registros)"
  done
}

consolidar() {
  # Consolida todos los .log existentes y los mueve a run_dir/backups/
  local out="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"
  echo "→ Consolidando en $out…"
  local first
  first=$(ls "${run_dir}/devices"/APL-*.log | head -n1)

  # Header
  head -n1 "$first" > "$out"
  # Datos y mover cada log al backup de esta ejecución
  for f in "${run_dir}/devices"/APL-*.log; do
    tail -n +2 "$f" >> "$out"
    mv "$f" "${run_dir}/backups/"
  done

  echo "  • Registros consolidados: $(( $(wc -l < "$out") - 1 ))"
  echo "  • Archivos originales movidos a ${run_dir}/backups/"
}

report_events() {
  # Genera reporte de eventos
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"   # CORREGIDO: ruta correcta
  local out="${run_dir}/reports/APLSTATS-EVENTS-${ts}.log"
  echo "→ Generando reporte de eventos en $out…"
  {
    printf "mission\tdevice_status\tdevice_type\tcount\n"
    awk -F'\t' 'NR>1 { key=$2"\t"$4"\t"$3; c[key]++ }
      END { for (k in c) print k"\t"c[k] }' "$in"
  } > "$out"
  echo "  • Hecho."
}

report_disconnections() {
  # Genera reporte de desconexiones (status "unknown")
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"   # CORREGIDO: ruta correcta
  local out="${run_dir}/reports/APLSTATS-DISCONNECTIONS-${ts}.log"
  echo "→ Generando reporte de desconexiones en $out…"
  {
    printf "mission\tdevice_type\tunknown_count\n"
    awk -F'\t' 'NR>1 && $4=="unknown" { key=$2"\t"$3; c[key]++ }
      END { for (k in c) print k"\t"c[k] }' "$in"
  } > "$out"
  echo "  • Hecho."
}

report_killed() {
  # Genera reporte de dispositivos inoperables (status "killed")
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"   # CORREGIDO: ruta correcta
  local out="${run_dir}/reports/APLSTATS-KILLED-${ts}.log"
  echo "→ Generando reporte de inoperables en $out…"
  {
    printf "mission\tkilled_count\n"
    awk -F'\t' 'NR>1 && $4=="killed" { c[$2]++ }
      END { for (m in c) print m"\t"c[m] }' "$in"
  } > "$out"
  echo "  • Hecho."
}

report_percentages() {
  # Genera reporte de porcentajes por misión y tipo de dispositivo
  local in="${run_dir}/reports/APLSTATS-CONSOLIDATION-${ts}.log"   # CORREGIDO: ruta correcta
  local out="${run_dir}/reports/APLSTATS-PERCENTAGES-${ts}.log"
  echo "→ Generando reporte de porcentajes en $out…"
  {
    printf "mission\tdevice_type\tpercent\n"
    local total
    total=$(awk 'END{print NR-1}' "$in")
    awk -F'\t' -v tot="$total" 'NR>1 { key=$2"\t"$3; c[key]++ }
      END {
        for (k in c) printf "%s\t%.2f%%\n", k, (c[k]/tot*100)
      }' "$in"
  } > "$out"
  echo "  • Hecho."
}

# Unifica todos los reportes
report_all() {
  report_events
  report_disconnections
  report_killed
  report_percentages
}

# ── Ayuda ────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Uso: $0 <comando>
Comandos disponibles:
  simular         Genera los archivos de simulación
  consolidar      Consolida y respalda los logs
  events          Genera el reporte de eventos
  disconnections  Genera el reporte de desconexiones (unknown)
  killed          Genera el reporte de inoperables (killed)
  percentages     Genera el reporte de porcentajes por misión y dispositivo
  reports         Ejecuta todos los reportes anteriores
  todo            Ejecuta simular, consolidar y todos los reportes
  help            Muestra esta ayuda
EOF
}

# ── Dispatcher ───────────────────────────────────────────────────────
case "${1-}" in
  simular)       simular ;;
  consolidar)    consolidar ;;
  events)        report_events ;;
  disconnections)report_disconnections ;;
  killed)        report_killed ;;
  percentages)   report_percentages ;;
  reports)       report_all ;;
  todo)          simular; consolidar; report_all ;;
  help|*)        usage; exit 1 ;;
esac
