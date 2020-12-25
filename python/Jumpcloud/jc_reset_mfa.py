#!/usr/bin/env python3
"""
This script will search for a given email and reset TOTP MFA in Jumpcloud.

An API key for Jumpcloud must be set as an environment variable. Easiest to 
put this in your shell config (.bashrc, .zshrc, or similar).
"""

import requests
import json
import os
import sys
import datetime
from argparse import ArgumentParser


JC_API_TOKEN = os.environ.get("JC_API_TOKEN")
JUMPCLOUD = 'https://console.jumpcloud.com/api'
JC_HEADERS = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'x-api-key': JC_API_TOKEN
}

def check_jc_api_key():
    if not JC_API_TOKEN:
        print("No JC api key found, export as env variable and try the script again")
        sys.exit(1)

# creates parser
def create_parser():
    parser = ArgumentParser()
    parser.add_argument('email', help="email to search for and return user data")
    return parser

def find_user(email):
    try:
        r = requests.get(f'{JUMPCLOUD}/systemusers?filter=email:eq:{email}', headers=JC_HEADERS)

        user_data = json.loads(r.text)

        if not user_data['results']:
            print(f'No user found for {email}')
            sys.exit(1)
            
        else:
            jc_user_id = user_data['results'][0]['id']

            return jc_user_id
            
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print('Something went wrong with finding the JC user: ' + repr(err))
        sys.exit(1)

def reset_mfa(jc_user_id):
    mfa_date = str(datetime.date.today() + datetime.timedelta(days=7))

    reset_mfa = {
        "mfa": {"exclusion": True, "exclusionUntil": mfa_date}
    }

    set_mfa = {
        "mfa": {"exclusion": True, "exclusionUntil": mfa_date, "configured": True}
    }

    try:
        print('Attempting to reset MFA... ')
        # expires TOTP
        r = requests.post(f'{JUMPCLOUD}/systemusers/{jc_user_id}/resetmfa', headers=JC_HEADERS, json=reset_mfa)
        # print(r.status_code, r.content)
        
        # sets expiration and enables TOTP
        r = requests.put(f'{JUMPCLOUD}/systemusers/{jc_user_id}', headers=JC_HEADERS, json=set_mfa)
        # # print(r.status_code)

        print(f'Successfully reset MFA for {email}')
        
    except requests.exceptions.RequestException as err:
        print(r.status_code, r.content)
        print('Something went wrong with resetting user\'s MFA: ' + repr(err))
        sys.exit(1)

if __name__ == "__main__":
    check_jc_api_key()
    
    args = create_parser().parse_args()
    
    email = args.email

    jc_user_id = find_user(email)

    reset_mfa(jc_user_id)