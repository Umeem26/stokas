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


def open_logged_in(browser, login, password):
    ctx = browser.new_context(viewport={'width': 1440, 'height': 900}, device_scale_factor=2, locale='id-ID')
    page = ctx.new_page()
    page.set_default_timeout(STEP_MS)
    page.goto(f'http://127.0.0.1:{PORT}/')
    page.wait_for_selector('flt-semantics-placeholder', state='attached')
    page.evaluate("document.querySelector('flt-semantics-placeholder').click()")
    page.get_by_role('textbox', name='Username atau email').click()
    page.keyboard.type(login)
    page.get_by_role('textbox', name='Password').click()
    page.keyboard.type(password)
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


def main():
    env = json.loads((ROOT / 'integration_test' / 'env.test.json').read_text(encoding='utf-8'))
    RAW.mkdir(parents=True, exist_ok=True)
    server = serve()
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(channel='chrome', headless=True)
            ctx, page = open_logged_in(browser, env['CASHIER_EMAIL'], env['CASHIER_PASSWORD'])
            wait_text(page, 'Siap scan')
            search = page.get_by_role('textbox', name='Cari nama atau scan kode')
            page.wait_for_timeout(1500)  # daftar barang dimuat
            for code in ['DEMO-05', 'DEMO-01', 'DEMO-18', 'DEMO-18']:
                search.click()
                page.keyboard.type(code)
                page.keyboard.press('Enter')
                page.wait_for_timeout(1200)
            shot(page, '30-pc-kasir-keranjang')  # tanpa bayar: data tidak berubah
            ctx.close()

            ctx, page = open_logged_in(browser, env['OWNER_EMAIL'], env['OWNER_PASSWORD'])
            wait_text(page, 'Omzet hari ini')
            wait_text(page, 'Perlu diurus')
            shot(page, '31-pc-owner-home')
            page.locator('flt-semantics[role=button]', has_text=re.compile(r'^\s*Staf\s*$')).first.click()
            wait_text(page, 'Kelola Staf')
            wait_text(page, 'Nonaktif')
            shot(page, '32-pc-owner-staf')
            ctx.close()
            browser.close()
    finally:
        server.shutdown()


if __name__ == '__main__':
    sys.exit(main())
