---
name: remove-solid-background
description: Remove solid-color backgrounds from raster images and export transparent PNGs. Use when Codex needs to process local images for AdventurerGuild assets, including requests such as 去除纯色背景, 纯色背景转透明, 去绿幕, 去紫幕, 抠绿, 抠紫, or convert a PNG/JPG/WebP with a uniform or nearly uniform background color into a transparent PNG.
---

# Remove Solid Background

Use the bundled Python CLI to remove a solid-color background from a local raster image. It detects the dominant border color automatically and also accepts an explicit key color.

Treat bright green and magenta as the primary expected screen colors. Keep regression coverage for both whenever the masking defaults change.

## Quick Start

Run from the repository root:

```powershell
python .agents\skills\remove-solid-background\scripts\remove_solid_background.py --input path\source.png --output path\source-transparent.png
```

To select the background color explicitly:

```powershell
python .agents\skills\remove-solid-background\scripts\remove_solid_background.py --input path\source.png --output path\source-transparent.png --color "#FF00FF"
```

Default settings:

- `--color auto`
- `--tolerance 35`
- `--softness 40`
- `--despill 1`

## Workflow

1. Preserve the source image. Write the result to a new `.png` file unless the user explicitly asks to overwrite.
2. During parameter tuning, use a new output filename for each revision so visual comparisons do not reuse a cached preview.
3. Use automatic border-color detection first for a uniform or nearly uniform background.
4. If detection selects the wrong color, sample the actual background and pass it as `--color "#RRGGBB"`.
5. If background-color residue remains on semi-transparent edges, increase `--tolerance` or `--despill`. Despill is limited to pixels affected by the background mask so opaque foreground colors remain unchanged.
6. If edges become too transparent, lower `--tolerance` or `--softness`.
7. Prefer output names ending in `-transparent.png` or `_transparent.png`.

## Script Options

```powershell
python .agents\skills\remove-solid-background\scripts\remove_solid_background.py `
  --input path\source.png `
  --output path\source-transparent.png `
  --color "#FF00FF" `
  --tolerance 35 `
  --softness 40 `
  --despill 1
```

The input may be any format Pillow can read. The output is always saved as PNG with an alpha channel.
