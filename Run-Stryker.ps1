# README .TXT
# parameter commit - commit id from which the changes will be considered for stryker execution. The changes in the given commit is excluded
# StrykerReportEmpty.html should be availabe in the same script root path. This file is used as template for html stryker report generation
# Get-ChangeFileset.ps1 should be available in the same script root path
# Run-StrykerForOneAssembly.ps1 should be available in the same script root path
# FunctionalProjectTestProjectMap.json should contain mapping of functional project to test project. The reference project to functional project can be included in "referenceProjectPath"
# Get-ChangeFileset.ps1 file creates stryker.data.json in the same script root path.
# Run-StrykerForOneAssembly.ps1 will be executed for every functional and test project combination given in stryker.data.json
# Logs for this & Get-ChangeFileset.ps1 script will be created in rootpath\strykeroutput folder and filename would be prefixed with "StrykerLog" 	   followed by timestamp with format "yyyyMMddTHHmmssZ"
# Logs for Run-StrykerForOneAssembly.ps1 will be created in the test project path under the folder "StrykerOutput" and filename would be prefixed with "StrykerLog" followed by timestamp with format "yyyyMMddTHHmmssZ"
# logs for stryker execution will be stored under the folder "StrykerOutput" and under the timestamp folder
# stryker config file "stryker-config.json" is stored in script root path
# StrykerReportEmpty.html should be availabe
# gitignore files will be created in all folder created by the script

[CmdletBinding()]
param ([Parameter()] 
	[string] $commit=""
)


function JoinStykerJsonFile ($additionalFile, $joinedFileName) {
    Join-FilesSection $additionalFile $joinedFileName
	Join-TestFilesSection $additionalFile $joinedFileName
}

function Join-FilesSection($additionalFile, $joinedFile) {
	
	$joinedFileContent = (Get-Content $joinedFile | Out-String) 
	$additionalFileContent = (Get-Content $additionalFile | Out-String)
	
	$offset = 2  # for removing trailing comma from content 
	$startStringToSearchFor = '"files":{'
	$startStringToSearchForLength = $startStringToSearchFor.Length

	$endStringToSearchFor = '"testFiles":{'
	$endStringToSearchForLength = $endStringToSearchFor.Length
	
	$indexofstartStringToSearchForInAdditionalFile = $additionalFileContent.IndexOf($startStringToSearchFor) 
	$indexofendStringToSearchForInAdditionalFile = $additionalFileContent.IndexOf($endStringToSearchFor)
	
	$ContentFromAdditionalFile = $additionalFileContent.Substring($indexofstartStringToSearchForInAdditionalFile+$startStringToSearchForLength, $indexofendStringToSearchForInAdditionalFile - $indexofstartStringToSearchForInAdditionalFile - $startStringToSearchForLength - $offset)
	
	$stringToReplaceInJoinedFile = $startStringToSearchFor + $ContentFromAdditionalFile + ","
	$updatedContent = $joinedFileContent.Replace($startStringToSearchFor, $stringToReplaceInJoinedFile)
	
	Set-Content -Path $joinedFile -Value $updatedContent
}

function Join-TestFilesSection($additionalFile, $joinedFile) {
	$joinedFileContent = (Get-Content $joinedFile | Out-String) 
	$additionalFileContent = (Get-Content $additionalFile | Out-String)
	
	$offset = 2 # for removing trailing '}' from content
	$startStringToSearchFor = '"testFiles":{'
	$startStringToSearchForLength = $startStringToSearchFor.Length
	
	$endStringToSearchFor = "}}"
	$endStringToSearchForLength = $endStringToSearchFor.Length
	
	$indexofstartStringToSearchForInAdditionalFile = $additionalFileContent.IndexOf($startStringToSearchFor) 
	$indexofendStringToSearchForInAdditionalFile = $additionalFileContent.LastIndexOf($endStringToSearchFor)
	
	$ContentFromAdditionalFile = $additionalFileContent.Substring($indexofstartStringToSearchForInAdditionalFile+$startStringToSearchForLength, $additionalFileContent.Length-($indexofstartStringToSearchForInAdditionalFile+$startStringToSearchForLength+$endStringToSearchForLength+ $offset))
	
	$stringToReplaceInJoinedFile = $startStringToSearchFor + $ContentFromAdditionalFile + ","
	
	$updatedContent = $joinedFileContent.Replace($startStringToSearchFor, $stringToReplaceInJoinedFile)
	Set-Content -Path $joinedFile -Value $updatedContent 
}


function JoinJsonWithHtmlFile ($joinedJsonFileName, $reportFileName, $emptyReportFileName, $reportTitle) {
    $report = (Get-Content $emptyReportFileName | Out-String)
    $Json = (Get-Content $joinedJsonFileName | Out-String)

    $report = $report.Replace("##REPORT_JSON##", $Json)
    $report = $report.Replace("##REPORT_TITLE##", $reportTitle)
    # hardcoded link to the package from the npm CDN
    $report = $report.Replace("<script>##REPORT_JS##</script>", '<script defer src="https://www.unpkg.com/mutation-testing-elements"></script>')
        
    Set-Content -Path $reportFileName -Value $report
}

function JoinAllJsonFiles ($joinedFileName) {
    $files = Get-ChildItem  -Filter "*.json" -Exclude $joinedFileName -Recurse -ErrorAction SilentlyContinue -Force
    Write-Log "Found $($files.Count) json files to join"
    $firstFile = $true
    foreach ($file in $files) {
        if ($true -eq $firstFile) {
            # copy the first file as is
            Copy-Item $file.FullName "$joinedFileName"
            $firstFile = $false
            continue
        }

        JoinStykerJsonFile $file.FullName $joinedFileName
    }
    Write-Log "Joined $($files.Count) files to the new json file: $joinedFileName"
}

function LoadConfigurationFile ($startDir, $configurationFile) {  
    # try to load given file
    $strykerDataFilePath = $configurationFile    
    Write-Log "Searching for configuration file in this location: $strykerDataFilePath"
    if (!(Test-Path $strykerDataFilePath -PathType Leaf)) {
        # test for testdata first
        $strykerDataFilePath = "$startDir\Stryker.TestData.json"
        Write-Log "Searching for configuration file in this location: $strykerDataFilePath"
        if (!(Test-Path $strykerDataFilePath -PathType Leaf)) {
            # if no testdata, use the data file
            $strykerDataFilePath = "$startDir\Stryker.data.json"            
            Write-Log "Using configuration file in this location: $strykerDataFilePath"
        }
    }

    Write-Log "Using configuration file at '$strykerDataFilePath'"
    # load the data file
    $strykerData = (Get-Content $strykerDataFilePath | Out-String | ConvertFrom-Json)
        
    # create a new directory for the output if needed
    $outputPath = "$($strykerData.jsonReportsPath)"
    New-Item $outputPath -ItemType "directory" -Force

    return $strykerData
}

function DeleteDataFromPreviousRuns ($strykerData) {
    if (!$strykerData) {
        Write-Log "Cannot delete from unknown directory"
        return
    }
    # clear the output path
    Write-Log "Deleting previous json files from $($strykerData.jsonReportsPath)"
    Get-ChildItem -Path "$($strykerData.jsonReportsPath)" -Include *.json -File -Recurse | ForEach-Object { $_.Delete()}
}

function MutateAllAssemblies($strykerData){
    $counter = 1
	$StrykerExecuteFileName = "Run-StrykerForOneAssembly.ps1"
	$strykerFileFullPath = Join-Path -path $PSScriptRoot -childPath $StrykerExecuteFileName
	$jobList = @()
	$currentList = Get-Job
	foreach($currJob in $currentList) {
		Remove-Job -Name $currjob.Name -Force
	}
    foreach ($project in $strykerData.projectsToTest) {
        $item = Get-Item -Path $project.csProjPath
		Write-Log "Running mutation for project $($counter) of $($strykerData.projectsToTest.Length)"
        #Run-StrykerForOneAssembly $project.csprojPath $project.testPath $strykerData.solutionPath $strykerData.jsonReportsPath
		$jobinfo = Start-Job -FilePath $strykerFileFullPath -ArgumentList $project.csprojPath,$project.testPath,$strykerData.solutionPath,$strykerData.jsonReportsPath,$strykerConfigFile,$CommitId -Name $item.Name
		$jobList += $jobinfo
        $counter++
    }
	if($jobList.Count -eq 0) {
		Write-Log "No project information available. Check the commit Id provided"
		return
	}
	$isjobRunning = $true
	$atleastOneJobRunning = $false
	while ($isjobRunning -eq $true) {
		$currentList = Get-Job
		Write-Log ("-----------Checking the job status----------------")
		$isjobRunning = $true
		$atleastOneJobRunning = $false
		foreach($currJob in $currentList) {
			Write-Log ("The stryker execution for " + $currjob.Name + " is " + $currJob.State)
			if($currJob.State -eq "Running" -or $currJob.State -eq "NotStarted") {
				$isjobRunning = $true
				$atleastOneJobRunning = $true
			}
			elseif ($atleastOneJobRunning -eq $false) {
				$isjobRunning = $false
			}

		}
		Write-Log ("-----------Next job status check after 5 seconds--")
		Start-Sleep -Second 5
	}
	$currentList = Get-Job
	foreach($currJob in $currentList) {
		Remove-Job -Name $currjob.Name
	}
}

function CreateReportFromAllJsonFiles ($reportDir, $startDir) {
    # Join all the json files
    Set-Location "$reportDir"
    $joinedJsonFileName = "mutation-report.json"

    JoinAllJsonFiles $joinedJsonFileName

    # join the json with the html template for the final output
    $reportFileName = "StrykerReport.html"
    $emptyReportFileName = "$startDir\StrykerReportEmpty.html"
    $reportTitle = "Stryker Mutation Testing"
    if ((Test-Path $joinedJsonFileName -PathType Leaf)) {
		JoinJsonWithHtmlFile $joinedJsonFileName $reportFileName $emptyReportFileName $reportTitle
		Write-Log "Created new report file: $reportDir\$reportFileName"
	}
	else {
		Write-Log "No report available. Check logs for more details"
	}
}

function RunEverything ($startDir, $configurationFile) {
    try {
        $strykerData = LoadConfigurationFile $startDir $configurationFile

        # check for errors
        if( -not $?) {
            exit;
        }

        Create-GitIgnoreFile $strykerData.jsonReportsPath
		# clean up previous runs
        DeleteDataFromPreviousRuns $strykerData

        # mutate all projects in the data file
        MutateAllAssemblies $strykerData

        # check for errors
        if( -not $?) {
            exit;
        }

        CreateReportFromAllJsonFiles $strykerData.jsonReportsPath $startDir
    }
    finally {
        # change back to the starting directory
        Set-Location $startDir
    }
}


function RunStryker ($startDir, $configurationFile) {
    try {
        $strykerData = LoadConfigurationFile $startDir $configurationFile

        # check for errors
        if( -not $?) {
            exit;
        }

        # clean up previous runs
        DeleteDataFromPreviousRuns $strykerData

        # mutate all projects in the data file
        MutateAllAssemblies $strykerData

        # check for errors
        if( -not $?) {
            exit;
        }
    }
    finally {
        # change back to the starting directory
        Set-Location $startDir
    }
}

function Create-GitIgnoreFile($path) {
	
	$fullPath = Join-Path -Path $logFolderPath -childPath ".gitignore"
	if (!(Test-Path $fullPath -PathType Leaf)) {
		New-Item -ItemType File -Path $fullPath
	}
	Set-Content -Path $fullPath -Value "*"
}

function Write-Log($text) {
	Write-Host $text
	$text | Out-File -FilePath $logFilePath -Append
}

try {
	
	$stopwatch = New-Object System.Diagnostics.Stopwatch
	$stopwatch.Start()
	$fileName = "StrykerLog" + $(get-date -f yyyyMMddTHHmmssZ) +".log"
	$logFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "StrykerOutput"
	if((Test-Path $logFolderPath) -eq $false) {
		New-Item -ItemType Directory -Path $logFolderPath -Force
	}
	Create-GitIgnoreFile $logFolderPath
	$logFilePath = Join-Path -Path $logFolderPath -childPath $fileName
	$strykerConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "stryker-config.json"
	$CommitId = $commit
	Write-Log "Starting execution"
	if ([string]::IsNullOrEmpty($CommitId) -eq $true) {
		Write-Log "Commit Id not available. Stryker will be executed for all projects"
        $CommitId = ""
	}

	$changeSetFilepath = Join-Path -Path $PSScriptRoot -childPath "Get-ChangeFileset.ps1"
	Invoke-Expression "$changeSetFilepath $logFilePath $CommitId"
	$startDir = Get-Location
	Write-Log "Starting at: " $startDir
	RunEverything $startDir $startDir -ErrorAction stop
}
catch {

	Write-Log $Error[0]
}
finally {
	$stopwatch.Stop()
	$elapsedTime = $stopwatch.Elapsed
	Write-Log "Execution took $elapsedTime seconds"
}