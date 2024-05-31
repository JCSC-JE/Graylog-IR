# Welcome Banner
Write-Host "Graylog EVTX UPLOAD SCRIPT | v1.0"
Write-Host "Zachary Burnham 2019 | @zmbf0r3ns1cs adjusted by @cyberkryption"
Write-Host "[!] If multiple systems, please ensure all logs are local and grouped by system within nested folders." "`n"

# Backend Maintenance
# Check to see if Winlogbeat Registry File from prior uploads exists
$regFile = Test-Path $pwd\winlogbeat-7.10.2\data\evtx-registry.yml
# If it does exists, remove Winlogbeat Registry File
if($regFile -eq $true){Remove-Item -Path $pwd\winlogbeat-7.10.2\data\evtx-registry.yml -Force}

# Get current date for logging
$date = Get-Date -UFormat "%m-%d"


# Ask for path containing desired logs
Do {
    Write-Host "Enter target directory path containing EVTX logs or folders grouping them by system (i.e. C:\Users\cyberkryption\EVTX-Logs)."
    $tempPath = Read-Host "Path"
    # Check to see if input path exists
    $checkPath = Test-Path $tempPath
    if($checkPath -eq $false){Write-Host "[!] Directory Path not found. Please check your input and try again." "`n"}
}
Until ($checkPath -eq $true)
Write-Host ""

# Adjust target directory path to have proper syntax for Winlogbeat, if needed
$userPath = $tempPath -replace '/','\'

# Check for nested folders
Write-Host "Do you have nested folders labeled by system within this directory? (Default is NO)"
    $nested = Read-Host "(y/n)" 
    Switch ($nested){ 
        Y {Write-Host ""} 
        N {Write-Host ""} 
        Default {
            Write-Host ""
            Write-Host "[*] Defaulting to no nested folders..." "`n"
        }
} 

# Perform directory check if nested folders exist
if($nested -eq "y"){
    Do {
        # Filter for all folders
        $folders = Get-ChildItem -Path $userPath -Directory

        # Verify Info
        Write-Host "The following folders (systems) were detected:"
        Write-Host ""
        Write-Host $folders
        Write-Host ""
        Write-Host "Is this the data you wish to upload? (Default is NO)"
            $answer = Read-Host "(y/n)" 
            Switch ($answer){ 
                Y {Write-Host ""} 
                N {Write-Host ""} 
                Default {
                    Write-Host ""
                    Write-Host "[*] Defaulting to NO..." "`n"
                } 
            } 
    }
    Until ($answer -eq "y")
}

# Ask for Client Name
$tempclient = Read-Host "Enter Client Name (i.e. JCSC.JE)"
# Replace Spaces, if any, in name for Graylog Index Name
$client = $tempClient -replace '\s','_'

# Ask for Case Number
$case = Read-Host "Enter Case # (i.e. 20-0101)"

#Ask for logtype
$templogtype = Read-Host "Enter log type (i.e. Server or Workstation)"
# Replace Spaces, if any, in name for logtyper
$logtype = $templogtype -replace '\s','_'

#Ask for location
$templocation = Read-Host "Enter location (i.e. St.Helier)"
# Replace Spaces, if any, in name for logtyper
$location = $templocation -replace '\s','_'

# Nested Folders Code
if($nested -eq "y"){
    # Filter for all folders
    $folders = Get-ChildItem -Path $userPath -Directory
    # Create for loop to cycle through all folders
    foreach($folder in $folders){
        # Define loop vars
        $i = 1
	    $ID = $folder
	    $foldersPath = $userPath + "\" + $folder
        # Filter for just the .evtx files within selected folder
	    $dirs = Get-ChildItem -Path $foldersPath -filter *.evtx
        $dirsCount = $dirs.Count
	    # Create for loop to grab all .evtx files within selected folder
	    foreach($file in $dirs){
            # Add shiny progress bar
            $percentComplete = ($i / $dirsCount) * 100
            Write-Progress -Activity "$i of $dirsCount EVTX files found within $foldersPath sent to Graylog" -Status "Uploading $file..." -PercentComplete $percentComplete
		    $filePath = $foldersPath + "\" + $file
            # Execute Winlogbeat w/custom vars
		    .\winlogbeat-7.10.2\winlogbeat.exe -e -c .\winlogbeat-7.10.2\winlogbeat-evtx.yml -E EVTX_FILE="$filePath" -E CLIENT="$client" -E CASE="$case" -E LOCATION="$location" -E LOGTYPE="$logtype" -E FILE="$file" 2>&1 >> $pwd\winlogbeat_log_${date}.txt
		    Sleep 3
            $i++
	    }
    }
}

# Single Folder Code
if($nested -eq "n"){
    $i = 1
    # Filter by EVTX extension
    $dirs = Get-ChildItem -Path $userPath -filter *.evtx
    $dirsCount = $dirs.Count
	# Create for loop to grab all .evtx files within selected folder
	foreach($file in $dirs){
        # Add shiny progress bar
        $percentComplete = ($i / $dirsCount) * 100
        Write-Progress -Activity "$i of $dirsCount EVTX files found within $userPath sent to Graylog" -Status "Uploading $file..." -PercentComplete $percentComplete
		$filePath = $userPath + "\" + $file
        # Execute Winlogbeat w/custom vars
		.\winlogbeat-7.10.2\winlogbeat.exe -e -c .\winlogbeat-7.10.2\winlogbeat-evtx.yml -E EVTX_FILE="$filePath" -E CLIENT="$client" -E CASE="$case" -E LOCATION="$location" -E LOGTYPE="$logtype" -E FILE="$file" 2>&1 >> $pwd\winlogbeat_log_${date}.txt
		Sleep 3
        $i++
	}
}

# Show message confirming successful upload
Write-Host "[*] EVTX Upload completed. View uploaded file data in Graylog."