#!/usr/bin/env python3
"""Six real-device translation smoke cases through the unchanged chat API.

Not a translation-quality benchmark. No reference tuning, no cloud calls.
Token is read only from the separate debug app, never written to the report.
"""
import argparse
import http.client
import json
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET

CASES = [
    ('ru-en', 'English', 'Посылка прибудет завтра после 15:00. Пожалуйста, позвоните перед доставкой.'),
    ('en-ru', 'Russian', 'Your appointment is on 12 October at 14:30. Please bring your passport.'),
    ('zh-en', 'English', '请在周五之前发送发票，并保留订单编号 AB-123。'),
    ('de-ru', 'Russian', 'Die Lieferung verspätet sich um zwei Tage. Die Sendungsnummer bleibt unverändert.'),
    ('tr-ru', 'Russian', "Toplantı yarın saat 10.00'da başlayacak."),
    ('json-en-de', 'German', '{"message":"Hello, {user_name}. Your order {order_id} is ready.","count":3}'),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host', required=True)
    p.add_argument('--device', required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--only', choices=[c[0] for c in CASES])
    a = p.parse_args()
    root = ET.fromstring(subprocess.check_output([
        'adb', '-s', a.device, 'exec-out', 'run-as', 'ai.cortiq.cmf_mobile.dev',
        'cat', 'shared_prefs/FlutterSharedPreferences.xml']))
    token = next(n.text for n in root if n.get('name') == 'flutter.serverToken')
    headers = {'Authorization': 'Bearer '+token, 'Content-Type': 'application/json'}
    c = http.client.HTTPConnection(a.host, 8080, timeout=180)
    c.request('GET', '/v1/models', headers=headers)
    r = c.getresponse()
    models = json.loads(r.read())
    model = models['data'][0]['id']
    assert 'hy-mt2-1.8b-q1t' in model, models
    result = {'model': model, 'file_bytes': 694894587,
              'file_sha256': 'aeb52bf287fb52f6e67f452dd72302087420f3b9e2081ed0cb86fd65cf289424',
              'runtime': '0.8.0', 'app_code_commit': 'c415256', 'app_version': '1.3.0-dev+47',
              'backend': 'CPU (GPU setting disabled)', 'transport': 'Wi-Fi HTTP SSE',
              'sampling': {'temperature': 0, 'top_p': 1, 'max_tokens': 192},
              'scope': 'six short smoke cases, no quality benchmark; first request is cold', 'cases': []}
    a.out.parent.mkdir(parents=True, exist_ok=True)
    with a.out.open('x') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    try:
        for name, language, source in CASES:
            if a.only and a.only != name:
                continue
            prompt = (f'Translate the following text into {language}. Note that you should only output '
                      'the translated result without any additional explanation:')
            if name.startswith('json'):
                # Keep instructions outside the source section: this small
                # translation specialist can translate instructions placed
                # after the source delimiter instead of the intended data.
                prompt = (f'### Translation job\nConvert user-visible JSON values to {language}.\n'
                          '### Constraints\nKeep all field names, braces, indentation, numeric values '
                          'and variable placeholders unchanged. Do not translate or explain these rules. '
                          'Return only valid JSON.\n### JSON input\n'+source)
            else:
                prompt += '\n\n'+source
            body = {'model': model, 'messages': [{'role': 'user', 'content': prompt}],
                    'temperature': 0, 'top_p': 1, 'max_tokens': 192, 'stream': True}
            start = time.perf_counter()
            c.request('POST', '/v1/chat/completions', json.dumps(body, ensure_ascii=False).encode(), headers)
            r = c.getresponse()
            assert r.status == 200, (r.status, r.read().decode()[:300])
            content = []
            ttft = last = None
            finish = None
            usage = None
            done = False
            while line := r.readline():
                if not line.startswith(b'data: '):
                    continue
                data = line[6:].strip()
                if data == b'[DONE]':
                    done = True
                    break
                obj = json.loads(data)
                choice = obj['choices'][0]
                text = choice.get('delta', {}).get('content', '')
                if text:
                    now = time.perf_counter()
                    if ttft is None:
                        ttft = now-start
                    last = now-start
                    content.append(text)
                if choice.get('finish_reason'):
                    finish = choice['finish_reason']
                usage = obj.get('usage', usage)
            # Drain the HTTP response, preserving keep-alive framing.
            r.read()
            elapsed = time.perf_counter()-start
            output = ''.join(content)
            row = {'case': name, 'source': source, 'prompt': prompt, 'translation': output,
                   'http_status': r.status, 'sse_done': done, 'finish_reason': finish,
                   'ttft_s': ttft, 'total_s': elapsed, 'last_token_s': last, 'usage': usage,
                   'nonempty': bool(output.strip())}
            if usage:
                row['output_tokens_per_total_second'] = usage['completion_tokens']/elapsed
            row['sse_content_delivery_span_s'] = None if ttft is None or last is None else last-ttft
            row['decode_rate_measured'] = False
            # Network deltas may be coalesced. Arrival gaps do not measure
            # native decode throughput; never turn a burst into "50k tok/s".
            if name.startswith('json'):
                try:
                    obj = json.loads(output)
                    row['structure_preserved'] = (set(obj) == {'message', 'count'} and obj['count'] == 3
                        and all(s in obj['message'] for s in ['{user_name}', '{order_id}']))
                except (ValueError, TypeError, KeyError):
                    row['structure_preserved'] = False
            result['cases'].append(row)
            a.out.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
            print(json.dumps(row, ensure_ascii=False), flush=True)
    finally:
        c.close()


if __name__ == '__main__':
    main()
