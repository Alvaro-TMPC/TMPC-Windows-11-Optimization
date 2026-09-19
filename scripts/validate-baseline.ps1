#Requires -Version 5.1
<#
.SYNOPSIS
    Validador estatico local del baseline TMPC Windows 11 Optimization.
.DESCRIPTION
    Comprueba en modo solo lectura el baseline versionado del repositorio:
    existencia de archivos obligatorios, XML bien formado y limitado a amd64,
    sintaxis del PowerShell embebido, ventoy.json, hashes SHA-256 frente a la
    documentacion, EOL/BOM, trailing whitespace, .gitattributes y enlaces
    relativos de la documentacion.
    No ejecuta los scripts embebidos, no escribe en el sistema y no sustituye
    una instalacion limpia real.
.PARAMETER RepoRoot
    Ruta alternativa a la raiz del repositorio. Por defecto se deduce del
    directorio padre de este script. Pensado para pruebas sobre copias.
.PARAMETER RequireClean
    Convierte en FAIL un working tree Git no limpio. Sin este conmutador, un
    working tree no limpio se informa como WARN y no afecta al codigo de salida.
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-baseline.ps1
.NOTES
    Solo lectura. Windows PowerShell 5.1. Sin dependencias externas.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$RequireClean
)

$ErrorActionPreference = 'Stop'

$script:OkCount = 0
$script:FailCount = 0
$script:WarnCount = 0
$script:FileCache = @{}
$script:Root = $null
$script:Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

function Write-Section {
    param([string]$Name)
    Write-Host ''
    Write-Host ("=== {0} ===" -f $Name)
}

function Add-Ok {
    param([string]$Message)
    $script:OkCount++
    Write-Host ("[OK]   {0}" -f $Message)
}

function Add-Fail {
    param([string]$Message)
    $script:FailCount++
    Write-Host ("[FAIL] {0}" -f $Message)
}

function Add-Warn {
    param([string]$Message)
    $script:WarnCount++
    Write-Host ("[WARN] {0}" -f $Message)
}

function Get-AbsolutePath {
    param([string]$Path)
    return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
}

function Get-BomKind {
    param([byte[]]$Bytes)
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { return 'UTF8' }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) { return 'UTF16LE' }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) { return 'UTF16BE' }
    return 'NONE'
}

function Get-EolKind {
    param([byte[]]$Bytes)
    $crlf = 0
    $lf = 0
    $cr = 0
    $i = 0
    while ($i -lt $Bytes.Length) {
        if ($Bytes[$i] -eq 13) {
            if ((($i + 1) -lt $Bytes.Length) -and ($Bytes[$i + 1] -eq 10)) {
                $crlf++
                $i++
            } else {
                $cr++
            }
        } elseif ($Bytes[$i] -eq 10) {
            $lf++
        }
        $i++
    }
    $kind = 'NONE'
    if ($crlf -gt 0 -and $lf -eq 0 -and $cr -eq 0) { $kind = 'CRLF' }
    elseif ($lf -gt 0 -and $crlf -eq 0 -and $cr -eq 0) { $kind = 'LF' }
    elseif ($crlf -eq 0 -and $lf -eq 0 -and $cr -eq 0) { $kind = 'NONE' }
    else { $kind = 'MIXED' }
    return [pscustomobject]@{ Kind = $kind; CRLF = $crlf; LoneLF = $lf; LoneCR = $cr }
}

function Get-TrailingWhitespaceCount {
    param([string]$Text)
    $count = 0
    foreach ($line in [regex]::Split($Text, "\r\n|\n|\r")) {
        if ($line -match '[ \t]+$') { $count++ }
    }
    return $count
}

function Get-FileRecord {
    param([string]$RelativePath)
    if ($script:FileCache.ContainsKey($RelativePath)) { return $script:FileCache[$RelativePath] }
    $record = [pscustomobject]@{
        Relative = $RelativePath
        Exists   = $false
        Abs      = $null
        Bytes    = $null
        Text     = $null
        DecodeOk = $false
        Bom      = 'NONE'
        Eol      = $null
        Trailing = -1
    }
    try {
        $abs = Get-AbsolutePath -Path (Join-Path $script:Root $RelativePath)
        $record.Abs = $abs
        $record.Exists = $true
        $bytes = [System.IO.File]::ReadAllBytes($abs)
        $record.Bytes = $bytes
        $record.Bom = Get-BomKind -Bytes $bytes
        $record.Eol = Get-EolKind -Bytes $bytes
        try {
            $text = $script:Utf8Strict.GetString($bytes)
            $record.Text = $text
            $record.DecodeOk = $true
            $record.Trailing = Get-TrailingWhitespaceCount -Text $text
        } catch {
            $record.DecodeOk = $false
        }
    } catch {
        $record.Exists = $false
    }
    $script:FileCache[$RelativePath] = $record
    return $record
}

function Test-FilePolicy {
    param(
        [string]$RelativePath,
        [string]$ExpectedEol,
        [string]$ExpectedBom,
        [string]$BomMismatchSeverity = 'FAIL'
    )
    $record = Get-FileRecord -RelativePath $RelativePath
    if (-not $record.Exists) {
        Add-Fail ("{0}: no existe" -f $RelativePath)
        return
    }
    if (-not $record.DecodeOk) {
        Add-Fail ("{0}: no es UTF-8 valido" -f $RelativePath)
        return
    }
    $ok = $true
    if ($record.Bom -ne $ExpectedBom) {
        $message = "{0}: BOM={1} (esperado {2})" -f $RelativePath, $record.Bom, $ExpectedBom
        if ($BomMismatchSeverity -eq 'WARN') {
            Add-Warn $message
        } else {
            Add-Fail $message
            $ok = $false
        }
    }
    if ($record.Eol.Kind -ne $ExpectedEol) {
        Add-Fail ("{0}: EOL={1} (esperado {2}; CRLF={3}, LF={4}, CR={5})" -f $RelativePath, $record.Eol.Kind, $ExpectedEol, $record.Eol.CRLF, $record.Eol.LoneLF, $record.Eol.LoneCR)
        $ok = $false
    }
    if ($record.Trailing -gt 0) {
        Add-Fail ("{0}: trailing whitespace en {1} linea(s)" -f $RelativePath, $record.Trailing)
        $ok = $false
    }
    if ($ok) {
        Add-Ok ("{0}: {1}, BOM={2}, trailing whitespace = 0" -f $RelativePath, $ExpectedEol, $record.Bom)
    }
}

function Test-PowerShellBlock {
    param(
        [string]$Name,
        [string]$Text
    )
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    $list = @()
    if ($null -ne $errors) { $list = @($errors) }
    if ($list.Count -eq 0) {
        Add-Ok ("{0}: 0 errores de sintaxis" -f $Name)
        return
    }
    Add-Fail ("{0}: {1} error(es) de sintaxis" -f $Name, $list.Count)
    $shown = 0
    foreach ($e in $list) {
        if ($shown -ge 5) { break }
        Add-Fail ("    L{0}:C{1} {2}" -f $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber, $e.Message)
        $shown++
    }
}

function Test-ExplorerDefaults {
    param([string]$Text)

    $presenceChecks = @(
        @{ Snippet = "-Name 'UseCompactMode' -Type 'DWord' -Value 1"; Description = 'Explorer HKCU: UseCompactMode = 1' },
        @{ Snippet = "-Name 'AutoCheckSelect' -Type 'DWord' -Value 0"; Description = 'Explorer HKCU: AutoCheckSelect = 0' },
        @{ Snippet = "-Name 'HideFileExt' -Type 'DWord' -Value 0"; Description = 'Explorer HKCU: HideFileExt = 0' },
        @{ Snippet = "-Name 'Hidden' -Type 'DWord' -Value 1"; Description = 'Explorer HKCU: Hidden = 1' },
        @{ Snippet = "-Name 'ShowSuperHidden' -Type 'DWord' -Value 0"; Description = 'Explorer HKCU: ShowSuperHidden = 0' },
        @{ Snippet = '{885a186e-a440-4ada-812b-db871b942259}'; Description = 'Downloads FolderType GUID presente' },
        @{ Snippet = '{00000000-0000-0000-0000-000000000000}'; Description = 'FolderTypes TopView por defecto presente' },
        @{ Snippet = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes'; Description = 'Origen HKLM FolderTypes presente' },
        @{ Snippet = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes'; Description = 'Destino HKCU FolderTypes presente' },
        @{ Snippet = "-Name 'GroupBy' -Value '' -Type String"; Description = 'GroupBy se establece como String vacio' },
        @{ Snippet = 'System.DateModified'; Description = 'Gate GroupBy = System.DateModified presente' }
    )
    foreach ($check in $presenceChecks) {
        if ($Text.Contains($check.Snippet)) {
            Add-Ok $check.Description
        } else {
            Add-Fail ("{0}: fragmento no encontrado" -f $check.Description)
        }
    }

    $recursiveCopy = $false
    foreach ($match in [regex]::Matches($Text, 'reg\.exe\s+copy\b[^\r\n]*')) {
        if ($match.Value -match '/s' -and $match.Value -match '/f') {
            $recursiveCopy = $true
        }
    }
    if ($recursiveCopy) {
        Add-Ok 'reg.exe copy recursivo (/s /f) presente'
    } else {
        Add-Fail 'reg.exe copy recursivo (/s /f) no encontrado'
    }

    $forbidden = @('UseAutoGrouping', 'ConvertibleSlateMode', 'ConvertibilityEnabled')
    foreach ($name in $forbidden) {
        if ($Text.Contains($name)) {
            Add-Fail ("{0}: presente y no permitido" -f $name)
        } else {
            Add-Ok ("{0}: ausente" -f $name)
        }
    }

    $bagMutationPattern = '(?im)^\s*.*(?:Remove-Item|Remove-ItemProperty|New-Item|Set-ItemProperty|Set-RegistryValue|Remove-RegistryKey|Remove-RegistryValue|New-RegistryKey|reg\.exe\s+(?:add|delete)).*(?:BagMRU|\\Bags\b).*$'
    if ([regex]::IsMatch($Text, $bagMutationPattern)) {
        Add-Fail 'Bags/BagMRU: mutacion detectada'
    } else {
        Add-Ok 'Bags/BagMRU: sin mutaciones'
    }

    if ($Text.Contains('Shell\Bags') -or $Text.Contains('Shell\BagMRU')) {
        Add-Fail 'Bags/BagMRU: ruta de registro presente y no permitida'
    } else {
        Add-Ok 'Bags/BagMRU: sin rutas de registro'
    }

    if ([regex]::IsMatch($Text, '(?im)^\s*.*(?:Set-ItemProperty|New-Item|New-ItemProperty|Remove-Item|Remove-ItemProperty|Set-RegistryValue|Remove-RegistryKey|New-RegistryKey|Remove-RegistryValue|reg\.exe\s+(?:add|delete)).*HKLM.*FolderTypes.*$')) {
        Add-Fail 'HKLM FolderTypes: mutacion detectada'
    } else {
        Add-Ok 'HKLM FolderTypes: solo lectura'
    }
}

function Get-HereStringMatches {
    param(
        [string]$Text,
        [string]$VariableName
    )
    $pattern = '^\s*\$' + [regex]::Escape($VariableName) + '\s*=\s*@''\r?\n(?<body>[\s\S]*?)^''@[ \t]*$'
    return [regex]::Matches($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

function Get-MarkdownSection {
    param(
        [string]$Text,
        [string]$StartPattern,
        [string]$EndPattern
    )
    $startMatch = [regex]::Match($Text, $StartPattern)
    if (-not $startMatch.Success) { return $null }
    $rest = $Text.Substring($startMatch.Index + $startMatch.Length)
    $endMatch = [regex]::Match($rest, $EndPattern)
    if ($endMatch.Success) { return $rest.Substring(0, $endMatch.Index) }
    return $rest
}

function Get-BaselineHashCandidates {
    param(
        [string]$Block,
        [string]$FileName
    )
    $found = @()
    foreach ($m in [regex]::Matches($Block, [regex]::Escape($FileName))) {
        $windowStart = $m.Index + $m.Length
        $windowLength = [Math]::Min(200, $Block.Length - $windowStart)
        if ($windowLength -le 0) { continue }
        $window = $Block.Substring($windowStart, $windowLength)
        $hashMatch = [regex]::Match($window, '([0-9A-Fa-f]{64})')
        if ($hashMatch.Success) {
            $found += $hashMatch.Groups[1].Value.ToUpperInvariant()
        }
    }
    return $found
}

function Test-GitAttributesCrossCheck {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCmd) {
        Add-Warn 'Git no disponible: sin comprobacion adicional con git check-attr'
        return
    }
    $targets = @(
        'autounattend.xml',
        'ventoy.json',
        'README.md',
        'README.es.md',
        'LICENSE',
        'THIRD_PARTY_NOTICES.md',
        'docs/preparacion-previa-instalacion.md',
        'docs/pre-installation-preparation.md',
        'docs/configuracion-pruebas-limitaciones-fuentes.md',
        'docs/configuration-testing-limitations-sources.md',
        'docs/comprobaciones-posteriores-instalacion.md',
        'docs/post-installation-checks.md',
        'scripts/validate-baseline.ps1'
    )
    try {
        $output = @(& git -C $script:Root check-attr eol -- $targets 2>$null)
    } catch {
        Add-Warn 'git check-attr no se pudo ejecutar'
        return
    }
    if ($LASTEXITCODE -ne 0) {
        Add-Warn 'git check-attr no disponible en este repositorio'
        return
    }
    $expected = @{
        'autounattend.xml'                                   = 'lf'
        'ventoy.json'                                        = 'crlf'
        'README.md'                                          = 'lf'
        'README.es.md'                                       = 'lf'
        'LICENSE'                                            = 'lf'
        'THIRD_PARTY_NOTICES.md'                             = 'lf'
        'docs/preparacion-previa-instalacion.md'             = 'lf'
        'docs/pre-installation-preparation.md'               = 'lf'
        'docs/configuracion-pruebas-limitaciones-fuentes.md' = 'lf'
        'docs/configuration-testing-limitations-sources.md'  = 'lf'
        'docs/comprobaciones-posteriores-instalacion.md'     = 'lf'
        'docs/post-installation-checks.md'                   = 'lf'
        'scripts/validate-baseline.ps1'                      = 'lf'
    }
    $mismatches = 0
    foreach ($line in $output) {
        $parts = $line -split ': '
        if ($parts.Count -ge 3) {
            $file = $parts[0].Trim()
            $value = $parts[2].Trim()
            if ($expected.ContainsKey($file) -and $value -ne $expected[$file]) {
                $mismatches++
                Add-Warn ("git check-attr: {0} eol={1} (esperado {2})" -f $file, $value, $expected[$file])
            }
        }
    }
    if ($mismatches -eq 0) {
        Add-Ok 'git check-attr: atributos eol coherentes con la politica'
    }
}

function Test-DocumentLinks {
    param([string]$RelativePath)
    $record = Get-FileRecord -RelativePath $RelativePath
    if (-not $record.Exists) { return }
    if (-not $record.DecodeOk) { return }
    $baseDir = Split-Path -Parent $record.Abs
    $checked = 0
    $broken = 0
    foreach ($m in [regex]::Matches($record.Text, '\]\(([^)]+)\)')) {
        $target = $m.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $target = ($target -split '\s+')[0]
        if ($target -match '^(https?://|mailto:|#)') { continue }
        $anchorIndex = $target.IndexOf('#')
        if ($anchorIndex -ge 0) { $target = $target.Substring(0, $anchorIndex) }
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $checked++
        $candidate = Join-Path $baseDir $target
        if (-not (Test-Path -LiteralPath $candidate)) {
            $broken++
            Add-Fail ("{0}: enlace relativo no encontrado: {1}" -f $RelativePath, $target)
        }
    }
    if ($broken -eq 0) {
        Add-Ok ("{0}: {1} enlace(s) relativo(s) comprobado(s)" -f $RelativePath, $checked)
    }
}

function Test-LicensingFiles {
    $licenseRecord = Get-FileRecord -RelativePath 'LICENSE'
    if ($licenseRecord.Exists -and $licenseRecord.DecodeOk) {
        if ($licenseRecord.Text.Contains('MIT License')) {
            Add-Ok 'LICENSE: titulo MIT License presente'
        } else {
            Add-Fail 'LICENSE: falta el titulo "MIT License"'
        }
        if ($licenseRecord.Text.Contains('Copyright (c) 2026 Alvaro-TMPC')) {
            Add-Ok 'LICENSE: copyright TMPC 2026 presente'
        } else {
            Add-Fail 'LICENSE: falta "Copyright (c) 2026 Alvaro-TMPC"'
        }
        if ($licenseRecord.Text.Contains('Permission is hereby granted, free of charge')) {
            Add-Ok 'LICENSE: texto de permiso MIT presente'
        } else {
            Add-Fail 'LICENSE: falta el texto de permiso MIT'
        }
    }

    $thirdRecord = Get-FileRecord -RelativePath 'THIRD_PARTY_NOTICES.md'
    if ($thirdRecord.Exists -and $thirdRecord.DecodeOk) {
        $thirdChecks = @(
            @{ Snippet = 'memstechtips/UnattendedWinstall'; Description = 'THIRD_PARTY_NOTICES: upstream UnattendedWinstall' },
            @{ Snippet = 'cca752363772a845eb0fed9d3a5b89b5d0a10d20'; Description = 'THIRD_PARTY_NOTICES: snapshot de referencia' },
            @{ Snippet = 'Copyright (c) 2025 Marco du Plessis (memstechtips)'; Description = 'THIRD_PARTY_NOTICES: copyright de terceros' }
        )
        foreach ($check in $thirdChecks) {
            if ($thirdRecord.Text.Contains($check.Snippet)) {
                Add-Ok $check.Description
            } else {
                Add-Fail ("{0}: fragmento no encontrado" -f $check.Description)
            }
        }
    }

    foreach ($relativePath in @('README.md', 'README.es.md')) {
        $record = Get-FileRecord -RelativePath $relativePath
        if (-not $record.Exists -or -not $record.DecodeOk) { continue }
        if ($record.Text.Contains('](LICENSE)')) {
            Add-Ok ("{0}: referencia relativa a LICENSE presente" -f $relativePath)
        } else {
            Add-Fail ("{0}: sin referencia relativa a LICENSE" -f $relativePath)
        }
        if ($record.Text.Contains('](THIRD_PARTY_NOTICES.md)')) {
            Add-Ok ("{0}: referencia relativa a THIRD_PARTY_NOTICES.md presente" -f $relativePath)
        } else {
            Add-Fail ("{0}: sin referencia relativa a THIRD_PARTY_NOTICES.md" -f $relativePath)
        }
        if ($record.Text.Contains('Copyright (c) 2026 Alvaro-TMPC')) {
            Add-Ok ("{0}: copyright TMPC 2026 presente" -f $relativePath)
        } else {
            Add-Fail ("{0}: falta el copyright TMPC 2026" -f $relativePath)
        }
    }

    $docsRecord = Get-FileRecord -RelativePath 'docs/configuracion-pruebas-limitaciones-fuentes.md'
    if ($docsRecord.Exists -and $docsRecord.DecodeOk) {
        if ($docsRecord.Text.Contains('Copyright (c) 2026 Alvaro-TMPC')) {
            Add-Ok 'docs/configuracion-pruebas-limitaciones-fuentes.md: copyright TMPC 2026 presente'
        } else {
            Add-Fail 'docs/configuracion-pruebas-limitaciones-fuentes.md: falta el copyright TMPC 2026'
        }
        if ($docsRecord.Text.Contains('cca752363772a845eb0fed9d3a5b89b5d0a10d20')) {
            Add-Ok 'docs/configuracion-pruebas-limitaciones-fuentes.md: snapshot de referencia presente'
        } else {
            Add-Fail 'docs/configuracion-pruebas-limitaciones-fuentes.md: falta el snapshot de referencia'
        }
    }
}

# ---------------------------------------------------------------------------
# Resolucion de la raiz del repositorio
# ---------------------------------------------------------------------------

if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    try {
        $script:Root = Get-AbsolutePath -Path $RepoRoot
    } catch {
        $script:Root = $null
    }
}
if (-not $script:Root -and -not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    try {
        $script:Root = Get-AbsolutePath -Path (Join-Path $PSScriptRoot '..')
    } catch {
        $script:Root = $null
    }
}
if (-not $script:Root -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    try {
        $script:Root = Get-AbsolutePath -Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')
    } catch {
        $script:Root = $null
    }
}

Write-Host ''
Write-Host 'Validador estatico del baseline - TMPC Windows 11 Optimization'

Write-Section 'REPOSITORIO'

if (-not $script:Root) {
    Add-Fail 'No se pudo determinar la raiz del repositorio; usa -RepoRoot con una ruta valida'
    Write-Host ''
    Write-Host '=== RESULTADO ==='
    Write-Host ("Comprobaciones OK: {0}; FAIL: {1}; WARN: {2}" -f $script:OkCount, $script:FailCount, $script:WarnCount)
    Write-Host 'RESULTADO: FAIL (no se pudo iniciar la validacion)'
    exit 1
}

Add-Ok ("Raiz del repositorio: {0}" -f $script:Root)

$mandatoryFiles = @(
    'autounattend.xml',
    'ventoy.json',
    '.gitattributes',
    'README.md',
    'README.es.md',
    'LICENSE',
    'THIRD_PARTY_NOTICES.md',
    'docs/preparacion-previa-instalacion.md',
    'docs/pre-installation-preparation.md',
    'docs/configuracion-pruebas-limitaciones-fuentes.md',
    'docs/configuration-testing-limitations-sources.md',
    'docs/comprobaciones-posteriores-instalacion.md',
    'docs/post-installation-checks.md'
)
foreach ($relativePath in $mandatoryFiles) {
    $record = Get-FileRecord -RelativePath $relativePath
    if ($record.Exists) {
        Add-Ok ("{0}: existe" -f $relativePath)
    } else {
        Add-Fail ("{0}: no existe" -f $relativePath)
    }
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCmd) {
    Add-Warn 'Git no disponible: no se informa del estado del arbol de trabajo'
} else {
    try {
        $branch = @(& git -C $script:Root rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $branch.Count -ge 1) {
            Add-Ok ("Rama Git: {0}" -f $branch[0])
        } else {
            Add-Warn 'No se pudo consultar la rama Git'
        }
    } catch {
        Add-Warn 'No se pudo consultar la rama Git'
    }
    try {
        $statusLines = @(& git -C $script:Root status --porcelain 2>$null)
        if ($LASTEXITCODE -ne 0) {
            Add-Warn 'No se pudo consultar el estado del arbol de trabajo'
        } elseif ($statusLines.Count -eq 0) {
            Add-Ok 'Working tree limpio (Git)'
        } elseif ($RequireClean) {
            Add-Fail ("Working tree no limpio (Git): {0} entrada(s)" -f $statusLines.Count)
        } else {
            Add-Warn ("Working tree no limpio (Git): {0} entrada(s); usa -RequireClean para elevarlo a FAIL" -f $statusLines.Count)
        }
    } catch {
        Add-Warn 'No se pudo consultar el estado del arbol de trabajo'
    }
}

# ---------------------------------------------------------------------------
# XML
# ---------------------------------------------------------------------------

Write-Section 'XML'

$doc = $null
$xmlRecord = Get-FileRecord -RelativePath 'autounattend.xml'
if (-not $xmlRecord.Exists) {
    Add-Fail 'autounattend.xml: no existe; no se puede validar el XML'
} else {
    try {
        $doc = New-Object System.Xml.XmlDocument
        $doc.XmlResolver = $null
        $doc.Load($xmlRecord.Abs)
        Add-Ok 'autounattend.xml: XML bien formado'
    } catch {
        Add-Fail ("autounattend.xml: XML mal formado: {0}" -f $_.Exception.Message)
        $doc = $null
    }
}

if ($null -ne $doc) {
    $components = @($doc.SelectNodes("//*[local-name()='component']"))
    $amd64 = 0
    $x86 = 0
    $arm64 = 0
    $other = 0
    foreach ($component in $components) {
        switch ($component.GetAttribute('processorArchitecture')) {
            'amd64' { $amd64++ }
            'x86' { $x86++ }
            'arm64' { $arm64++ }
            default { $other++ }
        }
    }
    if ($amd64 -eq 3) {
        Add-Ok 'processorArchitecture amd64 = 3'
    } else {
        Add-Fail ("processorArchitecture amd64 = {0} (esperado 3 para el baseline actual)" -f $amd64)
    }
    if ($x86 -eq 0) {
        Add-Ok 'processorArchitecture x86 = 0'
    } else {
        Add-Fail ("processorArchitecture x86 = {0} (esperado 0)" -f $x86)
    }
    if ($arm64 -eq 0) {
        Add-Ok 'processorArchitecture arm64 = 0'
    } else {
        Add-Fail ("processorArchitecture arm64 = {0} (esperado 0)" -f $arm64)
    }
    if ($other -gt 0) {
        Add-Fail ("processorArchitecture distinto de amd64/x86/arm64 = {0}" -f $other)
    }
}

# ---------------------------------------------------------------------------
# PowerShell embebido
# ---------------------------------------------------------------------------

Write-Section 'POWERSHELL EMBEBIDO'

if ($null -eq $doc) {
    Add-Fail 'No se puede analizar el PowerShell embebido: el XML no esta disponible'
} else {
    $extractText = $null
    $extractNode = $doc.SelectSingleNode("//*[local-name()='ExtractScript']")
    if ($null -eq $extractNode) {
        Add-Fail 'ExtractScript: nodo no encontrado'
    } else {
        $extractText = $extractNode.InnerText.Trim()
        if ([string]::IsNullOrWhiteSpace($extractText)) {
            Add-Fail 'ExtractScript: contenido vacio'
            $extractText = $null
        } else {
            Add-Ok 'ExtractScript: nodo encontrado con contenido'
        }
    }

    $sysText = $null
    $fileNodes = @($doc.SelectNodes("//*[local-name()='File' and @path]"))
    $sysNodes = @($fileNodes | Where-Object { $_.GetAttribute('path').EndsWith('SystemCustomizations.ps1', [System.StringComparison]::Ordinal) })
    if ($sysNodes.Count -ne 1) {
        Add-Fail ("SystemCustomizations.ps1: se esperaba 1 nodo File; encontrados {0}" -f $sysNodes.Count)
    } else {
        $sysText = $sysNodes[0].InnerText.Trim()
        if ([string]::IsNullOrWhiteSpace($sysText)) {
            Add-Fail 'SystemCustomizations.ps1: contenido vacio'
            $sysText = $null
        } else {
            Add-Ok 'SystemCustomizations.ps1: nodo File encontrado con contenido'
        }
    }

    $bloatText = $null
    $oneDriveText = $null
    if ($null -eq $sysText) {
        Add-Fail 'BloatRemoval.ps1: no se puede extraer sin SystemCustomizations.ps1'
        Add-Fail 'OneDriveRemoval.ps1: no se puede extraer sin SystemCustomizations.ps1'
    } else {
        $bloatMatches = @(Get-HereStringMatches -Text $sysText -VariableName 'bloatRemovalContent')
        if ($bloatMatches.Count -ne 1) {
            Add-Fail ("BloatRemoval.ps1: here-string no inequivoco ({0} coincidencia(s))" -f $bloatMatches.Count)
        } else {
            $bloatText = $bloatMatches[0].Groups['body'].Value
            if ([string]::IsNullOrWhiteSpace($bloatText)) {
                Add-Fail 'BloatRemoval.ps1: bloque vacio'
                $bloatText = $null
            } else {
                Add-Ok 'BloatRemoval.ps1: bloque extraido'
            }
        }
        $oneDriveMatches = @(Get-HereStringMatches -Text $sysText -VariableName 'oneDriveRemovalContent')
        if ($oneDriveMatches.Count -ne 1) {
            Add-Fail ("OneDriveRemoval.ps1: here-string no inequivoco ({0} coincidencia(s))" -f $oneDriveMatches.Count)
        } else {
            $oneDriveText = $oneDriveMatches[0].Groups['body'].Value
            if ([string]::IsNullOrWhiteSpace($oneDriveText)) {
                Add-Fail 'OneDriveRemoval.ps1: bloque vacio'
                $oneDriveText = $null
            } else {
                Add-Ok 'OneDriveRemoval.ps1: bloque extraido'
            }
        }
    }

    if ($null -ne $extractText) {
        Test-PowerShellBlock -Name 'ExtractScript' -Text $extractText
    }
    if ($null -ne $sysText) {
        Test-PowerShellBlock -Name 'SystemCustomizations.ps1' -Text $sysText
    }
    if ($null -ne $bloatText) {
        Test-PowerShellBlock -Name 'BloatRemoval.ps1' -Text $bloatText
    }
    if ($null -ne $oneDriveText) {
        Test-PowerShellBlock -Name 'OneDriveRemoval.ps1' -Text $oneDriveText
    }

    if ($null -ne $sysText) {
        Write-Section 'EXPLORER DEFAULTS'
        Test-ExplorerDefaults -Text $sysText
    }
}

# ---------------------------------------------------------------------------
# Ventoy
# ---------------------------------------------------------------------------

Write-Section 'VENTOY'

$ventoyRecord = Get-FileRecord -RelativePath 'ventoy.json'
$ventoyJson = $null
if (-not $ventoyRecord.Exists) {
    Add-Fail 'ventoy.json: no existe; no se puede validar'
} elseif (-not $ventoyRecord.DecodeOk) {
    Add-Fail 'ventoy.json: no es UTF-8 valido'
} else {
    try {
        $ventoyText = $ventoyRecord.Text
        if ($ventoyText.Length -gt 0 -and $ventoyText[0] -eq [char]0xFEFF) {
            $ventoyText = $ventoyText.Substring(1)
        }
        $ventoyJson = ConvertFrom-Json -InputObject $ventoyText
        Add-Ok 'ventoy.json: JSON valido'
    } catch {
        Add-Fail ("ventoy.json: JSON invalido: {0}" -f $_.Exception.Message)
        $ventoyJson = $null
    }
}

if ($null -ne $ventoyJson) {
    $control = $null
    $entry = $null
    if ($null -ne $ventoyJson.PSObject.Properties['control']) {
        $control = @($ventoyJson.control)
    }
    if ($null -ne $ventoyJson.PSObject.Properties['auto_install']) {
        $entry = @($ventoyJson.auto_install)
    }
    $vsm = $null
    $image = $null
    $template = $null
    $autosel = $null
    $timeout = $null
    if ($control.Count -ge 1) {
        if ($null -ne $control[0].PSObject.Properties['VTOY_SECONDARY_BOOT_MENU']) { $vsm = $control[0].VTOY_SECONDARY_BOOT_MENU }
    }
    if ($entry.Count -ge 1) {
        if ($null -ne $entry[0].PSObject.Properties['image']) { $image = $entry[0].image }
        if ($null -ne $entry[0].PSObject.Properties['template']) { $template = $entry[0].template }
        if ($null -ne $entry[0].PSObject.Properties['autosel']) { $autosel = $entry[0].autosel }
        if ($null -ne $entry[0].PSObject.Properties['timeout']) { $timeout = $entry[0].timeout }
    }
    Write-Host ("       VTOY_SECONDARY_BOOT_MENU={0}; image={1}; template={2}; autosel={3}; timeout={4}" -f $vsm, $image, $template, $autosel, $timeout)
    if ([string]$vsm -eq '0') { Add-Ok 'VTOY_SECONDARY_BOOT_MENU = "0"' } else { Add-Fail ('VTOY_SECONDARY_BOOT_MENU = {0} (esperado "0")' -f $vsm) }
    if ([string]$image -eq '/Win11_25H2_Spanish_x64_v2.iso') { Add-Ok 'image = "/Win11_25H2_Spanish_x64_v2.iso"' } else { Add-Fail ("image = {0} (esperado /Win11_25H2_Spanish_x64_v2.iso)" -f $image) }
    if ([string]$template -eq '/ventoy/script/autounattend.xml') { Add-Ok 'template = "/ventoy/script/autounattend.xml"' } else { Add-Fail ("template = {0} (esperado /ventoy/script/autounattend.xml)" -f $template) }
    if ([string]$autosel -eq '1') { Add-Ok 'autosel = 1' } else { Add-Fail ("autosel = {0} (esperado 1)" -f $autosel) }
    if ([string]$timeout -eq '0') { Add-Ok 'timeout = 0' } else { Add-Fail ("timeout = {0} (esperado 0)" -f $timeout) }
}

# ---------------------------------------------------------------------------
# Hashes y coherencia documental
# ---------------------------------------------------------------------------

Write-Section 'HASHES'

$realHashes = @{}
foreach ($relativePath in @('autounattend.xml', 'ventoy.json')) {
    $record = Get-FileRecord -RelativePath $relativePath
    if (-not $record.Exists) {
        Add-Fail ("{0}: no existe; no se puede calcular SHA-256" -f $relativePath)
        continue
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $record.Abs).Hash
    $realHashes[$relativePath] = $hash
    Write-Host ("       SHA-256 {0}: {1}" -f $relativePath, $hash)
    Add-Ok ("{0}: SHA-256 calculado" -f $relativePath)
}

$baselineHashSources = @(
    @{
        Path   = 'README.md'
        Start  = '(?m)^## File integrity \(SHA-256\)[ \t]*\r?\n'
        End    = '(?m)^##[ \t]'
        Marker = '## File integrity (SHA-256)'
    },
    @{
        Path   = 'README.es.md'
        Start  = '(?m)^## Integridad de archivos \(SHA-256\)[ \t]*\r?\n'
        End    = '(?m)^##[ \t]'
        Marker = '## Integridad de archivos (SHA-256)'
    },
    @{
        Path   = 'docs/configuracion-pruebas-limitaciones-fuentes.md'
        Start  = 'Hashes SHA-256 del baseline actual:'
        End    = '(?m)^###[ \t]'
        Marker = 'Hashes SHA-256 del baseline actual:'
    },
    @{
        Path   = 'docs/configuration-testing-limitations-sources.md'
        Start  = 'SHA-256 hashes of the current baseline:'
        End    = '(?m)^###[ \t]'
        Marker = 'SHA-256 hashes of the current baseline:'
    }
)
foreach ($source in $baselineHashSources) {
    $sourceRecord = Get-FileRecord -RelativePath $source.Path
    if (-not $sourceRecord.Exists) {
        Add-Fail ("{0}: no existe; no se pueden comprobar los hashes del baseline actual" -f $source.Path)
        continue
    }
    if (-not $sourceRecord.DecodeOk) {
        Add-Fail ("{0}: no es UTF-8 valido; no se pueden comprobar los hashes del baseline actual" -f $source.Path)
        continue
    }
    $block = Get-MarkdownSection -Text $sourceRecord.Text -StartPattern $source.Start -EndPattern $source.End
    if ($null -eq $block) {
        Add-Fail ("{0}: bloque de hashes del baseline actual no encontrado ({1})" -f $source.Path, $source.Marker)
        continue
    }
    foreach ($relativePath in @('autounattend.xml', 'ventoy.json')) {
        if (-not $realHashes.ContainsKey($relativePath)) { continue }
        $documented = @(Get-BaselineHashCandidates -Block $block -FileName $relativePath)
        $label = "{0} [{1}] {2}" -f $source.Path, $source.Marker, $relativePath
        if ($documented.Count -eq 0) {
            Add-Fail ("{0}: sin hash documentado en el bloque del baseline actual" -f $label)
        } elseif ($documented.Count -gt 1) {
            Add-Fail ("{0}: hash no inequivoco en el bloque del baseline actual ({1} coincidencia(s))" -f $label, $documented.Count)
        } elseif ($documented[0] -eq $realHashes[$relativePath]) {
            Add-Ok ("{0}: hash del baseline actual coincide" -f $label)
        } else {
            Add-Fail ("{0}: hash {1} != real {2}" -f $label, $documented[0], $realHashes[$relativePath])
        }
    }
}

# ---------------------------------------------------------------------------
# EOL / encoding
# ---------------------------------------------------------------------------

Write-Section 'EOL / ENCODING'

Test-FilePolicy -RelativePath 'autounattend.xml' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'README.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'README.es.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'LICENSE' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'THIRD_PARTY_NOTICES.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'docs/preparacion-previa-instalacion.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'docs/pre-installation-preparation.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'docs/configuracion-pruebas-limitaciones-fuentes.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'docs/configuration-testing-limitations-sources.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'docs/comprobaciones-posteriores-instalacion.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'docs/post-installation-checks.md' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'ventoy.json' -ExpectedEol 'CRLF' -ExpectedBom 'NONE' -BomMismatchSeverity 'WARN'

$scriptsDir = Join-Path $script:Root 'scripts'
if (Test-Path -LiteralPath $scriptsDir) {
    $scriptFiles = @(Get-ChildItem -LiteralPath $scriptsDir -Filter '*.ps1' -File)
    foreach ($scriptFile in $scriptFiles) {
        Test-FilePolicy -RelativePath ('scripts/' + $scriptFile.Name) -ExpectedEol 'LF' -ExpectedBom 'UTF8'
    }
}

# ---------------------------------------------------------------------------
# Documentacion
# ---------------------------------------------------------------------------

Write-Section 'DOCUMENTACION'

$gitattributesRecord = Get-FileRecord -RelativePath '.gitattributes'
if (-not $gitattributesRecord.Exists) {
    Add-Fail '.gitattributes: no existe'
} elseif (-not $gitattributesRecord.DecodeOk) {
    Add-Fail '.gitattributes: no es UTF-8 valido'
} else {
    $lines = @()
    foreach ($line in [regex]::Split($gitattributesRecord.Text, "\r\n|\n|\r")) {
        $lines += $line.Trim()
    }
    $requiredRules = @(
        'autounattend.xml text eol=lf',
        'ventoy.json text eol=crlf',
        'README.md text eol=lf',
        'README.es.md text eol=lf',
        'LICENSE text eol=lf',
        'THIRD_PARTY_NOTICES.md text eol=lf',
        'docs/*.md text eol=lf',
        'scripts/*.ps1 text eol=lf'
    )
    foreach ($rule in $requiredRules) {
        if ($lines -contains $rule) {
            Add-Ok (".gitattributes: regla presente: {0}" -f $rule)
        } else {
            Add-Fail (".gitattributes: falta la regla: {0}" -f $rule)
        }
    }
    Test-GitAttributesCrossCheck
}

Test-DocumentLinks -RelativePath 'README.md'
Test-DocumentLinks -RelativePath 'README.es.md'
Test-DocumentLinks -RelativePath 'THIRD_PARTY_NOTICES.md'
$docsDir = Join-Path $script:Root 'docs'
if (Test-Path -LiteralPath $docsDir) {
    $docFiles = @(Get-ChildItem -LiteralPath $docsDir -Filter '*.md' -File)
    foreach ($docFile in $docFiles) {
        Test-DocumentLinks -RelativePath ('docs/' + $docFile.Name)
    }
}

Write-Section 'LICENCIAS'
Test-LicensingFiles

# ---------------------------------------------------------------------------
# Resultado
# ---------------------------------------------------------------------------

Write-Section 'RESULTADO'
Write-Host ("Comprobaciones OK: {0}" -f $script:OkCount)
Write-Host ("Comprobaciones FAIL: {0}" -f $script:FailCount)
Write-Host ("Comprobaciones WARN: {0}" -f $script:WarnCount)

if ($script:FailCount -eq 0) {
    Write-Host 'RESULTADO: OK (0 FAIL; las comprobaciones obligatorias pasan)'
    exit 0
}

Write-Host ("RESULTADO: FAIL ({0} comprobacion(es) obligatoria(s) fallida(s))" -f $script:FailCount)
exit 1
