# Sets up the environment for building and running xtool on Windows.
# Dot-source it from PowerShell:  . .\scripts\windows-env.ps1
param(
    [string]$VcpkgInstalled = (Join-Path $PSScriptRoot '..\vcpkg_installed\x64-windows')
)

if (-not (Test-Path "$VcpkgInstalled\lib\pkgconfig")) {
    throw "No vcpkg libraries at '$VcpkgInstalled'. Run 'vcpkg install --triplet x64-windows' in the repo root first."
}
$VcpkgInstalled = (Resolve-Path $VcpkgInstalled).Path

# SwiftPM reads the .pc files itself, so no pkg-config executable is needed
$env:PKG_CONFIG_PATH = "$VcpkgInstalled\lib\pkgconfig"
# xtool.exe loads the vcpkg DLLs at runtime
if (($env:Path -split ';') -notcontains "$VcpkgInstalled\bin") {
    $env:Path = "$env:Path;$VcpkgInstalled\bin"
}
