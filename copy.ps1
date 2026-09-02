$Source = $PSScriptRoot
$Destination = "E:\SteamLibrary\steamapps\common\The Binding of Isaac Rebirth\mods\my_stuff_descriptions_for_repentogon"
$ExcludeNames = @(
    ".vscode",
    ".git",
    ".gitignore",
    ".luarc.json",
    "README.md"
)
$ScriptName = Split-Path -Leaf $PSCommandPath

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

Get-ChildItem -LiteralPath $Source -Force |
Where-Object {
    $_.Name -notin $ExcludeNames -and
    $_.Name -ne $ScriptName
} |
ForEach-Object {
    Copy-Item `
        -LiteralPath $_.FullName `
        -Destination $Destination `
        -Recurse `
        -Force
}

Write-Host "Copied mod files to: $Destination"
