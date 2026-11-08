#!/usr/bin/env python3
"""shots.py: upload store screenshots for Legal Light's current version (en-US, 6.9").

  tools/asc/.venv/bin/python tools/asc/shots.py tools/shots/store/*.png   # replaces the set, in order
"""
import hashlib, json, os, sys, time, urllib.request
sys.path.insert(0, os.path.dirname(__file__))
from asc import call

APP = '6832333458'
TYPE = 'APP_IPHONE_67'   # the 6.7/6.9" slot (1290x2796 or 1320x2868)
files = sys.argv[1:]
vid = call('GET', f'/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS')['data'][0]['id']
loc = call('GET', f'/v1/appStoreVersions/{vid}/appStoreVersionLocalizations')['data'][0]['id']
sets = call('GET', f'/v1/appStoreVersionLocalizations/{loc}/appScreenshotSets')['data']
sset = next((s for s in sets if s['attributes']['screenshotDisplayType'] == TYPE), None)
if sset is None:
    r = call('POST', '/v1/appScreenshotSets', {'data': {'type': 'appScreenshotSets', 'attributes': {'screenshotDisplayType': TYPE},
             'relationships': {'appStoreVersionLocalization': {'data': {'type': 'appStoreVersionLocalizations', 'id': loc}}}}})
    if 'httpError' in r: sys.exit(json.dumps(r)[:600])
    sset = r['data']
sid = sset['id']
for old in call('GET', f'/v1/appScreenshotSets/{sid}/appScreenshots')['data']:
    call('DELETE', f"/v1/appScreenshots/{old['id']}")
ids = []
for f in files:
    data = open(f, 'rb').read()
    r = call('POST', '/v1/appScreenshots', {'data': {'type': 'appScreenshots',
             'attributes': {'fileName': os.path.basename(f), 'fileSize': len(data)},
             'relationships': {'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': sid}}}}})
    if 'httpError' in r: sys.exit(f + ': ' + json.dumps(r)[:600])
    shot = r['data']
    for op in shot['attributes']['uploadOperations']:
        req = urllib.request.Request(op['url'], method=op['method'], data=data[op['offset']:op['offset'] + op['length']],
                                     headers={h['name']: h['value'] for h in op['requestHeaders']})
        urllib.request.urlopen(req).read()
    r = call('PATCH', f"/v1/appScreenshots/{shot['id']}", {'data': {'type': 'appScreenshots', 'id': shot['id'],
             'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(data).hexdigest()}}})
    print(' ', os.path.basename(f), 'uploaded' if 'httpError' not in r else json.dumps(r)[:300])
    ids.append(shot['id'])
call('PATCH', f'/v1/appScreenshotSets/{sid}/relationships/appScreenshots',
     {'data': [{'type': 'appScreenshots', 'id': i} for i in ids]})
time.sleep(8)
for s in call('GET', f'/v1/appScreenshotSets/{sid}/appScreenshots')['data']:
    print(' ', s['attributes']['fileName'], s['attributes'].get('assetDeliveryState', {}).get('state'))
