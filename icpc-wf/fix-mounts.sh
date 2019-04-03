#!/bin/bash
set -e
gsettings set org.gnome.desktop.media-handling automount false
gsettings set org.gnome.desktop.media-handling automount-open false
gsettings set org.gnome.nautilus.desktop volumes-visible false
