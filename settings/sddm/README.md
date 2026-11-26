# Charcoal City login screen

This is a separate preset using the installed `sddm-astronaut-theme` and its Sakura login layout. The original theme stays intact. An 8 FPS clock drives opaque autumn leaves to the left at varied speeds, with upward, level and downward drift, gentle gusts and small irregular eddies near the bottom edge. Entry heights and swirl settings randomize on each re-entry. Each leaf has three tumble frames, four silhouettes, eight hues and fine pixel detail. Tower lights and the other rooftops’ red beacons fade fully dark between pulses in a six-second cycle, with staggered timing. The background is the unchanged pixel-art desktop wallpaper, rendered without smoothing. Beacon glow in the static image is covered by nearby sky samples within the QML scene. Artwork prompts are in [ARTWORK.md](ARTWORK.md).

Requires the Qt 6 SDDM greeter and Astronaut at `/usr/share/sddm/themes/sddm-astronaut-theme`. This system-wide preset is separate from the home-directory deployer and palette switcher.

The home-directory deployer also sets the pixel-art desktop wallpaper and a matching static Hyprlock background, with blur disabled. Hyprlock keeps its existing PAM authentication setup. The leaves and beacons animate in SDDM; Hyprlock uses the shared still image.

Copy the preset from the repository root:

```sh
sudo cp -r settings/sddm/charcoal-city /usr/share/sddm/themes/
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/charcoal-city
```

After checking the preview, back up `/etc/sddm.conf` and change only its `[Theme]` section's `Current` entry to `charcoal-city`. Existing DPI, input and authentication settings should remain as they are. Activation takes effect at the next login screen; restarting SDDM closes the current desktop session.

To revert, change `Current` back to `sddm-astronaut-theme`. Its selected Sakura preset is untouched.

Run the motion checks without opening desktop windows:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/qml
```
