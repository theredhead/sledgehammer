import pathlib, subprocess, plistlib, shutil, time
root = pathlib.Path(__file__).resolve().parent.parent / 'work/launch-probe'
root.mkdir(parents=True, exist_ok=True)
subprocess.run(['/usr/bin/xcrun', 'swiftc', str(pathlib.Path(__file__).with_name('LaunchFixture.swift')), '-o', str(root / 'Fixture')], check=True)
for name in ['Quarantined', 'Cleared']:
    app = root / (name + '.app')
    if app.exists(): shutil.rmtree(app)
    (app / 'Contents/MacOS').mkdir(parents=True)
    shutil.copy(root / 'Fixture', app / 'Contents/MacOS/Fixture')
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleName': name, 'CFBundleExecutable':'Fixture','CFBundleIdentifier':'local.trustme.launchprobe.' + name.lower(),'CFBundlePackageType':'APPL'}))
    subprocess.run(['/usr/bin/codesign','--force','--sign','-',str(app)],check=True)
    subprocess.run(['/usr/bin/xattr','-w','com.apple.quarantine','0083;00000000;TrustMeDisposableTest;',str(app)],check=True)
    if name == 'Cleared':
        subprocess.run(['/usr/bin/xattr','-d','com.apple.quarantine',str(app)],check=True)
    marker = app.with_suffix('.launched')
    marker.unlink(missing_ok=True)
    result = subprocess.run(['/usr/bin/open','-n',str(app)],capture_output=True,text=True,timeout=15)
    time.sleep(2)
    print(f'{name}: open exit={result.returncode}; launch marker={marker.exists()}; {(result.stdout+result.stderr).strip()}', flush=True)
print('Only our disposable, locally compiled fixture was submitted to LaunchServices.')
