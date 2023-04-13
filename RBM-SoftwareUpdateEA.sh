#!/bin/bash

# Copyright Richard Brown-Martin 2023. All rights reserved.
# Strictly no un-authorised use, specifically by anyone at Jigsaw24.
# Anyone else can use this freely.



# No Updates = Nothing to update
# Pending = Updates have been found but softwareupdate -d has not completed
# Downloaded = SoftwareUpdate has downloaded


echo "<result>$(cat /Library/Preferences/uk.co.academia.softwareupdates.txt)</result>"

