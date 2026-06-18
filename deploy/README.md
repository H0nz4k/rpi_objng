# deploy – Windows PowerShell nasazení

## Konfigurace

Zkopíruj `deploy.config.ps1.example` → `deploy.config.ps1` a vyplň:

```powershell
@{
    RemoteHost   = '192.168.1.2'   # IP Raspberry Pi
    User         = 'objng'
    RemoteDir    = '/home/objng'
    PackageDir   = ''              # prazdne = automaticky nejnovejsi cislovana slozka
    Password     = 'heslo'         # volitelne SSH heslo (vyzaduje Posh-SSH modul)
    SudoPassword = ''              # volitelne sudo heslo (defaultuje na Password)
}
```

`deploy.config.ps1` je v `.gitignore` – nikdy se necommituje.

## Prikazy

```powershell
# Prvni instalace na ciste zarizeni
.\deploy\deploy.ps1 -Build -Install

# Reset + reinstalace
.\deploy\deploy.ps1 -Build -Reset -Install

# Jen reset firstbootu (bez instalace)
.\deploy\deploy.ps1 -Reset

# Hluboky reset (smaze /opt/objednavka-ng)
.\deploy\reset-remote.ps1 -Factory

# Plny test cyklus (build + reset + install + reboot)
.\deploy\deploy.ps1 -TestCycle
```

## Parametry deploy.ps1

| Parametr | Popis |
|----------|-------|
| `-Build` | Zabali nejnovejsi slozku do .tar.gz |
| `-Install` | Nahraje archiv a spusti setup-master-img.sh |
| `-Reset` | Spusti reset-objng-firstboot na RPi |
| `-Factory` | S `-Reset`: hlubsy reset (smaze /opt/objednavka-ng) |
| `-TestCycle` | Reset + Build + Install (full cyklus) |
| `-NoReboot` | Nerebootuje po instalaci |
| `-RemoteHost` | Prepisat IP z konfigurace |
