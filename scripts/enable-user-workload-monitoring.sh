#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

OC_BIN="${OC_BIN:-oc}"
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

require "${OC_BIN}"
require jq

if ! "${OC_BIN}" whoami >/dev/null 2>&1; then
  echo "[ERROR] oc não está autenticado. Execute oc login com usuário válido." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
config_file="${tmpdir}/config.yaml"

if "${OC_BIN}" -n openshift-monitoring get configmap cluster-monitoring-config >/dev/null 2>&1; then
  "${OC_BIN}" -n openshift-monitoring get configmap cluster-monitoring-config \
    -o jsonpath='{.data.config\.yaml}' >"${config_file}" 2>/dev/null || true
else
  : >"${config_file}"
fi

if grep -qE '^enableUserWorkload:' "${config_file}"; then
  sed -i -E 's/^enableUserWorkload:.*/enableUserWorkload: true/' "${config_file}"
else
  if [[ -s "${config_file}" ]]; then
    printf '\n' >>"${config_file}"
  fi
  printf 'enableUserWorkload: true\n' >>"${config_file}"
fi

payload="$(jq -n --arg config "$(cat "${config_file}")" '{data: {"config.yaml": $config}}')"

if "${OC_BIN}" -n openshift-monitoring get configmap cluster-monitoring-config >/dev/null 2>&1; then
  "${OC_BIN}" -n openshift-monitoring patch configmap cluster-monitoring-config \
    --type=merge \
    -p "${payload}" >/dev/null
else
  "${OC_BIN}" -n openshift-monitoring create configmap cluster-monitoring-config \
    --from-file=config.yaml="${config_file}" >/dev/null
fi

echo "[OK] User Workload Monitoring habilitado em openshift-monitoring/cluster-monitoring-config."
echo "[INFO] Aguarde os pods em openshift-user-workload-monitoring ficarem Running."
