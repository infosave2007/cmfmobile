#!/usr/bin/env python3
"""Bounded real-phone HTTP smoke/load test. No oracle calls; no tokens in reports.

Use PHONE_TOKEN + --host for a normal installation, or --adb-device for the
separate debuggable package. All inference happens on the phone, not the client.
"""
import argparse
import collections
import concurrent.futures
import http.client
import json
import math
import os
from pathlib import Path
import subprocess
import threading
import time
import xml.etree.ElementTree as ET

EXAMPLES = [
    ('banking77', 'I still have not received my new card', 'card_arrival'),
    ('clinc150', 'What is the weather forecast for tomorrow?', 'weather'),
    ('massive', 'Play some jazz music', 'play_music'),
]


def percentile(a, p):
    a = sorted(a)
    if not a:
        return None
    x = (len(a)-1)*p
    return a[math.floor(x)] + (a[math.ceil(x)]-a[math.floor(x)])*(x-math.floor(x))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host', required=True)
    p.add_argument('--port', type=int, default=8080)
    p.add_argument('--adb-device')
    p.add_argument('--mode', choices=['functional', 'load'], default='functional')
    p.add_argument('--requests', type=int, default=120)
    p.add_argument('--concurrency', type=int, default=1)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if not 1 <= a.requests <= 1000 or not 1 <= a.concurrency <= 16:
        p.error('bounded test: 1–1000 requests, 1–16 clients')
    token = os.environ.get('PHONE_TOKEN', '')
    if a.adb_device:
        raw = subprocess.check_output([
            'adb', '-s', a.adb_device, 'exec-out', 'run-as',
            'ai.cortiq.cmf_mobile.dev', 'cat', 'shared_prefs/FlutterSharedPreferences.xml'])
        token = next(n.text for n in ET.fromstring(raw)
                     if n.get('name') == 'flutter.serverToken')
    if not token:
        p.error('Set PHONE_TOKEN or use --adb-device for the debug app')
    local = threading.local()
    connections = []
    lock = threading.Lock()

    def request(method, path, value=None, auth='valid', raw=None):
        if not hasattr(local, 'connection'):
            local.connection = http.client.HTTPConnection(a.host, a.port, timeout=15)
            with lock:
                connections.append(local.connection)
        headers = {'Content-Type': 'application/json'}
        if auth != 'none':
            headers['Authorization'] = 'Bearer ' + (token if auth == 'valid' else 'invalid-test-token')
        body = raw if raw is not None else json.dumps(value) if value is not None else None
        start = time.perf_counter_ns()
        try:
            local.connection.request(method, path, body, headers)
            response = local.connection.getresponse()
            body = response.read()
            elapsed = (time.perf_counter_ns()-start)/1e6
            try:
                obj = json.loads(body)
            except (ValueError, UnicodeDecodeError):
                obj = {}
            return response.status, obj, elapsed, len(body)
        except (OSError, http.client.HTTPException) as e:
            local.connection.close()
            return 0, {'transport_error': type(e).__name__}, (time.perf_counter_ns()-start)/1e6, 0

    records = []
    result = {'transport': 'HTTP over Wi-Fi LAN', 'host': a.host, 'port': a.port,
              'mode': a.mode, 'oracle_calls': 0, 'timestamp_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    try:
        if a.mode == 'functional':
            def check(name, method, path, expected, value=None, auth='valid', raw=None, predicate=None):
                status, obj, ms, size = request(method, path, value, auth, raw)
                ok = status == expected and (predicate(obj) if predicate else True)
                records.append({'test': name, 'status': status, 'expected': expected,
                                'pass': ok, 'http_ms': ms, 'response_bytes': size})
                return obj
            check('health_public', 'GET', '/healthz', 200, auth='none')
            check('missing_token', 'GET', '/v1/models', 401, auth='none')
            check('wrong_token', 'POST', '/v1/decide', 401, {}, auth='wrong')
            check('models', 'GET', '/v1/models', 200)
            check('skills', 'GET', '/v1/skills', 200, predicate=lambda b: len(b['skills']) == 3)
            for skill, text, label in EXAMPLES:
                check(skill, 'POST', '/v1/decide', 200, {'skill': skill, 'text': text},
                      predicate=lambda b, label=label: b.get('choice') == label and b.get('accepted') and b.get('oracle') is False)
            check('abstention', 'POST', '/v1/decide', 200,
                  {'skill': 'banking77', 'text': 'Calculate the quantum entanglement of purple dinosaurs on Jupiter'},
                  predicate=lambda b: b.get('accepted') is False and b.get('choice') is None)
            rubric = check('rubric', 'GET', '/v1/skills/banking77', 200)['rubric']
            typed = {'model': 'cortiq/decision', 'state': EXAMPLES[0][1], 'questions': {'intent': {'type': 'choice',
                     'instructions': rubric['instructions'], 'criteria': rubric['criteria']}},
                     'cmf': {'skill': 'banking77', 'oracle': False}}
            for path in ['/v1/decisions', '/api/alpha/decisions']:
                check('typed_' + path, 'POST', path, 200, typed,
                      predicate=lambda b: b['answers']['intent']['choice'] == 'card_arrival')
            for name, value, expected in [
                ('empty_text', {'skill': 'banking77', 'text': ''}, 400),
                ('unknown_skill', {'skill': 'missing', 'text': 'test'}, 404),
                ('invalid_profile', {'skill': 'banking77', 'text': 'test', 'profile': 'missing'}, 400),
                ('unexpected_field', {'skill': 'banking77', 'text': 'test', 'oracle': True}, 400),
                ('too_long_text', {'skill': 'banking77', 'text': 'x'*32769}, 400),
            ]:
                check(name, 'POST', '/v1/decide', expected, value)
            check('invalid_json', 'POST', '/v1/decide', 400, raw='{bad')
            check('not_an_object', 'POST', '/v1/decide', 400, raw='[]')
            check('oracle_blocked', 'POST', '/v1/decisions', 400, {'cmf': {'oracle': True}})
            check('wrong_model_chat', 'POST', '/v1/chat/completions', 409, {})
            check('recovery_after_errors', 'POST', '/v1/decide', 200,
                  {'skill': EXAMPLES[0][0], 'text': EXAMPLES[0][1]}, predicate=lambda b: b.get('choice') == 'card_arrival')
            result['all_passed'] = all(r['pass'] for r in records)
        else:
            for i in range(15):
                skill, text, _ = EXAMPLES[i % 3]
                status, _, _, _ = request('POST', '/v1/decide', {'skill': skill, 'text': text})
                assert status == 200, 'warm-up failed'
            def run(i):
                skill, text, label = EXAMPLES[i % 3]
                status, obj, ms, size = request('POST', '/v1/decide', {'skill': skill, 'text': text})
                return {'i': i, 'skill': skill, 'status': status, 'http_ms': ms,
                        'native_ms': obj.get('timings_us', {}).get('total', 0)/1000,
                        'response_bytes': size, 'id': obj.get('id'),
                        'choice': obj.get('choice'), 'accepted': obj.get('accepted'),
                        'correct_smoke_label': obj.get('choice') == label and obj.get('skill') == skill,
                        'error_code': obj.get('error', {}).get('code')}
            start = time.perf_counter()
            with concurrent.futures.ThreadPoolExecutor(max_workers=a.concurrency) as pool:
                records = list(pool.map(run, range(a.requests)))
            seconds = time.perf_counter()-start
            ok = [r for r in records if r['status'] == 200]
            result.update({'n': a.requests, 'concurrency': a.concurrency, 'duration_s': seconds,
                           'successful_requests_per_s': len(ok)/seconds,
                           'statuses': dict(collections.Counter(r['status'] for r in records)),
                           'successful_smoke_labels_correct': all(r['correct_smoke_label'] for r in ok),
                           'response_ids_unique': len(set(r['id'] for r in ok)) == len(ok),
                           'http_ms_success': {p: percentile([r['http_ms'] for r in ok], q) for p, q in [('p50', .5), ('p95', .95), ('p99', .99)]},
                           'native_ms_success': {p: percentile([r['native_ms'] for r in ok], q) for p, q in [('p50', .5), ('p95', .95)]}})
        result['records'] = records
        a.out.parent.mkdir(parents=True, exist_ok=True)
        with a.out.open('x') as f:
            json.dump(result, f, indent=2)
        print(json.dumps({k: v for k, v in result.items() if k != 'records'}, indent=2))
        if a.mode == 'functional':
            print(json.dumps(records, indent=2))
        if a.mode == 'functional' and not result['all_passed']:
            raise SystemExit(1)
    finally:
        for c in connections:
            c.close()


if __name__ == '__main__':
    main()
