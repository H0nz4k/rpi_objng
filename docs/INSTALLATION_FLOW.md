# Instalační tok

1. Existuje uživatel `objng`.
2. Do `files/` jsou lokálně vloženy binárky a config.
3. `install.sh` vytvoří config před spuštěním AppImage.
4. Nastaví `/opt/objednavka-ng`, autologin, splash, scale, TeamViewer a servisní příkazy.
5. Po rebootu `objng-dokoncit` provede čtečku, TeamViewer a dotyk.
6. Po ověření se zapne kiosk přes `kiosk-on`.
