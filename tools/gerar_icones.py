"""Gera os ícones PNG do PWA (192, 512, maskable 512 e apple-touch 180).

Uso:  python tools/gerar_icones.py   (requer Pillow: pip install pillow)

Desenho: fundo coral com barras creme alternando alto/baixo — o "perfil" de um HIIT.
"""
from pathlib import Path
from PIL import Image, ImageDraw

CORAL = (194, 69, 31)
CREME = (246, 239, 228)
PASTA = Path(__file__).resolve().parent.parent / "icons"

# barras: (altura relativa) — aquecimento, tiros, desaceleração
BARRAS = [0.35, 0.55, 1.0, 0.45, 1.0, 0.45, 0.6]


def desenhar(tamanho: int, area_util: float, cantos: bool) -> Image.Image:
    escala = 4  # desenha maior e reduz, para bordas suaves
    t = tamanho * escala
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    raio = int(t * 0.22) if cantos else 0
    d.rounded_rectangle((0, 0, t - 1, t - 1), radius=raio, fill=CORAL)

    # área central onde as barras ficam (maskable precisa de margem de 20%)
    lado = t * area_util
    x0 = (t - lado) / 2
    base = (t + lado) / 2
    n = len(BARRAS)
    vao = lado * 0.06
    larg = (lado - vao * (n - 1)) / n
    for i, h in enumerate(BARRAS):
        x = x0 + i * (larg + vao)
        topo = base - lado * h
        d.rounded_rectangle((x, topo, x + larg, base), radius=int(larg * 0.3), fill=CREME)
    return img.resize((tamanho, tamanho), Image.LANCZOS)


def main() -> None:
    PASTA.mkdir(exist_ok=True)
    desenhar(192, 0.62, True).save(PASTA / "icon-192.png")
    desenhar(512, 0.62, True).save(PASTA / "icon-512.png")
    # maskable: fundo sangrado (sem cantos) e conteúdo dentro do círculo seguro
    desenhar(512, 0.5, False).save(PASTA / "icon-maskable-512.png")
    # iOS aplica a própria máscara; sem transparência
    desenhar(180, 0.6, False).convert("RGB").save(PASTA / "apple-touch-icon.png")
    print("Ícones gerados em", PASTA)


if __name__ == "__main__":
    main()
