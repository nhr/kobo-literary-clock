# Kobo Literary Clock

Turn a Kobo Clara HD into a literary clock. Instead of showing the time with numbers, it displays literary quotes that naturally reference the current time of day, with the time phrase highlighted in bold.

Touching the screen briefly shows the book title and author.

## Based On

This project is a port of the [Literary Clock Made From an E-Reader](https://www.instructables.com/Literary-Clock-Made-From-E-reader/) by **Jaap Meijers** (tjaap), originally built for the Kindle. The quote database was compiled from a 2011 [Guardian crowdsourcing effort](https://www.theguardian.com/books/booksblog/2011/apr/21/literary-clock) and Meijers' own research.

## Requirements

### Development machine (image generation)

- Python 3 with [Pillow](https://python-pillow.org/)
- [Linux Libertine](https://libertine-fonts.org/) fonts: `LinLibertine_RZ.ttf`, `LinLibertine_RB.ttf`, `LinLibertine_RZI.ttf`

### Kobo Clara HD

- [FBInk](https://github.com/NiLuJe/FBInk) — framebuffer image display (static or dynamic binary for armhf)
- [NickelMenu](https://pgaskin.net/NickelMenu/) — adds a launch entry to the Kobo UI

## Setup

### 1. Generate images

Place the three Linux Libertine `.ttf` files in this directory, then run:

```
pip install -r requirements.txt
python3 quote_to_image.py
```

This reads `litclock_annotated.csv` and generates ~2,880 grayscale PNG images (1072x1448, 300ppi) into `images/` and `images/metadata/`.

### 2. Install prerequisites on the Kobo

1. Install [NickelMenu](https://pgaskin.net/NickelMenu/) (follow its instructions).
2. Download a [FBInk release](https://github.com/NiLuJe/FBInk/releases) built for your device.

### 3. Deploy to the Kobo

Connect the Kobo via USB and copy files to create this layout:

```
/mnt/onboard/.adds/
├── nm/
│   └── nickelmenu.cfg          # from scripts/
└── timelit/
    ├── bin/
    │   └── fbink               # FBInk binary
    ├── images/                 # generated quote images
    │   └── metadata/           # quote images with title/author
    └── scripts/
        ├── clock_main.sh
        ├── showMetadata.sh
        ├── startstopClock.sh
        └── timelit.sh
```

Copy the NickelMenu config:

```
cp scripts/nickelmenu.cfg /path/to/KOBOeReader/.adds/nm/
```

Copy the app files:

```
mkdir -p /path/to/KOBOeReader/.adds/timelit/bin
mkdir -p /path/to/KOBOeReader/.adds/timelit/scripts
cp scripts/*.sh /path/to/KOBOeReader/.adds/timelit/scripts/
cp -r images /path/to/KOBOeReader/.adds/timelit/
```

Place your FBInk binary at `/path/to/KOBOeReader/.adds/timelit/bin/fbink`.

### 4. Launch

Eject and reboot the Kobo. **Literary Clock** will appear in the main menu.

## How it works

When launched from NickelMenu, the app:

1. Detaches from Nickel (the Kobo UI) via `setsid`
2. Stops Nickel and all its companion processes
3. Enters a loop: each minute, picks a random quote matching the current time and displays it via FBInk
4. On touch, briefly shows the book title and author, then reverts
5. On exit, restarts Nickel cleanly

## File overview

| File | Description |
|---|---|
| `litclock_annotated.csv` | Pipe-delimited quote database (time, time string, quote, title, author) |
| `quote_to_image.py` | Generates 1072x1448 grayscale PNGs from the quote database |
| `requirements.txt` | Python dependencies (Pillow) |
| `scripts/startstopClock.sh` | Entry point — launched by NickelMenu, starts `clock_main.sh` |
| `scripts/clock_main.sh` | Main process — manages Nickel lifecycle and runs the display loop |
| `scripts/timelit.sh` | Picks a random quote for the current minute and displays it |
| `scripts/showMetadata.sh` | Shows book title and author on touch, reverts after 3 seconds |
| `scripts/nickelmenu.cfg` | NickelMenu config to add "Literary Clock" to the Kobo menu |

## Adapting for other Kobo models

The image dimensions (1072x1448) and touch input device (`/dev/input/event1`) are specific to the Clara HD. To adapt for another model:

- Update `WIDTH` and `HEIGHT` in `quote_to_image.py` and regenerate images
- Check the correct touch input device path in `showMetadata.sh`
- Verify FBInk works on your device

## Credits

- **Jaap Meijers** (tjaap) — original [Literary Clock](https://www.instructables.com/Literary-Clock-Made-From-E-reader/) concept, quote database, and Kindle implementation
- **The Guardian** — [2011 literary clock crowdsourcing](https://www.theguardian.com/books/booksblog/2011/apr/21/literary-clock)
- **NiLuJe** — [FBInk](https://github.com/NiLuJe/FBInk)
- **pgaskin** — [NickelMenu](https://pgaskin.net/NickelMenu/)
- Nickel lifecycle management approach based on [KOReader](https://github.com/koreader/koreader)

## License

[CC BY-NC-SA 2.5](https://creativecommons.org/licenses/by-nc-sa/2.5/) — same license as the original project.
