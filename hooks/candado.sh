#!/usr/bin/env bash
# candado.sh — hook PreToolUse (Bash) del plugin cuarentena.
#
# Niega cualquier comando que EJECUTE algo que vive en ~/cuarentena/ (o $CUARENTENA_DIR):
# correr un script de ahí, entrar con cd y correr un instalador, darle permiso de
# ejecución, abrirlo con open, cargarlo con source. Leer (ls, cat, grep, find) pasa.
#
# Sin dependencias: lee el JSON del hook como texto. No necesita jq, node ni python.
# Siempre sale 0; cuando niega, lo dice con el JSON de permissionDecision "deny".

entrada="$(cat)"

# Solo nos importa el comando. Si el JSON no trae "command", no es un Bash y no hacemos nada.
case "$entrada" in
  *'"command"'*) ;;
  *) exit 0 ;;
esac

# Sacar el valor de "command" sin jq: lo que va entre "command":" y la siguiente comilla
# no escapada. Luego deshacer los escapes más comunes del JSON.
cmd="$(printf '%s' "$entrada" | LC_ALL=C sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
cmd="$(printf '%s' "$cmd" | sed -e 's/\\"/"/g' -e "s/\\\\'/'/g" -e 's/\\n/ ; /g' -e 's/\\t/ /g' -e 's/\\\\/\\/g')"
[ -n "$cmd" ] || exit 0

raiz="${CUARENTENA_DIR:-$HOME/cuarentena}"
nombre_raiz="$(basename "$raiz")"

# ¿El comando menciona la cuarentena? (por ruta absoluta, con ~ o con $HOME)
case "$cmd" in
  *"$raiz"*|*"~/$nombre_raiz"*|*'$HOME/'"$nombre_raiz"*|*'${HOME}/'"$nombre_raiz"*) ;;
  *) exit 0 ;;
esac

negar() {
  razon="Candado de cuarentena: $1. Lo que está en cuarentena se lee, no se ejecuta. Si de verdad quieres instalarlo, primero revisa la ficha y copia a su lugar solo lo que necesitas."
  razon="$(printf '%s' "$razon" | sed 's/"/\\"/g')"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$razon"
  exit 0
}

# Una ruta que empieza en la cuarentena, escrita de cualquiera de las cuatro formas.
# Ojo: tiene que EMPEZAR ahí. El propio plugin vive en .../plugins/cache/cuarentena/...
# y sus scripts reciben la carpeta como argumento: esos sí tienen que pasar.
esc() { printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g'; }
rel="${raiz#$HOME/}"
RUTA="[\"']?($(esc "$raiz")|~/$(esc "$rel")|\\\$HOME/$(esc "$rel")|\\\$\\{HOME\\}/$(esc "$rel"))(/|[\"']|[[:space:]]|$)"

# Programas que ejecutan lo que les pases
EJEC='(bash|sh|zsh|dash|fish|ksh|source|\.|exec|node|deno|bun|python[0-9.]*|pythonw|ruby|perl|php|osascript|open|xdg-open|start|pwsh|powershell|cmd|npx|npm|pnpm|yarn|pip[0-9.]*|pipx|uv|uvx|make|cargo|go|java|dotnet|sudo|env|nohup|xargs|launchctl|crontab|install|chmod|code|cursor)'
FLAGS='([[:space:]]+-[^[:space:]]*)*'

# 1) Un programa que ejecuta, seguido (con o sin opciones) de una ruta de la cuarentena
if printf '%s' "$cmd" | LC_ALL=C grep -Eq "(^|[;&|(\`]|\\\$\\()[[:space:]]*${EJEC}${FLAGS}[[:space:]]+${RUTA}"; then
  negar "ese comando ejecutaría un archivo que está en cuarentena"
fi

# 1b) Instaladores y lanzadores: cualquier argumento dentro de la cuarentena basta
#     (pip install <carpeta>, python -m pip install <carpeta>, chmod +x <archivo>, npm i <carpeta>)
LANZA='(npx|npm|pnpm|yarn|pip[0-9.]*|pipx|uv|uvx|python[0-9.]*|make|cargo|go|dotnet|sudo|env|nohup|xargs|launchctl|crontab|install|chmod|open|xdg-open|osascript|claude|code|cursor)'
if printf '%s' "$cmd" | LC_ALL=C grep -Eq "(^|[;&|(\`]|\\\$\\()[[:space:]]*${LANZA}([[:space:]]+[^;&|]*)?[[:space:]]+${RUTA}"; then
  negar "ese comando instalaría o lanzaría algo que está en cuarentena"
fi

# 2) Una ruta de la cuarentena usada como comando (./algo, ~/cuarentena/x/instalar.sh)
if printf '%s' "$cmd" | LC_ALL=C grep -Eq "(^|[;&|(\`]|\\\$\\()[[:space:]]*${RUTA}"; then
  negar "ese comando corre directamente un archivo que está en cuarentena"
fi

# 3) Entrar con cd (o pushd) a la cuarentena y luego correr algo que no sea solo leer
if printf '%s' "$cmd" | LC_ALL=C grep -Eq "(cd|pushd)[[:space:]]+${RUTA}"; then
  resto="$(printf '%s' "$cmd" | LC_ALL=C sed -E "s/.*(cd|pushd)[[:space:]]+[^;&|]*//")"
  if printf '%s' "$resto" | LC_ALL=C grep -Eq "(^|[;&|(\`])[[:space:]]*(${EJEC}([[:space:]]|$)|\./|[^[:space:]]+\.(sh|command|py|js|mjs|rb|pl|ps1|bat|exe|app)([[:space:]]|$)|claude([[:space:]]|$)|git[[:space:]]+(submodule|lfs|checkout|pull))"; then
    negar "entrar a la carpeta en cuarentena y correr algo ahí la saca de cuarentena"
  fi
fi

# 4) Copiar o mover desde la cuarentena hacia los lugares que se cargan solos
if printf '%s' "$cmd" | LC_ALL=C grep -Eq "(cp|mv|rsync|ln|tee|install|ditto)[[:space:]].*${RUTA}.*(LaunchAgents|LaunchDaemons|/\.zshrc|/\.bashrc|/\.zprofile|/\.bash_profile|/\.profile|/etc/|/usr/local/bin|crontab)"; then
  negar "eso copiaría algo de la cuarentena a un lugar que arranca solo con tu compu"
fi

exit 0
