$packages = Resolve-Path ".\packages"
$sitelib = Join-Path $env:SystemDrive "r-packages"
$rversion = 4.1

$installdir = Join-Path $sitelib $rversion

if (-not (Test-Path $installdir)) {
    New-Item $installdir -ItemType "directory" -Force | Out-Null
}

Get-ChildItem $packages -Filter "*.zip" | ForEach-Object {
    Expand-Archive $_.FullName -DestinationPath $installdir -Force
    $pkgname = $_.Name.Split("_")[0]
    $pkgdir =  Join-Path $installdir $pkgname
    $md5file = Join-Path $pkgdir "MD5"
    $success = $true
    if (Test-Path $md5file) {
        Get-Content $md5file | ForEach-Object {
            $hash = $_.Split(" ")[0]
            $file = Join-Path $pkgdir $_.Split(" ")[1].TrimStart("*")
            if (Test-Path $file) {
                if ((Get-FileHash $file -Algorithm "MD5").Hash -ne $hash) {
                    $success = $false
                }
            } else { $success = $false }
        }
    } else { $success = $false }
    if ($success) {
        Write-Host "$pkgname successfully unpacked and MD5 sums checked"
    } else {
        Remove-Item $pkgdir -Recurse -Force -ErrorAction "SilentlyContinue"
        Write-Warning "$pkgname failed checks and was not installed"
    }
}
