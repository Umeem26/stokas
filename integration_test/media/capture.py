"""Penggerak host untuk media_capture_test.dart (lihat media/manifest.md).

  python integration_test/media/capture.py android   # Pixel_9: screenshot, mode gelap, offline, rekaman
  python integration_test/media/capture.py android --name "gudang"   # hanya tes yang cocok (argumen diteruskan ke flutter test)
  python integration_test/media/capture.py brand     # Pixel_9: splash (screenrecord+ffmpeg), ikon di launcher & laci
  python integration_test/media/capture.py web       # Chrome 1440x900 dpr 2 (butuh chromedriver)
  python integration_test/media/capture.py post      # struk PDF->PNG, GIF, contact sheet, docs/screenshots

Butuh: adb, flutter, ffmpeg (post), Python + pymupdf + pillow (post). Jalankan dari akar repo.
"""
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'media' / 'raw'
DOCS = ROOT / 'docs' / 'screenshots'
PKG = 'com.umem.minimarket_pos'
DEVICE = os.environ.get('MEDIA_DEVICE', 'emulator-5554')
TEST = 'integration_test/media/media_capture_test.dart'
DEFINES = '--dart-define-from-file=integration_test/env.test.json'
FLUTTER = shutil.which('flutter') or 'flutter'



def supabase_host():
    """Host dari SUPABASE_URL di .env (untuk cek jaringan pulih; ICMP tidak jalan di NAT emulator)."""
    for line in (ROOT / '.env').read_text(encoding='utf-8').splitlines():
        if line.startswith('SUPABASE_URL='):
            return line.split('=', 1)[1].strip().strip('"').split('//')[-1].split('/')[0]
    return 'google.com'

# Set pilihan untuk README: nama di docs/screenshots -> file mentah.
SELECTION = {
    'splash': '33-umum-splash',
    'launcher-ikon': '35-umum-launcher-ikon',
    'login': '01-umum-login-kosong',
    'owner-home': '21-owner-home',
    'owner-detail-barang': '23-owner-detail-barang',
    'owner-staf': '26-owner-staf',
    'kasir-keranjang': '05-kasir-keranjang-3-item',
    'kasir-bayar': '07-kasir-bayar-tunai-uang-cepat',
    'kasir-struk': '12-kasir-sukses-struk',
    'gudang-terima': '16-gudang-terima-terisi',
    'gudang-stok': '15-gudang-stok-daftar',
    'pc-kasir': '30-pc-kasir-keranjang',
    'pc-owner-home': '31-pc-owner-home',
    'gelap-kasir-keranjang': '06-kasir-keranjang-3-item-gelap',
    'gelap-owner-detail-barang': '53-owner-detail-barang-gelap',
    'gelap-pc-owner-home': '61-pc-owner-home-gelap',
}
WEB_TIMEOUT = 8 * 60
MAX_BYTES = 250 * 1024
GIF_MAX = MAX_BYTES


def shell_cmd(args):
    """flutter.bat butuh shell di Windows; kutip argumen ber-karakter khusus cmd (mis. regex --name a|b)."""
    if os.name != 'nt':
        return args
    return ' '.join(f'"{a}"' if any(ch in a for ch in ' |&<>^') else a for a in args)


def adb(*args, **kw):
    return subprocess.run(['adb', '-s', DEVICE, *args], check=kw.pop('check', True), **kw)


def demo(command, **extra):
    args = ['shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', command]
    for k, v in extra.items():
        args += ['-e', k, v]
    adb(*args, stdout=subprocess.DEVNULL)


def demo_on():
    adb('shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1')
    demo('enter')
    demo('clock', hhmm='1200')
    demo('battery', level='100', plugged='false')
    demo('network', wifi='show', level='4', fully='true')
    demo('network', mobile='hide')
    demo('notifications', visible='false')


def demo_off():
    demo('exit')
    adb('shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '0')


def net(on):
    state = 'enable' if on else 'disable'
    adb('shell', f'svc wifi {state}; svc data {state}')
    demo('network', wifi='show' if on else 'hide', level='4', fully='true')
    if not on:
        time.sleep(3)
        return
    for _ in range(30):
        if adb('shell', 'nc', '-z', '-w', '3', supabase_host(), '443', check=False, stdout=subprocess.DEVNULL).returncode == 0:
            time.sleep(2)
            return
        time.sleep(1)
    raise RuntimeError('Jaringan emulator tidak pulih')


class Host:
    def __init__(self):
        self.recorder = None

    def run(self, cmd, arg):
        if cmd == 'shot':
            png = adb('exec-out', 'screencap', '-p', capture_output=True).stdout
            (RAW / f'{arg}.png').write_bytes(png)
            print(f'  [host] {arg}.png ({len(png) // 1024} KB)')
        elif cmd == 'night':
            adb('shell', 'cmd', 'uimode', 'night', arg, stdout=subprocess.DEVNULL)
            time.sleep(2)
        elif cmd == 'net':
            net(arg == 'on')
        elif cmd == 'rec-start':
            self.recorder = subprocess.Popen(['adb', '-s', DEVICE, 'shell', 'screenrecord', '--time-limit', '25', '--bit-rate', '8000000', '/sdcard/checkout.mp4'])
            time.sleep(1.5)
        elif cmd == 'rec-stop':
            adb('shell', 'pkill', '-INT', 'screenrecord', check=False)
            self.recorder.wait(timeout=15)
            time.sleep(1)
            adb('pull', '/sdcard/checkout.mp4', str(RAW / 'checkout.mp4'))
            adb('shell', 'rm', '/sdcard/checkout.mp4')
        elif cmd == 'pull':
            src, dest = arg.split('>')
            data = adb('exec-out', 'run-as', PKG, 'cat', src, capture_output=True).stdout
            (RAW / dest).write_bytes(data)
        elif cmd == 'note':
            with open(RAW / 'data-demo-diubah.txt', 'a', encoding='utf-8') as f:
                f.write(arg + '\n')
            print(f'  [host] DATA DEMO DIUBAH: {arg}')
        else:
            raise ValueError(cmd)


def android(extra):
    RAW.mkdir(parents=True, exist_ok=True)
    host = Host()
    demo_on()
    adb('shell', 'cmd', 'uimode', 'night', 'no', stdout=subprocess.DEVNULL)
    proc = subprocess.Popen(
        shell_cmd([FLUTTER, 'test', TEST, '-d', DEVICE, DEFINES, '-r', 'expanded', *extra]),
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace', bufsize=1,
        shell=os.name == 'nt',
    )
    try:
        for line in proc.stdout:
            sys.stdout.write(line)
            if 'MEDIA|' not in line:
                continue
            _, _seq, cmd, rest = line.strip()[line.index('MEDIA|'):].split('|', 3)
            arg, ack = rest.rsplit('|', 1)
            host.run(cmd, arg)
            adb('shell', 'run-as', PKG, 'touch', ack)
        return proc.wait()
    finally:
        if proc.poll() is None:
            proc.kill()
        net(True)
        adb('shell', 'cmd', 'uimode', 'night', 'no', stdout=subprocess.DEVNULL)
        demo_off()


SPLASH_BG = {'no': (0xF6, 0xF8, 0xFB), 'yes': (0x0B, 0x15, 0x24)}


def screencap(name):
    png = adb('exec-out', 'screencap', '-p', capture_output=True).stdout
    (RAW / f'{name}.png').write_bytes(png)
    print(f'  {name}.png ({len(png) // 1024} KB)')


def splash_frame(frames, bg):
    """Frame splash terbersih: tengah rentang terpanjang frame yang badannya >= 97% warna latar splash
    dan bagian tengahnya memuat tanda (bukan layar kosong / UI aplikasi)."""
    from PIL import Image

    def pixels(im):
        return getattr(im, 'get_flattened_data', im.getdata)()

    def is_splash(path):
        im = Image.open(path).convert('RGB')
        w, h = im.size
        body = im.crop((0, int(h * 0.08), w, int(h * 0.92))).resize((108, 200))
        px = list(pixels(body))
        near = sum(1 for p in px if max(abs(a - b) for a, b in zip(p, bg)) <= 6) / len(px)
        center = im.crop((w // 2 - 120, h // 2 - 120, w // 2 + 120, h // 2 + 120)).resize((24, 24))
        mark = sum(1 for p in pixels(center) if max(abs(a - b) for a, b in zip(p, bg)) > 40)
        return near >= 0.97 and mark >= 10

    best, run = [], []
    for f in frames:
        run = run + [f] if is_splash(f) else []
        if len(run) > len(best):
            best = run
    if not best:
        raise RuntimeError('Tidak ada frame splash')
    return best[len(best) // 2], len(best)


def brand():
    """Splash (terang/gelap) dari screenrecord + ffmpeg, lalu layar utama & laci aplikasi dengan ikon Stokas."""
    import tempfile

    RAW.mkdir(parents=True, exist_ok=True)
    demo_on()
    try:
        for night, suffix, n in (('no', '', 33), ('yes', '-gelap', 34)):
            adb('shell', 'cmd', 'uimode', 'night', night, stdout=subprocess.DEVNULL)
            adb('shell', 'am', 'force-stop', PKG)
            adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
            time.sleep(2)
            rec = subprocess.Popen(['adb', '-s', DEVICE, 'shell', 'screenrecord', '--time-limit', '4', '/sdcard/splash.mp4'])
            time.sleep(0.8)
            adb('shell', 'monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1', stdout=subprocess.DEVNULL)
            rec.wait(timeout=15)
            time.sleep(1)
            with tempfile.TemporaryDirectory() as tmp:
                mp4 = Path(tmp) / 'splash.mp4'
                adb('pull', '/sdcard/splash.mp4', str(mp4), stdout=subprocess.DEVNULL)
                adb('shell', 'rm', '/sdcard/splash.mp4')
                subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', str(mp4), str(Path(tmp) / 'f%03d.png')], check=True)
                frame, count = splash_frame(sorted(Path(tmp).glob('f*.png')), SPLASH_BG[night])
                dest = RAW / f'{n}-umum-splash{suffix}.png'
                shutil.copy(frame, dest)
                print(f'  {dest.name} ({frame.name}, {count} frame splash)')
            adb('shell', 'am', 'force-stop', PKG)
        for night, suffix, home_n, drawer_n in (('no', '', 35, 37), ('yes', '-gelap', 36, 38)):
            adb('shell', 'cmd', 'uimode', 'night', night, stdout=subprocess.DEVNULL)
            adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
            time.sleep(3)
            screencap(f'{home_n}-umum-launcher-ikon{suffix}')
            adb('shell', 'input', 'swipe', '540', '2000', '540', '600', '300')
            time.sleep(2)
            screencap(f'{drawer_n}-umum-laci-aplikasi-ikon{suffix}')
            adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
            time.sleep(1)
    finally:
        adb('shell', 'cmd', 'uimode', 'night', 'no', stdout=subprocess.DEVNULL)
        demo_off()


def web():
    driver = os.environ.get('CHROMEDRIVER') or shutil.which('chromedriver')
    if not driver:
        sys.exit('Set CHROMEDRIVER ke chromedriver.exe yang cocok dengan versi Chrome')
    RAW.mkdir(parents=True, exist_ok=True)
    cd = subprocess.Popen([driver, '--port=4444'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    proc = None
    try:
        time.sleep(2)
        # --release: tanpa debug service (DWDS); mode debug macet di "Waiting for connection from debug service".
        proc = subprocess.Popen(
            shell_cmd([FLUTTER, 'drive', '--release', '--driver=integration_test/media/media_driver.dart', f'--target={TEST}',
                       '-d', 'chrome', '--browser-dimension=1440x900@2', DEFINES]),
            cwd=ROOT, shell=os.name == 'nt',
        )
        return proc.wait(timeout=WEB_TIMEOUT)
    except subprocess.TimeoutExpired:
        print(f'web: batas {WEB_TIMEOUT} dtk terlewati, dihentikan')
        return 124
    finally:
        if proc and proc.poll() is None:
            subprocess.run(['taskkill', '/T', '/F', '/PID', str(proc.pid)], capture_output=True) if os.name == 'nt' else proc.kill()
        cd.kill()


def optimize_png(src, dest):
    """Kuantisasi 256 warna; perkecil bertahap sampai <= MAX_BYTES."""
    from PIL import Image

    img = Image.open(src).convert('RGB')
    width = img.width
    while True:
        scaled = img if width == img.width else img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
        scaled.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(dest, optimize=True)
        if dest.stat().st_size <= MAX_BYTES or width <= 480:
            return
        width = int(width * 0.85)


def contact_sheet(files, dest):
    from PIL import Image, ImageDraw, ImageFont

    thumb_w, cols, pad, label_h = 260, 6, 16, 28
    thumbs = []
    for f in files:
        im = Image.open(f).convert('RGB')
        thumbs.append((f.name, im.resize((thumb_w, round(im.height * thumb_w / im.width)), Image.LANCZOS)))
    rows = [thumbs[i:i + cols] for i in range(0, len(thumbs), cols)]
    heights = [max(t.height for _, t in r) + label_h for r in rows]
    sheet = Image.new('RGB', (cols * (thumb_w + pad) + pad, sum(heights) + pad * (len(rows) + 1)), 'white')
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(str(ROOT / 'assets/fonts/Inter-Regular.ttf'), 12)
    except OSError:
        font = ImageFont.load_default()
    y = pad
    for r, h in zip(rows, heights):
        for i, (name, t) in enumerate(r):
            x = pad + i * (thumb_w + pad)
            draw.text((x, y), name, fill='black', font=font)
            sheet.paste(t, (x, y + label_h - 6))
            draw.rectangle([x - 1, y + label_h - 7, x + t.width, y + label_h - 6 + t.height], outline='#999999')
        y += h + pad
    sheet.save(dest, optimize=True)


def post():
    import pymupdf

    pdfs = sorted(RAW.glob('*.pdf'))
    for pdf in pdfs:
        doc = pymupdf.open(pdf)
        doc[0].get_pixmap(dpi=203).save(pdf.with_suffix('.png'))  # 203 dpi = printer termal 80 mm
    mp4 = RAW / 'checkout.mp4'
    gif = RAW / 'checkout.gif'
    if mp4.exists():
        # Lebar/fps/warna diturunkan bertahap sampai <= GIF_MAX (batas per gambar README).
        for width, fps, colors in ((300, 8, 32), (280, 8, 24), (270, 6, 24), (260, 6, 16), (240, 5, 16)):
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(mp4), '-vf',
                            f'fps={fps},scale={width}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors={colors}:stats_mode=diff[p];'
                            '[b][p]paletteuse=dither=none:diff_mode=rectangle', '-loop', '0', str(gif)], check=True)
            if gif.stat().st_size <= GIF_MAX:
                break
        print(f'checkout.gif {gif.stat().st_size // 1024} KB')
    shots = sorted(p for p in RAW.glob('[0-9][0-9]-*.png'))
    contact_sheet([p for p in shots if not p.stem.endswith('-gelap')], RAW / 'contact-sheet-terang.png')
    contact_sheet([p for p in shots if p.stem.endswith('-gelap')], RAW / 'contact-sheet-gelap.png')
    DOCS.mkdir(parents=True, exist_ok=True)
    for old in DOCS.glob('*.png'):
        if old.stem not in SELECTION:
            old.unlink()  # set pilihan lama yang tidak dipakai lagi
    for name, src in SELECTION.items():
        dest = DOCS / f'{name}.png'
        if not (RAW / f'{src}.png').exists():
            print(f'{dest.name} dilewati: {src}.png belum ada')
            continue
        optimize_png(RAW / f'{src}.png', dest)
        print(f'{dest.name} {dest.stat().st_size // 1024} KB')
    if gif.exists():
        shutil.copy(gif, DOCS / 'checkout.gif')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace', line_buffering=True)
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    if mode not in ('android', 'brand', 'web', 'post'):
        sys.exit(__doc__)
    sys.exit((android(sys.argv[2:]) if mode == 'android' else {'brand': brand, 'web': web, 'post': post}[mode]()) or 0)
