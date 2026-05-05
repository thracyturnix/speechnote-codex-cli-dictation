# Global Speech Dictation Into Codex CLI on Linux

This setup lets you press a global hotkey, speak into Speech Note, and have the dictated text pasted back into the terminal running Codex, Claude, Gemini, Kimi, or another CLI AI tool.

Tested on Linux Mint / Cinnamon using X11, Tilix, Speech Note Flatpak, AutoKey, CopyQ, and xdotool.

## What it does

Press `Ctrl+Alt+Space`.

Speech Note starts listening.

When Speech Note finishes dictation and updates the clipboard, the script switches back to the terminal window you were using and pastes the text with `Ctrl+Shift+V`.

This matters because many terminals use `Ctrl+Shift+V` for paste. Plain `Ctrl+V` may not work.

## Requirements

Install or check that these commands exist:

    command -v xdotool
    command -v copyq
    command -v flatpak
    command -v autokey-gtk

Speech Note should be installed as a Flatpak.

The Speech Note Flatpak app ID is:

    net.mkiol.SpeechNote

You can check the active Speech Note speech-to-text model with:

    flatpak run net.mkiol.SpeechNote --print-active-model stt

## Why use AutoKey?

Cinnamon custom shortcuts can be unreliable or difficult to debug for this job.

The working flow is:

    Ctrl+Alt+Space
    -> AutoKey
    -> shell script
    -> Speech Note
    -> clipboard
    -> terminal paste

## Create the shell script

Create this file:

    ~/.local/bin/speechnote_to_focused_window.sh

Put this inside it:

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

Make it executable:

    chmod +x ~/.local/bin/speechnote_to_focused_window.sh

## Create the AutoKey script

Create the folder:

    mkdir -p ~/.config/autokey/data/Codex

Create this file:

    ~/.config/autokey/data/Codex/Speech Note Dictation.py

Put this inside it:

    system.exec_command("/bin/bash -lc 'printf \"%s\\n\" \"$(date -Is) AutoKey Ctrl+Alt+Space fired\" >> /tmp/autokey-speechnote-dictation.log; nohup /bin/bash \"$HOME/.local/bin/speechnote_to_focused_window.sh\" >> /tmp/autokey-speechnote-dictation.log 2>&1 &'")

Now create this file:

    ~/.config/autokey/data/Codex/Speech Note Dictation.json

Put this inside it:

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

Important: the space key must be written as a literal space:

    "hotKey": " "

Do not write:

    "hotKey": "space"

That can cause AutoKey to fail with:

    Unknown key name: space

## Start AutoKey

AutoKey may already start automatically.

To start it manually:

    DISPLAY=:0 \
    XAUTHORITY="$HOME/.Xauthority" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
    XDG_RUNTIME_DIR="/run/user/$(id -u)" \
    setsid -f autokey-gtk >/tmp/autokey-gtk.log 2>&1

Check that AutoKey is running:

    ps -ef | grep -i '[a]utokey'

## Optional: remove old Cinnamon shortcut

If you previously used the same shortcut in Cinnamon, clear it so AutoKey owns the hotkey:

    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom2/ binding "[]"

Check it was cleared:

    gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom2/ binding

Expected result:

    @as []

## Test it

Focus the terminal running Codex.

Press `Ctrl+Alt+Space`.

Speak into Speech Note.

When dictation finishes, the text should paste into the terminal.

Check whether AutoKey fired:

    tail -40 /tmp/autokey-speechnote-dictation.log

Check the wrapper log:

    tail -80 /tmp/speechnote-to-focused-window.log

A successful log should look roughly like this:

    === 2026-05-05T13:23:09+09:30 starting Speech Note wrapper ===
    DISPLAY=:0
    XDG_SESSION_TYPE=x11
    target_window=56623111
    started Speech Note clipboard action pid=...
    clipboard changed; pasting into target window

## Common problems

Use `Ctrl+Shift+V` for terminal paste.

Do not use `Ctrl+V` in Tilix or many other terminals. It may not paste text correctly.

This setup is for X11. It may not work the same way on Wayland because xdotool depends on X11 window control.
