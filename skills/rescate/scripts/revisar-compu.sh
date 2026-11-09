#!/usr/bin/env bash
# revisar-compu.sh — foto de SOLO LECTURA de todo lo que un paquete pudo cambiarle a tu compu.
#
# Uso:   bash revisar-compu.sh [días]      (días = cuánto hacia atrás marcar como reciente; 14 por defecto)
#
# No cambia, no borra y no manda nada. Los valores que parecen secretos (token, key, secret,
# password, auth) salen tapados como ••••. Salida: 0 siempre.

set -u
DIAS="${1:-14}"
case "$DIAS" in ''|*[!0-9]*) DIAS=14 ;; esac
H="$HOME"

tapar() {
  # tapa el valor de cualquier llave que suene a secreto, en JSON, en .env y en export
  sed -E \
    -e 's/("[^"]*([Tt][Oo][Kk][Ee][Nn]|[Kk][Ee][Yy]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss]|[Aa][Uu][Tt][Hh])[^"]*"[[:space:]]*:[[:space:]]*)"[^"]*"/\1"••••"/g' \
    -e 's/(([A-Z0-9_]*(TOKEN|KEY|SECRET|PASS|AUTH)[A-Z0-9_]*)=)[^[:space:]]+/\1••••/g' \
    -e 's/(([A-Za-z0-9_.:\/-]*([Tt]oken|[Kk]ey|[Ss]ecret|[Pp]ass(word)?|_auth)[A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*)[^[:space:]]+/\1••••/g' \
    -e 's/(Bearer )[A-Za-z0-9._~+\/=-]+/\1••••/g' \
    -e 's/(sk-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]+/\1••••/g'
}

reciente() { # imprime "  (cambió hace menos de N días)" si el archivo es reciente
  if [ -e "$1" ] && [ -n "$(find "$1" -maxdepth 0 -mtime -"$DIAS" 2>/dev/null)" ]; then
    printf '  ← cambió en los últimos %s días' "$DIAS"
  fi
}

fecha() { # fecha de modificación, en macOS y en Linux
  stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$1" 2>/dev/null || stat -c '%y' "$1" 2>/dev/null | cut -c1-16
}

titulo() { echo; echo "## $1"; }

echo "RESCATE · foto de solo lectura · $(date '+%Y-%m-%d %H:%M')"
echo "Marca como reciente lo que cambió en los últimos $DIAS días."

# ── 1. Claude Code: configuración global ────────────────────────────────────
titulo "1. Configuración global de Claude Code"
for f in "$H/.claude/settings.json" "$H/.claude/settings.local.json" "$H/.claude/CLAUDE.md"; do
  if [ -f "$f" ]; then
    echo "### ${f/#$H/~} · $(fecha "$f")$(reciente "$f")"
    tapar < "$f" | head -n 200
  else
    echo "### ${f/#$H/~} · no existe"
  fi
done

titulo "2. Lo instalado en ~/.claude (skills, agentes, comandos, hooks, plugins)"
for d in skills agents commands hooks output-styles; do
  p="$H/.claude/$d"
  if [ -d "$p" ]; then
    echo "### ~/.claude/$d"
    find "$p" -mindepth 1 -maxdepth 1 2>/dev/null | sort | while IFS= read -r x; do
      echo "- $(basename "$x") · $(fecha "$x")$(reciente "$x")"
    done
  fi
done
if [ -f "$H/.claude/plugins/installed_plugins.json" ]; then
  echo "### Plugins instalados"
  grep -oE '"[A-Za-z0-9._-]+@[A-Za-z0-9._-]+"' "$H/.claude/plugins/installed_plugins.json" | tr -d '"' | sort -u | sed 's/^/- /'
fi
if [ -f "$H/.claude/plugins/known_marketplaces.json" ]; then
  echo "### Marketplaces agregados"
  grep -oE '"(repo|url|path)"[[:space:]]*:[[:space:]]*"[^"]+"' "$H/.claude/plugins/known_marketplaces.json" | sed -E 's/.*:[[:space:]]*"(.*)"/- \1/' | sort -u
fi

# ── 3. Servidores MCP ───────────────────────────────────────────────────────
titulo "3. Servidores MCP"
if command -v claude >/dev/null 2>&1; then
  echo "### claude mcp list"
  (claude mcp list 2>&1 | tapar | head -n 60) || echo "(no se pudo listar)"
fi
if [ -f "$H/.claude.json" ]; then
  echo "### Nombres de servidores en ~/.claude.json (sin valores)"
  # solo los nombres de las llaves dentro de cada "mcpServers": { ... }
  awk '/"mcpServers"[[:space:]]*:/ {en=1; prof=0} en {print} en && /\{/ {prof+=gsub(/\{/,"{")} en && /\}/ {prof-=gsub(/\}/,"}"); if (prof<=0) en=0}' "$H/.claude.json" 2>/dev/null \
    | grep -oE '^[[:space:]]{2,8}"[^"]+"[[:space:]]*:[[:space:]]*\{' | grep -oE '"[^"]+"' | tr -d '"' | grep -v mcpServers | sort -u | sed 's/^/- /'
fi

# ── 4. Arranque de la terminal ──────────────────────────────────────────────
titulo "4. Arranque de la terminal (lo que corre cada vez que abres una)"
for f in .zshrc .zprofile .zshenv .zlogin .bashrc .bash_profile .profile .config/fish/config.fish; do
  p="$H/$f"
  [ -f "$p" ] || continue
  echo "### ~/$f · $(fecha "$p")$(reciente "$p")"
  # solo las líneas que hacen algo con efecto: descargar, evaluar, cambiar rutas, alias, variables
  grep -nE 'curl|wget|eval|source|\. |export|alias|PATH|base64|nohup|&$|claude|ANTHROPIC|npx|python|node' "$p" 2>/dev/null | tapar | head -n 60
done

# ── 5. Lo que arranca solo ──────────────────────────────────────────────────
titulo "5. Lo que arranca solo con tu compu"
for d in "$H/Library/LaunchAgents" "/Library/LaunchAgents" "/Library/LaunchDaemons"; do
  [ -d "$d" ] || continue
  echo "### ${d/#$H/~}"
  find "$d" -maxdepth 1 -name '*.plist' 2>/dev/null | sort | while IFS= read -r x; do
    prog="$(grep -A3 -E 'Program(Arguments)?' "$x" 2>/dev/null | grep -oE '<string>[^<]+' | sed 's/<string>//' | head -3 | tr '\n' ' ')"
    echo "- $(basename "$x") · $(fecha "$x")$(reciente "$x") · corre: ${prog:-?}"
  done
done
if command -v crontab >/dev/null 2>&1; then
  echo "### crontab"
  crontab -l 2>/dev/null | grep -v '^#' | tapar || true
fi
if [ -d "$H/.config/autostart" ]; then
  echo "### ~/.config/autostart"
  ls -la "$H/.config/autostart"
fi
if command -v systemctl >/dev/null 2>&1; then
  echo "### servicios de usuario (systemd)"
  systemctl --user list-unit-files --state=enabled 2>/dev/null | head -n 30
fi

# ── 6. git, npm y red ───────────────────────────────────────────────────────
titulo "6. git, npm y red"
if command -v git >/dev/null 2>&1; then
  hp="$(git config --global core.hooksPath 2>/dev/null)"
  echo "- git core.hooksPath global: ${hp:-(no definido)}"
fi
for f in .npmrc .gitconfig .pip/pip.conf .config/pip/pip.conf; do
  p="$H/$f"
  [ -f "$p" ] || continue
  echo "### ~/$f · $(fecha "$p")$(reciente "$p")"
  tapar < "$p" | head -n 40
done
if [ -f /etc/hosts ]; then
  echo "### /etc/hosts · $(fecha /etc/hosts)$(reciente /etc/hosts)"
  grep -vE '^[[:space:]]*(#|$)' /etc/hosts | head -n 30
fi
if [ -f "$H/.ssh/authorized_keys" ]; then
  echo "- ~/.ssh/authorized_keys: $(grep -c . "$H/.ssh/authorized_keys") llaves · $(fecha "$H/.ssh/authorized_keys")$(reciente "$H/.ssh/authorized_keys")"
fi

# ── 7. Cambios recientes en los lugares de configuración ────────────────────
titulo "7. Archivos de configuración que cambiaron en los últimos $DIAS días"
find "$H/.claude" "$H/.config" "$H/Library/LaunchAgents" "$H/.local/bin" "$H/bin" \
  -maxdepth 3 -type f -mtime -"$DIAS" 2>/dev/null \
  | grep -vE '/(projects|todos|shell-snapshots|statsig|cache|Cache|logs|file-history|plugins/cache|plugins/marketplaces|session-env|ide|debug|telemetry|paste-cache|sessions|backups|tasks)/' \
  | sed "s|^$H|~|" | sort | head -n 80

echo
echo "FIN · nada se cambió."
exit 0
