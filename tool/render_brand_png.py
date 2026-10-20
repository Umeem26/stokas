"""Render PNG ikon/splash dari SVG di assets/brand/ lewat Chrome headless (tanpa cairo/inkscape).

  python tool/render_brand_png.py

Hasil di assets/brand/generated/ (subfolder: tidak ikut dibundel sebagai asset Flutter):
- icon-monochrome-1024.png: lapisan monochrome Android 13, posisi & skala sama dengan icon-foreground-1024.png.
- splash-mark-1152.png / splash-mark-reverse-1152.png: splash Android 12 (1152 px, tanda di dalam lingkaran 768 px).
"""
import os
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'assets' / 'brand'
OUT = BRAND / 'generated'
CHROME = os.environ.get('CHROME', r'C:\Program Files\Google\Chrome\Application\chrome.exe')
# Kotak konten tanda (tanpa padding viewBox asli 18 16 60 64): x 22..74, y 20..76.
CONTENT = (22, 20, 52, 56)


def render(svg_name, size, scale, dest, left=None, top=None, color=None):
    svg = (BRAND / svg_name).read_text(encoding='utf-8')
    svg = svg.replace('viewBox="18 16 60 64" width="60" height="64"',
                      'viewBox="{} {} {} {}" style="width:100%;height:100%;display:block"'.format(*CONTENT))
    w, h = CONTENT[2] * scale, CONTENT[3] * scale
    left = (size - w) / 2 if left is None else left
    top = (size - h) / 2 if top is None else top
    html = (f'<!doctype html><html><body style="margin:0;background:transparent;color:{color or "#000"}">'
            f'<div style="position:absolute;left:{left}px;top:{top}px;width:{w}px;height:{h}px">'
            f'{svg}</div></body></html>')
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / 'p.html'
        page.write_text(html, encoding='utf-8')
        shot = Path(tmp) / 's.png'
        subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                        '--default-background-color=00000000', f'--window-size={size},{size}', f'--screenshot={shot}',
                        page.as_uri()], check=True, capture_output=True)
        Image.open(shot).convert('RGBA').crop((0, 0, size, size)).save(dest, optimize=True)
    print(dest.relative_to(ROOT), Image.open(dest).getchannel('A').getbbox())


def main():
    OUT.mkdir(exist_ok=True)
    fg = Image.open(BRAND / 'icon-foreground-1024.png').getchannel('A').getbbox()
    print('foreground bbox', fg)
    render('stokas-mark-mono.svg', 1024, (fg[2] - fg[0]) / CONTENT[2], OUT / 'icon-monochrome-1024.png',
           left=fg[0], top=fg[1], color='#FFFFFF')
    # Diagonal tanda = 78% dari lingkaran 768 px, sama dengan proporsi tanda di ikon adaptif.
    scale = 0.78 * 768 / (CONTENT[2] ** 2 + CONTENT[3] ** 2) ** 0.5
    render('stokas-mark.svg', 1152, scale, OUT / 'splash-mark-1152.png')
    render('stokas-mark-reverse.svg', 1152, scale, OUT / 'splash-mark-reverse-1152.png')


if __name__ == '__main__':
    main()
