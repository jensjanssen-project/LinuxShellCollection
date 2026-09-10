# Advantech Jetson für PIDVISION einrichten

`install-jetson.sh` richtet den Rechner aus der bisherigen Installationsnotiz
vollständig ein. Dazu gehören:

- SSH, UFW-Grundregeln, Chromium, Docker, NVIDIA-Container-Runtime und Tailscale
- statische IPv4-Adressen für `eth5` (`192.168.1.11/24`) und `eth6`
  (`192.168.11.110/24`), jeweils ohne Gateway und DNS
- Klonen, Bauen und Starten von `pidvision-studio`
- ein nur an Tailscale gebundener GNOME-VNC-Server auf Port 5901
- Sicherungen der vorhandenen Netzwerk-, UFW- und Docker-Konfiguration
- abschließende Prüfungen aller Dienste, Adressen, Routen und Container

Getestetes Zielsystem ist ein NVIDIA Jetson mit Ubuntu 22.04 und mindestens
30 GB freiem Speicher. `eth5` und `eth6` werden zusätzlich anhand der bekannten
MAC-Adressen dieses Rechners geprüft, bevor ihre Konfiguration geändert wird.

## Start

Das Skript als normaler Desktop-Benutzer ausführen, **nicht** mit `sudo bash`:

```bash
curl -fLO https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Jetson_setup/install-jetson.sh
curl -fLO https://raw.githubusercontent.com/jensjanssen-project/LinuxShellCollection/main/Jetson_setup/SHA256SUMS
sha256sum --check SHA256SUMS
chmod +x install-jetson.sh
./install-jetson.sh
```

Für einen fest reproduzierbaren Produktiveinsatz sollte `main` in beiden URLs
durch einen vorhandenen Release-Tag wie `v1.0.0` ersetzt werden. Dadurch wird
nicht unbemerkt eine später veränderte Version ausgeführt.

Das GitLab-Repository `pidvision-studio` ist nicht anonym erreichbar. Vor der
Installation muss deshalb für den ausführenden Benutzer ein GitLab-Zugang
vorhanden sein. Für automatische Installationen wird eine SSH-URL mit Deploy-Key
empfohlen, beispielsweise:

```bash
APP_REPOSITORY=git@gitlab.com:pidvision/pidvision-studio.git \
./install-jetson.sh
```

Der Deploy-Key und der geprüfte GitLab-Host-Key müssen vorher im Benutzerkonto
eingerichtet sein; private Schlüssel gehören nicht in das öffentliche
Installer-Repository.

Beim ersten interaktiven Lauf werden die Tailscale-Anmeldung und ein
VNC-Passwort abgefragt. Das VNC-Passwort muss 6 bis 8 Zeichen lang sein.

## Unbeaufsichtigter Lauf

Geheimnisse sollten nicht in das öffentliche Repository geschrieben werden.
Für einen automatischen Lauf können sie aus nur lokal lesbaren Dateien kommen:

```bash
chmod 600 /pfad/zu/tailscale-auth-key /pfad/zu/vnc-passwort
APP_REPOSITORY=git@gitlab.com:pidvision/pidvision-studio.git \
TAILSCALE_AUTH_KEY_FILE=/pfad/zu/tailscale-auth-key \
VNC_PASSWORD_FILE=/pfad/zu/vnc-passwort \
NONINTERACTIVE=1 \
./install-jetson.sh
```

Alternativ werden `TAILSCALE_AUTH_KEY` und `VNC_PASSWORD` unterstützt. Die
Dateivariante ist für den Tailscale-Schlüssel sicherer, weil der Schlüssel nicht
als Klartextargument in der Prozessliste erscheint.

## Abweichende Hardware

Die voreingestellten MAC-Adressen stammen von dem dokumentierten Rechner. Bei
einem anderen Gerät müssen sie ausdrücklich angegeben werden:

```bash
ETH5_EXPECTED_MAC=aa:bb:cc:dd:ee:ff \
ETH6_EXPECTED_MAC=11:22:33:44:55:66 \
./install-jetson.sh
```

Ein leerer Wert deaktiviert den MAC-Abgleich. Andere Ubuntu-Versionen oder
Nicht-Jetson-Systeme benötigen zusätzlich `ALLOW_UNTESTED_SYSTEM=1` und gelten
als ungetestet.

## Firewall und Wiederholungsläufe

UFW wird standardmäßig nach dem Einrichten von SSH und VNC aktiviert. Mit
`ENABLE_UFW=0` werden die Regeln nur gespeichert. Von Docker auf allen
Host-Adressen veröffentlichte Ports können UFW umgehen; das Skript meldet solche
Ports am Ende, verändert sie ohne Kenntnis der PIDVISION-Anforderungen aber
nicht automatisch.

Vorhandene Konfigurationen werden unter
`/var/backups/pidvision-installer/<zeitstempel>` gesichert. Das vollständige
Protokoll liegt unter `/var/log/pidvision-install-<zeitstempel>.log` und ist nur
für root lesbar.

Ein erneuter Lauf aktualisiert ein sauberes `pidvision-studio`-Repository und
baut die Container neu. Lokale Änderungen im Repository werden nicht
überschrieben. Mit `SKIP_APP_BUILD=1` oder `SKIP_VNC=1` lassen sich diese Schritte
gezielt auslassen. Alle Einstellungen zeigt `./install-jetson.sh --help`.
