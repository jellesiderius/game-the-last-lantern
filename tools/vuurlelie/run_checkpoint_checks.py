#!/usr/bin/env python3
"""Storage, native interaction lifecycle and fresh-process recovery. Never touches real saves."""
import subprocess, time, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
namespace='vuurlelie_check_'+str(int(time.time()))
failed=False
for name,flags,headless in [('storage',['--save-replay'],True),('lifecycle',['--checkpoint-replay'],False),('fresh_process',['--checkpoint-replay','--checkpoint-reload'],False)]:
 log=ROOT/'.dream-loop'/('vuurlelie-'+name+'.log')
 command=[GODOT,'--path',str(ROOT)]+(['--headless'] if headless else [])+['--',*flags,'--fps=60','--save-test-root='+namespace]
 with log.open('w') as output:
  try:result=subprocess.run(command,stdout=output,stderr=subprocess.STDOUT,timeout=170)
  except subprocess.TimeoutExpired:print(name,'TIMEOUT',flush=True);failed=True;continue
 report=ROOT/'captures/vuurlelie'/(('storage' if name=='storage' else name)+'_checks.json')
 data=json.loads(report.read_text()) if report.exists() else {}
 ok=result.returncode==0 and data.get('failures')==0 and 'SCRIPT ERROR:' not in log.read_text()
 print(name,'PASS' if ok else 'FAIL', 'checks='+str(len(data.get('checks',[]))),flush=True)
 failed |= not ok
raise SystemExit(int(failed))
