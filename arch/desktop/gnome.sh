#!/usr/bin/env bash

pacman --noconfirm -S gnome gnome-tweaks gnome-themes-extra power-profiles-daemon gnome-remote-desktop switcheroo-control

sleep 1

systemctl enable gdm.service
systemctl enable switcheroo-control.service

systemctl enable avahi-daemon.socket

sleep 2
