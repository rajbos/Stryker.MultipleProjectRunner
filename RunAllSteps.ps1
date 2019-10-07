# import the script with all the code
. '.\Run Stryker.ps1'

# save where we started
$startDir = Get-Location
Write-Host "Starting at: " $startDir

RunEverything $startDir $startDir