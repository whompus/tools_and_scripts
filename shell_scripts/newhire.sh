#!/bin/bash

# Author: Mat L
# This script will create a Google, Jumpcloud, and Slack account based on the information you provide.
# It assumes you have GAM installed on your local machine in ${GAM_DIR}.
# An API key is required for Jumpcloud and Slack and jq must be installed
# Slack API keys can be found here: https://api.slack.com/custom-integrations/legacy-tokens

abort() {
	ERR_STRING=${*}
	echo "${ERR_STRING}"
	exit 1
}

FILE_SERVER="hostname"

# checks if jq is installed, this is required to parse the user ID from user creation into the API request to add to specific group
jq --version > /dev/null 2>&1

ERR=$?

if [[ ${ERR} -ne 0 ]]; then
  abort "jq is not installed, it is required. Please install jq using 'brew install jq' and run the script again"
fi

# checks if GAM is installed in the correct directory #add check for path?
GAM_DIR="${HOME}/bin/gam/gam"

if [[ ! -d /Users/$USER/bin/gam ]]
then
  abort "GAM is not installed in correct directory, please install in ${GAM_DIR}, exiting"
fi

# new hire account information
echo
echo "---------------"
echo "New Hire Script"
echo "---------------"
echo
echo "~Google Account Creation~"

while read -p 'User First Name: ' FIRST_NAME && [[ ${FIRST_NAME} != [[:upper:]]* ]]; do
  printf 'Please enter a capitalized name\n' >&2
done

while read -p 'User Last Name: ' LAST_NAME && [[ ${LAST_NAME} != [[:upper:]]* ]]; do
  printf 'Please enter a capitalized name\n' >&2
done

while read -p 'Start Date (day of the month, e.g. 01, 15, 31): ' START_DATE && [[ ${START_DATE} != [[:digit:]]* ]]; do 
  printf 'Please enter a number in the correct format: DD\n' >&2
done

while read -p 'Is this an employee or contractor? (e/c) ' EMP_TYPE && [[ {$EMP_TYPE} != [EeCc] ]]; do
    printf 'Please enter either "e" or "c"\n' >&2
done

if [[ {$EMP_TYPE} == [Ee]* ]]; then
  read -p 'LOCATION (CO, NY, HO, UK, or HK): ' LOCATION
fi

USER_EMAIL="${FIRST_NAME}.${LAST_NAME}@example.com"
PASSWD="${FIRST_NAME}.${LAST_NAME}${START_DATE}"
USER_VAR="${FIRST_NAME}.${LAST_NAME}"

# create google account
echo "Creating GApps account for ${FIRST_NAME}..."
${GAM_DIR} create user ${USER_EMAIL} firstname ${FIRST_NAME} lastname ${LAST_NAME} password ${PASSWD} changepassword on || exit $?
sleep 2

if [[ ${EMP_TYPE} == [Ee]* ]]; then
  echo "Adding user to ${LOCATION}@example.com DL..."
  case ${LOCATION} in
    CO|co) ${GAM_DIR} update group co@example.com add member ${USER_EMAIL} ;;
    NY|ny) ${GAM_DIR} update group ny@example.com add member ${USER_EMAIL} ;;
    HO|ho) ${GAM_DIR} update group homeoffice@example.com add member ${USER_EMAIL} ;;
    UK|uk) ${GAM_DIR} update group uk@example.com add member ${USER_EMAIL} ;;
    HK|hk) ${GAM_DIR} update group teamhk@example.com add member ${USER_EMAIL} && ${GAM_DIR} update group hk@example.com add member ${USER_EMAIL} ;;
  esac
  
  read -p "Do you want to add ${FIRST_NAME} ${LAST_NAME} to an additional group? [y/n]: " ANSWER
  while [[ ${ANSWER} == y* ]]; do
    read -p 'Additional group to add to (do not append @example.com): ' GROUP;
    read -p 'member or owner? (m/o) ' priv # while read -p 'member or owner? ' priv && [[ ${PRIV} != [MmOo] ]]; do printf 'Please enter M or O\n' >&2 /dev/null
    if [[ ${PRIV} == [Mm] ]]; 
        then ~/bin/gam/gam update group ${GROUP} add member ${USER_VAR}@example.com
    elif [[ ${PRIV} == [Oo] ]]; 
        then ~/bin/gam/gam update group ${GROUP} add owner ${USER_VAR}@example.com
    fi
    printf "Any additional groups? [y/n]: " 
    read ANSWER
  done
  
  #echo "Adding user to all@example.com..."
  #${GAM_DIR} update group all@example.com add member ${USER_EMAIL}
  echo "Generating backup codes..."
  ${GAM_DIR} user ${FIRST_NAME}.${LAST_NAME} update backupcodes
else
  echo "Adding user to 2-step-exempt@example.com..."
  ${GAM_DIR} update group 2-step-exempt@example.com add member ${USER_EMAIL}
fi

echo "Updating profile picture..."
cd /tmp
curl -OLk ${FILE_SERVER}/files/logo.png > /dev/null 2>&1
${GAM_DIR} user ${FIRST_NAME}.${LAST_NAME} update photo logo.png

echo
echo "Here are the groups that the user is a part of (for verification): "
${GAM_DIR} print groups member ${USER_EMAIL}
echo

ERR=$?
if [[ ${ERR} -ne 0 ]]; then
  abort "Aborting, there was a problem finalizing the Google account, please check the user's account in the admin panel"
else
  echo "Google account created successfully"
fi

# JC account creation
# checks to see if encrypted file exists, creates it on first use and encrypts/password protects file
echo "~API keys input and encrypted file generation~"
if test ! -e ${HOME}/apikeyencrypted.txt; then
  read -p "No encrypted API key file detected, please enter your Jumpcloud API key: " JC_API_KEY_TXT
  read -p "Enter Slack API key: " SLACK_API_KEY_TXT  
  printf "%s\n" "${JC_API_KEY_TXT}" "${SLACK_API_KEY_TXT}" > ${HOME}/apikey.txt && openssl enc -aes-256-cbc -e -in ${HOME}/apikey.txt -out ${HOME}/apikeyencrypted.txt
  echo "File created and password protected; you will not need to provide your API key again, only a password"
fi

# decrypts the file with password sepcified above, and creates apikey.txt
echo "Decrypting apikeyencrypted.txt file..."
until openssl enc -aes-256-cbc -d -in ${HOME}/apikeyencrypted.txt -out ${HOME}/apikey.txt > /dev/null 2>&1; do
  printf "Wrong password, check your fingers and try again\n" >&2
done

JC_API_KEY=$(sed -n 1p ${HOME}/apikey.txt)
SLACK_API_KEY=$(sed -n 2p ${HOME}/apikey.txt)
JC_GROUP_1="59400ceb1f247535a9160628"
JC_GROUP_2="5a5934f31f24755c30baf64f"

echo
echo "~Jumpcloud User Creation~"
echo
read -p 'Enter new user Jumpcloud username: ' JC_USER_NAME
echo "Creating Jumpcloud account for ${FIRST_NAME}..."

# POST API call to create jumpcloud user, sets password, and uses jq to parse $JC_USER_ID from user creation which passes it into group addition below
JC_USER_ID=$(curl -s -X POST https://console.jumpcloud.com/api/systemusers \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${JC_API_KEY}" \
  -d '{"username":"'${JC_USER_NAME}'", "email":"'${USER_EMAIL}'", "FIRST_NAME":"'${FIRST_NAME}'", "LAST_NAME":"'${LAST_NAME}'", "displayname":"'${FIRST_NAME}' '${LAST_NAME}'", "password":"'${PASSWD}'"}' | jq -r '._id')

ERR=$?
if [[ ${ERR} -ne 0 ]]; then
  echo "There was a problem creating the user account, please check Jumpcloud." && rm ${HOME}/apikey.txt
fi

if [[ {$EMP_TYPE} == [Ee]* ]]; then
  curl -X POST https://console.jumpcloud.com/api/v2/usergroups/${JC_GROUP_1}/members \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${JC_API_KEY}" \
  -d '{"op": "add", "type": "user", "id": "'${JC_USER_ID}'"}'
  
  ERR=$?
  if [[ ${ERR} -ne 0 ]]; then
    echo "There was a problem creating the user account, please check Jumpcloud." && rm ${HOME}/apikey.txt
  else
    echo "Jumpcloud account created successfully"
    echo "Added ${JC_USER_NAME} to All_Emps"
  fi

else
  curl -X POST https://console.jumpcloud.com/api/v2/usergroups/${JC_GROUP_2}/members \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${JC_API_KEY}" \
  -d '{"op": "add", "type": "user", "id": "'${JC_USER_ID}'"}'
  
  ERR=$?
  if [[ ${ERR} -ne 0 ]]; then
    echo "There was a problem creating the user account, please check Jumpcloud." && rm ${HOME}/apikey.txt
  else
    echo "Jumpcloud account created successfully"
    echo "Added ${JC_USER_NAME} to All_Contractors"
  fi

fi

echo
echo "~Slack User Addition~"
echo
echo "Adding ${FIRST_NAME} to Slack... "

curl -X POST "https://sphero.slack.com/api/users.admin.invite?token=${SLACK_API_KEY}&email=${USER_EMAIL}" -H 'Content-Type: application/json' > /dev/null 2>&1

ERR=$?

if [[ ${ERR} -ne 0 ]]; then
  abort "Aborting, There was a problem creating the user account, please check Slack or try running the script again." && rm ${HOME}/apikey.txt
else
  echo "Slack account created successfully, bye bye" && rm ${HOME}/apikey.txt && exit 0
fi