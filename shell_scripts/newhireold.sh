#!/bin/bash

# Author: Mat L
# This script will create both a Google and Jumpcloud account based on the information you provide.
# It assumes you have GAM installed on your local machine in $gappsm.
# An API key is required for Jumpcloud and jq must be installed

abort() {
	errString=${*}
	echo "$errString"
	exit 1
}

# checks if jq is installed
jq --version > /dev/null 2>&1
err=$?
if [[ ${err} -ne 0 ]]; then
  abort "jq is not installed, please install jq using 'brew install jq' and run the script again"
fi

# checks if GAM is installed in the correct directory
if [[ ! -d /Users/$USER/bin/gam ]]
then
  echo "GAM is not installed in correct directory, please install in $gappsm, exiting"
  exit 1
fi

# new hire account information
echo "New Hire Script"
echo
echo "Please enter the New Hire information below: "
while read -p 'User First Name: ' firstName && [[ $firstName != [[:upper:]]* ]]; do
  printf 'Please enter a capitalized name\n' >&2
done
while read -p 'User Last Name: ' lastName && [[ $lastName != [[:upper:]]* ]]; do
  printf 'Please enter a capitalized name\n' >&2
done
while read -p 'Start Date (day of the month, e.g. 01, 15, 31): ' startDate && [[ $startDate != [[:digit:]]* ]]; do 
  printf 'Please enter a number in the correct format: DD\n' >&2
done
while read -p 'Is this an employee or contractor? (e/c) ' empType && [[ $empType != [EeCc] ]]; do
    printf 'Please enter either "e" or "c"\n' >&2
done
if [[ $empType == [Ee]* ]]; then
  read -p 'Location (US, UK, or HK): ' location
fi

userEmail="$firstName.$lastName@sphero.com"
gappsm="$HOME/bin/gam/gam"

# create google account
echo "Creating Gapps account..."
  $gappsm create user $userEmail firstname $firstName lastname $lastName password ${firstName}.${lastName}${startDate} changepassword on || exit $?
sleep 2

if [[ $empType == [Ee]* ]]; then
  echo "Adding user to DLs based on location..."
  case $location in
  US|us) $gappsm update group us@sphero.com add member $userEmail ;;
  UK|uk) $gappsm update group uk@sphero.com add member $userEmail ;;
  HK|hk) $gappsm update group teamhk@sphero.com add member $userEmail &&
         $gappsm update group hk@sphero.com add member $userEmail ;;
  esac
  echo "Adding user to all@sphero.com..."
    $gappsm update group all@sphero.com add member $userEmail
  echo "Generating backup codes..."
    $gappsm user ${firstName}.${lastName} update backupcodes
else
  echo "Adding user to 2-step-exempt@sphero.com..."
    $gappsm update group 2-step-exempt@sphero.com add member $userEmail
fi
echo "Updating profile picture..."
  cd /tmp
  curl -OLk spherosrv02/files/logo.png > /dev/null 2>&1
  $gappsm user ${firstName}.${lastName} update photo /tmp/logo.png
echo
echo "Here are the groups that the user is a part of (for verification): "
  $gappsm print groups member $userEmail

err=$?
if [[ ${err} -ne 0 ]]; then
  abort "There was a problem finalizing the google account, please check the user's account in the admin panel"
else
  echo "Google account created successfully"
fi

# JC account creation
# checks to see if encrypted file exists, creates it on first use and encrypts/password protects file
if test ! -e $HOME/jcapikeyencrypted.txt; then
  read -p "No encrypted API key file detected, please enter you API key to create the encrypted file: " apiTxt
  echo ${apiTxt} > $HOME/jcapikey.txt && openssl enc -aes-256-cbc -e -in $HOME/jcapikey.txt -out $HOME/jcapikeyencrypted.txt
  echo "File created and password protected, you will not need to provide your api key again, only a password"
  echo "Decrypting API key file... "
else
  echo "Decrypting API key file... "
fi

# decrypts the file with password sepcified above, and creates jcapikey.txt
openssl enc -aes-256-cbc -d -in $HOME/jcapikeyencrypted.txt -out $HOME/jcapikey.txt

apiKey=$(head -n 1 $HOME/jcapikey.txt)
read -p 'Enter new user Jumpcloud username: ' userName

# POST request to create jumpcloud user, sends new user an email
userID=$(curl -s -X POST https://console.jumpcloud.com/api/systemusers \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: $apiKey" \
  -d '{
	"username":"'$userName'",
	"email":"'$userEmail'",
	"firstname":"'$firstName'",
	"lastname":"'$lastName'",
  "password":"'${firstName}.${lastName}${startDate}'"
}' | jq -r '._id') && curl -X POST https://console.jumpcloud.com/api/v2/usergroups/59400ceb1f247535a9160628/members \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: $apiKey" \
  -d '{
    "op": "add",
    "type": "user",
    "id": "'${userID}'"
}'

err=$?
if [[ ${err} -ne 0 ]]; then
  abort "There was a problem creating the user account, please check jumpcloud or try running the script again." && rm $HOME/jcapikey.txt
else
  echo "New hire created successfully and added to all_emps" && rm $HOME/jcapikey.txt && exit 0
fi
exit 0
