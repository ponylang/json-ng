Param(
  [Parameter(Position=0, HelpMessage="The action to take (test, examples, clean).")]
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

function BuildTest
{
  $testTarget = "$target.exe"
  $testFile = Join-Path -Path $buildDir -ChildPath $testTarget
  $testTimestamp = [DateTime]::MinValue
  if (Test-Path $testFile)
  {
    $testTimestamp = (Get-ChildItem -Path $testFile).LastWriteTimeUtc
  }

  :testFiles foreach ($file in (Get-ChildItem -Path $srcDir -Include "*.pony" -Recurse))
  {
    if ($testTimestamp -lt $file.LastWriteTimeUtc)
    {
      Write-Host "corral fetch"
      $output = (corral fetch)
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }

      Write-Host "corral run -- ponyc $configFlag --output `"$buildDir`" `"$srcDir`""
      $output = (corral run -- ponyc $configFlag --output "$buildDir" "$srcDir")
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }
      break testFiles
    }
  }

  Write-Output "$testTarget is built" # force function to return a list of outputs
  return $testFile
}

function BuildExamples
{
  $examplesDir = Join-Path -Path $rootDir -ChildPath "examples"
  $examples = Get-ChildItem -Path $examplesDir -Directory

  foreach ($example in $examples)
  {
    $exampleName = $example.Name
    $exampleTarget = "$exampleName.exe"
    $exampleFile = Join-Path -Path $buildDir -ChildPath $exampleTarget

    Write-Host "Building example: $exampleName"

    $needsRebuild = $false
    if (-not (Test-Path $exampleFile))
    {
      $needsRebuild = $true
    }
    else
    {
      $exampleTimestamp = (Get-ChildItem -Path $exampleFile).LastWriteTimeUtc

      Get-ChildItem -Path $srcDir -Include "*.pony" -Recurse | ForEach-Object {
        if ($exampleTimestamp -lt $_.LastWriteTimeUtc)
        {
          $needsRebuild = $true
        }
      }

      Get-ChildItem -Path $example.FullName -Include "*.pony" -Recurse | ForEach-Object {
        if ($exampleTimestamp -lt $_.LastWriteTimeUtc)
        {
          $needsRebuild = $true
        }
      }
    }

    if ($needsRebuild)
    {
      Write-Host "corral fetch"
      $output = (corral fetch)
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error during corral fetch" }

      Write-Host "corral run -- ponyc $configFlag --output `"$buildDir`" `"$($example.FullName)`""
      $output = (corral run -- ponyc $configFlag --output "$buildDir" "$($example.FullName)")
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error building example $exampleName" }
    }
    else
    {
      Write-Host "$exampleTarget is up to date"
    }
  }
}

switch ($Command.ToLower())
{
  "test"
  {
    $testFile = (BuildTest)[-1]
    Write-Host "$testFile --exclude=integration --sequential"
    & "$testFile" --exclude=integration --sequential
    if ($LastExitCode -ne 0) { throw "Test failed with exit code $LastExitCode" }

    BuildExamples
    break
  }

  "examples"
  {
    if (-not (Test-Path $buildDir))
    {
      mkdir "$buildDir"
    }
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
    throw "Unknown command '$Command'; must be one of (test, examples, clean)."
  }
}
