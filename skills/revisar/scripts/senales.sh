#!/usr/bin/env bash
# senales.sh — busca, sin ejecutar nada, las señales de que un paquete toca tu compu.
#
# Uso:   bash senales.sh <carpeta-en-cuarentena>
#
# Imprime un bloque por categoría con archivo:línea y el fragmento. Un hallazgo NO es un
# veredicto: es un lugar que Claude tiene que abrir y leer en contexto.
# Salida: 0 siempre que pudo leer la carpeta · 3 uso incorrecto.

set -u
DIR="${1:-}"
if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  echo "Uso: bash senales.sh <carpeta>" >&2
  exit 3
fi
DIR="${DIR%/}"
TOPE="${SENALES_TOPE:-40}"   # hallazgos máximos por categoría (el total se dice igual)

# grep recursivo, sin binarios, con número de línea; rutas relativas a la carpeta
buscar() {
  # $1 = título · $2 = regex extendida · $3 = opciones extra de grep (p. ej. -i)
  local titulo="$1" patron="$2" extra="${3:-}"
  local salida
  salida="$(cd "$DIR" && LC_ALL=C grep -rEnI $extra -e "$patron" . 2>/dev/null \
    | sed 's|^\./||' | cut -c1-220)"
  local n
  n="$(printf '%s' "$salida" | grep -c . || true)"
  echo "### $titulo — $n"
  if [ "$n" -gt 0 ]; then
    printf '%s\n' "$salida" | head -n "$TOPE"
    if [ "$n" -gt "$TOPE" ]; then echo "… y $((n - TOPE)) más"; fi
  fi
  echo
}

echo "SEÑALES EN: $DIR"
echo "(un hallazgo es un lugar para leer, no una condena)"
echo

echo "## A. Configuración de agentes que venía adentro"
cfg="$(cd "$DIR" && find . \( -name '*.cuarentena' -o -name 'settings*.json' -o -name 'hooks.json' \
  -o -name 'plugin.json' -o -name 'marketplace.json' -o -name '.mcp.json*' \) 2>/dev/null | sed 's|^\./||')"
echo "### Archivos de configuración encontrados — $(printf '%s' "$cfg" | grep -c . || true)"
printf '%s\n' "$cfg" | grep . || true
echo
buscar "Permisos amplios o saltar permisos" 'bypassPermissions|dangerously-skip-permissions|skipDangerousModePermissionPrompt|"defaultMode"|Bash\(\*\)|Bash\(\)|"allow"[[:space:]]*:'
buscar "Hooks (comandos que corren solos)" '"hooks"[[:space:]]*:|PreToolUse|PostToolUse|SessionStart|UserPromptSubmit|"Stop"|SubagentStop|"command"[[:space:]]*:'
buscar "Servidores MCP" 'mcpServers|enableAllProjectMcpServers|enabledMcpjsonServers|claude mcp add|"mcp"[[:space:]]*:'
buscar "Redirigir a Claude a otro servidor o llave" 'ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN|apiKeyHelper|awsAuthRefresh|otelHeadersHelper|HTTPS?_PROXY'

echo "## B. Escribe fuera de su carpeta"
buscar "Toca la config global de Claude" '~/\.claude|\$HOME/\.claude|\$\{HOME\}/\.claude|\.claude\.json|homedir\(\)[^;]*\.claude'
buscar "Toca el arranque de tu terminal" '\.zshrc|\.zprofile|\.zshenv|\.bashrc|\.bash_profile|[^a-z]\.profile|config\.fish|Microsoft\.PowerShell_profile'
buscar "Se programa para correr solo" 'LaunchAgents|LaunchDaemons|launchctl|crontab|systemctl|\.service|schtasks|Startup|RunOnce|CurrentVersion\\Run'
buscar "Cambia el sistema o salta protecciones" 'sudo |defaults write|osascript|xattr -[rd]|com\.apple\.quarantine|spctl|csrutil|/etc/hosts|/usr/local/bin|/etc/sudoers|Set-ExecutionPolicy|chmod (\+x|7[0-7][0-7])|chown '
buscar "Toca git o npm globales" 'core\.hooksPath|git config --global|\.gitconfig|\.npmrc|npm config set|registry='

echo "## C. Corre código al instalar o al abrir"
buscar "Scripts de instalación (npm, pip...)" '"(pre|post)?install"[[:space:]]*:|"prepare"[[:space:]]*:|"prepublish"[[:space:]]*:|cmdclass|setup\.py|install_requires'
buscar "Baja algo de internet y lo corre" '(curl|wget)[^|;]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh|(curl|wget)[^|;]*\|[[:space:]]*(python|node|perl|ruby)|iwr |Invoke-WebRequest|Invoke-Expression|iex[[:space:](]|DownloadString|bash -c "\$\(curl'
buscar "Ejecuta texto como código" '\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|;|$)|eval[[:space:]]*\(|eval "\$\(|new Function\(|exec\(|execSync|spawn\(|child_process|subprocess\.|os\.system|os\.popen|Runtime\.getRuntime|shell=True'

echo "## D. Lee tus llaves y datos"
buscar "Llaves, contraseñas y sesiones" '\.ssh/|id_rsa|id_ed25519|authorized_keys|\.aws/|credentials|\.netrc|\.pgpass|keychain|security find-|Login Data|Cookies|Local State|\.config/gh|\.docker/config|\.kube/config|wallet|seed phrase|mnemonic'
buscar "Variables secretas" 'ANTHROPIC_API_KEY|OPENAI_API_KEY|GITHUB_TOKEN|GH_TOKEN|AWS_SECRET|STRIPE_|SUPABASE_|process\.env|os\.environ|getenv\(|\.env[^a-zA-Z]|printenv|env >'

echo "## E. Habla con internet"
buscar "Manda datos fuera" 'fetch\(|axios|XMLHttpRequest|WebSocket|requests\.(post|put)|urllib|http\.request|curl .*(-d|--data|-F|-T)|nc -|/dev/tcp|webhook|discord(app)?\.com/api/webhooks|api\.telegram\.org|pastebin|ngrok|transfer\.sh|requestbin|pipedream|interactsh|burpcollaborator'
echo "### Dominios mencionados (únicos)"
(cd "$DIR" && LC_ALL=C grep -rhoEI 'https?://[A-Za-z0-9.-]+' . 2>/dev/null) \
  | sed -E 's|https?://||' | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn | head -n 60
echo

echo "## F. Escondido u ofuscado"
buscar "Decodifica base64 o arma texto escondido" 'base64 (-d|-D|--decode)|b64decode|atob\(|Buffer\.from\([^)]*base64|fromCharCode|\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}|[A-Za-z0-9+/]{200,}={0,2}'
echo "### Líneas de más de 1000 caracteres (código minificado o empaquetado)"
(cd "$DIR" && find . -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.py' -o -name '*.sh' -o -name '*.ts' \) \
  -exec awk 'length($0) > 1000 {print FILENAME ":" FNR " (" length($0) " caracteres)"; n++; if (n>=3) exit}' {} + 2>/dev/null) \
  | sed 's|^\./||' | head -n "$TOPE"
echo
echo "### Caracteres invisibles (pueden esconder instrucciones)"
# U+200B–U+200F, U+202A–U+202E, U+2060–U+2064, U+FEFF, y la etiqueta Unicode U+E0000–U+E007F
inv="$(cd "$DIR" && LC_ALL=C grep -rlI -e $'\xe2\x80[\x8b-\x8f]' -e $'\xe2\x80[\xaa-\xae]' -e $'\xe2\x81[\xa0-\xa4]' -e $'\xef\xbb\xbf' -e $'\xf3\xa0[\x80-\x81]' . 2>/dev/null | sed 's|^\./||')"
if [ -n "$inv" ]; then printf '%s\n' "$inv"; else echo "ninguno"; fi
echo

echo "## G. Instrucciones para el agente escondidas en el texto"
buscar "Le habla a la IA" '(ignore|disregard|forget)[^.]{0,30}(previous|prior|above|all)[^.]{0,20}instructions|ignora[^.]{0,30}instrucciones|(do not|don.t|never)[^.]{0,20}(tell|mention|inform|ask)[^.]{0,20}(the )?user|no (le )?(digas|menciones|avises)|sin (preguntar|avisar|pedir permiso)|without (asking|telling|confirmation)|you are now|system prompt|as an ai|<\!--[^>]*(claude|assistant|ai|agent|instruc)' -i

echo "## H. Binarios y archivos que no se pueden leer"
(cd "$DIR" && find . -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.dylib' -o -iname '*.so' -o -iname '*.node' \
  -o -iname '*.bin' -o -iname '*.pkg' -o -iname '*.dmg' -o -iname '*.msi' -o -iname '*.jar' -o -iname '*.app' -o -iname '*.scpt' \
  -o -iname '*.pyc' -o -iname '*.wasm' \) 2>/dev/null | sed 's|^\./||' | head -n "$TOPE")
if command -v file >/dev/null 2>&1; then
  (cd "$DIR" && find . -type f -size +1k 2>/dev/null | head -n 4000 | while IFS= read -r f; do
     t="$(file -b "$f" 2>/dev/null)"
     case "$t" in *Mach-O*|*ELF*|*PE32*|*executable*) echo "${f#./}: $t" ;; esac
   done) | head -n "$TOPE"
fi
echo

echo "## Inventario"
echo "archivos: $(find "$DIR" -type f | wc -l | tr -d ' ')"
echo "### Por tipo"
find "$DIR" -type f 2>/dev/null | sed -E 's|.*/||; s|^[^.]*$|(sin extensión)|; s|.*\.||' | sort | uniq -c | sort -rn | head -n 15
echo "### Estructura (2 niveles)"
(cd "$DIR" && find . -maxdepth 2 -not -path '.' 2>/dev/null | sed 's|^\./||' | sort | head -n 80)
exit 0
