$packages = Resolve-Path ".\packages"
$sitelib = Join-Path $env:SystemDrive "r-packages"
$rversion = 4.1

$installdir = Join-Path $sitelib $rversion

if (-not (Test-Path $sitelib)) {
    New-Item $sitelib -ItemType "directory" -Force
}

Get-ChildItem $packages -Filter "*.zip" | ForEach-Object {
    Expand-Archive $_.FullName -DestinationPath $sitelib -Force
    $pkgname = $_.Name.Split("_")[0]
    $pkgdir =  Join-Path $installdir $pkgname
    Get-Content (Join-Path $pkgdir "MD5") | ForEach-Object {
        $hash = $_.Split(" ")[0]
        $file = Join-Path $pkgdir $_.Split(" ")[1].TrimStart("*")
        if ((Get-FileHash $file -Algorithm "MD5").Hash -ne $hash) {
            Write-Warning $file
        }
    }
}
