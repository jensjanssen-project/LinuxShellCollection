#!/usr/bin/env bash
# Vollstaendige Ersteinrichtung des Advantech-Jetson-PCs fuer PIDVISION.
#
# Als normaler Desktop-Benutzer starten, nicht mit "sudo bash". Das Skript
# fordert sudo nur fuer die Schritte an, die Administratorrechte brauchen.
# Es ist idempotent und kann nach einem Fehler erneut ausgefuehrt werden.
#
# Optionale Konfiguration per Umgebungsvariable:
#   ETH5_ADDRESS=192.168.1.11/24
#   ETH6_ADDRESS=192.168.11.110/24
#   ORBBEC_CAMERA_IP=192.168.1.10         # PoE-Kamera am ersten statischen Netz
#   ORBBEC_UDP_SOURCE_PORT=3956            # UDP-Quellport der Kamera
#   ETH5_EXPECTED_MAC=aa:bb:cc:dd:ee:ff    # optionaler Port-Abgleich
#   ETH6_EXPECTED_MAC=11:22:33:44:55:66    # optionaler Port-Abgleich
#   TAILSCALE_AUTH_KEY=tskey-auth-...       # fuer unbeaufsichtigte Anmeldung
#   TAILSCALE_AUTH_KEY_FILE=/sicherer/pfad  # Alternative zur Variable
#   VNC_PASSWORD=geheim                     # 6 bis 8 Zeichen
#   VNC_PASSWORD_FILE=/sicherer/pfad        # Alternative zur Variable
#   NONINTERACTIVE=1                        # bei fehlenden Geheimnissen abbrechen
#   SKIP_VNC=1                              # VNC nicht einrichten
#   ENABLE_UFW=0                            # UFW-Regeln anlegen, aber nicht aktivieren
#   MIN_FREE_GB=30                          # benoetigter freier Speicher
#   ALLOW_UNTESTED_SYSTEM=1                 # andere Ubuntu-/Hardwareversion zulassen

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
readonly INSTALLER_VERSION='1.0.5'
readonly ETH5_INTERFACE="${ETH5_INTERFACE:-eth5}"
readonly ETH6_INTERFACE="${ETH6_INTERFACE:-eth6}"
readonly ETH5_ADDRESS="${ETH5_ADDRESS:-192.168.1.11/24}"
readonly ETH6_ADDRESS="${ETH6_ADDRESS:-192.168.11.110/24}"
readonly ORBBEC_CAMERA_IP="${ORBBEC_CAMERA_IP:-192.168.1.10}"
readonly ORBBEC_UDP_SOURCE_PORT="${ORBBEC_UDP_SOURCE_PORT:-3956}"
readonly ETH5_EXPECTED_MAC="${ETH5_EXPECTED_MAC:-}"
readonly ETH6_EXPECTED_MAC="${ETH6_EXPECTED_MAC:-}"
readonly NONINTERACTIVE="${NONINTERACTIVE:-0}"
readonly SKIP_VNC="${SKIP_VNC:-0}"
readonly ENABLE_UFW="${ENABLE_UFW:-1}"
readonly MIN_FREE_GB="${MIN_FREE_GB:-30}"
readonly ALLOW_UNTESTED_SYSTEM="${ALLOW_UNTESTED_SYSTEM:-0}"
INSTALL_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
readonly INSTALL_RUN_ID
readonly INSTALL_LOG="/var/log/pidvision-install-$INSTALL_RUN_ID.log"
readonly BACKUP_DIRECTORY="/var/backups/pidvision-installer/$INSTALL_RUN_ID"

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

warn() {
  printf '\033[1;33mWARNUNG: %s\033[0m\n' "$*" >&2
}

die() {
  printf '\033[1;31mFEHLER: %s\033[0m\n' "$*" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  printf '\n\033[1;31mInstallation in Zeile %s fehlgeschlagen (Status %s).\033[0m\n' \
    "$1" "$exit_code" >&2
  printf 'Nach Behebung der Ursache kann %s erneut gestartet werden.\n' "$SCRIPT_NAME" >&2
  exit "$exit_code"
}
trap 'on_error "$LINENO"' ERR

show_help() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "$0"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
  exit 0
fi
[[ $# -eq 0 ]] || die "Unbekannte Option: $1 (Hilfe: ./$SCRIPT_NAME --help)"

for boolean_setting in NONINTERACTIVE SKIP_VNC ENABLE_UFW ALLOW_UNTESTED_SYSTEM; do
  boolean_value="${!boolean_setting}"
  [[ "$boolean_value" == '0' || "$boolean_value" == '1' ]] \
    || die "$boolean_setting muss 0 oder 1 sein."
done

[[ $EUID -ne 0 ]] || die 'Bitte als normaler Benutzer starten, nicht mit sudo.'
[[ -r /etc/os-release ]] || die '/etc/os-release wurde nicht gefunden.'

# shellcheck source=/dev/null
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "Unterstuetzt wird Ubuntu; erkannt wurde ${ID:-unbekannt}."
[[ "${VERSION_CODENAME:-}" =~ ^[a-z]+$ ]] || die 'Ubuntu-Codename konnte nicht sicher ermittelt werden.'

if [[ "${VERSION_ID:-}" != '22.04' && "$ALLOW_UNTESTED_SYSTEM" != '1' ]]; then
  die "Getestet ist Ubuntu 22.04; erkannt wurde ${VERSION_ID:-unbekannt}. Mit ALLOW_UNTESTED_SYSTEM=1 auf eigenes Risiko fortsetzen."
fi

case "$(uname -m)" in
  aarch64 | arm64) ;;
  *)
    [[ "$ALLOW_UNTESTED_SYSTEM" == '1' ]] \
      || die "Erwartet wurde ein Jetson mit ARM64, erkannt wurde $(uname -m)."
    warn "Ungetestete Architektur: $(uname -m)."
    ;;
esac

[[ "$MIN_FREE_GB" =~ ^[0-9]+$ ]] || die 'MIN_FREE_GB muss eine ganze Zahl sein.'
available_kb="$(df -Pk "$HOME" | awk 'NR == 2 {print $4}')"
required_kb=$((MIN_FREE_GB * 1024 * 1024))
(( available_kb >= required_kb )) \
  || die "Zu wenig freier Speicher: mindestens $MIN_FREE_GB GB werden benoetigt."

IS_JETSON=1
if [[ ! -r /etc/nv_tegra_release ]] \
  && ! dpkg-query -W -f='${Status}' nvidia-l4t-core 2>/dev/null | grep -q 'ok installed'; then
  IS_JETSON=0
  [[ "$ALLOW_UNTESTED_SYSTEM" == '1' ]] \
    || die 'Es wurde keine NVIDIA-Jetson-/JetPack-Installation erkannt.'
  warn 'JetPack konnte nicht erkannt werden.'
fi
readonly IS_JETSON

read_secret_file() {
  local file_path=$1
  local variable_name=$2
  [[ -f "$file_path" ]] || die "$variable_name verweist nicht auf eine Datei: $file_path"
  [[ ! -L "$file_path" ]] || die "$variable_name darf kein symbolischer Link sein: $file_path"
  local file_mode
  file_mode="$(stat -c '%a' "$file_path")"
  (( (8#${file_mode: -3} & 8#077) == 0 )) \
    || die "$variable_name darf nur fuer den Besitzer lesbar sein (chmod 600): $file_path"
  local value
  IFS= read -r value < "$file_path" || true
  [[ -n "$value" ]] || die "$variable_name ist leer: $file_path"
  printf '%s' "$value"
}

TAILSCALE_KEY="${TAILSCALE_AUTH_KEY:-}"
TAILSCALE_KEY_FILE_PATH="${TAILSCALE_AUTH_KEY_FILE:-}"
if [[ -n "${TAILSCALE_AUTH_KEY_FILE:-}" ]]; then
  [[ -z "$TAILSCALE_KEY" ]] || die 'Nur TAILSCALE_AUTH_KEY oder TAILSCALE_AUTH_KEY_FILE setzen, nicht beides.'
  read_secret_file "$TAILSCALE_KEY_FILE_PATH" TAILSCALE_AUTH_KEY_FILE >/dev/null
fi

VNC_SECRET="${VNC_PASSWORD:-}"
if [[ -n "${VNC_PASSWORD_FILE:-}" ]]; then
  [[ -z "$VNC_SECRET" ]] || die 'Nur VNC_PASSWORD oder VNC_PASSWORD_FILE setzen, nicht beides.'
  VNC_SECRET="$(read_secret_file "$VNC_PASSWORD_FILE" VNC_PASSWORD_FILE)"
fi

unset TAILSCALE_AUTH_KEY VNC_PASSWORD

log 'Administratorrechte pruefen'
sudo -v
sudo install -m 0600 /dev/null "$INSTALL_LOG"
exec > >(sudo tee -a "$INSTALL_LOG") 2>&1
printf 'PIDVISION-Installer %s, Lauf %s\n' "$INSTALLER_VERSION" "$INSTALL_RUN_ID"

log 'Bestehende Systemkonfiguration sichern'
sudo install -m 0700 -d "$BACKUP_DIRECTORY"
if [[ -d /etc/NetworkManager/system-connections ]]; then
  sudo cp -a /etc/NetworkManager/system-connections "$BACKUP_DIRECTORY/"
fi
if [[ -d /etc/ufw ]]; then
  sudo cp -a /etc/ufw "$BACKUP_DIRECTORY/"
fi
for backup_file in \
  /etc/docker/daemon.json \
  /etc/apt/sources.list.d/docker.list \
  /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  /etc/apt/sources.list.d/tailscale.list; do
  if [[ -e "$backup_file" ]]; then
    sudo cp -a "$backup_file" "$BACKUP_DIRECTORY/"
  fi
done

log 'APT-Basispakete installieren'
sudo env DEBIAN_FRONTEND=noninteractive apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl dbus-x11 gnupg2 iproute2 nano network-manager openssh-server \
  python3 ufw x11-utils xauth

validate_cidr() {
  python3 - "$1" <<'PY'
import ipaddress
import sys
ipaddress.IPv4Interface(sys.argv[1])
PY
}

validate_cidr "$ETH5_ADDRESS"
validate_cidr "$ETH6_ADDRESS"

python3 - "$ORBBEC_CAMERA_IP" <<'PY'
import ipaddress
import sys
ipaddress.IPv4Address(sys.argv[1])
PY
if [[ ! "$ORBBEC_UDP_SOURCE_PORT" =~ ^[0-9]+$ ]] \
  || (( 10#$ORBBEC_UDP_SOURCE_PORT < 1 || 10#$ORBBEC_UDP_SOURCE_PORT > 65535 )); then
  die 'ORBBEC_UDP_SOURCE_PORT muss zwischen 1 und 65535 liegen.'
fi

verify_interface_identity() {
  local interface=$1
  local expected_mac=${2,,}
  local actual_mac
  ip link show "$interface" >/dev/null 2>&1 \
    || die "Netzwerkschnittstelle $interface wurde nicht gefunden."
  if [[ -z "$expected_mac" ]]; then
    warn "Fuer $interface ist kein MAC-Abgleich konfiguriert; der Schnittstellenname wird verwendet."
    return
  fi
  [[ "$expected_mac" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] \
    || die "Ungueltige erwartete MAC-Adresse fuer $interface: $expected_mac"
  actual_mac="$(<"/sys/class/net/$interface/address")"
  [[ "${actual_mac,,}" == "$expected_mac" ]] \
    || die "$interface hat MAC $actual_mac, erwartet wurde $expected_mac. Abbruch zum Schutz vor einer falschen Portzuordnung."
}

verify_interface_identity "$ETH5_INTERFACE" "$ETH5_EXPECTED_MAC"
verify_interface_identity "$ETH6_INTERFACE" "$ETH6_EXPECTED_MAC"

log 'Netzwerk und Hardware vorab pruefen'
for required_url in \
  https://download.docker.com/linux/ubuntu/gpg \
  https://nvidia.github.io/libnvidia-container/gpgkey \
  https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  "https://pkgs.tailscale.com/stable/ubuntu/$VERSION_CODENAME.tailscale-keyring.list"; do
  curl --fail --silent --show-error --location --retry 2 \
    --range 0-0 --output /dev/null "$required_url" \
    || die "Nicht erreichbar: $required_url"
done

log 'Docker-Paketquelle einrichten'
sudo install -m 0755 -d /etc/apt/keyrings
docker_key="$(mktemp)"
nvidia_key_armored="$(mktemp)"
nvidia_keyring="$nvidia_key_armored.gpg"
nvidia_list="$(mktemp)"
tailscale_keyring="$(mktemp)"
tailscale_list="$(mktemp)"
cleanup_downloads() {
  rm -f \
    "$docker_key" "$nvidia_key_armored" "$nvidia_keyring" "$nvidia_list" \
    "$tailscale_keyring" "$tailscale_list"
}
trap cleanup_downloads EXIT

curl --fail --silent --show-error --location --retry 3 \
  https://download.docker.com/linux/ubuntu/gpg -o "$docker_key"
sudo install -m 0644 "$docker_key" /etc/apt/keyrings/docker.asc
printf '%s\n' \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

log 'Tailscale-Paketquelle einrichten'
curl --fail --silent --show-error --location --retry 3 \
  "https://pkgs.tailscale.com/stable/ubuntu/$VERSION_CODENAME.noarmor.gpg" \
  -o "$tailscale_keyring"
curl --fail --silent --show-error --location --retry 3 \
  "https://pkgs.tailscale.com/stable/ubuntu/$VERSION_CODENAME.tailscale-keyring.list" \
  -o "$tailscale_list"
sudo install -m 0755 -d /usr/share/keyrings
sudo install -m 0644 "$tailscale_keyring" /usr/share/keyrings/tailscale-archive-keyring.gpg
sudo install -m 0644 "$tailscale_list" /etc/apt/sources.list.d/tailscale.list

if [[ "$IS_JETSON" == '1' ]]; then
  log 'Offizielle NVIDIA-Container-Toolkit-Paketquelle einrichten'
  curl --fail --silent --show-error --location --retry 3 \
    https://nvidia.github.io/libnvidia-container/gpgkey \
    -o "$nvidia_key_armored"
  gpg --batch --yes --dearmor --output "$nvidia_keyring" "$nvidia_key_armored"
  curl --fail --silent --show-error --location --retry 3 \
    https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    -o "$nvidia_list"
  sudo install -m 0644 \
    "$nvidia_keyring" /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    "$nvidia_list" \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
fi

log 'Docker, Tailscale, Chromium und VNC-Pakete installieren'
sudo env DEBIAN_FRONTEND=noninteractive apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  chromium-browser chromium-browser-l10n \
  containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin \
  tailscale tigervnc-common tigervnc-standalone-server tigervnc-tools xfonts-base

log 'SSH und Docker aktivieren'
sudo systemctl enable --now ssh docker tailscaled
sudo ufw allow OpenSSH
sudo usermod -aG docker "$(id -un)"

if [[ "$IS_JETSON" == '1' ]]; then
  log 'NVIDIA-Container-Runtime fuer Jetson konfigurieren'
  if ! command -v nvidia-ctk >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
  fi

  command -v nvidia-ctk >/dev/null 2>&1 \
    || die 'nvidia-container-toolkit wurde installiert, aber nvidia-ctk fehlt.'
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo python3 - <<'SET_NVIDIA_DEFAULT'
import json
import os
import pathlib

path = pathlib.Path('/etc/docker/daemon.json')
data = json.loads(path.read_text()) if path.exists() else {}
data['default-runtime'] = 'nvidia'
temporary = path.with_name(path.name + '.pidvision.tmp')
temporary.write_text(json.dumps(data, indent=2) + '\n')
os.chmod(temporary, 0o644)
os.replace(temporary, path)
SET_NVIDIA_DEFAULT
  sudo systemctl daemon-reload
  sudo systemctl restart docker
fi

find_connection_profile() {
  local interface=$1
  local profile
  profile="$(nmcli -g GENERAL.CONNECTION device show "$interface" 2>/dev/null || true)"
  if [[ -n "$profile" && "$profile" != '--' ]]; then
    printf '%s' "$profile"
    return
  fi

  local preferred="pidvision-${interface}-static"
  if nmcli connection show "$preferred" >/dev/null 2>&1; then
    printf '%s' "$preferred"
    return
  fi

  local uuid bound_interface connection_type
  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] || continue
    bound_interface="$(nmcli -g connection.interface-name connection show "$uuid" 2>/dev/null || true)"
    connection_type="$(nmcli -g connection.type connection show "$uuid" 2>/dev/null || true)"
    if [[ "$bound_interface" == "$interface" && "$connection_type" == '802-3-ethernet' ]]; then
      nmcli -g connection.id connection show "$uuid"
      return
    fi
  done < <(nmcli -t -f UUID connection show)

  printf '%s' "$preferred"
}

configure_static_interface() {
  local interface=$1
  local address=$2
  local profile

  ip link show "$interface" >/dev/null 2>&1 || die "Netzwerkschnittstelle $interface wurde nicht gefunden."
  profile="$(find_connection_profile "$interface")"

  if ! nmcli connection show "$profile" >/dev/null 2>&1; then
    sudo nmcli connection add type ethernet ifname "$interface" con-name "$profile"
  fi

  sudo nmcli connection modify "$profile" \
    connection.interface-name "$interface" \
    connection.autoconnect yes \
    ipv4.method manual \
    ipv4.addresses "$address" \
    ipv4.gateway '' \
    ipv4.dns '' \
    ipv4.dns-search '' \
    ipv4.routes '' \
    ipv4.never-default yes \
    ipv6.method link-local \
    ipv6.never-default yes

  if [[ "$(nmcli -g GENERAL.CONNECTION device show "$interface" 2>/dev/null || true)" == "$profile" ]]; then
    if ! sudo nmcli device reapply "$interface"; then
      sudo nmcli connection up "$profile" ifname "$interface"
    fi
  elif ! sudo nmcli connection up "$profile" ifname "$interface"; then
    warn "$interface ist vermutlich nicht verbunden. Das Profil ist gespeichert und startet bei vorhandener Verbindung automatisch."
  fi

  printf '%-5s -> %-22s (%s)\n' "$interface" "$address" "$profile"
}

log 'Statische Netze konfigurieren (ohne Gateway und DNS)'
configure_static_interface "$ETH5_INTERFACE" "$ETH5_ADDRESS"
configure_static_interface "$ETH6_INTERFACE" "$ETH6_ADDRESS"

# Das Orbbec SDK waehlt fuer seine lokale UDP-Antwortadresse dynamische Ports.
# Die Freigabe bleibt deshalb auf Schnittstelle, Kamera-IP, Host-IP, Protokoll
# und den beobachteten festen Quellport der Kamera beschraenkt.
ORBBEC_HOST_IP="${ETH5_ADDRESS%/*}"
readonly ORBBEC_HOST_IP
log 'Orbbec-PoE-Kamera in UFW freigeben'
sudo ufw allow in on "$ETH5_INTERFACE" proto udp \
  from "$ORBBEC_CAMERA_IP" port "$ORBBEC_UDP_SOURCE_PORT" \
  to "$ORBBEC_HOST_IP" comment 'Orbbec PoE camera'

log 'Tailscale anmelden'
if ! tailscale ip -4 >/dev/null 2>&1; then
  if [[ -n "$TAILSCALE_KEY_FILE_PATH" ]]; then
    sudo tailscale up --authkey="file:$TAILSCALE_KEY_FILE_PATH"
  elif [[ -n "$TAILSCALE_KEY" ]]; then
    sudo tailscale up --auth-key="$TAILSCALE_KEY"
  elif [[ "$NONINTERACTIVE" == '1' ]]; then
    die 'Tailscale ist nicht angemeldet. Fuer einen unbeaufsichtigten Lauf TAILSCALE_AUTH_KEY oder TAILSCALE_AUTH_KEY_FILE setzen.'
  else
    printf 'Im naechsten Schritt wird eine URL zur Tailscale-Anmeldung angezeigt.\n'
    # Die Umleitung soll bewusst vor sudo durch den aktuellen Benutzer erfolgen.
    # shellcheck disable=SC2024
    sudo tailscale up </dev/tty
  fi
fi
TAILSCALE_IP="$(tailscale ip -4 | head -n 1)"
validate_cidr "$TAILSCALE_IP/32"
TAILSCALE_KEY=''
TAILSCALE_KEY_FILE_PATH=''

if [[ "$SKIP_VNC" != '1' ]]; then
  log 'Headless-GNOME-VNC einrichten'
  [[ -x /usr/bin/gnome-session ]] \
    || die 'GNOME Desktop wurde nicht gefunden. Bitte zuerst Ubuntu Desktop installieren.'
  sudo loginctl enable-linger "$(id -un)"

  mkdir -p \
    "$HOME/.local/share/jetson-vnc/bin" \
    "$HOME/.local/share/jetson-vnc/setup" \
    "$HOME/.config/systemd/user" \
    "$HOME/.config/jetson-vnc/desktop/autostart"
  chmod 700 "$HOME/.config/jetson-vnc"

  if [[ -n "$VNC_SECRET" || ! -s "$HOME/.config/jetson-vnc/passwd" ]]; then
    if [[ -z "$VNC_SECRET" ]]; then
      [[ "$NONINTERACTIVE" != '1' ]] \
        || die 'Noch kein VNC-Passwort vorhanden. VNC_PASSWORD oder VNC_PASSWORD_FILE setzen.'
      while :; do
        IFS= read -r -s -p 'VNC-Passwort (6 bis 8 Zeichen): ' VNC_SECRET </dev/tty
        printf '\n'
        IFS= read -r -s -p 'VNC-Passwort wiederholen: ' vnc_repeat </dev/tty
        printf '\n'
        [[ "$VNC_SECRET" == "$vnc_repeat" ]] || { warn 'Die Passwoerter stimmen nicht ueberein.'; continue; }
        [[ ${#VNC_SECRET} -ge 6 && ${#VNC_SECRET} -le 8 ]] \
          || { warn 'Das VNC-Passwort muss 6 bis 8 Zeichen lang sein.'; continue; }
        break
      done
    fi
    [[ "$VNC_SECRET" != *$'\n'* && ${#VNC_SECRET} -ge 6 && ${#VNC_SECRET} -le 8 ]] \
      || die 'VNC_PASSWORD muss 6 bis 8 Zeichen lang sein und darf keinen Zeilenumbruch enthalten.'
    vnc_password_tmp="$(mktemp "$HOME/.config/jetson-vnc/passwd.XXXXXX")"
    chmod 600 "$vnc_password_tmp"
    printf '%s\n' "$VNC_SECRET" | tigervncpasswd -f > "$vnc_password_tmp"
    mv "$vnc_password_tmp" "$HOME/.config/jetson-vnc/passwd"
  fi
  chmod 600 "$HOME/.config/jetson-vnc/passwd"
  VNC_SECRET=''

  cat > "$HOME/.local/share/jetson-vnc/bin/session" <<'VNC_SESSION'
#!/usr/bin/env bash
set -Eeuo pipefail
export DISPLAY=:1
export XDG_RUNTIME_DIR="/run/user/$(id -u)/jetson-vnc"
export XDG_CONFIG_HOME="$HOME/.config/jetson-vnc/desktop"
export XDG_CACHE_HOME="$HOME/.cache/jetson-vnc"
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export GNOME_SHELL_SESSION_MODE=ubuntu
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export __GLX_VENDOR_LIBRARY_NAME=mesa
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY GNOME_DESKTOP_SESSION_ID
umask 077
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"
touch "$XAUTHORITY"
chmod 600 "$XAUTHORITY"
xauth -f "$XAUTHORITY" add "$DISPLAY" . "$(mcookie)"

/usr/bin/Xtigervnc "$DISPLAY" -geometry 1920x1080 -depth 24 -rfbport 5901 \
  -interface "${VNC_BIND_ADDRESS:?}" -localhost no -UseIPv6=0 \
  -SecurityTypes VncAuth -PasswordFile "$HOME/.config/jetson-vnc/passwd" \
  -auth "$XAUTHORITY" -nolisten tcp -AlwaysShared -desktop 'Jetson GNOME' &
vnc_pid=$!
trap 'kill "$vnc_pid" ${gnome_pid:-} ${clipboard_pid:-} 2>/dev/null || true; wait || true' EXIT
for _attempt in {1..50}; do
  kill -0 "$vnc_pid" || exit 1
  if xdpyinfo >/dev/null 2>&1; then break; fi
  sleep 0.2
done
xdpyinfo >/dev/null
/usr/bin/tigervncconfig -nowin &
clipboard_pid=$!
/usr/bin/dbus-run-session -- "$HOME/.local/share/jetson-vnc/bin/gnome" &
gnome_pid=$!
wait -n "$vnc_pid" "$gnome_pid" "$clipboard_pid"
VNC_SESSION

  cat > "$HOME/.local/share/jetson-vnc/bin/gnome" <<'VNC_GNOME'
#!/usr/bin/env bash
set -Eeuo pipefail
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 0
exec /usr/bin/gnome-session --builtin --session=ubuntu --disable-acceleration-check
VNC_GNOME

  cat > "$HOME/.local/share/jetson-vnc/bin/change-password" <<'VNC_PASSWORD_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
base="$HOME/.config/jetson-vnc"
tmp="$(mktemp "$base/passwd.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
/usr/bin/tigervncpasswd "$tmp"
mv "$tmp" "$base/passwd"
echo 'VNC-Passwort aktualisiert. Es werden maximal acht Zeichen verwendet.'
VNC_PASSWORD_SCRIPT

  chmod 755 \
    "$HOME/.local/share/jetson-vnc/bin/session" \
    "$HOME/.local/share/jetson-vnc/bin/gnome" \
    "$HOME/.local/share/jetson-vnc/bin/change-password"

  for autostart_name in nvpmodel_indicator gnome-initial-setup-first-login \
    gnome-initial-setup-copy-worker tracker-miner-fs-3 gnome-software-service \
    nvbackground; do
    cat > "$HOME/.config/jetson-vnc/desktop/autostart/$autostart_name.desktop" <<VNC_AUTOSTART
[Desktop Entry]
Type=Application
Name=$autostart_name
Hidden=true
VNC_AUTOSTART
  done

  cat > "$HOME/.config/systemd/user/jetson-vnc.service" <<VNC_SERVICE
[Unit]
Description=Headless GNOME desktop via TigerVNC (Tailscale only)
StartLimitIntervalSec=0
After=network-online.target

[Service]
Type=exec
Environment=VNC_BIND_ADDRESS=$TAILSCALE_IP
ExecStartPre=/bin/sh -c '/usr/sbin/ip -4 address show dev tailscale0 | /usr/bin/grep -q "inet $TAILSCALE_IP/"'
ExecStart=%h/.local/share/jetson-vnc/bin/session
Restart=always
RestartSec=10
TimeoutStopSec=20
KillMode=control-group
UMask=0077

[Install]
WantedBy=default.target
VNC_SERVICE

  if [[ ! -s "$HOME/.local/share/jetson-vnc/setup/original-power-settings.json" ]]; then
    dbus-run-session -- python3 - <<'SAVE_POWER'
import json
import pathlib
import subprocess

keys = ['sleep-inactive-ac-type', 'sleep-inactive-battery-type']
settings = {
    key: subprocess.check_output(
        ['gsettings', 'get', 'org.gnome.settings-daemon.plugins.power', key],
        text=True,
    ).strip()
    for key in keys
}
path = pathlib.Path.home() / '.local/share/jetson-vnc/setup/original-power-settings.json'
path.write_text(json.dumps(settings, indent=2) + '\n')
SAVE_POWER
  fi
  dbus-run-session -- gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
  dbus-run-session -- gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

  bash -n \
    "$HOME/.local/share/jetson-vnc/bin/session" \
    "$HOME/.local/share/jetson-vnc/bin/gnome" \
    "$HOME/.local/share/jetson-vnc/bin/change-password"
  systemd-analyze --user verify "$HOME/.config/systemd/user/jetson-vnc.service"
  systemctl --user daemon-reload
  systemctl --user enable jetson-vnc.service
  systemctl --user restart jetson-vnc.service
  sudo ufw allow in on tailscale0 to any port 5901 proto tcp
else
  warn 'SKIP_VNC=1: VNC wurde nicht eingerichtet.'
fi

if [[ "$ENABLE_UFW" == '1' ]]; then
  log 'UFW-Firewall aktivieren'
  sudo ufw --force enable
else
  warn 'ENABLE_UFW=0: UFW-Regeln wurden angelegt, die Firewall aber nicht aktiviert.'
fi

log 'Installation und Dienste pruefen'
for system_service in ssh docker tailscaled; do
  sudo systemctl is-enabled --quiet "$system_service" \
    || die "$system_service ist nicht fuer den Systemstart aktiviert."
  sudo systemctl is-active --quiet "$system_service" \
    || die "$system_service laeuft nicht."
done

verify_static_interface() {
  local interface=$1
  local address=$2
  local profile
  profile="$(find_connection_profile "$interface")"
  [[ "$(nmcli -g ipv4.method connection show "$profile")" == 'manual' ]] \
    || die "$profile verwendet nicht die manuelle IPv4-Konfiguration."
  nmcli -g ipv4.addresses connection show "$profile" | grep -Fxq "$address" \
    || die "$profile enthaelt nicht die erwartete Adresse $address."
  [[ "$(nmcli -g ipv4.never-default connection show "$profile")" == 'yes' ]] \
    || die "$profile kann unerwartet eine Default-Route setzen."

  if [[ "$(<"/sys/class/net/$interface/carrier")" == '1' ]]; then
    ip -o -4 address show dev "$interface" \
      | awk '{print $4}' \
      | grep -Fxq "$address" \
      || die "$interface hat trotz bestehender Verbindung nicht die erwartete Adresse $address."
  else
    warn "$interface hat keinen Link; das gespeicherte Netzwerkprofil ist jedoch korrekt."
  fi
  if ip -4 route show default dev "$interface" | grep -q .; then
    die "$interface besitzt unerwartet eine Default-Route."
  fi
}

verify_static_interface "$ETH5_INTERFACE" "$ETH5_ADDRESS"
verify_static_interface "$ETH6_INTERFACE" "$ETH6_ADDRESS"

[[ "$(tailscale ip -4 | head -n 1)" == "$TAILSCALE_IP" ]] \
  || die 'Die Tailscale-IP ist nach der Einrichtung nicht mehr erreichbar.'

sudo docker info >/dev/null
if [[ "$IS_JETSON" == '1' ]]; then
  docker_runtime_names="$(sudo docker info --format '{{range $name, $_ := .Runtimes}}{{println $name}}{{end}}')"
  grep -Fx 'nvidia' <<<"$docker_runtime_names" >/dev/null \
    || die 'Docker kennt die NVIDIA-Runtime nicht.'
fi

if [[ "$SKIP_VNC" != '1' ]]; then
  systemctl --user is-enabled --quiet jetson-vnc.service \
    || die 'jetson-vnc.service ist nicht fuer den Benutzerstart aktiviert.'
  systemctl --user is-active --quiet jetson-vnc.service \
    || die 'jetson-vnc.service laeuft nicht.'
  vnc_ready=0
  for _attempt in {1..20}; do
    if ss -ltn | awk '{print $4}' | grep -Fqx "$TAILSCALE_IP:5901"; then
      vnc_ready=1
      break
    fi
    sleep 1
  done
  [[ "$vnc_ready" == '1' ]] || die "VNC lauscht nicht an $TAILSCALE_IP:5901."
fi

if [[ "$ENABLE_UFW" == '1' ]]; then
  sudo env LC_ALL=C ufw status | grep -q '^Status: active' || die 'UFW ist nicht aktiv.'
fi

log 'Installation abgeschlossen'
printf 'Statische Netze:  %s = %s, %s = %s\n' \
  "$ETH5_INTERFACE" "$ETH5_ADDRESS" "$ETH6_INTERFACE" "$ETH6_ADDRESS"
printf 'Orbbec-Freigabe:   %s:%s/udp -> %s auf %s\n' \
  "$ORBBEC_CAMERA_IP" "$ORBBEC_UDP_SOURCE_PORT" "$ORBBEC_HOST_IP" "$ETH5_INTERFACE"
printf 'Tailscale-IP:      %s\n' "$TAILSCALE_IP"
if [[ "$SKIP_VNC" != '1' ]]; then
  printf 'VNC-Adresse:       vnc://%s:5901\n' "$TAILSCALE_IP"
fi
printf 'Sicherung:         %s\n' "$BACKUP_DIRECTORY"
printf 'Installationslog:  %s\n' "$INSTALL_LOG"
printf '\nHinweis: Die Docker-Gruppenzugehoerigkeit gilt in neuen Anmeldesitzungen.\n'
sudo chmod 0600 "$INSTALL_LOG"
