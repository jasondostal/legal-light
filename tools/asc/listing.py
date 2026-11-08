#!/usr/bin/env python3
"""listing.py: push docs/store.md into App Store Connect for Legal Light (idempotent).

  tools/asc/.venv/bin/python tools/asc/listing.py [--dry]

Sets: subtitle + privacy URL (appInfo localization), categories, age rating (all none),
description / keywords / promo / URLs (version localization), copyright, review detail.
Not settable here: App Privacy (web UI), and the build attach / submission (separate steps)."""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from asc import call

APP = '6832333458'
DRY = '--dry' in sys.argv
md = open(os.path.join(os.path.dirname(__file__), '..', '..', 'docs', 'store.md')).read()

def section(title):
    m = re.search(r'^## ' + re.escape(title) + r'[^\n]*\n\n(.*?)(?=\n## |\Z)', md, re.S | re.M)
    return m.group(1).strip()
def tick(text):
    return re.search(r'`([^`]+)`', text).group(1)

name_sub = section('Name and subtitle')
subtitle = tick(name_sub.split('Subtitle:')[1])
promo = section('Promotional text')
desc = section('Description')
keywords = tick(section('Keywords'))
notes = section('Review notes')
urls = section('URLs')
support = re.search(r'Support: (\S+)', urls).group(1)
marketing = re.search(r'Marketing: (\S+)', urls).group(1)
privacy = re.search(r'Privacy policy: (\S+)', urls).group(1)

for k, v, n in [('subtitle', subtitle, 30), ('promo', promo, 170), ('description', desc, 4000), ('keywords', keywords, 100)]:
    print(f'{k}: {len(v)}/{n}' + ('  TOO LONG' if len(v) > n else ''))
    assert len(v) <= n
if DRY: sys.exit()

def ok(label, r):
    if 'httpError' in r:
        print('  !', label, r['httpError'], json.dumps(r['body'].get('errors', r['body']))[:400])
    else:
        print('  ok', label)

def patch(path, typ, id_, attrs=None, rels=None):
    data = {'type': typ, 'id': id_}
    if attrs: data['attributes'] = attrs
    if rels: data['relationships'] = rels
    return call('PATCH', path, {'data': data})

info = call('GET', f'/v1/apps/{APP}/appInfos')['data'][0]['id']
loc = call('GET', f'/v1/appInfos/{info}/appInfoLocalizations')['data'][0]['id']
ok('appInfo localization', patch(f'/v1/appInfoLocalizations/{loc}', 'appInfoLocalizations', loc,
                                 {'subtitle': subtitle, 'privacyPolicyUrl': privacy}))
ok('categories', patch(f'/v1/appInfos/{info}', 'appInfos', info, rels={
    'primaryCategory': {'data': {'type': 'appCategories', 'id': 'SPORTS'}},
    'secondaryCategory': {'data': {'type': 'appCategories', 'id': 'UTILITIES'}}}))

age = call('GET', f'/v1/appInfos/{info}/ageRatingDeclaration')['data']
attrs = {}
for k, v in age['attributes'].items():
    if k in ('ageRatingOverride', 'ageRatingOverrideV2', 'koreaAgeRatingOverride', 'gracRatingClassificationNumber',
             'developerAgeRatingInfoUrl', 'kidsAgeBand'):
        continue
    attrs[k] = v
BOOLS = {'advertising', 'ageAssurance', 'gambling', 'healthOrWellnessTopics', 'lootBox', 'messagingAndChat',
         'parentalControls', 'socialMedia', 'unrestrictedWebAccess', 'userGeneratedContent', 'socialMediaAgeRestricted'}
attrs = {k: (False if k in BOOLS else 'NONE') for k in attrs}
r = patch(f'/v1/ageRatingDeclarations/{age["id"]}', 'ageRatingDeclarations', age['id'], attrs)
ok('age rating', r)

ver = call('GET', f'/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS')['data'][0]
vid = ver['id']
ok('version copyright', patch(f'/v1/appStoreVersions/{vid}', 'appStoreVersions', vid,
                              {'copyright': '2026 Jason Dostal', 'releaseType': 'AFTER_APPROVAL'}))
vloc = call('GET', f'/v1/appStoreVersions/{vid}/appStoreVersionLocalizations')['data'][0]['id']
ok('version localization', patch(f'/v1/appStoreVersionLocalizations/{vloc}', 'appStoreVersionLocalizations', vloc,
                                 {'description': desc, 'keywords': keywords, 'promotionalText': promo,
                                  'supportUrl': support, 'marketingUrl': marketing}))

contact = {'contactFirstName': 'Jason', 'contactLastName': 'Dostal', 'contactPhone': '7152521170',
           'contactEmail': 'jdostal@witekdivers.com', 'demoAccountRequired': False, 'notes': notes}
rd = call('GET', f'/v1/appStoreVersions/{vid}/appStoreReviewDetail').get('data')
if rd:
    ok('review detail', patch(f'/v1/appStoreReviewDetails/{rd["id"]}', 'appStoreReviewDetails', rd['id'], contact))
else:
    ok('review detail (new)', call('POST', '/v1/appStoreReviewDetails', {'data': {
        'type': 'appStoreReviewDetails', 'attributes': contact,
        'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}}))
