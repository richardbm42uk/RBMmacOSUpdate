#!/bin/bash

# No Updates = Nothing to update
# Pending = Updates have been found but softwareupdate -d has not completed
# Downloaded = SoftwareUpdate has downloaded


echo "<result>$(cat /Library/Preferences/uk.co.academia.softwareupdates.txt)</result>"

