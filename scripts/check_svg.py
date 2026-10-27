"""Check SVG diagrams: valid XML, every box has a shadow, and every text element fits its box.

Text width is estimated as len(text) * font_size * factor (0.55 regular, 0.60 bold), which is
conservative for Segoe UI / Arial. A text's container is the smallest <rect> that contains its
anchor point. Text outside any box is checked against the canvas.

Usage: python scripts/check_svg.py docs/images/*.svg
"""
import sys
import xml.etree.ElementTree as ET

NS = "{http://www.w3.org/2000/svg}"
PAD = 3


def num(el, attr, default=0.0):
    return float(el.get(attr, default))


def check(path):
    root = ET.parse(path).getroot()
    vb = [float(v) for v in root.get("viewBox").split()]
    canvas = (0, 0, vb[2], vb[3])
    rects = []
    problems = []
    for r in root.iter(NS + "rect"):
        w, h = num(r, "width"), num(r, "height")
        if w >= vb[2] and h >= vb[3] - 80:
            continue  # background
        rects.append((num(r, "x"), num(r, "y"), w, h))
        if "filter" not in r.attrib and h > 22:
            problems.append(f"box at ({num(r,'x'):.0f},{num(r,'y'):.0f}) {w:.0f}x{h:.0f} has no shadow filter")
    texts = 0
    for t in root.iter(NS + "text"):
        s = "".join(t.itertext())
        if not s.strip():
            continue
        texts += 1
        x, y, fs = num(t, "x"), num(t, "y"), num(t, "font-size", 12)
        width = len(s) * fs * (0.60 if t.get("font-weight") == "bold" else 0.55)
        anchor = t.get("text-anchor", "start")
        x0 = x - width / 2 if anchor == "middle" else (x - width if anchor == "end" else x)
        x1 = x0 + width
        inside = [b for b in rects if b[0] <= x <= b[0] + b[2] and b[1] <= y - fs * 0.4 <= b[1] + b[3]]
        box = min(inside, key=lambda b: b[2] * b[3]) if inside else canvas
        if x0 < box[0] + PAD - 0.01 or x1 > box[0] + box[2] - PAD + 0.01 or y > box[1] + box[3] - 1:
            problems.append(f'text "{s[:50]}" (~{width:.0f}px) overflows box at ({box[0]:.0f},{box[1]:.0f}) {box[2]:.0f}x{box[3]:.0f}')
    status = "PASS" if not problems else "FAIL"
    print(f"{status} {path}: {len(rects)} boxes, {texts} texts, {len(problems)} problems")
    for p in problems:
        print("   -", p)
    return not problems


if __name__ == "__main__":
    ok = all([check(p) for p in sys.argv[1:]])
    sys.exit(0 if ok else 1)
