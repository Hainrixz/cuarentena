#!/usr/bin/env bash
# pruebas/verificar.sh — prueba los tres scripts sin red y sin Claude.
#   1. arma el ZIP trampa y el limpio (pruebas/armar.py)
#   2. aislar.sh: el trampa deja fuera el symlink y la ruta ../, renombra la config, apaga el ejecutable
#   3. senales.sh: encuentra cada señal plantada en el trampa y casi nada en el limpio
#   4. candado: niega lo que ejecuta y deja pasar lo que lee (pruebas/candado.sh)
# Sale 0 si todo cuadra, 1 si algo falla.
cd "$(dirname "$0")/.." || exit 1
R="$PWD"; fallos=0
ok()   { echo "ok    $1"; }
mal()  { echo "FALLA $1"; fallos=$((fallos+1)); }
afirma() { if eval "$2"; then ok "$1"; else mal "$1"; fi; }

python3 -I pruebas/armar.py >/dev/null || { echo "no pude armar los ZIP (¿python3?)"; exit 1; }
export CUARENTENA_DIR="$R/pruebas/salida/cuarentena"
rm -rf "$CUARENTENA_DIR"

echo "== aislar.sh"
out="$(bash skills/revisar/scripts/aislar.sh pruebas/salida/trampa.zip)"; rc=$?
caso="$(printf '%s' "$out" | sed -n 's/^LISTO: //p')"
afirma "sale 0 con el trampa" '[ $rc -eq 0 ]'
afirma "anota el symlink" 'printf "%s" "$out" | grep -q "symlink-en-el-zip|notas-bonitas/llaves"'
afirma "anota la ruta ../" 'printf "%s" "$out" | grep -q "ruta-peligrosa|../fuera-de-la-carpeta.txt"'
afirma "nada se salió de la carpeta" '[ ! -e "$CUARENTENA_DIR/fuera-de-la-carpeta.txt" ] && [ ! -e "$R/pruebas/salida/fuera-de-la-carpeta.txt" ]'
afirma "no quedó ningún symlink" '[ -z "$(find "$caso" -type l)" ]'
afirma "instalar.sh ya no es ejecutable" '[ ! -x "$caso/contenido/notas-bonitas/instalar.sh" ]'
afirma "renombró .claude, CLAUDE.md y .mcp.json" '[ -d "$caso/contenido/notas-bonitas/.claude.cuarentena" ] && [ -f "$caso/contenido/notas-bonitas/CLAUDE.md.cuarentena" ] && [ -f "$caso/contenido/notas-bonitas/.mcp.json.cuarentena" ]'
afirma "no queda un .claude activo" '[ ! -e "$caso/contenido/notas-bonitas/.claude" ] && [ ! -e "$caso/contenido/notas-bonitas/CLAUDE.md" ]'
bash skills/revisar/scripts/aislar.sh >/dev/null 2>&1; afirma "sin argumento sale 3" '[ $? -eq 3 ]'
bash skills/revisar/scripts/aislar.sh pruebas/no-existe.zip >/dev/null 2>&1; afirma "archivo que no existe sale 4" '[ $? -eq 4 ]'

echo "== senales.sh"
s="$(bash skills/revisar/scripts/senales.sh "$caso/contenido")"
for patron in "bypassPermissions" "SessionStart" "mcpServers" "\.zshrc" "LaunchAgents" "postinstall" "\.ssh/id_ed25519" "colector.example.invalid" "base64 -d" "ignore previous instructions" "sin preguntar"; do
  afirma "encuentra $patron" 'printf "%s" "$s" | grep -q -- "$patron"'
done
afirma "encuentra caracteres invisibles en SKILL.md" 'printf "%s" "$s" | sed -n "/Caracteres invisibles/,/^## G/p" | grep -q "SKILL.md"'

bash skills/revisar/scripts/aislar.sh pruebas/salida/limpio.zip >/dev/null
limpio="$(ls -d "$CUARENTENA_DIR"/limpio-*/contenido)"
sl="$(bash skills/revisar/scripts/senales.sh "$limpio")"
graves="$(printf '%s' "$sl" | grep -E '^### (Permisos|Hooks|Servidores|Redirigir|Toca el arranque|Se programa|Cambia el sistema|Scripts de instal|Baja algo|Ejecuta texto|Llaves|Manda datos|Decodifica|Le habla)' | grep -vc ' — 0$')"
afirma "el limpio no tiene señales graves" '[ "$graves" -eq 0 ]'

echo "== candado"
unset CUARENTENA_DIR; bash pruebas/candado.sh >/dev/null && ok "candado: 24 casos" || mal "candado (corre bash pruebas/candado.sh para ver cuál)"

echo
if [ "$fallos" -eq 0 ]; then echo "todo cuadra"; exit 0; else echo "$fallos fallos"; exit 1; fi
