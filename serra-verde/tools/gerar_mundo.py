#!/usr/bin/env python3
"""Gera terreno, splatmap, zonas e dados do mundo de Serra Verde a partir de dados_mapa.py.
Uso: python gerar_mundo.py [pasta_saida]
Requer: numpy scipy pillow
"""
import json, sys, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.spatial import cKDTree
from dados_mapa import *

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "../godot/assets/world")
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1921, 1111
MPP = MUNDO_LARGURA_M / 1920.0
HMIN, HMAX = -80.0, 1600.0
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

def P(x, y): return (x, y - OFFY)
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def lerp(a, b, t): return a + (b - a) * t
def gauss(a, s): return ndi.gaussian_filter(a, s)

def poly_mask(pts, blur=0.0):
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).polygon([P(*p) for p in pts], fill=255)
    m = np.asarray(im, np.float32) / 255
    return gauss(m, blur) if blur else m
def ell_mask(cx, cy, rx, ry, blur=0.0):
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).ellipse([cx - rx, cy - OFFY - ry, cx + rx, cy - OFFY + ry], fill=255)
    m = np.asarray(im, np.float32) / 255
    return gauss(m, blur) if blur else m
def line_mask(pts, width, blur=0.0):
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    d.line([P(*p) for p in pts], fill=255, width=int(max(1, width)), joint="curve")
    m = np.asarray(im, np.float32) / 255
    return gauss(m, blur) if blur else m

def noise(cell, seed_off=0):
    r = np.random.default_rng(int(rng.integers(1 << 30)) + seed_off)
    hh, ww = int(H / cell) + 4, int(W / cell) + 4
    g = r.standard_normal((hh, ww)).astype(np.float32)
    z = ndi.zoom(g, cell, order=3)[:H, :W]
    return z / (z.std() + 1e-6)
def fbm(cell, octv=4, pers=0.5):
    tot = np.zeros((H, W), np.float32); amp = 1.0; norm = 0.0
    for i in range(octv):
        tot += noise(max(cell / (2 ** i), 2.0)) * amp; norm += amp * amp; amp *= pers
    return tot / math.sqrt(norm)
def ridged(cell, octv=5):
    n = fbm(cell, octv, 0.55)
    return (1 - np.abs(n * 0.7).clip(0, 1)) ** 2

print("1/9 relevo base e montanhas")
vn = yy / (H - 1)
base = 6 + 60 * (1 - vn) ** 1.6 + 18 * fbm(300, 3)
B = np.zeros((H, W), np.float32)
for (cx, cy, r, hh) in MONTANHAS:
    B += hh * np.exp(-(((xx - cx) ** 2 + (yy - (cy - OFFY)) ** 2) / (r * r)) ** 1.6)
Bn = np.tanh(1.3 * B) / np.tanh(1.3)
mount = Bn * (140 + 1050 * ridged(120)) + Bn * 45 * fbm(30, 4)
h = base + mount + 22 * fbm(90, 3) * (0.35 + Bn)

print("2/9 mar e praias")
sea = np.zeros((H, W), np.float32)
for poly in MAR: sea = np.maximum(sea, poly_mask(poly, 1.5))
sea_bin = sea > 0.5
d_land = ndi.distance_transform_edt(~sea_bin).astype(np.float32)   # distância até o mar
d_sea = ndi.distance_transform_edt(sea_bin).astype(np.float32)
h = np.where(sea_bin, -2 - 0.4 * d_sea + 0.6 * fbm(20, 2), lerp(1.4, h, smooth(0, 16, d_land)))
h = np.clip(h, -75, None)

print("3/9 zonas planas (cidades, aeroporto)")
urban = np.zeros((H, W), np.float32)
for (nome, tipo, cx, cy, rx, ry, dens, flat) in ZONAS:
    m = ell_mask(cx, cy, rx, ry, 10)
    if tipo != "poi": urban = np.maximum(urban, m * dens)
    if flat:
        if tipo == "aeroporto":
            lvl = np.median(h[m > 0.6]); h = lerp(h, lvl, m * 0.97)
        else:
            h = lerp(h, gauss(h, 22), 0.9 * m)
air = np.zeros((H, W), np.float32)
for (a, b, w) in PISTAS: air = np.maximum(air, line_mask([a, b], w, 2))

print("4/9 estradas (perfil vertical)")
def densify(pts, step=4.0):
    pts = np.array(pts, np.float32); seg = np.hypot(*np.diff(pts, axis=0).T)
    cum = np.r_[0, np.cumsum(seg)]; n = max(2, int(cum[-1] / step))
    t = np.linspace(0, cum[-1], n)
    return np.c_[np.interp(t, cum, pts[:, 0]), np.interp(t, cum, pts[:, 1])]
roads_out = []
road_mask = np.zeros((H, W), np.float32)
road_y = np.zeros((H, W), np.float32)
for (nome, tipo, wm, pts) in ESTRADAS:
    d = densify(pts)
    cx_ = np.clip(d[:, 0], 0, W - 1); cy_ = np.clip(d[:, 1] - OFFY, 0, H - 1)
    hs = ndi.map_coordinates(h, [cy_, cx_], order=1, mode="nearest")
    hs = ndi.uniform_filter1d(hs, 9, mode="nearest"); hs = ndi.uniform_filter1d(hs, 9, mode="nearest")
    hs = np.maximum(hs, 1.8) + 0.25
    roads_out.append({"nome": nome, "tipo": tipo, "largura_m": wm,
                      "pontos": [[round(float(x * MPP), 1), round(float(y), 2), round(float((yy_ - OFFY) * MPP), 1)] for (x, yy_), y in zip(d, hs)]})
    wpx = max(2, int(wm / MPP * 1.2))
    for i in range(len(d) - 1):
        a = P(*d[i]); b = P(*d[i + 1])
        im = Image.new("L", (W, H), 0); ImageDraw.Draw(im).line([a, b], fill=255, width=wpx)
        m = np.asarray(im, np.float32) > 0
        road_y[m] = hs[i]; road_mask[m] = 1.0

print("5/9 lagos")
lagos_out = []; water_core = np.zeros((H, W), np.float32)
for lg in LAGOS:
    m = poly_mask(lg["pts"]); mb = m > 0.5
    ring = ndi.binary_dilation(mb, iterations=12) & ~ndi.binary_dilation(mb, iterations=2)
    L = float(np.median(h[ring]))
    pl = gauss(ndi.binary_dilation(mb, iterations=6).astype(np.float32), 6)
    h = lerp(h, L + 0.8, pl * 0.8)
    e = ndi.distance_transform_edt(mb).astype(np.float32)
    depth = 1.5 + 7 * (e / max(e.max(), 1))
    ms = gauss(m, 2)
    h = lerp(h, L - depth, smooth(0.35, 0.65, ms))
    water_core = np.maximum(water_core, ms)
    lagos_out.append({"nome": lg["nome"], "nivel": round(L, 2),
                      "poligono": [[round(x * MPP, 1), round((y - OFFY) * MPP, 1)] for x, y in lg["pts"]]})

print("6/9 rio")
pts = np.array([(x, y, w) for x, y, w in RIO], np.float32)
seg = np.hypot(*np.diff(pts[:, :2], axis=0).T); cum = np.r_[0, np.cumsum(seg)]
N = int(cum[-1]); tt = np.linspace(0, cum[-1], N)
rx_ = np.interp(tt, cum, pts[:, 0]); ry_ = np.interp(tt, cum, pts[:, 1]); rw_ = np.interp(tt, cum, pts[:, 2])
terr = ndi.map_coordinates(h, [np.clip(ry_ - OFFY, 0, H - 1), np.clip(rx_, 0, W - 1)], order=1, mode="nearest")
terr = ndi.uniform_filter1d(terr, 61, mode="nearest")
bed = np.minimum.accumulate(terr - 2.5)
bed = np.maximum(bed, -1.2)
bed = ndi.uniform_filter1d(bed, 15, mode="nearest")
tree = cKDTree(np.c_[rx_, ry_ - OFFY])
dist, idx = tree.query(np.c_[xx.ravel(), yy.ravel()], workers=-1)
dist = dist.reshape(H, W).astype(np.float32); idx = idx.reshape(H, W)
wpx = rw_[idx] * 0.5
bed_p = bed[idx]
target = bed_p + np.maximum(0, dist - wpx) * MPP * 0.25
vend = wpx * 2.5 + 60
k = 1 - smooth(wpx + 2, vend, dist)
h_antes = h.copy()
h2 = h - np.clip(h - target, 0, None) * k
h = np.where(dist <= wpx + 0.5, np.minimum(h, bed_p), h2)
h = gauss(h, 0.8)
# onde uma estrada cruza o rio, mantém um aterro (a estrada vira ponte/dique transitável)
rm_pre = np.clip(gauss(road_mask, 1.5) * 1.6, 0, 1)
h = lerp(h, h_antes, rm_pre)
river_core = (dist <= wpx + 1.5).astype(np.float32) * (1 - rm_pre)
rio_out = {"pontos": [[round(float(rx_[i] * MPP), 1), round(float(bed[i] + 1.6), 2), round(float((ry_[i] - OFFY) * MPP), 1), round(float(rw_[i] * MPP), 1)] for i in range(0, N, 6)]}
rio_out["pontos"].append([round(float(rx_[-1] * MPP), 1), 0.4, round(float((ry_[-1] - OFFY) * MPP), 1), round(float(rw_[-1] * MPP), 1)])

print("7/9 pântano")
sm = poly_mask(PANTANO); sb = sm > 0.5
ring = ndi.binary_dilation(sb, iterations=12) & ~ndi.binary_dilation(sb, iterations=2)
SL = float(np.median(h[ring])) - 0.3
msw = gauss(sm, 6)
h = lerp(h, SL + 0.25 * fbm(6, 2), msw)
pools = ((fbm(14, 3) > 0.25) & (msw > 0.7)).astype(np.float32)
h -= gauss(pools, 1.5) * 0.9
swamp_out = {"nivel": round(SL - 0.1, 2), "poligono": [[round(x * MPP, 1), round((y - OFFY) * MPP, 1)] for x, y in PANTANO]}

print("8/9 achatar sob estradas")
rm = np.clip(gauss(road_mask, 2.2) * 1.6, 0, 1) * (1 - np.clip(river_core * 1.5, 0, 1)) * (1 - (sea > 0.5))
ry_ok = gauss(road_y * road_mask, 2.0) / np.maximum(gauss(road_mask, 2.0), 1e-3)
h = lerp(h, np.where(road_mask > 0, road_y, ry_ok), rm * 0.92)
h += 0.7 * fbm(5, 2) * (1 - np.clip(urban + air + rm, 0, 1)) * (1 - (sea > 0.5)) * (1 - np.clip(water_core, 0, 1))
h = gauss(h, 0.6)

print("9/9 splatmap, zonas e exportação")
gy, gx = np.gradient(h, MPP); slope = np.hypot(gx, gy).astype(np.float32)
wetshore = np.maximum(smooth(14, 0, d_land) * (h < 7), gauss(np.maximum(river_core, water_core), 3) * 0.8)
fields = np.zeros((H, W), np.float32)
for poly in CAMPOS: fields = np.maximum(fields, poly_mask(poly, 3))
ring_m = ell_mask(*CAMPOS_ANEL[:2], CAMPOS_ANEL[2], CAMPOS_ANEL[2] * 0.8, 15) * (1 - ell_mask(925, 595, 85, 65, 12))
fields = np.maximum(fields, ring_m * (fbm(40, 2) > -0.3)) * (1 - np.clip(urban * 1.5, 0, 1))
meadow = poly_mask(RESERVA, 12) * (1 - smooth(500, 700, h))
sw_m = msw

w_grass = np.ones((H, W), np.float32)
w_rock = np.clip((slope - 0.75) / 0.3, 0, 1) + 0.9 * smooth(700, 950, h)
w_sand = np.clip(wetshore, 0, 1)
w_dirt = np.clip(fields * 0.9 + sw_m * 0.9 + urban * 0.7 + gauss(road_mask, 1.5) * 1.2 + air * 1.0, 0, 1.2)
S = np.stack([w_grass * 0.8, w_rock * 2.0, w_sand * 2.0, w_dirt * 1.5], -1)
S /= S.sum(-1, keepdims=True)
splat8 = (S * 255).astype(np.uint8)
Image.fromarray(splat8, "RGBA").save(OUT / "splat.png")
splat8.tofile(OUT / "splat.rgba")

alt_ok = 1 - smooth(650, 950, h)
forest = (fbm(70, 3) > -0.45).astype(np.float32)
forest = gauss(forest, 3) * alt_ok * (1 - smooth(0.5, 0.9, slope)) * (1 - np.clip(fields + urban * 1.4 + meadow + sw_m * 0.6 + wetshore + air + gauss(road_mask, 2) * 1.5, 0, 1))
forest *= 0.55 + 0.45 * smooth(1000, 300, xx * 1.0 + 0)  # mais denso no oeste
forest = np.clip(forest * 1.2, 0, 1)
zon = np.stack([forest, urban, fields, np.clip(meadow, 0, 1)], -1)
zon8 = (zon * 255).astype(np.uint8)
Image.fromarray(zon8, "RGBA").save(OUT / "zonas.png")
zon8.tofile(OUT / "zonas.rgba")

u16 = (np.clip((h - HMIN) / (HMAX - HMIN), 0, 1) * 65535).astype(np.uint16)
Image.fromarray(u16).save(OUT / "heightmap16.png")
h.astype("<f4").tofile(OUT / "heightmap.f32")

def hs_(px, py):
    return float(h[int(np.clip(py - OFFY, 0, H - 1)), int(np.clip(px, 0, W - 1))])
pois_out = [{"nome": n, "tipo": t, "x": round(px * MPP, 1), "z": round((py - OFFY) * MPP, 1), "y": round(hs_(px, py), 1)} for n, t, px, py in POIS]
zonas_out = [{"nome": n, "tipo": t, "x": round(cx * MPP, 1), "z": round((cy - OFFY) * MPP, 1), "rx": round(rx * MPP, 1), "rz": round(ry * MPP, 1), "densidade": d, "y": round(hs_(cx, cy), 1)} for (n, t, cx, cy, rx, ry, d, f) in ZONAS]
pistas_out = [{"a": [round(a[0] * MPP, 1), round((a[1] - OFFY) * MPP, 1)], "b": [round(b[0] * MPP, 1), round((b[1] - OFFY) * MPP, 1)], "largura_m": round(w * MPP, 1), "y": round(hs_((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) + 0.15, 2)} for a, b, w in PISTAS]
mundo = {"largura": W, "altura": H, "metros_por_pixel": MPP, "altura_min": HMIN, "altura_max": HMAX,
         "nivel_mar": 0.0, "tamanho_m": [round((W - 1) * MPP, 1), round((H - 1) * MPP, 1)],
         "lagos": lagos_out, "rio": rio_out, "pantano": swamp_out, "estradas": roads_out,
         "pois": pois_out, "zonas": zonas_out, "pistas": pistas_out}
(OUT / "mundo.json").write_text(json.dumps(mundo, ensure_ascii=False, indent=1))

# pré-visualização (sombreamento + cores) e sobreposição sobre a referência
ls = np.array([-1, -1, 1.2], np.float32); ls /= np.linalg.norm(ls)
nx, ny = -gx, -gy; nz = np.ones_like(nx)
nl = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2); shade = np.clip((nx * ls[0] + ny * ls[1] + nz * ls[2]) / nl, 0, 1)
col = np.zeros((H, W, 3), np.float32)
col[:] = (0.20, 0.32, 0.15)
col = np.where((forest > 0.4)[..., None], (0.09, 0.20, 0.09), col)
col = np.where((fields > 0.4)[..., None], (0.45, 0.50, 0.25), col)
col = np.where((w_rock > 0.55)[..., None], (0.50, 0.48, 0.45), col)
col = np.where((h > 950)[..., None], (0.92, 0.94, 0.96), col)
col = np.where((urban > 0.3)[..., None], (0.62, 0.60, 0.57), col)
col = np.where((sw_m > 0.5)[..., None], (0.15, 0.25, 0.22), col)
col = np.where((np.maximum(river_core, water_core) > 0.5)[..., None], (0.12, 0.35, 0.50), col)
col = np.where((sea > 0.5)[..., None], np.stack([0.03 + 0.12 * smooth(60, 0, d_sea)] * 3, -1) * (0.3, 1.0, 1.4), col)
col = np.where((road_mask > 0)[..., None], (0.85, 0.55, 0.15), col)
prev = np.clip(col * (0.45 + 0.75 * shade[..., None]), 0, 1)
Image.fromarray((prev * 255).astype(np.uint8)).save(OUT.parent.parent.parent / "tools" / "preview_terreno.png")
print("alturas: min %.1f max %.1f | tamanho %.1f x %.1f km" % (h.min(), h.max(), (W - 1) * MPP / 1000, (H - 1) * MPP / 1000))
