#!/bin/bash

# Copyright Richard Brown-Martin 2023. All rights reserved.
# Strictly no un-authorised use, specifically by anyone at Jigsaw24.
# Anyone else can use this freely.

# Jamf Credentials
username="updateAPI"
password="updateAPIuser123!"
URL="https://jigsaw24richard.jamfcloud.com"

# Max time to wait
maxTime=900

# Log Path
logPath="/var/log/softwareupdates.log"

#Flag path for EA
flagpath="/Library/Preferences/uk.co.academia.softwareupdates.txt"

previousMessage=""

bearerToken=""
tokenExpirationEpoch="0"

xpath() {
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
		/usr/bin/xpath "$@"
	fi
}

displayDialogwithGNMalert(){
	if [ "$previousMessage" != "$1" ]; then
		echo "$1"
	fi
	/usr/local/bin/gnmalert "$1" -w "$2" -t "$3" $1>/dev/null
	previousMessage="$1"
}

displayDialog (){
	echo "$1"
	echo "$(date): $1" >> $logPath
	if [ -n "$3" ]; then
		sleep $3
	fi
}

getCommandStatus(){
	status=$(curl --request GET \
--url $URL/JSSResource/computerhistory/id/$computerID/subset/Commands \
--header "Authorization: Bearer $bearerToken" \
--header 'accept: application/xml' | xmllint --xpath "//commands/pending/command/name/text()" - )
}

sendBlankPush(){
	curl --request POST \
	--header "Authorization: Bearer $bearerToken" \
	--url $URL/JSSResource/computercommands/command/BlankPush/id/$computerID
}


getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$URL"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

checkTokenExpiration() {
	nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
	if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
	then
		echo "Token valid until the following epoch time: " "$tokenExpirationEpoch"
	else
		echo "No valid token available, getting new token"
		getBearerToken
	fi
}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" $URL/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		bearerToken=""
		tokenExpirationEpoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}


#### Start of Script

caffeinate -dimsu &
caffeinatePID=$!

## Check for software updates 
#Display Message 
displayDialog "Checking for macOS Updates" 3 30 &
#Check for updates
swup=$(softwareupdate -l)
updatesNeeded=$(( $(echo "$swup" | grep -c restart) ))

## Quit if no updates found or notify updates being downloeded
if (( $updatesNeeded < 1 )); then 
	displayDialog "No Updates needed" 2 5 &
	echo "No Updates" > "$flagpath"
	exit 0
else
	displayDialog "$updatesNeeded Updates needed, starting download" 2 5 &
fi

# Work out which software to download
softwareToUpdateList=$(echo "$swup" | grep -B 1 restart | grep '*' | awk -F ':' '{print $NF}' | xargs)

# Loop through each item to be downloaded
IFS=$'\n'
for softwareToUpdate in $softwareToUpdateList; do
	
	# Download the update
	softwareupdate -d "$softwareToUpdate" <<< "fakepass" &
	displayDialog  "Starting Download $softwareToUpdate" 3 10
	
	# Loop the message while downloading
	softwareUpdateRunning=$(ps aux | grep -c "softwareupdate -d" )
	while (( $softwareUpdateRunning > 1 )); do
		displayDialog  "Downloading $softwareToUpdate" 3 10
		softwareUpdateRunning=$(ps aux | grep -c "softwareupdate -d" )
	done
done 

# Display a complete message
displayDialog  "macOS Updates Downloaded" 3 5


##### Softwareupdates now downloaded... starting install with API call...

# Use encoded username and password to request a token with an API call and store the output as a variable in a script:
checkTokenExpiration

# Grab the serial for the Mac we're running on
serial=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'"' '/IOPlatformSerialNumber/{print $4}')

# Use an API call to get the Jamf ID for the Mac
computerID=$(curl --request GET \
--url $URL/JSSResource/computers/serialnumber/$serial \
--header 'accept: application/xml' \
--silent \
--header "Authorization: Bearer $bearerToken" | xmllint --xpath "//computer/general/id/text()" - )

echo $computerID

# Send the SoftwareUpdate command
curl --request POST \
--header "Authorization: Bearer $bearerToken" \
--url $URL/api/v1/macos-managed-software-updates/send-updates \
--header 'accept: application/json' \
--header 'content-type: application/json' \
--data "
{
			\"deviceIds\": [
					\"$computerID\"
			],
			\"skipVersionVerification\": false,
			\"applyMajorUpdate\": false,
			\"forceRestart\": true,
			\"maxDeferrals\": 0
}"

displayDialog "Install triggered, please connect to power and wait for reboot!" 1 30 &

startTime=$(date +%s)
nowTime=$(date +%s)
timeDiff=$(( $startTime - $nowTime ))

# Loop until the timer runs out
while (( $timeDiff < $maxTime )); do
	
	# Check if there are any commands pending
	getCommandStatus
	# Filter commands for ScheduleOSUpdateScan
	pendingScheduleOSUpdateScan=$(echo "$status" | grep -c ScheduleOSUpdateScan )
	if (( $pendingScheduleOSUpdateScan > 0 )); then
		# Show updates for ~1 min
		for i in {1..8}; do
			nowTime=$(date +%s)
			timeDiff=$(( $nowTime - $startTime ))
			timeRemaining=$(( ($maxTime - $timeDiff) / 60))
			displayDialog "Awaiting Update, $timeRemaining minutes remaining" 2 3
		done
	else
		# Filter commands for AvailableOSUpdates
		pendingAvailableOSUpdates=$(echo "$status" | grep -c AvailableOSUpdates )
		if (( $pendingAvailableOSUpdates > 0 )); then
			# Show updates for ~1 min
			for i in {1..8}; do
				nowTime=$(date +%s)
				timeDiff=$(( $nowTime - $startTime ))
				timeRemaining=$(( ($maxTime - $timeDiff) / 60))
				displayDialog "Verifying Update, $timeRemaining minutes remaining" 2 3
			done
		else
			# Reset the updates flag
			echo "No Updates" > "$flagpath"
			# Show update Started for for 5 seconds and quit loop
			pendingScheduleOSUpdate=$(echo "$status" | grep -c ScheduleOSUpdate )
			if  (( $pendingScheduleOSUpdate > 0 )); then
				displayDialog "Update Started" 2 5 &
				break
			else
				# If no pending updates, then show "Waiting to Start" and loop for 10 seconds
				for i in {1..3}; do
					nowTime=$(date +%s)
					timeDiff=$(( $nowTime - $startTime ))
					timeRemaining=$(( ($maxTime - $timeDiff) / 60))
					displayDialog "Waiting to Start" 2 3
				done
			fi
		fi
	fi
	
	#Send a blank push
	sendBlankPush 
	displayDialog "Nudging Update" 1 5 &
	
done

invalidateToken

kill $caffeinatePID

displayDialog "Software Update Timed Out" 1 10