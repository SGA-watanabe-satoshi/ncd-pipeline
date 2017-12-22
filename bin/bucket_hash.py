#!/usr/bin/env python
""" Print hashes for cloud storage buckets.

Look at a cloud storage bucket (or buckets) and calculate a hash based
on the metadata. If something in the bucket changes, then the hash will
be different.

The provided URLs can be a file pattern. The script will check all the
files in the bucket against the pattern, and only consider files that
match the pattern when calculating the hash.

It is expected that the environment variable GOOGLE_PROJECT_ID is set.

Usage:
    bucket_hash.py GS_URL...

Options:
    -h, --help  Show this screen.
    --version   Show version.
"""

import md5
import os
from fnmatch import fnmatch
from urlparse import urlparse

from docopt import docopt
from gcloud import storage
from gcloud.exceptions import NotFound


def calc_hash(gs_url):
    parsed_url = urlparse(gs_url)
    bucket_name = parsed_url.netloc
    # Remove leading slash
    blob_pattern = parsed_url.path.lstrip('/')

    client = storage.Client(project=os.environ.get('GOOGLE_PROJECT_ID'))

    md5sum = md5.new()
    md5sum.update(bucket_name)

    try:
        bucket = client.get_bucket(bucket_name)
        for blob in bucket.list_blobs():
            if fnmatch(blob.name, blob_pattern):
                md5sum.update(blob.name)
                md5sum.update(blob.md5_hash)

    except NotFound as e:
        # The bucket doesn't exist
        pass

    print "%s  %s" % (md5sum.hexdigest(), gs_url)



if __name__ == "__main__":
    arguments = docopt(__doc__, version="1.0.0")
    # print arguments

    for gs_url in sorted(arguments['GS_URL']):
        calc_hash(gs_url)