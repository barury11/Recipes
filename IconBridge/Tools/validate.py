#!/usr/bin/env python3
import hashlib,json,pathlib,plistlib,sys,unittest,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
class SourceTests(unittest.TestCase):
    def test_catalog(self):
        catalog=json.loads((ROOT/'Resources/catalog.json').read_text())
        self.assertEqual(len(catalog),24)
        for key in ['id','name','bundleID']:
            self.assertEqual(len({x[key] for x in catalog}),len(catalog))
        for app in catalog:
            p=ROOT/'Shortcuts/Unsigned'/('IconBridge - '+app['name']+'.shortcut')
            body=plistlib.loads(p.read_bytes());action=body['WFWorkflowActions'][0]
            self.assertEqual(len(body['WFWorkflowActions']),1)
            self.assertEqual(action['WFWorkflowActionIdentifier'],'is.workflow.actions.openapp')
            self.assertEqual(action['WFWorkflowActionParameters']['WFAppIdentifier'],app['bundleID'])
            self.assertEqual(body['WFWorkflowName'],'IconBridge - '+app['name'])
    def test_importer_references(self):
        body=plistlib.loads((ROOT/'Shortcuts/Unsigned/IconBridge - Importuj.shortcut').read_bytes())
        actions=body['WFWorkflowActions'];seen=set()
        for action in actions:
            params=action['WFWorkflowActionParameters']
            if 'WFInput' in params:self.assertIn(params['WFInput']['Value']['OutputUUID'],seen)
            self.assertNotIn(params['UUID'],seen);seen.add(params['UUID'])
        self.assertEqual(actions[0]['WFWorkflowActionIdentifier'],'is.workflow.actions.selectphoto')
        self.assertTrue(actions[1]['WFWorkflowActionParameters']['WFLocalOnly'])
        self.assertEqual(actions[2]['WFWorkflowActionParameters']['WFURLActionURL'],'iconbridge://import-clipboard')
    def test_app_manifest(self):
        info=plistlib.loads((ROOT/'App/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleURLTypes'][0]['CFBundleURLSchemes'],['iconbridge'])
        self.assertNotIn('NSAllowsArbitraryLoads', info['NSAppTransportSecurity'])
        self.assertNotIn('UIBackgroundModes',info)
        project=(ROOT/'IconBridge.xcodeproj/project.pbxproj').read_text()
        for folder in ['Core','App']:
            for file in (ROOT/folder).glob('*.swift'):self.assertIn(file.relative_to(ROOT).as_posix(),project)
    def test_generator_deterministic(self):
        from generate_shortcuts import generate
        before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'Shortcuts/Unsigned').glob('*.shortcut')}
        generate()
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'Shortcuts/Unsigned').glob('*.shortcut')})
def verify_ipa(filename):
    with zipfile.ZipFile(filename) as archive:
        if archive.testzip():raise SystemExit('Corrupt IPA')
        base='Payload/IconBridge.app/'
        info=plistlib.loads(archive.read(base+'Info.plist'))
        assert info['CFBundleIdentifier']=='com.barury11.iconbridge'
        assert base+info['CFBundleExecutable'] in archive.namelist()
        assert not any('_CodeSignature/' in n or n.endswith('embedded.mobileprovision') for n in archive.namelist()),'IPA must be unsigned'
        files=[n for n in archive.namelist() if n.startswith(base+'Launchers/') and n.endswith('.shortcut')]
        assert len(files)==25,(len(files),'signed launcher count')
        for name in files:assert not archive.read(name).startswith((b'bplist00',b'<?xml')),'Unsigned shortcut bundled'
        print('Verified unsigned IPA, bundle ID, executable, 25 signed shortcuts and ZIP integrity')
if __name__=='__main__':
    if len(sys.argv)==3 and sys.argv[1]=='--ipa':verify_ipa(sys.argv[2])
    else:unittest.main()
