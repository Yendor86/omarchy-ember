# 🟠 Ember

**A warm, living AI presence for your Omarchy / Hyprland desktop.**

When you talk to an agent, it's *alive* somewhere in the background. Ember gives
it a body. A small, warm presence sits in the corner of your screen and breathes.
When an agent is **listening**, it opens toward you. When it's **thinking**, its
currents churn. When it's **speaking**, ripples pulse out. When a background job
**finishes**, it glows for your attention.

Not a face — a presence. Deliberately warm, not cold sci-fi blue.

> Ember is a native Omarchy shell plugin: pure QML/Quickshell, no browser, no
> daemon. It draws on a transparent, click-through layer over your wallpaper.

## Install

**From the Omarchy plugin catalog:**

```bash
omarchy plugin add https://github.com/Yendor86/omarchy-ember.git --enable
```

**Or clone and run the installer** (symlinks the repo so your edits hot-reload):

```bash
git clone https://github.com/Yendor86/omarchy-ember.git ~/code/ember
~/code/ember/install.sh
```

That's it — Ember appears in the bottom-right corner.

## Talk to it

Any tool can drive Ember's mood with one line — that's the whole point.

```bash
ember listening   # it opens and steadies toward you
ember thinking    # currents churn while it works
ember speaking    # ripples pulse with its voice
ember alert       # glows for attention, then settles (use for "job done")
ember idle        # back to a resting breath
ember status      # print the current state
```

Under the hood the CLI just writes one word to
`$XDG_RUNTIME_DIR/ember/state`, which the plugin watches. Anything that can
write a file can move Ember.

### Wire it into Claude Code

Make Ember react to your actual agent by adding hooks to
`~/.claude/settings.json`:

```jsonc
{
  "hooks": {
    "PreToolUse":  [{ "hooks": [{ "type": "command", "command": "ember thinking" }] }],
    "Stop":        [{ "hooks": [{ "type": "command", "command": "ember alert"    }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "ember listening" }] }]
  }
}
```

Now Ember churns while Claude works and flares when it's done — even when the
terminal is off-screen.

## Configure

Open `Ember.qml` and edit the properties at the top (the shell hot-reloads on
save — no restart):

| Property      | Default | Meaning                                  |
|---------------|---------|------------------------------------------|
| `boxSize`     | `260`   | Ember's size in px                       |
| `marginX/Y`   | `26`    | Gap from the screen edge                 |
| `everyScreen` | `true`  | `false` = primary monitor only           |

To move it to a different corner, change the `anchors` in the `PanelWindow`
(e.g. `left: true; top: true`). To sit it *behind* windows on the wallpaper,
change `WlrLayer.Top` to `WlrLayer.Bottom`.

## States

| State       | When it fires              | What it does                    |
|-------------|----------------------------|---------------------------------|
| `idle`      | nothing running            | slow breath, gentle drift       |
| `listening` | you're talking to it       | opens, steadies, soft rings     |
| `thinking`  | working it out             | fast churn, a flicker of effort |
| `speaking`  | responding                 | rhythmic ripples, like a voice  |
| `alert`     | a background agent finished| flares warm, then settles       |

## How it works

- `Ember.qml` — the service: a click-through `PanelWindow` layer-shell surface
  per screen, plus a `FileView` watching the state file.
- `EmberScene.qml` — the art: a QML `Canvas` that renders the ember and eases
  smoothly between states, vsynced via `FrameAnimation`.
- `bin/ember` — the one-line CLI that sets the state.

## License

MIT © 2026 Rodney Baker. Do anything you like with it.
