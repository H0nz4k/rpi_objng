# Lokální instalační soubory

Tato složka obsahuje podklady, které instalátor kopíruje do Raspberry Pi.

## Soubory vložené lokálně před instalací

Do této složky přidej:

```text
objednavka-ng.AppImage   # aplikace ObjednávkaNG, přibližně 125 MB
teamviewer.deb            # TeamViewer Full ARM64 Debian balíček
config.json               # skutečná konfigurace konkrétní instalace
```

Soubor `config.json` je v distribuovaném ZIPu připravený pro lokální test, ale `.gitignore` jej ve výchozím stavu neodešle na Git. Do repozitáře patří pouze `config.example.json`.

Sledované soubory v Gitu:

```text
config.example.json
splash-image.tga
splash-image-preview.png
```

Ignorované lokální soubory:

```text
objednavka-ng.AppImage
teamviewer.deb
config.json
SHA256SUMS
```

Po vložení lokálních souborů vytvoř kontrolní součty:

```bash
./tools/build_SHA256SUMS.sh
```
