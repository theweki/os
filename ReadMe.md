# Setup

## Pre Install

    setfont ter-132b # HiDPI Display
    iwctl --passphrase [password] station wlan0 connect [network]

## Minimal Install

    bash <(curl -s https://raw.githubusercontent.com/theweki/os/refs/heads/main/arch/install/archinstall.sh)

## Gnome Desktop

    curl -o gnome.sh https://raw.githubusercontent.com/theweki/os/refs/heads/main/arch/desktop/gnome.sh
    chmod +x gnome.sh
    sudo ./gnome.sh

### Post Gnome Install

    Gnome Extensions - kstatusappindicatornotifier userthemes dashtodock blurmyshell clipboardindicator

## Tools

    rustup default stable
    gh auth login

    curl -o apps.sh https://raw.githubusercontent.com/theweki/os/refs/heads/main/arch/tools/apps.sh
    chmod +x apps.sh
    sudo ./apps.sh
    
    Download Idea Ultimate from official tarball

