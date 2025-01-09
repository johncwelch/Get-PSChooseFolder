#initial Get-ChooseFolder script.
#this will steal a LOT from Get-ChooseFile

function Get-ChooseFolder {
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