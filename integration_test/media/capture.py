"""Penggerak host untuk media_capture_test.dart (lihat media/manifest.md).

  python integration_test/media/capture.py android   # Pixel_9: screenshot, mode gelap, offline, rekaman
  python integration_test/media/capture.py android --name "gudang"   # hanya tes yang cocok (argumen diteruskan ke flutter test)
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
    'owner-home': '21-owner-home',
    'kasir-keranjang': '05-kasir-keranjang-3-item',
    'kasir-bayar': '07-kasir-bayar-tunai-uang-cepat',
    'gudang-terima': '16-gudang-terima-terisi',
    'owner-staf': '26-owner-staf',
    'pc-kasir': '30-pc-kasir-keranjang',
    'pc-owner-home': '31-pc-owner-home',
    'pc-owner-staf': '32-pc-owner-staf',
}
WEB_TIMEOUT = 8 * 60
MAX_BYTES = 250 * 1024
GIF_MAX = 4 * 1024 * 1024


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
        for colors in (128, 64, 32):
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(mp4), '-vf',
                            f'fps=12,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors={colors}:stats_mode=diff[p];'
                            '[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle', '-loop', '0', str(gif)], check=True)
            if gif.stat().st_size <= GIF_MAX:
                break
        print(f'checkout.gif {gif.stat().st_size // 1024} KB')
    shots = sorted(p for p in RAW.glob('[0-9][0-9]-*.png'))
    contact_sheet(shots, RAW / 'contact-sheet.png')
    DOCS.mkdir(parents=True, exist_ok=True)
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
    if mode not in ('android', 'web', 'post'):
        sys.exit(__doc__)
    sys.exit((android(sys.argv[2:]) if mode == 'android' else {'web': web, 'post': post}[mode]()) or 0)
