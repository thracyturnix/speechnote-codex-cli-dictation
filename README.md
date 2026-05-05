# Global Speech Note Dictation Into Codex CLI on Linux

This is a working setup for using [Speech Note](https://flathub.org/apps/net.mkiol.SpeechNote) as a global dictation hotkey that transcribes speech and pastes the result into the currently focused Codex CLI terminal.

The setup below was tested on Linux Mint/Cinnamon with an X11 session, Tilix, Speech Note Flatpak, AutoKey, CopyQ, and `xdotool`.

## What This Does

Press:

```text
Ctrl+Alt+Space
```

Then speak into Speech Note. When Speech Note finishes and updates the clipboard, the wrapper reactivates the original terminal window and pastes the transcription with:

```text
Ctrl+Shift+V
```

That last detail matters. In Tilix and many terminals, `Ctrl+V` is not the normal text paste shortcut. It may trigger image paste handling or do something else. `Ctrl+Shift+V` is the terminal paste shortcut.

## Requirements

Install or verify:

```bash
command -v xdotool
command -v copyq
command -v flatpak
command -v autokey-gtk
```

Speech Note Flatpak app ID:

```text
net.mkiol.SpeechNote
```

Useful Speech Note model check:

```bash
flatpak run net.mkiol.SpeechNote --print-active-model stt
```

In my working setup, the active model was:

```text
en_fasterwhisper_small "English (FasterWhisper Small) / en"
```

## Why AutoKey Instead Of Cinnamon Custom Shortcuts

Cinnamon custom shortcuts can work, but debugging them from a sandboxed CLI session is painful because `gsettings` may appear to set values while the real desktop session does not actually grab or execute the shortcut.

AutoKey gave a more reliable global hotkey path:

```text
Ctrl+Alt+Space -> AutoKey -> shell wrapper -> Speech Note -> clipboard -> terminal paste
```

## Shell Wrapper

Create:

```text
~/.local/bin/speechnote_to_focused_window.sh
```

Script:

```bash
#!/usr/bin/env bash
set -u

log_file=/tmp/speechnote-to-focused-window.log
{
  echo
  echo "=== $(date -Is) starting Speech Note wrapper ==="
  echo "DISPLAY=${DISPLAY:-}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
} >>"$log_file"

target_window="$(xdotool getwindowfocus 2>>"$log_file" || true)"
before_clipboard="$(copyq clipboard 2>>"$log_file" || true)"
echo "target_window=${target_window:-none}" >>"$log_file"

flatpak run net.mkiol.SpeechNote --action start-listening-clipboard >>"$log_file" 2>&1 &
echo "started Speech Note clipboard action pid=$!" >>"$log_file"

for _ in $(seq 1 900); do
  sleep 0.1
  current_clipboard="$(copyq clipboard 2>>"$log_file" || true)"

  if [ -n "$current_clipboard" ] && [ "$current_clipboard" != "$before_clipboard" ]; then
    if [ -n "$target_window" ]; then
      xdotool windowactivate --sync "$target_window" >>"$log_file" 2>&1 || true
    fi
    echo "clipboard changed; pasting into target window" >>"$log_file"
    xdotool key --clearmodifiers ctrl+shift+v >>"$log_file" 2>&1
    exit 0
  fi
done

echo "Timed out waiting for Speech Note to update clipboard" >>"$log_file"
exit 1
```

Make it executable:

```bash
chmod +x ~/.local/bin/speechnote_to_focused_window.sh
```

## AutoKey Script

Create this folder:

```bash
mkdir -p ~/.config/autokey/data/Codex
```

Create:

```text
~/.config/autokey/data/Codex/Speech Note Dictation.py
```

Content:

```python
system.exec_command("/bin/bash -lc 'printf \"%s\\n\" \"$(date -Is) AutoKey Ctrl+Alt+Space fired\" >> /tmp/autokey-speechnote-dictation.log; nohup /bin/bash \"$HOME/.local/bin/speechnote_to_focused_window.sh\" >> /tmp/autokey-speechnote-dictation.log 2>&1 &'")
```

Create:

```text
~/.config/autokey/data/Codex/Speech Note Dictation.json
```

Content:

```json
{
    "type": "script",
    "description": "Speech Note Dictation",
    "store": {},
    "modes": [],
    "usageCount": 0,
    "prompt": false,
    "omitTrigger": false,
    "showInTrayMenu": false,
    "abbreviation": {
        "abbreviations": [],
        "backspace": true,
        "ignoreCase": false,
        "immediate": false,
        "triggerInside": false,
        "wordChars": "[\\w]"
    },
    "hotkey": {
        "modifiers": [
            "<ctrl>",
            "<alt>"
        ],
        "hotKey": " "
    },
    "filter": {
        "regex": null,
        "isRecursive": false
    }
}
```

Important: AutoKey wants the space key represented as a literal space:

```json
"hotKey": " "
```

Do not use:

```json
"hotKey": "space"
```

That can fail with an AutoKey error like:

```text
Unknown key name: space
```

## Start AutoKey

AutoKey may already be configured to autostart. To start it manually in the current desktop session:

```bash
DISPLAY=:0 \
XAUTHORITY="$HOME/.Xauthority" \
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
XDG_RUNTIME_DIR="/run/user/$(id -u)" \
setsid -f autokey-gtk >/tmp/autokey-gtk.log 2>&1
```

Verify:

```bash
ps -ef | grep -i '[a]utokey'
```

## Optional: Clear Cinnamon Custom Shortcut

If you previously tried Cinnamon custom shortcuts for the same combo, clear them so only AutoKey owns the hotkey:

```bash
gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom2/ binding "[]"
```

Verify:

```bash
gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom2/ binding
```

Expected:

```text
@as []
```

## Test

With Codex CLI focused, press:

```text
Ctrl+Alt+Space
```

Then dictate in Speech Note and finish the dictation.

Check AutoKey fired:

```bash
tail -40 /tmp/autokey-speechnote-dictation.log
```

Check the wrapper:

```bash
tail -80 /tmp/speechnote-to-focused-window.log
```

Expected wrapper log shape:

```text
=== 2026-05-05T13:23:09+09:30 starting Speech Note wrapper ===
DISPLAY=:0
XDG_SESSION_TYPE=x11
target_window=56623111
started Speech Note clipboard action pid=...
clipboard changed; pasting into target window
```

## Known Traps

Do not use `Ctrl+Alt+Shift+D` for this. In a terminal, anything involving `Ctrl+D` can be interpreted as EOF/exit behavior.

Do not use `Ctrl+Alt+V` or similar paste-looking shortcuts. They collide with paste workflows and are confusing.

Do not paste into Tilix/Codex CLI with `Ctrl+V`. Use `Ctrl+Shift+V`.

Do not assume a `gsettings set` made from a sandboxed CLI session actually updated the real Cinnamon desktop session. If dconf reports `/run/user/1000/dconf/user` as read-only, you are not testing the real shortcut path.

Do not use `"hotKey": "space"` in AutoKey JSON. Use `"hotKey": " "`.

## What This Is

This is mostly configuration and glue:

- AutoKey config binds a global hotkey.
- A tiny AutoKey script launches a shell wrapper.
- The shell wrapper calls Speech Note, watches the clipboard, returns focus, and sends terminal paste.
- Speech Note does the actual speech-to-text work.

It is not a full application. It is a working desktop automation recipe.
