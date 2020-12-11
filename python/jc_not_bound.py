#!/usr/bin/env python3

"""
This script will go through our JC instance and look for users without 
any system association (bound to their machine).
An API key for Jumpcloud must be set as an environment variable. Easiest to 
put this in your shell config (.bashrc, .zshrc, or similar).
"""

import requests
import os
import json
import sys

JC_API_TOKEN = os.environ.get("JC_API_TOKEN")
JUMPCLOUDV1='https://console.jumpcloud.com/api/systemusers'
JUMPCLOUDV2='https://console.jumpcloud.com/api/v2/users'
JC_HEADERS = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'x-api-key': JC_API_TOKEN
}


def get_emails_and_userids():

    # initialize user_dict object
    user_dict = {}

    try:
        # make request to get total records
        r = requests.get(f'{JUMPCLOUDV1}', headers=JC_HEADERS).json()

        total_records = int(r['totalCount'])
        
        # makes paginated API call to retrieve email and user ID, range is based on total_count
        for offset in range(0, total_records, 100):
            r = requests.get(f'{JUMPCLOUDV1}?skip={offset}', headers=JC_HEADERS).json()

            # parses email and userid from response into user_dict
            [user_dict.update({element['email']: element['id']}) for element in r['results']]
        
        return user_dict, total_records

    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong with contacting JC: " + repr(err))
        sys.exit(1)

    # convert list of dict to dict. Need to find a better way of doing this. did it! see list comprehension above
    # user_dict = {}

    # for element in user_list:
    #     for k,v in element.items():
    #         user_dict[k] = v


def get_user_system_association(user_dict):

    # initialize list to put user IDs in to loop through (optimized below using user_dict.values())
    # user_ids = []

    # initialize list to store not bound user IDs
    not_bound = []

    # adds values (User IDs) from user_dict into user_ids list (optimized below using user_dict.values())
    # for email, userid in user_dict.items():
    #     user_ids.append(userid)

    try:
        # loop through dict values (IDs) returned by get_user_ids and if empty result, add user ID to not_bound list
        for uid in user_dict.values():
            r = requests.get(f'{JUMPCLOUDV2}/{uid}/associations?targets=system', headers=JC_HEADERS).json()

            if not r:
                # print(f'{uid} does not have a system association')
                not_bound.append(uid)
        
        # match not bound with values from the not_bound list 
        for k, v in user_dict.items():
            if v in not_bound:
                print(k)

    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong: " + repr(err))
        sys.exit(1)

if __name__ == '__main__':
    user_dict, total_records = get_emails_and_userids()

    get_user_system_association(user_dict)


