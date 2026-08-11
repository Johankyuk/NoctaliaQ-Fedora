#!/usr/bin/env bash
# Instala el modulo de energia ARCHIVADO de NoctaliaQ (portado de horus-nix):
# fan curves quiet/balanced/performance, perfiles power-profiles-daemon,
# switch hibrido por firmware, cap de CPU por fuente. Requiere asusctl y
# power-profiles-daemon ya instalados — este script no los instala.
#
# ARCHIVADO el 2026-08-06: superseded por scripts/noctaliaq-gpu.sh (modo GPU
# de 3 vias, sin fan-curves) + scripts/noctaliaq-battery.sh + asusd/asusctl
# ya no son requeridos para GPU/bateria/teclado. Este instalador depende de
# asusd corriendo -- si seguiste la migracion a "cero asusd", NO lo corras.
# Ver archive/README.md para el detalle completo de la decision.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== NoctaliaQ energy installer (ARCHIVADO, requiere asusd) =="
read -rp "Este modulo depende de asusd y duplica cosas que ahora hace scripts/noctaliaq-gpu.sh. ¿Seguro que quieres instalarlo? [s/N] " _confirm
case "$_confirm" in [sS]) ;; *) echo "cancelado."; exit 0 ;; esac

for c in asusctl powerprofilesctl; do
    command -v "$c" >/dev/null 2>&1 || {
        echo "ERROR: falta '$c' en PATH. Instala asusctl y power-profiles-daemon primero."
        exit 1
    }
done

echo "-> Copiando binarios a /usr/local/bin (pide sudo)..."
sudo install -m 755 "$DIR"/bin/* /usr/local/bin/

echo "-> Instalando unit de sistema (fan curves al boot)..."
sudo install -m 644 "$DIR/systemd/system/noctaliaq-fan-curves.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now noctaliaq-fan-curves.service

echo "-> Habilitando dependencias de sistema si no estan activas..."
sudo systemctl enable --now power-profiles-daemon.service asusd.service

echo "-> Instalando unit de usuario (vigilante PRIME + fan curve performance)..."
mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$DIR/systemd/user/noctaliaq-gpu-watch.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now noctaliaq-gpu-watch.service

echo "-> Instalando sudoers NOPASSWD para noctaliaq-cpu-cap (pide sudo)..."
sed "s/__USER__/$(whoami)/" "$DIR/sudoers.d/noctaliaq-cpu-cap" | sudo tee /etc/sudoers.d/noctaliaq-cpu-cap >/dev/null
sudo chmod 440 /etc/sudoers.d/noctaliaq-cpu-cap
sudo visudo -c -f /etc/sudoers.d/noctaliaq-cpu-cap || {
    echo "ERROR: sudoers invalido, revirtiendo."
    sudo rm -f /etc/sudoers.d/noctaliaq-cpu-cap
    exit 1
}

echo "== listo =="
echo "Estado: noctaliaq-power --actual"
echo "Logs del vigilante: journalctl --user -u noctaliaq-gpu-watch -f"
