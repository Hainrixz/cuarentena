# Cuarentena

**Claude reviews a ZIP, folder or repo before it touches your computer.** · [Español](README.md)

Someone sends you a skill in a ZIP, you find a tool on GitHub, or a friend shares a "pro config"
folder. You open it with Claude Code and, without noticing, it changes your permissions, leaves a
hook that runs on its own, adds a line to `~/.zshrc`, or schedules itself to start with your machine.

**Cuarentena** does the review first. It moves the package into a separate folder, runs nothing
from it, and gives you a report with three answers:

1. **What it would change on your computer.** Every file or place outside its own folder, and
   whether its README warns you.
2. **What looks suspicious.** With file and line.
3. **Whether it does what it claims.** README promises against what the code actually does.

The report ends with a verdict: **Install**, **Install with changes** or **Don't install**.
`/cuarentena:rescate` is for when you already opened something: it audits your setup read-only and
helps you undo each change, with a backup and your approval.

## Review it before you install it

It's 3 Bash scripts, 2 Markdown skills and one hook, with zero dependencies:

- `aislar.sh` isolates the package.
- `senales.sh` is a read-only grep.
- `revisar-compu.sh` takes a read-only snapshot of your setup and masks secrets.
- `candado.sh` is a hook that denies executing anything inside `~/cuarentena/`.

None of it sends data anywhere. The only network call is `curl` to fetch a GitHub repo as a ZIP
when you pass a link.

## Install

Requires [Claude Code](https://claude.com/claude-code) on macOS, Linux or WSL.

```
/plugin marketplace add Hainrixz/cuarentena
/plugin install cuarentena@cuarentena
```

## Use

```
/cuarentena:revisar ~/Downloads/some-skill.zip
/cuarentena:revisar https://github.com/someone/tool
/cuarentena:rescate 30
```

Here is a real report, produced from the trap ZIP in `pruebas/`:
[`docs/ficha-ejemplo.md`](docs/ficha-ejemplo.md) (in Spanish).

## How it works

1. **Isolate without running.** Archive entries with `..`, absolute paths and symlinks are not
   extracted, and they are recorded. There is a 1 GB unpacked cap, and every file loses its exec bit.
2. **Disable auto-loaded config.** These get a `.cuarentena` suffix so they are inert text:
   `CLAUDE.md`, `.claude/`, `.mcp.json`, `AGENTS.md`, `.cursor/`, `.vscode/` and others. Claude Code
   loads a subfolder's `CLAUDE.md` as soon as it reads a file there, and a folder's project hooks
   can run without a prompt when you already trusted a parent folder.
3. **Scan eight categories:**
   - agent config (permissions, hooks, MCP);
   - writes outside the folder (`~/.claude`, shell profiles, LaunchAgents, cron);
   - install-time code (`postinstall`, `curl | bash`);
   - secret reads;
   - network destinations;
   - obfuscation and invisible Unicode;
   - hidden instructions to the AI;
   - binaries.
4. **Read and judge.** Claude reads what matters, compares claims against behavior and treats every
   file as data, never as instructions.
5. **Second opinion.** It also runs [SkillSpector](https://github.com/NVIDIA/skillspector) if you
   have it installed.

**The lock.** A PreToolUse hook denies any command that would run something from `~/cuarentena/`.
It works even with permissions bypassed.

## Limits

- It can't read binaries or compiled code.
- It can't see what gets downloaded later.
- Determined obfuscation can beat it.
- It is not an antivirus or a VM.

## Tests

`bash pruebas/verificar.sh` builds a trap ZIP with 10 planted signals and a clean one. It tests the
scripts and the lock offline, without Claude.

MIT · [Enrique Rocha](https://github.com/Hainrixz) · [tododeia.com](https://www.tododeia.com/community/cuarentena-claude)
