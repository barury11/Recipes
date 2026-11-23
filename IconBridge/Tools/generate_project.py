#!/usr/bin/env python3
"""Dependency-free Xcode project and app icon generator. Paths stay inside IconBridge."""
import hashlib, json, pathlib, plistlib, struct, zlib
ROOT = pathlib.Path(__file__).resolve().parents[1]

def uid(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def quoted(value): return json.dumps(str(value))
def generate():
    objects = []
    def obj(name, value):
        key = uid(name); objects.append(f'{key} = {{ {value} }};'); return key
    files = []
    for path in sorted(list((ROOT/'App').glob('*.swift')) + list((ROOT/'Core').glob('*.swift'))):
        rel = path.relative_to(ROOT).as_posix()
        ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(rel)}; sourceTree = "<group>";')
        build = obj('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};')
        files.append((ref, build))
    resources=[]
    for name, typ in [('catalog.json','text.json'), ('Assets.xcassets','folder.assetcatalog'), ('Launchers','folder')]:
        ref=obj('resource:'+name, f'isa = PBXFileReference; lastKnownFileType = {typ}; path = {quoted("Resources/"+name)}; sourceTree = "<group>";')
        build=obj('resource-build:'+name,f'isa = PBXBuildFile; fileRef = {ref};');resources.append((ref,build))
    product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = IconBridge.app; sourceTree = BUILT_PRODUCTS_DIR;')
    products=obj('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
    group=obj('group',f'isa = PBXGroup; children = ({",".join([x[0] for x in files+resources]+[products])},); sourceTree = "<group>";')
    sources=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(x[1] for x in files)},); runOnlyForDeploymentPostprocessing = 0;')
    resphase=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(x[1] for x in resources)},); runOnlyForDeploymentPostprocessing = 0;')
    frameworks=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    configs=[]; project_configs=[]
    for name in ('Debug','Release'):
        configs.append(obj('config:'+name, f'''isa = XCBuildConfiguration; name = {name}; buildSettings = {{
            ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            CODE_SIGN_STYLE = Automatic;
            CURRENT_PROJECT_VERSION = 1;
            DEVELOPMENT_TEAM = "";
            GENERATE_INFOPLIST_FILE = NO;
            INFOPLIST_FILE = App/Info.plist;
            IPHONEOS_DEPLOYMENT_TARGET = 17.0;
            MARKETING_VERSION = 0.1.0;
            PRODUCT_BUNDLE_IDENTIFIER = com.barury11.iconbridge;
            PRODUCT_NAME = "$(TARGET_NAME)";
            SDKROOT = iphoneos;
            SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
            SUPPORTS_MACCATALYST = NO;
            SWIFT_VERSION = 5.0;
            TARGETED_DEVICE_FAMILY = "1,2";
            SWIFT_OPTIMIZATION_LEVEL = {quoted('-Onone' if name=='Debug' else '-O')};
            ENABLE_USER_SCRIPT_SANDBOXING = YES;
        }};'''))
        project_configs.append(obj('project-config:'+name,f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; }};'))
    configlist=obj('config-list',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    plist=obj('project-config-list',f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({sources},{frameworks},{resphase},); buildRules = (); dependencies = (); name = IconBridge; productName = IconBridge; productReference = {product}; productType = "com.apple.product-type.application";')
    project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {plist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = pl; hasScannedForEncodings = 0; knownRegions = (pl,en,Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
    dest=ROOT/'IconBridge.xcodeproj'; dest.mkdir(exist_ok=True)
    (dest/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
    scheme=dest/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
    (scheme/'IconBridge.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="IconBridge.app" BlueprintName="IconBridge" ReferencedContainer="container:IconBridge.xcodeproj"/>
</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="IconBridge.app" BlueprintName="IconBridge" ReferencedContainer="container:IconBridge.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
    icon=ROOT/'Resources/Assets.xcassets/AppIcon.appiconset'
    icon.mkdir(parents=True,exist_ok=True)
    # Opaque app asset drawn as overlapping cards on a purple field; no external assets/dependencies.
    n=1024; scan=bytearray()
    for y in range(n):
        scan.append(0)
        for x in range(n):
            r,g,b=int(48+45*x/n),int(20+22*y/n),int(108+78*x/n)
            for cx,cy,w,h,c in [(443,468,430,460,(154,115,239)),(555,555,430,460,(233,220,255))]:
                dx=max(abs(x-cx)-(w/2-72),0);dy=max(abs(y-cy)-(h/2-72),0)
                if dx*dx+dy*dy<=72*72:r,g,b=c
            if 507<x<603 and 418<y<674 or 425<x<685 and 500<y<596:r,g,b=96,53,176
            scan.extend((r,g,b))
    def chunk(t,d):return struct.pack('!I',len(d))+t+d+struct.pack('!I',zlib.crc32(t+d)&0xffffffff)
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',n,n,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan,9))+chunk(b'IEND',b'')
    (icon/'AppIcon.png').write_bytes(png)
    (icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
    (ROOT/'Resources/Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')

if __name__=='__main__':generate()
