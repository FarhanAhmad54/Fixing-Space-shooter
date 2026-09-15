#!/usr/bin/env python3
"""Generate high-fidelity, production-grade sprite and texture assets for Starfall Vengeance.
Uses Pillow with anti-aliasing, multi-layer drawing, and lighting glows.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

ASSETS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
os.makedirs(ASSETS_DIR, exist_ok=True)

def create_glow(img, radius=4):
    """Generate a soft neon glow behind an RGBA image."""
    glow = img.copy().filter(ImageFilter.GaussianBlur(radius))
    composite = Image.new("RGBA", img.size, (0, 0, 0, 0))
    composite.paste(glow, (0, 0), glow)
    composite.paste(img, (0, 0), img)
    return composite

def draw_viper(size=(96, 96)):
    """Viper Interceptor — Sleek high-speed fighter with cyan neon accents."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w / 2, h / 2

    # Main Wings (swept back)
    draw.polygon([
        (cx, 10), (cx + 36, 75), (cx + 28, 85), (cx + 10, 72),
        (cx, 82),
        (cx - 10, 72), (cx - 28, 85), (cx - 36, 75)
    ], fill=(30, 45, 65, 255), outline=(90, 160, 240, 255), width=2)

    # Inner Wings & Armor Panels
    draw.polygon([
        (cx, 16), (cx + 20, 68), (cx + 8, 70), (cx, 76),
        (cx - 8, 70), (cx - 20, 68)
    ], fill=(50, 75, 110, 255), outline=(130, 210, 255, 255), width=1)

    # Forward Canards
    draw.polygon([(cx, 12), (cx + 14, 38), (cx, 32)], fill=(40, 60, 90, 255))
    draw.polygon([(cx, 12), (cx - 14, 38), (cx, 32)], fill=(40, 60, 90, 255))

    # Glowing Cockpit Canopy
    draw.ellipse([cx - 5, 26, cx + 5, 52], fill=(0, 240, 255, 255), outline=(220, 255, 255, 255), width=1)
    draw.ellipse([cx - 2, 30, cx + 2, 42], fill=(255, 255, 255, 220))

    # Engine Nozzles & Ion Thrusters
    draw.rectangle([cx - 8, 76, cx - 2, 84], fill=(20, 30, 45, 255), outline=(0, 200, 255, 255))
    draw.rectangle([cx + 2, 76, cx + 8, 84], fill=(20, 30, 45, 255), outline=(0, 200, 255, 255))
    draw.ellipse([cx - 7, 80, cx - 3, 88], fill=(0, 220, 255, 200))
    draw.ellipse([cx + 3, 80, cx + 7, 88], fill=(0, 220, 255, 200))

    return create_glow(img, 3)

def draw_titan(size=(108, 108)):
    """Titan Dreadnought — Heavy dual-rail fortress with amber/orange armor."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w / 2, h / 2

    # Heavy broadside armor
    draw.polygon([
        (cx - 20, 14), (cx + 20, 14),
        (cx + 42, 45), (cx + 46, 85), (cx + 24, 95), (cx, 88),
        (cx - 24, 95), (cx - 46, 85), (cx - 42, 45)
    ], fill=(45, 38, 30, 255), outline=(240, 150, 40, 255), width=2)

    # Dual Heavy Rail Cannon Barrels
    draw.rectangle([cx - 26, 8, cx - 18, 55], fill=(30, 25, 20, 255), outline=(255, 170, 50, 255), width=1)
    draw.rectangle([cx + 18, 8, cx + 26, 55], fill=(30, 25, 20, 255), outline=(255, 170, 50, 255), width=1)
    draw.ellipse([cx - 25, 6, cx - 19, 12], fill=(255, 220, 120, 255))
    draw.ellipse([cx + 19, 6, cx + 25, 12], fill=(255, 220, 120, 255))

    # Core Bridge & Reactor Grate
    draw.polygon([(cx, 32), (cx + 14, 52), (cx, 74), (cx - 14, 52)], fill=(75, 55, 35, 255), outline=(255, 180, 50, 255), width=2)
    draw.ellipse([cx - 6, 46, cx + 6, 60], fill=(255, 140, 20, 255), outline=(255, 240, 180, 255), width=1)

    # Quad Thruster Exhausts
    for ox in [-28, -14, 14, 28]:
        draw.rectangle([cx + ox - 4, 88, cx + ox + 4, 96], fill=(30, 20, 15, 255), outline=(255, 120, 20, 255))
        draw.ellipse([cx + ox - 3, 93, cx + ox + 3, 100], fill=(255, 100, 20, 220))

    return create_glow(img, 3)

def draw_spectre(size=(96, 96)):
    """Spectre Ghost — Curved stealth delta wing with violet/plasma aesthetics."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w / 2, h / 2

    # Curved stealth delta frame
    draw.polygon([
        (cx, 12), (cx + 18, 32), (cx + 42, 68), (cx + 36, 82), (cx + 16, 74),
        (cx, 84),
        (cx - 16, 74), (cx - 36, 82), (cx - 42, 68), (cx - 18, 32)
    ], fill=(35, 20, 50, 255), outline=(190, 80, 255, 255), width=2)

    # Phase Inversion Rings
    draw.arc([cx - 24, 40, cx + 24, 76], start=0, end=180, fill=(230, 130, 255, 255), width=2)
    draw.ellipse([cx - 5, 28, cx + 5, 48], fill=(160, 40, 240, 255), outline=(240, 200, 255, 255))
    draw.ellipse([cx - 2, 34, cx + 2, 42], fill=(255, 255, 255, 255))

    return create_glow(img, 3)

def draw_aegis(size=(100, 100)):
    """Aegis Carrier — Hexagonal mothership with drone hangars and emerald shields."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    cx, cy = w / 2, h / 2

    # Hexagonal Command Hull
    draw.polygon([
        (cx, 14), (cx + 34, 30), (cx + 40, 70), (cx + 18, 88),
        (cx - 18, 88), (cx - 40, 70), (cx - 34, 30)
    ], fill=(20, 45, 45, 255), outline=(40, 240, 180, 255), width=2)

    # Sponson Drone Bays
    draw.rectangle([cx - 36, 42, cx - 22, 64], fill=(10, 30, 30, 255), outline=(60, 255, 200, 255), width=1)
    draw.rectangle([cx + 22, 42, cx + 36, 64], fill=(10, 30, 30, 255), outline=(60, 255, 200, 255), width=1)
    draw.ellipse([cx - 31, 50, cx - 27, 56], fill=(0, 255, 190, 255))
    draw.ellipse([cx + 27, 50, cx + 31, 56], fill=(0, 255, 190, 255))

    # Core Emitter
    draw.polygon([(cx, 32), (cx + 12, 48), (cx, 64), (cx - 12, 48)], fill=(30, 70, 65, 255), outline=(100, 255, 220, 255), width=2)
    draw.ellipse([cx - 5, 43, cx + 5, 53], fill=(80, 255, 210, 255))

    return create_glow(img, 3)

def draw_swarmer(size=(48, 48)):
    """Fast crimson arrowhead raider."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    draw.polygon([(cx, 4), (cx + 18, 42), (cx, 34), (cx - 18, 42)], fill=(90, 20, 25, 255), outline=(255, 70, 70, 255), width=2)
    draw.ellipse([cx - 4, 18, cx + 4, 26], fill=(255, 180, 70, 255))
    return create_glow(img, 2)

def draw_sniper(size=(56, 56)):
    """Emerald railgun needle ship."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    # Extended barrel
    draw.rectangle([cx - 2, 2, cx + 2, 26], fill=(20, 70, 40, 255), outline=(80, 255, 130, 255))
    draw.polygon([(cx, 16), (cx + 20, 48), (cx, 40), (cx - 20, 48)], fill=(20, 50, 35, 255), outline=(70, 240, 120, 255), width=2)
    draw.ellipse([cx - 4, 24, cx + 4, 32], fill=(120, 255, 170, 255))
    return create_glow(img, 2)

def draw_bomber(size=(64, 64)):
    """Bulky orange heavy munitions ship."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    draw.polygon([
        (cx - 10, 8), (cx + 10, 8), (cx + 26, 44), (cx + 18, 56),
        (cx - 18, 56), (cx - 26, 44)
    ], fill=(80, 45, 15, 255), outline=(255, 160, 30, 255), width=2)
    draw.ellipse([cx - 16, 28, cx - 6, 38], fill=(255, 210, 40, 255))
    draw.ellipse([cx + 6, 28, cx + 16, 38], fill=(255, 210, 40, 255))
    draw.rectangle([cx - 6, 22, cx + 6, 42], fill=(40, 25, 10, 255), outline=(255, 190, 50, 255))
    return create_glow(img, 2)

def draw_turret(size=(58, 58)):
    """Rotating purple/violet ring drone."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(40, 20, 60, 255), outline=(190, 80, 255, 255), width=2)
    # Radial gun pods
    for a in [0, math.pi/2, math.pi, math.pi * 1.5]:
        gx = cx + math.cos(a) * 22
        gy = cy + math.sin(a) * 22
        draw.ellipse([gx - 4, gy - 4, gx + 4, gy + 4], fill=(240, 140, 255, 255))
    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(180, 50, 240, 255), outline=(255, 220, 255, 255))
    return create_glow(img, 2)

def draw_boss(size=(140, 140)):
    """Colossal dreadnought flagship."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2

    # Main armored command hull
    draw.polygon([
        (cx, 10), (cx + 26, 24), (cx + 58, 62), (cx + 64, 110),
        (cx + 34, 126), (cx, 115),
        (cx - 34, 126), (cx - 64, 110), (cx - 58, 62), (cx - 26, 24)
    ], fill=(40, 20, 35, 255), outline=(255, 60, 120, 255), width=3)

    # Heavy frontal beam emitters
    draw.polygon([(cx - 16, 12), (cx - 8, 48), (cx - 24, 48)], fill=(70, 25, 45, 255), outline=(255, 100, 160, 255), width=1)
    draw.polygon([(cx + 16, 12), (cx + 8, 48), (cx + 24, 48)], fill=(70, 25, 45, 255), outline=(255, 100, 160, 255), width=1)

    # Core Reactor Orb
    draw.ellipse([cx - 22, 54, cx + 22, 98], fill=(255, 30, 90, 255), outline=(255, 220, 240, 255), width=2)
    draw.ellipse([cx - 10, 66, cx + 10, 86], fill=(255, 255, 255, 255))

    # Flak sponson mounts
    draw.ellipse([cx - 48, 70, cx - 36, 82], fill=(255, 90, 140, 255))
    draw.ellipse([cx + 36, 70, cx + 48, 82], fill=(255, 90, 140, 255))

    return create_glow(img, 4)

def draw_bullet(size=(24, 24), color=(100, 220, 255), shape="circle"):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    r, g, b = color
    if shape == "circle":
        draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(r, g, b, 255), outline=(255, 255, 255, 255))
    elif shape == "oval":
        draw.ellipse([cx - 4, cy - 8, cx + 4, cy + 8], fill=(r, g, b, 255), outline=(255, 255, 255, 255))
    elif shape == "beam":
        draw.rectangle([cx - 3, 2, cx + 3, size[1] - 2], fill=(r, g, b, 255), outline=(255, 255, 255, 255))
    return create_glow(img, 2)

def draw_rocket(size=(32, 48)):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = size[0] / 2
    draw.polygon([(cx, 4), (cx + 8, 20), (cx + 8, 38), (cx - 8, 38), (cx - 8, 20)], fill=(220, 220, 230, 255), outline=(255, 80, 20, 255), width=2)
    # Fins
    draw.polygon([(cx - 8, 28), (cx - 14, 40), (cx - 8, 38)], fill=(255, 60, 20, 255))
    draw.polygon([(cx + 8, 28), (cx + 14, 40), (cx + 8, 38)], fill=(255, 60, 20, 255))
    # Exhaust flame
    draw.polygon([(cx - 5, 38), (cx, 47), (cx + 5, 38)], fill=(255, 200, 40, 255))
    return create_glow(img, 2)

def draw_shield(size=(80, 80)):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    draw.ellipse([6, 6, size[0] - 6, size[1] - 6], outline=(100, 210, 255, 220), width=3)
    draw.ellipse([16, 16, size[0] - 16, size[1] - 16], fill=(50, 160, 255, 45), outline=(160, 235, 255, 180), width=1)
    return create_glow(img, 3)

def draw_fire(size=(36, 36)):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 120, 20, 220))
    draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 240, 80, 255))
    return create_glow(img, 3)

def draw_pickup(size=(40, 40), icon="heart", color=(255, 80, 100)):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] / 2, size[1] / 2
    draw.ellipse([4, 4, size[0] - 4, size[1] - 4], fill=(30, 35, 50, 240), outline=color, width=2)
    r, g, b = color
    if icon == "heart":
        draw.polygon([(cx, cy + 7), (cx + 8, cy - 2), (cx + 4, cy - 7), (cx, cy - 4), (cx - 4, cy - 7), (cx - 8, cy - 2)], fill=(r, g, b, 255))
    elif icon == "shield":
        draw.polygon([(cx, cy - 7), (cx + 7, cy - 4), (cx + 5, cy + 6), (cx, cy + 9), (cx - 5, cy + 6), (cx - 7, cy - 4)], fill=(r, g, b, 255))
    elif icon == "time":
        draw.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=(r, g, b, 255), width=2)
        draw.line([(cx, cy), (cx, cy - 4)], fill=(r, g, b, 255), width=2)
        draw.line([(cx, cy), (cx + 4, cy)], fill=(r, g, b, 255), width=2)
    elif icon == "scrap":
        draw.polygon([(cx, cy - 8), (cx + 8, cy), (cx, cy + 8), (cx - 8, cy)], fill=(255, 215, 0, 255), outline=(255, 255, 200, 255))
    elif icon == "core":
        draw.polygon([(cx, cy - 9), (cx + 7, cy - 5), (cx + 7, cy + 5), (cx, cy + 9), (cx - 7, cy + 5), (cx - 7, cy - 5)], fill=(180, 50, 255, 255), outline=(230, 150, 255, 255), width=2)
    return create_glow(img, 2)

def draw_background(size=(512, 512)):
    """Deep space nebula background with swirling stellar gas."""
    img = Image.new("RGBA", size, (6, 10, 22, 255))
    draw = ImageDraw.Draw(img)
    # Soft nebula clouds
    for ox, oy, r, col in [
        (120, 140, 160, (20, 40, 90, 80)),
        (380, 360, 200, (60, 15, 75, 70)),
        (260, 220, 140, (10, 60, 80, 60)),
    ]:
        cloud = Image.new("RGBA", size, (0, 0, 0, 0))
        cdraw = ImageDraw.Draw(cloud)
        cdraw.ellipse([ox - r, oy - r, ox + r, oy + r], fill=col)
        cloud = cloud.filter(ImageFilter.GaussianBlur(40))
        img.paste(cloud, (0, 0), cloud)
    return img

def draw_stars(size=(512, 512), count=180, brightness=200):
    """Seamless star field texture."""
    import random
    random.seed(42)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for _ in range(count):
        x = random.randint(0, size[0] - 1)
        y = random.randint(0, size[1] - 1)
        b = random.randint(brightness - 60, brightness + 55)
        b = max(40, min(255, b))
        sz = random.choice([1, 1, 1, 2])
        col = (b, b, min(255, b + 20), b)
        if sz == 1:
            draw.point((x, y), fill=col)
        else:
            draw.ellipse([x, y, x + 1, y + 1], fill=col)
    return img

def main():
    print("Generating Starfall Vengeance production asset suite...")

    items = {
        # Ships
        "SpaceShip.png": draw_viper(),
        "ship_viper.png": draw_viper(),
        "ship_titan.png": draw_titan(),
        "ship_spectre.png": draw_spectre(),
        "ship_aegis.png": draw_aegis(),

        # Enemies & Bosses
        "SWARMERS.png": draw_swarmer(),
        "SNIPERS.png": draw_sniper(),
        "BOMBERS.png": draw_bomber(),
        "TURRET DRONES.png": draw_turret(),
        "MINI-BOSSES.png": draw_boss(),

        # Projectiles
        "bullet.png": draw_bullet((20, 20), (100, 210, 255), "circle"),
        "bullet-1.png": draw_bullet((18, 18), (255, 190, 50), "oval"),
        "bullet-2.png": draw_bullet((24, 24), (80, 255, 140), "beam"),
        "laser-1.png": draw_bullet((22, 22), (0, 240, 255), "beam"),
        "laser-2.png": draw_bullet((22, 22), (255, 70, 70), "beam"),
        "laser-3.png": draw_bullet((22, 22), (200, 80, 255), "beam"),
        "plasm.png": draw_bullet((28, 28), (255, 120, 20), "circle"),
        "rocket.png": draw_rocket(),
        "super_plasma.png": draw_bullet((36, 36), (255, 80, 220), "circle"),
        "super_arc.png": draw_bullet((32, 32), (80, 220, 255), "beam"),
        "super_vortex.png": draw_bullet((40, 40), (150, 40, 255), "circle"),
        "super_swarm.png": draw_rocket((24, 36)),

        # Shields & FX
        "shield.png": draw_shield(),
        "fire.png": draw_fire(),

        # Pickups & Currency
        "bonus_life.png": draw_pickup((36, 36), "heart", (255, 60, 90)),
        "bonus_shield.png": draw_pickup((36, 36), "shield", (60, 180, 255)),
        "bonus_time.png": draw_pickup((36, 36), "time", (255, 200, 40)),
        "scrap.png": draw_pickup((32, 32), "scrap", (255, 215, 0)),
        "core.png": draw_pickup((34, 34), "core", (200, 60, 255)),

        # Environments
        "bg.png": draw_background(),
        "Stars-A.png": draw_stars((512, 512), 220, 180),
        "Stars-B.png": draw_stars((512, 512), 120, 240),
    }

    for filename, img in items.items():
        outpath = os.path.join(ASSETS_DIR, filename)
        img.save(outpath, "PNG", optimize=True)
        print(f"  [+] {filename} ({img.size[0]}x{img.size[1]})")

    print(f"Successfully generated {len(items)} assets in {ASSETS_DIR}")

if __name__ == "__main__":
    main()
