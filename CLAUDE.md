# cuarentena — notas para quien trabaja en este repo

Plugin de Claude Code. Dos skills (`revisar`, `rescate`), un hook (`candado.sh`) y cero dependencias:
solo Bash 3.2 (el de macOS), `unzip`, `tar`, `find`, `grep`, `sed`, `awk` y `curl`.

- **Antes de cada commit:** `bash pruebas/verificar.sh` tiene que decir "todo cuadra".
- **Bash 3.2 y BSD:** nada de `declare -A`, `mapfile`, `${var,,}`, `grep -P` ni `sed -i` sin `''`.
  En `sed`, la alternancia `|` solo funciona con `-E`.
- **El candado decide sobre texto:** lee el JSON del hook sin jq. Si agregas un caso, agrégalo
  también a `pruebas/candado.sh`, con su par que debe pasar. Ojo: el propio plugin vive en
  `.../plugins/cache/cuarentena/...` y sus scripts reciben `~/cuarentena/...` como argumento; eso
  tiene que seguir pasando.
- **Una señal nueva** va en `senales.sh`, se explica en `skills/revisar/references/senales.md` y se
  planta en `pruebas/armar.py` con su afirmación en `verificar.sh`.
- **Los ZIP de prueba se arman, no se versionan** (`pruebas/salida/` está en `.gitignore`). Todo
  apunta a `example.invalid`.
- `docs/ficha-ejemplo.md` salió de una corrida real de `/cuarentena:revisar` sobre el ZIP trampa.
  Si cambias la plantilla de la ficha, vuelve a generarla.
