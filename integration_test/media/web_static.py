"""PC mode (1440x900, dpr 2) dari build release statis + Playwright; hanya membaca data (tanpa checkout).

  flutter build web --release
  python integration_test/media/web_static.py      # butuh: pip install playwright; Chrome terpasang

Alasan: `flutter drive -d chrome` (debug) macet di "Waiting for connection from debug service" dan
`--release` mengompilasi ulang dart2js tiap jalan (~5 mnt). Build statis cukup sekali; Playwright memakai Chrome
terpasang (channel chrome) dan semantics Flutter untuk memilih field/tombol lewat label.
"""
import functools
import http.server
import json
import re
import sys
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'media' / 'raw'
WEB = ROOT / 'build' / 'web'
PORT = 8091
STEP_MS = 30_000


def serve():
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass

    handler = functools.partial(Quiet, directory=str(WEB))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def open_logged_in(browser, login, password, scheme='light'):
    ctx = browser.new_context(viewport={'width': 1440, 'height': 900}, device_scale_factor=2, locale='id-ID',
                              color_scheme=scheme)
    page = ctx.new_page()
    page.set_default_timeout(STEP_MS)
    page.goto(f'http://127.0.0.1:{PORT}/')
    page.wait_for_selector('flt-semantics-placeholder', state='attached')
    page.evaluate("document.querySelector('flt-semantics-placeholder').click()")
    # Jeda setelah klik: tanpa itu huruf pertama kadang hilang sebelum field Flutter fokus.
    page.get_by_role('textbox', name='Username atau email').click()
    page.wait_for_timeout(500)
    page.keyboard.type(login, delay=30)
    page.get_by_role('textbox', name='Password').click()
    page.wait_for_timeout(500)
    page.keyboard.type(password, delay=30)
    page.keyboard.press('Enter')
    return ctx, page


def wait_text(page, text):
    """Teks Flutter ada di innerText atau aria-label node semantics (sering tergabung); get_by_text tidak andal."""
    page.wait_for_function(
        "t => Array.from(document.querySelectorAll('flt-semantics'))"
        ".some(e => ((e.getAttribute('aria-label') || '') + (e.innerText || '')).includes(t))", arg=text)


def shot(page, name):
    page.wait_for_timeout(1500)  # animasi & gambar mereda
    page.screenshot(path=str(RAW / f'{name}.png'))
    print(f'  {name}.png')


def open_tab(page, label):
    page.locator('flt-semantics[role=button]', has_text=re.compile(rf'^\s*{label}\s*$')).first.click()


def cashier_cart(browser, env, name, scheme='light'):
    ctx, page = open_logged_in(browser, env['CASHIER_EMAIL'], env['CASHIER_PASSWORD'], scheme)
    wait_text(page, 'Siap scan')
    search = page.get_by_role('textbox', name='Cari nama atau scan kode')
    page.wait_for_timeout(1500)  # daftar barang dimuat
    for code in ['DEMO-05', 'DEMO-01', 'DEMO-18', 'DEMO-18']:
        search.click()
        page.keyboard.type(code)
        page.keyboard.press('Enter')
        page.wait_for_timeout(1200)
    shot(page, name)  # tanpa bayar: data tidak berubah
    ctx.close()


def owner_home(browser, env, scheme='light'):
    ctx, page = open_logged_in(browser, env['OWNER_EMAIL'], env['OWNER_PASSWORD'], scheme)
    wait_text(page, 'Omzet hari ini')
    wait_text(page, 'Perlu diurus')
    return ctx, page


def main():
    env = json.loads((ROOT / 'integration_test' / 'env.test.json').read_text(encoding='utf-8'))
    RAW.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])  # mis. "ext": hanya 60-64
    server = serve()
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(channel='chrome', headless=True)
            if 'ext' not in only:
                cashier_cart(browser, env, '30-pc-kasir-keranjang')
                ctx, page = owner_home(browser, env)
                shot(page, '31-pc-owner-home')
                open_tab(page, 'Staf')
                wait_text(page, 'Kelola Staf')
                wait_text(page, 'Nonaktif')
                shot(page, '32-pc-owner-staf')
                ctx.close()

            # Perluasan: mode gelap (prefers-color-scheme), Riwayat, Stok, Terima. Tanpa simpan.
            cashier_cart(browser, env, '60-pc-kasir-keranjang-gelap', 'dark')
            ctx, page = owner_home(browser, env, 'dark')
            shot(page, '61-pc-owner-home-gelap')
            ctx.close()
            ctx, page = owner_home(browser, env)
            open_tab(page, 'Riwayat')
            wait_text(page, 'Riwayat Transaksi')
            wait_text(page, 'Rp')
            shot(page, '62-pc-owner-riwayat')
            open_tab(page, 'Stok')
            wait_text(page, 'Kedaluwarsa')
            shot(page, '63-pc-owner-stok')
            ctx.close()
            ctx, page = open_logged_in(browser, env['WAREHOUSE_EMAIL'], env['WAREHOUSE_PASSWORD'])
            wait_text(page, 'Belum ada barang')
            page.wait_for_timeout(1500)
            shot(page, '64-pc-gudang-terima')
            ctx.close()
            browser.close()
    finally:
        server.shutdown()


if __name__ == '__main__':
    sys.exit(main())
