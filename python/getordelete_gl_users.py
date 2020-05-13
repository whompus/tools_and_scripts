#! /usr/bin/env python3

# GL_TOKEN is an environment variable local to the system you are running on

# TODO: Add functionality to test against staging or prod
# TODO: Add search in remove function


import requests
import os
import json

URL = "https://gitlab.orbxdev.com/api/v4/users/"
TOKEN = os.environ.get('GL_TOKEN')

answer = str(input('Would you like to GET, REMOVE, or SEARCH users? '))

def error(r):
    if r.status_code == 404:
        print(str(r.status_code) + ': user not found')
    else:
        print(str(r.status_code) + ': something else happened')

def search_user():
    user_name = input('Enter a username to search for: ')
    PARAMS = {'private_token':TOKEN, 'username':user_name}
    r = requests.get(url = URL, params = PARAMS)
    data = json.loads(r.text)
    if data:
        name = str(data[0]['name'])
        email = str(data[0]['email'])
        print('\nName: ' + name + '\n' + 'Email: ' + email)
    else:
        print('User not found')

def get_user():
    for ID in range(1, 50):
        PARAMS = {'private_token':TOKEN}
        try:
            r = requests.get(url = URL + str(ID), params = PARAMS)
            data = json.dumps(r.json(), indent=2, sort_keys=True)
            parse = json.loads(data)
            if r.status_code == 200:
                print('email: ' + str(parse["email"]) + ', id: ' + str(parse["id"]) + ' [status code: ' + str(r.status_code) + ']')
        except:
            error(r)

if answer == 'GET':
    get_user()

# elif answer == 'REMOVE':
#     # modify this so we can search for a user to remove
#     print('remove')

elif answer == 'SEARCH':
    search_user()
    
else:
    print('Not a valid answer')