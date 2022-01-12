#Requires -RunAsAdministrator

$pkgroot = Resolve-Path ".\packages" -ErrorAction "Stop"
$sitelib = Join-Path $env:ProgramData "r-site-library"

if (-not (Test-Path $sitelib)) {
    New-Item $sitelib -ItemType "directory" -Force -ErrorAction "Stop" |
    Out-Null
} else {
    $testfile = Join-Path $sitelib "write-test"
    New-Item  $testfile -ItemType "file" -Force -ErrorAction "Stop" | Out-Null
    Remove-Item $testfile -Force
}

Get-ChildItem $pkgroot -Filter "?.?" -Directory -ErrorAction "Stop" |
Where-Object {$_.Name -match "^[0-9].[0-9]$"} |
Get-ChildItem -Filter "*.zip" -File -ErrorAction "Stop" |
ForEach-Object {
    $rver = $_.Directory.Name
    $installdir = Join-Path $sitelib $rver
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
        Write-Host "$pkgname $pkgver ($rver) unpacked and MD5 sums checked"
    } else {
        Remove-Item $pkgdir -Recurse -Force -ErrorAction "Ignore"
        Write-Warning "$pkgname $pkgver ($rver) failed checks and was omitted"
    }
}

$purged = $false
Get-ChildItem (Join-Path $env:SystemDrive "Users") -Force -Directory `
-Exclude "All Users","Default User","Public" | ForEach-Object {
    $renviron = Join-Path $_.FullName "Documents\.Renviron"
    if (-not (Test-Path $renviron)) {
        New-Item $renviron -ItemType "file" -Force | Out-Null
    } else {
        $old = Get-Content $renviron
        $new = $old | Where-Object {$_ -notmatch "^R_LIBS_SITE="} |
        Set-Content -Path $renviron -Force -PassThru
    }
    if ($old.Count -gt $new.Count) {
        Set-Variable -Name "purged" -Value $true
    }
    Add-Content $renviron -Value "R_LIBS_SITE=`"$sitelib\%v`"" -Force
}
if ($purged) {
    Write-Warning "existing R_LIBS_SITE entries removed from .Renviron files"
}
