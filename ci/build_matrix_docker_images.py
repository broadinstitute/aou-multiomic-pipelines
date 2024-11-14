#!/usr/bin/env python3
"""
Parse a list of changed files since last commit,
and determine the list of Docker images to build.
"""

import os
import sys
import json
import argparse
from pathlib import Path

# Main directory holding all docker images to build. The directory
# should be relative to the repository root.
#
# This scripts assumes that each docker image to build is in
# its own subdirectory of the listed folder below.
DOCKER_IMGS_PATH = Path("docker")

# Google Artifact Registry repository URL
GAR_REPOSITORY = "us-central1-docker.pkg.dev/broad-dsp-lrma/aou-multiomics/"


def find_repo_root(fname: Path):
    if fname.is_file():
        fname = fname.parent

    while fname != Path('/'):
        has_git = (fname / ".git").is_dir()

        if has_git:
            return fname

        fname = fname.parent


def find_docker_root(fname):
    """Finds the first parent folder of `fname` that contains a `Dockerfile`."""

    if fname.name == 'Dockerfile':
        return fname.parent

    curr_dir: Path = fname.parent
    while curr_dir != Path('/'):
        has_dockerfile = (curr_dir / 'Dockerfile').is_file()

        if has_dockerfile:
            return curr_dir

        curr_dir = curr_dir.parent


def main():
    parser = argparse.ArgumentParser(
        description="Parses a list of changed files, and identifies any docker images to rebuild."
    )
    parser.add_argument(
        'finput', type=argparse.FileType('r'), default=sys.stdin, nargs='?',
        help="List of files to parse. One per line. Defaults to stdin."
    )
    parser.add_argument(
        '-g', '--github-output', action="store_true", default=False,
        help="By default, outputs JSON to stdout. With this flag the JSON is written to $GITHUB_OUTPUT."
    )

    args = parser.parse_args()

    repo_root = find_repo_root(Path(__file__))
    repo_docker_root = repo_root / DOCKER_IMGS_PATH

    docker_images = set()
    for f in map(lambda line: Path(line.strip()), args.finput):
        if not f.is_file():
            print("Non-existing file:", f, file=sys.stderr)
            continue

        docker_root = find_docker_root(f.resolve())

        if not docker_root:
            continue

        if docker_root.is_relative_to(repo_docker_root):
            docker_img_name = docker_root.name
            docker_images.add(docker_img_name)

    output = []
    for img_name in docker_images:
        output.append({
            "dockerfile": (repo_docker_root / img_name / "Dockerfile").as_posix(),
            "img_name": GAR_REPOSITORY + img_name
        })

    if args.github_output and 'GITHUB_OUTPUT' in os.environ:
        with open(os.environ['GITHUB_OUTPUT'], 'a') as ofile:
            ofile.write("dockers=")
            json.dump(output, ofile)
    else:
        print(json.dumps(output))


if __name__ == '__main__':
    main()
