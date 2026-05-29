# TeamViewer Full

Nekopíruje se `global.conf` ze starého zařízení ani žádné ID, certifikáty, klíče nebo hash hesla. Přiřazení účtu a heslo se řeší příkazy `teamviewer setup` a `teamviewer passwd` přes wizard `teamviewer-dokoncit`.

Volitelné experimentální lokální preference:

```bash
sudo teamviewer-lokalni-volby preview
sudo teamviewer-lokalni-volby apply
sudo teamviewer-lokalni-volby restore
```

Blokování/povolení APT aktualizací:

```bash
sudo teamviewer-updates-off
sudo teamviewer-updates-on
```
