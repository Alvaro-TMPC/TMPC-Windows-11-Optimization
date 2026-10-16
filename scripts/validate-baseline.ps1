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
    $Text = $Text.TrimStart([char]0xFEFF)
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

function Test-XmlHardening {
    param([string]$SystemText, [string]$BloatText, [string]$OneDriveText)

    $sysTokens=$null; $sysErrors=$null
    $sysAst=[System.Management.Automation.Language.Parser]::ParseInput($SystemText,[ref]$sysTokens,[ref]$sysErrors)
    $sysCommands=@()
    if (@($sysErrors).Count -eq 0) {
        $sysCommands=@($sysAst.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
    } else {
        Add-Fail 'XML hardening: SystemCustomizations no parseable'
    }

    # OneNote: no arbitrary uninstall string, no forced process termination.
    $bloatTokens=$null; $bloatErrors=$null
    $bloatAst=[System.Management.Automation.Language.Parser]::ParseInput($BloatText,[ref]$bloatTokens,[ref]$bloatErrors)
    if (@($bloatErrors).Count -eq 0) {
        $bloatCommands=@($bloatAst.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
        foreach ($danger in @('Stop-Process','takeown','icacls','cmd.exe')) {
            if (@($bloatCommands | Where-Object { $_ -eq $danger }).Count -gt 0) { Add-Fail ("OneNote: comando peligroso presente en BloatRemoval: {0}" -f $danger) }
            else { Add-Ok ("OneNote: comando peligroso ausente en BloatRemoval: {0}" -f $danger) }
        }
    } else { Add-Fail 'OneNote: BloatRemoval no parseable para las comprobaciones de endurecimiento' }
    if (-not $BloatText.Contains('$uninstallString')) { Add-Ok 'OneNote: sin ejecucion de UninstallString en BloatRemoval' }
    else { Add-Fail 'OneNote: UninstallString ejecutable presente en BloatRemoval' }
    if ($BloatText.Contains('desktop uninstall deferred; no uninstall string is executed')) { Add-Ok 'OneNote: desinstalacion de escritorio diferida y advertida' }
    else { Add-Fail 'OneNote: falta el aviso de aplazamiento del desinstalador de escritorio' }
    if ($BloatText.Contains("'OneNote'")) { Add-Ok 'OneNote: objetivo conservado en la lista de apps especiales' }
    else { Add-Fail 'OneNote: objetivo eliminado de la lista de apps especiales' }

    # OneDrive: no shell execution, no ownership/ACL changes, no forced kills
    # and no deletion-on-reboot entries. Command names come from the AST, not
    # from prose mentions in comments.
    $odTokens=$null; $odErrors=$null
    $odAst=[System.Management.Automation.Language.Parser]::ParseInput($OneDriveText,[ref]$odTokens,[ref]$odErrors)
    if (@($odErrors).Count -eq 0) {
        $odCommands=@($odAst.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
        foreach ($danger in @('cmd.exe','takeown','icacls','Stop-Process')) {
            if (@($odCommands | Where-Object { $_ -eq $danger }).Count -gt 0) { Add-Fail ("OneDrive: comando peligroso presente: {0}" -f $danger) }
            else { Add-Ok ("OneDrive: comando peligroso ausente: {0}" -f $danger) }
        }
    } else { Add-Fail 'OneDrive: OneDriveRemoval no parseable para las comprobaciones de endurecimiento' }
    if ($OneDriveText -notmatch 'MoveFileEx|MOVEFILE_DELAY_UNTIL_REBOOT|Schedule-DeleteOnReboot') {
        Add-Ok 'OneDrive: sin borrados diferidos al reinicio'
    } else { Add-Fail 'OneDrive: borrado diferido al reinicio presente' }
    $uninstallerPattern='^"?(.+?OneDriveSetup\.exe)"?\s+(/uninstall(?:\s+/allusers)?)\s*$'
    foreach ($check in @(
        @{ Fragment=$uninstallerPattern; Description='OneDrive: firma estricta de UninstallString OneDriveSetup.exe presente' },
        @{ Fragment='Get-TMPCSignature'; Description='OneDrive: verificacion de firma a traves del seam' },
        @{ Fragment='Start-TMPCVerifiedUninstaller'; Description='OneDrive: ejecucion solo a traves del ejecutor verificado' },
        @{ Fragment='Remove-OneDriveRemnant'; Description='OneDrive: eliminacion solo por la allowlist de restos' },
        @{ Fragment='Assert-NoReparsePath'; Description='OneDrive: rechazo de reparse points presente' },
        @{ Fragment='UserFolder'; Description='OneDrive: inventario de raices de sincronizacion personalizadas presente' },
        @{ Fragment='%USERPROFILE%\OneDrive'; Description='OneDrive: proteccion explicita de la carpeta de usuario presente' }
    )) {
        if ($OneDriveText.Contains($check.Fragment)) { Add-Ok $check.Description }
        else { Add-Fail ("{0}: fragmento no encontrado" -f $check.Description) }
    }

    # Embedded registry engine (mirror of the standalone idempotent contract).
    if (@($sysErrors).Count -eq 0) {
        try {
            $embeddedSet=(Get-StaticFunction $sysAst 'Set-RegistryValue').Extent.Text
            $embeddedRead=$embeddedSet.IndexOf('Get-RegistryEntryState -Path $Path -Name $Name')
            $embeddedWrite=$embeddedSet.IndexOf('Set-ItemProperty -Path $Path -Name $Name')
            $embeddedLastRead=$embeddedSet.LastIndexOf('Get-RegistryEntryState -Path $Path -Name $Name')
            if ($embeddedRead -ge 0 -and $embeddedWrite -gt $embeddedRead -and $embeddedLastRead -gt $embeddedWrite -and
                $embeddedSet.Contains('ALREADY_COMPLIANT') -and $embeddedSet.Contains('READ_DENIED') -and
                $embeddedSet.Contains('WRITE_DENIED') -and $embeddedSet.Contains('VERIFY_FAILED')) {
                Add-Ok 'XML: Set-RegistryValue lee el estado, escribe solo si difiere y verifica; estados diferenciables'
            } else { Add-Fail 'XML: Set-RegistryValue no cumple el contrato idempotente verificado' }
            foreach ($removalName in @('Remove-RegistryValue','Remove-RegistryKey')) {
                $removal=(Get-StaticFunction $sysAst $removalName).Extent.Text
                if ($removal.Contains('ALREADY_COMPLIANT') -and $removal.Contains('VERIFY_FAILED') -and $removal.Contains('READ_DENIED')) {
                    Add-Ok ("XML: {0} trata la ausencia como conforme y verifica el borrado" -f $removalName)
                } else { Add-Fail ("XML: {0} no cumple el contrato de borrado verificado" -f $removalName) }
            }
            if ((Get-StaticFunction $sysAst 'Set-BinaryBit').Extent.Text.Contains('ALREADY_COMPLIANT') -and
                (Get-StaticFunction $sysAst 'Set-BinaryBit').Extent.Text.Contains('VERIFY_FAILED') -and
                (Get-StaticFunction $sysAst 'Get-RegistryEntryState').Extent.Text.Contains('ItemNotFoundException')) {
                Add-Ok 'XML: preferencias binarias idempotentes y verificadas; lectura denegada no se confunde con ausencia'
            } else { Add-Fail 'XML: preferencias binarias o discriminacion de lectura incompletas' }
        } catch { Add-Fail ("XML hardening AST: {0}" -f $_.Exception.Message) }
    }

    # XML-wide command-name exclusions that are safe to assert globally.
    foreach ($danger in @('takeown','Stop-Process')) {
        if (@($sysCommands | Where-Object { $_ -eq $danger }).Count -gt 0) { Add-Fail ("XML: comando peligroso presente: {0}" -f $danger) }
        else { Add-Ok ("XML: comando peligroso ausente: {0}" -f $danger) }
    }
}

function Test-TestsSuite {
    $runnerRecord=Get-FileRecord -RelativePath 'scripts/tests/Invoke-TMPCTests.ps1'
    $helpersRecord=Get-FileRecord -RelativePath 'scripts/tests/TMPC.Tests.Helpers.ps1'
    if (-not $runnerRecord.Exists) { Add-Fail 'scripts/tests/Invoke-TMPCTests.ps1: no existe' }
    if (-not $helpersRecord.Exists) { Add-Fail 'scripts/tests/TMPC.Tests.Helpers.ps1: no existe' }
    if (-not $runnerRecord.Exists -or -not $helpersRecord.Exists) { return }
    if (-not $helpersRecord.DecodeOk -or -not $runnerRecord.DecodeOk) { Add-Fail 'Suite de tests: no es UTF-8 valido'; return }
    $doubleMarkers=@('Get-TMPCRegistryEntryState','Write-TMPCRegistryEntry','Remove-TMPCRegistryEntry','Get-TMPCPathItem','Get-TMPCSignature','Start-TMPCVerifiedUninstaller','Get-TMPCSystemInfo','Get-RegistryEntryState')
    $missingDoubles=@($doubleMarkers | Where-Object { -not $helpersRecord.Text.Contains($_) })
    if ($missingDoubles.Count -eq 0) { Add-Ok 'Suite de tests: dobles en memoria para Registro, sistema de archivos, firma, ejecucion y preflight' }
    else { Add-Fail ("Suite de tests: faltan dobles: {0}" -f ($missingDoubles -join ', ')) }
    $caseMarkers=@('ALREADY_COMPLIANT','READ_DENIED','WRITE_DENIED','VERIFY_FAILED','SKIPPED_NOT_APPLICABLE')
    $missingCases=@($caseMarkers | Where-Object { -not $runnerRecord.Text.Contains($_) })
    if ($missingCases.Count -eq 0) { Add-Ok 'Suite de tests: casos negativos de estados presentes' }
    else { Add-Fail ("Suite de tests: faltan casos de estados: {0}" -f ($missingCases -join ', ')) }
    if ($runnerRecord.Text.Contains('SkipValidatorCase') -and $helpersRecord.Text.Contains('function Assert-TestThrows') -and $runnerRecord.Text.Contains('Assert-TestThrows')) {
        Add-Ok 'Suite de tests: runner con caso de validador integrado y assertion de excepciones en los helpers'
    } else { Add-Fail 'Suite de tests: estructura del runner/helpers inesperada' }
}

function Get-StaticFunction {
    param($Ast, [string]$Name)
    $nodes = @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true))
    if ($nodes.Count -ne 1) { throw "Funcion no inequivoca: $Name" }
    return $nodes[0]
}

function Get-StaticInventory {
    param($Ast, [string]$FunctionName)
    $function = Get-StaticFunction $Ast $FunctionName
    $strings = @($function.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.StringConstantType -eq 'SingleQuotedHereString' }, $true))
    if ($strings.Count -ne 1) { throw "Inventario no inequivoco: $FunctionName" }
    return $strings[0].Value
}

function Get-InventoryTuples {
    param([string]$Text)
    $path = $null
    foreach ($line in ($Text -split '\r?\n')) {
        if (-not $line) { continue }
        if ($line -match '^\[(.+)\]$') { $path=$matches[1]; continue }
        if ($line -eq '!KEY') { "$path|REMOVEKEY" }
        elseif ($line.StartsWith('!')) { "$path|REMOVEVALUE|$($line.Substring(1))" }
        else { "$path|SET|$line" }
    }
}

function Get-SourceRegistryTuples {
    param([string]$Text, [string]$Hive)
    $tokens=$null; $errors=$null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text,[ref]$tokens,[ref]$errors)
    $commands = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and
        $n.GetCommandName() -in @('Set-RegistryValue','Remove-RegistryValue','Remove-RegistryKey') },$true))
    foreach ($command in $commands) {
        $args=@{}
        for ($i=1; $i -lt $command.CommandElements.Count-1; $i++) {
            $element=$command.CommandElements[$i]
            if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                $args[$element.ParameterName]=$command.CommandElements[$i+1]
            }
        }
        if (-not $args.ContainsKey('Path')) { continue }
        $pathAst=$args['Path']
        # The generic inventories are literal data. Special operations staged
        # with variables (for example the wallpaper block) are validated by
        # dedicated checks instead of the tuple comparison.
        if ($pathAst -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { continue }
        $path=$pathAst.Value
        if (-not $path.StartsWith($Hive,[StringComparison]::OrdinalIgnoreCase)) { continue }
        switch ($command.GetCommandName()) {
            'Remove-RegistryKey' { "$path|REMOVEKEY" }
            'Remove-RegistryValue' { "$path|REMOVEVALUE|$($args['Name'].SafeGetValue())" }
            'Set-RegistryValue' {
                $name=$args['Name'].SafeGetValue()
                $type=$args['Type'].SafeGetValue()
                $value=$args['Value'].SafeGetValue()
                if ($type -eq 'Binary') { $value=(@($value | ForEach-Object { '{0:X2}' -f [byte]$_ }) -join ',') }
                "$path|SET|$name|$type|$value"
            }
        }
    }
}

function Test-PostInstallStandalone {
    param([string]$SourceText, [string]$BloatText, [hashtable]$Hashes)
    Write-Section 'STANDALONE POST-INSTALL (ESTATICO; NUNCA EJECUTADO)'
    $record=Get-FileRecord 'Apply-TMPCOptimizations.ps1'
    if (-not $record.Exists -or -not $record.DecodeOk) { Add-Fail 'Standalone no disponible'; return }
    if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSEdition -ne 'Desktop') {
        Add-Fail 'Ejecutar este validador en Windows PowerShell 5.1 para validar su parser'
    }
    Test-PowerShellBlock 'Apply-TMPCOptimizations.ps1 (parser 5.1)' $record.Text
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseInput($record.Text.TrimStart([char]0xFEFF),[ref]$tokens,[ref]$errors)
    $hashMatches=[regex]::Matches($record.Text,'SOURCE_AUTOUNATTEND_SHA256 = ([A-F0-9]{64})')
    if ($hashMatches.Count -eq 1 -and $hashMatches[0].Groups[1].Value -eq $Hashes['autounattend.xml']) {
        Add-Ok 'Standalone: SOURCE_AUTOUNATTEND_SHA256 coincide; deriva futura bloqueada'
    } else { Add-Fail 'Standalone: hash fuente ausente/ambiguo/desincronizado' }
    $fixedHashes=@{
        'autounattend.xml'='D99BF0EC59A8CB322A84E99F36373FEDD6358350A0D053A02FEB24C11A608EA4'
        'ventoy.json'='058F0FB83D2BD9EBBB471E518040E04C0CD9D1A752CBBCEC5904166B9EB5908B'
    }
    foreach ($file in $fixedHashes.Keys) {
        if ($Hashes[$file] -eq $fixedHashes[$file]) { Add-Ok "${file}: hash esperado del candidato vigente" }
        else { Add-Fail "${file}: revisar expresamente la sincronizacion del baseline" }
    }
    try {
        # No dot-sourcing, Invoke-Expression, compiled optimizer code or execution:
        # inspect literal DATA and constant arguments with the parser only.
        # ConfigureStartPins is staged explicitly in Invoke-SystemPhase (persistent
        # JSON first, ADMX-exact machine policy pair afterwards), so the two exact
        # data operations it represents are added back to the standalone side of
        # the parity comparison.
        $startPinsPath='C:\ProgramData\TMPC-Windows-11-Optimization\LayoutModification.json'
        $startPinsFlagCall="-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPins' -Type 'DWord' -Value 1"
        $startPinsJsonCall="-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPinsJSON' -Type 'ExpandString' -Value '$startPinsPath'"
        $startPinsFlagExplicit="Set-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPins' -Type DWord -Value 1 -Force"
        $startPinsJsonExplicit="Set-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPinsJSON' -Type ExpandString -Value '$startPinsPath' -Force"
        $startPinsFlagTuple="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|SET|ConfigureStartPins|DWord|1"
        $startPinsJsonTuple="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|SET|ConfigureStartPinsJSON|ExpandString|$startPinsPath"
        $startPinsSystemText=(Get-StaticFunction $ast 'Invoke-SystemPhase').Extent.Text
        $startPinsFlagCount=@([regex]::Matches($startPinsSystemText,[regex]::Escape($startPinsFlagExplicit))).Count
        $startPinsJsonCount=@([regex]::Matches($startPinsSystemText,[regex]::Escape($startPinsJsonExplicit))).Count
        foreach ($scope in @(@{Function='Get-SystemRegistryProfile';Hive='HKLM:'},@{Function='Get-UserRegistryProfile';Hive='HKCU:'})) {
            $actual=@(Get-InventoryTuples (Get-StaticInventory $ast $scope.Function))
            $expected=@(Get-SourceRegistryTuples $SourceText $scope.Hive)
            if ($scope.Hive -eq 'HKLM:' -and $startPinsFlagCount -eq 1 -and $startPinsJsonCount -eq 1) {
                $actual+=$startPinsFlagTuple
                $actual+=$startPinsJsonTuple
            }
            $delta=@(Compare-Object ($expected | Sort-Object -Unique) ($actual | Sort-Object -Unique))
            if ($delta.Count -eq 0) { Add-Ok "Standalone $($scope.Hive): inventario Registro EXACTO ($($expected.Count) operaciones fuente)" }
            else {
                Add-Fail "Standalone $($scope.Hive): delta Registro ($($delta.Count))"
                foreach ($d in $delta) { Write-Host ("       {0} {1}" -f $d.SideIndicator,$d.InputObject) }
            }
            if (@($actual | Where-Object { -not $_.StartsWith($scope.Hive,[StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
                Add-Fail 'Standalone: inventario cruza la frontera HKLM/HKCU'
            }
        }
        # Start pins candidate: persistent empty JSON staged through the ADMX-exact machine policy pair.
        if ($SourceText.Contains($startPinsFlagCall) -and $SourceText.Contains($startPinsJsonCall)) {
            Add-Ok 'Start pins: XML usa el par ADMX DWord 1 + ExpandString con ruta persistente'
        } else { Add-Fail 'Start pins: XML no usa el par ADMX esperado' }
        if (@([regex]::Matches($SourceText,[regex]::Escape($startPinsFlagCall))).Count -eq 1 -and
            @([regex]::Matches($SourceText,[regex]::Escape($startPinsJsonCall))).Count -eq 1) {
            Add-Ok 'Start pins: XML define cada operacion exactamente una vez (sin duplicados)'
        } else { Add-Fail 'Start pins: operacion XML ausente o duplicada' }
        if ($startPinsFlagCount -eq 1 -and $startPinsJsonCount -eq 1) {
            Add-Ok 'Start pins: standalone aplica el par ADMX una sola vez desde Invoke-SystemPhase'
        } else { Add-Fail 'Start pins: par explicito ausente o duplicado en Invoke-SystemPhase' }
        $startPinsInventory=(Get-StaticInventory $ast 'Get-SystemRegistryProfile')
        if ($startPinsInventory -match 'ConfigureStartPins\|') {
            Add-Fail 'Start pins: inventario generico todavia contiene ConfigureStartPins (duplicado)'
        } else { Add-Ok 'Start pins: inventario generico sin ConfigureStartPins (sin duplicados)' }
        if ($SourceText.Contains("-Name 'ConfigureStartPins' -Type 'String'") -or $record.Text.Contains("-Name 'ConfigureStartPins' -Type String ")) {
            Add-Fail 'Start pins: representacion antigua REG_SZ de ConfigureStartPins presente'
        } else { Add-Ok 'Start pins: sin representacion antigua REG_SZ de ConfigureStartPins' }
        if ($SourceText -match 'PolicyManager\\current\\device\\Start''\s+-Name\s+''ConfigureStartPins''') {
            Add-Fail 'Start pins: escritura antigua en PolicyManager\current\device\Start presente'
        } else { Add-Ok 'Start pins: sin ConfigureStartPins en PolicyManager\current\device\Start' }
        $jsonLiteral='{"applyOnce":true,"pinnedList":[]}'
        if ($SourceText.Contains($jsonLiteral) -and $record.Text.Contains($jsonLiteral)) {
            Add-Ok 'Start pins: JSON exacto compartido por XML y standalone'
        } else { Add-Fail 'Start pins: JSON exacto ausente o divergente' }
        try {
            $parsedJson=ConvertFrom-Json -InputObject $jsonLiteral
            if ($parsedJson.applyOnce -eq $true -and @($parsedJson.pinnedList).Count -eq 0) {
                Add-Ok 'Start pins: JSON parseable con applyOnce=true y pinnedList vacio'
            } else { Add-Fail 'Start pins: JSON no cumple applyOnce/pinnedList esperados' }
        } catch { Add-Fail 'Start pins: JSON literal no parseable' }
        if ($startPinsPath.StartsWith('C:\ProgramData\Autounattend',[StringComparison]::OrdinalIgnoreCase)) {
            Add-Fail 'Start pins: el JSON persistente esta bajo la ruta de cleanup'
        } else { Add-Ok 'Start pins: JSON persistente fuera de la ruta de cleanup' }
        if ($SourceText -match '(?is)Remove-Item.{0,200}TMPC-Windows-11-Optimization') {
            Add-Fail 'Start pins: cleanup intenta borrar la ruta persistente'
        } else { Add-Ok 'Start pins: cleanup no toca la ruta persistente' }
        $xWrite=$SourceText.IndexOf('[System.IO.File]::WriteAllText($startPinsJsonPath')
        $xFlag=$SourceText.IndexOf($startPinsFlagCall)
        $xJson=$SourceText.IndexOf($startPinsJsonCall)
        $xKind=$SourceText.IndexOf("GetValueKind('ConfigureStartPins')")
        if ($xWrite -ge 0 -and $xFlag -gt $xWrite -and $xJson -gt $xFlag -and $xKind -gt $xJson) {
            Add-Ok 'Start pins: XML crea el JSON antes del par ADMX y verifica tipos despues'
        } else { Add-Fail 'Start pins: orden XML JSON -> par ADMX -> verificacion incorrecto' }
        $iWrite=$record.Text.IndexOf('[System.IO.File]::WriteAllText($startPinsJsonPath')
        $iContent=$record.Text.IndexOf('if ($startPinsWritten -ne $startPinsJsonContent)')
        $iFlag=$record.Text.IndexOf($startPinsFlagExplicit)
        $iJson=$record.Text.IndexOf($startPinsJsonExplicit)
        $iKind=$record.Text.IndexOf("GetValueKind('ConfigureStartPins')")
        if ($iWrite -ge 0 -and $iContent -gt $iWrite -and $iFlag -gt $iContent -and $iJson -gt $iFlag -and $iKind -gt $iJson) {
            Add-Ok 'Start pins: standalone crea y verifica el JSON antes del par ADMX y verifica tipos despues'
        } else { Add-Fail 'Start pins: orden standalone JSON -> par ADMX -> verificacion incorrecto' }
        if ($startPinsSystemText.Contains($startPinsFlagExplicit) -and $startPinsSystemText.Contains($startPinsJsonExplicit) -and -not (Get-StaticFunction $ast 'Invoke-UserPhase').Extent.Text.Contains('ConfigureStartPins')) {
            Add-Ok 'Start pins: la politica de maquina vive solo en Invoke-SystemPhase; UserOnly sin cambio global'
        } else { Add-Fail 'Start pins: riesgo de politica global fuera de Full' }
        if ($record.Text.Contains($startPinsPath) -and $record.Text.Contains('GetValueKind')) {
            Add-Ok 'Standalone: staging y verificacion de tipos del par ADMX presentes'
        } else { Add-Fail 'Standalone: falta staging o verificacion del par ADMX' }
        # Cloud optimized content policy: machine-level suppression of cloud
        # optimized promotional taskbar pins (for example the Outlook
        # placeholder). Exactly one inventory entry in the standalone and one
        # operation in the XML; HKLM only, DWord 1; never part of UserOnly.
        $cloudContentCall="-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableCloudOptimizedContent' -Type 'DWord' -Value 1"
        $cloudContentTuple='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent|SET|DisableCloudOptimizedContent|DWord|1'
        $cloudContentInv=(Get-StaticInventory $ast 'Get-SystemRegistryProfile')
        if ($SourceText.Contains($cloudContentCall)) {
            Add-Ok 'Cloud optimized content: XML usa la ruta HKLM exacta con DisableCloudOptimizedContent, DWord y valor 1'
        } else { Add-Fail 'Cloud optimized content: operacion XML ausente o con forma distinta' }
        if (@([regex]::Matches($SourceText,[regex]::Escape($cloudContentCall))).Count -eq 1) {
            Add-Ok 'Cloud optimized content: XML define la operacion exactamente una vez'
        } else { Add-Fail 'Cloud optimized content: operacion XML ausente o duplicada' }
        if (@([regex]::Matches($cloudContentInv,'(?m)^DisableCloudOptimizedContent\|DWord\|1\r?$')).Count -eq 1) {
            Add-Ok 'Cloud optimized content: standalone la declara exactamente una vez en el inventario HKLM'
        } else { Add-Fail 'Cloud optimized content: definicion standalone ausente o duplicada' }
        if (@(Get-InventoryTuples $cloudContentInv) -contains $cloudContentTuple) {
            Add-Ok 'Cloud optimized content: inventario standalone HKLM equivalente al XML'
        } else { Add-Fail 'Cloud optimized content: inventario standalone no equivalente al XML' }
        if (-not (Get-StaticFunction $ast 'Invoke-UserPhase').Extent.Text.Contains('DisableCloudOptimizedContent')) {
            Add-Ok 'Cloud optimized content: UserOnly no aplica la politica global'
        } else { Add-Fail 'Cloud optimized content: la politica global aparece en UserOnly' }
        if ((Get-StaticFunction $ast 'Invoke-SystemPhase').Extent.Text.Contains("GetValueKind('DisableCloudOptimizedContent')")) {
            Add-Ok 'Cloud optimized content: verificacion de tipo en Invoke-SystemPhase'
        } else { Add-Fail 'Cloud optimized content: falta la verificacion de tipo en Invoke-SystemPhase' }
        # All apps view mode: first-run HKCU "List" preference. Applied once in the
        # user phase, only when the value is absent (an existing user choice is
        # preserved), never from the system phase and never part of the generic
        # inventories, so no recurring policy or additional task is created.
        # Status: RUNTIME_EXISTING_PROFILE = PASS (manual on 26H2);
        # CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED; STANDALONE_RUNTIME = NOT_TESTED.
        $allAppsPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
        $allAppsWrite="-Name 'AllAppsViewMode' -Type DWord -Value 2"
        $allAppsPresence="GetValueNames() -contains 'AllAppsViewMode'"
        $allAppsGuard='-lt 22000'
        $allAppsSoloPresence='Get-TMPCRegistryEntryState -Path $path -Name ''AllAppsViewMode'''
        $allAppsSoloWrite='Write-TMPCRegistryEntry -Path $path -Name ''AllAppsViewMode'' -Type ''DWord'' -Value 2'
        $allAppsUserPhase=(Get-StaticFunction $ast 'Invoke-UserPhase').Extent.Text
        $allAppsFunction=(Get-StaticFunction $ast 'Invoke-AllAppsViewPreference').Extent.Text
        $allAppsXmlWrite=@([regex]::Matches($SourceText,[regex]::Escape($allAppsWrite))).Count
        $allAppsXmlPresence=@([regex]::Matches($SourceText,[regex]::Escape($allAppsPresence))).Count
        if ($allAppsXmlPresence -eq 1 -and $allAppsXmlWrite -eq 1) {
            Add-Ok 'All apps view mode: XML comprueba la presencia y escribe REG_DWORD 2 exactamente una vez'
        } else { Add-Fail 'All apps view mode: operacion XML ausente o duplicada' }
        if ($SourceText.Contains($allAppsPath) -and $SourceText.Contains($allAppsGuard)) {
            Add-Ok 'All apps view mode: XML usa la ruta HKCU Start y el gate de build Windows 11'
        } else { Add-Fail 'All apps view mode: ruta o gate de build ausentes en el XML' }
        $xAllAppsPresence=$SourceText.IndexOf($allAppsPresence)
        $xAllAppsWrite=$SourceText.IndexOf($allAppsWrite)
        if ($xAllAppsPresence -ge 0 -and $xAllAppsWrite -gt $xAllAppsPresence) {
            Add-Ok 'All apps view mode: XML comprueba la existencia antes de escribir y preserva la preferencia'
        } else { Add-Fail 'All apps view mode: orden de no sobrescritura incorrecto en el XML' }
        if ($allAppsFunction.Contains($allAppsPath) -and
            $allAppsFunction.IndexOf($allAppsSoloPresence) -ge 0 -and
            $allAppsFunction.LastIndexOf($allAppsSoloPresence) -gt $allAppsFunction.IndexOf($allAppsSoloWrite) -and
            $allAppsFunction.IndexOf($allAppsSoloWrite) -gt $allAppsFunction.IndexOf($allAppsSoloPresence)) {
            Add-Ok 'All apps view mode: standalone define ruta, lectura previa, escritura condicional y reverificacion REG_DWORD 2'
        } else { Add-Fail 'All apps view mode: definicion standalone ausente o incompleta' }
        if ($allAppsFunction -notmatch 'HKLM[:\\]|HKEY_LOCAL_MACHINE' -and $allAppsFunction.Contains($allAppsGuard)) {
            Add-Ok 'All apps view mode: funcion HKCU pura con gate de build; sin operaciones HKLM'
        } else { Add-Fail 'All apps view mode: la funcion standalone cruza la frontera HKLM o carece de gate' }
        $sAllAppsPresence=$allAppsFunction.IndexOf($allAppsSoloPresence)
        $sAllAppsWrite=$allAppsFunction.IndexOf($allAppsSoloWrite)
        if ($sAllAppsPresence -ge 0 -and $sAllAppsWrite -gt $sAllAppsPresence) {
            Add-Ok 'All apps view mode: standalone comprueba la existencia antes de escribir y preserva la preferencia'
        } else { Add-Fail 'All apps view mode: orden de no sobrescritura incorrecto en el standalone' }
        if (@([regex]::Matches($allAppsUserPhase,'Invoke-AllAppsViewPreference')).Count -eq 1 -and
            -not (Get-StaticFunction $ast 'Invoke-SystemPhase').Extent.Text.Contains('AllAppsViewMode')) {
            Add-Ok 'All apps view mode: se aplica una sola vez desde la fase de usuario; ausente en la fase de sistema'
        } else { Add-Fail 'All apps view mode: llamada UserOnly ausente, duplicada o presente en la fase de sistema' }
        if (-not (Get-StaticInventory $ast 'Get-SystemRegistryProfile').Contains('AllAppsViewMode') -and
            -not (Get-StaticInventory $ast 'Get-UserRegistryProfile').Contains('AllAppsViewMode')) {
            Add-Ok 'All apps view mode: fuera de los inventarios genericos (sin sobrescritura recurrente)'
        } else { Add-Fail 'All apps view mode: presente en un inventario generico (sobrescribiria la preferencia)' }
        if ($record.Text -match '(?i)gpupdate|registry\.pol|gpedit') {
            Add-Fail 'Standalone: sin gpupdate/Registry.pol/gpedit (sin fallback especulativo)'
        } else { Add-Ok 'Standalone: sin gpupdate/Registry.pol/gpedit (sin fallback especulativo)' }
        $bloat=Get-StaticFunction $ast 'Invoke-BloatRemoval'
        $bt=$null; $be=$null
        $ba=[System.Management.Automation.Language.Parser]::ParseInput($BloatText,[ref]$bt,[ref]$be)
        foreach ($name in @('packages','capabilities','optionalFeatures','specialApps')) {
            $find={ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq ('$'+$name) }
            $source=@($ba.FindAll($find,$true))
            $target=@($bloat.FindAll($find,$true))
            if ($source.Count -ne 1 -or $target.Count -ne 1) { throw "Lista no inequivoca: $name" }
            $s=@($source[0].Right.FindAll({param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst]},$true) | ForEach-Object Value)
            $t=@($target[0].Right.FindAll({param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst]},$true) | ForEach-Object Value)
            if (@(Compare-Object $s $t).Count -eq 0) { Add-Ok "Standalone debloat $name EXACTO ($($s.Count))" }
            else { Add-Fail "Standalone debloat $name difiere del XML" }
        }
        $binary=Get-StaticInventory $ast 'Invoke-UserBinaryPreferences'
        $expectedBits=@()
        $pattern='(?m)^\s*Set-BinaryBit -Path ''HKCU:\\([^'']+)'' -Name ''([^'']+)'' -ByteIndex (\d+) -BitMask 0x([0-9a-fA-F]+) -SetBit \$(True|False)'
        foreach ($m in [regex]::Matches($SourceText,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $bit=if ($m.Groups[5].Value -eq 'True') {'1'} else {'0'}
            $expectedBits += '{0}|{1}|{2}|{3}|{4}' -f $m.Groups[1].Value,$m.Groups[2].Value,$m.Groups[3].Value,$m.Groups[4].Value,$bit
        }
        if ($expectedBits.Count -eq 10 -and @(Compare-Object $expectedBits ($binary -split '\r?\n')).Count -eq 0) {
            Add-Ok 'Standalone: 10 preferencias binarias EXACTAS'
        } else { Add-Fail 'Standalone: preferencias binarias difieren del XML' }
        $sys=Get-StaticFunction $ast 'Invoke-SystemPhase'
        $taskAssign=@($sys.FindAll({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$scheduledTasks'},$true))
        $tasks=@($taskAssign[0].Right.FindAll({param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst]},$true) | ForEach-Object Value)
        $sourceTasks=@([regex]::Matches($SourceText,'(?m)^\s*@\{ TN="([^"]+)"; Action="/Disable"') | ForEach-Object { $_.Groups[1].Value })
        if ($sourceTasks.Count -eq 10 -and @(Compare-Object $sourceTasks $tasks).Count -eq 0) { Add-Ok 'Standalone: 10 tareas del perfil EXACTAS; Autochk preservada' }
        else { Add-Fail 'Standalone: lista de tareas difiere' }
        $params=@($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        if ($params -contains 'UserOnly' -and $params -contains 'Restart' -and
            $record.Text.Contains("if (-not `$UserOnly) { Invoke-SystemPhase }")) { Add-Ok 'Standalone: Full por defecto, UserOnly y Restart explicitos' }
        else { Add-Fail 'Standalone: modos no inequivocos' }
        $user=Get-StaticFunction $ast 'Invoke-UserPhase'
        $userCommands=@($user.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
        $allowed=@('Invoke-RegistryProfile','Get-UserRegistryProfile','Invoke-UserBinaryPreferences','Invoke-QuietHours',
            'Invoke-DownloadsPreference','Invoke-AllAppsViewPreference','Join-Path','Test-Path','Write-Log','Invoke-Operation','Set-ItemProperty','Get-Item','Remove-ItemProperty',
            'Get-TMPCRegistryEntryState','Write-TMPCRegistryEntry','Remove-TMPCRegistryEntry')
        if (@($userCommands | Where-Object { $_ -notin $allowed }).Count -eq 0 -and -not $user.Extent.Text.Contains('HKLM:')) {
            Add-Ok 'Standalone: entrada UserOnly solo preferencias HKCU; sin fase global'
        } else { Add-Fail 'Standalone: revisar comandos del grafo UserOnly' }
        foreach ($functionName in @('Invoke-UserBinaryPreferences','Invoke-QuietHours','Invoke-DownloadsPreference','Invoke-AllAppsViewPreference')) {
            $function=Get-StaticFunction $ast $functionName
            $calls=@($function.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
            $userAllowed=@('Invoke-Operation','New-Item','Test-Path','Get-Item','Set-ItemProperty','Get-ItemProperty','Remove-Item',
                'New-Object','Add-Type','Write-Log','Invoke-Native','Out-Null',
                'Get-TMPCRegistryEntryState','Write-TMPCRegistryEntry')
            if (@($calls | Where-Object { $_ -notin $userAllowed }).Count -gt 0) { throw "Grafo UserOnly con comando inesperado: $functionName" }
            if ($functionName -ne 'Invoke-DownloadsPreference' -and $function.Extent.Text -match 'HKLM[:\\]|HKEY_LOCAL_MACHINE') {
                throw "HKLM inesperado en $functionName"
            }
        }
        Add-Ok 'Standalone: helpers UserOnly auditados sin debloat, energia, tasks ni OneDrive global'
        $systemCalls=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Invoke-SystemPhase'},$true))
        if ($systemCalls.Count -ne 1 -or $systemCalls[0].Parent.Parent.Parent.Extent.Text -notmatch 'if \(-not \$UserOnly\)') {
            throw 'Fase global no confinada al modo Full'
        }
        $nativeCalls=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Invoke-Native'},$true))
        foreach ($call in $nativeCalls) {
            if ($call.CommandElements[1].SafeGetValue() -notin @('reg.exe','powercfg.exe','shutdown.exe')) { throw 'Ejecutable nativo inesperado' }
        }
        Add-Ok 'Standalone: unica entrada de sistema protegida por not UserOnly; ejecutables nativos acotados'
        # Critical command exclusions operate on AST command names, not prose.
        $commands=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst]},$true) | ForEach-Object { $_.GetCommandName() })
        $forbidden=@('diskpart','diskpart.exe','Format-Volume','Clear-Disk','Initialize-Disk','Format','clean','bcdedit',
            'Invoke-WebRequest','Invoke-RestMethod','Start-BitsTransfer','curl','curl.exe','wget','Invoke-Expression',
            'Disable-NetAdapter','Enable-NetAdapter','Set-MpPreference','Add-MpPreference','Stop-Process',
            'Register-ScheduledTask','New-LocalUser','Remove-LocalUser','takeown','icacls','cmd.exe')
        if (@($commands | Where-Object { $_ -in $forbidden }).Count -eq 0) { Add-Ok 'Standalone: sin comandos de disco, descargas, cuentas, Defender disable, impersonacion ni kills' }
        else { Add-Fail 'Standalone: comando critico prohibido detectado' }
        $delete=Get-StaticFunction $ast 'Remove-OneDriveRemnant'
        foreach ($snippet in @('$allowed -notcontains $full',"Join-Path `$env:USERPROFILE 'OneDrive'",'Assert-NoReparsePath $full','FileAttributes]::ReparsePoint','$script:ProtectedOneDriveRoots','$script:OneDriveProtectionReady')) {
            if (-not $delete.Extent.Text.Contains($snippet)) { throw 'Proteccion OneDrive ausente' }
        }
        # Every filesystem Remove-Item outside this function must target registry.
        $removes=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Remove-Item'},$true))
        foreach ($remove in $removes) {
            $owner=$remove.Parent
            while ($owner -and $owner -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { $owner=$owner.Parent }
            if (-not $owner -or $owner.Name -notin @('Remove-OneDriveRemnant','Invoke-RegistryProfile','Invoke-DownloadsPreference','Invoke-OneDriveRemoval','Invoke-SystemPhase','Remove-TMPCRegistryEntry')) {
                throw 'Borrado fuera de las funciones auditadas'
            }
        }
        Add-Ok 'Standalone: OneDrive protegido, allowlist de restos y rechazo de reparse points'
        foreach ($name in @('DisableAntiSpyware','DisableRealtimeMonitoring','DisableAntiVirus','DisableBehaviorMonitoring')) {
            if ($record.Text.Contains($name)) { throw 'Decision Defender alterada' }
        }
        Add-Ok 'Standalone: Defender preservado; Store/Edge/WebView2 no son targets de debloat'
        if ($record.Text.Contains('Test-TMPCRestartRequested -RestartRequested $Restart.IsPresent -ExitCode $exitCode') -and
            $record.Text.Contains('return ($RestartRequested -and $ExitCode -eq 0)') -and
            $record.Text.Contains('if ($UserOnly -and ($Restart -or $NetFx3Source))')) {
            Add-Ok 'Standalone: reinicio solo con Restart explicito y sin errores; UserOnly no reinicia'
        } else { Add-Fail 'Standalone: gate de reinicio ausente' }
        # Idempotent verified registry engine: read -> compare -> conditional
        # verified write, with distinguishable per-operation states.
        $registryEngine=(Get-StaticFunction $ast 'Invoke-RegistryProfile').Extent.Text
        $engineFirstRead=$registryEngine.IndexOf('Get-TMPCRegistryEntryState -Path $path -Name $name')
        $engineWrite=$registryEngine.IndexOf('Write-TMPCRegistryEntry -Path $path -Name $name')
        $engineLastRead=$registryEngine.LastIndexOf('Get-TMPCRegistryEntryState -Path $path -Name $name')
        if ($engineFirstRead -ge 0 -and $engineWrite -gt $engineFirstRead -and $engineLastRead -gt $engineWrite -and
            -not $registryEngine.Contains('Set-ItemProperty')) {
            Add-Ok 'Motor idempotente: Invoke-RegistryProfile lee, escribe solo si difiere y reverifica a traves del seam'
        } else { Add-Fail 'Motor idempotente: el patron leer -> escribir -> verificar no se cumple' }
        $engineTokens=@('ALREADY_COMPLIANT','READ_DENIED','WRITE_DENIED','WRITE_FAILED','VERIFY_FAILED','CONFLICTING_STATE')
        $engineMissing=@($engineTokens | Where-Object { -not $record.Text.Contains($_) })
        if ($engineMissing.Count -eq 0) {
            Add-Ok 'Motor idempotente: estados diferenciables presentes (ALREADY_COMPLIANT, READ_DENIED, WRITE_DENIED, WRITE_FAILED, VERIFY_FAILED, CONFLICTING_STATE)'
        } else { Add-Fail ("Motor idempotente: faltan estados: {0}" -f ($engineMissing -join ', ')) }
        if (@($engineTokens | Where-Object { -not $registryEngine.Contains($_) -and $_ -ne 'CONFLICTING_STATE' }).Count -eq 0 -and
            $registryEngine.Contains('READ_DENIED') -and $registryEngine.Contains('WRITE_DENIED') -and
            $registryEngine.Contains('VERIFY_FAILED') -and $registryEngine.Contains('ALREADY_COMPLIANT')) {
            Add-Ok 'Motor idempotente: el perfil de Registro distingue conforme, lectura/escritura denegadas y verificacion'
        } else { Add-Fail 'Motor idempotente: el perfil de Registro no distingue los estados esperados' }
        if ($record.Text.Contains("'SKIPPED_NOT_APPLICABLE'") -and $record.Text.Contains("'COMPLIANT'") -and
            $record.Text.Contains('already compliant: $script:Compliant; skipped: $script:Skipped')) {
            Add-Ok 'Motor idempotente: contadores y niveles de log distinguen aplicadas, conformes y omitidas'
        } else { Add-Fail 'Motor idempotente: contadores o niveles de log ausentes' }
        foreach ($seam in @('Get-TMPCRegistryEntryState','Write-TMPCRegistryEntry','Remove-TMPCRegistryEntry','Test-TMPCRegistryStateEqual','Get-TMPCPathItem','Get-TMPCSignature','Start-TMPCVerifiedUninstaller','Get-TMPCSystemInfo')) {
            $nodes=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $seam},$true))
            if ($nodes.Count -ne 1) { throw "Seam no inequivoco: $seam" }
        }
        Add-Ok 'Motor idempotente: puntos de inyeccion (seams) de Registro, sistema de archivos, firma, ejecucion y preflight definidos una sola vez'
        if ($registryEngine.Contains('Test-TMPCRegistryStateEqual')) {
            Add-Ok 'Motor idempotente: comparacion exacta de tipo y valor (incluidas cadenas ordinales y binarios byte a byte)'
        } else { Add-Fail 'Motor idempotente: falta la comparacion exacta de tipo/valor' }
    } catch { Add-Fail ("Standalone AST: {0}" -f $_.Exception.Message) }
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
        'scripts/validate-baseline.ps1',
        'scripts/tests/TMPC.Tests.Helpers.ps1',
        'scripts/tests/Invoke-TMPCTests.ps1',
        'Apply-TMPCOptimizations.ps1'
    )
    try {
        if ((Get-Location).ProviderPath -ne $script:Root) {
            Add-Warn 'Git: ejecutar desde la raiz para comprobar atributos de esta copia'
            return
        }
        $output = @(& git check-attr eol -- $targets 2>$null)
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
        'scripts/tests/TMPC.Tests.Helpers.ps1'               = 'lf'
        'scripts/tests/Invoke-TMPCTests.ps1'                 = 'lf'
        'Apply-TMPCOptimizations.ps1'                        = 'lf'
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
    'Apply-TMPCOptimizations.ps1',
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
    'docs/post-installation-checks.md',
    'scripts/tests/TMPC.Tests.Helpers.ps1',
    'scripts/tests/Invoke-TMPCTests.ps1'
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
if ($null -eq $gitCmd -or (Get-Location).ProviderPath -ne $script:Root) {
    Add-Warn 'Git no disponible o cwd distinto de RepoRoot: sin consulta Git de esta copia'
} else {
    try {
        $branch = @(& git rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $branch.Count -ge 1) {
            Add-Ok ("Rama Git: {0}" -f $branch[0])
        } else {
            Add-Warn 'No se pudo consultar la rama Git'
        }
    } catch {
        Add-Warn 'No se pudo consultar la rama Git'
    }
    try {
        $statusLines = @(& git status --porcelain 2>$null)
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

    Write-Section 'XML HARDENING (ONENOTE/ONEDRIVE)'
    if ($null -ne $sysText -and $null -ne $bloatText -and $null -ne $oneDriveText) {
        Test-XmlHardening -SystemText $sysText -BloatText $bloatText -OneDriveText $oneDriveText
    } else {
        Add-Fail 'XML hardening: no se pudieron extraer todos los bloques embebidos'
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
    if ([string]$image -eq '/Windows11_Client_x64_es-es_26300_9457.iso') { Add-Ok 'image = "/Windows11_Client_x64_es-es_26300_9457.iso"' } else { Add-Fail ("image = {0} (esperado /Windows11_Client_x64_es-es_26300_9457.iso)" -f $image) }
    if ([string]$template -eq '/ventoy/script/autounattend.xml') { Add-Ok 'template = "/ventoy/script/autounattend.xml"' } else { Add-Fail ("template = {0} (esperado /ventoy/script/autounattend.xml)" -f $template) }
    if ([string]$autosel -eq '1') { Add-Ok 'autosel = 1' } else { Add-Fail ("autosel = {0} (esperado 1)" -f $autosel) }
    if ([string]$timeout -eq '0') { Add-Ok 'timeout = 0' } else { Add-Fail ("timeout = {0} (esperado 0)" -f $timeout) }
}

# ---------------------------------------------------------------------------
# Plataforma objetivo 26H2
# ---------------------------------------------------------------------------

Write-Section 'COMPATIBILIDAD POR CAPAS (TESTED_ON / NOT_RUNTIME_TESTED)'

$platformStandalone = Get-FileRecord -RelativePath 'Apply-TMPCOptimizations.ps1'
if ($platformStandalone.Exists -and $platformStandalone.DecodeOk) {
    $platformText = $platformStandalone.Text
    if ($platformText.Contains('function Get-TMPCPreflightResult') -and $platformText.Contains('function Get-TMPCSystemInfo')) {
        Add-Ok 'Standalone: preflight por capas con sonda de entorno inyectable'
    } else {
        Add-Fail 'Standalone: falta el preflight por capas'
    }
    foreach ($check in @(
        @{ Fragment = '$info.ProductType -ne 1'; Description = 'Standalone: rechazo de ediciones de servidor' },
        @{ Fragment = '$info.Build -lt 22000'; Description = 'Standalone: rechazo de familias anteriores a Windows 11' },
        @{ Fragment = "PSEdition -ne 'Desktop'"; Description = 'Standalone: rechazo de PowerShell no Desktop' },
        @{ Fragment = 'PSVersionMajor -ne 5'; Description = 'Standalone: rechazo de PowerShell distinto de 5.1' },
        @{ Fragment = 'Is64BitProcess'; Description = 'Standalone: rechazo de procesos de 32 bits' },
        @{ Fragment = "ProcessArch -ne 'AMD64'"; Description = 'Standalone: rechazo de arquitectura de proceso no AMD64' },
        @{ Fragment = "MachineArch -ne 'AMD64'"; Description = 'Standalone: rechazo de arquitectura nativa no AMD64' },
        @{ Fragment = 'S-1-5-18'; Description = 'Standalone: rechazo de cuentas de servicio' },
        @{ Fragment = 'Full mode requires Windows PowerShell opened with Run as administrator'; Description = 'Standalone: Full exige elevacion' },
        @{ Fragment = 'if ($UserOnly -and ($Restart -or $NetFx3Source))'; Description = 'Standalone: UserOnly rechaza parametros incompatibles' },
        @{ Fragment = 'CanApplyUser'; Description = 'Standalone: identidad HKCU verificada o diferida' },
        @{ Fragment = 'NOT_RUNTIME_TESTED'; Description = 'Standalone: estado NOT_RUNTIME_TESTED registrado' },
        @{ Fragment = 'TESTED_ON'; Description = 'Standalone: referencia probada TESTED_ON declarada' }
    )) {
        if ($platformText.Contains($check.Fragment)) { Add-Ok $check.Description } else { Add-Fail ("{0}: fragmento no encontrado" -f $check.Description) }
    }
    if ($platformText -notmatch '\$build -lt 26300 -or \$build -ge 26400' -and $platformText -notmatch "-ne '26H2'") {
        Add-Ok 'Standalone: sin bloqueo por build 26300-26399 ni DisplayVersion 26H2'
    } else {
        Add-Fail 'Standalone: permanece el bloqueo obsoleto por build/version'
    }
    if ($platformText -notmatch '26200') {
        Add-Ok 'Standalone: sin preflight operativo residual de 25H2/26200'
    } else {
        Add-Fail 'Standalone: queda preflight operativo de 25H2/26200'
    }
} else {
    Add-Fail 'Standalone no disponible para las comprobaciones de plataforma'
}

foreach ($compatDoc in @('docs/configuracion-pruebas-limitaciones-fuentes.md','docs/configuration-testing-limitations-sources.md')) {
    $compatRecord = Get-FileRecord -RelativePath $compatDoc
    if ($compatRecord.Exists -and $compatRecord.DecodeOk) {
        $missingCategories = @('TESTED_ON','SUPPORTED_BY_DESIGN','NOT_RUNTIME_TESTED','UNSUPPORTED','INCOMPATIBLE' | Where-Object { -not $compatRecord.Text.Contains($_) })
        if ($missingCategories.Count -eq 0) {
            Add-Ok ("{0}: categorias de compatibilidad documentadas" -f $compatDoc)
        } else {
            Add-Fail ("{0}: faltan categorias de compatibilidad: {1}" -f $compatDoc, ($missingCategories -join ', '))
        }
    } else {
        Add-Fail ("{0}: no disponible para las categorias de compatibilidad" -f $compatDoc)
    }
}

$platformXml = Get-FileRecord -RelativePath 'autounattend.xml'
if ($platformXml.Exists -and $platformXml.DecodeOk) {
    if ($platformXml.Text.Contains('Target reference: Windows 11 Pro 26H2 (build base 26300)')) {
        Add-Ok 'autounattend.xml: referencia objetivo 26H2 (base 26300) presente'
    } else {
        Add-Fail 'autounattend.xml: falta la referencia objetivo 26H2'
    }
    if ($platformXml.Text.Contains('Target reference: Windows 11 25H2.')) {
        Add-Fail 'autounattend.xml: referencia objetivo 25H2 obsoleta presente'
    } else {
        Add-Ok 'autounattend.xml: sin referencia objetivo operativa a 25H2'
    }
} else {
    Add-Fail 'autounattend.xml no disponible para las comprobaciones de plataforma'
}

$platformPresence = @(
    @{ Path = 'README.md'; Snippet = 'Target platform: Windows 11 Pro 26H2, x64 / amd64'; Description = 'README EN: plataforma objetivo 26H2' },
    @{ Path = 'README.es.md'; Snippet = 'Plataforma objetivo: Windows 11 Pro 26H2, x64 / amd64'; Description = 'README ES: plataforma objetivo 26H2' },
    @{ Path = 'docs/configuration-testing-limitations-sources.md'; Snippet = 'Target platform: Windows 11 Pro 26H2, x64 / amd64'; Description = 'Doc EN: plataforma objetivo 26H2' },
    @{ Path = 'docs/configuracion-pruebas-limitaciones-fuentes.md'; Snippet = 'Plataforma objetivo: Windows 11 Pro 26H2, x64 / amd64'; Description = 'Doc ES: plataforma objetivo 26H2' },
    @{ Path = 'docs/pre-installation-preparation.md'; Snippet = '- Windows 11 Pro 26H2 x64 / amd64;'; Description = 'Preparacion EN: plataforma 26H2' },
    @{ Path = 'docs/preparacion-previa-instalacion.md'; Snippet = '- Windows 11 Pro 26H2 x64 / amd64;'; Description = 'Preparacion ES: plataforma 26H2' },
    @{ Path = 'docs/pre-installation-preparation.md'; Snippet = 'The target platform is Windows 11 Pro 26H2 x64 / amd64.'; Description = 'Preparacion EN: medio de instalacion 26H2' },
    @{ Path = 'docs/preparacion-previa-instalacion.md'; Snippet = 'La plataforma objetivo es Windows 11 Pro 26H2 x64 / amd64.'; Description = 'Preparacion ES: medio de instalacion 26H2' }
)
foreach ($check in $platformPresence) {
    $record = Get-FileRecord -RelativePath $check.Path
    if ($record.Exists -and $record.DecodeOk -and $record.Text.Contains($check.Snippet)) {
        Add-Ok $check.Description
    } else {
        Add-Fail ("{0}: fragmento no encontrado" -f $check.Description)
    }
}

$platformObsolete = @(
    @{ Path = 'README.md'; Snippet = 'Target platform: Windows 11 25H2,'; Description = 'README EN: sin objetivo operativo 25H2' },
    @{ Path = 'README.es.md'; Snippet = 'Plataforma objetivo: Windows 11 25H2,'; Description = 'README ES: sin objetivo operativo 25H2' },
    @{ Path = 'docs/configuration-testing-limitations-sources.md'; Snippet = 'Target platform: Windows 11 25H2,'; Description = 'Doc EN: sin objetivo operativo 25H2' },
    @{ Path = 'docs/configuracion-pruebas-limitaciones-fuentes.md'; Snippet = 'Plataforma objetivo: Windows 11 25H2,'; Description = 'Doc ES: sin objetivo operativo 25H2' },
    @{ Path = 'docs/pre-installation-preparation.md'; Snippet = 'The target platform is Windows 11 25H2'; Description = 'Preparacion EN: sin objetivo operativo 25H2' },
    @{ Path = 'docs/preparacion-previa-instalacion.md'; Snippet = 'La plataforma objetivo es Windows 11 25H2'; Description = 'Preparacion ES: sin objetivo operativo 25H2' }
)
foreach ($check in $platformObsolete) {
    $record = Get-FileRecord -RelativePath $check.Path
    if ($record.Exists -and $record.DecodeOk -and $record.Text.Contains($check.Snippet)) {
        Add-Fail ("{0}: fragmento obsoleto presente" -f $check.Description)
    } else {
        Add-Ok $check.Description
    }
}

if ($null -ne $ventoyJson) {
    $imageEntry = @($ventoyJson.auto_install)
    if ($imageEntry.Count -ge 1 -and [string]$imageEntry[0].image -eq '/Windows11_Client_x64_es-es_26300_9457.iso') {
        Add-Ok 'Ventoy: la imagen declarada es la ISO 26H2 confirmada'
    } else {
        Add-Fail 'Ventoy: la imagen declarada no es la ISO 26H2 confirmada'
    }
    if ([string]$imageEntry[0].image -notmatch '25H2') {
        Add-Ok 'Ventoy: sin referencia operativa a la ISO 25H2'
    } else {
        Add-Fail 'Ventoy: la imagen declarada sigue siendo la ISO 25H2'
    }
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

Test-PostInstallStandalone -SourceText $sysText -BloatText $bloatText -Hashes $realHashes

Write-Section 'SUITE DE TESTS AISLADA'
Test-TestsSuite

# ---------------------------------------------------------------------------
# EOL / encoding
# ---------------------------------------------------------------------------

Write-Section 'EOL / ENCODING'

Test-FilePolicy -RelativePath 'autounattend.xml' -ExpectedEol 'LF' -ExpectedBom 'NONE'
Test-FilePolicy -RelativePath 'Apply-TMPCOptimizations.ps1' -ExpectedEol 'LF' -ExpectedBom 'UTF8'
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
Test-FilePolicy -RelativePath 'scripts/tests/TMPC.Tests.Helpers.ps1' -ExpectedEol 'LF' -ExpectedBom 'UTF8'
Test-FilePolicy -RelativePath 'scripts/tests/Invoke-TMPCTests.ps1' -ExpectedEol 'LF' -ExpectedBom 'UTF8'

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
        'scripts/*.ps1 text eol=lf',
        'scripts/tests/*.ps1 text eol=lf',
        'Apply-TMPCOptimizations.ps1 text eol=lf'
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
