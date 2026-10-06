#!/usr/bin/env bash
# Usage (depuis le dossier apps/, avec app-pos/ et app-stock/ a cote des zips):
#   bash fix_ir_columns.sh string   # variante 1 : VARCHAR2 -> STRING
#   bash fix_ir_columns.sh strip    # variante 2 : supprime les blocs source{dataType} des colonnes IR
#
# Hypothese : ORA-02290 WWV_FLOW_VALID_WS_COL_TYPE vient d'un dataType de colonne IR
# (VARCHAR2) que le runtime APEX 26.1 ne mappe pas vers STRING/NUMBER/DATE/CLOB.
set -euo pipefail

MODE="${1:-string}"
APPS=(app-pos app-stock)

for app in "${APPS[@]}"; do
  [ -d "$app" ] || { echo "Dossier $app introuvable (decompressez $app.zip ici)"; exit 1; }
  # sauvegarde unique de la version d'origine
  [ -f "$app.zip.orig" ] || { [ -f "$app.zip" ] && cp "$app.zip" "$app.zip.orig"; }

  while IFS= read -r -d '' f; do
    cp -n "$f" "$f.orig"
    case "$MODE" in
      string)
        # uniquement dans les blocs column (source indente de 12 espaces)
        perl -0pi -e 's/(\n {12}source \{\n {16}dataType: )(?:VARCHAR2|varchar2|CHAR|char)(\n {12}\})/$1STRING$2/g' "$f"
        ;;
      strip)
        perl -0pi -e 's/\n {12}source \{\n {16}dataType: \w+\n {12}\}//g' "$f"
        ;;
      *) echo "Mode inconnu : $MODE"; exit 1 ;;
    esac
    echo "patche ($MODE) : $f"
  done < <(grep -rlZ 'type: interactiveReport' "$app" --include='*.apx')

  rm -f "$app.zip"
  zip -qr "$app.zip" "$app"
  echo "zip regenere : $app.zip"
done

echo
echo "Ensuite, dans SQLcl 26.2 (hote) :"
echo "  apex import -workspace REGAL -input app-pos.zip"
echo "  apex import -workspace REGAL -input app-stock.zip"
echo "(une commande par ligne, sans les coller ensemble)"
echo "Retour arriere : copiez les fichiers *.orig / *.zip.orig sur les originaux."
