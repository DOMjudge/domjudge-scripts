# Preparing DOMlogo

First, create the following files:
- `images/logos/DOMjudge.png`, a 64x64 DOMjudge logo with transparent background.
- `images/photos/crew.png`, an image with a width of 1024 (and any height) to show for teams without a photo.
- `images/photos/idle.png`, an image with a width of 1024 (and any height) to show when the judgedaemon is idle.

Next, add the needed Python dependencies to the `lib` folder, within a folder called `python3.10`. You can copy this
folder from a local machine and it should contain the `FreeSimpleGUI` and `requests` Python packages.

Optionally you can create a file `images/config.yaml` with something like:

```yaml
host-bg-color: '#013370'
```

DOMlogo will use the DOMjudge API to download logos and photos for all teams, so no further configuration should be needed.
