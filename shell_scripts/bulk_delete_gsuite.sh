#!/bin/bash

# Author Mat L
# this script takes a list of users in txt format as a positional parameter
# usage: bulk_delete_gsuite.sh path/to/list.txt

GAM="$HOME/bin/gam/gam"

if [[ ! -d /Users/$USER/bin/gam ]]
then
    echo "GAM is not installed in correct directory, please install in $GAM, exiting"
    exit 1
fi

if [[ -z $1 ]]; then
    echo "No file supplied."
    echo "Usage: $0 path/to/list.txt"
    echo "Exiting!"
    exit 2
fi

while IFS= read -r USERNAME || [ -n "${USERNAME}" ]; do
    
    ${GAM} info user "${USERNAME}" >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        echo "${USERNAME} does not exist in Google Suite."
    else 
        ${GAM} delete user "${USERNAME}"
    fi

done < "$1"

exit 0
