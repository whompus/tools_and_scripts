#!/bin/bash

# Author: Mat L
# This script will create a Google, Jumpcloud, and Slack account based on the information you provide.
# It assumes you have GAM installed on your local machine in $gamDir.
# An API key is required for Jumpcloud and Slack and jq must be installed
# Slack API keys can be found here: https://api.slack.com/custom-integrations/legacy-tokens

abort() {
	errString=${*}
	echo "$errString"
	exit 1
}

# checks if jq is installed, this is required to parse the user ID from user creation into the API request to add to specific group
jq --version > /dev/null 2>&1
err=$?
if [[ ${err} -ne 0 ]]; then
  abort "jq is not installed, it is required. Please install jq using 'brew install jq' and run the script again"
fi

# checks if GAM is installed in the correct directory #add check for path?
gamDir="$HOME/bin/gam/gam"
if [[ ! -d /Users/$USER/bin/gam ]]
then
  abort "GAM is not installed in correct directory, please install in ${gamDir}, exiting"
fi

# new hire account information
echo
echo "---------------"
echo "New Hire Script"
echo "---------------"
echo
echo "~Google Account Creation~"
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
  read -p 'Location (CO, NY, HO, UK, or HK): ' location
fi

userEmail="${firstName}.${lastName}@sphero.com"
passwd="${firstName}.${lastName}${startDate}"
uservar="${firstName}.${lastName}"

# create google account
echo "Creating GApps account for ${firstName}..."
$gamDir create user $userEmail firstname $firstName lastname $lastName password $passwd changepassword on || exit $?
sleep 2

if [[ $empType == [Ee]* ]]; then
  echo "Adding user to ${location}@sphero.com DL..."
  case $location in
    CO|co) $gamDir update group co@sphero.com add member $userEmail ;;
    NY|ny) $gamDir update group ny@sphero.com add member $userEmail ;;
    HO|ho) $gamDir update group homeoffice@sphero.com add member $userEmail ;;
    UK|uk) $gamDir update group uk@sphero.com add member $userEmail ;;
    HK|hk) $gamDir update group teamhk@sphero.com add member $userEmail && $gamDir update group hk@sphero.com add member $userEmail ;;
  esac
  
  read -p "Do you want to add $firstName $lastName to an additional group? [y/n]: " answer
  while [[ $answer == y* ]]; do
    read -p 'Additional group to add to (do not append @sphero.com): ' group;
    read -p 'member or owner? (m/o) ' priv # while read -p 'member or owner? ' priv && [[ $priv != [MmOo] ]]; do printf 'Please enter M or O\n' >&2 /dev/null
    if [[ $priv == [Mm] ]]; 
        then ~/bin/gam/gam update group $group add member ${uservar}@sphero.com
    elif [[ $priv == [Oo] ]]; 
        then ~/bin/gam/gam update group $group add owner ${uservar}@sphero.com
    fi
    printf "Any additional groups? [y/n]: " 
    read answer
  done
  
  #echo "Adding user to all@sphero.com..."
  #$gamDir update group all@sphero.com add member $userEmail
  echo "Generating backup codes..."
  $gamDir user ${firstName}.${lastName} update backupcodes
else
  echo "Adding user to 2-step-exempt@sphero.com..."
  $gamDir update group 2-step-exempt@sphero.com add member $userEmail
fi

echo "Updating profile picture..."
cd /tmp
curl -OLk spherosrv02/files/logo.png > /dev/null 2>&1
$gamDir user ${firstName}.${lastName} update photo logo.png

echo
echo "Here are the groups that the user is a part of (for verification): "
$gamDir print groups member $userEmail
echo

err=$?
if [[ ${err} -ne 0 ]]; then
  abort "Aborting, there was a problem finalizing the Google account, please check the user's account in the admin panel"
else
  echo "Google account created successfully"
fi

# JC account creation
# checks to see if encrypted file exists, creates it on first use and encrypts/password protects file
echo "~API keys input and encrypted file generation~"
if test ! -e $HOME/apikeyencrypted.txt; then
  read -p "No encrypted API key file detected, please enter your Jumpcloud API key: " jcApiTxt
  read -p "Enter Slack API key: " slackApiTxt  
  printf "%s\n" "${jcApiTxt}" "${slackApiTxt}" > $HOME/apikey.txt && openssl enc -aes-256-cbc -e -in $HOME/apikey.txt -out $HOME/apikeyencrypted.txt
  echo "File created and password protected; you will not need to provide your API key again, only a password"
fi

# decrypts the file with password sepcified above, and creates apikey.txt
echo "Decrypting apikeyencrypted.txt file..."
until openssl enc -aes-256-cbc -d -in $HOME/apikeyencrypted.txt -out $HOME/apikey.txt > /dev/null 2>&1; do
  printf "Wrong password, check your fingers and try again\n" >&2
done

jcKey=$(sed -n 1p $HOME/apikey.txt)
slackKey=$(sed -n 2p $HOME/apikey.txt)
allEmps="59400ceb1f247535a9160628"
allCont="5a5934f31f24755c30baf64f"

echo
echo "~Jumpcloud User Creation~"
echo
read -p 'Enter new user Jumpcloud username: ' userName
echo "Creating Jumpcloud account for ${firstName}..."
# POST API call to create jumpcloud user, sets password, and uses jq to parse $userID from user creation which passes it into group addition below
userID=$(curl -s -X POST https://console.jumpcloud.com/api/systemusers \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${jcKey}" \
  -d '{"username":"'${userName}'", "email":"'${userEmail}'", "firstname":"'${firstName}'", "lastname":"'${lastName}'", "displayname":"'${firstName}' '${lastName}'", "password":"'${passwd}'"}' | jq -r '._id')

err=$?
if [[ ${err} -ne 0 ]]; then
  echo "There was a problem creating the user account, please check Jumpcloud." && rm $HOME/apikey.txt
fi

if [[ $empType == [Ee]* ]]; then
  curl -X POST https://console.jumpcloud.com/api/v2/usergroups/${allEmps}/members \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${jcKey}" \
  -d '{"op": "add", "type": "user", "id": "'${userID}'"}'
  
  err=$?
  if [[ ${err} -ne 0 ]]; then
    echo "There was a problem creating the user account, please check Jumpcloud." && rm $HOME/apikey.txt
  else
    echo "Jumpcloud account created successfully"
    echo "Added $userName to All_Emps"
  fi

else
  curl -X POST https://console.jumpcloud.com/api/v2/usergroups/${allCont}/members \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${jcKey}" \
  -d '{"op": "add", "type": "user", "id": "'${userID}'"}'
  
  err=$?
  if [[ ${err} -ne 0 ]]; then
    echo "There was a problem creating the user account, please check Jumpcloud." && rm $HOME/apikey.txt
  else
    echo "Jumpcloud account created successfully"
    echo "Added $userName to All_Contractors"
  fi

fi

echo
echo "~Slack User Addition~"
echo
echo "Adding ${firstName} to Slack... "

curl -X POST "https://sphero.slack.com/api/users.admin.invite?token=${slackKey}&email=${userEmail}" -H 'Content-Type: application/json' > /dev/null 2>&1

err=$?
if [[ ${err} -ne 0 ]]; then
  abort "Aborting, There was a problem creating the user account, please check Slack or try running the script again." && rm $HOME/apikey.txt
else
  echo "Slack account created successfully, bye bye" && rm $HOME/apikey.txt && exit 0
fi