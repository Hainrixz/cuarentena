# Plantilla de la ficha

Guarda la ficha como `FICHA.md` junto a `AISLAMIENTO.txt`. Sin relleno: si una sección no aplica,
escribe "nada" y sigue. Cada señal lleva archivo:línea.

```markdown
# Ficha de cuarentena · <nombre del paquete>

**Veredicto: <Instalar | Instalar con cambios | No instalar>**
<Una o dos frases con la razón principal. Si hubo límites de lectura, aquí van.>

Revisado: <fecha> · Origen: <ruta o link> · sha256: <huella de AISLAMIENTO.txt>

## Qué promete y qué hace

| Promete (README, SKILL.md) | Hace (código) |
|---|---|
| <frase del README> | <lo que de verdad hace, con archivo:línea> |

## Lo que cambiaría en tu compu

| Lugar | Qué haría | ¿Lo avisa el README? | Riesgo |
|---|---|---|---|
| <~/.claude/settings.json> | <agrega permiso Bash(*)> | <no> | <alto> |

Si no toca nada fuera de su carpeta, escribe: "Nada fuera de su propia carpeta."

## Señales

1. **<Título corto>** · `<archivo>:<línea>`
   <Qué hace, en una frase de persona normal, y por qué importa.>

## Lo que se dejó fuera al aislar

<Copia de "Lo que NO se extrajo", "ejecutables" y "renombrados" de AISLAMIENTO.txt, o "nada".>

## Segunda opinión

<Resultado de SkillSpector si corrió, o "SkillSpector no está instalado".>

## Lo que esta revisión no puede ver

<Binarios, código compilado, lo que baje de internet después, partes que no se leyeron.>

## Instalación mínima

<Solo si el veredicto no es "No instalar": los comandos exactos para copiar lo necesario a su
lugar, sin lo marcado. No se corren sin un sí.>
```
