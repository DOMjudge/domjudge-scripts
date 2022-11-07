#!/usr/bin/python3
import sys
import os
import yaml
import zipfile
import argparse

DEFAULT_OUTPUT = 'samps.zip'

def add_to_zip(zipf, source, dest, predicate=None):
    for root, dirs, files in os.walk(source):
        for fname in files:
            path = os.path.join(root, fname)
            if predicate is not None and not predicate(path):
                continue
            zipf.write(path, os.path.join(dest, os.path.relpath(path, source)))

def public_sample_file(path):
    testcase, ext = os.path.splitext(path)

    if ext not in {'.in', '.ans', '.interaction'}:
        return False

    if ext != '.interaction' and os.path.exists(testcase + '.interaction'):
        return False

    return True

def main():
    parser = argparse.ArgumentParser(prog = 'create_samples_zip', description = 'generate the samples.zip file from a contest archive')
    parser.add_argument('-o', '--output', default = DEFAULT_OUTPUT, help = 'the output path for the samples zip')
    parser.add_argument('config_path', help = 'the path to the contest archive')
    args = parser.parse_args()

    config_path = args.config_path
    output_path = args.output
    if os.path.isdir(output_path):
        output_path = os.path.join(output_path, DEFAULT_OUTPUT)

    with open(os.path.join(config_path, 'problemset.yaml'), 'r') as f:
        problemset = yaml.load(f, Loader=yaml.Loader)

    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for problem in problemset['problems']:

            add_to_zip(zipf,
                       os.path.join(config_path, problem['short-name'], 'data', 'sample'),
                       problem['letter'],
                       public_sample_file)

            add_to_zip(zipf,
                       os.path.join(config_path, problem['short-name'], 'attachments'),
                       os.path.join(problem['letter'], 'attachments'))

if __name__ == '__main__':
    main()

