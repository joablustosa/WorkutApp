"""Gera os icones do PWA a partir de assets/icon.png.

A marca vem com fundo transparente; na tela inicial do celular isso aparece
como um borrao, entao aqui cada icone recebe fundo branco (o mesmo fundo em
que a logo oficial vive) e a marca e encaixada com a margem certa:

- icones normais: marca ocupando ~80% do quadro;
- icones "maskable": ~58%, porque o Android recorta o icone num circulo e
  tudo fora da zona segura e cortado.

Rodar com:  python tool/gen_web_icons.py
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(HERE, 'assets', 'icon.png')
ICONS_DIR = os.path.join(HERE, 'web', 'icons')
WEB_DIR = os.path.join(HERE, 'web')

BACKGROUND = (255, 255, 255, 255)


def render(size, coverage):
    """Marca centrada sobre fundo branco, ocupando `coverage` do quadro."""
    source = Image.open(SOURCE).convert('RGBA')
    box = source.getbbox() or (0, 0, *source.size)
    mark = source.crop(box)

    target = int(round(size * coverage))
    ratio = min(target / mark.width, target / mark.height)
    mark = mark.resize(
        (max(1, int(round(mark.width * ratio))),
         max(1, int(round(mark.height * ratio)))),
        Image.LANCZOS,
    )

    canvas = Image.new('RGBA', (size, size), BACKGROUND)
    canvas.alpha_composite(
        mark,
        ((size - mark.width) // 2, (size - mark.height) // 2),
    )
    return canvas


def main():
    os.makedirs(ICONS_DIR, exist_ok=True)

    outputs = [
        (os.path.join(ICONS_DIR, 'Icon-192.png'), 192, 0.80),
        (os.path.join(ICONS_DIR, 'Icon-512.png'), 512, 0.80),
        (os.path.join(ICONS_DIR, 'Icon-maskable-192.png'), 192, 0.58),
        (os.path.join(ICONS_DIR, 'Icon-maskable-512.png'), 512, 0.58),
        (os.path.join(ICONS_DIR, 'apple-touch-icon-180.png'), 180, 0.78),
        (os.path.join(WEB_DIR, 'favicon.png'), 64, 0.86),
    ]

    for path, size, coverage in outputs:
        render(size, coverage).save(path, 'PNG', optimize=True)
        print('ok', os.path.relpath(path, HERE), size)


if __name__ == '__main__':
    main()
