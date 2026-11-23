#!/usr/bin/env python3
"""Sign only generated public templates, then verify signatures and workflow contents.
Local Apple CLI is preferred. On CI without iCloud, use the documented public
Shortcuty V1 API: https://github.com/Shortcuty/Signing-Server-API-Documentation
Never send user icon packs, credentials or personalized workflows to this service.
"""
import pathlib,subprocess,sys,json,time,urllib.request,urllib.error,hashlib
from verify_shortcut import verify
ROOT=pathlib.Path(__file__).resolve().parents[1]
ENDPOINT='https://sign.shortcuty.app/api/v1/sign'

def remote(source,output):
    data=source.read_bytes()
    request=urllib.request.Request(ENDPOINT,data=data,method='POST',headers={
        'Content-Type':'application/octet-stream','X-Filename':source.name,'User-Agent':'IconBridge-build/0.1'})
    for attempt in range(2):
        try:
            with urllib.request.urlopen(request,timeout=75) as response:
                signed=response.read(2*1024*1024+1)
                if response.headers.get('X-Shortcut-Input-SHA256')!=hashlib.sha256(data).hexdigest():raise ValueError('Signing service input hash mismatch')
                if response.headers.get('X-Shortcut-Signed-SHA256')!=hashlib.sha256(signed).hexdigest():raise ValueError('Signing service output hash mismatch')
                if not signed.startswith(b'AEA1') or len(signed)>2*1024*1024:raise ValueError('Signing service did not return AEA1')
                output.write_bytes(signed);return
        except urllib.error.HTTPError as error:
            if attempt or error.code not in (429,502,503,504):raise
            retry=error.headers.get('Retry-After','2')
            try:delay=min(30,max(1,int(retry)))
            except ValueError:delay=2
            time.sleep(delay)
    raise RuntimeError('Signing failed')

def sign():
    subprocess.run([sys.executable,str(ROOT/'Tools/generate_shortcuts.py')],check=True)
    dest=ROOT/'Resources/Launchers';dest.mkdir(parents=True,exist_ok=True)
    backend='local';report=[]
    for source in sorted((ROOT/'Shortcuts/Unsigned').glob('*.shortcut')):
        output=dest/source.name
        if backend=='local':
            result=subprocess.run(['/usr/bin/shortcuts','sign','--mode','anyone','--input',str(source),'--output',str(output)],capture_output=True,text=True,timeout=55)
            if result.returncode!=0:
                print('Local signing unavailable:',(result.stderr+result.stdout).strip(),flush=True)
                backend='Shortcuty public API (static templates only)'
        if backend!='local':remote(source,output)
        verify(source,output)
        report.append({'file':output.name,'bytes':output.stat().st_size,'signed':True,'backend':backend,
                       'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                       'signed_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
                       'aea_signature_verified':True,'workflow_matches_source':True})
        print('Signed and verified:',source.name,flush=True)
    (ROOT/'Shortcuts/signing-report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':sign()
