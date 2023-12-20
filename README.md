# Stryker.MultipleProjectRunner
Runs Stryker for multiple .NET Core projects and aggregates the results, based on [this GitHub conversation](https://github.com/stryker-mutator/stryker-net/issues/740). The script gets a commit id and gather all the changes done since that commit and creates a project & unit test mapping file which is used to execute stryker in parallel fashion
The script needs a json file (FunctionalProjectTestProjectMap.json) containing the mapping to functional project and its respective test project. The other project references used by the main functional project can be included in the referenceProjectPath.

TL;DR: Stryker is capable of running only for changes using --Since commit flag but consumes lot of time in getting the list of mutants to be executed. Hence we create the functional project & test project only for the changes in the commit and execute stryker in parallel.

### Note
Have added logs for every script but still error handling can be improved.


## Requirements
* Install dotnet core
* Install global dotnet core tool for Stryker: `dotnet tool install -g dotnet-stryker`
* `git clone` or `download` this repository somewhere
* Update the datafile with your files. See `DATAFILE` below.

## Running this script
Just call the script with commitId from which you want stryker to execute. If no commitid is provided, then stryker gets executed for all available project in FunctionalProjectTestProjectMap.json. It creates an Output directory from your starting path and will save all output files there

Files needed:
* Run-Stryker.ps1
* Get-ChangeFileset.ps1
* Run-StrykerForOneAssembly.ps1
* stryker-config.json
* FunctionalProjectTestProjectMap.json
* StrykerReportEmpty.html

## What will happen?
 * parameter commit - commit id from which the changes will be considered for stryker execution. The changes in the given commit is excluded
 * StrykerReportEmpty.html should be availabe in the same script root path. This file is used as template for html stryker report generation
 * Get-ChangeFileset.ps1 should be available in the same script root path
 * Run-StrykerForOneAssembly.ps1 should be available in the same script root path
 * FunctionalProjectTestProjectMap.json should contain mapping of functional project to test project. The reference project to functional project can be included in "referenceProjectPath"
 * Get-ChangeFileset.ps1 file creates stryker.data.json in the same script root path.
 * Run-StrykerForOneAssembly.ps1 will be executed for every functional and test project combination given in stryker.data.json
 * Logs for Run-Stryker.ps1 & Get-ChangeFileset.ps1 script will be created in rootpath\strykeroutput folder and filename would be prefixed with "StrykerLog" 	   followed by timestamp with format "yyyyMMddTHHmmssZ"
 * Logs for Run-StrykerForOneAssembly.ps1 will be created in the test project path under the folder "StrykerOutput" and filename would be prefixed with "StrykerLog" followed by timestamp with format "yyyyMMddTHHmmssZ"
 * Logs for stryker execution will be stored under the folder "StrykerOutput" and under the timestamp folder
 * stryker config file "stryker-config.json" is stored in script root path
 * StrykerReportEmpty.html should be availabe
 * gitignore files will be created in all folder created by the script

## DATAFILE (FunctionalProjectTestProjectMap.json)
In the datafile the following properties should be set:

|Property|Example|Description|
|---|---|---|
|projectmapper|see below|Array of projects to run|

### projectmapper array
The projectmapper property is an array of items with these properties:

|Property|Example|Description|
|---|---|---|
|csProjPath|`D:\Source\SolutionFolder\src\ProjectFolder\project.csproj`|FilePath of the project file to mutate|
|testPath|`D:\Source\SolutionFolder\test\ProjectFolder-Tests\`|FilePath of the test folder to run the tests in|
|referenceProjectPath|`[D:\Source\SolutionFolder\src\ProjectFolder1\project1.csproj, D:\Source\SolutionFolder\src\ProjectFolder2\project2.csproj]`| array of project path which also share the same unit test project
