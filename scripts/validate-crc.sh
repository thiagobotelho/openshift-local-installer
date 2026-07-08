#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

CRC_BIN="${CRC_BIN:-crc}"
OC_BIN="${OC_BIN:-oc}"
CRC_MIN_CPUS="${CRC_MIN_CPUS:-8}"
CRC_MIN_MEMORY_MIB="${CRC_MIN_MEMORY_MIB:-24576}"
EXPECTED_NAMESPACES="${EXPECTED_NAMESPACES:-openshift-gitops openshift-monitoring openshift-user-workload-monitoring keycloak-dev grafana zabbix observability tempo openshift-logging}"

if ! command -v "${CRC_BIN}" >/dev/null 2>&1; then
  bundled_crc="$(find "${ROOT_DIR}/bin" -maxdepth 2 -type f -name crc -perm -111 2>/dev/null | head -n 1)"
  if [[ -n "${bundled_crc}" ]]; then
    CRC_BIN="${bundled_crc}"
  fi
fi

if ! command -v "${OC_BIN}" >/dev/null 2>&1; then
  for candidate in "${HOME:-}/.local/bin/oc" "${ROOT_DIR}/bin/oc"; do
    if [[ -x "${candidate}" ]]; then
      OC_BIN="${candidate}"
      break
    fi
  done
fi

if ! command -v "${OC_BIN}" >/dev/null 2>&1 && [[ -d "${HOME:-}/.crc/cache" ]]; then
  bundled_oc="$(find "${HOME}/.crc/cache" -maxdepth 2 -type f -name oc -perm -111 2>/dev/null | sort | tail -n 1)"
  if [[ -n "${bundled_oc}" ]]; then
    OC_BIN="${bundled_oc}"
  fi
fi

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Comando obrigatório não encontrado: $1" >&2
    exit 1
  }
}

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

require "${CRC_BIN}"
require "${OC_BIN}"

echo "[INFO] Validando CRC/OpenShift Local..."
"${CRC_BIN}" status

if ! "${OC_BIN}" whoami >/dev/null 2>&1; then
  echo "[ERROR] oc não está autenticado. Execute oc login com usuário válido." >&2
  exit 1
fi
ok "oc autenticado em $("${OC_BIN}" whoami --show-server) como $("${OC_BIN}" whoami)"

configured_cpus="$("${CRC_BIN}" config get cpus 2>/dev/null | awk '{print $NF}' || true)"
configured_memory="$("${CRC_BIN}" config get memory 2>/dev/null | awk '{print $NF}' || true)"
monitoring_enabled="$("${CRC_BIN}" config get enable-cluster-monitoring 2>/dev/null | awk '{print $NF}' || true)"

if [[ "${configured_cpus:-0}" =~ ^[0-9]+$ ]] && (( configured_cpus < CRC_MIN_CPUS )); then
  warn "CRC CPUs=${configured_cpus}; recomendado para a stack: >= ${CRC_MIN_CPUS}."
fi
if [[ "${configured_memory:-0}" =~ ^[0-9]+$ ]] && (( configured_memory < CRC_MIN_MEMORY_MIB )); then
  warn "CRC memory=${configured_memory}MiB; recomendado: >= ${CRC_MIN_MEMORY_MIB}MiB."
fi
if [[ "${monitoring_enabled}" != "true" ]]; then
  warn "enable-cluster-monitoring não está true. Use: crc config set enable-cluster-monitoring true; crc stop; crc start"
else
  ok "enable-cluster-monitoring=true"
fi

echo "[INFO] Validando ClusterOperators..."
"${OC_BIN}" get co

for ns in ${EXPECTED_NAMESPACES}; do
  if "${OC_BIN}" get ns "${ns}" >/dev/null 2>&1; then
    ok "namespace ${ns}"
  else
    warn "namespace ausente: ${ns}"
  fi
done

echo "[INFO] Validando OpenShift Monitoring..."
"${OC_BIN}" -n openshift-monitoring get pods
"${OC_BIN}" -n openshift-user-workload-monitoring get pods
"${OC_BIN}" -n openshift-monitoring get configmap cluster-monitoring-config -o yaml 2>/dev/null || warn "cluster-monitoring-config ausente"

echo "[INFO] Validando rotas principais..."
"${OC_BIN}" get route -A | grep -E 'openshift-gitops|keycloak|grafana|zabbix' || warn "rotas principais não encontradas"

echo "[INFO] Validando aplicações Argo CD..."
"${OC_BIN}" get applications.argoproj.io -n openshift-gitops 2>/dev/null || warn "CRD Application/Argo CD não disponível"

ok "Validação CRC concluída."
