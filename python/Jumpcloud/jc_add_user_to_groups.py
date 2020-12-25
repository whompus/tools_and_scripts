#!/usr/bin/env python3

"""
This script will add a user to the groups of your choosing. It requires 
a Jumpcloud API key to be stored as an env var. When you run the 
script, pass an email address as an argument. The script will search 
for the user in your Jumpcloud directory, displays a selectable list
of groups for you to choose from, and adds the given user to those groups.
"""

import requests
import os
import sys
import json
import sys
from pick import pick
from operator import itemgetter

from argparse import ArgumentParser

JC_API_TOKEN = os.environ.get("JC_API_TOKEN")
JUMPCLOUD = 'https://console.jumpcloud.com/api'
JC_HEADERS = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'x-api-key': JC_API_TOKEN
}

# creates parser
def create_parser():
    parser = ArgumentParser()
    parser.add_argument('email', help="email to search for and return user data")
    return parser

# find user id from email supplied as argument
# TODO: extract userId from this to get rid of other function
def find_user(email):
    try:
        r = requests.get(f'{JUMPCLOUD}/systemusers?filter=email:eq:{email}', headers=JC_HEADERS)

        user_data = json.loads(r.text)

        if not user_data['results']:
            print(f'No user found for {email}')
            sys.exit(1)
            
        else:
            jc_user_id = user_data['results'][0]['id']
            # print(f'{email}\'s user id is {jc_user_id}')

            return jc_user_id
            
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print('Something went wrong with finding the JC user: ' + repr(err))
        sys.exit(1)


# get groups and store as list
def get_groups():
    groups_list = []

    payload = {
        "limit": "100"
    }

    try:
        r = requests.get(f'{JUMPCLOUD}/v2/usergroups', headers=JC_HEADERS, params=payload)

        groups_json = json.loads(r.text)

        for group in groups_json:
            groups_list.append(group['name'])
        
        return groups_list # returns LIST
    
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong getting groups: " + repr(err))
        sys.exit(1)


#add them to picker to be a selectable list
def group_selection(groups_list):    
    title = 'Please choose the groups that the user should be added to, all users are added to WiFi and Prod VPN by default (SPACE to mark, ENTER to continue): '
    options = groups_list
    selected = dict(pick(options, title, multiselect=True, min_selection_count=0))
    selected_group_names = list(selected.keys())

    return selected_group_names # returns list to work with

# gets group name and id as {key: value} pair
def extract_group_name_and_id():
    payload = {
        "limit": "100"
    }

    try:
        r = requests.get(f'{JUMPCLOUD}/v2/usergroups', headers=JC_HEADERS, params=payload)

        groups_listing = r.json()
        name_and_id = list(map(itemgetter('name', 'id'), groups_listing))
    
        return dict(name_and_id)
    
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong while contacting JC to get group name and ID: " + repr(err))
        sys.exit(1)

# collect list of groups the user should be added to
def group_list(name_and_id, selected_group_names):
    group_ids = []
    
    print(f'\nUser will be added to: {selected_group_names}\n')
    
    for group in selected_group_names:
        if group in name_and_id:
            group_ids.append(name_and_id[group])
            
    return group_ids

# adds user to selected groups
def add_user_to_groups(group_ids, jc_user_id):    
    payload = {
        "op": "add",
        "type": "user",
        "id": jc_user_id
    }

    print('Adding user to JC groups...')

    try:
        for i in group_ids:
            r = requests.post(f'{JUMPCLOUD}/v2/usergroups/{i}/members', headers=JC_HEADERS, json=payload)

    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong while contacting JC to get group name and ID: " + repr(err))
        sys.exit(1)


if __name__ == "__main__":
    args = create_parser().parse_args()
    email = args.email

    # email = input("Enter email to add to JC groups: ")

    jc_user_id = find_user(email)
    
    groups_list = get_groups()

    selected_group_names = group_selection(groups_list)

    name_and_id = extract_group_name_and_id()

    group_ids = group_list(name_and_id, selected_group_names)

    add_user_to_groups(group_ids, jc_user_id)

