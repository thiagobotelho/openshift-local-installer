#!/usr/bin/env bash

set -euo pipefail

# === Variáveis ===
CRC_ARCHIVE="bin/crc/crc-linux-amd64.tar.xz"
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
    if [ ! -f "$CRC_ARCHIVE" ]; then
        echo "[ERROR] Arquivo '$CRC_ARCHIVE' não encontrado. Verifique o caminho."
        exit 1
    fi

    tar -xf "$CRC_ARCHIVE" -C ./bin
    CRC_DIR=$(find ./bin -maxdepth 1 -type d -name "crc-linux-*-amd64" | head -n1)

    if [ -z "$CRC_DIR" ]; then
        echo "[ERROR] Diretório CRC não encontrado após extração."
        exit 1
    fi

    sudo cp "${CRC_DIR}/crc" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/crc"
}

# === Setup do CRC ===
function setup_crc() {
    echo "[INFO] Executando crc setup e configurações..."
    crc config set consent-telemetry no
    crc setup
    crc config set memory 16384
    crc config set cpus 2
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
