#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_env_file() {
    local env_file="${ROOT_DIR}/.env"
    [[ -f "${env_file}" ]] || return 0

    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ "${line}" == *"="* ]] || continue

        local key="${line%%=*}"
        local value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        if [[ -z "${!key+x}" ]]; then
            export "${key}=${value}"
        fi
    done < "${env_file}"
}

load_env_file

# === Variáveis ===
CRC_ARCHIVE="${CRC_ARCHIVE:-bin/crc/crc-linux-amd64.tar.xz}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
PULL_SECRET_FILE="${PULL_SECRET_FILE:-./config/pull-secret}"
CRC_MEMORY="${CRC_MEMORY:-40960}"
CRC_CPUS="${CRC_CPUS:-10}"
CRC_DISK_SIZE="${CRC_DISK_SIZE:-200}"
ENABLE_CLUSTER_MONITORING="${ENABLE_CLUSTER_MONITORING:-true}"
ENABLE_USER_WORKLOAD_MONITORING="${ENABLE_USER_WORKLOAD_MONITORING:-false}"
ARGOCD_GITOPS_REF="${ARGOCD_GITOPS_REF:-main}"
ARGOCD_GITOPS_OVERLAY="${ARGOCD_GITOPS_OVERLAY:-desenvolvimento}"
DEPLOY_GITOPS=false

usage() {
    echo "Uso: $0 [--deploy-gitops]"
}

wait_for_resource() {
    local description="$1"
    shift
    local timeout="${TIMEOUT_SECONDS:-600}"
    local sleep_seconds="${SLEEP_SECONDS:-5}"
    local deadline=$((SECONDS + timeout))

    until "$@" >/dev/null 2>&1; do
        if (( SECONDS >= deadline )); then
            echo "[ERROR] Timeout aguardando ${description}."
            "$@" || true
            exit 1
        fi
        sleep "${sleep_seconds}"
    done
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

    echo "[INFO] Instalando dependências..."
    sudo dnf install -y libvirt virt-install jq podman curl tar

    if ! jq -e '.auths | type == "object"' "$PULL_SECRET_FILE" >/dev/null 2>&1; then
        echo "[ERROR] Pull secret inválido: esperado JSON com a chave 'auths'."
        exit 1
    fi

    echo "[INFO] Habilitando serviços..."
    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt "$USER"
}

# === Instalação do CRC ===
function install_crc() {
    echo "[INFO] Extraindo e instalando CRC..."
    if [ ! -f "$CRC_ARCHIVE" ]; then
        echo "[ERROR] Arquivo '$CRC_ARCHIVE' não encontrado."
        echo "[ERROR] Baixe o OpenShift Local em https://console.redhat.com/openshift/install/local"
        echo "[ERROR] e salve o pacote como '${CRC_ARCHIVE}'."
        exit 1
    fi

    mkdir -p ./bin
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
    crc config set memory "$CRC_MEMORY"
    crc config set cpus "$CRC_CPUS"
    crc config set disk-size "$CRC_DISK_SIZE"
    crc config set enable-cluster-monitoring "$ENABLE_CLUSTER_MONITORING"
    crc config set pull-secret-file "$PULL_SECRET_FILE"
    crc setup
}

# === Start do cluster ===
function start_crc() {
    echo "[INFO] Iniciando o cluster OpenShift Local..."
    crc start
}

function enable_user_workload_monitoring() {
    [[ "$ENABLE_USER_WORKLOAD_MONITORING" == "true" ]] || return 0

    echo "[INFO] Habilitando User Workload Monitoring..."
    eval "$(crc oc-env)"
    "${ROOT_DIR}/scripts/enable-user-workload-monitoring.sh"
}

function deploy_gitops() {
    [[ "$DEPLOY_GITOPS" == true ]] || return 0

    echo "[INFO] Instalando OpenShift GitOps e o App-of-Apps..."
    eval "$(crc oc-env)"
    raw_base="https://raw.githubusercontent.com/thiagobotelho/argocd-gitops/${ARGOCD_GITOPS_REF}/base"

    oc apply -f "${raw_base}/namespace.yaml"
    oc apply -f "${raw_base}/operatorgroup.yaml"
    oc apply -f "${raw_base}/subscription.yaml"

    wait_for_resource "CRD argocds.argoproj.io" \
        oc get crd argocds.argoproj.io

    wait_for_resource "Subscription openshift-gitops-operator com installedCSV" \
        oc -n openshift-gitops-operator get subscription openshift-gitops-operator \
        -o jsonpath='{.status.installedCSV}'

    csv="$(oc -n openshift-gitops-operator get subscription openshift-gitops-operator -o jsonpath='{.status.installedCSV}')"
    if [[ -n "${csv}" ]]; then
        oc -n openshift-gitops-operator wait \
            --for=jsonpath='{.status.phase}'=Succeeded \
            "csv/${csv}" \
            --timeout="${TIMEOUT_SECONDS:-600}s"
    fi

    oc apply -f "${raw_base}/argocd.yaml"
    oc apply -f "${raw_base}/clusterrolebinding.yaml"
    oc apply -f "${raw_base}/openshift-apiserver-check-endpoints-networkpolicy.yaml"

    wait_for_resource "deployment openshift-gitops-server" \
        oc -n openshift-gitops get deployment openshift-gitops-server

    oc wait --for=condition=Available deployment/openshift-gitops-server \
        -n openshift-gitops --timeout="${TIMEOUT_SECONDS:-600}s"

    # O root Application reconcilia os repositórios declarados em base/apps.
    oc apply -k "https://github.com/thiagobotelho/argocd-gitops//overlays/${ARGOCD_GITOPS_OVERLAY}?ref=${ARGOCD_GITOPS_REF}"

    echo "[INFO] Sincronize aplicações gradualmente conforme a memória disponível."
}

# === Execução sequencial ===
check_prerequisites
install_crc
setup_crc
start_crc
enable_user_workload_monitoring
deploy_gitops

echo "[SUCCESS] Instalação concluída. Execute 'crc console' para abrir a UI."
