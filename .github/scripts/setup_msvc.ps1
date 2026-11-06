# Export the Visual Studio developer environment for subsequent GitHub Actions steps.
param(
    [Parameter(Mandatory)]
    [ValidateSet('x64', 'x86')]
    [string] $Arch
)

$ErrorActionPreference = 'Stop'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or !$installPath) {
    throw 'Could not find a Visual Studio installation with the C++ toolchain'
}

$vsDevCmd = Join-Path $installPath 'Common7\Tools\VsDevCmd.bat'
$environment = & $env:COMSPEC /d /s /c "`"$vsDevCmd`" -no_logo -arch=$Arch && set"
if ($LASTEXITCODE -ne 0) {
    throw "VsDevCmd.bat failed with exit code $LASTEXITCODE"
}

# Preserve values containing '=' and only export variables changed by VsDevCmd.
foreach ($line in $environment) {
    if ($line -match '^([^=]+)=(.*)$') {
        $name, $value = $Matches[1], $Matches[2]
        if ($value -cne [Environment]::GetEnvironmentVariable($name)) {
            "$name=$value" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        }
    }
}
