#!/usr/bin/env python3
import subprocess

import FreeSimpleGUI as sg
import glob
import os
import requests
import re
import time
import platform
import shlex
import yaml
from PIL import Image, ImageDraw, ImageFont


def generate_placeholder(text: str, path: str, background_color, width: int, height: int):
    image = Image.new("RGB", (width, height), background_color)
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72)
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    text_x = (width - text_width) / 2
    text_y = (height - text_height) / 2
    draw.text((text_x, text_y), text, fill=(255,255,255), font=font)

    # Add some hint how to replace the image.
    small_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    placeholder_text = f'(Replace this placeholder image at {path})'
    text_bbox = draw.textbbox((0, 0), placeholder_text, font=small_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (width - text_width) / 2
    text_y = text_y + 1.4*text_height
    draw.text((text_x, text_y), placeholder_text, fill=(195,196,199), font=small_font)
    image.save(path)


def download_image(image_type: str, entity_id: str, file: dict):
    href = file['href']
    filename = file['filename']
    photo_head = requests.head(f'{api_url}/{href}', auth=(user, passwd))
    etag = photo_head.headers['ETag']
    etag_file = f'domlogo-files/{image_type}s/{entity_id}.etag.txt'
    temp_file = f'domlogo-files/{image_type}s/temp-{entity_id}-{filename}'
    existing_etag = None
    if os.path.isfile(etag_file):
        with open(etag_file) as f:
            existing_etag = f.readline().strip()

    if existing_etag != etag:
        print(f'Downloading and converting {image_type} for entity with ID {entity_id}...')
        os.makedirs(os.path.dirname(temp_file), exist_ok=True)
        with open(temp_file, 'wb') as f:
            f.write(requests.get(f'{api_url}/{href}', auth=(user, passwd)).content)

        return True, temp_file, etag_file, etag

    return False, None, None, None


font = ('Roboto', 14)
mono_font = ('Liberation Mono', 32)
host = platform.node()
host_bg_color = 'black'

idle_image = 'domlogo-files/photos/idle.png'
if not os.path.isfile(idle_image):
    os.makedirs(os.path.dirname(idle_image), exist_ok=True)
    generate_placeholder('judgehost idle', idle_image, (10,75,120), 1024, 768)

config_file = 'domlogo-files/config.yaml'
if os.path.isfile(config_file) and os.access(config_file, os.R_OK):
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
        if 'host-bg-color' in config:
            host_bg_color = config['host-bg-color']

team_image = sg.Image(filename='domlogo-files/photos/idle.png')
metadata_text = sg.Text('No submissions in queue.', font=font)
results_text = sg.Text('', font=font)
current_column = [
    [team_image],
    [metadata_text],
    [results_text],
]
cache = [('domlogo-files/logos/DOMjudge.png', '           \n          ', None, None) for _ in range(10)]
previous_column = [
    [sg.Image(filename=c[0]), sg.Text(c[1], font=font), sg.Canvas(size=(10,50))] for c in cache
]
layout = [
    [sg.Push(), sg.Text(f'{host}', font=mono_font, background_color=host_bg_color), sg.Push()],
    [sg.Column(current_column), sg.VerticalSeparator(), sg.Column(previous_column)],
]
window = sg.Window('DOMlogo', layout, location=(600,50), keep_on_top=True, no_titlebar=True)

with open('etc/restapi.secret', 'r') as secrets:
    while True:
        line = secrets.readline()
        if not line:
            break
        if line.startswith('#'):
            continue
        id, api_url, user, passwd = line.strip().split()
        break
print(f'Using {api_url} as endpoint.')

print('Loading teams and organizations from API')
teams = {team['id']: team for team in requests.get(f'{api_url}/teams', auth=(user, passwd)).json()}
for team_id in teams:
    if 'display_name' not in teams[team_id]:
        teams[team_id]['display_name'] = teams[team_id]['name']
organizations = {org['id']: org for org in requests.get(f'{api_url}/organizations', auth=(user, passwd)).json()}

print('Downloading any new or changed logos and photos...')
for organization in organizations.values():
    if 'logo' in organization:
        organization_id = organization['id']
        logo = organization['logo'][0]
        downloaded, downloaded_to, etag_file, etag = download_image('logo', organization_id, logo)
        if downloaded_to:
            # Convert to both 64x64 (for sidebar) and 160x160 (for overlay over photo)
            downloaded_to_escaped = shlex.quote(downloaded_to)
            target = shlex.quote(f'domlogo-files/logos/{organization_id}.png')
            command = f'convert {downloaded_to_escaped} -resize 64x64 -background none -gravity center -extent 64x64 {target}'
            os.system(command)

            target = shlex.quote(f'domlogo-files/logos/{organization_id}.160.png')
            command = f'convert {downloaded_to_escaped} -resize 160x160 -background none -gravity center -extent 160x160 {target}'
            os.system(command)

            with open(etag_file, 'w') as f:
                f.write(etag)

            os.unlink(downloaded_to)

for team in teams.values():
    if 'photo' in team and team['display_name'] != 'DOMjudge':
        team_id = team['id']
        photo = team['photo'][0]
        downloaded, downloaded_to, etag_file, etag = download_image('photo', team_id, photo)
        if downloaded_to:
            # First convert to a good known size because adding the annotation and logo assumes this
            intermediate_target = f'domlogo-files/photos/{team_id}-intermediate.png'
            command = f'convert {downloaded_to} -resize 1024x1024 -gravity center {intermediate_target}'
            os.system(command)

            # Now add logo and team name. We use subprocess.run here to escape the team name
            target = f'domlogo-files/photos/{team_id}.png'
            organization_id = team['organization_id']
            logo_file = f'domlogo-files/logos/{organization_id}.png'
            command = [
                'convert',
                intermediate_target,
                '-fill', 'white',
                '-undercolor', '#00000080',
                '-gravity', 'south',
                '-font', 'Ubuntu',
                '-pointsize', '30',
                '-annotate', '+5+5', f' {team["display_name"]} ',
                logo_file,
                '-gravity', 'northeast',
                '-composite',
                target
            ]

            subprocess.run(command)

            with open(etag_file, 'w') as f:
                f.write(etag)

            os.unlink(downloaded_to)
            os.unlink(intermediate_target)

latest_logfile = max(glob.glob('output/log/judge.*-2.log'), key=os.path.getctime)
print(f'Checking logfile {latest_logfile}')
with open(latest_logfile, 'r') as logfile:
    # Seeks to the end of the file.
    logfile.seek(0, 2)
    results = []
    last_seen, needs_update = (None, None)
    while True:
        if needs_update is None:
            event, values = window.read(timeout=1)
            if event == sg.WIN_CLOSED:
                break
        line = logfile.readline()
        # Sleep here for a tiny amount of time to avoid using too much CPU.
        if len(line) == 0 and needs_update is None:
            time.sleep(0.1)
        needs_update = None
        if 'Working directory:' in line:
            token = line.strip().split('/')
            judging_id = token[-1]
            submission_id = token[-2]
            if not last_seen or last_seen[1] != judging_id:
                print(f'new submission, line was {line}')
                needs_update = last_seen
                results = []
                submission_data = requests.get(f'{api_url}/submissions/{submission_id}', auth=(user,passwd)).json()
                team_id = submission_data['team_id']
                last_seen = (submission_id, judging_id, team_id)
                new_filename = f'domlogo-files/photos/{team_id}.png'
                if not os.path.isfile(new_filename):
                    generate_placeholder(f'team {team_id}', new_filename, (137,28,28), 1024, 768)
                team_image.update(filename=new_filename)
                metadata_text.update(f's{submission_id} / {submission_data["problem_id"]} / {submission_data["language_id"]}')
                results_text.update('Busy compiling.')
        elif 'No submissions in queue' in line:
            needs_update = last_seen
            last_seen = None
            team_image.update(filename=f'domlogo-files/photos/idle.png')
            metadata_text.update('No submissions in queue.')
            results_text.update('')
        elif ' Compilation: ' in line:
            results_text.update(line.split('💻')[1:])
        elif ', result: ' in line:
            result = line.split(', result: ')[-1].strip()
            results.append('✔' if result == 'correct' else '✘')
            results_text.update('\n'.join(re.findall(
                '.{1,78}', ' '.join(results))))
        if needs_update:
            sid, jid, tid = needs_update
            judging_data = requests.get(f'{api_url}/judgements/{jid}', auth=(user,passwd)).json()
            verdict = judging_data['judgement_type_id'] or 'pending'
            color = 'firebrick1'
            if verdict == 'AC':
                color = 'LightGreen'
            elif verdict == 'pending':
                color = 'DeepSkyBlue'
            for i in range(len(cache)-1):
                cache[i] = cache[i+1]
            organization_id = None
            if tid in teams:
                organization_id = teams[tid]['organization_id']
            organization_logo = 'domlogo-files/logos/DOMjudge.png'
            # Organization ID is null for internal teams so explicitly check for it
            if organization_id:
                potential_organization_logo = f'domlogo-files/logos/{organization_id}.png'
                if os.path.isfile(potential_organization_logo):
                    organization_logo = potential_organization_logo
            cache[-1] = (organization_logo, f's{sid}/j{jid}\n{verdict}', color, jid)
            for i in range(len(cache)):
                previous_column[i][0].update(filename=cache[i][0])
                previous_column[i][1].update(cache[i][1])
                previous_column[i][2].TKCanvas.config(bg=cache[i][2])

window.close()
