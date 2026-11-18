"""Builds every app icon (Android, iOS, web) from the Euromed Studios mark.

The mark is the same drawing as lib/core/widgets/logo.dart (64 x 100 grid):
white shield half + gold leaves under a sound equaliser, on navy.
Run from the repo root:  python3 tools/icon/make_icons.py
Needs rsvg-convert (librsvg). No Flutter package is added for this.
"""
import json, os, subprocess, sys

NAVY, GOLD, WHITE = "#1C2B6B", "#CCAB7C", "#FFFFFF"
APP = os.path.join(os.path.dirname(__file__), "..", "..", "app")


def mark(light):
    cols, bars = [0, 13, 27, 41, 54], [2, 4, 3, 2, 3]
    rects = "".join(
        f'<rect x="{c}" y="{17.5 - j * 6}" width="10" height="3.6" fill="{light}"/>'
        for c, n in zip(cols, bars) for j in range(n))
    return (rects
            + f'<path fill="{light}" d="M0 30 L35.5 30 Q26.5 38 25.8 52 L25.8 98 Q7 97.5 0 73 Z"/>'
            + f'<path fill="{GOLD}" d="M63.5 30.5 Q40 33 39 64.5 Q47 61 63.5 52 Z"/>'
            + f'<path fill="{GOLD}" d="M63.5 67 Q41 72 39 98 Q63.5 94 63.5 73 Z"/>')


def svg(size, mark_h, bg):
    """Mark centred, mark_h = share of the canvas height it takes."""
    h = size * mark_h
    s = h / 101                      # grid is 64 wide, -1..100 high
    x, y = (size - 64 * s) / 2, (size - h) / 2 + s
    back = f'<rect width="{size}" height="{size}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}">'
            f'{back}<g transform="translate({x:.2f} {y:.2f}) scale({s:.4f})">'
            f'{mark(WHITE)}</g></svg>')


def png(path, size, mark_h, bg=NAVY):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".svg"
    open(tmp, "w").write(svg(size, mark_h, bg))
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), tmp, "-o", path], check=True)
    os.remove(tmp)
    if bg:  # App stores refuse transparency in full icons.
        subprocess.run(["convert", path, "-background", bg, "-alpha", "remove", "-alpha", "off", path], check=True)


def main():
    out = os.path.abspath(APP)
    # Master, for docs and stores.
    png(f"{out}/assets/brand/app_icon_1024.png", 1024, 0.56)

    # Android: classic square icons + adaptive icon (navy back, mark front).
    res = f"{out}/android/app/src/main/res"
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        png(f"{res}/mipmap-{name}/ic_launcher.png", px, 0.56)
        # Foreground is 108dp; keep the mark inside the 66dp safe circle.
        png(f"{res}/drawable-{name}/ic_launcher_foreground.png", px * 108 // 48, 0.5, bg=None)
    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')
    os.makedirs(f"{res}/values", exist_ok=True)
    open(f"{res}/values/ic_launcher_background.xml", "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{NAVY}</color>\n</resources>\n')

    # iOS: every size listed by the Xcode asset catalog.
    cat = f"{out}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if os.path.exists(f"{cat}/Contents.json"):
        for img in json.load(open(f"{cat}/Contents.json"))["images"]:
            if "filename" not in img:
                continue
            pt = float(img["size"].split("x")[0])
            px = round(pt * int(img["scale"].rstrip("x")))
            png(f"{cat}/{img['filename']}", px, 0.56)
    else:
        print("ios/ not found yet: iOS icons skipped", file=sys.stderr)

    # Web (also what an iPhone shows after "Add to Home Screen").
    png(f"{out}/web/favicon.png", 64, 0.62)
    for px in (192, 512):
        png(f"{out}/web/icons/Icon-{px}.png", px, 0.56)
        png(f"{out}/web/icons/Icon-maskable-{px}.png", px, 0.5)


if __name__ == "__main__":
    main()
