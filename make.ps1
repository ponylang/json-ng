Param(
  [Parameter(Position=0, HelpMessage="The action to take (test, clean).")]
  [string]
  $Command = 'test',

  [Parameter(HelpMessage="The build configuration (Release, Debug).")]
  [string]
  $Config = "Release"
)

$ErrorActionPreference = "Stop"

$target = "json"
$rootDir = Split-Path $script:MyInvocation.MyCommand.Path
$srcDir = Join-Path -Path $rootDir -ChildPath $target

if ($Config -ieq "Release")
{
  $configFlag = ""
  $buildDir = Join-Path -Path $rootDir -ChildPath "build/release"
}
elseif ($Config -ieq "Debug")
{
  $configFlag = "--debug"
  $buildDir = Join-Path -Path $rootDir -ChildPath "build/debug"
}
else
{
  throw "Invalid -Config '$Config'; must be one of (Debug, Release)."
}

if (-not (Test-Path $buildDir))
{
  mkdir "$buildDir"
}

function BuildTest
{
  Write-Host "corral fetch"
  $output = (corral fetch)
  $output | ForEach-Object { Write-Host $_ }
  if ($LastExitCode -ne 0) { throw "Error" }

  Write-Host "corral run -- ponyc $configFlag --output `"$buildDir`" `"$srcDir`""
  $output = (corral run -- ponyc $configFlag --output "$buildDir" "$srcDir")
  $output | ForEach-Object { Write-Host $_ }
  if ($LastExitCode -ne 0) { throw "Error" }

  return (Join-Path -Path $buildDir -ChildPath "$target.exe")
}

function BuildExamples
{
  $examplesDir = Join-Path -Path $rootDir -ChildPath "examples"
  $examples = Get-ChildItem -Path $examplesDir -Directory

  foreach ($example in $examples)
  {
    $exampleName = $example.Name
    Write-Host "Building example: $exampleName"

    Write-Host "corral fetch"
    $output = (corral fetch)
    $output | ForEach-Object { Write-Host $_ }
    if ($LastExitCode -ne 0) { throw "Error during corral fetch" }

    Write-Host "corral run -- ponyc $configFlag --output `"$buildDir`" `"$($example.FullName)`""
    $output = (corral run -- ponyc $configFlag --output "$buildDir" "$($example.FullName)")
    $output | ForEach-Object { Write-Host $_ }
    if ($LastExitCode -ne 0) { throw "Error building example $exampleName" }
  }
}

switch ($Command.ToLower())
{
  "test"
  {
    $testFile = BuildTest
    Write-Host "$testFile --exclude=integration --sequential"
    & "$testFile" --exclude=integration --sequential
    if ($LastExitCode -ne 0) { throw "Test failed with exit code $LastExitCode" }

    BuildExamples
    break
  }

  "clean"
  {
    if (Test-Path "$buildDir")
    {
      Remove-Item -Path "$buildDir" -Recurse -Force
    }
    break
  }

  default
  {
    throw "Unknown command '$Command'; must be one of (test, clean)."
  }
}
