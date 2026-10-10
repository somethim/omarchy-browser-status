# Browser Status

An Omarchy bar icon for your default browser, similar to a tray icon. It appears only while the browser runs.

The browser is whatever you set as default (`xdg-settings get default-web-browser`, which is what Omarchy's launcher uses). Supported browsers:

- **Chromium-based** (Brave, Chrome, Chromium, Vivaldi, Edge, Helium, Thorium, ...): full per-process breakdown, plus the optional background keeper.
- **Firefox-based** (Firefox, LibreWolf, Zen, Floorp, Waterfox, ...): per-process breakdown.

## What it shows

- **Icon:** the browser's own icon. An accent dot means it is running with no visible windows.
- **Hover:** one-line summary of mode, process count, memory, and CPU.
- **Left click:** a panel with uptime, totals, a breakdown by process type (Browser, Tabs & frames, Extensions, GPU, Network, ...), open window titles, and **Open window** / **Quit** buttons.
- **Right click:** open a new browser window.

## Install

```bash
omarchy plugin add https://github.com/somethim/omarchy-browser-status.git --enable
```

## Background notifications (Chromium only, opt-in)

Chromium browsers on Linux exit when their last window closes, and have no working background mode, so web notifications stop. With **Background notifications** on in the panel, the widget keeps one blank app window open (about one small renderer process) and parks it on the hidden `special:browser-keeper` workspace.

- At login, the widget starts the browser with only the keeper window, once per session.
- When the browser is opened any other way (launcher, link, web app), the widget adds the keeper within about 10 seconds.
- **Quit** stops everything. The browser stays closed until you open it again or log in again.
- Turning the switch off closes the keeper. The setting is stored in `~/.local/state/browser-status/keeper-enabled`.

The widget moves the keeper window itself. To stop it from flashing on screen for a moment when it opens, add this rule to `~/.config/hypr/looknfeel.lua` (optional):

```lua
o.window({ class = ".*Browser_Keeper.*" }, {
  workspace = "special:browser-keeper silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
})
```

Only sites that send Web Push notifications reach you while their tab is closed. Brave also needs "Use Google services for push messaging" enabled in `brave://settings/privacy`.

## How it works

`bin/browser-status` (Python 3, standard library only) reads the default browser's desktop entry and finds its install directory. It follows the launcher, including wrapper scripts, falls back to well-known install paths, and learns from the browser's open windows. It then reads `/proc` for processes running from that directory. Memory is reported as PSS (`/proc/<pid>/smaps_rollup`), so shared pages are not counted twice. CPU is measured over a 0.5 s sample instead of the lifetime average that `ps` shows. Windows are the Hyprland clients owned by the browser's main process, and the keeper is not counted. The widget polls every 10 seconds (3 while its panel is open) and when you hover it.

Commands: `bin/browser-status [status|info|open|quit|keeper-on|keeper-off]`.

## Dependencies

All of these ship with Omarchy: `python3`, `hyprctl`, `xdg-settings`, `uwsm-app`, and `omarchy-launch-browser`. No root access is needed.

## Uninstall

Turn **Background notifications** off first if you enabled it, then:

```bash
omarchy plugin remove somethim.browser-status
rm -rf ~/.local/state/browser-status
```

## License

MIT
