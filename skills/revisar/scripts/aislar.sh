#!/usr/bin/env bash
# aislar.sh — mete un ZIP, un .tar.gz, una carpeta o un repo de GitHub en cuarentena.
#
# Uso:   bash aislar.sh <origen>
#   <origen> = ruta a un .zip / .tar.gz / .tgz / .tar, ruta a una carpeta,
#              o https://github.com/<dueño>/<repo>
#
# Qué hace, en orden, y qué NO hace:
#   1. Crea ~/cuarentena/<nombre>-<fecha>/contenido/ (o $CUARENTENA_DIR si la defines).
#   2. Lista el archivo ANTES de abrirlo: rutas con "..", rutas absolutas y symlinks
#      no se extraen y quedan anotados como señal.
#   3. Extrae sin ejecutar nada. Nunca corre un instalador, un script ni un hook.
#   4. Quita el permiso de ejecución a todo y borra los symlinks (los anota antes).
#   5. Renombra lo que Claude Code u otros editores cargan solos (CLAUDE.md, .claude/,
#      .mcp.json, AGENTS.md, .cursor/, .vscode/...) agregándole ".cuarentena".
#   6. Escribe AISLAMIENTO.txt con todo lo anterior y la huella sha256 del origen.
#
# Salida: 0 aislado · 3 uso incorrecto · 4 no se pudo aislar (se explica en pantalla).
# No necesita nada instalado: usa unzip, tar, find, shasum/sha256sum y curl (solo para GitHub).

set -u

ORIGEN="${1:-}"
if [ -z "$ORIGEN" ]; then
  echo "Uso: bash aislar.sh <zip | tar.gz | carpeta | https://github.com/dueño/repo>" >&2
  exit 3
fi

RAIZ="${CUARENTENA_DIR:-$HOME/cuarentena}"
LIMITE_MB="${CUARENTENA_LIMITE_MB:-1024}"   # tope de tamaño descomprimido (contra bombas zip)
SELLO="$(date +%Y%m%d-%H%M%S)"

fallar() { echo "NO SE PUDO AISLAR: $*" >&2; exit 4; }

huella() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else echo "sin-huella"; fi
}

# ── Nombre y carpeta ────────────────────────────────────────────────────────
TIPO=""
case "$ORIGEN" in
  https://github.com/*|http://github.com/*) TIPO="github" ;;
  *.zip|*.ZIP) TIPO="zip" ;;
  *.tar.gz|*.tgz|*.TGZ|*.tar) TIPO="tar" ;;
  *) if [ -d "$ORIGEN" ]; then TIPO="carpeta"; fi ;;
esac
[ -n "$TIPO" ] || fallar "no reconozco '$ORIGEN'. Acepto .zip, .tar.gz, .tgz, .tar, una carpeta o un link de GitHub."
if [ "$TIPO" != "github" ] && [ ! -e "$ORIGEN" ]; then fallar "no existe '$ORIGEN'."; fi

base="$(basename "${ORIGEN%/}")"
base="${base%.zip}"; base="${base%.ZIP}"; base="${base%.tar.gz}"; base="${base%.tgz}"; base="${base%.tar}"
NOMBRE="$(printf '%s' "$base" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-60)"
[ -n "$NOMBRE" ] || NOMBRE="paquete"

CASO="$RAIZ/$NOMBRE-$SELLO"
DEST="$CASO/contenido"
mkdir -p "$DEST" || fallar "no pude crear $DEST"
MANIFIESTO="$CASO/AISLAMIENTO.txt"
OMITIDOS="$CASO/.omitidos"
: > "$OMITIDOS"

# ── GitHub: se baja como ZIP, sin git (git podría correr filtros o hooks globales) ──
if [ "$TIPO" = "github" ]; then
  ruta="${ORIGEN#*github.com/}"; ruta="${ruta%.git}"; ruta="${ruta%/}"
  dueno="$(printf '%s' "$ruta" | cut -d/ -f1)"; repo="$(printf '%s' "$ruta" | cut -d/ -f2)"
  [ -n "$dueno" ] && [ -n "$repo" ] || fallar "el link de GitHub tiene que ser https://github.com/dueño/repo"
  ARCHIVO="$CASO/descarga.zip"
  curl -fsSL --max-time 300 -o "$ARCHIVO" "https://codeload.github.com/$dueno/$repo/zip/HEAD" \
    || fallar "no pude bajar $dueno/$repo (¿el repo es privado o no existe?)"
  TIPO="zip"
else
  ARCHIVO="$ORIGEN"
fi

# ── Revisión ANTES de extraer ───────────────────────────────────────────────
ruta_peligrosa() {
  # rutas absolutas, con "..", o con unidad de Windows
  case "$1" in
    /*|*../*|..|*/..|*..\\*|[A-Za-z]:*) return 0 ;;
  esac
  return 1
}

if [ "$TIPO" = "zip" ]; then
  unzip -Z1 "$ARCHIVO" >/dev/null 2>&1 || fallar "el ZIP está dañado o no es un ZIP."
  total_bytes="$(unzip -l "$ARCHIVO" 2>/dev/null | tail -1 | awk '{print $1}')"
  # symlinks: en el listado largo de zipinfo la línea empieza con "l"
  unzip -Z "$ARCHIVO" 2>/dev/null | awk '/^l/ {print $NF}' | while IFS= read -r e; do
    printf 'symlink-en-el-zip|%s\n' "$e" >> "$OMITIDOS"
  done
  unzip -Z1 "$ARCHIVO" | while IFS= read -r e; do
    if ruta_peligrosa "$e"; then printf 'ruta-peligrosa|%s\n' "$e" >> "$OMITIDOS"; fi
  done
elif [ "$TIPO" = "tar" ]; then
  tar -tf "$ARCHIVO" >/dev/null 2>&1 || fallar "el archivo .tar está dañado."
  total_bytes="$(tar -tvf "$ARCHIVO" 2>/dev/null | awk '{s+=$5} END {print s+0}')"
  tar -tvf "$ARCHIVO" 2>/dev/null | awk '/^[lh]/ {print $(NF-2)}' | while IFS= read -r e; do
    printf 'symlink-en-el-tar|%s\n' "$e" >> "$OMITIDOS"
  done
  tar -tf "$ARCHIVO" | while IFS= read -r e; do
    if ruta_peligrosa "$e"; then printf 'ruta-peligrosa|%s\n' "$e" >> "$OMITIDOS"; fi
  done
else
  total_bytes="$(du -sk "$ARCHIVO" | awk '{print $1*1024}')"
fi

total_mb=$(( ${total_bytes:-0} / 1048576 ))
if [ "$total_mb" -gt "$LIMITE_MB" ]; then
  fallar "descomprimido pesaría ${total_mb} MB (tope ${LIMITE_MB} MB). Puede ser una bomba zip. Sube el tope con CUARENTENA_LIMITE_MB si confías en el tamaño."
fi

# ── Extraer o copiar, sin ejecutar nada ─────────────────────────────────────
if [ "$TIPO" = "zip" ]; then
  # -x excluye lo marcado; -qq silencio; -o sin preguntar dentro de la carpeta nueva
  excluir=()
  while IFS='|' read -r _ e; do [ -n "$e" ] && excluir+=("$e"); done < "$OMITIDOS"
  if [ "${#excluir[@]}" -gt 0 ]; then
    unzip -qq -o "$ARCHIVO" -d "$DEST" -x "${excluir[@]}" 2>/dev/null
  else
    unzip -qq -o "$ARCHIVO" -d "$DEST" 2>/dev/null
  fi
  [ "$(find "$DEST" -mindepth 1 | head -1)" ] || fallar "el ZIP no trajo archivos que se pudieran extraer."
elif [ "$TIPO" = "tar" ]; then
  # bsdtar y GNU tar rechazan ".." y rutas absolutas por defecto; no se conservan dueños
  tar -xf "$ARCHIVO" -C "$DEST" --no-same-owner 2>/dev/null || tar -xf "$ARCHIVO" -C "$DEST" 2>/dev/null \
    || fallar "no pude extraer el .tar."
else
  # carpeta: se copia el contenido; los symlinks se copian como symlink y abajo se borran
  cp -R "$ARCHIVO/." "$DEST/" 2>/dev/null || fallar "no pude copiar la carpeta."
fi

# ── Symlinks fuera, ejecutables apagados ────────────────────────────────────
find "$DEST" -type l 2>/dev/null | while IFS= read -r l; do
  printf 'symlink-borrado|%s -> %s\n' "${l#$DEST/}" "$(readlink "$l")" >> "$OMITIDOS"
  rm -f "$l"
done

EJECUTABLES="$CASO/.ejecutables"
find "$DEST" -type f -perm -u+x 2>/dev/null | sed "s|^$DEST/||" > "$EJECUTABLES"
find "$DEST" -type f -exec chmod a-x {} + 2>/dev/null

# ── Renombrar lo que se carga solo ──────────────────────────────────────────
RENOMBRADOS="$CASO/.renombrados"
: > "$RENOMBRADOS"
# primero lo más profundo, para que renombrar una carpeta no rompa las rutas de adentro
find "$DEST" -depth \( \
    -name 'CLAUDE.md' -o -name 'CLAUDE.local.md' -o -name 'AGENTS.md' -o -name 'GEMINI.md' \
    -o -name '.claude' -o -name '.mcp.json' -o -name '.cursor' -o -name '.cursorrules' \
    -o -name '.windsurfrules' -o -name '.vscode' -o -name '.github' -o -name '.envrc' \
    -o -name '.claude-plugin' -o -name '.codex' \
  \) 2>/dev/null | while IFS= read -r p; do
  mv "$p" "$p.cuarentena" && printf '%s\n' "${p#$DEST/}" >> "$RENOMBRADOS"
done

# ── Manifiesto ──────────────────────────────────────────────────────────────
n_archivos="$(find "$DEST" -type f | wc -l | tr -d ' ')"
peso="$(du -sh "$DEST" 2>/dev/null | awk '{print $1}')"
{
  echo "CUARENTENA"
  echo "origen: $ORIGEN"
  echo "tipo: $TIPO"
  if [ -f "$ARCHIVO" ]; then echo "sha256: $(huella "$ARCHIVO")"; fi
  echo "fecha: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "carpeta: $DEST"
  echo "archivos: $n_archivos ($peso)"
  echo
  echo "## Lo que NO se extrajo o se borró (señal: un paquete normal casi nunca trae esto)"
  if [ -s "$OMITIDOS" ]; then sed 's/^/- /' "$OMITIDOS"; else echo "- nada"; fi
  echo
  echo "## Archivos que venían marcados como ejecutables (se les quitó el permiso)"
  if [ -s "$EJECUTABLES" ]; then sed 's/^/- /' "$EJECUTABLES"; else echo "- ninguno"; fi
  echo
  echo "## Renombrados con .cuarentena (se cargan solos al abrir la carpeta)"
  if [ -s "$RENOMBRADOS" ]; then sed 's/^/- /' "$RENOMBRADOS"; else echo "- ninguno"; fi
} > "$MANIFIESTO"
rm -f "$OMITIDOS" "$EJECUTABLES" "$RENOMBRADOS"

cat "$MANIFIESTO"
echo
echo "LISTO: $CASO"
exit 0
