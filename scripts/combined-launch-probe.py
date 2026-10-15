"""Test production quarantine preparation + normal launch, using only our own fixture."""
import os, pathlib, plistlib, shutil, subprocess, time, uuid
root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(root / 'work/cache'))
probe = root / 'work/launch-probe'
probe.mkdir(parents=True, exist_ok=True)
def run(*args):
    p = subprocess.run([str(a) for a in args], env=env, capture_output=True, text=True, timeout=60)
    if p.returncode: raise RuntimeError(p.stdout + p.stderr)
    return p.stdout.strip()
print('Gatekeeper before:', run('/usr/sbin/spctl','--status'), flush=True)
run('/usr/bin/xcrun','swiftc','scripts/LaunchFixture.swift','-o',probe/'Fixture')
run('/usr/bin/xcrun','swiftc','Sources/TrustMe/Quarantine.swift','Tests/LaunchProbe/main.swift','-o',probe/'CombinedDriver')
app = probe / 'CombinedProbe.app'
if app.exists(): shutil.rmtree(app)
(app/'Contents/MacOS').mkdir(parents=True)
shutil.copy(probe/'Fixture',app/'Contents/MacOS/Fixture')
(app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleName':'CombinedProbe','CFBundleExecutable':'Fixture','CFBundleIdentifier':'local.trustme.combined.'+uuid.uuid4().hex,'CFBundlePackageType':'APPL'}))
run('/usr/bin/codesign','--force','--sign','-',app)
run('/usr/bin/xattr','-r','-w','com.apple.quarantine','0083;00000000;TrustMeDisposableTest;',app)
run('/usr/bin/xattr','-w','local.keep','preserved',app)
marker=app.with_suffix('.launched')
for attempt in [1,2]:
    marker.unlink(missing_ok=True)
    print(f'Launch {attempt}:', run(probe/'CombinedDriver',app), flush=True)
    for _ in range(30):
        if marker.exists(): break
        time.sleep(.1)
    print(f'Launch {attempt} marker:',marker.exists(),flush=True)
    if not marker.exists(): raise RuntimeError('The fixture did not execute its harmless marker write')
    time.sleep(.3)
run('/usr/bin/codesign','--verify','--deep','--strict',app)
print('Signature intact; unrelated attribute:',run('/usr/bin/xattr','-p','local.keep',app),flush=True)
print('Gatekeeper after:',run('/usr/sbin/spctl','--status'),flush=True)
print('PASS: production preparation and two normal launches. No separate override API, Settings navigation, or global policy change.',flush=True)
