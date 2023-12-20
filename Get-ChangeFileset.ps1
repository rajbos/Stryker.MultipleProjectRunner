#README.TXT
# Get-ChangeFileset.ps1 should be available in the same path as Run-Stryker.ps1
# Refer to Run-Stryker.ps1 README for the script usage and how it works
[CmdletBinding()]
param ([Parameter()]
	[string] $logFileName,
    [string] $sinceCommit=""
)

if ([string]::IsNullOrEmpty($logFileName)) {
	$fileName = "StrykerLog" + $(get-date -f yyyyMMddTHHmmssZ) +".log"
	$logFilePath = Join-Path -Path $PSScriptRoot -childPath $fileName
}
$basePath = $PSScriptRoot
$projectMapData = $null
$mappingFileName = "FunctionalProjectTestProjectMap.json"
$strykerDatajsonFile = "stryker.data.json"
$strykerOutputPath = "StrykerOutput\"
$strykerDatajson = @{

    solutionPath = ""
    jsonReportsPath = ""
    projectsToTest = @()
}

$allowedFileType = @(".cs")

function Get-ProjectMapStructureObject($csproj, $testPath) {
	return @{
		csProjPath = $($csproj)
	    testPath = $($testPath)
	}
}


function Get-AllChanges($commitId) {
	$path = Get-Item $PSScriptRoot
	$parentPath = $path.Parent
	$cmd = "git log --oneline " + $commitId + "^..HEAD"
	$cmdOutput = Invoke-Expression $cmd
	$commitList = @()
	$fileList = @()
	foreach($s in $cmdOutput)
	{
		$currentCommitId = $s.split(' ')[0]
		if($commitId.IndexOf($currentCommitId) -gt -1) {
			continue
		}
		$commitList += $currentCommitId
	}
	foreach($s in $commitList){
        Write-Log "Getting details for commit $s"
		$commitcmd = "git show --oneline " + $s +" --name-status"
		$diffcmd = "git diff --name-status"
		$commitcmdOutput = Invoke-Expression $commitcmd
		foreach($line in $commitcmdOutput) {
			if ($line.IndexOf($s) -ne -1) {
				continue;
			}
			else {
				$fileInfo=@{
						UpdateType = $line.split('')[0]
						FilePath = $(Join-Path -Path $parentPath.FullName -childPath $line.split('')[1])
				}
			}
			$fileList += New-Object PSObject -Property $fileInfo
		}
		$diffcmdOutput = Invoke-Expression $diffcmd
		foreach($line in $diffcmdOutput) {
			if ($line.IndexOf($s) -ne -1) {
				continue;
			}
			else {
				$fileInfo=@{
						UpdateType = $line.split('')[0]
						FilePath = $(Join-Path -Path $parentPath.FullName -childPath $line.split('')[1])
				}
			}
			$fileList += New-Object PSObject -Property $fileInfo
		}
	}
    Write-Log ("Total files found is " + $fileList.Count)
    return $fileList
}

function Get-StrykerDatajson($fileList, $projectMapData) {
	foreach($file in $fileList) {
        if(-not (Test-Path -Path $file.FilePath)) {
            continue
        }
		if($file.UpdateType -eq 'A' -or $file.UpdateType -eq 'M') {
            $fInfo = Get-Item $file.FilePath
		    $extn = [IO.Path]::GetExtension($fInfo)
		    if ($allowedFileType -contains $extn) {
			    $projPath = Get-ProjectFromFilePath $fInfo.Directory.FullName
			    if ([string]::IsNullOrEmpty($projPath)) {
				    Write-Log "Project file not available for $($file.FilePath)"
			    }
			    $projTestPath = Get-TestProjectForFunctionalProject $projPath
                $projFunctionalPath = Get-FunctionalProjectForReferenceProject $projPath
			    if (-not [string]::IsNullOrEmpty($projTestPath)) {
			        $projmapinfo = Get-ProjectMapStructureObject $projFunctionalPath $projTestPath
                    $result = Check-ProjectAlreadyAdded $projmapinfo
                    if(-not $result) {
			            $strykerDatajson.projectsToTest += New-Object PSObject -Property $projmapinfo
                    }
                }
                continue
		    }
		    else {
			    Write-Log "$($file.FilePath) is not configured for stryker execution"
			    continue
		    }
        }
	}
}

function Check-ProjectAlreadyAdded($projmapinfo) {
    
    if($strykerDatajson.projectsToTest.Count -eq 0) {
        return $false
    }
    foreach($info in $strykerDatajson.projectsToTest) {
        if($projmapinfo.csProjPath -eq $info.csProjPath){
            return $true
        }
    }
    return $false
}

function Get-FunctionalProjectForReferenceProject($projPath) {
    Get-ProjectPath $projPath $false
}

function Get-TestProjectForFunctionalProject($projPath) {
    Get-ProjectPath $projPath $true
}

function Get-AllProjectStrykerJsonData() {
	
	$path = Get-Item $PSScriptRoot
	$parentPath = $path.Parent.FullName
    foreach ($project in $projectMapData.projectmapper){
		$projFullPath = Join-Path -Path $parentPath -childPath $project.csProjPath
		$testProjFullPath = Join-Path -Path $parentPath -childPath $project.testPath
		$projmapinfo = Get-ProjectMapStructureObject $projFullPath $testProjFullPath
		$result = Check-ProjectAlreadyAdded $projmapinfo
		if(-not $result) {
			$strykerDatajson.projectsToTest += New-Object PSObject -Property $projmapinfo
		}
	}
}

function Get-ProjectPath($projPath, $isTestProject) {
	$isTestProjAvailable = $false
	$path = Get-Item $PSScriptRoot
	$parentPath = $path.Parent.FullName
	foreach ($project in $projectMapData.projectmapper){
		$projFullPath = Join-Path -Path $parentPath -childPath $project.csProjPath
		$testProjFullPath = Join-Path -Path $parentPath -childPath $project.testPath
		if($projFullPath -eq $projPath) {
			if($isTestProject -eq $true) {
                return $testProjFullPath
            }
            else {
                return $projFullPath
            }
		}
        foreach($refProj in $project.referenceProjectPath){
			$projFullPath = Join-Path -Path $parentPath -childPath $project.csProjPath
			$testProjFullPath = Join-Path -Path $parentPath -childPath $project.testPath
			$refProjFullPath = Join-Path -Path $parentPath -childPath $refProj
            if($refProjFullPath -eq $projPath) {
			    if($isTestProject -eq $true) {
                    return $testProjFullPath
                }
                else {
                    return $projFullPath
                }
		    }
        }
	}
	if (!$isTestProjAvailable){
		Write-Log "No test project mapped for $projPath. Hence stryker will not be executed for this project"
	}
	return
}

function Load-TestProjectForFunctionalProject() {
	$mappingFile = Join-Path -path $basePath -childPath $mappingFileName
	if (Test-Path $mappingFile) {
		$projectMapData = (Get-Content $mappingFile | Out-String | ConvertFrom-Json)
	}
	else {
		Write-Log "$mappingFileName not available in root path $basePath"
		throw
	}
    return $projectMapData
}

function Get-ProjectFromFilePath($path) {
	$proj = Get-ChildItem -Path $path  -Filter "*.csproj"
	if ($proj.Count -gt 1){
		return
	}
	elseif($proj.Count -eq 1) {
		return $proj.FullName
	}
	elseif($proj.Count -eq 0){
		$curr = Get-Item $path
		if($curr.Parent -eq $basePath) {
			return
		}
		else {
			Get-ProjectFromFilePath $curr.Parent
		}
	}
	return
}

function Save-MetadataToStrykerDatajson(){
	$strykerDatajson.solutionPath = Get-solutionPath
	$strykerDatajson.jsonReportsPath = Join-path -path $basePath -childPath $strykerOutputPath
	$strykerjsonFilePath = Join-Path -Path $basePath -childPath $strykerDatajsonFile
	if ((Test-Path $strykerDatajsonFile -PathType Leaf)) {
		Remove-Item -Path $strykerjsonFilePath -Force
	}
    $strykerDatajson | ConvertTo-Json | Set-Content -Path $strykerjsonFilePath
}

function Get-solutionPath() {
	$sol = Get-ChildItem -Path $basePath  -Filter "*.sln"
	if ($sol.Count -gt 1){
		Write-Log "More than one solution file available in root path $basePath"
		throw
	}
	elseif($sol.Count -eq 1) {
		return ($sol.FullName )
	}
	else {
		Write-Log "No solution is available in root path $basePath"
		throw
	}
}

function Write-Log($text) {
	Write-Host $text
	$text | Out-File -FilePath $logFilePath -Append
}


$projectMapData = Load-TestProjectForFunctionalProject
if ([string]::IsNullOrEmpty($sinceCommit)) {
	Get-AllProjectStrykerJsonData
}
else {
	$fileList = Get-AllChanges $sinceCommit
	Get-StrykerDatajson $fileList $projectMapData
}
Save-MetadataToStrykerDatajson