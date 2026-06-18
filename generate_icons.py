from PIL import Image

src = Image.open("banner.png").convert("RGBA")

# Add padding (logo takes 72% of canvas, rest is transparent)
sizes = {
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

for path, size in sizes.items():
    # Create transparent canvas 1.4x bigger
    canvas_size = int(size * 1.4)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    logo = src.resize((size, size), Image.LANCZOS)
    offset = (canvas_size - size) // 2
    canvas.paste(logo, (offset, offset), logo)
    canvas.save(path)
    print(f"Saved {path}")