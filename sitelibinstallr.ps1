$packages = Resolve-Path ".\packages"
$sitelib = Join-Path $env:SystemDrive "r-site-library"
$threads = 8

if (-not (Test-Path $sitelib)) {
    New-Item $sitelib -ItemType "directory" -Force | Out-Null
}

Get-ChildItem $packages -Filter "*.zip" | ForEach-Object -Parallel {
    Expand-Archive $_.FullName -DestinationPath $using:sitelib -Force
    $pkgname = $_.Name.Split("_")[0]
    $pkgdir =  Join-Path $using:sitelib $pkgname
    $md5file = Join-Path $pkgdir "MD5"
    $success = $true
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
        Write-Host "$pkgname successfully unpacked and MD5 sums checked"
    } else {
        Remove-Item $pkgdir -Recurse -Force -ErrorAction "SilentlyContinue"
        Write-Warning "$pkgname failed checks and was not installed"
    }
} -ThrottleLimit $threads

$purged = $false
Get-ChildItem (Join-Path $env:SystemDrive "Users") -Force -Directory `
-Exclude "All Users","Default User","Public","Default","Administrator" | ForEach-Object {
    $renviron = Join-Path $_.FullName "Documents\.Renviron"
    if (-not (Test-Path $renviron)) {
        New-Item $renviron -ItemType "file" | Out-Null
    } else {
        $old = Get-Content $renviron
        $new = $old | Where-Object {$_ -notmatch "^R_LIBS_SITE="} |
        Set-Content -Path $renviron -Force -PassThru
    }
    if ($old.Count -gt $new.Count) {
        Set-Variable -Name "purged" -Value $true
    }
    Add-Content $renviron -Value "R_LIBS_SITE=`"$sitelib`""
}
if ($purged) {
    Write-Warning "exitsting R_LIBS_SITE entries removed from .Renviron files"
}
