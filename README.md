# kvmd-web-defaults

Server-side UI defaults for [PiKVM](https://pikvm.org/) — configure default settings for all users via a single CSS file.

![PiKVM Extension](https://img.shields.io/badge/PiKVM-Extension-blue)

## What it does

PiKVM's Web UI has ~18 client-side settings (confirmation dialogs, stream mode, mouse behavior, etc.) with defaults hardcoded in JavaScript. Users can change them, but admins have no way to set organization-wide defaults.

This extension lets admins configure all UI defaults server-side via CSS custom properties in `/etc/kvmd/web.css`. User preferences still override — this only changes what new users see before they customize.

## Requirements

- PiKVM with kvmd 4.140+

## Installation

Download the latest release and install:

```bash
curl -LO https://github.com/nullstacked/kvmd-web-defaults/releases/latest/download/kvmd-web-defaults-1.0.0-1-any.pkg.tar.zst
pacman -U kvmd-web-defaults-1.0.0-1-any.pkg.tar.zst
```

No restart needed — changes take effect on next browser reload.

## Configuration

Create or edit `/etc/kvmd/web.css`:

```css
:root {
    /* Interface settings */
    --config-ui--kvm--page-close-ask: 0;        /* Don't ask on page close */
    --config-ui--kvm--full-tab-stream: 1;       /* Expand stream by default */
    --config-ui--kvm--stream-suspend: 1;        /* Suspend when tab inactive */

    /* Stream settings */
    --config-ui--kvm--stream-mode: mjpeg;       /* janus, media, or mjpeg */
    --config-ui--kvm--stream-orient: 0;         /* 0, 90, 180, 270 */
    --config-ui--kvm--stream-mic: 0;
    --config-ui--kvm--stream-cam: 0;

    /* Confirmation dialogs */
    --config-ui--kvm--atx-ask: 0;               /* Don't confirm ATX actions */
    --config-ui--kvm--switch-atx-ask: 0;
    --config-ui--kvm--switch-msd-ask: 0;
    --config-ui--kvm--hid-sysrq-ask: 0;
    --config-ui--kvm--hid-pak-ask: 0;

    /* Keyboard settings */
    --config-ui--kvm--hid-keyboard-bad-link: 0;
    --config-ui--kvm--hid-keyboard-swap-cc: 0;

    /* Mouse settings */
    --config-ui--kvm--hid-mouse-squash: 1;
    --config-ui--kvm--hid-mouse-reverse-scrolling: 0;
    --config-ui--kvm--hid-mouse-reverse-panning: 0;
    --config-ui--kvm--hid-mouse-cumulative-scrolling: 1;
    --config-ui--kvm--hid-mouse-dot: 1;

    /* Paste settings */
    --config-ui--kvm--hid-pak-secure: 0;
}
```

Only include the settings you want to change. Unset properties use kvmd's built-in defaults.

## Survives kvmd updates

An ALPM hook automatically re-applies patches after any `kvmd` package upgrade.

## Uninstall

```bash
pacman -R kvmd-web-defaults
pacman -S kvmd  # reinstall to restore original JS files
```

Your `/etc/kvmd/web.css` is not removed — delete it manually if no longer needed.

## Building from source

On a PiKVM device:

```bash
git clone https://github.com/nullstacked/kvmd-web-defaults
cd kvmd-web-defaults
makepkg -f
pacman -U kvmd-web-defaults-*.pkg.tar.zst
```

## License

GPL-3.0 — same as kvmd.
