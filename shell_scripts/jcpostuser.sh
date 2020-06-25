#!/bin/bash
# This script will create a Jumpcloud user using the Jumpcloud API
# This will be added to the newhire script once it's finalized
# Requires API Key to run and jq to be installed

abort() {
	errString=${*}
	echo "$errString"
	exit 1
}
# checks if jq is installed
jq --version
err=$?
if [[ ${err} -ne 0 ]]; then
    abort "jq is not installed, please install jq using 'brew install jq' and run the script again"
fi

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
read -p 'Enter new user email address: ' userEmail
read -p 'Enter new user username: ' userName
read -p 'Enter new user first name: ' firstName
read -p 'Enter new user last name: ' lastName
# read -p 'Enter api key: ' apiKey

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
    "password":"'$firstName.$lastName'"
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
    echo "New hire created successfully!" && rm $HOME/jcapikey.txt && exit 0
fi