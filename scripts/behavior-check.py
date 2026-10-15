"""Disposable metadata/policy probe. Never launches the fixture or changes policy."""
import pathlib, tempfile, subprocess, shutil, plistlib, platform

def run(*args):
    p = subprocess.run(args, capture_output=True, text=True)
    return f'exit={p.returncode} {(p.stdout + p.stderr).strip()}'

print('Host:', platform.mac_ver()[0], platform.machine())
print('Policy before:', run('/usr/sbin/spctl', '--status'))
with tempfile.TemporaryDirectory(prefix='trustme-disposable-') as temp:
    app = pathlib.Path(temp) / 'Disposable.app'
    (app / 'Contents/MacOS').mkdir(parents=True)
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'Fixture','CFBundleIdentifier':'local.disposable.probe','CFBundlePackageType':'APPL'}))
    shutil.copy('/usr/bin/true', app / 'Contents/MacOS/Fixture')
    print('Sign:', run('/usr/bin/codesign', '--force', '--sign', '-', str(app)))
    print('Set test quarantine:', run('/usr/bin/xattr', '-w', 'com.apple.quarantine', '0083;00000000;DisposableTest;', str(app)))
    print('Assess before:', run('/usr/sbin/spctl', '--assess', '--type', 'execute', str(app)))
    print('Remove outer test quarantine:', run('/usr/bin/xattr', '-d', 'com.apple.quarantine', str(app)))
    print('Read after:', run('/usr/bin/xattr', '-p', 'com.apple.quarantine', str(app)))
    print('Verify after:', run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)))
    print('Assess after:', run('/usr/sbin/spctl', '--assess', '--type', 'execute', str(app)))
print('Policy after:', run('/usr/sbin/spctl', '--status'))
print('No fixture was launched. Temporary files deleted.')
