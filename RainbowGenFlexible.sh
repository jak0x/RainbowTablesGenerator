#!/bin/bash

set -e

# ========================
# Rainbow Table Generator
# Nivel 1 + Nivel 2 + Nivel 3
# ========================

START_TIME=$(date +%s)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
GENERAL_LOG="$LOG_DIR/rainbowgen_$TIMESTAMP.log"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MAX_THREADS=$(nproc)
USER_THREADS=$MAX_THREADS
COMPRESS="false"
UPLOAD_ONLY="false"
CONFIG_FILE=""
IS_MULTI="false"

# Funciones
print_help() {
  echo -e "${GREEN}Rainbow Table Generator - Paralelizado con subida a S3${NC}"
  echo "\nUso básico:"
  echo "  $0 [FLAGS] [--config <archivo.json>]"
  echo "\nFlags disponibles:"
  echo "  --config <archivo>    Archivo de configuración JSON"
  echo "  --upload-only         Solo subir archivos .rt o .gz a S3"
  echo "  --multi               Ejecutar múltiples trabajos desde JSON"
  echo "  --threads <n>         Número de hilos a usar (máximo: $MAX_THREADS)"
  echo "  --compress            Comprimir los archivos .rt antes de subir"
  echo "  -h, --help            Muestra esta ayuda"
  echo "\nEjemplo completo:"
  echo "  $0 --config config.json --multi"
  exit 0
}

check_cpu_load() {
  LOAD=$(awk '{print $1}' /proc/loadavg)
  while (( $(echo "$LOAD > $MAX_THREADS" | bc -l) )); do
    echo -e "${YELLOW}⚠️ Carga alta ($LOAD), esperando...${NC}"
    sleep 2
    LOAD=$(awk '{print $1}' /proc/loadavg)
  done
}

upload_existing_files() {
  echo -e "${GREEN}→ Subiendo archivos locales existentes a S3...${NC}"
  find . -maxdepth 1 -type f \( -name "*.rt" -o -name "*.rt.gz" \) | while read -r file; do
    aws s3 cp "$file" "s3://${S3_BUCKET}/tables/$(basename "$file")" && echo "✔ Subido $file"
  done
  exit 0
}

install_if_needed() {
  command -v aws >/dev/null || sudo apt install -y awscli
  command -v make >/dev/null || sudo apt install -y build-essential git
}

run_job() {
  local job_json=$1
  local algo charset min max chainlen chainnum table start parts
  
  algo=$(jq -r '.algo' <<< "$job_json")
  charset=$(jq -r '.charset' <<< "$job_json")
  min=$(jq -r '.min' <<< "$job_json")
  max=$(jq -r '.max' <<< "$job_json")
  chainlen=$(jq -r '.chainlen' <<< "$job_json")
  chainnum=$(jq -r '.chainnum' <<< "$job_json")
  table=$(jq -r '.table' <<< "$job_json")
  start=$(jq -r '.start' <<< "$job_json")
  parts=$(jq -r '.parts' <<< "$job_json")

  mkdir -p rainbow_tables
  cd rainbow_tables || exit 1
  
  PROGRESS=0
  SUCCESS_UPLOADS=0
  
  generate_table() {
    local part_index=$1
    local file_prefix="${algo}_${charset}_${min}_${max}_${chainlen}_${chainnum}_${table}_${part_index}_${parts}"
    local file_name="${algo}_${charset}_${min}_${max}#${chainlen}x${chainnum}#${table}_${part_index}_${parts}.rt"
    local part_log="../$LOG_DIR/${file_prefix}.log"

    echo -e "${YELLOW}→ [$part_index] Verificando tabla...${NC}" | tee -a "$GENERAL_LOG"
    if [[ -f "$file_name" ]]; then
      echo -e "${YELLOW}↪ [$part_index] Ya existe $file_name. Saltando generación.${NC}" | tee -a "$GENERAL_LOG"
    else
      ../rainbowcrack/src/rtgen $algo $charset $min $max $table $chainlen $chainnum $part_index $parts &> "$part_log"
    fi

    if [[ -f "$file_name" && "$COMPRESS" == "true" ]]; then
      echo -e "${YELLOW}→ [$part_index] Comprimiendo...${NC}" | tee -a "$GENERAL_LOG"
      gzip -f "$file_name"
      file_name="$file_name.gz"
    fi

    echo -e "${YELLOW}→ [$part_index] Subiendo $file_name a S3...${NC}" | tee -a "$GENERAL_LOG"
    if [[ -f "$file_name" ]]; then
      aws s3 cp "$file_name" "s3://${S3_BUCKET}/tables/$(basename "$file_name")" && SUCCESS_UPLOADS=$((SUCCESS_UPLOADS+1))
    fi

    PROGRESS=$((PROGRESS+1))
    echo -e "${GREEN}[PROGRESO] ${PROGRESS}/${parts} partes completadas${NC}"
  }

  JOBS=0
  for (( i=0; i<parts; i++ )); do
    part_index=$((start + i))
    check_cpu_load
    generate_table $part_index &
    JOBS=$((JOBS+1))
    if [[ "$JOBS" -ge "$USER_THREADS" ]]; then
      wait -n
      JOBS=$((JOBS-1))
    fi
  done
  wait
  cd ..
}

# ------------------------
# PARSEO DE FLAGS
# ------------------------

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift ;;
    --upload-only) UPLOAD_ONLY="true" ;;
    --multi) IS_MULTI="true" ;;
    --threads) USER_THREADS="$2"; shift ;;
    --compress) COMPRESS="true" ;;
    -h|--help) print_help ;;
    *) echo -e "${RED}❌ Opción desconocida: $1${NC}"; print_help ;;
  esac
  shift
done

# Validaciones
if [[ "$USER_THREADS" -gt "$MAX_THREADS" ]]; then
  echo -e "${RED}❌ No puedes usar más de $MAX_THREADS hilos.${NC}" && exit 1
fi

install_if_needed

# Modo solo subida
if [[ "$UPLOAD_ONLY" == "true" ]]; then
  [[ -z "$CONFIG_FILE" ]] && { echo -e "${RED}Necesitas especificar --config para saber el bucket.${NC}"; exit 1; }
  S3_BUCKET=$(jq -r '.global.bucket' "$CONFIG_FILE")
  upload_existing_files
fi

# Ejecutar trabajo/s desde JSON
if [[ -n "$CONFIG_FILE" ]]; then
  CONFIG=$(cat "$CONFIG_FILE")
  S3_BUCKET=$(jq -r '.global.bucket' <<< "$CONFIG")
  USER_THREADS=$(jq -r '.global.threads // $USER_THREADS' <<< "$CONFIG")
  COMPRESS=$(jq -r '.global.compress // false' <<< "$CONFIG")

  if [[ "$IS_MULTI" == "true" ]]; then
    echo -e "${GREEN}→ Ejecutando múltiples trabajos...${NC}"
    JOB_COUNT=$(jq '.jobs | length' <<< "$CONFIG")
    for ((j=0; j<JOB_COUNT; j++)); do
      JOB=$(jq ".jobs[$j]" <<< "$CONFIG")
      echo -e "${YELLOW}==> Trabajo $((j+1)) de $JOB_COUNT${NC}"
      run_job "$JOB"
    done
  else
    echo -e "${GREEN}→ Ejecutando trabajo único desde JSON...${NC}"
    JOB=$(jq '.jobs[0]' <<< "$CONFIG")
    run_job "$JOB"
  fi
else
  echo -e "${RED}❌ Debes usar --config para correr trabajos con esta versión.${NC}"
  exit 1
fi

# Resumen final
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_FMT=$(printf '%02d:%02d:%02d' $((DURATION/3600)) $((DURATION%3600/60)) $((DURATION%60)))

echo -e "\n${GREEN}================== RESUMEN FINAL ==================${NC}"
echo -e "⏱ Tiempo total: $DURATION_FMT"
echo -e "📄 Log general: $GENERAL_LOG"
echo -e "${GREEN}==================================================${NC}"
