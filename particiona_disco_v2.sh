#!/bin/bash

# Script para particionar automáticamente un disco con una sola partición
# Uso: ./particionar_disco.sh /dev/sdX
# Opción silenciosa: ./particionar_disco.sh -q /dev/sdX

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables por defecto
QUIET_MODE=false
DISCO=""

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

# Función de ayuda
show_help() {
    echo "Uso: $0 [OPCIONES] /dev/sdX"
    echo ""
    echo "Opciones:"
    echo "  -q, --quiet    Modo silencioso (sin confirmaciones)"
    echo "  -h, --help     Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 /dev/sdb                    # Modo interactivo"
    echo "  $0 -q /dev/sdb                 # Modo silencioso"
    echo "  $0 --quiet /dev/sdc            # Modo silencioso"
    exit 0
}

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            log_error "Opción desconocida: $1"
            echo "Use -h para ver la ayuda"
            exit 1
            ;;
        *)
            if [[ -z "$DISCO" ]]; then
                DISCO=$1
            else
                log_error "Demasiados argumentos: $1"
                echo "Use -h para ver la ayuda"
                exit 1
            fi
            shift
            ;;
    esac
done

# Verificar si se proporcionó el dispositivo
if [ -z "$DISCO" ]; then
    log_error "No se especificó el dispositivo"
    echo "Uso: $0 [OPCIONES] /dev/sdX"
    echo "Use -h para ver la ayuda completa"
    exit 1
fi

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

# Confirmación del usuario (a menos que esté en modo silencioso)
if [ "$QUIET_MODE" = false ]; then
    read -p "¿Estás seguro de que quieres particionar $DISCO? (s/N): " confirmacion
    if [[ ! $confirmacion =~ ^[Ss]$ ]]; then
        log_info "Operación cancelada"
        exit 0
    fi
else
    log_warn "Modo silencioso activado - procediendo sin confirmación"
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

# Mostrar información final
if [ "$QUIET_MODE" = false ]; then
    log_info "Resultado final:"
    lsblk -f $DISCO
fi
