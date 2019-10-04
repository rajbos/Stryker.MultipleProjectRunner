# Stryker.MultipleProjectRunner
Runs Stryker for multiple .NET Core projects and aggregates the results, based on [this GitHub conversation](https://github.com/stryker-mutator/stryker-net/issues/740). 

TL;DR: Stryker cannot run for an entire solution with multiple test projects (YET), so we need to help it a little and run each project by itself and then join the results.

### Note
This is a first draft and could use some more error handling 😄.


## Requirements
* Install dotnet core
* Install global dotnet core tool for Stryker: `dotnet tool install -g dotnet-stryker`
* `git clone` or `download` this repository somewhere
* Update the datafile with your files. See `DATAFILE` below.

## Running this script
Just call the script. It creates an Output directory from your starting path and will save all output files there

Files needed:
* Run Stryker.ps1
* Stryker.data.json
* StrykerReportEmpty.html

## What will happen?
The data file will be read from disk. Each project in the "projectsToTest" setting will be send to a Stryker run. The last generated json file from that run will be copied with a datetime in the filename to the `jsonReportsPath` path.
After all runs have been completed, the json files in the Output directory will be joined and copied into the empty report html file by matter of string replacement. A JavaScript file from the Stryker CDN will be added to the html report as well.

The html report will be stand-alone after the run.


## DATAFILE
In the datafile the following properties should be set:

|Property|Example|Description|
|---|---|---|
|solutionPath|`D:\Source\SolutionFolder\MySolution.sln`|Full file path to the Visual Studio Solution file that the Projects in `projectsToTest` are a part of|
|jsonReportsPath|`D:\Source\SolutionFolder\Stryker.Output\`|Output folder|
|projectsToTest|see below|Array of projects to run|

### ProjectsToTest array
The projectsToTest property is an array of items with these properties:

|Property|Example|Description|
|---|---|---|
|csProjPath|`D:\Source\SolutionFolder\src\ProjectFolder\project.csproj`|FilePath of the project file to mutate|
|testPath|`D:\Source\SolutionFolder\test\ProjectFolder-Tests\project.csproj`|FilePath of the test folder to run the tests in|