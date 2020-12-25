#!/usr/bin/env python3

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

def create_parser():
    parser = ArgumentParser()
    parser.add_argument('email', help="email to search for and return user data")
    return parser

# find user id from email
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


#add them to picker
def group_selection(groups_list):    
    title = 'Please choose the groups that the user should be added to, all users are added to WiFi and Prod VPN by default (SPACE to mark, ENTER to continue): '
    options = groups_list
    selected = dict(pick(options, title, multiselect=True, min_selection_count=0))
    selected_group_names = list(selected.keys())

    return selected_group_names # returns list to work with


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


def match_groups(name_and_id, selected_group_names):
    group_ids = []
    
    print(f'\nUser will be added to: {selected_group_names}\n')
    
    for group in selected_group_names:
        if group in name_and_id:
            group_ids.append(name_and_id[group])
            
    return group_ids


def get_jc_user_id(email):
    try:
        r = requests.get(f'{JUMPCLOUD}/systemusers?filter=email:eq:{email}', headers=JC_HEADERS)
        # load user data
        user_json = json.loads(r.text)

        #extract user id for group additions
        jc_user_id = (json.dumps(user_json['results'][0]['id']).strip('"'))

    except requests.exceptions.RequestException as err:
        print("Something went wrong while contacting JC to get user info: " + repr(err))
        sys.exit(1)

    return jc_user_id


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

    group_ids = match_groups(name_and_id, selected_group_names)

    jc_user_id = get_jc_user_id(email)

    add_user_to_groups(group_ids, jc_user_id)

