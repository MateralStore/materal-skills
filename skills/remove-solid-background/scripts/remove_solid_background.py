import argparse
import math
from pathlib import Path

from PIL import Image


DEFAULT_COLOR = "auto"
DEFAULT_TOLERANCE = 35
DEFAULT_SOFTNESS = 40
DEFAULT_DESPILL = 1.0
COLOR_BUCKET_SIZE = 16


def apply_solid_background(
    source,
    color=DEFAULT_COLOR,
    tolerance=DEFAULT_TOLERANCE,
    softness=DEFAULT_SOFTNESS,
    despill=DEFAULT_DESPILL,
):
    image = source.convert("RGBA")
    output = Image.new("RGBA", image.size)
    source_pixels = image.load()
    output_pixels = output.load()

    target = detect_background_color(image) if color in (None, "auto") else parse_color(color)
    similarity = clamp(tolerance / 255.0, 0.0, 1.0)
    smoothness = clamp(softness / 255.0, 0.0, 1.0)
    despill_amount = clamp(float(despill), 0.0, 1.0)

    width, height = image.size
    for y in range(height):
        for x in range(width):
            pixel = source_pixels[x, y]
            distance = get_smoothed_color_distance(source_pixels, width, height, x, y, target)
            foreground_mask = calculate_foreground_mask(distance, similarity, smoothness)
            alpha = round(pixel[3] * foreground_mask)
            red, green, blue = apply_despill(
                pixel[:3],
                target,
                despill_amount * (1.0 - foreground_mask),
            )
            output_pixels[x, y] = (red, green, blue, int(clamp(alpha, 0, 255)))

    return output


def parse_color(color):
    value = color.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError(f"Color '{color}' must use #RRGGBB format.")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def detect_background_color(image):
    pixels = image.load()
    width, height = image.size
    coordinates = [(x, 0) for x in range(width)]

    if height > 1:
        coordinates.extend((x, height - 1) for x in range(width))
    if width > 1:
        coordinates.extend((0, y) for y in range(1, height - 1))
        coordinates.extend((width - 1, y) for y in range(1, height - 1))

    buckets = {}
    for x, y in coordinates:
        pixel = pixels[x, y]
        if pixel[3] <= 0:
            continue
        sample = pixel[:3]
        bucket = tuple(
            min(255 // COLOR_BUCKET_SIZE, (channel + (COLOR_BUCKET_SIZE // 2)) // COLOR_BUCKET_SIZE)
            for channel in sample
        )
        buckets.setdefault(bucket, []).append(sample)

    if not buckets:
        raise ValueError("Cannot detect a background color from a fully transparent image border.")

    dominant_samples = max(buckets.values(), key=len)
    return tuple(
        round(sum(sample[channel] for sample in dominant_samples) / len(dominant_samples))
        for channel in range(3)
    )


def get_smoothed_color_distance(pixels, width, height, x, y, target):
    center_weight = 12.0
    neighbor_weight = 0.5
    total = color_distance(pixels[x, y], target) * center_weight
    weight = center_weight

    for neighbor_x, neighbor_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        if 0 <= neighbor_x < width and 0 <= neighbor_y < height:
            total += color_distance(pixels[neighbor_x, neighbor_y], target) * neighbor_weight
            weight += neighbor_weight

    return total / weight


def color_distance(pixel, target):
    squared_distance = sum(((pixel[index] - target[index]) / 255.0) ** 2 for index in range(3))
    return math.sqrt(squared_distance / 3.0)


def calculate_foreground_mask(distance, similarity, smoothness):
    base_mask = distance - similarity
    if base_mask <= 0:
        return 0.0
    if smoothness <= 0:
        return 1.0
    return math.pow(clamp(base_mask / smoothness, 0.0, 1.0), 1.5)


def apply_despill(pixel, target, despill):
    if despill <= 0:
        return pixel

    target_minimum = min(target)
    target_vector = tuple(channel - target_minimum for channel in target)
    target_magnitude = math.sqrt(sum(channel ** 2 for channel in target_vector))
    if target_magnitude <= 0:
        return pixel

    pixel_minimum = min(pixel)
    pixel_vector = tuple(channel - pixel_minimum for channel in pixel)
    pixel_magnitude = math.sqrt(sum(channel ** 2 for channel in pixel_vector))
    if pixel_magnitude <= 0:
        return pixel

    alignment = sum(
        pixel_channel * target_channel
        for pixel_channel, target_channel in zip(pixel_vector, target_vector)
    ) / (pixel_magnitude * target_magnitude)
    influence = clamp(despill * ((alignment - 0.9) / 0.1), 0.0, 1.0)
    if influence <= 0:
        return pixel

    maximum_target_channel = max(target_vector)
    key_channels = [
        index
        for index, channel in enumerate(target_vector)
        if channel > maximum_target_channel * 0.05
    ]
    neutral_channels = [index for index in range(3) if index not in key_channels]
    neutral_level = max((pixel[index] for index in neutral_channels), default=pixel_minimum)
    output = list(pixel)

    for index in key_channels:
        if output[index] > neutral_level:
            output[index] = move_toward(output[index], neutral_level, influence)

    return tuple(output)


def move_toward(value, target, amount):
    return int(clamp(round(value + ((target - value) * amount)), 0, 255))


def clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def build_parser():
    parser = argparse.ArgumentParser(description="Remove a solid-color background and export a transparent PNG.")
    parser.add_argument("--input", required=True, help="Source image path.")
    parser.add_argument("--output", required=True, help="Output PNG path.")
    parser.add_argument(
        "--color",
        default=DEFAULT_COLOR,
        help="Background color in #RRGGBB format. Defaults to auto-detection from the image border.",
    )
    parser.add_argument("--tolerance", type=int, default=DEFAULT_TOLERANCE, help="Key tolerance, 0-255.")
    parser.add_argument("--softness", type=int, default=DEFAULT_SOFTNESS, help="Edge softness, 0-255.")
    parser.add_argument("--despill", type=float, default=DEFAULT_DESPILL, help="Color spill reduction, 0-1.")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    input_path = Path(args.input)
    output_path = Path(args.output)

    with Image.open(input_path) as source:
        processed = apply_solid_background(
            source,
            color=args.color,
            tolerance=args.tolerance,
            softness=args.softness,
            despill=args.despill,
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    processed.save(output_path, format="PNG")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
