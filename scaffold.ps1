param([Parameter(Position = 0, Mandatory = 1)][string]$projectName,
      [Parameter(Position = 1, Mandatory = 1)][string]$solutionName) 

$projectPath = Join-Path "." -ChildPath $projectName
New-Item $projectPath -Type directory

$gitignore = Join-Path $projectPath -ChildPath ".gitignore"
Invoke-WebRequest "https://raw.githubusercontent.com/github/gitignore/master/VisualStudio.gitignore" -OutFile $gitignore
Add-Content $gitignore "`n# CUSTOM"
Add-Content $gitignore "[Tt]ools"

$srcPath = Join-Path $projectPath -ChildPath "src"
New-Item $srcPath -Type directory
$solutionPath = Join-Path $srcPath -ChildPath "$solutionName.sln"
New-Item $solutionPath -Type file -Value "`nMicrosoft Visual Studio Solution File, Format Version 12.00`n
# Visual Studio 14`n
VisualStudioVersion = 14.0.23107.0`n
MinimumVisualStudioVersion = 10.0.40219.1`n
Global`n
    GlobalSection(SolutionProperties) = preSolution`n
        HideSolutionNode = FALSE`n
    EndGlobalSection`n
EndGlobal`n"

$setupScript = Join-Path $projectPath -ChildPath "setup.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/melkio/scripts/master/setup.ps1" -OutFile $setupScript

&$setupScript -baseDirectory $projectPath