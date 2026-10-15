import pathlib, struct
folder = pathlib.Path('work/TrustMe.iconset')
chunks = []
for tag, name in [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'), ('ic07', 'icon_128x128.png'), ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'), ('ic10', 'icon_512x512@2x.png')]:
    data = (folder / name).read_bytes()
    chunks.append(tag.encode() + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
pathlib.Path('resources/TrustMe.icns').write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
