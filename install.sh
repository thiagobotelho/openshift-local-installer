#!/usr/bin/env bash

set -euo pipefail

# === Variáveis ===
CRC_ARCHIVE="bin/crc/crc-linux-amd64.tar.xz"
INSTALL_DIR="/usr/local/bin"
PULL_SECRET_FILE="./config/pull-secret"
CRC_MEMORY="${CRC_MEMORY:-16384}"
CRC_CPUS="${CRC_CPUS:-4}"
CRC_DISK_SIZE="${CRC_DISK_SIZE:-200}"
DEPLOY_GITOPS=false

usage() {
    echo "Uso: $0 [--deploy-gitops]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deploy-gitops) DEPLOY_GITOPS=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[ERROR] Opção desconhecida: $1"; usage; exit 2 ;;
    esac
    shift
done

# === Verificações iniciais ===
function check_prerequisites() {
    if [[ ! -s "$PULL_SECRET_FILE" ]]; then
        echo "[ERROR] Pull secret ausente ou vazio em '$PULL_SECRET_FILE'."
        exit 1
    fi
    if ! jq -e '.auths | type == "object"' "$PULL_SECRET_FILE" >/dev/null 2>&1; then
        echo "[ERROR] Pull secret inválido: esperado JSON com a chave 'auths'."
        exit 1
    fi

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

    sudo install -m 0755 "${CRC_DIR}/crc" "$INSTALL_DIR/crc"
}

# === Setup do CRC ===
function setup_crc() {
    echo "[INFO] Executando crc setup e configurações..."
    crc config set consent-telemetry no
    crc setup
    crc config set memory "$CRC_MEMORY"
    crc config set cpus "$CRC_CPUS"
    crc config set disk-size "$CRC_DISK_SIZE"
    crc config set pull-secret-file "$PULL_SECRET_FILE"
}

# === Start do cluster ===
function start_crc() {
    echo "[INFO] Iniciando o cluster OpenShift Local..."
    crc start
}

function deploy_gitops() {
    [[ "$DEPLOY_GITOPS" == true ]] || return 0

    echo "[INFO] Instalando OpenShift GitOps e o App-of-Apps..."
    eval "$(crc oc-env)"
    oc apply -k "https://github.com/thiagobotelho/argocd-gitops//base?ref=main"
    oc wait --for=condition=Available deployment/openshift-gitops-server \
        -n openshift-gitops --timeout=10m

    # O root Application reconcilia os repositórios declarados em base/apps.
    oc apply -k "https://github.com/thiagobotelho/argocd-gitops//overlays/apps?ref=main"

    echo "[INFO] Sincronize aplicações gradualmente conforme a memória disponível."
}

# === Execução sequencial ===
check_prerequisites
install_crc
setup_crc
start_crc
deploy_gitops

echo "[SUCCESS] Instalação concluída. Execute 'crc console' para abrir a UI."
