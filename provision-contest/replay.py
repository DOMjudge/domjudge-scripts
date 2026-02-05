#!/usr/bin/python3

import argparse
from halo import Halo
import json
import os
from zipfile import ZipFile
from datetime import datetime
from datetime import timedelta
from itertools import dropwhile
import time
import sys
import random
import requests
import logging

logging.basicConfig(
        level=logging.INFO,
        datefmt='%d-%b-%y %H:%M:%S',
        format='%(asctime)s - \x1b[34;1m%(message)s\x1b[0m',
)

parser = argparse.ArgumentParser(
        formatter_class=argparse.RawTextHelpFormatter,
        description='Replay a contest.')

parser.add_argument('api_url', help='Contest API URL.')
parser.add_argument('-c', '--contest', help='''submit for contest with ID CONTEST.
    Mandatory when more than one contest is active.''')
parser.add_argument('-s', '--submissionid', help='submission to start at.')
parser.add_argument('--insecure', help='do not verify SSL certificate', action='store_true')
parser.add_argument('-r', '--no_remap_teams', help='do not remap team ID\'s to team ID\'s of contest from API.', action='store_true')
parser.add_argument('-I', '--ignore_teamids', help='Completely randomize teamids during replay, not storing any mapping.', action='store_true')
parser.add_argument('-i', '--internal_data_source', help='The API uses an internal API source.', action='store_true')
parser.add_argument('-f', '--simulation_speed', help='Speed up replay speed by this factor. Use 0 to not sleep at all.')
parser.add_argument('-z', '--flatten_zips', help='Flatten directory hierarchy in submission ZIPs', action='store_true')
parser.add_argument('-p', '--problem_id', nargs='+', help='Only submit submissions for these problem ID(s).')
parser.add_argument('-t', '--team_id', nargs='+', help='Only submit submissions for these team ID(s).')

args = parser.parse_args()

api_url = args.api_url
verify = not args.insecure
if args.contest:
    contest = args.contest
else:
    contests = requests.get(f'{api_url}/contests', verify=verify).json()
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

if args.problem_id:
    submissions = [s for s in submissions if s['problem_id'] in args.problem_id]
    logging.info(f'Filtered to {len(submissions)} submissions for problem(s) {", ".join(args.problem_id)}.')
if args.team_id:
    submissions = [s for s in submissions if s['team_id'] in args.team_id]
    logging.info(f'Filtered to {len(submissions)} submissions for team(s) {", ".join(args.team_id)}.')

problem_data = requests.get(f'{api_url}/contests/{contest}/problems', verify=verify).json()
known_problem_ids = set([p['id'] for p in problem_data])
used_problem_ids = set([s['problem_id'] for s in submissions])
unknown_problem_ids = used_problem_ids.difference(known_problem_ids)
if unknown_problem_ids:
    if len(unknown_problem_ids) == len(used_problem_ids):
        logging.critical('None of the used problem IDs is known.')
        sys.exit(-1)
    logging.error(f'Some problem IDs are used but not known: {unknown_problem_ids}')

contest_data = requests.get(f'{api_url}/contests/{contest}', verify=verify).json()
if 'code' in contest_data and 'message' in contest_data and contest_data['code'] != 200:
    code = contest_data['code']
    msg = contest_data['message']
    logging.critical(f'Failed to retrieve contest, HTTP status code: {code}, message: {msg}')
    sys.exit(-1)

while not contest_data['start_time']:
    logging.info(f'Start time unknown - contest delayed.')
    time_diff = 30
    spinner = Halo(spinner='dots', text=f'Sleeping for ~{str(round(time_diff,2))}s while waiting for contest start to be set.')
    spinner.start()
    time.sleep(time_diff)
    spinner.stop()
    contest_data = requests.get(f'{api_url}/contests/{contest}', verify=verify).json()

contest_start = datetime.strptime(contest_data['start_time'], '%Y-%m-%dT%H:%M:%S%z').timestamp()
contest_start_obj = datetime.strptime(contest_data['start_time'], '%Y-%m-%dT%H:%M:%S%z')
contest_duration = (datetime.strptime(contest_data['duration'], '%H:%M:%S.000') - datetime(1900, 1, 1)).total_seconds()

if args.no_remap_teams:
    if args.ignore_teamids:
        logging.critical('Cannot specify --no_remap_teams and --ignore_teamids at the same time.')
        sys.exit(-1)

    logging.info('Keeping original team IDs.')
else:
    # Get the teams from the contest
    team_data = requests.get(f'{api_url}/contests/{contest}/teams', verify=verify).json()
    team_ids = [team['id'] for team in team_data if not team['hidden']]

    if not team_ids:
        logging.critical('Contest has no teams, can\'t submit.')
        sys.exit(-1)

    logging.info(f'Remapping teams to {len(team_ids)} teams from API.')

now = time.time()
orig_contest_duration = 5 * 60 * 60

first_submission_time = 0
if args.submissionid:
    skip_to_submission = args.submissionid
    submissions = list(dropwhile(lambda s: s['id'] != skip_to_submission, submissions))
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
if args.simulation_speed:
    simulation_speed = float(args.simulation_speed)
logging.info(f'Simulation speed: {simulation_speed}')

if args.internal_data_source:
    # problems.json is necessary to map from problem id to label.
    problems = json.load(open('problems.json'))
    summary = ', '.join([p['label'] for p in problems])
    logging.info(f'Loaded {len(problems)} problems ({summary}).')

    problem_to_label = dict()
    for problem in problems:
        problem_to_label[problem['id']] = problem['label']

team_problem_team_map = dict()

submissions_api_url = f'{api_url}/contests/{contest}/submissions'
for submission in submissions:
    if not submission['id']:
        continue
    times = submission['contest_time'].split(':')
    hours = int(times[0])
    minutes = int(times[1])
    seconds = float(times[2])
    orig_submission_time = hours*3600 + minutes*60 + seconds
    if simulation_speed != 0:
        new_submission_time = orig_submission_time/simulation_speed
        time_from_start = time.time() - contest_start
        time_diff = new_submission_time - time_from_start
        if time_diff > 0:
            logging.info(f'Waiting for simulated contest time of {hours}:{minutes:02}:{seconds:06.3f}.')
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
    if args.internal_data_source:
        problem_label = problem_to_label[problem_id]
    else:
        problem_label = problem_id
    if not args.no_remap_teams:
        if args.ignore_teamids:
            team_id = random.choice(team_ids)
        else:
            if team_id not in team_problem_team_map:
                team_problem_team_map[team_id] = dict()
            if problem_label not in team_problem_team_map[team_id]:
                team_problem_team_map[team_id][problem_label] = random.choice(team_ids)
            team_id = team_problem_team_map[team_id][problem_label]
    else:
        team_id = submission['team_id']

    files = []
    problem_zip = ZipFile(submission['id'] + ".zip")
    for name in problem_zip.namelist():
        if args.flatten_zips:
            if name.endswith('/'):
                continue
            file_tuple = ('code[]', (os.path.basename(name), problem_zip.read(name), 'text/plain'))
        else:
            file_tuple = ('code[]', (name, problem_zip.read(name), 'text/plain'))
        files.insert(len(files), file_tuple)
    first_filename = files[0][1][0]
    # We don't allow python2 anymore, let's rewrite it as python3 and try our
    # best.
    language_id = submission['language_id']
    if language_id == 'python2':
        language_id = 'python3'

    data = {
        'problem_id': problem_label,
        'language_id': language_id,
        'team_id': team_id
    }
    if 'entry_point' in submission:
        data['entry_point'] = submission['entry_point']
    logging.info(f'Submitting problem {problem_label} ({first_filename}) on behalf of team {team_id}.')
    r = requests.post(
            submissions_api_url,
            data = data,
            files = files,
            verify = verify,
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
