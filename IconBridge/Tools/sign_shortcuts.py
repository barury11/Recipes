#!/usr/bin/env python3
"""Apple's signer only. Never present unsigned sources as installable shortcuts."""
import pathlib,subprocess,sys,json,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def sign():
    subprocess.run([sys.executable,str(ROOT/'Tools/generate_shortcuts.py')],check=True)
    dest=ROOT/'Resources/Launchers';dest.mkdir(parents=True,exist_ok=True)
    report=[]
    for source in sorted((ROOT/'Shortcuts/Unsigned').glob('*.shortcut')):
        output=dest/source.name
        result=None
        for attempt in range(2):
            try:
                result=subprocess.run(['/usr/bin/shortcuts','sign','--mode','anyone','--input',str(source),'--output',str(output)],capture_output=True,text=True,timeout=55)
            except subprocess.TimeoutExpired:
                result=None
            if result is not None and result.returncode==0 and output.is_file() and output.stat().st_size>0:break
            if attempt==0:time.sleep(2)
        if result is None or result.returncode!=0 or not output.is_file() or output.stat().st_size==0:
            raise SystemExit(f'Apple signing failed for {source.name}: '+('timeout' if result is None else result.stderr+result.stdout))
        if output.read_bytes().startswith((b'bplist00',b'<?xml')):
            raise SystemExit(f'Unsigned output rejected: {output.name}')
        report.append({'file':output.name,'bytes':output.stat().st_size,'signed':True})
        print('Signed:',source.name,flush=True)
    (ROOT/'Shortcuts/signing-report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':sign()
