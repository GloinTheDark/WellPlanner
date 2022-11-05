import zipfile
import os
import json
import re

version = "1.1.2"

print('Scanning changelog.txt for version...')
file1 = open('changelog.txt', 'r')
Lines = file1.readlines() 
for line in Lines:
    match = re.match(r'Version: (.+)', line)
    if match:
        version = match.group(1).strip()
        break

print(f'Version = "{version}"')
excludeFiles = [
    "info.json", 
    ".gitattributes", 
    "deploy.py"
]


myfiles = []
for root, dirs, files in os.walk('.'):
    for d in dirs:
        if d.startswith('.'):
            dirs.remove(d)
    for name in files:
        myfiles.append(os.path.join(root, name))



archiveName = f'WellPlanner_{version}'
archiveFile = f'{archiveName}.zip'

print(f'Creating archive {archiveFile}...')

with open('info.json') as f:
  info = json.load(f)
info['version'] = version

zf = zipfile.ZipFile(
    '../' + archiveFile, 
    mode='w',                 
    compression=zipfile.ZIP_DEFLATED
)

try:
    print('Writing info.json with version.')
    zf.writestr(f"{archiveName}/info.json", json.dumps(info, indent=1))
    for file in myfiles:      
        if not excludeFiles.__contains__(os.path.basename(file)) :
            print(f'Adding "{file}".')
            zf.write(file, f'{archiveName}/{file}')
finally:
    print(f'Closing {archiveName}.')
    zf.close()

