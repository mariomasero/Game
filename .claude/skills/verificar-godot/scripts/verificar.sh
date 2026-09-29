#!/usr/bin/env bash
# Verificación del proyecto (AGENTS.md → «Verificación y entrega») con salida corta.
# La salida completa de Godot va a .local/verificacion/ultimo.log: volcarla entera
# al contexto del agente gasta mucho uso y casi nunca hace falta.
#
# Uso:
#   verificar.sh                      todo: versión, importación, arranque y todas las pruebas
#   verificar.sh water plot_layout    solo las pruebas cuyo nombre contenga esas palabras
#                                     (la guarda de píxel se ejecuta siempre)
#   verificar.sh --sin-arranque ...   salta importación y arranque (más rápido)
#
# Variables: GODOT (ruta del ejecutable de consola), VERIFICAR_TIMEOUT (segundos por paso, 300).

set -u

G="${GODOT:-/c/Users/mario/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
VERSION_ESPERADA="4.7.2.stable.official.ed1daf0bf"
LIMITE="${VERIFICAR_TIMEOUT:-300}"
GUARDA="tests/test_pixel_settings_guard.gd"

# Avisos que AGENTS.md declara esperados: se cuentan, pero no hacen fallar.
ESPERADOS='teselas con tres terrenos degradadas|Parameter "material" is null'
# Líneas que delatan un problema en la salida de Godot o de las pruebas.
PROBLEMAS='(^|[^A-Za-z])(SCRIPT ERROR|ERROR|Parse Error|FAIL)([^A-Za-z]|$)'

RAIZ="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$RAIZ" || exit 2

if [ ! -x "$G" ] && ! command -v "$G" >/dev/null 2>&1; then
  echo "FALLO  no encuentro Godot en: $G"
  echo "       Define GODOT con la ruta del ejecutable *_console.exe."
  exit 2
fi

DIR=".local/verificacion"
mkdir -p "$DIR"
LOG="$DIR/ultimo.log"
: > "$LOG"
SALIDA_PASO="$DIR/paso.tmp"

# `timeout` de GNU si existe (Git Bash lo trae); el timeout.exe de Windows es otra cosa.
if timeout --version >/dev/null 2>&1; then
  CON_LIMITE=(timeout "$LIMITE")
else
  CON_LIMITE=()
fi

fallos=0
esperados=0

paso() { # nombre, comando...
  local nombre="$1"; shift
  "${CON_LIMITE[@]}" "$@" >"$SALIDA_PASO" 2>&1
  local codigo=$?
  tr -d '\r' <"$SALIDA_PASO" >"$SALIDA_PASO.limpio"
  { echo "===== $nombre (código $codigo) ====="; cat "$SALIDA_PASO.limpio"; echo; } >>"$LOG"

  local n_esperados problemas resultado
  n_esperados=$(grep -cE "$ESPERADOS" "$SALIDA_PASO.limpio")
  esperados=$((esperados + n_esperados))
  problemas=$(grep -E "$PROBLEMAS" "$SALIDA_PASO.limpio" | grep -vE "$ESPERADOS" | grep -v 'RESULTADO')
  resultado=$(grep -E 'RESULTADO' "$SALIDA_PASO.limpio" | tail -n 1)

  local estado="OK   "
  if [ "$codigo" -eq 124 ] && [ ${#CON_LIMITE[@]} -gt 0 ]; then
    estado="FALLO"
    problemas="se pasó del límite de ${LIMITE} s"$'\n'"$problemas"
  elif [ "$codigo" -ne 0 ] || [ -n "$problemas" ]; then
    estado="FALLO"
  fi

  printf '%s  %-38s %s\n' "$estado" "$nombre" "$resultado"
  if [ "$estado" = "FALLO" ]; then
    fallos=$((fallos + 1))
    [ "$codigo" -ne 0 ] && echo "         código de salida $codigo"
    if [ -n "$problemas" ]; then
      local unicos total
      unicos=$(printf '%s\n' "$problemas" | awk 'NF && !visto[$0]++')
      printf '%s\n' "$unicos" | head -n 12 | sed 's/^/         /'
      total=$(printf '%s\n' "$unicos" | wc -l)
      [ "$total" -gt 12 ] && echo "         … y $((total - 12)) líneas más en $LOG"
    fi
  fi
}

# --- argumentos ---
sin_arranque=0
filtros=()
for a in "$@"; do
  case "$a" in
    --sin-arranque) sin_arranque=1 ;;
    *) filtros+=("$a") ;;
  esac
done

# --- versión ---
version=$("$G" --version 2>/dev/null | tr -d '\r' | tail -n 1)
if [ "$version" = "$VERSION_ESPERADA" ]; then
  printf '%s  %-38s %s\n' "OK   " "versión de Godot" "$version"
else
  printf '%s  %-38s %s\n' "AVISO" "versión de Godot" "$version (se esperaba $VERSION_ESPERADA)"
fi

# --- importación y arranque ---
if [ "$sin_arranque" -eq 0 ]; then
  paso "importación del editor" "$G" --headless --path . --editor --quit
  paso "arranque de la escena principal" "$G" --headless --path . --quit-after 5
fi

# --- pruebas ---
pruebas=()
for t in tests/test_*.gd; do
  [ -e "$t" ] || continue
  if [ ${#filtros[@]} -eq 0 ] || [ "$t" = "$GUARDA" ]; then
    pruebas+=("$t"); continue
  fi
  for f in "${filtros[@]}"; do
    case "$t" in *"$f"*) pruebas+=("$t"); break ;; esac
  done
done

if [ ! -e "$GUARDA" ]; then
  printf '%s  %-38s\n' "FALLO" "falta la guarda de píxel ($GUARDA)"
  fallos=$((fallos + 1))
fi

for t in "${pruebas[@]}"; do
  paso "$(basename "$t")" "$G" --headless --path . --script "$t"
done

rm -f "$SALIDA_PASO" "$SALIDA_PASO.limpio"
echo
[ "$esperados" -gt 0 ] && echo "Avisos esperados (AGENTS.md): $esperados"
echo "Log completo: $LOG"
if [ "$fallos" -eq 0 ]; then
  echo "RESUMEN: todo correcto (${#pruebas[@]} pruebas)"
  exit 0
else
  echo "RESUMEN: $fallos paso(s) con fallos"
  exit 1
fi
