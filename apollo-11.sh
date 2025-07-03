#!/usr/bin/env bash
set -euo pipefail

# Parámetros de simulación
min_files=1
max_files=3
min_lines=1
max_lines=5

# Calcular cantidad de archivos a crear
num_files=$(( RANDOM % (max_files - min_files + 1) + min_files ))
echo "Creando $num_files archivo(s)..."

# Asegurarse de que exista la carpeta devices
mkdir -p devices

# Arrays de valores posibles
misiones=(ORBONE CLNM TMRS GALXONE UNKN)
device_types=(satellite ship suit vehicle)
statuses=(excellent good warning faulty killed unknown)

# Precalcular longitudes
n_misiones=${#misiones[@]}
n_types=${#device_types[@]}
n_status=${#statuses[@]}

for ((i=1; i<=num_files; i++)); do
  # Misión aleatoria
  mission=${misiones[RANDOM % n_misiones]}

  # Formatear ID de archivo
  id=$(printf "%05d" "$i")
  file="devices/APL-${mission}-${id}.log"

  # Cantidad aleatoria de líneas (1 a 5)
  n_lines=$(( RANDOM % (max_lines - min_lines + 1) + min_lines ))

  {
    # Header único
    printf "date\tmission\tdevice_type\tdevice_status\thash\n"

    # Generar registros
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

  echo "  — $file ($n_lines registros)"
done

echo "Simulación completa. Archivos en devices/."
