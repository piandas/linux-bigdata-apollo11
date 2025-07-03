#!/usr/bin/env bash

min=1
max=3
numero=$(( RANDOM % (max - min + 1) + min ))

# 1) Generar número aleatorio de archivos
echo "$numero archivo(s) por crear."

# 2) Asegurarse de que exista la carpeta devices
mkdir -p devices

# 3) Array con misiones disponibles
misiones=(ORBONE CLNM TMRS GALXONE UNKN)
n_misiones=${#misiones[@]}  # longitud del array

# 4) Bucle para crear archivos
for i in $(seq 1 "$numero"); do
    # Seleccionar una misión aleatoria
    index_mision=$(( RANDOM % n_misiones ))
    mission=${misiones[$index_mision]}

    # Formatear el ID del archivo con ceros a la izquierda
    id_formateado=$(printf "%05d" "$i")
    nombre_archivo="APL-${mission}-${id_formateado}.log"
    touch "devices/${nombre_archivo}"
done

echo "Se generaron $numero archivos en devices"
