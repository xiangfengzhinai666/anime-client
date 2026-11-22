"""从一张图生成应用图标（PNG 1024 + 七档 ICO + 各尺寸对照图）。

用法：
    python scripts/gen_icon.py "D:\\pics\\fav.jpg"
    python scripts/gen_icon.py "D:\\pics\\fav.jpg" --crop 0.84 --left 30 --top 0

依赖：Pillow（`pip install pillow`）

产出：
    assets/branding/app_icon.png             1024x1024 源图（入库）
    windows/runner/resources/app_icon.ico    16/24/32/48/64/128/256 七档
    build/icon-preview.png                   各尺寸在浅/深底上的对照图

裁切建议：
    --crop  0.80~0.90 之间，脸占比更大；1.0 为原图不裁
    --left/--top  微调裁切起点（像素），默认居中
"""
from __future__ import annotations

import argparse
import io
import os
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZES = [16, 24, 32, 48, 64, 128, 256]
ROOT = Path(__file__).resolve().parent.parent
PNG_OUT = ROOT / "assets" / "branding" / "app_icon.png"
ICO_OUT = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
PREVIEW_OUT = ROOT / "build" / "icon-preview.png"

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    "/System/Library/Fonts/PingFang.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
]


def load_font(size: int = 16):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size, index=0)
            except Exception:
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    continue
    return ImageFont.load_default()


def load_source(path: str, crop: float, left: int, top: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = int(min(w, h) * max(0.2, min(1.0, crop)))
    # 默认居中；显式给了 left/top 就按给的来（夹到合法范围）
    x = left if left else (w - side) // 2
    y = top if top else (h - side) // 2
    x = max(0, min(x, w - side))
    y = max(0, min(y, h - side))
    return im.crop((x, y, x + side, y + side)).resize((1024, 1024), Image.LANCZOS)


def render(im: Image.Image, size: int) -> Image.Image:
    out = im.resize((size, size), Image.LANCZOS)
    if size <= 64:
        # 小尺寸轻微锐化，避免缩成一团糊
        out = out.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=0))
    return out


def write_ico(im: Image.Image, path: Path) -> None:
    """手写 ICO（PNG 负载），每档都用自己重采样的结果，不交给库凑合。"""
    blobs = []
    for s in SIZES:
        buf = io.BytesIO()
        render(im, s).save(buf, format="PNG", optimize=True)
        blobs.append((s, buf.getvalue()))

    n = len(blobs)
    offset = 6 + 16 * n
    header = struct.pack("<HHH", 0, 1, n)
    entries, data = b"", b""
    for s, blob in blobs:
        dim = 0 if s >= 256 else s
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
        data += blob
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + entries + data)


def write_preview(im: Image.Image, path: Path) -> None:
    font = load_font(14)
    pad = 16
    width = pad + sum(SIZES) + 20 * len(SIZES) + pad
    band_h = 256 + pad * 2 + 22
    sheet = Image.new("RGB", (width, band_h * 2), (245, 245, 245))
    y = 0
    for bg, color in (((245, 245, 245), (25, 25, 25)), ((17, 17, 20), (230, 230, 230))):
        band = Image.new("RGB", (width, band_h), bg)
        d = ImageDraw.Draw(band)
        x = pad
        for s in SIZES:
            band.paste(render(im, s), (x, pad + (256 - s)))
            d.text((x, pad + 256 + 4), str(s), fill=color, font=font)
            x += s + 20
        sheet.paste(band, (0, y))
        y += band_h
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main() -> None:
    ap = argparse.ArgumentParser(description="生成应用图标（PNG + ICO + 对照图）")
    ap.add_argument("source", help="源图片路径")
    ap.add_argument("--crop", type=float, default=0.84, help="裁切比例 0.2~1.0，默认 0.84")
    ap.add_argument("--left", type=int, default=0, help="裁切起点 X（默认居中）")
    ap.add_argument("--top", type=int, default=0, help="裁切起点 Y（默认居中）")
    args = ap.parse_args()

    im = load_source(args.source, args.crop, args.left, args.top)
    PNG_OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(PNG_OUT, optimize=True)
    write_ico(im, ICO_OUT)
    write_preview(im, PREVIEW_OUT)

    print(f"png     : {PNG_OUT} ({PNG_OUT.stat().st_size} bytes)")
    print(f"ico     : {ICO_OUT} ({ICO_OUT.stat().st_size} bytes, sizes={SIZES})")
    print(f"preview : {PREVIEW_OUT}")
    print("下一步  : flutter build windows --release（ICO 变了必须重建 exe）")


if __name__ == "__main__":
    main()
