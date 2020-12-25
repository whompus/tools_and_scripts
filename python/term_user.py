#!/usr/bin/env python3

"""
AX Term script
----------
The idea of this script is to be able to run from the command line instead of
wasting time logging into each service in a browser. Makes terminations more streamlined and standardized.

Could adapt this script once we get SSO working.

API keys must be set as environment variables with the appropriate names.

GAM must be installed; this is a hacky solution until we get proper API calls to Google configured.

TODO: Get lastpass working
"""

import requests
import json
import os
import sys
import subprocess
from argparse import ArgumentParser

JC_API_TOKEN = os.environ.get("JC_API_TOKEN")
JUMPCLOUD = 'https://console.jumpcloud.com/api'
JC_HEADERS = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'x-api-key': JC_API_TOKEN
}

LP_API_TOKEN = os.environ.get("LP_API_TOKEN")
LP_CID = os.environ.get("LP_CID")
LASTPASS = 'https://lastpass.com/enterpriseapi.php'
LASTPASS_HEADERS = {
    'Content-Type': 'application/json'
}


def check_jc_api_key():
    if not JC_API_TOKEN:
        print("No JC api key found, export as env variable and try the script again")
        sys.exit(1)

def check_lp_info():
    if not LP_API_TOKEN:
        print("No LP api key found, export as env variable and try the script again")
        sys.exit(1)
    
    if not LP_CID:
        print("No CID (Customer ID) found, export as env variable and try the script again")
        sys.exit(1)


def create_parser():
    parser = ArgumentParser()
    parser.add_argument('email', help="Email to search for and term user")
    return parser


# finds jc user and returns jc user ID for later use
def find_jc_user(user_email):
    try:
        r = requests.get(f'{JUMPCLOUD}/systemusers?filter=email:eq:{user_email}', headers=JC_HEADERS)
        user_data = json.loads(r.text)
        # print(json.dumps(user_data, indent=2))

        if not user_data['results']:
            print(f'No user found for {user_email}')
            sys.exit(1)
        
        else:
            jc_user_id = json.dumps(user_data['results'][0]['id']).strip('"')
            return jc_user_id
    
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong getting JC user: " + repr(err))
        sys.exit(1)


# checks if user is bound to machine, if they are, suspend, if not, delete
def term_jc_user(jc_user_id, user_email):
    try:
        r = requests.get(f'{JUMPCLOUD}/v2/users/{jc_user_id}/systems?type:system', headers=JC_HEADERS)
        system_association = json.loads(r.text)

        if not system_association:
            print(f'No systems found for {user_email}, deleting user...')

            try:
                r = requests.delete(f'{JUMPCLOUD}/systemusers/{jc_user_id}', headers=JC_HEADERS)

                # could do the status code checking better here maybe?
                if r.status_code == 200:
                    print(f'{user_email} deleted successfully')
                else:
                    print(f"Something went wrong deleting {user_email}")
                    print(r.status_code, r.content)

            except requests.exceptions.RequestException as err:
                print(r.status_code, r.content)
                print(f"Something went wrong deleting {user_email}: " + repr(err))
                sys.exit(1)
        else:
            print(f"Systems found for {user_email}, suspending...")
            # print(json.dumps(system_association, indent=2))

            payload = {
                "suspended": True
            }

            try:
                r = requests.put(f'{JUMPCLOUD}/systemusers/{jc_user_id}', headers=JC_HEADERS, json=payload)
                data = json.loads(r.content)
                suspended_status = json.dumps(data['suspended'])

                # could do the status code checking better here maybe?
                if r.status_code == 404:
                    print(r.content)
                elif suspended_status == "true":
                    print(f"{user_email} suspended")
                else:
                    print(f'Something went wrong suspending, check JC console for {user_email}')
                    print(r.status_code, r.content)

            except requests.exceptions.RequestException as err:
                print(r.status_code, r.content)
                print(f"Something went wrong suspending {user_email}: " + repr(err))
            

    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print(f"Something went wrong getting system associations for {user_email}: " + repr(err))
        sys.exit(1)


# suspends in Gsuite
def suspend_gsuite(user_email):
    print(f'Doing Google term tasks for {user_email}')
    
    manager = input("Please input the manager's email address for delegation: ")
    passwd = input("Please enter a password for the termed user: ")

    homedir = os.environ["HOME"]
    gam = f"{homedir}/bin/gam/gam"

    try:
        subprocess.run(f'{gam} info user {user_email}', shell=True)
    except subprocess.CalledProcessError as err:
        print('GAM might not be installed correctly or user not found: ' + err.output)
        sys.exit(1)

    try:
        subprocess.run(f"{gam} update org 'Termed Employees' add users {user_email}", shell=True)
    except subprocess.CalledProcessError as err:
        print('Something went wrong: ' + err.output)

    try:
        subprocess.run(f'{gam} user {user_email} update calendar {user_email} notification clear', shell=True)
    except subprocess.CalledProcessError as err:
        print('Something went wrong: ' + err.output)

    try:
        subprocess.run(f'{gam} user {user_email} forward off', shell=True)
    except subprocess.CalledProcessError as err:
        print('Something went wrong: ' + err.output)

    try:
        subprocess.run(f'{gam} user {user_email} delegate to {manager}', shell=True)
    except subprocess.CalledProcessError as err:
        print('Something went wrong: ' + err.output)

    try:
        print('Updating Google password...')
        subprocess.run(f'{gam} update user {user_email} password {passwd} changepassword off', shell=True)
    except subprocess.CalledProcessError as err:
        print('Something went wrong: ' + err.output)

    try:
        print('Removing from GAL...')
        # subprocess.run(f'{gam} update user {user_email} suspended on', shell=True)
        subprocess.run(f'{gam} update user {user_email} gal off', shell=True)
    except subprocess.CalledProcessError as err:
        print('Something went wrong: ' + err.output)

def term_lastpass_user(user_email):
    user_payload = {
            "cid": LP_CID,
            "provhash": LP_API_TOKEN,
            "cmd": "deluser",
            "data": [
                {
                    "username": user_email,
                    "deleteaction": 0
                }
            ]
        }
        
    try:
        print("Suspend user on Lastpass\n")
        r = requests.post(LASTPASS, headers=LASTPASS_HEADERS, json=user_payload)

        r.raise_for_status()
    
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print("Something went wrong with LP user creation: " + repr(err))
        sys.exit(1)

if __name__ == "__main__":
    args = create_parser().parse_args()
    user_email = args.email
    jc_user_id = find_jc_user(user_email)
    term_jc_user(jc_user_id, user_email)
    suspend_gsuite(user_email)
    term_lastpass_user(user_email)

