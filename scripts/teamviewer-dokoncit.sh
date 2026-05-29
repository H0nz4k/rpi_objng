#!/usr/bin/env bash
set -Eeuo pipefail
EMAIL_HINT="hamouz@altisima.cz"
[[ "$EUID" -ne 0 ]] || { echo "Spusť jako běžný uživatel, bez sudo." >&2; exit 1; }
command -v teamviewer >/dev/null 2>&1 || { echo "TeamViewer není nainstalovaný." >&2; exit 1; }
echo "============================================================"; echo " TeamViewer Full – dokončení instalace"; echo "============================================================"; echo
sudo systemctl enable --now teamviewerd
teamviewer info 2>/dev/null || true
echo
read -r -p "Přiřadit toto zařízení k TeamViewer účtu nyní? [A/n] " setup_ans
if [[ "${setup_ans:-A}" =~ ^[AaYy]$ ]]; then
  echo "Ve výzvě TeamVieweru použij e-mail: ${EMAIL_HINT}"
  echo "Heslo účtu zadáváš přímo TeamVieweru; tento skript ho nečte ani neukládá."
  sudo teamviewer setup || echo "Setup nebyl dokončen; můžeš jej později zopakovat: teamviewer-dokoncit"
fi
echo
read -r -p "Nastavit pevné servisní heslo pro bezobslužný přístup? [A/n] " pass_ans
if [[ "${pass_ans:-A}" =~ ^[AaYy]$ ]]; then echo "Spouštím TeamViewer nastavení hesla; heslo se neukládá do instalátoru ani logu."; sudo teamviewer passwd || echo "Nastavení hesla nebylo dokončeno."; fi
echo
read -r -p "Zobrazit krok pro LAN připojení a české rozhraní? [A/n] " prefs_ans
if [[ "${prefs_ans:-A}" =~ ^[AaYy]$ ]]; then
  cat <<'EOF'
Nastavení ověř v TeamViewer Full GUI:
  Settings → General → Incoming LAN Connections → Accept
  Language / Jazyk → Čeština

Balíček obsahuje i experimentální lokální patch pouze těchto dvou voleb:
  sudo teamviewer-lokalni-volby preview
  sudo teamviewer-lokalni-volby apply

Patch vždy vytváří zálohu global.conf, ale není oficiální konfigurační metoda TeamVieweru;
proto jej použij až po ověření na testovacím terminálu.
EOF
fi
echo
read -r -p "Zablokovat aktualizaci TeamViewer balíčku přes APT? [A/n] " update_ans
if [[ "${update_ans:-A}" =~ ^[AaYy]$ ]]; then sudo teamviewer-updates-off; echo "V TeamViewer GUI navíc zkontroluj automatickou instalaci nových verzí."; fi
echo; echo "Alias zařízení změň ručně ve svém TeamViewer seznamu podle konkrétního terminálu."
