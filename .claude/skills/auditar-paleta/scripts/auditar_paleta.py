#!/usr/bin/env python3
"""Comprueba que unas texturas PNG solo usan los colores de una paleta.

La disciplina de paleta es una regla del proyecto: ningún color nuevo fuera del
conjunto definido. Este script lo mide de forma objetiva y nunca modifica las
imágenes que revisa.

Uso:
  auditar_paleta.py --paleta PALETA IMAGEN_O_CARPETA [...]
  auditar_paleta.py --paleta PALETA --mostrar-paleta
  auditar_paleta.py --paleta PALETA IMAGEN --mapa .local/auditoria-paleta
  auditar_paleta.py --paleta PALETA IMAGEN --cuantizar .local/cuantizada.png

Formatos de paleta:
  .aseprite / .ase  paleta guardada en el archivo (modo «panel», por defecto) o
                    los colores pintados en el primer fotograma (--modo pixeles)
  .gpl              paleta de GIMP (Aseprite la exporta así)
  .hex / .txt       un color hexadecimal por línea
  .png              los colores opacos de la imagen

Código de salida: 0 si todo cabe en la paleta, 1 si hay colores fuera, 2 si hay un error.
Requiere Pillow y NumPy (pip install pillow numpy).
"""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("ERROR: faltan Pillow y NumPy. Instálalos con: pip install pillow numpy")
    sys.exit(2)


# --------------------------------------------------------------------- paletas

def _leer_aseprite(ruta: Path, modo: str) -> list[tuple[int, int, int]]:
    """Lee un .aseprite según la especificación oficial del formato.

    modo "panel": chunk de paleta (0x2019, o los antiguos 0x0004 / 0x0011).
    modo "pixeles": colores opacos de las celdas del primer fotograma.
    """
    datos = ruta.read_bytes()
    if len(datos) < 128 or struct.unpack_from("<H", datos, 4)[0] != 0xA5E0:
        raise ValueError(f"{ruta} no parece un archivo de Aseprite")
    n_frames, ancho, alto, profundidad = struct.unpack_from("<HHHH", datos, 6)
    transparente = datos[28]

    paleta: dict[int, tuple[int, int, int, int]] = {}
    celdas: list[tuple[int, int, int, bytes]] = []  # (w, h, tipo, píxeles)
    pos = 128
    for n_frame in range(n_frames):
        bytes_frame, magia, viejos = struct.unpack_from("<IHH", datos, pos)
        if magia != 0xF1FA:
            raise ValueError(f"{ruta}: fotograma {n_frame} dañado")
        nuevos = struct.unpack_from("<I", datos, pos + 12)[0]
        n_chunks = nuevos or viejos
        c = pos + 16
        for _ in range(n_chunks):
            tam, tipo = struct.unpack_from("<IH", datos, c)
            d = c + 6
            if tipo == 0x2019:
                total, primero, ultimo = struct.unpack_from("<III", datos, d)
                e = d + 20
                for i in range(primero, ultimo + 1):
                    flags, r, g, b, a = struct.unpack_from("<HBBBB", datos, e)
                    e += 6
                    if flags & 1:
                        e += 2 + struct.unpack_from("<H", datos, e)[0]
                    paleta[i] = (r, g, b, a)
            elif tipo in (0x0004, 0x0011) and not paleta:
                paquetes = struct.unpack_from("<H", datos, d)[0]
                e, i = d + 2, 0
                for _ in range(paquetes):
                    i += datos[e]
                    n = datos[e + 1] or 256
                    e += 2
                    for _ in range(n):
                        r, g, b = datos[e:e + 3]
                        if tipo == 0x0011:  # 0-63 en el formato antiguo
                            r, g, b = (v * 255 // 63 for v in (r, g, b))
                        paleta[i] = (r, g, b, 255)
                        e += 3
                        i += 1
            elif tipo == 0x2005 and n_frame == 0:
                tipo_celda = struct.unpack_from("<H", datos, d + 7)[0]
                if tipo_celda in (0, 2):
                    w, h = struct.unpack_from("<HH", datos, d + 16)
                    crudo = datos[d + 20:c + tam]
                    if tipo_celda == 2:
                        crudo = zlib.decompress(crudo)
                    celdas.append((w, h, tipo_celda, crudo))
            c += tam
        pos += bytes_frame

    if modo == "panel":
        colores = [v[:3] for _, v in sorted(paleta.items()) if v[3] > 0]
        if not colores:
            raise ValueError(f"{ruta} no tiene paleta guardada; prueba --modo pixeles")
        return colores

    vistos: set[tuple[int, int, int]] = set()
    for w, h, _, px in celdas:
        if profundidad == 32:
            arr = np.frombuffer(px, dtype=np.uint8)[: w * h * 4].reshape(-1, 4)
            arr = arr[arr[:, 3] > 0][:, :3]
        elif profundidad == 16:
            g = np.frombuffer(px, dtype=np.uint8)[: w * h * 2].reshape(-1, 2)
            g = g[g[:, 1] > 0][:, 0]
            arr = np.stack([g, g, g], axis=1)
        else:  # indexado
            idx = np.frombuffer(px, dtype=np.uint8)[: w * h]
            arr = np.array([paleta[i][:3] for i in idx
                            if i != transparente and i in paleta], dtype=np.uint8).reshape(-1, 3)
        vistos.update(map(tuple, np.unique(arr, axis=0).tolist()))
    if not vistos:
        raise ValueError(f"{ruta}: el primer fotograma no tiene píxeles opacos")
    return sorted(vistos)


def _hex(linea: str) -> tuple[int, int, int] | None:
    t = linea.strip().lstrip("#")
    if len(t) >= 6 and all(ch in "0123456789abcdefABCDEF" for ch in t[:6]):
        return int(t[0:2], 16), int(t[2:4], 16), int(t[4:6], 16)
    return None


def leer_paleta(ruta: Path, modo: str) -> list[tuple[int, int, int]]:
    ext = ruta.suffix.lower()
    if ext in (".aseprite", ".ase"):
        colores = _leer_aseprite(ruta, modo)
    elif ext == ".gpl":
        colores = []
        for linea in ruta.read_text(encoding="utf-8", errors="replace").splitlines():
            partes = linea.split()
            if len(partes) >= 3 and all(p.isdigit() for p in partes[:3]):
                colores.append(tuple(int(p) for p in partes[:3]))
    elif ext in (".hex", ".txt"):
        colores = [c for c in map(_hex, ruta.read_text().splitlines()) if c]
    elif ext == ".png":
        arr = np.asarray(Image.open(ruta).convert("RGBA")).reshape(-1, 4)
        colores = [tuple(c) for c in np.unique(arr[arr[:, 3] > 0][:, :3], axis=0).tolist()]
    else:
        raise ValueError(f"formato de paleta no admitido: {ruta.suffix}")
    # Sin duplicados, conservando el orden.
    return list(dict.fromkeys(colores))


# -------------------------------------------------------------------- auditoría

def a_hex(c) -> str:
    return "#%02x%02x%02x" % tuple(int(v) for v in c[:3])


def auditar(ruta: Path, paleta: np.ndarray, mapa: Path | None) -> bool:
    img = np.asarray(Image.open(ruta).convert("RGBA"))
    alto, ancho = img.shape[:2]
    alfa = img[..., 3]
    opacos = alfa > 0
    semi = int(np.count_nonzero((alfa > 0) & (alfa < 255)))

    rgb = img[..., :3].astype(np.int32)
    codigo = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
    cod_paleta = (paleta[:, 0] << 16) | (paleta[:, 1] << 8) | paleta[:, 2]
    fuera = opacos & ~np.isin(codigo, cod_paleta)

    n_opacos = int(np.count_nonzero(opacos))
    n_fuera = int(np.count_nonzero(fuera))
    unicos = np.unique(codigo[opacos]).size if n_opacos else 0

    estado = "OK   " if n_fuera == 0 else "FUERA"
    print(f"{estado}  {ruta}  ({ancho}×{alto}, {unicos} colores, {n_opacos} píxeles opacos)")
    if semi:
        print(f"         {semi} píxeles semitransparentes (alfa entre 1 y 254): revisa que no sea antialiasing")

    if n_fuera:
        cods, cuentas = np.unique(codigo[fuera], return_counts=True)
        orden = np.argsort(-cuentas)
        print(f"         {cods.size} colores fuera de paleta en {n_fuera} píxeles "
              f"({100 * n_fuera / n_opacos:.2f} % de lo opaco)")
        for k in orden[:10]:
            c = np.array([(cods[k] >> 16) & 255, (cods[k] >> 8) & 255, cods[k] & 255])
            d = np.sqrt(((paleta - c) ** 2).sum(axis=1))
            j = int(np.argmin(d))
            ys, xs = np.nonzero(fuera & (codigo == cods[k]))
            print(f"         {a_hex(c)}  {int(cuentas[k]):>6} px  primero en ({xs[0]},{ys[0]})"
                  f"  más cercano {a_hex(paleta[j])} (distancia {d[j]:.1f})")
        if cods.size > 10:
            print(f"         … y {cods.size - 10} colores más")

    if mapa is not None and n_fuera:
        mapa.mkdir(parents=True, exist_ok=True)
        vista = img.copy()
        vista[..., :3] = (vista[..., :3] * 0.35).astype(np.uint8)  # lo correcto, apagado
        vista[fuera] = (255, 0, 255, 255)  # lo que sobra, en magenta
        destino = mapa / f"{ruta.stem}_fuera_de_paleta.png"
        Image.fromarray(vista).save(destino)
        print(f"         mapa: {destino}")
    return n_fuera == 0


def cuantizar(ruta: Path, paleta: np.ndarray, destino: Path) -> None:
    if destino.resolve() == ruta.resolve():
        raise ValueError("--cuantizar nunca sobrescribe la imagen original; elige otra ruta")
    img = np.asarray(Image.open(ruta).convert("RGBA")).copy()
    rgb = img[..., :3].reshape(-1, 1, 3).astype(np.int32)
    idx = np.argmin(((rgb - paleta[None, :, :]) ** 2).sum(axis=2), axis=1)
    img[..., :3] = paleta[idx].reshape(img.shape[0], img.shape[1], 3).astype(np.uint8)
    destino.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(destino)
    print(f"Cuantizada al color más cercano de la paleta: {destino}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("imagenes", nargs="*", type=Path)
    ap.add_argument("--paleta", required=True, type=Path)
    ap.add_argument("--modo", choices=["panel", "pixeles"], default="panel",
                    help="para .aseprite: paleta guardada (panel) o colores pintados (pixeles)")
    ap.add_argument("--mostrar-paleta", action="store_true")
    ap.add_argument("--mapa", type=Path, help="carpeta donde dejar un PNG con lo que sobra en magenta")
    ap.add_argument("--cuantizar", type=Path, help="escribe una copia cuantizada (una sola imagen)")
    args = ap.parse_args()

    try:
        colores = leer_paleta(args.paleta, args.modo)
    except (OSError, ValueError, struct.error, zlib.error) as e:
        print(f"ERROR: {e}")
        return 2
    paleta = np.array(colores, dtype=np.int32)
    es_ase = args.paleta.suffix.lower() in (".aseprite", ".ase")
    print(f"Paleta: {args.paleta} ({len(colores)} colores" + (f", modo {args.modo})" if es_ase else ")"))
    if args.mostrar_paleta or not args.imagenes:
        print("         " + " ".join(a_hex(c) for c in colores))
        if not args.imagenes:
            return 0

    rutas: list[Path] = []
    for r in args.imagenes:
        rutas += sorted(r.rglob("*.png")) if r.is_dir() else [r]
    if not rutas:
        print("ERROR: no hay PNG que revisar")
        return 2

    if args.cuantizar:
        if len(rutas) != 1:
            print("ERROR: --cuantizar admite una sola imagen")
            return 2
        try:
            cuantizar(rutas[0], paleta, args.cuantizar)
        except (OSError, ValueError) as e:
            print(f"ERROR: {e}")
            return 2
        return 0

    todo_bien = True
    for r in rutas:
        try:
            todo_bien &= auditar(r, paleta, args.mapa)
        except OSError as e:
            print(f"ERROR  {r}: {e}")
            return 2
    print(f"RESUMEN: {'todo dentro de la paleta' if todo_bien else 'hay colores fuera de paleta'}"
          f" ({len(rutas)} imágenes)")
    return 0 if todo_bien else 1


if __name__ == "__main__":
    sys.exit(main())
