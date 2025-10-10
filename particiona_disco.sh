#!/bin/bash

# Script para particionar automáticamente un disco con una sola partición
# Uso: ./particionar_disco.sh /dev/sdX

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para mostrar mensajes
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se proporcionó el dispositivo
if [ $# -eq 0 ]; then
    echo "Uso: $0 /dev/sdX"
    echo "Ejemplo: $0 /dev/sdb"
    exit 1
fi

DISCO=$1

# Verificar si el disco existe
if [ ! -b "$DISCO" ]; then
    log_error "El dispositivo $DISCO no existe"
    exit 1
fi

# Verificar si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root"
    exit 1
fi

# Mostrar información del disco
log_info "Información del disco $DISCO:"
fdisk -l $DISCO

# Confirmación del usuario
read -p "¿Estás seguro de que quieres particionar $DISCO? (s/N): " confirmacion
if [[ ! $confirmacion =~ ^[Ss]$ ]]; then
    log_info "Operación cancelada"
    exit 0
fi

# Crear tabla de particiones GPT
log_info "Creando tabla de particiones GPT..."
parted -s $DISCO mklabel gpt

# Crear una sola partición que use todo el disco
log_info "Creando partición que usa todo el disco..."
parted -s $DISCO mkpart primary ext4 0% 100%

# Formatear la partición como ext4
PARTICION="${DISCO}1"
log_info "Formateando $PARTICION como ext4..."
mkfs.ext4 -F $PARTICION

log_info "¡Particionado completado!"
log_info "Partición creada: $PARTICION"
