#!/usr/bin/env bash
# pruebas/candado.sh — prueba que el candado niega lo que ejecuta y deja pasar lo que lee.
# Uso: bash pruebas/candado.sh   (sale 0 si todo cuadra, 1 si algo falla)
cd "$(dirname "$0")/.." || exit 1
fallos=0
json() { python3 -c 'import json,sys;print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" 2>/dev/null \
  || printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
caso() { # $1 = niega|pasa · $2 = comando
  out="$(json "$2" | bash hooks/candado.sh)"
  if [ -n "$out" ]; then got=niega; else got=pasa; fi
  if [ "$got" = "$1" ]; then echo "ok    $1  | $2"; else echo "FALLA esperaba $1, dio $got | $2"; fallos=$((fallos+1)); fi
}
P="$HOME/.claude/plugins/cache/cuarentena/cuarentena/0.1.0"
caso niega 'bash ~/cuarentena/foo-1/contenido/install.sh'
caso niega "sh \"$HOME/cuarentena/foo-1/contenido/setup.sh\""
caso niega 'cd ~/cuarentena/foo-1/contenido && npm install'
caso niega 'cd "$HOME/cuarentena/foo-1/contenido"; ./instalar.sh'
caso niega '~/cuarentena/foo-1/contenido/run.sh --yes'
caso niega 'chmod +x ~/cuarentena/foo/contenido/a.sh'
caso niega 'python3 -m pip install ~/cuarentena/foo/contenido'
caso niega 'npm --prefix ~/cuarentena/foo/contenido install'
caso niega 'open ~/cuarentena/foo/contenido/App.app'
caso niega 'source ~/cuarentena/foo/contenido/env.sh'
caso niega 'cp ~/cuarentena/foo/contenido/x.plist ~/Library/LaunchAgents/'
caso niega 'cd ~/cuarentena/foo/contenido && claude'
caso niega 'ls && bash ${HOME}/cuarentena/x/a.sh'
caso niega 'node $HOME/cuarentena/x/contenido/index.js'
caso pasa 'ls -la ~/cuarentena/foo-1/contenido'
caso pasa 'cat ~/cuarentena/foo/AISLAMIENTO.txt'
caso pasa "bash \"$P/skills/revisar/scripts/senales.sh\" ~/cuarentena/foo-1/contenido"
caso pasa "bash \"$P/skills/revisar/scripts/aislar.sh\" ~/Downloads/cosa.zip"
caso pasa 'grep -rn curl ~/cuarentena/foo/contenido'
caso pasa 'cd ~/cuarentena/foo/contenido && ls && cat README.md'
caso pasa 'cp -R ~/cuarentena/foo/contenido/skills/mi-skill ~/.claude/skills/'
caso pasa 'rm -rf ~/cuarentena/foo-1'
caso pasa 'npm install'
caso pasa 'bash ~/proyectos/cuarentena-app/run.sh'
echo
if [ "$fallos" -eq 0 ]; then echo "candado: todo cuadra"; exit 0; else echo "candado: $fallos fallos"; exit 1; fi
