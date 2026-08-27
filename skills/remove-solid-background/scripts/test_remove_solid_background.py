import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


SCRIPT_PATH = Path(__file__).with_name("remove_solid_background.py")


def load_module():
    spec = importlib.util.spec_from_file_location("remove_solid_background", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class RemoveSolidBackgroundTests(unittest.TestCase):
    def test_default_settings_use_auto_detection(self):
        module = load_module()

        self.assertEqual("auto", module.DEFAULT_COLOR)
        self.assertEqual(35, module.DEFAULT_TOLERANCE)
        self.assertEqual(40, module.DEFAULT_SOFTNESS)
        self.assertEqual(1.0, module.DEFAULT_DESPILL)

    def test_apply_solid_background_makes_matching_green_transparent_and_keeps_foreground(self):
        module = load_module()
        image = Image.new("RGBA", (2, 1))
        image.putpixel((0, 0), (0, 255, 0, 255))
        image.putpixel((1, 0), (255, 0, 0, 255))

        processed = module.apply_solid_background(image, color="#00FF00")

        self.assertEqual(0, processed.getpixel((0, 0))[3])
        self.assertEqual(255, processed.getpixel((1, 0))[3])
        self.assertGreater(processed.getpixel((1, 0))[0], processed.getpixel((1, 0))[1])

    def test_apply_solid_background_softens_and_despills_green_edge_pixels(self):
        module = load_module()
        image = Image.new("RGBA", (1, 1), (90, 190, 90, 255))

        processed = module.apply_solid_background(
            image,
            color="#00FF00",
            tolerance=75,
            softness=60,
            despill=1,
        )
        pixel = processed.getpixel((0, 0))

        self.assertGreater(pixel[3], 0)
        self.assertLess(pixel[3], 255)
        self.assertLess(pixel[1], 190)

    def test_apply_solid_background_makes_matching_purple_transparent_and_keeps_foreground(self):
        module = load_module()
        image = Image.new("RGBA", (2, 1))
        image.putpixel((0, 0), (255, 0, 255, 255))
        image.putpixel((1, 0), (0, 255, 0, 255))

        processed = module.apply_solid_background(image, color="#FF00FF")

        self.assertEqual(0, processed.getpixel((0, 0))[3])
        self.assertEqual(255, processed.getpixel((1, 0))[3])

    def test_purple_background_settings_keep_character_colors_opaque(self):
        module = load_module()
        character_colors = {
            "skin": (215, 183, 165, 255),
            "light_clothing": (191, 183, 179, 255),
            "dark_hair": (104, 110, 85, 255),
        }

        for name, color in character_colors.items():
            with self.subTest(name=name):
                processed = module.apply_solid_background(
                    Image.new("RGBA", (1, 1), color),
                    color="#EC06EC",
                )

                self.assertEqual(255, processed.getpixel((0, 0))[3])

    def test_auto_detected_magenta_background_keeps_subject_interior_opaque(self):
        module = load_module()
        image = Image.new("RGBA", (7, 7), (236, 6, 236, 255))
        for y in range(2, 5):
            for x in range(2, 5):
                image.putpixel((x, y), (215, 183, 165, 255))
        image.putpixel((3, 3), (191, 183, 179, 255))

        processed = module.apply_solid_background(image)

        self.assertEqual(0, processed.getpixel((0, 0))[3])
        self.assertEqual(255, processed.getpixel((2, 2))[3])
        self.assertEqual(255, processed.getpixel((3, 3))[3])

    def test_apply_solid_background_despills_both_purple_edge_channels(self):
        module = load_module()
        image = Image.new("RGBA", (1, 1), (210, 60, 210, 255))

        processed = module.apply_solid_background(
            image,
            color="#FF00FF",
            tolerance=35,
            softness=40,
            despill=1,
        )
        pixel = processed.getpixel((0, 0))

        self.assertGreater(pixel[3], 0)
        self.assertLess(pixel[3], 255)
        self.assertLess(pixel[0], 210)
        self.assertLess(pixel[2], 210)

    def test_despill_does_not_change_opaque_foreground_colors(self):
        module = load_module()
        samples = (
            ((0, 100, 0, 255), "#00FF00"),
            ((100, 0, 100, 255), "#FF00FF"),
        )

        for color, key_color in samples:
            with self.subTest(color=color, key_color=key_color):
                processed = module.apply_solid_background(
                    Image.new("RGBA", (1, 1), color),
                    color=key_color,
                )

                self.assertEqual(color, processed.getpixel((0, 0)))

    def test_auto_detection_removes_a_white_border_and_keeps_dark_foreground(self):
        module = load_module()
        image = Image.new("RGBA", (3, 3), (255, 255, 255, 255))
        image.putpixel((1, 1), (20, 20, 20, 255))

        processed = module.apply_solid_background(image)

        self.assertEqual(0, processed.getpixel((0, 0))[3])
        self.assertEqual(255, processed.getpixel((1, 1))[3])

    def test_auto_detected_green_screen_preserves_opaque_subject(self):
        module = load_module()
        source = Image.new("RGBA", (9, 9), (0, 255, 0, 255))
        subject_colors = (
            (40, 70, 30, 255),
            (104, 110, 85, 255),
            (191, 183, 179, 255),
            (215, 183, 165, 255),
        )
        for index, color in enumerate(subject_colors):
            source.putpixel((3 + (index % 2), 3 + (index // 2)), color)

        processed = module.apply_solid_background(source)

        self.assertEqual((0, 255, 0), module.detect_background_color(source))
        self.assertEqual(0, processed.getpixel((0, 0))[3])
        for index, color in enumerate(subject_colors):
            self.assertEqual(color, processed.getpixel((3 + (index % 2), 3 + (index // 2))))

    def test_cli_writes_transparent_png_without_modifying_source(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            source_path = temp_path / "source.png"
            output_path = temp_path / "source-transparent.png"
            source = Image.new("RGBA", (1, 1), (0, 255, 0, 255))
            source.save(source_path)

            exit_code = module.main(["--input", str(source_path), "--output", str(output_path)])

            self.assertEqual(0, exit_code)
            self.assertEqual((0, 255, 0, 255), Image.open(source_path).convert("RGBA").getpixel((0, 0)))
            self.assertEqual(0, Image.open(output_path).convert("RGBA").getpixel((0, 0))[3])

    def test_cli_supports_explicit_purple_background(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            source_path = temp_path / "source.png"
            output_path = temp_path / "source-transparent.png"
            Image.new("RGBA", (1, 1), (255, 0, 255, 255)).save(source_path)

            exit_code = module.main([
                "--input",
                str(source_path),
                "--output",
                str(output_path),
                "--color",
                "#FF00FF",
            ])

            self.assertEqual(0, exit_code)
            self.assertEqual(0, Image.open(output_path).convert("RGBA").getpixel((0, 0))[3])


if __name__ == "__main__":
    unittest.main()
