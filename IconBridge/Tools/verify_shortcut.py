#!/usr/bin/env python3
"""Verify the AEA signature and compare the extracted workflow with our source.
Apple's import UI performs the final certificate trust/import validation on iOS.
Uses only macOS's openssl, aea and aa; no third-party executable dependencies.
"""
import base64,pathlib,plistlib,struct,subprocess,tempfile

def _tlv(data,offset):
    tag=data[offset];size=data[offset+1];start=offset+2
    if size&128:
        count=size&127
        if not 1<=count<=4:raise ValueError('Invalid DER length')
        size=int.from_bytes(data[start:start+count],'big');start+=count
    if start+size>len(data):raise ValueError('Truncated DER')
    return tag,data[start:start+size],start+size

def compare_workflows(expected,actual):
    # A shortcut's import name comes from its download filename. Apple normalizes
    # source-only name/client metadata while signing. Actions and permissions must
    # remain byte-for-byte equivalent after plist decoding.
    if actual.get('WFWorkflowActions')!=expected['WFWorkflowActions']:
        raise ValueError('Signed workflow changed actions or their parameters')
    for key in ('WFWorkflowImportQuestions','WFWorkflowTypes','WFWorkflowInputContentItemClasses','WFWorkflowOutputContentItemClasses'):
        if actual.get(key,[])!=expected.get(key,[]):
            raise ValueError(f'Signed workflow changed input/import configuration: {key}')

def verify(source,output):
    blob=output.read_bytes()
    if blob[:4]!=b'AEA1' or len(blob)>2*1024*1024:raise ValueError('Expected a signed AEA1 container under 2 MB')
    profile,count=struct.unpack_from('<II',blob,4)
    if profile!=0 or count>len(blob)-12:raise ValueError('Expected unencrypted sign-only AEA')
    chain=plistlib.loads(blob[12:12+count]).get('SigningCertificateChain',[])
    if not chain:raise ValueError('Missing signing certificate chain')
    with tempfile.TemporaryDirectory() as temp:
        temp=pathlib.Path(temp);leaf=temp/'leaf.der';leaf.write_bytes(chain[0])
        pem=subprocess.check_output(['/usr/bin/openssl','x509','-inform','DER','-in',str(leaf),'-pubkey','-noout'])
        der=base64.b64decode(b''.join(line for line in pem.splitlines() if not line.startswith(b'---')))
        tag,sequence,_=_tlv(der,0)
        if tag!=0x30:raise ValueError('Expected SPKI sequence')
        _,_,next_offset=_tlv(sequence,0)
        tag,bits,_=_tlv(sequence,next_offset)
        if tag!=3 or bits[0]!=0 or bits[1]!=4 or len(bits)-1 not in (65,97,133):raise ValueError('Expected EC public key')
        key=temp/'public.hex';key.write_text('hex:'+bits[1:].hex())
        archive=temp/'workflow.aa'
        subprocess.run(['/usr/bin/aea','decrypt','-i',str(output),'-o',str(archive),'-sign-pub',str(key)],check=True,capture_output=True)
        extracted=temp/'extracted';extracted.mkdir()
        subprocess.run(['/usr/bin/aa','extract','-i',str(archive),'-d',str(extracted)],check=True,capture_output=True)
        workflows=list(extracted.glob('*.wflow'))
        if len(workflows)!=1:raise ValueError('Expected exactly one workflow in signed archive')
        actual=plistlib.loads(workflows[0].read_bytes());expected=plistlib.loads(source.read_bytes())
        compare_workflows(expected,actual)
        if actual.get('WFWorkflowName')!=expected.get('WFWorkflowName'):
            print('Signer normalized name metadata; preserving import filename:',output.name,flush=True)
    return True
