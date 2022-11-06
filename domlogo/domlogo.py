#!/usr/bin/python3

import PySimpleGUI as sg
import glob
import os
import requests
import re
import time

font = ('Roboto', 14)
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
    [sg.Column(current_column), sg.VerticalSeparator(), sg.Column(previous_column)],
]
window = sg.Window('DOMlogo', layout, location=(600,0), keep_on_top=True, no_titlebar=True)

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

contests = requests.get(f'{api_url}/contests', auth=(user,passwd)).json()
latest_contest = sorted(contests, key=lambda c: c['end_time'])[-1]
cid = latest_contest['id']
api_url = f'{api_url}/contests/{cid}'
print(f'Contest is {cid}.')

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
                if not team_id.isdigit():
                    new_filename = f'domlogo-files/photos/crew.png'
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
            if not tid.isdigit():
                tid = 'DOMjudge'
            cache[-1] = (f'domlogo-files/logos/{tid}.png', f's{sid}/j{jid}\n{verdict}', color, jid)
            for i in range(len(cache)):
                previous_column[i][0].update(filename=cache[i][0])
                previous_column[i][1].update(cache[i][1])
                previous_column[i][2].TKCanvas.config(bg=cache[i][2])

window.close()
