#!/usr/bin/env python3
"""Run real-scene regressions sequentially with the same 120 Hz physics.
Usage: python3 tools/run_checks.py --caps 30 60 120
The default uses a visible game. --headless is a logic check, not visual proof.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--caps', nargs='+', type=int, default=[30, 60, 120])
    parser.add_argument('--suite', choices=['all', 'melee', 'bow', 'enemy', 'controller', 'crowd'], default='all')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--character', choices=['crow','capybara','red_panda'], default='crow')
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    reports = []
    failed = False
    for cap in args.caps:
        for suite, flag, prefix in [('melee', '--replay', 'runtime'), ('bow', '--bow-replay', 'bow'), ('enemy', '--enemy-replay', 'enemy'), ('controller', '--controller-replay', 'controller'), ('crowd', '--crowd-replay', 'crowd')]:
            if args.suite not in ['all', suite]:
                continue
            cmd = [args.godot, '--path', str(ROOT), 'res://scenes/levels/TestArena.tscn']
            if args.headless:
                cmd.append('--headless')
            cmd += ['--', flag, '--fps=' + str(cap), '--character=' + args.character]
            suffix = '' if args.character == 'crow' and suite != 'crowd' else '_' + args.character
            log = ROOT / 'captures' / f'{prefix}_run{suffix}_{cap}.log'
            report = ROOT / 'captures' / f'{prefix}_checks{suffix}_{cap}.json'
            if report.exists():
                report.unlink()
            print(f'Running {suite} at render cap {cap}', flush=True)
            try:
                with log.open('w') as handle:
                    process = subprocess.run(cmd, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, timeout=90)
                output = log.read_text()
                passed = process.returncode == 0 and report.exists() and 'SCRIPT ERROR:' not in output
                data = json.loads(report.read_text()) if report.exists() else {}
                passed = passed and data.get('failures') == 0
            except subprocess.TimeoutExpired:
                passed, data = False, {'error': '90 second timeout'}
            reports.append({'suite': suite, 'cap': cap, 'passed': passed, 'report': str(report.relative_to(ROOT)), 'observed_render_fps': data.get('observed_render_fps')})
            failed |= not passed
            print(f'{suite} {cap}: {"PASS" if passed else "FAIL"}', flush=True)
    summary = ROOT / 'captures' / ('suite_summary_' + args.character + '.json')
    previous = json.loads(summary.read_text()) if summary.exists() else {}
    by_key = {(r['suite'], r['cap']): r for r in previous.get('runs', [])} if previous.get('headless') == args.headless else {}
    by_key.update({(r['suite'], r['cap']): r for r in reports})
    summary.write_text(json.dumps({'headless': args.headless, 'runs': list(by_key.values())}, indent=2) + '\n')
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
