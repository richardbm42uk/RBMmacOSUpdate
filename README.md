# RBM macOS Update

## Software Update scripts

By Richard Brown Martin

Originally written for Guardian on 24th November 2022

Updated for general use 13th April 2023

## Introduction

In order to install latest versions of macOS and other security updates that require a Mac to reboot, Apple require a command to be issued via MDM (eg: Jamf Pro) when running on Apple CPU-based Macs.

The scripts in this project are intended to provide a mechanism to:
- 	Download any updates in the background
- 	Monitor the status of downloaded Updates
- 	Trigger install of macOS Updates via MDM command

#### Components

#### RBM-SoftwareUpdateEA.sh

This script is designed to monitor the Software Update download status by readying the flag written at /Library/Preferences/uk.co.guardian.SWUpdate.txt

The expected values are:

NoUpdates	-	No Updates are available / Apple’s Software Update Server was unavailable at last execution of the Software Download script
Pending	-	Updates have been found when running the Software Download script, but have not been confirmed as fully downloaded
Downloaded 	-	Software Updates have been found and downloaded by last execution of Software Downloaded Script

#### GNM-SoftwareUpdateDownloader.sh

This script is designed to run in the background on client machines in order to download any Software Updates that require software 

It will write the flag file /Library/Preferences/uk.co.guardian.SWUpdate.txt to reflect software status

SoftwareUpdates are checked and filtered for updates that require a restart.
- If no updates are found, the flag is set to No Updates
- If updates are found, the flag is set to “Pending:” 
	- Softwareupdate download is triggered, and if completed the flag is changed to “Downloaded:”

##### Deployment notes: 
The GNM-SoftwareUpdateDownloader script should be deployed as a policy and scoped to run on machines where Jamf’s inventory has ascertained that a Mac requires software updates. 
Due to the long execution of downloading some software updates, the policy should only run less frequently than every checkin (eg: daily) and should not be scoped to Macs known to be in regions with limited internet or using mobile data.

#### GNM-SoftwareUpdateInstaller.sh

This script is designed to trigger macOS installation by way of a Jamf Pro API call to deliver an MDM command which will cause the Mac to install the update.

##### Overview of operation

1. Caffienate to prevent screen turning off
1. Check for available updates 
	- Exit if none available
1. Download any updates required
1. Send API call to Jamf Pro server to generate "macos-managed-software-updates” command
1. Loop until command causes reboot or up to 15 minutes, periodically checking Pending managed commands and displaying notifcations
	- If ScheduleOSUpdateScan is pending, show “Awaiting Update” (8 times for 3 seconds)
	- If AvailableOSUpdates is pending, show “Verifying Update” (8 times for 3 seconds)
	- If ScheduleOSUpdate is pending, show "Update Started" (1 time for 5 seconds)
	- If no commands are pending, show “Waiting to Start” ( 3 times for for 3 seconds)
	- After displaying message, send a blank push command and display “Nudging Update” (for 5 seconds)
1. If loop continues for over 15 minutes, kill Caffeinate and display “Software Update Time Out” (for 10 seconds)

##### Known issues

The MDM command “macos-managed-software-updates”  will only work on a Mac with Supervised status. Scoping should be used to exclude any Mac without this status.

##### Deployment

The script can be deployed using a variety of methods, including Self Service or automatically triggered
- If triggered by a package, it would be best to call a Jamf Policy Trigger to run the script in order to improve scoping
- Ideally the script should only be scoped to Macs that have already Downloaded the macOS update in order to minimise execution time and disruption to users
















