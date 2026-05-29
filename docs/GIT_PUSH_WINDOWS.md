# První push na Git z Windows

Rozbal ZIP například do `C:\Work\projects\objednavka-ng-rpi-installer` a otevři v této složce Git Bash.

```bash
./tools/validate_project.sh
git init
git branch -M main
git add .
git status
git commit -m "Initial ObjednavkaNG Raspberry Pi installer v0.7.0"
git remote add origin git@github.com:H0nz4k/objednavka-ng-rpi-installer.git
git push -u origin main
```

Před commitem ověř, že se necommitují `files/objednavka-ng.AppImage`, `files/teamviewer.deb`, `files/config.json` ani `files/SHA256SUMS`.

AppImage má přibližně 125 MB; pokud ji budeš chtít verzovat, použij Git LFS nebo Release asset. Pro první push doporučuji binárky nepřidávat.
