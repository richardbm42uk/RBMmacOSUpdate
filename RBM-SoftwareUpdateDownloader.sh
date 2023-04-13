#!/bin/bash

# Copyright Richard Brown-Martin 2023. All rights reserved.
# Strictly no un-authorised use, specifically by anyone at Jigsaw24.
# Anyone else can use this freely.

### RBM SoftwareUpdate Downloader

# Static variables

flagpath="/Library/Preferences/uk.co.academia.softwareupdates.txt"

log(){
	echo "$1"
	echo "$1" > "$flagpath"
}

#Check for updates
swup=$(softwareupdate -l)
updatesNeeded=$(( $(echo "$swup" | grep -c restart) ))

## Quit if no updates found or notify updates being downloaded
if (( $updatesNeeded < 1 )); then 
	log "No Updates"
	/usr/local/bin/jamf recon
	exit 0
else
	# Work out which software to download
	softwareToUpdateList=$(echo "$swup" | grep -B 1 restart | grep '*' | awk -F ':' '{print $NF}' | xargs)
	log "Pending: $softwareToUpdateList"
	/usr/local/bin/jamf recon &
fi


# Loop through each item to be downloaded
IFS=$'\n'
for softwareToUpdate in $softwareToUpdateList; do
	
	# Download the update
	softwareupdate -d "$softwareToUpdate" <<< "fakepass"

done 

log "Downloaded: $softwareToUpdateList"

/usr/local/bin/jamf recon