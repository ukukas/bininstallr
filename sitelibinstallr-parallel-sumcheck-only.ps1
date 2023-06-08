$pkgroot = Resolve-Path ".\packages" -ErrorAction "Stop"
$threads = 8

$ProgressPreference = "SilentlyContinue"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "PowerShell 7.0 or above required for parallel operation"
    Exit 1
}

do {$tmpdir = Join-Path $env:TEMP (New-Guid)} while (Test-Path $tmpdir)
New-Item $tmpdir -ItemType "directory" -Force -ErrorAction "Stop" | Out-Null

Get-ChildItem $pkgroot -Filter "?.?" -Directory -ErrorAction "Stop" |
Where-Object {$_.Name -match "^[0-9].[0-9]$"} |
Get-ChildItem -Filter "*.zip" -File -ErrorAction "Stop" |
ForEach-Object -Parallel {
    $rver = $_.Directory.Name
    $installdir = Join-Path $using:tmpdir $rver
    $pkgname = $_.Name.Split("_")[0]
    $pkgver = $_.Name.Split("_")[1].TrimEnd(".zip")
    $pkgdir =  Join-Path $installdir $pkgname
    $md5file = Join-Path $pkgdir "MD5"
    $success = $true
    Expand-Archive $_.FullName $installdir -Force -ErrorAction "Ignore"
    if (Test-Path $md5file) {
        Get-Content $md5file | ForEach-Object {
            $hash = $_.Split(" ")[0]
            $file = Join-Path $pkgdir $_.Split(" ")[1].TrimStart("*")
            if (Test-Path $file) {
                if ((Get-FileHash $file -Algorithm "MD5").Hash -ne $hash) {
                    Set-Variable -Name "success" -Value $false
                }
            } else { Set-Variable -Name "success" -Value $false }
        }
    } else { Set-Variable -Name "success" -Value $false }
    if ($success) {
        Write-Host "$pkgname $pkgver ($rver) verified"
    } else {
        Remove-Item $pkgdir -Recurse -Force -ErrorAction "Ignore"
        Write-Warning "$pkgname $pkgver ($rver) failed verification"
    }
} -ThrottleLimit $threads

Remove-Item $tmpdir -Recurse -Force -ErrorAction "Stop"
