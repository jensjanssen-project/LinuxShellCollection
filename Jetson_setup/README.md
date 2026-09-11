# Advantech Jetson für PIDVISION einrichten

`install-jetson.sh` richtet den Rechner aus der bisherigen Installationsnotiz
vollständig ein. Dazu gehören:

- SSH, UFW-Grundregeln, Chromium, Docker, NVIDIA-Container-Runtime und Tailscale
- statische IPv4-Adressen für `eth5` (`192.168.1.11/24`) und `eth6`
  (`192.168.11.110/24`), jeweils ohne Gateway und DNS
- eine auf Kamera-IP, Schnittstelle und UDP-Quellport beschränkte UFW-Freigabe
  für die Orbbec-PoE-Kamera (`192.168.1.10`, UDP-Quellport `3956`)
- ein nur an Tailscale gebundener GNOME-VNC-Server auf Port 5901
- Sicherungen der vorhandenen Netzwerk-, UFW- und Docker-Konfiguration
- abschließende Prüfungen aller Dienste, Adressen, Routen und der Docker-Runtime

Das Skript lädt `pidvision-studio` bewusst nicht herunter und installiert oder
startet keine PIDVISION-Anwendung.

Für die NVIDIA-Container-Runtime richtet das Skript die offizielle
NVIDIA-Toolkit-Paketquelle separat ein. Dadurch funktioniert die Installation
auch auf Advantech-Images mit deaktivierten JetPack-L4T-Paketquellen.

Getestetes Zielsystem ist ein NVIDIA Jetson mit Ubuntu 22.04 und mindestens
30 GB freiem Speicher. Das Skript prüft, ob `eth5` und `eth6` vorhanden sind.
Ein zusätzlicher MAC-Abgleich kann bei Bedarf ausdrücklich aktiviert werden.

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
durch einen vorhandenen Release-Tag wie `v1.0.5` ersetzt werden. Dadurch wird
nicht unbemerkt eine später veränderte Version ausgeführt.

Beim ersten interaktiven Lauf werden die Tailscale-Anmeldung und ein
VNC-Passwort abgefragt. Das VNC-Passwort muss 6 bis 8 Zeichen lang sein.

## Unbeaufsichtigter Lauf

Geheimnisse sollten nicht in das öffentliche Repository geschrieben werden.
Für einen automatischen Lauf können sie aus nur lokal lesbaren Dateien kommen:

```bash
chmod 600 /pfad/zu/tailscale-auth-key /pfad/zu/vnc-passwort
TAILSCALE_AUTH_KEY_FILE=/pfad/zu/tailscale-auth-key \
VNC_PASSWORD_FILE=/pfad/zu/vnc-passwort \
NONINTERACTIVE=1 \
./install-jetson.sh
```

Alternativ werden `TAILSCALE_AUTH_KEY` und `VNC_PASSWORD` unterstützt. Die
Dateivariante ist für den Tailscale-Schlüssel sicherer, weil der Schlüssel nicht
als Klartextargument in der Prozessliste erscheint.

## Abweichende Hardware

Wenn die Portzuordnung zusätzlich abgesichert werden soll, können die erwarteten
MAC-Adressen ausdrücklich angegeben werden:

```bash
ETH5_EXPECTED_MAC=aa:bb:cc:dd:ee:ff \
ETH6_EXPECTED_MAC=11:22:33:44:55:66 \
./install-jetson.sh
```

Ohne diese Variablen findet kein MAC-Abgleich statt. Andere Ubuntu-Versionen
oder Nicht-Jetson-Systeme benötigen zusätzlich `ALLOW_UNTESTED_SYSTEM=1` und
gelten als ungetestet.

## Firewall und Wiederholungsläufe

UFW wird standardmäßig nach dem Einrichten von SSH und VNC aktiviert. Mit
`ENABLE_UFW=0` werden die Regeln nur gespeichert. Später von Docker auf allen
Host-Adressen veröffentlichte Anwendungsports können UFW umgehen und müssen bei
der separaten Anwendungsinstallation berücksichtigt werden.

Für die Orbbec-PoE-Kamera wird eingehender UDP-Verkehr von `192.168.1.10:3956`
auf die erste statische Host-Adresse erlaubt. Der Zielport ist absichtlich nicht
fest vorgegeben: Das Orbbec SDK handelt für jeden Verbindungsversuch einen neuen
dynamischen lokalen UDP-Port aus. Die Regel gilt trotzdem nur für die bekannte
Kamera-IP, ihren festen Quellport und die konfigurierte Kamera-Schnittstelle.

Bei einer abweichenden Kamera-IP oder einem anderen UDP-Quellport können die
Werte beim Start angepasst werden:

```bash
ORBBEC_CAMERA_IP=192.168.1.20 \
ORBBEC_UDP_SOURCE_PORT=3956 \
./install-jetson.sh
```

Die Kamera-Schnittstelle und Host-IP folgen `ETH5_INTERFACE` und `ETH5_ADDRESS`.
Auf dem aktuell eingerichteten Jetson ist das beispielsweise `eth1` und
`192.168.1.11/24`, wenn der Installer mit `ETH5_INTERFACE=eth1` gestartet wird.

Vorhandene Konfigurationen werden unter
`/var/backups/pidvision-installer/<zeitstempel>` gesichert. Das vollständige
Protokoll liegt unter `/var/log/pidvision-install-<zeitstempel>.log` und ist nur
für root lesbar.

Ein erneuter Lauf überprüft und aktualisiert die Systemkonfiguration, ohne eine
Anwendung zu installieren. Mit `SKIP_VNC=1` lässt sich die VNC-Einrichtung
auslassen. Alle Einstellungen zeigt `./install-jetson.sh --help`.
