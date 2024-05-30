function Publish-App {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ContainerName,
        [Parameter(Mandatory = $true)]
        [string]$AppFile,
        [Parameter(Mandatory = $true)]
        [string]$CompletionPath,
        [Parameter(Mandatory = $false)]
        $LaunchConfig
    )
    Write-Host "$(Get-Date -Format "G" ) - Publishing app $AppFile to container $ContainerName..."
    if ([String]::IsNullOrEmpty($ContainerName)) {
        $ContainerName = Get-ContainerName -LaunchConfig $LaunchConfig
    }

    if (Test-Path $CompletionPath) {
        Remove-Item $CompletionPath -Force
    }

    $Credential = Get-ALTestRunnerCredential -LaunchConfig $LaunchConfig
    Import-ContainerHelper
    
    try {
        if ($AppFile.EndsWith('.dep.app')) {
            $TempFolderPath = Join-Path "$([System.IO.Path]::GetTempPath())" "dep_app_$(([Guid]::NewGuid()).ToString())"
            if (-not (Test-Path $TempFolderPath)) {
                New-Item -ItemType Directory -Path $TempFolderPath | Out-Null
            }
            Extract-AppFileToFolder -appFilename $AppFile -appFolder $TempFolderPath

            $projectDependencySet = ConvertFrom-Json (Get-Content "$TempFolderPath\projectDependencySet.json" -Raw)
            foreach ($AppInfo in $projectDependencySet.StartupProject.ProjectsThatThisProjectDirectlyDependsOn) {
                $DependencyFilenamePath = "$TempFolderPath\$($AppInfo.Name).app"
                if (Test-Path $DependencyFilenamePath) {
                    Publish-BcContainerApp $ContainerName -appFile $DependencyFilenamePath -skipVerification -useDevEndpoint -credential $Credential
                    Write-Host "$(Get-Date -Format "G" ) - Published $($AppInfo.Name) successfully."
                }
            } 
            $StartupAppFilenamePath = "$TempFolderPath\$($projectDependencySet.StartupProject.ThisProject.Name).app"
            Publish-BcContainerApp $ContainerName -appFile $StartupAppFilenamePath -skipVerification -useDevEndpoint -credential $Credential

            Remove-Item -Path $TempFolderPath -Recurse -Force -ErrorAction Continue
        }
        else {   
            Publish-BcContainerApp $ContainerName -appFile $AppFile -skipVerification -useDevEndpoint -credential $Credential
        }
        Write-Host "$(Get-Date -Format "G" ) - Publishing completed successfully."
        Set-Content $CompletionPath '1'
    }
    catch {
        Set-Content $CompletionPath $_
    }
}

Export-ModuleMember -Function Publish-App