"""Re-brand the personal sideload build so it can't be confused with upstream.

Runs in CI on the throwaway checkout before `flutter build ios`; nothing it
touches is committed, so upstream files stay byte-identical and merges stay
clean. Only the home-screen NAME and the ICON COLOUR change. The bundle id is
left alone on purpose: changing it would make iOS treat this as a new app
with an empty database.

usage: python fork_branding.py <display name> <hue shift degrees>
"""
import pathlib
import plistlib
import sys

from PIL import Image

name, shift = sys.argv[1], int(sys.argv[2])

plist_path = pathlib.Path("ios/Runner/Info.plist")
plist = plistlib.loads(plist_path.read_bytes())
plist["CFBundleDisplayName"] = name
plist_path.write_bytes(plistlib.dumps(plist))

offset = round(shift % 360 * 255 / 360)
icons = sorted(pathlib.Path("ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("*.png"))
for icon in icons:
    img = Image.open(icon)
    alpha = img.convert("RGBA").getchannel("A")
    h, s, v = img.convert("RGB").convert("HSV").split()
    h = h.point(lambda x: (x + offset) % 256)
    out = Image.merge("HSV", (h, s, v)).convert("RGB")
    out.putalpha(alpha)
    # The App Store marketing icon must have no alpha channel.
    if img.mode != "RGBA" and "A" not in img.getbands():
        out = out.convert("RGB")
    out.save(icon)

print(f"display name -> {name!r}; hue +{shift} deg on {len(icons)} icons")
