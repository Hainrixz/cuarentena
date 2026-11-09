<p align="center">
  <b>Cuarentena</b><br>
  Claude revisa un ZIP, una carpeta o un repo antes de que toque tu compu.
</p>

<p align="center">
  <a href="#instalación">Instalación</a> ·
  <a href="#cómo-se-usa">Cómo se usa</a> ·
  <a href="#qué-hace-por-dentro">Qué hace por dentro</a> ·
  <a href="#lo-que-no-ve">Lo que no ve</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude_Code-plugin-0B0B0F?style=flat-square">
  <img alt="Sin dependencias" src="https://img.shields.io/badge/dependencias-cero-7CE0C3?style=flat-square">
  <img alt="MIT" src="https://img.shields.io/badge/license-MIT-F4F1EA?style=flat-square">
</p>

---

## Para qué sirve

Te pasan una skill en un ZIP, encuentras una herramienta en GitHub o alguien te comparte una
carpeta de "configuración pro". La abres con Claude Code y, sin que te des cuenta, te cambia los
permisos, te deja un hook que corre solo, te agrega una línea a `~/.zshrc` o se programa para
arrancar con tu compu.

**Cuarentena** hace la revisión antes. Mete el paquete en una carpeta aparte, no ejecuta nada de
lo que trae y te entrega una ficha con tres respuestas:

1. **Qué cambiaría en tu compu.** Cada archivo o lugar fuera de su carpeta, y si el README te lo avisa.
2. **Qué es sospechoso.** Con archivo y línea, explicado como se lo explicarías a alguien que no programa.
3. **Si hace lo que promete.** Lo que dice el README contra lo que hace el código.

Y un veredicto: **Instalar**, **Instalar con cambios** o **No instalar**.

Si ya lo abriste, `/cuarentena:rescate` revisa tu compu en modo solo lectura y te ayuda a deshacer
cada cambio, con respaldo y con tu permiso.

## Antes de instalarla: revísala

Estás a punto de instalar una herramienta de seguridad que alguien te pasó. Haz lo que ella te
enseña: pásale este repo a Claude en claude.ai o léelo tú. Son 3 scripts de Bash, 2 skills en
Markdown y un hook, todo sin dependencias:

| Archivo | Qué hace |
|---|---|
| `skills/revisar/scripts/aislar.sh` | Copia o descomprime a `~/cuarentena/`, deja fuera symlinks y rutas `../`, quita permisos de ejecución y renombra la config que se carga sola |
| `skills/revisar/scripts/senales.sh` | Busca con `grep` las señales de la tabla de abajo. Solo lee |
| `skills/rescate/scripts/revisar-compu.sh` | Foto de solo lectura de tu configuración; tapa lo que parece secreto |
| `hooks/candado.sh` | Hook que niega ejecutar cualquier cosa que esté en `~/cuarentena/` |

Nada de esto manda datos a ningún lado. La única red que usa es `curl` para bajar un repo de GitHub
como ZIP cuando le pasas un link.

## Instalación

Requisitos: [Claude Code](https://claude.com/claude-code) en macOS, Linux o WSL. No necesita Node,
Python ni nada más.

Dentro de Claude Code:

```
/plugin marketplace add Hainrixz/cuarentena
/plugin install cuarentena@cuarentena
```

O desde la terminal:

```bash
claude plugin marketplace add Hainrixz/cuarentena
claude plugin install cuarentena@cuarentena
```

## Cómo se usa

```
/cuarentena:revisar ~/Downloads/la-skill.zip
/cuarentena:revisar ~/Downloads/carpeta-que-me-pasaron
/cuarentena:revisar https://github.com/alguien/herramienta
```

También se activa sola si le dices a Claude cosas como "¿es seguro instalar esto?" o "revisa este
zip antes de abrirlo".

Te devuelve el veredicto en el chat y deja la ficha completa en
`~/cuarentena/<nombre>-<fecha>/FICHA.md`. Mira una ficha real en
[`docs/ficha-ejemplo.md`](docs/ficha-ejemplo.md), sacada del ZIP trampa de las pruebas.

Si el veredicto lo permite, Claude te propone la **instalación mínima**: copiar a su lugar solo lo
que hace falta, sin correr el instalador del autor. No hace nada sin tu sí.

### Si ya lo abriste

```
/cuarentena:rescate
/cuarentena:rescate 30
```

El número son los días hacia atrás que marca como recientes (14 por defecto). Revisa:

- la configuración global de Claude Code (permisos, hooks, `CLAUDE.md`);
- skills, plugins y servidores MCP;
- el arranque de la terminal;
- LaunchAgents y crontab;
- git y npm.

Después te dice qué es sospechoso y cómo se deshace cada cosa. Si algo leyó tus llaves y las mandó a
internet, te dice cuáles cambiar.

## Qué hace por dentro

**1. Aislar sin ejecutar.** `aislar.sh` lista el ZIP antes de abrirlo. Las entradas con `..`, las
rutas absolutas y los symlinks no se extraen y quedan anotados: un paquete normal no los trae. Pone
un tope de 1 GB descomprimido contra bombas zip. Quita el permiso de ejecución a todo.

**2. Apagar lo que se carga solo.** Renombra con `.cuarentena` lo que Claude Code y otros editores
leen solos al abrir una carpeta: `CLAUDE.md`, `.claude/`, `.mcp.json`, `AGENTS.md`, `.cursor/`,
`.vscode/` y otros. Claude Code carga el `CLAUDE.md` de una subcarpeta en cuanto lee un archivo de
ahí, y los hooks del `.claude/settings.json` de una carpeta pueden correr sin preguntarte si ya
confiaste en la carpeta de arriba. Renombrados, solo son texto.

**3. Buscar señales.** `senales.sh` busca en ocho categorías:

| | Busca |
|---|---|
| A | Permisos amplios, `bypassPermissions`, hooks, servidores MCP, redirección de la API |
| B | Escrituras a `~/.claude`, `~/.zshrc`, LaunchAgents, crontab, `sudo`, git/npm globales |
| C | `postinstall`, `curl \| bash`, `eval` y compañía |
| D | Lectura de `~/.ssh`, `~/.aws`, `.env`, llaveros y tokens |
| E | Envíos a internet y la lista de dominios |
| F | base64 que se ejecuta, código ofuscado, caracteres invisibles |
| G | Instrucciones escondidas para la IA ("ignora tus instrucciones", "no le digas al usuario") |
| H | Binarios que no se pueden leer |

**4. Leer y juzgar.** Claude abre lo que importa y compara lo que el paquete promete con lo que hace.
Decide con las reglas de [`skills/revisar/references/senales.md`](skills/revisar/references/senales.md).
Todo lo que lee lo trata como dato, nunca como orden: si un archivo le pide algo, eso va a la ficha
como hallazgo.

**5. Segunda opinión.** Si tienes instalado [SkillSpector](https://github.com/NVIDIA/skillspector),
lo corre también.

**El candado.** El plugin trae un hook que niega cualquier comando que ejecute algo de
`~/cuarentena/`: correr un script, `cd` y `npm install`, `chmod +x`, `open`, `source`. Funciona
aunque estés en modo de permisos saltados. Leer (`ls`, `cat`, `grep`) pasa.

## Lo que no ve

- **Binarios y código compilado.** No se pueden leer; la ficha lo dice y baja la confianza.
- **Lo que se baja después.** Si el paquete descarga un script el día que lo corres, la revisión
  ve que lo baja, no qué trae. Por eso `curl | bash` cuenta como señal.
- **Ofuscación fuerte.** Alguien decidido a esconder algo puede lograr que un `grep` no lo encuentre.
  La lectura de Claude ayuda, pero no es infalible.
- **No es un antivirus** ni reemplaza una máquina virtual para código que de verdad no confías.

## Pruebas

```bash
bash pruebas/verificar.sh
```

Arma un ZIP trampa con 10 señales plantadas (todo apunta a `example.invalid`, que no existe) y uno
limpio, y prueba los tres scripts y el candado sin red y sin Claude.

## Guía

Paso a paso, con el camino en la nube para revisar sin instalar nada:
[tododeia.com/community/cuarentena-claude](https://www.tododeia.com/community/cuarentena-claude)

## Licencia

MIT. Hecho por [Enrique Rocha](https://github.com/Hainrixz) para la comunidad de
[Tododeia](https://www.tododeia.com).
