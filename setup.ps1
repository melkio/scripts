param([Parameter(Position = 0, Mandatory = 0)][string]$baseDirectory = ".")

$toolsPath = Join-Path $baseDirectory -ChildPath "tools"
$toolsExists = Test-Path $toolsPath
If ($toolsExists -eq $true) {
    Remove-Item $toolsPath -Force -Recurse
}

New-Item $toolsPath -Type directory

$nugetPath = Join-Path $toolsPath -ChildPath "nuget"
New-Item $nugetPath -Type directory
$nuget = Join-Path $nugetPath -ChildPath "nuget.exe"
Invoke-WebRequest "https://www.nuget.org/nuget.exe" -OutFile $nuget
#&$nuget update -self

&$nuget install psake -OutputDirectory $toolsPath -ExcludeVersion
&$nuget install nunit.console -OutputDirectory $toolsPath -ExcludeVersion