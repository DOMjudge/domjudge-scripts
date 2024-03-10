#!/usr/bin/env python3

# Script based on: https://pypi.org/project/xkcdpass/
from xkcdpass import xkcd_password as xp
import re, os

words = xp.generate_wordlist(wordfile=xp.locate_wordfile(), min_length=3, max_length=8)

for root,_,files in os.walk('group_vars'):
    out = ''
    if '/' not in root:
        continue
    if 'secret.yml.example' not in files:
        continue
    if os.path.isfile(os.path.join(root, 'secret.yml')):
        print("Secret file exists already, exiting.")
        exit(-1)
    with open(os.path.join(root, 'secret.yml.example'), 'r') as fi:
        for line in fi:
            if '{' in line:
                parms = str(re.search('{.*}', line).group())[1:-1]
                if '-' in parms:
                    if 'strong' in parms:
                        vls = {parms: xp.generate_xkcdpassword(words, numwords=5, delimiter='-')}
                    else:
                        vls = {parms: xp.generate_xkcdpassword(words, numwords=3, delimiter='-')}
                    out += line.format(**vls)
            else:
                out += line
    with open(os.path.join(root, 'secret.yml'), 'w') as fo:
        fo.write(out)
