#!/usr/bin/env python3
"""submit.py: send Legal Light's current version to App Review.

  tools/asc/.venv/bin/python tools/asc/submit.py [expected-build]

Refuses unless the attached build matches expected-build (when given)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from asc import call

APP = '6832333458'
ver = call('GET', f'/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS')['data'][0]
vid = ver['id']
build = call('GET', f'/v1/appStoreVersions/{vid}/build')['data']
print('version', ver['attributes']['versionString'], ver['attributes'].get('appVersionState'),
      'build', build and build['attributes']['version'])
if len(sys.argv) > 1 and (not build or build['attributes']['version'] != sys.argv[1]):
    sys.exit(f'attached build is not {sys.argv[1]}; not submitting')

def must(label, r):
    if 'httpError' in r:
        sys.exit(f'{label}: {r["httpError"]} ' + json.dumps(r['body'].get('errors', r['body']))[:900])
    return r

sub = must('reviewSubmission', call('POST', '/v1/reviewSubmissions', {'data': {
    'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
    'relationships': {'app': {'data': {'type': 'apps', 'id': APP}}}}}))['data']
must('reviewSubmissionItem', call('POST', '/v1/reviewSubmissionItems', {'data': {
    'type': 'reviewSubmissionItems',
    'relationships': {'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sub['id']}},
                      'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}}))
r = must('submit', call('PATCH', f"/v1/reviewSubmissions/{sub['id']}", {'data': {
    'type': 'reviewSubmissions', 'id': sub['id'], 'attributes': {'submitted': True}}}))
print('submitted:', r['data']['attributes'].get('state'), sub['id'])
