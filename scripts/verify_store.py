#!/usr/bin/env python3
"""Verify the uploaded build, not just a successful transport exit code.
Credentials are environment-only. Output contains IDs/state, never tokens.
"""
import json
import os
import sys
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen


_GOOGLE_RETRYABLE_STATUSES = {429, 500, 502, 503, 504}
_GOOGLE_RETRY_DELAYS = (2, 4, 8, 16, 30)


def _google_request(session, method, url, **kwargs):
    """Make a Play Developer API request, retrying only transient failures."""
    import requests

    response = None
    for attempt in range(len(_GOOGLE_RETRY_DELAYS) + 1):
        try:
            response = getattr(session, method)(url, **kwargs)
        except requests.RequestException as error:
            if attempt == len(_GOOGLE_RETRY_DELAYS):
                raise
            detail = type(error).__name__
        else:
            if response.status_code not in _GOOGLE_RETRYABLE_STATUSES:
                response.raise_for_status()
                return response
            if attempt == len(_GOOGLE_RETRY_DELAYS):
                response.raise_for_status()
            detail = f'HTTP {response.status_code}'

        delay = _GOOGLE_RETRY_DELAYS[attempt]
        print(
            json.dumps(
                {
                    'store': 'google',
                    'operation': method.upper(),
                    'transient_error': detail,
                    'attempt': attempt + 1,
                    'retry_in_seconds': delay,
                }
            ),
            flush=True,
        )
        time.sleep(delay)


def apple():
    import jwt
    deadline = time.monotonic() + 25 * 60
    bundle = 'ai.cortiq.cmfMobile'
    version = os.environ['BUILD_NUMBER'].removeprefix('v')
    key = open(os.path.expanduser(f"~/private_keys/AuthKey_{os.environ['ASC_KEY_ID']}.p8")).read()

    def get(path, params):
        now = int(time.time())
        token = jwt.encode({'iss': '69a6de97-8c6a-47e3-e053-5b8c7c11a4d1',
                            'iat': now, 'exp': now + 300, 'aud': 'appstoreconnect-v1'},
                           key, algorithm='ES256', headers={'kid': os.environ['ASC_KEY_ID']})
        req = Request('https://api.appstoreconnect.apple.com/v1/' + path + '?' + urlencode(params),
                      headers={'Authorization': 'Bearer ' + token})
        with urlopen(req, timeout=30) as response:
            return json.load(response)

    apps = get('apps', {'filter[bundleId]': bundle})['data']
    if len(apps) != 1:
        raise RuntimeError('App Store app not found unambiguously')
    while time.monotonic() < deadline:
        builds = get('builds', {'filter[app]': apps[0]['id'], 'filter[version]': version,
                                'include': 'preReleaseVersion', 'limit': '20'})
        for build in builds['data']:
            state = build['attributes']['processingState']
            print(json.dumps({'store': 'apple', 'build': version, 'id': build['id'], 'state': state}), flush=True)
            if state == 'VALID':
                return
            if state in ('FAILED', 'INVALID'):
                raise RuntimeError('Apple rejected build processing')
        time.sleep(30)
    raise TimeoutError('Upload sent, but Apple processing has not completed after 25 minutes')


def google():
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher'])
    session = AuthorizedSession(creds)
    root = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/ai.cortiq.cmf_mobile/edits'
    response = _google_request(session, 'post', root, json={}, timeout=30)
    edit = response.json()['id']
    try:
        response = _google_request(
            session,
            'get',
            f"{root}/{edit}/tracks/{os.environ.get('PLAY_TRACK', 'internal')}",
            timeout=30,
        )
        releases = response.json().get('releases', [])
        wanted = os.environ['BUILD_NUMBER']
        matches = [r for r in releases if wanted in r.get('versionCodes', [])]
        if not matches:
            raise RuntimeError('Uploaded version code not found in the requested Play track')
        print(json.dumps({'store':'google', 'build':wanted, 'track':os.environ.get('PLAY_TRACK','internal'),
                          'releases':matches}), flush=True)
    finally:
        # Discard the read-only verification edit. Never commit it.
        _google_request(session, 'delete', f'{root}/{edit}', timeout=30)
        session.close()


if __name__ == '__main__':
    {'apple': apple, 'google': google}[sys.argv[1]]()
