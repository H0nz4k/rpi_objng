# Nahraje / resetuje / instaluje ObjednavkaNG balik na Raspberry Pi.
#
# Pouziti:
#   .\deploy.ps1                         # jen nahraje .tar.gz (zbuildi pokud je treba)
#   .\deploy.ps1 -Reset                  # vrati firstboot na zacatek + reboot
#   .\deploy.ps1 -Reset -Factory         # hlubsi reset (/opt/objednavka-ng pryc)
#   .\deploy.ps1 -Install                # nahraje + setup-master-img + reboot
#   .\deploy.ps1 -TestCycle              # Reset + nahrat + instalovat + reboot
#   .\deploy.ps1 -Build -TestCycle       # cely testovaci cyklus s novym archivem
#
# Konfigurace: deploy.config.ps1 (Password + .gitignore)

[CmdletBinding()]
param(
    [string]$RemoteHost,
    [string]$User,
    [string]$RemoteDir,
    [string]$PackageDir,
    [string]$Password,
    [string]$SudoPassword,
    [switch]$Build,
    [switch]$Reset,
    [switch]$Factory,
    [switch]$Install,
    [switch]$TestCycle,
    [switch]$NoReboot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$ConfigPath = Join-Path $Root 'deploy.config.ps1'
$Defaults = @{
    RemoteHost = '192.168.1.2'
    User       = 'objng'
    RemoteDir  = '/home/objng'
    PackageDir = ''
}
$DeployPassword = ''
$DeploySudoPassword = ''
$script:DeploySshSession = $null

if (Test-Path $ConfigPath) {
    $fileCfg = & $ConfigPath
    foreach ($key in @($fileCfg.Keys)) {
        if ($key -eq 'Password') {
            if ($null -ne $fileCfg[$key] -and "$($fileCfg[$key])" -ne '') {
                $DeployPassword = [string]$fileCfg[$key]
            }
            continue
        }
        if ($key -eq 'SudoPassword') {
            if ($null -ne $fileCfg[$key] -and "$($fileCfg[$key])" -ne '') {
                $DeploySudoPassword = [string]$fileCfg[$key]
            }
            continue
        }
        if ($Defaults.ContainsKey($key) -and $null -ne $fileCfg[$key] -and "$($fileCfg[$key])" -ne '') {
            $Defaults[$key] = [string]$fileCfg[$key]
        }
    }
}

if ($PSBoundParameters.ContainsKey('RemoteHost')) { $Defaults.RemoteHost = $RemoteHost }
if ($PSBoundParameters.ContainsKey('User')) { $Defaults.User = $User }
if ($PSBoundParameters.ContainsKey('RemoteDir')) { $Defaults.RemoteDir = $RemoteDir }
if ($PSBoundParameters.ContainsKey('PackageDir')) { $Defaults.PackageDir = $PackageDir }
if ($PSBoundParameters.ContainsKey('Password')) { $DeployPassword = $Password }
if ($PSBoundParameters.ContainsKey('SudoPassword')) { $DeploySudoPassword = $SudoPassword }
if (-not $DeploySudoPassword -and $DeployPassword) {
    $DeploySudoPassword = $DeployPassword
}

$wantReset = $Reset.IsPresent -or $TestCycle.IsPresent
$wantInstall = $Install.IsPresent -or $TestCycle.IsPresent

function Get-LatestPackageDir {
    param([string]$BasePath, [string]$Preferred)

    if ($Preferred) {
        $path = Join-Path $BasePath $Preferred
        if (-not (Test-Path $path)) {
            throw "Slozka baliku neexistuje: $path"
        }
        return (Resolve-Path $path).Path
    }

    $candidate = Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' } |
        Sort-Object { [int]$_.Name } -Descending |
        Select-Object -First 1

    if (-not $candidate) {
        throw "Nenalezena zadna cislovana slozka baliku (214, 215, ...) v $BasePath"
    }
    return $candidate.FullName
}

function Build-PackageArchive {
    param(
        [string]$SourceDir,
        [string]$ArchivePath
    )

    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path $tar)) {
        throw "Nenalezen tar.exe ($tar)."
    }

    $folderName = Split-Path $SourceDir -Leaf
    $parent = Split-Path $SourceDir -Parent

    if (Test-Path $ArchivePath) {
        Remove-Item $ArchivePath -Force
    }

    Write-Host "Balim: $folderName -> $(Split-Path $ArchivePath -Leaf)" -ForegroundColor Cyan
    & $tar -czf $ArchivePath -C $parent $folderName
    if ($LASTEXITCODE -ne 0) {
        throw "tar selhal, kod $LASTEXITCODE"
    }
}

function Test-ArchiveStale {
    param(
        [string]$SourceDir,
        [string]$ArchivePath
    )

    if (-not (Test-Path $ArchivePath)) { return $true }

    $archiveTime = (Get-Item $ArchivePath).LastWriteTimeUtc
    $newestSource = Get-ChildItem -Path $SourceDir -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if (-not $newestSource) { return $false }
    return $newestSource.LastWriteTimeUtc -gt $archiveTime
}

function Escape-BashSingleQuoted {
    param([string]$Value)
    if (-not $Value) { return '' }
    return ($Value -replace "'", "'\\''")
}

function Wrap-RemoteScript {
    param([string]$Body)

    $escaped = Escape-BashSingleQuoted $DeploySudoPassword
    @"
set -Eeuo pipefail
DEPLOY_SUDO_PW='$escaped'
deploy_sudo() {
  if [[ -n "`${DEPLOY_SUDO_PW:-}" ]]; then
    printf '%s\n' "`$DEPLOY_SUDO_PW" | sudo -S -p '' "`$@"
  else
    sudo -n "`$@" 2>/dev/null || sudo "`$@"
  fi
}

$Body
"@
}

function Test-UsePoshSsh {
    if (-not $DeployPassword) { return $false }
    return [bool](Get-Module -ListAvailable -Name Posh-SSH)
}

function Ensure-PoshSshModule {
    if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
        throw @"
Modul Posh-SSH neni nainstalovan.

Spust jednoraze:
  Install-Module -Name Posh-SSH -Scope CurrentUser -Force

Nebo heslo v deploy.config.ps1 smaz a pouzij SSH klic / rucni zadani hesla pri scp.
"@
    }
    Import-Module Posh-SSH -ErrorAction Stop | Out-Null
}

function Get-DeployCredential {
    if (-not $DeployPassword) {
        throw 'Get-DeployCredential volano bez hesla.'
    }
    $secure = ConvertTo-SecureString $DeployPassword -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($Defaults.User, $secure)
}

function Connect-DeploySession {
    Ensure-PoshSshModule
    if ($script:DeploySshSession) {
        return $script:DeploySshSession
    }
    $cred = Get-DeployCredential
    $session = New-SSHSession -ComputerName $Defaults.RemoteHost -Credential $cred -AcceptKey -ErrorAction Stop
    $script:DeploySshSession = $session
    return $session
}

function Close-DeploySession {
    if ($script:DeploySshSession) {
        Remove-SSHSession -SessionId $script:DeploySshSession.SessionId -ErrorAction SilentlyContinue | Out-Null
        $script:DeploySshSession = $null
    }
}

function Assert-SshTools {
    if (Test-UsePoshSsh) {
        Ensure-PoshSshModule
        return
    }
    if ($DeployPassword -and -not (Get-Module -ListAvailable -Name Posh-SSH)) {
        Write-Host "Posh-SSH neni nainstalovan: SSH heslo zadas rucne (2x). Sudo jde z configu automaticky." -ForegroundColor Yellow
        Write-Host "Tip: Install-Module -Name Posh-SSH -Scope CurrentUser -Force" -ForegroundColor DarkGray
    }
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        throw "Prikaz ssh neni v PATH. Nainstaluj OpenSSH Client."
    }
    if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
        throw "Prikaz scp neni v PATH. Nainstaluj OpenSSH Client."
    }
}

function Invoke-RemoteShell {
    param([string]$Script)

    $fullScript = Wrap-RemoteScript -Body $Script

    if (Test-UsePoshSsh) {
        $session = Connect-DeploySession
        $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($fullScript))
        $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "echo $b64 | base64 -d | bash -s" -TimeOut 7200
        if ($result.Output) {
            $result.Output | ForEach-Object { Write-Host $_ }
        }
        if ($result.ExitStatus -ne 0) {
            if ($result.Error) {
                $result.Error | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            }
            throw "Vzdaleny prikaz selhal, kod $($result.ExitStatus)"
        }
        return
    }

    $target = "{0}@{1}" -f $Defaults.User, $Defaults.RemoteHost
    $fullScript | & ssh -t -o BatchMode=no -o StrictHostKeyChecking=accept-new $target 'bash -s'
    # Kod 1 po rebootu = SSH spojeni spadlo pri restartu = OK
    if ($LASTEXITCODE -notin @(0, 1, 255)) {
        throw "Vzdaleny prikaz selhal, kod $LASTEXITCODE"
    }
}

function Invoke-RemoteReset {
    param([bool]$UseFactory, [bool]$Reboot)

    $factoryArg = if ($UseFactory) { ' --factory' } else { '' }
    $rebootCmd = if ($Reboot) { 'deploy_sudo reboot; sleep 3 || true' } else { 'echo "Reboot preskocen (-NoReboot)."' }

    Write-Host "Resetuji firstboot na ${RemoteTarget}..." -ForegroundColor Yellow
    $script = @"
if command -v reset-objng-firstboot >/dev/null 2>&1; then
  deploy_sudo reset-objng-firstboot$factoryArg
elif [[ -x `$HOME/bin/reset-objng-firstboot.sh ]]; then
  deploy_sudo `$HOME/bin/reset-objng-firstboot.sh$factoryArg
else
  echo "CHYBA: reset-objng-firstboot neni na zarizeni. Nejdriv spust -Install." >&2
  exit 1
fi
$rebootCmd
"@
    Invoke-RemoteShell -Script $script
}

function Invoke-RemoteInstall {
    param(
        [string]$PackageName,
        [bool]$Reboot
    )

    $rebootCmd = if ($Reboot) { 'deploy_sudo reboot; sleep 3 || true' } else { 'echo "Reboot preskocen (-NoReboot)."' }
    $remoteDir = $Defaults.RemoteDir

    Write-Host "Instaluji balik $PackageName na ${RemoteTarget}..." -ForegroundColor Cyan
    $script = @"
PKG='$PackageName'
REMOTE='$remoteDir'
ARCH="`${REMOTE}/`${PKG}.tar.gz"
[[ -f "`$ARCH" ]] || { echo "CHYBA: chybi `$ARCH" >&2; exit 1; }
cd "`$REMOTE"
rm -rf "`$REMOTE/objng_master_boot_v2"
tar -xzf "`$ARCH"
SETUP="`$(find "`$PKG" -type f -name setup-master-img.sh | head -1)"
[[ -n "`$SETUP" ]] || { echo "CHYBA: setup-master-img.sh nenalezen v `$PKG" >&2; exit 1; }
cd "`$(dirname "`$SETUP")"
chmod +x ./setup-master-img.sh
deploy_sudo ./setup-master-img.sh
$rebootCmd
"@
    Invoke-RemoteShell -Script $script
}

function Send-PackageArchive {
    param([string]$ArchivePath, [string]$PackageName)

    $remoteFile = "$($Defaults.RemoteDir.TrimEnd('/'))/$PackageName.tar.gz"
    $sizeMb = [math]::Round((Get-Item $ArchivePath).Length / 1MB, 1)

    if (Test-UsePoshSsh) {
        Ensure-PoshSshModule
        $cred = Get-DeployCredential
        Write-Host "Nahravam $sizeMb MB -> ${RemoteTarget}:$remoteFile" -ForegroundColor Cyan
        Set-SCPItem -ComputerName $Defaults.RemoteHost -Credential $cred -Path $ArchivePath -Destination $remoteFile -AcceptKey -ErrorAction Stop
        return
    }

    $remote = "{0}@{1}:{2}/" -f $Defaults.User, $Defaults.RemoteHost, $Defaults.RemoteDir.TrimEnd('/')
    Write-Host "Nahravam $sizeMb MB -> ${remote}${PackageName}.tar.gz" -ForegroundColor Cyan
    & scp $ArchivePath "${remote}"
    if ($LASTEXITCODE -ne 0) {
        throw "scp selhal, kod $LASTEXITCODE"
    }
}

try {
    $RemoteTarget = "{0}@{1}" -f $Defaults.User, $Defaults.RemoteHost
    $doDeploy = (-not $wantReset) -or $wantInstall
    $doResetOnly = $wantReset -and (-not $wantInstall)
    $doReboot = -not $NoReboot.IsPresent

    Assert-SshTools

    $packageDirPath = Get-LatestPackageDir -BasePath $Root -Preferred $Defaults.PackageDir
    $packageName = Split-Path $packageDirPath -Leaf
    $archivePath = Join-Path $Root "$packageName.tar.gz"

    if ($doResetOnly) {
        Invoke-RemoteReset -UseFactory $Factory.IsPresent -Reboot $doReboot
        Write-Host ""
        Write-Host "Reset dokoncen. Po rebootu zacne firstboot od kalibrace." -ForegroundColor Green
        return
    }

    if ($doDeploy) {
        $needsBuild = $Build.IsPresent -or -not (Test-Path $archivePath) -or (Test-ArchiveStale -SourceDir $packageDirPath -ArchivePath $archivePath)
        if ($needsBuild) {
            Build-PackageArchive -SourceDir $packageDirPath -ArchivePath $archivePath
        } else {
            Write-Host "Pouzivam existujici archiv: $archivePath" -ForegroundColor DarkGray
        }
        Send-PackageArchive -ArchivePath $archivePath -PackageName $packageName
    }

    if ($wantReset -and $wantInstall) {
        Invoke-RemoteReset -UseFactory $Factory.IsPresent -Reboot $false
    }

    if ($wantInstall) {
        Invoke-RemoteInstall -PackageName $packageName -Reboot $doReboot
        Write-Host ""
        Write-Host "Instalace spustena. Po rebootu pobezi firstboot." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "Balik nahran. Na RPi rucne:" -ForegroundColor Green
    Write-Host @"

  cd $($Defaults.RemoteDir)
  tar -xzf $packageName.tar.gz
  cd $packageName/ObjednavkaNG_MASTER_BOOT_v2.*/objng_master_boot_v2
  sudo ./setup-master-img.sh
  sudo reboot

Nebo: .\deploy.ps1 -Install   |   .\deploy.ps1 -TestCycle

"@
}
finally {
    Close-DeploySession
}
