#!/usr/bin/env python3
# https://github.com/ErikKalkoken/slackApiDoc
# TODO: add logic to see whether user wants to create or destroy account?

import json, os, requests, sys, traceback
from slackclient import SlackClient

SLACK_API_TOKEN = os.environ.get("SLACK_API_TOKEN")
slack_client = SlackClient(SLACK_API_TOKEN)

def slack_list_users():
    users_call = slack_client.api_call("users.list")
    if users_call.get('ok'):
        return users_call["members"]
    return None

def slack_make_inactive(token, uid):
    try:
        requests.post(
            'https://sphero.slack.com/api/users.admin.setInactive',
            params={'token': token, 'user': uid},
        )
    except Exception:
        traceback.print_exc()

def slack_invite_user(token, email):
    try:
        requests.post(
            'https://sphero.slack.com/api/users.admin.invite',
            params={'token': token, 'email': email},
        )
    except Exception:
        traceback.print_exc()

def slack_user_deprovision():
    USER_DEPRO = slack_list_users()
    if USER_DEPRO: #if we get soemthing back, continue with parsing data from api call above
        DEPRO_EMAIL = input('Enter email to look for and deactivate: ') #grabs input from user
        for slack_user in USER_DEPRO: #loops through the returned objects from the api call
            if slack_user.get('profile').get('email') == DEPRO_EMAIL: #loops until it finds provided email
                print("Slack user deleted? " + str(slack_user.get('deleted')))
                UID = str(slack_user.get('id')) #extracts userID and stores as variable
                prompt = None
                while prompt not in ("yes", "no"): #confirms if user should be deprovisioned
                    prompt = str(input('Are you sure you want to deactivate ' + DEPRO_EMAIL + '? ')).lower()
                    if prompt == "yes":
                        try:
                            print('Deactivating user account...')
                            slack_make_inactive(SLACK_API_TOKEN, UID) #calls depro function
                        except Exception:
                            traceback.print_exc()
                    elif prompt == "no":
                        print('Exiting.')
                        exit()
                    else:
                        print("Please answer yes or no")
    else:
        print("Unable to grab Slack things. Your API key might be configured incorrectly.") #need to add more here for specific errors

if __name__ == '__main__':
    init = input('depro or add slack user? ')
    if init == "depro":
        slack_user_deprovision()
    elif init == "add":
        NEW_HIRE_EMAIL = str(input('Email for new hire: '))
        slack_invite_user(SLACK_API_TOKEN, NEW_HIRE_EMAIL)
    else:
        print("Invalid answer")
        exit()