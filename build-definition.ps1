Include "build-helpers.ps1"

Properties {
    
    # This number will be appended to all nuget package versions and to the service fabric app versions
    # This should be overwritten by a CI system like VSTS, AppVeyor, TeamCity, ...
    $BuildNumber = "local-" + ((Get-Date).ToUniversalTime().ToString("MMddHHmm"))

    # The build configuration used for compilation
    $BuildConfiguration = "Release"
    
    # The folder in which all output packages should be placed
    $ArtifactsPath = "artifacts"

    # Artifacts-subfolder in which test results will be placed
    $ArtifactsPathTests = "tests"

}

FormatTaskName ("`n" + ("-"*25) + "[{0}]" + ("-"*25) + "`n")

Task Default -depends init, clean, dotnet-install, dotnet-restore, dotnet-build

Task init {

    Write-Host "BuildNumber: $BuildNumber"
    Write-Host "BuildConfiguration: $BuildConfiguration"
    Write-Host "ArtifactsPath: $ArtifactsPath"
    Write-Host "ArtifactsPathTests: $ArtifactsPathTests"

    Assert ($BuildNumber -ne $null) "Property 'BuildNumber' may not be null."
    Assert ($BuildConfiguration -ne $null) "Property 'BuildConfiguration' may not be null."
    Assert ($ArtifactsPath -ne $null) "Property 'ArtifactsPath' may not be null."
    Assert ($ArtifactsPathTests -ne $null) "Property 'ArtifactsPathTests' may not be null."

}

Task clean {
    
    if (Test-Path $ArtifactsPath) { Remove-Item -Path $ArtifactsPath -Recurse -Force -ErrorAction Ignore }
    New-Item $ArtifactsPath -ItemType Directory -ErrorAction Ignore | Out-Null

    Write-Host "Created artifacts folder '$ArtifactsPath'"
}

Task dotnet-install {
    
    if (Get-Command "dotnet.exe" -ErrorAction SilentlyContinue) {
        Write-Host "dotnet SDK already installed"
        exec { dotnet --version }
    } else {
        Write-Host "Installing dotnet SDK"
        
        $installScript = Join-Path $ArtifactsPath "dotnet-install.ps1"
        
        Invoke-WebRequest "https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/dotnet-install.ps1" `
            -OutFile $installScript
            
        & $installScript
    }
}

Task dotnet-restore {

    exec { dotnet restore -v Minimal }
}

Task dotnet-build {

    exec { dotnet build **\project.json -c $BuildConfiguration --version-suffix $BuildNumber }
}

Task dotnet-test {

    $testOutput = Join-Path $ArtifactsPath $ArtifactsPathTests

    Get-ChildItem -Filter project.json -Recurse | ForEach-Object {

        $projectJson = Get-Content -Path $_.FullName -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

        if ($projectJson -and $projectJson.testRunner -ne $null)
        {
            $library = Split-Path $_.DirectoryName -Leaf
            $testResultOutput = Join-Path $testOutput "$library.xml"

            Write-Host ""
            Write-Host "Testing $library"
            Write-Host ""
            
            exec { dotnet test $_.Directory -c $BuildConfiguration --no-build -xml $testResultOutput }
        }
    }
}



