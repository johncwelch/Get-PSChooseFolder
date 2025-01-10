#!/usr/bin/env pwsh

function Get-ChooseFolder {
	<#
	.SYNOPSIS
	This script is a bridge between PowerShell and the AppleScript Choose Folder UI primitive. It allows the use of the standard macOS Choose File dialog inside a PowerShell script and returns a string array of POSIX-Compliant file paths.

	Yes the syntax is very similar to Get-ChooseFile. If you look at the AppleScript commands I'm using for this module and Get-ChooseFile, you'll see the same similarity.
	.DESCRIPTION
	This module takes advantage of piping commands to /usr/bin/osascript to allow powershell to use AppleScript's Choose File function,
	(https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/PromptforaFileorFolder.html for more details)

	As with some of the other modules in this series, this attempts to plug a hole in PowerShell on macOS by allowing access to things that are useful in a GUI, like user input, or choosing a folder/folders.

	This module takes advantage of osascript's ability to run AppleScript from the Unix shell environment. There are a number of parameters you can use with this, (in -Detailed) to customize the dialog. There is no required parameter, so just running Get-ChooseFolder will give you a basic Choose File dialog.

	Use Get-Help Get-ChooseFolder - Detailed for Parameter List

	"Normally", there's one error that is thrown by design: if you hit "Cancel" in the choose file dialog, the script will return userCancelError. It's not returned as an *error* but as a string because it's not an error per se. The user hitting cancel is a viable correct option, so returning userCancelError allows you to manage that better.

	Note that PowerShell is case insensitive, so the parameters are as well

	.INPUTS
	None, there's nothing you can pipe to this

	.OUTPUTS
	Either an array of string(s) for folder paths or a string reading userCancelError

	.EXAMPLE
	Basic Choose Folder: Get-ChooseFolder
	That will give you a dialog that lets you choose a single folder

	.EXAMPLE
	Choose Folder with custom prompt: 
		Get-ChooseFolder -chooseFolderPrompt "My Custom Prompt"

	.EXAMPLE
	Choose folder starting in a specified folder: 
		Get-ChooseFolder -defaultLocation "Some unix path"
	Note that with the default location parameter, you shouldn't have to escape spaces, single quotes etc. Since this is expecting double quotes around the string, if you use a double quote in the file path, you'd have to escape it. HOWEVER, this is WHERE IT GETS WEIRD, because you have to combine unix AND PowerShell escaping.

	For Example, say the path you want to pass is: /Users/username/Pictures/Bill"s amazing pictures - to get that to work, you'd have to enter: "/Users/username/Pictures/Bill\`"s amazing pictures" because that will allow PowerShell to escape the double quote and pass the string: "/Users/username/Pictures/Bill\"s amazing pictures" to the unix command

	Try to avoid this, but if you can't, then the order is "PowerShell escape the string so Powershell passes a Unix-escaped string to the Unix command". If it makes your head hurt, JOIN THE CLUB

	ALSO IMPORTANT: avoid ~. It doesn't work. There's probably some escape magic that makes it work, but I'm too lazy to try to find it.

	.EXAMPLE
	Choose folder showing invisible folders:
		Get-ChooseFolder -showInvisibles $true
	The default for show invisibles is false. Note that in PowerShell, $true is True, $false is False using those without the $ will create a null-valued expression. The $ is IMPORTANT for bools

	.EXAMPLE
	Choose folder allowing multiple selections:
		Get-ChooseFolder -multipleSelectionsAllowed $true
	The default is false, it's a bool, so $true/$false

	.EXAMPLE
	Choose Folder and allow seeing the inside of packages
		Get-ChooseFolder -showPackageContents $true
	As with the other bools, the default is false, $true/$false to correctly set. This is mainly if you want to get paths inside of macOS packages, i.e. Application Packages. By default, selecting an application file would return a path to that app, so /Applications/Microsoft Word. Setting this to true lets you see inside the application bundle and select folder(s) inside that

	.LINK
	https://github.com/johncwelch/Get-PSChooseFolder

	#>
	
	Param (
		#we do the params this way so the help shows the description
		[Parameter(Mandatory = $false)][string]
		#optional, default is nothing
		$chooseFolderPrompt,
		[Parameter(Mandatory = $false)][string]
		#the dictionary says this has to be an alias, setting it to POSIX file works too.
		$defaultLocation,
		[Parameter(Mandatory = $false)][bool]
		#the default is false, so we only care if it's true
		$showInvisibles,
		[Parameter(Mandatory = $false)][bool]
		#same as for show invisibles
		$multipleSelectionsAllowed,
		[Parameter(Mandatory = $false)][bool]
		#default is false
		$showPackageContents
	)

	if (-Not $IsMacOS) {
		Write-Output "This module only runs on macOS, exiting"
		Exit
	}

	$chooseFolderCommand = "choose folder "

	#prompt processing
	if(-not [string]::IsNullOrEmpty($chooseFolderPrompt)) {
		$chooseFolderCommand = $chooseFolderCommand + "with prompt `"$chooseFolderPrompt`" "
	}

	if(-not [string]::IsNullOrEmpty($defaultLocation)) {
		#we have a location, but we have to be clever. Since we can't convert the path string to a POSIX file in a variable
		#we do the conversion in the command itself. Yes we need the quotes in the command once it's expanded, so we escape them

		$chooseFolderCommand = $chooseFolderCommand + "default location (`"$defaultLocation`" as POSIX file) "
	}

	#show invisibles processing
	if($showInvisibles) {
		#show invisibles is true
		$chooseFolderCommand = $chooseFolderCommand + "with invisibles "
	}

	if($multipleSelectionsAllowed) {
		#multiple selections allowed is true. This syntax seems awkward, but you can have multiple boolean "with" clauses in 
		#a choose file statement. It works for osascript and it's quite consistent.
		$chooseFolderCommand = $chooseFolderCommand + "with multiple selections allowed "
	}

	if($showPackageContents) {
		#we only care if showing package contents is true, the default is false, so we don't need to gode for that
		$chooseFolderCommand = $chooseFolderCommand + "with showing package contents "
	}

	#run the command
	$chooseFolderString = $chooseFolderCommand|/usr/bin/osascript -so

	#deal with cancel
	if($chooseFolderString.Contains("execution error: User canceled. `(-128`)")) {
		#Write-Output "user hit cancel button"
		return "userCancelError"
	}

	#build the output array
	$chooseFolderArray = $chooseFolderString.Split(",")
	#we need an arrayList here to shove the processed entries into.
	#we have to use a separate arraylist,
	#since we can't modify an array we're iterating through
	[System.Collections.ArrayList]$chooseFolderArrayList = @()

	#process the array removing spurious spaces and "alias "
	foreach($item in $chooseFolderArray){
		#remove any leading/trailing spaces
		$item = $item.Trim()
		#remove the leading "alias "
		$item = $item.Substring(6)
		#build the command to get the posix path. When expanded, $item has to be in quotes, so escaped quotes required
		$thePOSIXPathCommand = "get POSIX path of `"$item`""
		#run the command and get the posix path
		$item = $thePOSIXPathCommand|/usr/bin/osascript -so
		#add onto the arraylist
		$chooseFolderArrayList.Add($item) |Out-Null
	}

	#this is what we return
	return $chooseFolderArrayList
}

#what the module shows the world
Export-ModuleMember -Function Get-ChooseFolder



