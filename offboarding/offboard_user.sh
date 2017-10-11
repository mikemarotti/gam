#!/bin/bash
#This script performs various offboarding tasks when a user leaves the company.
username=$1
gam="$HOME/bin/gam/gam"

Removing all mobile devices connected
echo "Gathering mobile devices for $username"
IFS=$'\n'
mobile_devices=($($gam print mobile query $username | grep -v resourceId | awk -F"," '{print $1}'))
unset IFS
	for mobileid in ${mobile_devices[@]}
		do
			$gam update mobile $mobileid action account_wipe && echo "Removing $mobileid from $username"
	done | tee -a /tmp/$username.log

# Changing user's password to random
echo "Changing "$username"'s' password to something random"
$gam update user $username password random | tee -a /tmp/$username.log

# Removing all App-Specific account passwords, deleting MFA Recovery Codes,
# deleting all OAuth tokens
echo "Checking and Removing all of "$username"'s Application Specific Passwords, 2SV Recovery Codes, and all OAuth tokens"
$gam user $username deprovision | tee -a /tmp/$username.log

# Removing user from all Groups
echo "Gathering group information for $username"
amount_of_groups="$($gam info user $username | grep "Groups: (" | sed 's/[^0-9]//g')"
IFS=$'\n'	
groups_list=($($gam info user $username | grep -A $amount_of_groups Groups | grep -v Groups | sed 's/^[^<]*<//g' | sed 's/\@.*$//g'))
unset IFS
	for group_name in ${groups_list[@]}
		do
			$gam update group $group_name remove user $username && echo "Removed $username from $group_name"
	done | tee -a /tmp/$username.log 

# Forcing change password on next sign-in and then disabling immediately. 
# Speculation that this will sign user out within 5 minutes and not allow 
# user to send messages without reauthentication
echo "Setting force change password on next logon and then disabling immediately to expire current session"
$gam update user $username changepassword on
sleep 2 && echo "Waiting for 2 seconds"
$gam update user $username changepassword off

# Generating new set of MFA recovery codes for the user
echo "Generating new 2SV Recovery Codes for $username"
$gam user $username update backupcodes | tee -a /tmp/$username.log

# Removing all of user's calendar events
read -r -p "Do you want to Wipe "$username"'s calendar? [y/N]"
if [[ $response =~ ^([yY][eE][sS] |[yY][eE][sS])$ ]]
	then
		echo "Deleting all of "$username"'s calendar events"
		$gam calendar $username wipe | tee -a /tmp/$username.log
	else
		echo "Not wiping calendar" | tee -a /tmp/$username.log
fi

# Suspending user
echo "Setting $username to suspended"
$gam update user $username suspended on | tee -a /tmp/$username.log

# Asks admin if they want to transfer docs to manager, if so, asks for manager's 
# google username and then initiate a gdrive file transfer
read -r -p "Do you want to transfer Google Drive to the manager? [y/N] " response
if [[ $response =~ ^([yY][eE][sS] |[yY][eE][sS])$ ]]
	then 
		read -r -p "What is "$username"'s manager's username? " r_manager
		echo "Creating transfer to $r_manager"
		$gam create datatransfer $username gdrive $r_manager privacy_level shared,private | tee -a /tmp/$username.log
	else
		echo "Not transferring GDrive" | tee -a /tmp/$username.log
fi

# Printing Log location
echo "Offboard complete for $username."
echo "Temporary Log located at /tmp/$username.log"