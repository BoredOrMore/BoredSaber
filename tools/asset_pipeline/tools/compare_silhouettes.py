#!/usr/bin/env python3
# Compare already-aligned binary silhouette images. Requires Pillow: python -m pip install pillow
import sys, json
from PIL import Image
if len(sys.argv) != 3:
    raise SystemExit('Usage: compare_silhouettes.py reference.png render.png')
def mask(path):
    im=Image.open(path).convert('L')
    return im.size, [v >= 128 for v in im.getdata()]
size_a, a = mask(sys.argv[1]); size_b, b = mask(sys.argv[2])
if size_a != size_b:
    raise SystemExit(f'Image sizes differ: {size_a} vs {size_b}; align/crop first')
inter=sum(x and y for x,y in zip(a,b)); union=sum(x or y for x,y in zip(a,b))
print(json.dumps({'reference':sys.argv[1], 'render':sys.argv[2], 'size':size_a,
                  'silhouette_iou':round(inter/union if union else 1.0,5),
                  'caveat':'Only meaningful with matching camera, crop, scale, alignment, and threshold.'}, indent=2))
