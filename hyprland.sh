#!/usr/bin/env bash

# hyprland essentials
pacman --noconfirm -S hyprland xdg-desktop-portal-hyprland qt5-wayland qt6-wayland qt6-svg qt6-declarative
pacman --noconfirm -S hyprpaper hypridle hyprlock nwg-panel nwg-look
pacman --noconfirm -S swaync polkit-gnome rofi-wayland waybar network-manager-applet blueman pavucontrol grim slurp

# hyprland utilities
pacman --noconfirm -S thunar cliphist mpv alacritty

sleep 1
