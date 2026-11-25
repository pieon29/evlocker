#!/usr/bin/env bash
set -euo pipefail

CONFTEST_VERSION=0.56.0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${HOME}/.local/bin"
mkdir -p "${BIN}"

if ! command -v conftest >/dev/null 2>&1 && [ ! -x "${BIN}/conftest" ] && [ ! -x "${BIN}/conftest.exe" ]; then
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) asset="conftest_${CONFTEST_VERSION}_Windows_x86_64.zip" ;;
    Darwin) asset="conftest_${CONFTEST_VERSION}_Darwin_$(uname -m).tar.gz" ;;
    *) asset="conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" ;;
  esac
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/${asset}" "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/${asset}"
  case "${asset}" in
    *.zip) unzip -q -o "${tmp}/${asset}" -d "${tmp}" ;;
    *) tar -xzf "${tmp}/${asset}" -C "${tmp}" ;;
  esac
  cp "${tmp}"/conftest* "${BIN}/" 2>/dev/null || true
  rm -rf "${tmp}"
fi
export PATH="${BIN}:${PATH}"

cd "${ROOT}/terraform"
mkdir -p .plan
terraform plan -input=false -out .plan/tfplan
terraform show -json .plan/tfplan > .plan/tfplan.json
set +e
conftest test --policy policy .plan/tfplan.json
rc=$?
set -e
rm -f .plan/tfplan.json
exit "${rc}"
