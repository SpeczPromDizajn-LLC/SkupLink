#!/usr/bin/env bash
# SkupLink — install for Ubuntu / Debian (systemd).
# Run from this directory: sudo bash install.sh
#
# Required next to this script:
#   SkupLink
#   web/
#   config.example.json
#   skuplink.service

set -euo pipefail

BIN_DST="/usr/local/bin/SkupLink"
WEB_DST="/usr/local/bin/web"
CFG_DIR="/etc/skuplink"
CFG_DST="${CFG_DIR}/config.json"
UNIT_DST="/etc/systemd/system/skuplink.service"
SERVICE_NAME="skuplink"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_SRC="${SCRIPT_DIR}/SkupLink"
WEB_SRC="${SCRIPT_DIR}/web"
CFG_SRC="${SCRIPT_DIR}/config.example.json"
UNIT_SRC="${SCRIPT_DIR}/skuplink.service"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
  die "run as root: sudo bash $0"
fi

[[ -f "${BIN_SRC}" ]] || die "missing ${BIN_SRC}"
[[ -d "${WEB_SRC}" ]] || die "missing ${WEB_SRC}/"
[[ -f "${CFG_SRC}" ]] || die "missing ${CFG_SRC}"
[[ -f "${UNIT_SRC}" ]] || die "missing ${UNIT_SRC}"

echo "Installing SkupLink from ${SCRIPT_DIR}"
echo "  binary : ${BIN_SRC} -> ${BIN_DST}"
echo "  web    : ${WEB_SRC}/ -> ${WEB_DST}/"
echo "  config : ${CFG_SRC} -> ${CFG_DST} (only if missing)"
echo "  unit   : ${UNIT_SRC} -> ${UNIT_DST}"

install -d "$(dirname "${BIN_DST}")"
install -d "${WEB_DST}"
install -d "${CFG_DIR}"

install -m 755 "${BIN_SRC}" "${BIN_DST}"
rm -rf "${WEB_DST:?}/"*
cp -a "${WEB_SRC}/." "${WEB_DST}/"

if [[ ! -f "${CFG_DST}" ]]; then
  install -m 644 "${CFG_SRC}" "${CFG_DST}"
  echo "  created ${CFG_DST}"
else
  echo "  kept existing ${CFG_DST}"
fi

install -m 644 "${UNIT_SRC}" "${UNIT_DST}"

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"

echo
systemctl --no-pager --full status "${SERVICE_NAME}" || true
echo
echo "Done. Web UI: http://127.0.0.1:8847/"
