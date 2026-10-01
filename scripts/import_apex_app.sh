#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: APEX_DB_CONNECT="<SQLcl connect string>" %s <100|200|300|400|500> <export.sql>\n' "$0" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

case "$1" in
  100|200|300|400|500) ;;
  *) printf 'Erreur: ID APEX attendu : 100, 200, 300, 400 ou 500.\n' >&2; exit 2 ;;
esac

if [[ ! -f "$2" ]]; then
  printf 'Erreur: export SQL introuvable: %s\n' "$2" >&2
  exit 2
fi

if ! command -v sql >/dev/null 2>&1; then
  printf 'Erreur: SQLcl (commande sql) est requis.\n' >&2
  exit 127
fi

: "${APEX_DB_CONNECT:?Définis APEX_DB_CONNECT avec la chaîne de connexion SQLcl.}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export_file="$(realpath -- "$2")"

exec sql -S "$APEX_DB_CONNECT" \
  "@$script_dir/../apex/apps/import_app.sql" "$1" "$export_file"
