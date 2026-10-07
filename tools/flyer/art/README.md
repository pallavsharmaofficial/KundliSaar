# Generated note backgrounds

Drop `face.png` and `reverse.png` here and the build uses them instead of the
drawn furniture in `note.py`. Anything in `art/` is picked up automatically;
remove the files to go back to the drawn version.

- **Size:** 1453 x 744 px or larger. That is 123 x 63 mm at 300 dpi, the
  printed size of one panel. Bigger is fine, smaller will look soft.
- **Aspect:** 123:63, near enough 39:20. Generate at that ratio or the image
  gets cropped to fill.
- **No text in the image.** The brand, the value, the disclaimer, the serial
  and the QR are all laid over as live vector by `build_flyer.py`, so they
  stay sharp at any size and can be changed without regenerating anything.
- Leave the **centre-left clear** on `face` (the value block sits there) and
  the **centre clear** on `reverse` (the hook line sits there).

`.gitignore` keeps the images out of the repo; they are build inputs, not
source.
