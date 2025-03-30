# Dockerfile para RainbowGen
FROM ubuntu:22.04

# Variables
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias necesarias
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    git \
    awscli \
    jq \
    bc \
    gzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar el script y dar permisos
COPY rainbow_gen_parallel_s3.sh ./
RUN chmod +x rainbow_gen_parallel_s3.sh

# Clonar y compilar RainbowCrack
RUN git clone https://github.com/rofl0r/rainbowcrack.git && \
    cd rainbowcrack/src && make && cd ../..

# Crear carpeta de logs y tablas
RUN mkdir -p logs rainbow_tables

# Definir punto de entrada
ENTRYPOINT ["/app/rainbow_gen_parallel_s3.sh"]
