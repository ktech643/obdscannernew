#!/usr/bin/env python3
"""Revert-prove regression tests: a test never seen failing is not trusted.

    python3 tool/prove.py cases.json      (from the repo or worktree root)

cases.json is a list of
    {"name", "test": <test file>, "plain": <--plain-name filter>,
     "edits": [{"file", "old", "new"}], "env"?: {...}, "timeout"?: seconds}
Each case undoes ONE fix (every `old` must occur exactly once), runs only
its test, and must see it fail for the stated reason. A revert that does
not compile, or a filter that matches no test, proves nothing and fails
the run; a hang counts as the test failing. Files are always restored.
"""
import subprocess, sys, json, re, os
cases = json.load(open(sys.argv[1]))
ok = True
for c in cases:
    edits = c.get('edits') or [{'file': c['file'], 'old': c['old'], 'new': c['new']}]
    origs = {}
    for e in edits:
        origs.setdefault(e['file'], open(e['file']).read())
    try:
        cur = dict(origs)
        for e in edits:
            assert cur[e['file']].count(e['old']) == 1, (c['name'], e['file'], 'anchor count', cur[e['file']].count(e['old']))
            cur[e['file']] = cur[e['file']].replace(e['old'], e['new'])
        for f, t in cur.items():
            open(f, 'w').write(t)
        env = dict(os.environ, **c.get('env', {}))
        try:
            r = subprocess.run(['flutter', 'test', c['test'], '--plain-name', c['plain'], '--timeout', '90s'],
                               capture_output=True, text=True, env=env, timeout=c.get('timeout', 240))
            out = r.stdout + r.stderr
        except subprocess.TimeoutExpired:
            subprocess.run(['pkill', '-f', 'flutter_tester'])
            out = 'Some tests failed\nExpected: to finish\nActual: HUNG (a hang is this test failing)'
        failed = 'Some tests failed' in out
        # A revert that does not compile "fails" every test and proves nothing.
        broken = bool(re.search(r'Compilation failed|Failed to load|: Error: ', out))
        no_test = 'No tests ran' in out or 'No tests match' in out
        why = [l.strip() for l in out.splitlines() if re.search(r'Expected:|Actual:', l)][:2]
        if broken:
            why = [l.strip() for l in out.splitlines() if ': Error: ' in l][:2]
        verdict = ('!!! REVERT DOES NOT COMPILE — proves nothing' if broken
                   else '!!! NO TEST MATCHED — proves nothing' if no_test
                   else 'FAILS as it should' if failed else '!!! STILL PASSES')
        print(f"### {c['name']}: {verdict}", flush=True)
        for w in why: print('    ', w[:150], flush=True)
        ok = ok and failed and not broken and not no_test
    finally:
        for f, t in origs.items():
            open(f, 'w').write(t)
            assert open(f).read() == t, 'restore failed: ' + f
print('ALL PROVEN' if ok else 'SOME TEST DID NOT CATCH ITS BUG')
