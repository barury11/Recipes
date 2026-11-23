#!/usr/bin/env python3
"""Generate auditable plists. Signing is a separate, required macOS step."""
import json,pathlib,plistlib,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
def action(identifier,**parameters):
    parameters.setdefault('UUID',str(uuid.uuid5(uuid.NAMESPACE_URL,identifier+json.dumps(parameters,sort_keys=True)) ).upper())
    return {'WFWorkflowActionIdentifier':'is.workflow.actions.'+identifier,'WFWorkflowActionParameters':parameters}
def variable(action):
    return {'Value':{'OutputUUID':action['WFWorkflowActionParameters']['UUID'],'Type':'ActionOutput','OutputName':'Result'},'WFSerializationType':'WFTextTokenAttachment'}
def workflow(name,actions):
    return {'WFWorkflowName':name,'WFWorkflowClientRelease':'3.0','WFWorkflowClientVersion':'2600',
        'WFWorkflowMinimumClientVersion':900,'WFWorkflowMinimumClientVersionString':'900',
        'WFWorkflowActions':actions,'WFWorkflowImportQuestions':[], 'WFWorkflowTypes':[],
        'WFWorkflowInputContentItemClasses':[],
        'WFWorkflowIcon':{'WFWorkflowIconGlyphNumber':59511,'WFWorkflowIconStartColor':2071128575}}
def generate():
    dest=ROOT/'Shortcuts/Unsigned';dest.mkdir(exist_ok=True)
    specs=[]
    for app in json.loads((ROOT/'Resources/catalog.json').read_text()):
        name='IconBridge - '+app['name']
        specs.append((name,workflow(name,[action('openapp',WFAppIdentifier=app['bundleID'],WFSelectedApp={'BundleIdentifier':app['bundleID'],'Name':app['name']})])))
    photo=action('selectphoto',WFSelectMultiplePhotos=False)
    clipboard=action('setclipboard',WFInput=variable(photo),WFLocalOnly=True)
    url=action('url',WFURLActionURL='iconbridge://import-clipboard')
    name='IconBridge - Importuj'
    specs.append((name,workflow(name,[photo,clipboard,url,action('openurl',WFInput=variable(url))])))
    for name,body in specs:
        (dest/(name+'.shortcut')).write_bytes(plistlib.dumps(body,fmt=plistlib.FMT_BINARY,sort_keys=False))
    print(f'Generated {len(specs)} unsigned sources')
if __name__=='__main__':generate()
