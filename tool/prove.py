#!/usr/bin/env python3
"""Revert-prove regression tests: a test never seen failing is not trusted.

    python3 tool/prove.py cases.json      (from the repo or worktree root)

cases.json is a list of
    {"name", "test": <test file>, "plain": <--plain-name filter>,
     "edits": [{"file", "old", "new"}], "env"?: {...}, "timeout"?: seconds}
Each case undoes ONE fix (every `old` must occur exactly once, and differ
from its `new`), runs only its test, and must see it fail for the stated
reason. The same test must first pass on the untouched tree — a test that
already fails, or fails only under the case's `env`, proves nothing. A
revert that does not compile, or a filter that matches no test, proves
nothing either. A hang counts as the test failing, and kills only its own
run. Files are always restored. Exits 1 unless every case is proven.
"""
import json
import os
import re
import signal
import subprocess
import sys


def run(test, plain, env, timeout):
    """One `flutter test` in its own process group; (output, hung)."""
    p = subprocess.Popen(
        ['flutter', 'test', test, '--plain-name', plain, '--timeout', '90s'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env,
        start_new_session=True)
    try:
        out, _ = p.communicate(timeout=timeout)
        return out, False
    except subprocess.TimeoutExpired:
        # Only this run: another flutter_tester on the machine — a parallel
        # proof, the IDE, a reviewer — is none of its business.
        os.killpg(p.pid, signal.SIGKILL)
        p.communicate()
        return '', True


def verdict_of(out):
    broken = bool(re.search(r'Compilation failed|Failed to load|: Error: ', out))
    no_test = 'No tests ran' in out or 'No tests match' in out
    failed = 'Some tests failed' in out
    return broken, no_test, failed


cases = json.load(open(sys.argv[1]))
ok = True
baselines = {}
for c in cases:
    edits = c.get('edits') or [{'file': c['file'], 'old': c['old'], 'new': c['new']}]
    env = dict(os.environ, **c.get('env', {}))
    timeout = c.get('timeout', 240)

    # The test must pass before the revert, under the same environment.
    key = (c['test'], c['plain'], json.dumps(c.get('env', {}), sort_keys=True))
    if key not in baselines:
        out, hung = run(c['test'], c['plain'], env, timeout)
        broken, no_test, failed = verdict_of(out)
        baselines[key] = not (hung or broken or no_test or failed)
    if not baselines[key]:
        print(f"### {c['name']}: !!! FAILS BEFORE THE REVERT — proves nothing",
              flush=True)
        ok = False
        continue

    origs = {}
    for e in edits:
        origs.setdefault(e['file'], open(e['file']).read())
    try:
        cur = dict(origs)
        for e in edits:
            assert e['old'] != e['new'], (c['name'], 'an edit that changes nothing')
            assert cur[e['file']].count(e['old']) == 1, (
                c['name'], e['file'], 'anchor count', cur[e['file']].count(e['old']))
            cur[e['file']] = cur[e['file']].replace(e['old'], e['new'])
        for f, t in cur.items():
            open(f, 'w').write(t)
        out, hung = run(c['test'], c['plain'], env, timeout)
        if hung:
            out = 'Some tests failed\nExpected: to finish\nActual: HUNG (a hang is this test failing)'
        broken, no_test, failed = verdict_of(out)
        why = [l.strip() for l in out.splitlines() if re.search(r'Expected:|Actual:', l)][:2]
        if broken:
            why = [l.strip() for l in out.splitlines() if ': Error: ' in l][:2]
        verdict = ('!!! REVERT DOES NOT COMPILE — proves nothing' if broken
                   else '!!! NO TEST MATCHED — proves nothing' if no_test
                   else 'FAILS as it should' if failed else '!!! STILL PASSES')
        print(f"### {c['name']}: {verdict}", flush=True)
        for w in why:
            print('    ', w[:150], flush=True)
        ok = ok and failed and not broken and not no_test
    finally:
        for f, t in origs.items():
            open(f, 'w').write(t)
            assert open(f).read() == t, 'restore failed: ' + f
print('ALL PROVEN' if ok else 'SOME TEST DID NOT CATCH ITS BUG')
sys.exit(0 if ok else 1)
