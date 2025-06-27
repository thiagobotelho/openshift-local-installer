#!/usr/bin/env bash

set -euo pipefail

# === Variáveis ===
CRC_ARCHIVE="crc-linux-amd64.tar.xz"
INSTALL_DIR="/usr/local/bin"
PULL_SECRET_FILE="./config/pull-secret"

# === Verificações iniciais ===
function check_prerequisites() {
    echo "[INFO] Instalando dependências..."
    sudo dnf install -y libvirt virt-install jq podman curl tar

    echo "[INFO] Habilitando serviços..."
    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt "$USER"
}

# === Instalação do CRC ===
function install_crc() {
    echo "[INFO] Extraindo e instalando CRC..."
    tar -xf "$CRC_ARCHIVE"
    CRC_DIR=$(find . -maxdepth 1 -type d -name "crc-linux-*-amd64" | head -n1)
    sudo cp "${CRC_DIR}/crc" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/crc"
}

# === Setup do CRC ===
function setup_crc() {
    echo "[INFO] Executando crc setup e configurações..."
    crc setup
    crc config set memory 16384
    crc config set cpus 4
    crc config set pull-secret-file "$PULL_SECRET_FILE"
}

# === Start do cluster ===
function start_crc() {
    echo "[INFO] Iniciando o cluster OpenShift Local..."
    crc start
}

# === Execução sequencial ===
check_prerequisites
install_crc
setup_crc
start_crc

echo "[SUCCESS] Instalação concluída. Execute 'crc console' para abrir a UI."
