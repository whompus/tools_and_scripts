#!/bin/bash

#Authors: Mat Lee & JD Snodgrass
#This will activate GSuite accounts hidden from the GAL, add the accounts to specified groups, and set the password on each
#It assumes you have the GAM tool installed or linked on your local machine to ~/bin/gam
#Parameters: File path to a CSV (tab delimited) with first, last, and Email Address


# Define an error abort function
abort() {
	errString=${*}
	echo "$errString"
	exit 1
}

#Set the GAM installation dir into a variable
gamDir="$HOME/bin/gam/gam"

#Check for proper GAM installation
if [[ ! -d /Users/$USER/bin/gam ]]
then
    abort "GAM is not installed in correct directory, please install in $gamDir, exiting"
fi

#Script Title
echo "--------------------------------------------"
echo "Google Activation Script for Hidden Accounts"
echo "--------------------------------------------"
echo

#Collect user information when no file of users is supplied at script call: First, Last, number of date for password
if [[ -z $1 ]]; then
    echo "No file supplied, please enter the account information below: "
    while read -p 'User First Name: ' first && [[ $first != [[:upper:]]* ]]; do
        printf 'Please enter a capitalized name\n' >&2
    done
    while read -p 'User Last Name: ' last && [[ $last != [[:upper:]]* ]]; do
        printf 'Please enter a capitalized name\n' >&2
    done
    echo

    #Set Email and Password variables
    userEmail="${first}.${last}@sphero.com"
    passwd="${first}.${last}23!^"

    #Unhide account(s) from GAL
    echo "Enabling the sleeper (Show in GAL): $email"
    $gamDir update user $email gal on || exit $?
    echo

    #Add user(s) to Groups
    echo "Adding user to all@sphero.com and us@sphero.com..."
    $gamDir update group all@sphero.com add member $email
    $gamDir update group us@sphero.com add member $email

    #Set GSuite password for account(s)
    echo "Updating password for $email to standard format"
    $gamDir update user $email password $passwd
    echo
else
    printf "File supplied, adding users\n"
    while IFS= read -r user || [ -n "$user" ]; do 
        firstName=$(printf '%s\n' "$user" | cut -d ' ' -f 1)
        lastName=$(printf '%s\n' "$user" | cut -d ' ' -f 2)
        userEmail=$(printf '%s\n' "$user" | cut -d ' ' -f 3)
        passwd="${first}.${last}23!^"
    
        echo "Enabling the sleeper (Show in GAL): $userEmail"
        $gamDir update user $userEmail gal on || exit $?
        echo

        echo "Adding user to all@sphero.com and us@sphero.com..."
        $gamDir update group all@sphero.com add member $userEmail
        $gamDir update group us@sphero.com add member $userEmail

        echo "************"
    done < $1
fi
echo "Script has finished tasks...Exiting"
exit 0