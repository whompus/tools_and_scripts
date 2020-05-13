#!/usr/bin/env python3

import json, os, requests, sys, traceback
import jcapiv1
from jcapiv1.rest import ApiException

JC_API_TOKEN = os.environ.get("JC_API_TOKEN")
CONTENT_TYPE = "application/json"
ACCEPT = "application/json"
JC_EMAIL = "mat@sphero.com"

# def jc_find_user_id(JC_EMAIL):
#     skip_block = 0
#     results == get_results_from_api(skip_block)

def get_results_from_api(CONTENT_TYPE, ACCEPT, skip_block):
    try:
        requests.get(
            'https://console.jumpcloud.com/api/systemusers',
            params={'x-api-key': JC_API_TOKEN, 'Content-Type': CONTENT_TYPE, 'Accept': ACCEPT, 'skip': skip_block},
        )
    except Exception:
        print('Error making API request')
        traceback.print_exc()

def process_results(results, skip_block):
    if results:
        for jc_u in results:
            if jc_u.email == JC_EMAIL:
                JCID = str(jc_u._id)
                print("JC UID: " + JCID)
                return JCID
            else:
                skip_block += 100
                get_results_from_api(skip_block)

skip_block = 0
results = get_results_from_api(CONTENT_TYPE, ACCEPT, skip_block)

if __name__ == '__main__':
    process_results(results, skip_block)
