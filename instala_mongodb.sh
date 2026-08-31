#!/bin/bash

set -euo pipefail

###########
# Preludio
###########

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

###############
# instalación de software faltante
###############

PACKAGES=(
    "python3.12"
    "python3.12-devel"
    "lsof"
    "lvm2"
    "wget"
    "zip"
)

for package in "${PACKAGES[@]}"; do
    if rpm -q "$package" >/dev/null 2>&1; then
        log_info "$package está instalado"
    else
        log_warn "$package no está instalado, se instala ahora"
        sudo dnf install -y $package
    fi
done

##############
# Formateo de discos
##############
curl -LO https://raw.githubusercontent.com/vcdgibbs/utiles/refs/heads/main/particiona_disco_v2.sh
chmod +x particiona_disco_v2.sh

sudo particiona_disco_v2.sh -q /dev/sdb
sudo particiona_disco_v2.sh -q /dev/sdc

###############
# Modificar GRUB
###############

GRUB_FILE="/etc/default/grub"
PARAMS="numa=off transparent_hugepage=never scsi_mod.use_blk_mq=1 dm_mod.use_blk_mq=y"

# Backup
sudo cp -a "$GRUB_FILE" "${GRUB_FILE}.bak"

# Añadir los parámetros a GRUB_CMDLINE_LINUX_DEFAULT
sudo sed -i -E \
  "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"|\1 ${PARAMS}\"|" \
  "$GRUB_FILE"

# Regenerar configuración de GRUB
sudo grub2-mkconfig -o /boot/grub2/grub.cfg --update-bls-cmdline

# echo "Parámetros GRUB añadidos correctamente."
log_info "Parámetros GRUB añadidos correctamente."
sudo grubby --info=DEFAULT | grep '^args'


######
# Modificar sysctl.conf
######

SYSCTL_FILE="/etc/sysctl.conf"

# Backup
sudo cp -a "$SYSCTL_FILE" "${SYSCTL_FILE}.bak"

# Remove existing definitions
sudo sed -i \
    -e '/^[[:space:]]*vm\.zone_reclaim_mode[[:space:]]*=/d' \
    -e '/^[[:space:]]*vm\.max_map_count[[:space:]]*=/d' \
    -e '/^[[:space:]]*net\.ipv4\.tcp_fin_timeout[[:space:]]*=/d' \
    -e '/^[[:space:]]*net\.ipv4\.tcp_keepalive_intvl[[:space:]]*=/d' \
    -e '/^[[:space:]]*net\.ipv4\.tcp_keepalive_time[[:space:]]*=/d' \
    -e '/^[[:space:]]*net\.ipv4\.tcp_max_syn_backlog[[:space:]]*=/d' \
    -e '/^[[:space:]]*net\.ipv4\.tcp_keepalive_probes[[:space:]]*=/d' \
    -e '/^[[:space:]]*net\.core\.somaxconn[[:space:]]*=/d' \
    "$SYSCTL_FILE"

# Add configuration
sudo tee -a "$SYSCTL_FILE" > /dev/null <<'EOF'

# Network and VM tuning
vm.zone_reclaim_mode=0
vm.max_map_count=131060
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_keepalive_probes=6
net.core.somaxconn=4096
EOF

# Apply configuration
sudo sysctl -p "$SYSCTL_FILE"

# echo "sysctl configuration applied successfully."
log_info "Configuración sysctl exitosa"

###############
# Crea usuario mongod si no exite
###############

check_user() {
    local USERNAME="$1"

    if ! id "$USERNAME" >/dev/null 2>&1; then
        echo "[ERROR] El usuario '$USERNAME' no existe."
        return 1
    fi

    echo "[OK] El usuario '$USERNAME' existe."

    if id -nG "$USERNAME" | grep -qw wheel; then
        echo "[OK] El usuario '$USERNAME' pertenece al grupo wheel."
    else
        echo "[INFO] El usuario '$USERNAME' no pertenece al grupo wheel."
    fi

    if sudo -l -U "$USERNAME" >/dev/null 2>&1; then
        echo "[OK] El usuario '$USERNAME' tiene permisos sudo."
    else
        echo "[ERROR] El usuario '$USERNAME' NO tiene permisos sudo."
        return 1
    fi
}


USERNAME="mongod"
# Crear usuario si no existe
if ! id "$USERNAME" >/dev/null 2>&1; then
    #echo "[INFO] Creando usuario '$USERNAME'..."
    log_info "Creando usuario '$USERNAME'..."
    sudo useradd \
        --create-home \
        --user-group \
        "$USERNAME"

    echo "[OK] Usuario '$USERNAME' creado."
fi

# Crear configuración sudoers
if ! sudo test -f "/etc/sudoers.d/$USERNAME"; then
    #echo "[INFO] Configurando sudoers para '$USERNAME'..."
    log_info "Configurando sudoers para '$USERNAME'..."
    sudo tee "/etc/sudoers.d/$USERNAME" > /dev/null <<EOF
$USERNAME ALL=(ALL) ALL
EOF

    sudo chmod 440 "/etc/sudoers.d/$USERNAME"

    if sudo visudo -cf "/etc/sudoers.d/$USERNAME" >/dev/null 2>&1; then
        #echo "[OK] Sudoers configurado."
        log_info "Sudoers configurado."
    else
        #echo "[ERROR] Configuración sudoers inválida."
        log_error "Configuración sudoers inválida."
        sudo rm -f "/etc/sudoers.d/$USERNAME"
        exit 1
    fi
fi


# Comprobar configuración final
check_user "$USERNAME"

#########################
## Modificar limits.conf
#########################

LIMITS_FILE="/etc/security/limits.conf"

# Backup
sudo cp -a "$LIMITS_FILE" "${LIMITS_FILE}.bak"

# Eliminar configuraciones anteriores de mongod
sudo sed -i '/^[[:space:]]*mongod[[:space:]]/d' "$LIMITS_FILE"

# Agregar límites para mongod
sudo tee -a "$LIMITS_FILE" > /dev/null <<'EOF'

# MongoDB limits
mongod hard  cpu      unlimited
mongod soft  cpu      unlimited
mongod hard  memlock  unlimited
mongod soft  memlock  unlimited
mongod hard  as       unlimited
mongod soft  as       unlimited
mongod hard  fsize    unlimited
mongod soft  fsize    unlimited
mongod soft  nofile   64000
mongod hard  nofile   64000
mongod soft  nproc    64000
mongod hard  nproc    64000
EOF

#echo "[OK] Límites de mongod configurados en $LIMITS_FILE"
log_info "Límites de mongod configurados en $LIMITS_FILE"

########################
# Armar la estructura de directorios
########################

sudo mkdir /mongodb_software
sudo mkdir /mongodb

UUID_B=$(lsblk -no UUID /dev/sdb1)
UUID_C=$(lsblk -no UUID /dev/sdc1)

sudo cp /etc/fstab /etc/fstab.bak

sudo tee -a /etc/fstab  > /dev/null<<EOF
UUID=${UUID_B} /mongodb_software ext4 defaults 0 0
UUID=${UUID_C} /mongodb          ext4 defaults 0 0
EOF

sudo systemctl daemon-reload
sudo mount /mongodb_software
sudo mount /mongodb

sudo mkdir /mongodb_software/bin
sudo mkdir /mongodb/data
sudo mkdir /mongodb/log

sudo chown -R mongod:mongod /mongodb
