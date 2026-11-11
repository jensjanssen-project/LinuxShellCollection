#!/usr/bin/env bash
# Repariert den Firefox-Snap-Start in der isolierten Jetson-VNC-Sitzung.
# Als Desktop-Benutzer ohne sudo ausfuehren. Kein VNC-Neustart erforderlich.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Bitte ohne sudo starten.' >&2; exit 1; }
[[ -x /snap/bin/firefox ]] || { echo 'Firefox-Snap wurde nicht gefunden.' >&2; exit 1; }
backup_directory="$HOME/.local/share/jetson-vnc/backups/firefox-$(date -u +%Y%m%dT%H%M%SZ)"
launcher="$HOME/.local/share/jetson-vnc/bin/firefox"
desktop="$HOME/.local/share/applications/firefox_firefox.desktop"
mkdir -p "$backup_directory" "${launcher%/*}" "${desktop%/*}"
for existing in "$launcher" "$desktop" "$HOME/.bashrc"; do
  if [[ -e "$existing" ]]; then cp -a "$existing" "$backup_directory/"; fi
done
cat > "$launcher" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail
# Die getrennte GNOME-Sitzung behalten; nur Snap braucht den echten User-Bus.
if [[ "${XDG_RUNTIME_DIR:-}" == "/run/user/$(id -u)/jetson-vnc" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
fi
exec /snap/bin/firefox "$@"
LAUNCHER
chmod 700 "$launcher"
# Alle Startaktionen und Uebersetzungen des Snap-Launchers beibehalten.
sed "s|^Exec=/snap/bin/firefox|Exec=$launcher|" \
  /var/lib/snapd/desktop/applications/firefox_firefox.desktop > "$desktop"
chmod 644 "$desktop"
if ! grep -Fq '# BEGIN jetson-vnc Firefox launcher' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'BASHRC'

# BEGIN jetson-vnc Firefox launcher
firefox() { "$HOME/.local/share/jetson-vnc/bin/firefox" "$@"; }
# END jetson-vnc Firefox launcher
BASHRC
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications"
fi
bash -n "$launcher" "$HOME/.bashrc"
printf 'Firefox-VNC-Start repariert. Sicherung: %s\n' "$backup_directory"
printf 'Im bestehenden Terminal einmal ausfuehren: source ~/.bashrc\n'
