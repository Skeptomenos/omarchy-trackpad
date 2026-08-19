# david.trackpad

Trackpad settings panel for Omarchy on Apple Silicon Macs (and any libinput
touchpad). Draggable sliders for scroll speed, pointer speed, and workspace
swipe speed, plus switches for natural scrolling and Mac-style four-finger
gestures. Scroll and pointer speed apply live while dragging.

Gestures (Hyprland ≥ 0.55 Lua gestures): four-finger horizontal 1:1
workspace swipe like macOS Spaces, swipe up = fullscreen, swipe down =
`scratchpad` special workspace.

## Requirements

- Omarchy ≥ 4.0 (Quickshell shell, Lua Hyprland config)
- `hyprctl`, `jq`
- A touchpad Hyprland can see (`omarchy hw touchpad`). On Apple Silicon this
  needs the `multi-touch` detection fix (omarchy-mac PR #184 /
  basecamp/omarchy PR #7488).

## Install

```bash
omarchy plugin add https://github.com/Skeptomenos/omarchy-trackpad --enable

# The settings backend the panel calls:
install -Dm755 ~/.config/omarchy/plugins/david.trackpad/bin/trackpad-settings \
  ~/.local/bin/trackpad-settings
```

Load the generated settings from `~/.config/hypr/hyprland.lua`, after
`require("hypr.input")`:

```lua
require("hypr.trackpad-ui")
```

Then open the panel:

```bash
omarchy-shell shell summon david.trackpad
```

Optional menu entries (Setup > Trackpad) for
`~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"setup.trackpad": {"icon":"󰟸","label":"Trackpad","aliases":["trackpad","touchpad"],"when":"omarchy-hw-touchpad"},
"setup.trackpad.sliders": {"icon":"󰟸","label":"Sliders…","action":"omarchy-shell shell summon david.trackpad"},
"setup.trackpad.natural": {"icon":"󰕌","label":"Natural Scrolling","checked":"[[ \"$(trackpad-settings get natural_scroll)\" == \"on\" ]]","action":"trackpad-settings toggle natural_scroll"},
"setup.trackpad.gestures": {"icon":"󰓅","label":"Workspace Gestures","checked":"[[ \"$(trackpad-settings get gestures)\" == \"on\" ]]","action":"trackpad-settings toggle gestures"},
```

## How it works

`bin/trackpad-settings` persists all values to
`~/.config/hypr/trackpad-ui.lua` and applies them with `hyprctl reload`.
The panel (`Panel.qml`) live-applies scroll and pointer speed during a drag
via throttled `hyprctl keyword` calls and persists once on release. The file
is regenerated on every change — keep manual input tweaks in
`~/.config/hypr/input.lua`.

Background and the Apple Silicon trackpad boot-race diagnosis:
`docs/apple-silicon-trackpad.md` in
[Skeptomenos/omarchy-mac](https://github.com/Skeptomenos/omarchy-mac).
