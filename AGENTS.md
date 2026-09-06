# Ember — project context for agents

Native Omarchy shell plugin (Quickshell/QML) that renders a warm "living AI
presence" on the desktop and reacts to agent activity.

- **Plugin id:** `yendor.ember` (kind: `service`). Installs to
  `~/.config/omarchy/plugins/yendor.ember/` (install.sh symlinks this repo).
- **GitHub:** Yendor86/omarchy-ember (public, MIT). Free plugin.
- **Stack:** pure QML — no webkit, no daemon. `Ember.qml` (service +
  layer-shell windows + state file watch), `EmberScene.qml` (Canvas art, ported
  1:1 from the approved HTML design at the artifact), `bin/ember` (CLI).
- **State channel:** `$XDG_RUNTIME_DIR/ember/state` holds one word
  (idle|listening|thinking|speaking|alert). CLI writes it; `FileView` watches
  it. Keep this contract stable — hooks and scripts depend on it.
- **Design language:** warm only (ember/amber/coral on transparent), never cold.
  States differ by motion + brightness, not hue. It is a presence, not a face.
- **Hot reload:** saving any file under the plugin dir reloads it; use
  `omarchy restart shell` if a change doesn't take. Screenshot with `grim`.
- **Design source of truth:** the palette/state values live in
  `EmberScene.qml`'s `states` table; the original interactive reference is the
  Claude artifact. Keep the two in sync if the look changes.
