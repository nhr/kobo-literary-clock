#!/usr/bin/env python3
"""Generate literary clock images for the Kobo Clara HD.

Reads litclock_annotated.csv and produces grayscale PNG images (1072x1448)
for each quote, with the time-reference phrase highlighted in bold.
Also generates metadata variants with book title and author credits.

Based on the original PHP implementation by Jaap Meijers, 2018.

Usage:
    python3 quote_to_image.py
"""

import csv
import os
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Kobo Clara HD: 1072 x 1448 at 300ppi (portrait)
WIDTH = 1072
HEIGHT = 1448
MARGIN = 46
LINE_SPACING_RATIO = 1.618  # golden ratio
CREDITS_RESERVED = 180  # pixels reserved at bottom for credits
CREDITS_MAX_WIDTH = 900  # wrap credits to two lines above this
CREDITS_FONT_SIZE = 32
MIN_FONT_SIZE = 32

SCRIPT_DIR = Path(__file__).parent
FONT_REGULAR = str(SCRIPT_DIR / "LinLibertine_RZ.ttf")
FONT_BOLD = str(SCRIPT_DIR / "LinLibertine_RB.ttf")
FONT_ITALIC = str(SCRIPT_DIR / "LinLibertine_RZI.ttf")

COLOR_WHITE = 255
COLOR_GREY = 125
COLOR_BLACK = 0


def measure_text(font, text):
    """Return (width, height) of rendered text."""
    bbox = font.getbbox(text)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def try_render(words, time_start, time_count, font_size):
    """Try to render the quote at the given font size.

    Returns the Image if the text fits, or None if it overflows.
    """
    font_regular = ImageFont.truetype(FONT_REGULAR, font_size)
    font_bold = ImageFont.truetype(FONT_BOLD, font_size)

    img = Image.new("L", (WIDTH, HEIGHT), COLOR_WHITE)
    draw = ImageDraw.Draw(img)

    line_height = round(font_size * LINE_SPACING_RATIO)
    x, y = MARGIN, MARGIN

    for i, word in enumerate(words):
        if time_start <= i <= time_start + time_count:
            font = font_bold
            color = COLOR_BLACK
        else:
            font = font_regular
            color = COLOR_GREY

        w, _ = measure_text(font, word + " ")

        # single word wider than the page
        if w > WIDTH - MARGIN:
            return None

        # wrap to next line
        if x + w >= WIDTH - MARGIN:
            x = MARGIN
            y += line_height

        draw.text((x, y), word, font=font, fill=color)
        x += w

    paragraph_bottom = y
    if paragraph_bottom >= HEIGHT - CREDITS_RESERVED:
        return None

    return img


def render_quote(words, time_start, time_count):
    """Find the largest font size that fits and return the rendered image."""
    font_size = MIN_FONT_SIZE
    best = None

    while True:
        result = try_render(words, time_start, time_count, font_size)
        if result is None:
            break
        best = result
        font_size += 1

    return best


def add_credits(img, title, author):
    """Add title and author credits to the bottom-right of the image."""
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_ITALIC, CREDITS_FONT_SIZE)

    dash = "\u2014"
    credits = f"{title}, {author}"
    full_text = dash + credits

    w, h = measure_text(font, full_text)

    if w > CREDITS_MAX_WIDTH:
        # split credits into two lines, balancing length
        credit_words = credits.split(" ")
        line1 = ""
        line2 = ""
        for i in range(1, len(credit_words)):
            candidate1 = " ".join(credit_words[: len(credit_words) - i])
            candidate2 = " ".join(credit_words[len(credit_words) - i :])
            if len(candidate2) + 5 > len(candidate1):
                break
            line1 = candidate1
            line2 = candidate2

        if line1 and line2:
            w1, h1 = measure_text(font, dash + line1)
            w2, h2 = measure_text(font, line2)

            y = HEIGHT - MARGIN
            draw.text(
                (WIDTH - w1 - MARGIN, y - round(h1 * 1.1)),
                dash + line1,
                font=font,
                fill=COLOR_BLACK,
            )
            draw.text(
                (WIDTH - w2 - MARGIN, y),
                line2,
                font=font,
                fill=COLOR_BLACK,
            )
            return

    # single line, right-aligned
    draw.text(
        (WIDTH - w - MARGIN, HEIGHT - MARGIN),
        full_text,
        font=font,
        fill=COLOR_BLACK,
    )


def main():
    os.makedirs("images/metadata", exist_ok=True)

    previous_time = None
    image_number = 0

    with open(SCRIPT_DIR / "litclock_annotated.csv", newline="") as f:
        reader = csv.reader(f, delimiter="|")
        for row in reader:
            if len(row) < 5:
                continue

            time_raw = row[0]
            timestring = row[1].strip()
            quote = re.sub(r"\s+", " ", row[2]).strip()
            title = row[3].strip()
            author = row[4].strip()

            # find which words correspond to the time phrase
            words = quote.split(" ")
            before = quote.lower().split(timestring.lower())[0] if timestring else ""
            time_start = len(before.split()) if before.strip() else 0
            time_count = len(timestring.split()) - 1

            # format time as HHMM
            time_code = time_raw[:2] + time_raw[3:5]

            # track image numbering per time slot
            if time_code == previous_time:
                image_number += 1
            else:
                image_number = 0
            previous_time = time_code

            img = render_quote(words, time_start, time_count)
            if img is None:
                print(f"WARNING: could not fit quote for {time_code}_{image_number}")
                continue

            # save quote image
            quote_path = f"images/quote_{time_code}_{image_number}.png"
            img.save(quote_path)

            # save metadata variant with credits
            add_credits(img, title, author)
            credits_path = (
                f"images/metadata/quote_{time_code}_{image_number}_credits.png"
            )
            img.save(credits_path)

            print(f"Image for {time_code}_{image_number}")


if __name__ == "__main__":
    main()
