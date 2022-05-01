#!/usr/bin/python3

from halo import Halo
import json
from pprint import pprint
from zipfile import ZipFile
from datetime import datetime
import time
import sys
import random
import requests
import re
import logging

logging.basicConfig(
        level=logging.INFO,
        datefmt='%d-%b-%y %H:%M:%S',
        format='%(asctime)s - \x1b[34;1m%(message)s\x1b[0m',
)

if len(sys.argv) == 1 or len(sys.argv) > 4:
    print(f'Usage: {sys.argv[0]} <contest-api-url> [<contest> [<submissionid>]')
    sys.exit(-1)

api_url = sys.argv[1]
if len(sys.argv) >= 3:
    contest = sys.argv[2]
else:
    contests = requests.get(f'{api_url}/contests').json()
    if len(contests) == 1:
        contest = contests[0]['id']
    else:
        print('Need to specify contest if there is not exactly one active.')
        print('Active contests: ' + ', '.join(c['id'] for c in contests))
        sys.exit(1)

# submissions.json contains a list of submissions with a timestamp relative to
# contest start. Submission with negative timestamp (most likely jury
# submissions) are going to be batch-submitted right away.
submissions = json.load(open('submissions.json'))
logging.info(f'Loaded {len(submissions)} submissions.')

contest_data = requests.get(f'{api_url}/contests/{contest}').json()
contest_start = datetime.strptime(contest_data['start_time'], '%Y-%m-%dT%H:%M:%S%z').timestamp()
contest_duration = (datetime.strptime(contest_data['duration'], '%H:%M:%S.000') - datetime(1900, 1, 1)).total_seconds()

now = time.time()
orig_contest_duration = 5 * 60 * 60

first_submission_time = 0
if len(sys.argv) == 4:
    skip_to_submission = int(sys.argv[3])
    submissions = submissions[skip_to_submission:]
    logging.info(f'Skipped to submission {skip_to_submission}, {len(submissions)} remaining.')
    first_submission_time = (datetime.strptime(submissions[0]['contest_time'][:-4], '%H:%M:%S') - datetime(1900, 1, 1)).total_seconds()
    orig_contest_duration -= first_submission_time
    logging.info(f'Contest duration shortened to {orig_contest_duration}s.')

if contest_start < now:
    logging.info('Contest start was at '
            + time.strftime('%X %x %Z', time.localtime(contest_start)) + '.')
    simulation_speed = orig_contest_duration/(contest_start + contest_duration - now)
    contest_start = now - (first_submission_time)/simulation_speed
else:
    logging.info('Contest will be started at '
            + time.strftime('%X %x %Z', time.localtime(contest_start)) + '.')
    simulation_speed = orig_contest_duration/contest_duration
logging.info(f'Simulation speed: {simulation_speed}')

# problems.json is necessary to map from problem id to label.
problems = json.load(open('problems.json'))
summary = ', '.join([p['label'] for p in problems])
logging.info(f'Loaded {len(problems)} problems ({summary}).')

# We will submit under different user accounts, parse all teams out them.
accounts_tsv = open('accounts.tsv')
accounts = dict()
num_teams = 0
for line in accounts_tsv:
    credentials = line.rstrip('\n').split('\t')
    if credentials[0] != 'team':
        continue
    num_teams += 1
    accounts[num_teams] = (credentials[2], credentials[3])

problem_to_label = dict()
for problem in problems:
    problem_to_label[problem['id']] = problem['label']

team_problem_team_map = dict()

submissions_api_url = f'{api_url}/contests/{contest}/submissions'
for submission in submissions:
    times = submission['contest_time'].split(':')
    orig_submission_time = int(times[0])*3600 + int(times[1])*60 + float(times[2])
    new_submission_time = orig_submission_time/simulation_speed
    time_from_start = time.time() - contest_start
    time_diff = new_submission_time - time_from_start
    if time_diff > 0:
        logging.info(f'Waiting for simulated contest time of {times[0]}:{times[1]}:{times[2]}.')
        spinner = Halo(spinner='dots', text=f'Sleeping for ~{str(round(time_diff,2))}s')
        spinner.start()
        while time_diff > 1:
            time.sleep(1)
            time_from_start = time.time() - contest_start
            time_diff = new_submission_time - time_from_start
            spinner.text = f'Sleeping for ~{str(round(time_diff,2))}s'
        if time_diff > 0:
            time.sleep(time_diff)
        spinner.stop()

    # Make sure that for a given team/problem combination we pick the same team
    # all the time.
    team_id = submission['team_id']
    problem_id = submission['problem_id']
    # TODO: make this configurable or detect it.
    # With internal data source: 
    # problem_label = problem_to_label[problem_id]
    # With external data source:
    problem_label = problem_id
    if team_id not in team_problem_team_map:
        team_problem_team_map[team_id] = dict()
    if problem_label not in team_problem_team_map[team_id]:
        team_problem_team_map[team_id][problem_label] = random.randint(1, num_teams)
    team_id = team_problem_team_map[team_id][problem_label]

    files = []
    problem_zip = ZipFile(submission['id'] + ".zip")
    for name in problem_zip.namelist():
        file_tuple = ('code[]', (name, problem_zip.read(name), 'text/plain'))
        files.insert(len(files), file_tuple)
    first_filename = files[0][1][0]
    username = accounts[team_id][0]
    # We don't allow python2 anymore, let's rewrite it as python3 and try our
    # best.
    language_id = submission['language_id']
    if language_id == 'python2':
        language_id = 'python3'
    data = {'problem_id': problem_label, 'language_id': language_id}
    if 'entry_point' in submission:
        data['entry_point'] = submission['entry_point']
    logging.info(f'Submitting problem {problem_label} ({first_filename}) on behalf of user {username}.')
    r = requests.post(
            submissions_api_url,
            data = data,
            auth = accounts[team_id],
            files = files,
    ) 
    if r.status_code == 200:
        sid = r.json()['id']
        logging.info(f'Success, submission s{sid} received.')
    else:
        message = '?'
        try:
            json = r.json()
            message = json['message'] if 'message' in json else '?'
        except:
            pass
        logging.error(f'\x1b[31;21mSubmission failed with status code {r.status_code}. Message = {message}')
