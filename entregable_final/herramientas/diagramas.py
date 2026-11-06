#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera los diagramas de la memoria de Plato-Plató (MC, escenarios y MR).

Uso: python diagramas.py [directorio_de_salida]
Por defecto escribe en ../memoria/img respecto a este archivo.
"""
import functools
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Polygon, Rectangle
from matplotlib.textpath import TextPath

_fuentes = {f.name for f in font_manager.fontManager.ttflist}
FAMILIA = "Arial" if "Arial" in _fuentes else "DejaVu Sans"
UNIDAD_PT = 0.72  # 1 unidad del lienzo = 0,01 pulgadas = 0,72 puntos
DPI = 200

ACC = "#DCE6F8"
COM = "#DDF1E3"
ELA = "#FCE9D2"
INV = "#D8ECF8"
OFE = "#E8DEF6"
UNI = "#E6E6E6"
ENU = "#F0F4F2"
NOTA = "#FFF8DC"
LINEA = "#44505E"
TINTA = "#1B2430"
ROJO = "#B3261E"


@functools.lru_cache(maxsize=None)
def ancho(texto, size, weight="normal", style="normal"):
    if not texto:
        return 0.0
    fp = FontProperties(family=FAMILIA, weight=weight, style=style)
    return TextPath((0, 0), texto, size=size, prop=fp).get_extents().width / UNIDAD_PT


class Caja:
    def __init__(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h

    def ancla(self, espec):
        if "=" in espec:  # posición absoluta sobre el lado, por ejemplo "R=650"
            lado, _, valor = espec.partition("=")
            v = float(valor)
            if lado == "L":
                return (self.x, v)
            if lado == "R":
                return (self.x + self.w, v)
            if lado == "T":
                return (v, self.y)
            return (v, self.y + self.h)
        lado, _, frac = espec.partition(":")
        f = float(frac) if frac else 0.5
        if lado == "L":
            return (self.x, self.y + self.h * f)
        if lado == "R":
            return (self.x + self.w, self.y + self.h * f)
        if lado == "T":
            return (self.x + self.w * f, self.y)
        return (self.x + self.w * f, self.y + self.h)


class Diagrama:
    def __init__(self, nombre, fs=10.0, lh=None):
        self.nombre = nombre
        self.fs = fs
        self.lh = lh or fs * 1.62
        self.cajas = {}
        self.dibujo = []
        self.aristas = []
        self.grupos = []
        self.notas = []
        self.textos = []

    # ---------------------------------------------------------- cajas
    def _clase(self, cid, x, y, cab, filas, fill, w, kind, rojo=False):
        fs = self.fs
        ancho_txt = 0.0
        for t, weight, style, size in cab:
            ancho_txt = max(ancho_txt, ancho(t, size, weight, style))
        for t in filas:
            ancho_txt = max(ancho_txt, ancho(t, fs))
        ww = max(w or 0, ancho_txt + 20, 120)
        hcab = sum(c[3] * 1.5 for c in cab) + 8
        hcuerpo = max(len(filas), 0) * self.lh + (8 if filas else 0)
        caja = Caja(x, y, ww, hcab + hcuerpo)
        self.cajas[cid] = caja
        self.dibujo.append(("clase", caja, cab, filas, fill, hcab, kind, rojo))
        return caja

    def ent(self, cid, x, y, nombre, attrs, fill, w=None, stereo="entidad"):
        cab = [
            ("«%s»" % stereo, "normal", "italic", self.fs - 1),
            (nombre, "bold", "normal", self.fs + 0.5),
        ]
        return self._clase(cid, x, y, cab, attrs, fill, w, "clase")

    def enum(self, cid, x, y, nombre, vals, w=None):
        return self.ent(cid, x, y, nombre, vals, ENU, w, "enumerado")

    def obj(self, cid, x, y, titulo, attrs, fill, w=None, rojo=False):
        cab = [(titulo, "bold", "normal", self.fs)]
        return self._clase(cid, x, y, cab, attrs, fill, w, "objeto", rojo)

    def tabla(self, cid, x, y, nombre, filas, fill, w=None):
        """filas: lista de (marca, texto)."""
        fs = self.fs
        col = max([ancho(m, fs - 1, "bold") for m, _ in filas] + [0]) + 12
        cuerpo = max([ancho(t, fs, "bold" if m.startswith("PK") else "normal") for m, t in filas]
                     + [ancho(nombre, fs + 1, "bold") - col])
        ww = max(w or 0, col + cuerpo + 18, 130)
        hcab = (fs + 1) * 1.5 + 8
        caja = Caja(x, y, ww, hcab + len(filas) * self.lh + 8)
        self.cajas[cid] = caja
        self.dibujo.append(("tabla", caja, nombre, filas, fill, hcab, col))
        return caja

    # -------------------------------------------------------- aristas
    def arista(self, a, sa, b, sb, nombre=None, ma=None, mb=None, hvh=None, vhv=None, comp=None,
               flecha=False, rojo=False, nombre_en=None, ma_off=None, mb_off=None):
        """hvh=x: tramo horizontal-vertical-horizontal por x; vhv=y: vertical-horizontal-vertical por y."""
        self.aristas.append(dict(a=a, sa=sa, b=b, sb=sb, nombre=nombre, ma=ma, mb=mb, hvh=hvh, vhv=vhv,
                                 comp=comp, flecha=flecha, rojo=rojo, nombre_en=nombre_en,
                                 ma_off=ma_off, mb_off=mb_off))

    def grupo(self, titulo, ids, fill, pad=16, arriba=26, extra=(0, 0, 0, 0)):
        self.grupos.append((titulo, ids, fill, pad, arriba, extra))

    def nota(self, x, y, w, texto, fs=None, titulo=None):
        self.notas.append((x, y, w, texto, fs or self.fs - 1, titulo))

    def texto(self, x, y, s, fs=None, weight="normal", color=TINTA, ha="left"):
        self.textos.append((x, y, s, fs or self.fs, weight, color, ha))

    # ------------------------------------------------------- render
    @staticmethod
    def _ruta(p, sa, q, sb, hvh, vhv):
        if hvh is not None:
            return [p, (hvh, p[1]), (hvh, q[1]), q]
        if vhv is not None:
            return [p, (p[0], vhv), (q[0], vhv), q]
        la, lb = sa[0], sb[0]
        if abs(p[0] - q[0]) < 0.5 or abs(p[1] - q[1]) < 0.5:
            return [p, q]
        if la in "LR" and lb in "LR":
            xm = (p[0] + q[0]) / 2
            return [p, (xm, p[1]), (xm, q[1]), q]
        if la in "TB" and lb in "TB":
            ym = (p[1] + q[1]) / 2
            return [p, (p[0], ym), (q[0], ym), q]
        if la in "LR":
            return [p, (q[0], p[1]), q]
        return [p, (p[0], q[1]), q]

    @staticmethod
    def _envolver(texto, w, fs):
        lineas = []
        for parrafo in texto.split("\n"):
            act = ""
            for pal in parrafo.split(" "):
                prueba = (act + " " + pal).strip()
                if ancho(prueba, fs) > w and act:
                    lineas.append(act)
                    act = pal
                else:
                    act = prueba
            lineas.append(act)
        return lineas

    def guardar(self, archivo, margen=18):
        fs = self.fs
        notas = []
        for x, y, w, texto, nfs, titulo in self.notas:
            lineas = self._envolver(texto, w - 14, nfs)
            hl = nfs * 1.5
            h = len(lineas) * hl + 10 + (hl + 2 if titulo else 0)
            notas.append((x, y, w, h, lineas, nfs, hl, titulo))
        rect_grupos = []
        for titulo, ids, fill, pad, arriba, extra in self.grupos:
            cs = [self.cajas[i] for i in ids]
            x0 = min(c.x for c in cs) - pad - extra[0]
            y0 = min(c.y for c in cs) - arriba - extra[1]
            x1 = max(c.x + c.w for c in cs) + pad + extra[2]
            y1 = max(c.y + c.h for c in cs) + pad + extra[3]
            rect_grupos.append((x0, y0, x1, y1, titulo, fill))
        xs, ys = [], []
        for c in self.cajas.values():
            xs += [c.x, c.x + c.w]
            ys += [c.y, c.y + c.h]
        for r in rect_grupos:
            xs += [r[0], r[2]]
            ys += [r[1], r[3]]
        for x, y, w, h, *_ in notas:
            xs += [x, x + w]
            ys += [y, y + h]
        for t in self.textos:
            xs += [t[0], t[0] + ancho(t[2], t[3], t[4])]
            ys += [t[1]]
        for e in self.aristas:
            if e["hvh"] is not None:
                xs.append(e["hvh"])
            if e["vhv"] is not None:
                ys.append(e["vhv"])
        x_min, x_max = min(xs) - margen, max(xs) + margen
        y_min, y_max = min(ys) - margen, max(ys) + margen
        W, H = x_max - x_min, y_max - y_min

        fig = plt.figure(figsize=(W / 100.0, H / 100.0), dpi=DPI)
        ax = fig.add_axes([0, 0, 1, 1])
        ax.set_xlim(x_min, x_max)
        ax.set_ylim(y_max, y_min)
        ax.axis("off")
        kw = dict(family=FAMILIA, color=TINTA)

        for x0, y0, x1, y1, titulo, fill in rect_grupos:
            ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, facecolor=fill, alpha=0.30,
                                   edgecolor="#8C97A5", lw=0.9, zorder=1))
            ax.text((x0 + x1) / 2, y0 + 12, titulo, ha="center", va="center", fontsize=fs + 1,
                    weight="bold", zorder=2, **kw)

        for x, y, w, h, lineas, nfs, hl, titulo in notas:
            ax.add_patch(Rectangle((x, y), w, h, facecolor=NOTA, edgecolor="#B9A35C", lw=0.8, zorder=3))
            yy = y + 5 + hl / 2
            if titulo:
                ax.text(x + 7, yy, titulo, fontsize=nfs, weight="bold", va="center", zorder=4, **kw)
                yy += hl + 2
            for ln in lineas:
                ax.text(x + 7, yy, ln, fontsize=nfs, va="center", zorder=4, **kw)
                yy += hl

        etiquetas = []
        for e in self.aristas:
            ca, cb = self.cajas[e["a"]], self.cajas[e["b"]]
            p, q = ca.ancla(e["sa"]), cb.ancla(e["sb"])
            tramo = self._ruta(p, e["sa"], q, e["sb"], e["hvh"], e["vhv"])
            color = ROJO if e["rojo"] else LINEA
            ls = (0, (5, 3)) if e["rojo"] else "-"
            ax.plot([r[0] for r in tramo], [r[1] for r in tramo], color=color, lw=1.05, ls=ls,
                    zorder=5, solid_capstyle="round", solid_joinstyle="miter")
            if e["comp"]:
                punto, sig = (tramo[0], tramo[1]) if e["comp"] == "a" else (tramo[-1], tramo[-2])
                self._rombo(ax, punto, sig, color)
            if e["flecha"]:
                self._flecha(ax, tramo[-1], tramo[-2], color)
            for marca, extremo, sig, off in (
                (e["ma"], tramo[0], tramo[1], e["ma_off"]),
                (e["mb"], tramo[-1], tramo[-2], e["mb_off"]),
            ):
                if marca:
                    etiquetas.append(self._pos_mult(marca, extremo, sig, off, color))
            if e["nombre"]:
                if e["nombre_en"]:
                    nx, ny = e["nombre_en"]
                else:
                    mejor, nx, ny = -1, 0, 0
                    for r1, r2 in zip(tramo, tramo[1:]):
                        lon = abs(r1[0] - r2[0]) + abs(r1[1] - r2[1])
                        if lon > mejor:
                            mejor, nx, ny = lon, (r1[0] + r2[0]) / 2, (r1[1] + r2[1]) / 2
                etiquetas.append((nx, ny, e["nombre"], fs - 1, "center", color, "italic", True))
        for x, y, s, tam, ha, color, style, fondo in etiquetas:
            bbox = dict(facecolor="white", edgecolor="none", pad=1.1, alpha=0.95) if fondo else None
            ax.text(x, y, s, fontsize=tam, ha=ha, va="center", color=color, style=style,
                    family=FAMILIA, zorder=7, bbox=bbox)

        for d in self.dibujo:
            if d[0] == "clase":
                self._dib_clase(ax, *d[1:])
            else:
                self._dib_tabla(ax, *d[1:])
        for x, y, s, tam, weight, color, ha in self.textos:
            ax.text(x, y, s, fontsize=tam, weight=weight, color=color, ha=ha, va="center",
                    family=FAMILIA, zorder=9)
        os.makedirs(os.path.dirname(archivo), exist_ok=True)
        fig.savefig(archivo, dpi=DPI, facecolor="white")
        plt.close(fig)

    def _pos_mult(self, marca, ext, sig, off, color):
        dx, dy = sig[0] - ext[0], sig[1] - ext[1]
        lon = max((dx * dx + dy * dy) ** 0.5, 1e-6)
        dx, dy = dx / lon, dy / lon
        ox, oy = off if off else (0, 0)
        if abs(dx) > abs(dy):  # tramo horizontal: encima de la línea
            x = ext[0] + dx * (6 + ancho(marca, self.fs - 1) / 2)
            y = ext[1] - 9
        else:  # tramo vertical: a la derecha de la línea
            x = ext[0] + 5 + ancho(marca, self.fs - 1) / 2
            y = ext[1] + dy * 11
        return (x + ox, y + oy, marca, self.fs - 1, "center", color, "normal", False)

    @staticmethod
    def _rombo(ax, punto, sig, color):
        dx, dy = sig[0] - punto[0], sig[1] - punto[1]
        lon = max((dx * dx + dy * dy) ** 0.5, 1e-6)
        dx, dy = dx / lon, dy / lon
        px, py = -dy, dx
        a, b = 15, 5
        pts = [punto, (punto[0] + dx * a / 2 + px * b, punto[1] + dy * a / 2 + py * b),
               (punto[0] + dx * a, punto[1] + dy * a),
               (punto[0] + dx * a / 2 - px * b, punto[1] + dy * a / 2 - py * b)]
        ax.add_patch(Polygon(pts, closed=True, facecolor=color, edgecolor=color, lw=0.6, zorder=6))

    @staticmethod
    def _flecha(ax, punto, sig, color):
        dx, dy = sig[0] - punto[0], sig[1] - punto[1]
        lon = max((dx * dx + dy * dy) ** 0.5, 1e-6)
        dx, dy = dx / lon, dy / lon
        px, py = -dy, dx
        a, b = 9, 4
        pts = [punto, (punto[0] + dx * a + px * b, punto[1] + dy * a + py * b),
               (punto[0] + dx * a - px * b, punto[1] + dy * a - py * b)]
        ax.add_patch(Polygon(pts, closed=True, facecolor=color, edgecolor=color, lw=0.6, zorder=6))

    def _dib_clase(self, ax, caja, cab, filas, fill, hcab, kind, rojo):
        kw = dict(family=FAMILIA, color=ROJO if rojo else TINTA, zorder=9)
        ec = ROJO if rojo else "#7C8896"
        ls = (0, (5, 3)) if rojo else "-"
        ax.add_patch(Rectangle((caja.x, caja.y), caja.w, caja.h, facecolor="white", edgecolor=ec,
                               lw=1.0, ls=ls, zorder=8))
        ax.add_patch(Rectangle((caja.x, caja.y), caja.w, hcab, facecolor=fill, edgecolor=ec, lw=1.0,
                               ls=ls, zorder=8))
        yy = caja.y + 4
        for t, weight, style, size in cab:
            alto = size * 1.5
            ax.text(caja.x + caja.w / 2, yy + alto / 2, t, ha="center", va="center", fontsize=size,
                    weight=weight, style=style, **kw)
            if kind == "objeto":
                w_t = ancho(t, size, weight)
                ax.plot([caja.x + caja.w / 2 - w_t / 2, caja.x + caja.w / 2 + w_t / 2],
                        [yy + alto / 2 + size * 0.8] * 2, color=kw["color"], lw=0.8, zorder=9)
            yy += alto
        yy = caja.y + hcab + 4
        for t in filas:
            ax.text(caja.x + 8, yy + self.lh / 2, t, ha="left", va="center", fontsize=self.fs, **kw)
            yy += self.lh

    def _dib_tabla(self, ax, caja, nombre, filas, fill, hcab, col):
        fs = self.fs
        kw = dict(family=FAMILIA, color=TINTA, zorder=9)
        ax.add_patch(Rectangle((caja.x, caja.y), caja.w, caja.h, facecolor="white", edgecolor="#7C8896",
                               lw=1.0, zorder=8))
        ax.add_patch(Rectangle((caja.x, caja.y), caja.w, hcab, facecolor=fill, edgecolor="#7C8896",
                               lw=1.0, zorder=8))
        ax.text(caja.x + caja.w / 2, caja.y + hcab / 2, nombre, ha="center", va="center",
                fontsize=fs + 1, weight="bold", **kw)
        yy = caja.y + hcab + 4
        for marca, t in filas:
            pk = marca.startswith("PK")
            ax.text(caja.x + 6, yy + self.lh / 2, marca, ha="left", va="center", fontsize=fs - 1,
                    weight="bold", family=FAMILIA, color="#7A1F1F" if pk else "#33506E", zorder=9)
            ax.text(caja.x + 6 + col, yy + self.lh / 2, t, ha="left", va="center", fontsize=fs,
                    weight="bold" if pk else "normal", **kw)
            yy += self.lh


# ==================================================================== datos
A_ROL = ["nombre : TipoRol"]
A_PERMISO = ["nombre"]
A_USUARIO = ["nombre", "correoElectronico", "contraseñaProtegida", "estado : EstadoRegistro", "fechaCreacion"]
A_PROVEEDOR = ["nombre", "personaContacto [0..1]", "telefono [0..1]", "correoContacto [0..1]", "formaPago",
               "estado : EstadoRegistro"]
A_UNIDAD = ["codigo", "nombre", "magnitud : TipoMagnitud", "factorABase"]
A_INGREDIENTE = ["nombre", "categoria", "estado : EstadoRegistro", "/cantidadTotalDisponible"]
A_PRECIO = ["precioCompra", "fechaInicioVigencia", "fechaFinVigencia [0..1]", "seleccionadoParaCosteo"]
A_PLATO = ["nombre", "imagen [0..1]", "descripcion", "categoria", "menuDelDia", "precioVenta [0..1]",
           "estado : EstadoRegistro", "porcentajeMargenObjetivo [0..1]", "/costeProduccion [0..1]",
           "/margenBruto [0..1]", "/porcentajeMargen [0..1]"]
A_RECETA = ["nombre", "cantidadRendimiento", "estado : EstadoRegistro", "/costeElaboracion [0..1]",
            "/costeUnitario [0..1]"]
A_COMPONENTE = ["cantidad"]
A_LOTE = ["identificadorLote", "/cantidad", "fechaEntrada", "fechaCaducidad [0..1]", "ubicacionAlmacen", "fresco",
          "aptoParaConsumo"]
A_MOV = ["tipo : TipoMovimiento", "cantidad", "fechaMovimiento", "finalidadSalida : FinalidadSalida [0..1]"]
A_MERMA = ["cantidadDesperdiciada", "fechaMerma", "motivo : MotivoMerma", "detalleMotivo [0..1]",
           "costePerdida [0..1]"]
A_PERIODO = ["tipo : TipoOferta", "fechaInicio", "fechaFin [0..1]"]
A_AUT = ["fechaAutorizacion", "costeEvaluado", "precioVentaEvaluado"]


# ================================================================= MC global
def mc_global(sal):
    d = Diagrama("mc_global", fs=9.6)
    d.ent("rol", 40, 110, "Rol", A_ROL, ACC, w=128)
    d.ent("permiso", 40, 250, "Permiso", A_PERMISO, ACC, w=128)
    d.ent("usuario", 290, 110, "Usuario", A_USUARIO, ACC, w=170)
    d.ent("aut", 290, 376, "AutorizacionCarta", A_AUT, OFE, w=170)
    d.ent("per", 290, 524, "PeriodoOferta", A_PERIODO, OFE, w=170)

    d.ent("plato", 590, 110, "Plato", A_PLATO, ELA, w=226)
    d.ent("receta", 590, 408, "Receta", A_RECETA, ELA, w=226)
    d.ent("comp", 590, 620, "ComponenteReceta", A_COMPONENTE, ELA, w=226)
    d.ent("unidad", 590, 790, "UnidadMedida", A_UNIDAD, UNI, w=226)

    d.ent("mov", 950, 110, "MovimientoStock", A_MOV, INV, w=262)
    d.ent("merma", 1322, 110, "Merma", A_MERMA, INV, w=178)
    d.ent("lote", 950, 310, "Lote", A_LOTE, INV, w=262)

    d.ent("ing", 950, 610, "Ingrediente", A_INGREDIENTE, COM, w=262)
    d.ent("precio", 950, 790, "PrecioCompra", A_PRECIO, COM, w=262)
    d.ent("prov", 1322, 772, "Proveedor", A_PROVEEDOR, COM, w=178)

    d.grupo("Acceso", ["rol", "permiso", "usuario"], ACC)
    d.grupo("Oferta y autorización", ["aut", "per"], OFE, extra=(26, 0, 26, 0))
    d.grupo("Elaboraciones", ["plato", "receta", "comp"], ELA, extra=(30, 0, 44, 0))
    d.grupo("Inventario", ["mov", "merma", "lote"], INV)
    d.grupo("Compras", ["ing", "precio", "prov"], COM)

    d.arista("rol", "R=140", "usuario", "L=140", "tieneRol", "1", "0..*")
    d.arista("rol", "B", "permiso", "T", "concede", "0..*", "0..*", nombre_en=(104, 218))
    d.arista("usuario", "L=210", "permiso", "R=278", "tienePermisoAdicional", "0..*", "0..*", hvh=229,
             nombre_en=(229, 244), ma_off=(2, 0), mb_off=(2, 0))
    d.arista("usuario", "B=448", "aut", "T=448", "emite", "1", "0..*", nombre_en=(448, 318))
    d.arista("per", "T", "aut", "B", "tieneAutorizacion", "1", "0..1")
    d.arista("plato", "L=290", "per", "R=568", "tienePeriodoOferta", "1", "0..*", hvh=521, nombre_en=(521, 430))
    d.arista("plato", "B", "receta", "T", "tieneReceta", "0..1", "1")
    d.arista("receta", "B=670", "comp", "T=670", "seComponeDe", "1", "1..*", comp="a", nombre_en=(670, 575),
             ma_off=(8, 0))
    d.arista("comp", "R=636", "receta", "R=510", "utilizaReceta", "0..*", "0..1", hvh=846, nombre_en=(846, 575))
    d.arista("comp", "R=660", "ing", "L=660", "utilizaIngrediente", "0..*", "0..1", ma_off=(0, 22), mb_off=(0, 22))
    d.arista("unidad", "T", "comp", "B", "seExpresaEn", "1", "0..*")
    d.arista("unidad", "L=840", "receta", "L=470", "rindeEn", "1", "0..*", hvh=556, nombre_en=(556, 660))
    d.arista("unidad", "R=815", "ing", "L=704", "seMideEn", "1", "0..*", hvh=905, nombre_en=(905, 752))
    d.arista("unidad", "R=862", "precio", "L=862", "expresaPrecioEn", "1", "0..*", ma_off=(0, 22), mb_off=(0, 22))
    d.arista("prov", "L=840", "precio", "R=840", "ofrece", "1", "0..*")
    d.arista("ing", "B", "precio", "T", "tienePrecio", "1", "0..*")
    d.arista("lote", "B", "ing", "T", "tieneLote", "0..*", "1", nombre_en=(1081, 532))
    d.arista("mov", "B", "lote", "T", "recibeMovimiento", "0..*", "1")
    d.arista("merma", "B", "lote", "R=326", "afectaLote", "0..*", "0..1", nombre_en=(1320, 326))
    d.arista("mov", "R=165", "merma", "L=165", "originaSalida", "0..1", "0..1", ma_off=(0, 22), mb_off=(0, 22))
    d.arista("mov", "L=165", "plato", "R=165", "seDestinaA", "0..*", "0..1", ma_off=(0, 18), mb_off=(0, 18))
    d.texto(822, 148, "platoDestino", fs=8.4, color=LINEA)
    d.arista("merma", "T", "plato", "T=785", "afectaPlato", "0..*", "0..1", vhv=62)

    d.nota(1250, 350, 250,
           "RN-01 Con menos de 48 h para caducar, el lote solo se usa en platos del menú del día, si sigue apto.\n"
           "RN-03 Un lote fresco no se usa desde recepción + 72 h.", titulo="Reglas de inventario")
    d.nota(1250, 490, 250,
           "Merma: exactamente un Lote o un Plato (RC-14).\n"
           "Componente: exactamente un Ingrediente u otra Receta.\n"
           "Sin ciclos entre recetas (RC-12).", titulo="Asociaciones exclusivas")
    d.nota(40, 660, 440,
           "RN-02 Toda incorporación a carta permanente requiere autorización previa de un administrador, "
           "con independencia de la relación entre coste y precio, y con coste calculable.\n"
           "RN-04 Antes de la primera incorporación, al menos 14 días consecutivos como sugerencia del chef.",
           titulo="Reglas de oferta")
    d.nota(40, 800, 440,
           "1 exactamente uno; 0..1 ninguno o uno; 0..* cero o más; 1..* uno o más. "
           "/atributo: derivado; [0..1]: opcional; rombo negro: composición. "
           "Los enumerados se detallan en las vistas siguientes.", titulo="Leyenda")
    d.guardar(os.path.join(sal, "mc_global.png"))


# =============================================================== MC por vistas
def mc_vistas(sal):
    # 4.2 Acceso
    d = Diagrama("mc_acceso", fs=10.5)
    d.ent("rol", 40, 40, "Rol", A_ROL, ACC, w=170)
    d.ent("usuario", 420, 40, "Usuario", A_USUARIO, ACC, w=230)
    d.ent("permiso", 240, 280, "Permiso", A_PERMISO, ACC, w=170)
    d.enum("e1", 40, 420, "TipoRol", ["ADMINISTRADOR", "ENCARGADO", "EMPLEADO"], w=170)
    d.enum("e2", 260, 420, "EstadoRegistro", ["ACTIVO", "INACTIVO"], w=170)
    d.arista("rol", "R=78", "usuario", "L=78", "tieneRol", "1", "0..*")
    d.arista("rol", "B", "permiso", "L=318", "concede", "0..*", "0..*", nombre_en=(125, 235))
    d.arista("usuario", "B", "permiso", "R=318", "tienePermisoAdicional", "0..*", "0..*", nombre_en=(535, 262))
    d.nota(470, 420, 240, "Permisos efectivos = permisos del rol + permisos adicionales del usuario. "
                          "La cuenta debe estar activa (RC-10, D-03).", titulo="Control de acceso")
    d.guardar(os.path.join(sal, "mc_acceso.png"))

    # 4.3 Compras
    d = Diagrama("mc_compras", fs=10.5)
    d.ent("prov", 40, 40, "Proveedor", A_PROVEEDOR, COM, w=240)
    d.ent("ing", 760, 40, "Ingrediente", A_INGREDIENTE, COM, w=250)
    d.ent("precio", 370, 250, "PrecioCompra", A_PRECIO, COM, w=250)
    d.ent("unidad", 760, 250, "UnidadMedida", A_UNIDAD, UNI, w=250)
    d.enum("em", 40, 270, "TipoMagnitud", ["MASA", "VOLUMEN", "UNIDAD", "RACION"], w=170)
    d.arista("prov", "R=110", "precio", "T=450", "ofrece", "1", "0..*", nombre_en=(365, 110))
    d.arista("ing", "L=100", "precio", "T=560", "tienePrecio", "1", "0..*", nombre_en=(660, 100))
    d.arista("ing", "B", "unidad", "T", "seMideEn", "0..*", "1")
    d.arista("precio", "R=320", "unidad", "L=320", "expresaPrecioEn", "0..*", "1", ma_off=(0, 22), mb_off=(0, 22))
    d.nota(370, 400, 250, "Como máximo un precio seleccionado por ingrediente, vigente al calcular. "
                          "Sin selección válida, el coste queda sin valor (D-01, RC-11).",
           titulo="Selección para el costeo")
    d.guardar(os.path.join(sal, "mc_compras.png"))

    # 4.4 Platos y recetas
    d = Diagrama("mc_recetas", fs=10.0)
    d.ent("plato", 40, 40, "Plato", A_PLATO, ELA, w=240)
    d.ent("receta", 420, 40, "Receta", A_RECETA, ELA, w=230)
    d.ent("comp", 420, 280, "ComponenteReceta", A_COMPONENTE, ELA, w=230)
    d.ent("ing", 800, 255, "Ingrediente", A_INGREDIENTE, COM, w=230)
    d.ent("unidad", 420, 430, "UnidadMedida", A_UNIDAD, UNI, w=230)
    d.arista("plato", "R=90", "receta", "L=90", "tieneReceta", "0..1", "1")
    d.arista("receta", "B=500", "comp", "T=500", "seComponeDe", "1", "1..*", comp="a", ma_off=(8, 0))
    d.arista("comp", "R=298", "receta", "R=130", "utilizaReceta", "0..*", "0..1", hvh=710, nombre_en=(710, 215))
    d.arista("comp", "R=322", "ing", "L=322", "utilizaIngrediente", "0..*", "0..1", ma_off=(0, 22), mb_off=(0, 22))
    d.arista("unidad", "T", "comp", "B", "seExpresaEn", "1", "0..*")
    d.arista("unidad", "L=490", "receta", "L=130", "rindeEn", "1", "0..*", hvh=385, nombre_en=(385, 320))
    d.nota(40, 330, 300, "Una receta sin plato actúa como subreceta cuando otra receta la utiliza (D-07). "
                         "El rendimiento de la receta de un plato se expresa en raciones (D-02).",
           titulo="Subreceta: un papel, no una clase")
    d.nota(800, 400, 270, "Línea de ingrediente: cantidad convertida a la unidad del precio × precio.\n"
                          "Línea de receta: cantidad convertida a la unidad de rendimiento × coste unitario.\n"
                          "/costeUnitario = /costeElaboracion / cantidadRendimiento.\n"
                          "Si falta un precio válido, el coste queda sin valor (RC-11).",
           titulo="Cálculo del coste (RC-05)")
    d.guardar(os.path.join(sal, "mc_recetas.png"))

    # 4.5 Inventario
    d = Diagrama("mc_inventario", fs=10.0)
    d.ent("ing", 40, 40, "Ingrediente", A_INGREDIENTE, COM, w=225)
    d.ent("lote", 430, 40, "Lote", A_LOTE, INV, w=225)
    d.ent("mov", 40, 290, "MovimientoStock", A_MOV, INV, w=285)
    d.ent("merma", 430, 290, "Merma", A_MERMA, INV, w=225)
    d.ent("plato", 260, 490, "Plato", ["nombre", "menuDelDia"], ELA, w=170)
    d.enum("e1", 750, 40, "TipoMovimiento", ["ENTRADA", "SALIDA", "AJUSTE"], w=225)
    d.enum("e2", 750, 170, "FinalidadSalida", ["ELABORACION", "MERMA", "OTRA"], w=225)
    d.enum("e3", 750, 300, "MotivoMerma", ["CADUCIDAD", "DETERIORO", "ELABORACION_INCORRECTA", "PLATO_DESECHADO", "OTRO"], w=225)
    d.arista("ing", "R=90", "lote", "L=90", "tieneLote", "1", "0..*")
    d.arista("lote", "L=170", "mov", "T", "recibeMovimiento", "1", "0..*", nombre_en=(300, 170))
    d.arista("lote", "B", "merma", "T", "afectaLote", "0..1", "0..*")
    d.arista("mov", "R=350", "merma", "L=350", "originaSalida", "0..1", "0..1", ma_off=(0, 22), mb_off=(0, 22))
    d.arista("mov", "B", "plato", "L=535", "seDestinaA (platoDestino)", "0..*", "0..1", nombre_en=(182, 455))
    d.arista("merma", "B", "plato", "R=535", "afectaPlato", "0..*", "0..1", nombre_en=(542, 470))
    d.nota(750, 470, 225, "La merma de lote origina una sola salida MERMA. La de plato no descuenta de nuevo: "
                          "sus ingredientes salieron al elaborar (RC-14).", titulo="Sin doble descuento")
    d.nota(40, 600, 640, "Saldo = entradas − salidas + ajustes firmados; nunca negativo (RC-13). "
                         "RN-01: con menos de 48 h para caducar, solo platos del menú del día y si sigue apto. "
                         "RN-03: un lote fresco no se usa desde recepción + 72 h.", titulo="Saldo y uso de los lotes")
    d.guardar(os.path.join(sal, "mc_inventario.png"))

    # 4.6 Oferta
    d = Diagrama("mc_oferta", fs=10.5)
    d.ent("plato", 40, 40, "Plato", ["nombre", "precioVenta [0..1]", "/costeProduccion [0..1]"], ELA, w=220)
    d.ent("per", 460, 40, "PeriodoOferta", A_PERIODO, OFE, w=220)
    d.ent("aut", 460, 240, "AutorizacionCarta", A_AUT, OFE, w=220)
    d.ent("usu", 40, 240, "Usuario", ["nombre", "estado : EstadoRegistro"], ACC, w=220)
    d.ent("rol", 40, 410, "Rol", A_ROL, ACC, w=220)
    d.enum("e", 460, 410, "TipoOferta", ["SUGERENCIA_CHEF", "CARTA_PERMANENTE"], w=220)
    d.arista("plato", "R=90", "per", "L=90", "tienePeriodoOferta", "1", "0..*")
    d.arista("per", "B", "aut", "T", "tieneAutorizacion", "1", "0..1")
    d.arista("usu", "R=290", "aut", "L=290", "emite", "1", "0..*")
    d.arista("usu", "B", "rol", "T", "tieneRol", "0..*", "1")
    d.nota(730, 40, 270, "Toda incorporación requiere autorización previa de un administrador, con independencia de "
                         "la relación entre coste y precio. No se autoriza sin coste calculable.", titulo="RN-02")
    d.nota(730, 190, 270, "Antes de la primera incorporación, el plato debe haberse ofrecido como sugerencia del chef "
                          "durante al menos 14 días consecutivos ya transcurridos.", titulo="RN-04")
    d.guardar(os.path.join(sal, "mc_oferta.png"))


# ================================================================= escenarios
def escenarios(sal):
    # E1
    d = Diagrama("esc_1", fs=10.0)
    d.obj("h", 440, 110, "harina : Ingrediente", ['nombre = "Harina"', "unidad → kg", "estado = ACTIVO"], COM, w=210)
    d.obj("pa", 40, 30, "precioA : PrecioCompra", ["precioCompra = 1.20 €", "unidad → kg", "fechaInicioVigencia = 01/10/2026",
                                                  "fechaFinVigencia = sin valor", "seleccionadoParaCosteo = true"], COM, w=265)
    d.obj("pb", 40, 220, "precioB : PrecioCompra", ["precioCompra = 1.40 €", "unidad → kg", "fechaInicioVigencia = 01/10/2026",
                                                   "fechaFinVigencia = sin valor", "seleccionadoParaCosteo = false"], COM, w=265)
    d.obj("a", 780, 25, "proveedorA : Proveedor", ['nombre = "Distribuciones Norte"', "estado = ACTIVO"], COM, w=240)
    d.obj("b", 780, 245, "proveedorB : Proveedor", ['nombre = "Suministros Sur"', "estado = ACTIVO"], COM, w=240)
    d.arista("h", "L=150", "pa", "R=105", "tienePrecio", hvh=372, nombre_en=(372, 128))
    d.arista("h", "L=180", "pb", "R=240", "tienePrecio", hvh=372, nombre_en=(372, 210))
    d.arista("pa", "R=60", "a", "L=60", "ofrece")
    d.arista("pb", "R=290", "b", "L=290", "ofrece")
    d.guardar(os.path.join(sal, "esc_1.png"))

    # E2
    d = Diagrama("esc_2", fs=10.0)
    d.obj("p", 40, 30, "degustacion : Plato", ['nombre = "Degustación de salsa"', "precioVenta = 3.00 €", "/costeProduccion = 0.60 €",
                                               "/margenBruto = 2.40 €", "/porcentajeMargen = 80 %"], ELA, w=240)
    d.obj("rp", 420, 30, "recetaPlato : Receta", ['nombre = "Degustación de salsa"', "cantidadRendimiento = 1", "unidad → ración",
                                                  "estado = ACTIVO", "/costeElaboracion = 0.60 €", "/costeUnitario = 0.60 €"], ELA, w=245)
    d.obj("cs", 810, 45, "porcionSalsa : ComponenteReceta", ["cantidad = 0.15", "unidad → kg"], ELA, w=280)
    d.obj("rs", 810, 215, "recetaSalsa : Receta", ['nombre = "Salsa de tomate"', "cantidadRendimiento = 1.50", "unidad → kg",
                                                   "estado = ACTIVO", "/costeElaboracion = 6.00 €", "/costeUnitario = 4.00 €"], ELA, w=280)
    d.obj("ct", 420, 245, "tomateSalsa : ComponenteReceta", ["cantidad = 2.00", "unidad → kg"], ELA, w=260)
    d.obj("t", 40, 245, "tomate : Ingrediente", ['nombre = "Tomate"', "unidad → kg"], COM, w=240)
    d.obj("pr", 40, 390, "precioTomate : PrecioCompra", ["precioCompra = 3.00 €", "unidad → kg", "fechaInicioVigencia = 01/10/2026",
                                                         "fechaFinVigencia = sin valor", "seleccionadoParaCosteo = true"], COM, w=265)
    d.obj("hu", 460, 420, "huerta : Proveedor", ['nombre = "Huerta Local"', "estado = ACTIVO"], COM, w=220)
    d.arista("p", "R=90", "rp", "L=90", "tieneReceta")
    d.arista("rp", "R=85", "cs", "L=85", "seComponeDe", comp="a")
    d.arista("cs", "B", "rs", "T", "utilizaReceta")
    d.arista("rs", "L=285", "ct", "R=285", "seComponeDe", comp="a")
    d.arista("ct", "L=285", "t", "R=285", "utilizaIngrediente")
    d.arista("t", "B=160", "pr", "T=160", "tienePrecio")
    d.arista("hu", "L=460", "pr", "R=460", "ofrece")
    d.guardar(os.path.join(sal, "esc_2.png"))

    # E3
    d = Diagrama("esc_3", fs=10.0)
    d.obj("ar", 40, 80, "arroz : Ingrediente", ['nombre = "Arroz"', "unidad → kg", "/cantidadTotalDisponible = 8.00"], COM, w=240)
    d.obj("l", 400, 30, "loteArroz : Lote", ['identificadorLote = "ARR-001"', "fechaEntrada = 28/10/2026 09:00",
                                             "fechaCaducidad = 28/10/2027 09:00", "fresco = false",
                                             "aptoParaConsumo = true", "/cantidad = 8.00"], INV, w=265)
    d.obj("e", 810, 25, "entradaArroz : MovimientoStock", ["tipo = ENTRADA", "cantidad = 10.00", "fechaMovimiento = 28/10/2026 09:00",
                                                          "finalidadSalida = sin valor"], INV, w=275)
    d.obj("s", 810, 190, "salidaMerma : MovimientoStock", ["tipo = SALIDA", "cantidad = 2.00", "fechaMovimiento = 29/10/2026 10:00",
                                                          "finalidadSalida = MERMA"], INV, w=275)
    d.obj("m", 400, 250, "mermaArroz : Merma", ["cantidadDesperdiciada = 2.00", "fechaMerma = 29/10/2026 10:00", "motivo = DETERIORO",
                                                'detalleMotivo = "Envase roto y derrame"', "costePerdida = 4.00 €"], INV, w=280)
    d.arista("ar", "R=120", "l", "L=120", "tieneLote")
    d.arista("l", "R=75", "e", "L=75", "recibeMovimiento")
    d.arista("l", "R=150", "s", "L=225", "recibeMovimiento", hvh=740, nombre_en=(740, 186))
    d.arista("m", "T=530", "l", "B=530", "afectaLote")
    d.arista("m", "R=285", "s", "L=285", "originaSalida")
    d.guardar(os.path.join(sal, "esc_3.png"))

    # E4
    d = Diagrama("esc_4", fs=10.0)
    d.obj("le", 40, 70, "lechuga : Ingrediente", ['nombre = "Lechuga"', "unidad → kg"], COM, w=200)
    d.obj("l", 370, 30, "loteLechuga : Lote", ['identificadorLote = "LEC-001"', "fechaEntrada = 26/10/2026 10:00",
                                               "fechaCaducidad = 05/11/2026 10:00", "fresco = true", "aptoParaConsumo = true",
                                               "/cantidad = 3.00"], INV, w=280)
    d.obj("s", 370, 270, "salidaPropuesta : MovimientoStock", ["tipo = SALIDA", "cantidad = 0.20", "fechaMovimiento = 29/10/2026 10:00",
                                                              "finalidadSalida = ELABORACION"], INV, w=280, rojo=True)
    d.obj("en", 830, 275, "ensalada : Plato", ['nombre = "Ensalada verde"', "menuDelDia = true", "estado = ACTIVO"], ELA, w=200)
    d.arista("le", "R=105", "l", "L=105", "tieneLote")
    d.arista("l", "B", "s", "T", "recibeMovimiento · PROPUESTO", rojo=True)
    d.arista("s", "R=325", "en", "L=325", "seDestinaA · PROPUESTO", rojo=True)
    d.nota(720, 60, 300, "Entrada 26/10/2026 10:00 + 72 h = 29/10/2026 10:00. El instante límite está incluido en la "
                         "prohibición: el intento se rechaza y el saldo sigue en 3 kg.", titulo="RN-03: rechazo")
    d.guardar(os.path.join(sal, "esc_4.png"))

    # E5
    d = Diagrama("esc_5", fs=10.0)
    d.obj("la", 40, 130, "lasana : Plato", ['nombre = "Lasaña"', "precioVenta = 10.00 €", "/costeProduccion = 4.00 €", "estado = ACTIVO"], ELA, w=230)
    d.obj("pr", 480, 30, "pruebaLasana : PeriodoOferta", ["tipo = SUGERENCIA_CHEF", "fechaInicio = 01/10/2026 12:00", "fechaFin = 15/10/2026 12:00"], OFE, w=265)
    d.obj("ca", 480, 190, "cartaLasana : PeriodoOferta", ["tipo = CARTA_PERMANENTE", "fechaInicio = 15/10/2026 12:00", "fechaFin = sin valor"], OFE, w=265)
    d.obj("au", 480, 350, "aprobacionLasana : AutorizacionCarta", ["fechaAutorizacion = 15/10/2026 11:00", "costeEvaluado = 4.00 €", "precioVentaEvaluado = 10.00 €"], OFE, w=300)
    d.obj("an", 40, 370, "ana : Usuario", ['nombre = "Ana"', "estado = ACTIVO"], ACC, w=230)
    d.obj("ro", 40, 510, "rolAdmin : Rol", ["nombre = ADMINISTRADOR"], ACC, w=230)
    d.arista("la", "R=170", "pr", "L=75", "tienePeriodoOferta", hvh=320, nombre_en=(400, 75))
    d.arista("la", "R=210", "ca", "L=240", "tienePeriodoOferta", hvh=320, nombre_en=(400, 240))
    d.arista("ca", "B=610", "au", "T=610", "tieneAutorizacion")
    d.arista("an", "R=410", "au", "L=410", "emite")
    d.arista("an", "B", "ro", "T", "tieneRol")
    d.guardar(os.path.join(sal, "esc_5.png"))


# ==================================================================== MR
T_ROLES = [("PK", "id_rol : ID"), ("AK", "nombre : TipoRol")]
T_PERMISOS = [("PK", "id_permiso : ID"), ("AK", "nombre : TextoCorto")]
T_USUARIOS = [("PK", "id_usuario : ID"), ("", "nombre : TextoCorto"), ("AK", "correo_electronico : Correo"),
              ("", "contrasena_protegida : Hash"), ("", "estado : EstadoRegistro"), ("", "fecha_creacion : Instante"),
              ("FK", "id_rol : ID")]
T_ROLES_PERMISOS = [("PK FK", "id_rol : ID"), ("PK FK", "id_permiso : ID")]
T_PERM_AD = [("PK FK", "id_usuario : ID"), ("PK FK", "id_permiso : ID")]
T_UNIDADES = [("PK", "codigo : CodigoUnidad"), ("AK", "nombre : TextoCorto"), ("", "magnitud : TipoMagnitud"),
              ("", "factor_a_base : Factor")]
T_PROVEEDORES = [("PK", "id_proveedor : ID"), ("AK", "nombre : TextoCorto"), ("", "persona_contacto ? : TextoCorto"),
                 ("", "telefono ? : Telefono"), ("", "correo_contacto ? : Correo"), ("", "forma_pago : TextoCorto"),
                 ("", "estado : EstadoRegistro")]
T_INGREDIENTES = [("PK", "id_ingrediente : ID"), ("AK", "nombre : TextoCorto"), ("", "categoria : TextoCorto"),
                  ("FK", "unidad_medida : CodigoUnidad"), ("", "estado : EstadoRegistro")]
T_PRECIOS = [("PK", "id_precio_compra : ID"), ("FK AK", "id_proveedor : ID"), ("FK AK", "id_ingrediente : ID"),
             ("AK", "fecha_inicio_vigencia : Instante"), ("", "precio_compra : PrecioPositivo"),
             ("FK", "unidad_precio : CodigoUnidad"), ("", "fecha_fin_vigencia ? : Instante"),
             ("", "seleccionado_para_costeo : Booleano")]
T_RECETAS = [("PK", "id_receta : ID"), ("AK", "nombre : TextoCorto"), ("", "cantidad_rendimiento : CantidadPositiva"),
             ("FK", "unidad_rendimiento : CodigoUnidad"), ("", "estado : EstadoRegistro")]
T_PLATOS = [("PK", "id_plato : ID"), ("FK AK", "id_receta : ID"), ("AK", "nombre : TextoCorto"), ("", "imagen ? : Ruta"),
            ("", "descripcion : Texto"), ("", "categoria : TextoCorto"), ("", "menu_del_dia : Booleano"),
            ("", "precio_venta ? : ImportePositivo"), ("", "estado : EstadoRegistro"),
            ("", "porcentaje_margen_objetivo ? : Porcentaje")]
T_COMPONENTES = [("PK", "id_componente : ID"), ("FK AK", "id_receta : ID"), ("", "cantidad : CantidadPositiva"),
                 ("FK", "unidad_medida : CodigoUnidad"), ("FK AK", "id_ingrediente ? : ID"),
                 ("FK AK", "id_receta_componente ? : ID")]
T_LOTES = [("PK", "id_lote : ID"), ("AK", "identificador_lote : TextoCorto"), ("FK", "id_ingrediente : ID"),
           ("", "fecha_entrada : Instante"), ("", "fecha_caducidad ? : Instante"), ("", "ubicacion_almacen : TextoCorto"),
           ("", "fresco : Booleano"), ("", "apto_para_consumo : Booleano")]
T_MOV = [("PK", "id_movimiento : ID"), ("FK", "id_lote : ID"), ("", "tipo : TipoMovimiento"), ("", "cantidad : CantidadFirmada"),
         ("", "fecha_movimiento : Instante"), ("", "finalidad_salida ? : FinalidadSalida"), ("FK", "id_plato_destino ? : ID")]
T_MERMAS = [("PK", "id_merma : ID"), ("", "cantidad_desperdiciada : CantidadPositiva"), ("", "fecha_merma : Instante"),
            ("", "motivo : MotivoMerma"), ("", "detalle_motivo ? : Texto"), ("", "coste_perdida ? : ImporteNoNegativo"),
            ("FK", "id_lote ? : ID"), ("FK", "id_plato ? : ID"), ("FK AK", "id_movimiento ? : ID")]
T_PERIODOS = [("PK", "id_periodo_oferta : ID"), ("FK AK", "id_plato : ID"), ("AK", "fecha_inicio : Instante"),
              ("", "tipo : TipoOferta"), ("", "fecha_fin ? : Instante")]
T_AUT = [("PK", "id_autorizacion : ID"), ("FK AK", "id_periodo_oferta : ID"), ("FK", "id_emisor : ID"),
         ("", "fecha_autorizacion : Instante"), ("", "coste_evaluado : ImporteNoNegativo"),
         ("", "precio_venta_evaluado : ImportePositivo")]


def solo_claves(filas):
    return [f for f in filas if f[0].startswith(("PK", "FK"))]


def mr_global(sal):
    d = Diagrama("mr_global", fs=9.6)
    d.tabla("roles", 40, 60, "roles", solo_claves(T_ROLES), ACC, w=180)
    d.tabla("rp", 40, 175, "roles_permisos", solo_claves(T_ROLES_PERMISOS), ACC, w=180)
    d.tabla("permisos", 40, 305, "permisos", solo_claves(T_PERMISOS), ACC, w=180)
    d.tabla("usuarios", 310, 60, "usuarios", solo_claves(T_USUARIOS), ACC, w=240)
    d.tabla("pa", 310, 305, "permisos_adicionales_usuario", solo_claves(T_PERM_AD), ACC, w=240)
    d.tabla("aut", 310, 470, "autorizaciones_carta", solo_claves(T_AUT), OFE, w=240)
    d.tabla("per", 310, 625, "periodos_oferta", solo_claves(T_PERIODOS), OFE, w=240)
    d.tabla("platos", 680, 60, "platos", solo_claves(T_PLATOS), ELA, w=250)
    d.tabla("recetas", 680, 215, "recetas", solo_claves(T_RECETAS), ELA, w=250)
    d.tabla("comp", 680, 375, "componentes_receta", solo_claves(T_COMPONENTES), ELA, w=250)
    d.tabla("uni", 680, 640, "unidades_medida", solo_claves(T_UNIDADES), UNI, w=250)
    d.tabla("mov", 1050, 60, "movimientos_stock", solo_claves(T_MOV), INV, w=220)
    d.tabla("mermas", 1370, 60, "mermas", solo_claves(T_MERMAS), INV, w=220)
    d.tabla("lotes", 1190, 275, "lotes", solo_claves(T_LOTES), INV, w=250)
    d.tabla("ing", 1190, 450, "ingredientes", solo_claves(T_INGREDIENTES), COM, w=250)
    d.tabla("precios", 1190, 625, "precios_compra", solo_claves(T_PRECIOS), COM, w=250)
    d.tabla("prov", 1520, 655, "proveedores", solo_claves(T_PROVEEDORES), COM, w=170)
    d.grupo("Acceso y permisos", ["roles", "permisos", "usuarios", "rp", "pa"], ACC)
    d.grupo("Oferta y autorización", ["aut", "per"], OFE)
    d.grupo("Platos y recetas", ["platos", "recetas", "comp"], ELA, extra=(0, 0, 40, 0))
    d.grupo("Lotes, stock y mermas", ["mov", "mermas", "lotes"], INV)
    d.grupo("Compras", ["ing", "precios", "prov"], COM)
    fk = dict(flecha=True)
    d.arista("usuarios", "L=95", "roles", "R=95", **fk)
    d.arista("rp", "T", "roles", "B", **fk)
    d.arista("rp", "B", "permisos", "T", **fk)
    d.arista("pa", "L=340", "permisos", "R=340", **fk)
    d.arista("pa", "T=430", "usuarios", "B=430", **fk)
    d.arista("aut", "R=505", "usuarios", "R=110", hvh=596, **fk)
    d.arista("per", "R=660", "platos", "L=115", hvh=622, **fk)
    d.arista("aut", "B=430", "per", "T=430", **fk)
    d.arista("platos", "B=805", "recetas", "T=805", **fk)
    d.arista("comp", "T=805", "recetas", "B=805", **fk)
    d.arista("comp", "R=415", "recetas", "R=255", hvh=962, **fk)
    d.arista("comp", "R=478", "ing", "L=478", **fk)
    d.arista("comp", "B=805", "uni", "T=805", **fk)
    d.arista("recetas", "L=265", "uni", "L=675", hvh=650, **fk)
    d.arista("ing", "L=505", "uni", "R=660", hvh=1110, **fk)
    d.arista("precios", "L=705", "uni", "R=682", hvh=1140, **fk)
    d.arista("precios", "T=1315", "ing", "B=1315", **fk)
    d.arista("precios", "R=690", "prov", "L=690", **fk)
    d.arista("lotes", "B=1315", "ing", "T=1315", **fk)
    d.arista("mov", "B=1160", "lotes", "T=1250", vhv=225, **fk)
    d.arista("mov", "L=115", "platos", "R=115", **fk)
    d.arista("mermas", "L=115", "mov", "R=115", **fk)
    d.arista("mermas", "B=1480", "lotes", "T=1380", vhv=225, **fk)
    d.arista("mermas", "T", "platos", "T=908", vhv=30, **fk)
    d.guardar(os.path.join(sal, "mr_global.png"))


def mr_vistas(sal):
    fk = dict(flecha=True)
    # Acceso
    d = Diagrama("mr_acceso", fs=10.0)
    d.tabla("roles", 40, 40, "roles", T_ROLES, ACC, w=220)
    d.tabla("rp", 40, 175, "roles_permisos", T_ROLES_PERMISOS, ACC, w=220)
    d.tabla("permisos", 40, 310, "permisos", T_PERMISOS, ACC, w=220)
    d.tabla("usuarios", 400, 40, "usuarios", T_USUARIOS, ACC, w=320)
    d.tabla("pa", 400, 310, "permisos_adicionales_usuario", T_PERM_AD, ACC, w=320)
    d.arista("usuarios", "L=78", "roles", "R=78", **fk)
    d.arista("rp", "T", "roles", "B", **fk)
    d.arista("rp", "B", "permisos", "T", **fk)
    d.arista("pa", "T=560", "usuarios", "B=560", **fk)
    d.arista("pa", "L=350", "permisos", "R=350", **fk)
    d.guardar(os.path.join(sal, "mr_acceso.png"))
    # Compras
    d = Diagrama("mr_compras", fs=10.0)
    d.tabla("prov", 40, 40, "proveedores", T_PROVEEDORES, COM, w=340)
    d.tabla("prec", 40, 270, "precios_compra", T_PRECIOS, COM, w=340)
    d.tabla("ing", 520, 40, "ingredientes", T_INGREDIENTES, COM, w=320)
    d.tabla("uni", 520, 270, "unidades_medida", T_UNIDADES, UNI, w=320)
    d.arista("prec", "T=210", "prov", "B=210", **fk)
    d.arista("prec", "R=325", "ing", "L=115", hvh=450, **fk)
    d.arista("prec", "R=375", "uni", "L=330", hvh=485, **fk)
    d.arista("ing", "B=680", "uni", "T=680", **fk)
    d.guardar(os.path.join(sal, "mr_compras.png"))
    # Recetas
    d = Diagrama("mr_recetas", fs=10.0)
    d.tabla("pl", 40, 40, "platos", T_PLATOS, ELA, w=350)
    d.tabla("re", 500, 40, "recetas", T_RECETAS, ELA, w=340)
    d.tabla("co", 500, 235, "componentes_receta", T_COMPONENTES, ELA, w=340)
    d.tabla("un", 500, 450, "unidades_medida [referencia]", solo_claves(T_UNIDADES), UNI, w=340)
    d.tabla("in", 980, 300, "ingredientes [referencia]", solo_claves(T_INGREDIENTES), COM, w=270)
    d.arista("pl", "R=95", "re", "L=95", **fk)
    d.arista("co", "T=620", "re", "B=620", **fk)
    d.arista("co", "R=280", "re", "R=120", hvh=910, **fk)
    d.arista("co", "R=345", "in", "L=345", **fk)
    d.arista("co", "B=670", "un", "T=670", **fk)
    d.arista("re", "L=150", "un", "L=485", hvh=450, **fk)
    d.guardar(os.path.join(sal, "mr_recetas.png"))
    # Inventario
    d = Diagrama("mr_inventario", fs=10.0)
    d.tabla("lo", 40, 40, "lotes", T_LOTES, INV, w=340)
    d.tabla("mo", 520, 40, "movimientos_stock", T_MOV, INV, w=340)
    d.tabla("me", 40, 275, "mermas", T_MERMAS, INV, w=340)
    d.tabla("pl", 520, 370, "platos [referencia]", solo_claves(T_PLATOS), ELA, w=240)
    d.tabla("in", 980, 60, "ingredientes [referencia]", solo_claves(T_INGREDIENTES), COM, w=270)
    d.arista("mo", "L=100", "lo", "R=100", **fk)
    d.arista("me", "T=210", "lo", "B=210", **fk)
    d.arista("me", "R=320", "mo", "B=600", **fk)
    d.arista("me", "R=410", "pl", "L=410", **fk)
    d.arista("mo", "B=700", "pl", "T=700", **fk)
    d.arista("lo", "T=210", "in", "T=1115", vhv=16, **fk)
    d.guardar(os.path.join(sal, "mr_inventario.png"))
    # Oferta
    d = Diagrama("mr_oferta", fs=10.0)
    d.tabla("pe", 40, 40, "periodos_oferta", T_PERIODOS, OFE, w=320)
    d.tabla("au", 40, 240, "autorizaciones_carta", T_AUT, OFE, w=320)
    d.tabla("pl", 500, 60, "platos [referencia]", solo_claves(T_PLATOS), ELA, w=240)
    d.tabla("us", 500, 270, "usuarios [referencia]", solo_claves(T_USUARIOS), ACC, w=240)
    d.arista("pe", "R=100", "pl", "L=100", **fk)
    d.arista("au", "T=200", "pe", "B=200", **fk)
    d.arista("au", "R=310", "us", "L=310", **fk)
    d.guardar(os.path.join(sal, "mr_oferta.png"))


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    sal = sys.argv[1] if len(sys.argv) > 1 else os.path.join(base, "..", "memoria", "img")
    sal = os.path.abspath(sal)
    mc_global(sal)
    mc_vistas(sal)
    escenarios(sal)
    mr_global(sal)
    mr_vistas(sal)
    print("Diagramas generados en", sal, "con fuente", FAMILIA)


if __name__ == "__main__":
    main()
