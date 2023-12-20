#README.TXT
# Run-StrykerForOneAssembly.ps1 should be available in the same path as Run-Stryker.ps1
# Refer to Run-Stryker.ps1 README for the script usage and how it works

[CmdletBinding()]
param ([Parameter()]
	[string] $csprojPath,
	[string] $testPath,
	[string] $solutionPath, 
	[string] $outputPath,
	[string] $strykerConfigFile,
	[string] $commitId=""
)

$fileName = "StrykerLog" + $(get-date -f yyyyMMddTHHmmssZ) +".log"
$logFolderPath = Join-Path -Path $testPath -ChildPath "StrykerOutput"
if((Test-Path $logFolderPath) -eq $false) {
	New-Item -ItemType Directory -Path $logFolderPath -Force
}
$fullPath = Join-Path -Path $logFolderPath -childPath ".gitignore"
if (!(Test-Path $fullPath -PathType Leaf)) {
	New-Item -ItemType File -Path $fullPath
}
Set-Content -Path $fullPath -Value "*"
$logFilePath = Join-Path -Path $logFolderPath $fileName

function Run-StrykerForOneAssembly ($csprojPath, $testPath, $solutionPath, $outputPath) {
    Write-Log "csprojPath: $csprojPath"
    Write-Log ("Moving to test directory: $testPath")

    Set-Location $testPath

    Write-Log "Calling Stryker"
	if ([string]::IsNullOrEmpty($commitId)) {
		dotnet stryker --project "$csprojPath" --reporter "json" --reporter "progress" --log-to-file --config-file "$strykerConfigFile"
	}
	else {
		dotnet stryker --project "$csprojPath" --reporter "json" --reporter "progress" --log-to-file --since:"$commitId" --config-file "$strykerConfigFile"
	}

    if( -not $? ){
        Write-Log "Error in running Stryker, exiting the script"
        # write error output to Azure DevOps
        Write-Log "##vso[task.complete result=Failed;]Error"
        exit;
    }

    $searchPath = Split-Path -Path $testPath
    Write-Log "Searching for json files in this path: $searchPath"
    # find all json result files and use the most recent one
    $files = Get-ChildItem -Path "$searchPath"  -Filter "*.json" -Recurse -ErrorAction SilentlyContinue -Force
    $file = $files | Sort-Object {$_.LastWriteTime} | Select-Object -last 1
    
    # get the name and the timestamp of the file
    $orgReportFilePath=$file.FullName
    $splitted = $splitted = $orgReportFilePath.split("\")
    $dateTimeStamp = $splitted[$splitted.Length - 3]
    $fileName =  $splitted[$splitted.Length - 1]
	$item = Get-Item -Path $csprojPath
    Write-Log "Last file filename: $orgReportFilePath has timestamp: $dateTimeStamp"

    # create a new filename to use in the output
    $newFileName = "$outputPath" + $dateTimeStamp + $item.Name + "_"+ $fileName
    Write-Log "Copy the report file to '$newFileName'"
    # write the new file out to the report directory
    Copy-Item "$orgReportFilePath" "$newFileName"
}

function Write-Log($text) {
	Write-Host $text
	$text | Out-File -FilePath $logFilePath -Append
}

try {
	Run-StrykerForOneAssembly $csprojPath $testPath $solutionPath $outputPath -ErrorAction Stop
}
catch {
	Write-Log $Error[0]
}
