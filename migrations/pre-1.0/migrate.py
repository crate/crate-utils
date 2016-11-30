#!/usr/bin/env python3

"""Script to verify if a manual migration to upgrade from CrateDB 0.57 to 1.0
is required.


`blobs.path` filesystem layout changes:

    From

        <blobs.path>/indices/<indexName>/<shard>/blobs

    To

        <blobs.path>/nodes/<node_lock>/indices/<indexName>/<shard>/blobs


`path.data` handling changes - if it contains multiple paths all of them will
be utilized.

Before (up to 0.57):

    <path.data.1>/    <-- contains blob data
    <path.data.2>/    <-- might contain shard-state data
                          (to migrate blob data for the shards that contain
                          shard data in this folder need to be moved)

After

    <path.data.1>/    <-- contains blob data
    <path.data.2>/    <-- contains blob data
"""

import re
import sys
import pathlib
import argparse
from collections import OrderedDict
from crate.client import connect


def info(message, *args):
    """Print info messages to stdout"""
    print(message.format(*args))


def ok(message, *args):
    """Print OK messages to stdout"""
    print('\033[32;1m' + message.format(*args) + '\033[0m')


def warn(message, *args):
    """Print WARN messages to stdout"""
    print('\033[33;1m' + message.format(*args) + '\033[0m')


def error(message, *args):
    """Print ERROR messages to stderr"""
    print('\033[31;1m' + message.format(*args) + '\033[0m', file=sys.stderr)


def info_grouped(groups):
    """Print INFO messages grouped by node to stdout"""
    for node, msg in groups.items():
        ok('[{}]', node)
        [info(x) for x in msg]


def exit_if_no_blob_tables(c):
    c.execute("select count(*) from information_schema.tables where table_schema = 'blob'")
    if c.fetchone()[0] == 0:
        ok('No blob tables were found. No migration required.')
        sys.exit(0)


def get_target_path(path, blob_path):
    """ Return the target path for a blob path

    >>> get_target_path('/t/d/c/nodes/0/indices/t1/1', '/t/b/indices/t1/1/blobs')
    '/t/b/nodes/0/indices/t1/1/blobs'
    """
    node_lock = re.findall('/nodes/(\d+)/indices/', path)
    if not node_lock:
        raise ValueError("Invalid path: {} doesn't contain /nodes/<n>/indices/:".format(path))

    indices_start = blob_path.rindex('/indices/')
    return blob_path[0:indices_start] + '/nodes/' + node_lock[0] + blob_path[indices_start:]


def has_custom_blob_path(rows):
    """ Checks if any blob_paths have a custom blob path

    >>> has_custom_blob_path([
    ...     ('crate1',
    ...      '/t/d/c/nodes/0/indices/.blob_t1/1',
    ...      '/t/b/indices/.blob_t1/1/blobs'),
    ...     ('crate2',
    ...      '/t/d/c/nodes/0/indices/.blob_t1/1',
    ...      '/t/b/indices/.blob_t1/1/blobs'),
    ... ])
    (True, OrderedDict([('crate1', ['mv "/t/b/indices/.blob_t1/1/blobs" "/t/b/nodes/0/indices/.blob_t1/1/blobs"']), ('crate2', ['mv "/t/b/indices/.blob_t1/1/blobs" "/t/b/nodes/0/indices/.blob_t1/1/blobs"'])]))
    """
    ret, msg = False, OrderedDict()
    for node, path, blob_path in rows:
        if node not in msg:
            msg[node] = []
        path = pathlib.Path(path)
        blob_path = pathlib.Path(blob_path)
        try:
            blob_path.relative_to(path)
        except ValueError:
            ret = True
            msg[node].append('mv "{}" "{}"'.format(
                blob_path,
                get_target_path(str(path), str(blob_path))))
    return ret, msg


def has_path_diff(rows):
    """ Checks if there are any blob_paths that aren't childs of path

    >>> has_path_diff([
    ...     ('crate1', '/tmp/data1/x', '/tmp/data1/x/blobs'),
    ...     ('crate1', '/tmp/data2/x', '/tmp/data1/x/blobs'),
    ...     ('crate2', '/tmp/data1/x', '/tmp/data1/x/blobs'),
    ...     ('crate2', '/tmp/data2/x', '/tmp/data1/x/blobs'),
    ... ])
    (True, OrderedDict([('crate1', ['mv "/tmp/data1/x/blobs" "/tmp/data2/x"']), ('crate2', ['mv "/tmp/data1/x/blobs" "/tmp/data2/x"'])]))
    """
    ret, msg = False, OrderedDict()
    for node, path, blob_path in rows:
        if node not in msg:
            msg[node] = []
        path = pathlib.Path(path)
        blob_path = pathlib.Path(blob_path)
        try:
            blob_path.relative_to(path)
        except ValueError:
            ret = True
            msg[node].append('mv "{}" "{}"'.format(blob_path, path))
    return ret, msg


def exit_if_multiple_data_paths(c):
    c.execute("select fs['data']['path'] from sys.nodes")
    fs_data_path_rows = c.fetchall()

    c.execute("select _node['hostname'] as node, path, blob_path from sys.shards \
              where schema_name = 'blob' and path is not null order by 1, 2")
    path_and_blob_paths = c.fetchall()
    if any(len(row[0]) > 1 for row in fs_data_path_rows):
        ret, msg = has_path_diff(path_and_blob_paths)
        if ret:
            warn('WARNING: Multiple path.data paths have been found. Migration is required!')
            warn('Move the blob paths to their new location using the following commands on the given hosts:')
            info_grouped(msg)
            sys.exit(ret)


def exit_if_custom_blob_path_set(c):
    c.execute("select _node['hostname'] as node, path, blob_path from sys.shards \
              where schema_name = 'blob' and path is not null order by 1, 2")
    path_and_blob_paths = c.fetchall()
    ret, msg = has_custom_blob_path(path_and_blob_paths)
    if ret:
        warn('WARNING: A custom blob path set. Migration is required!')
        warn('Move the blob paths to their new location using the following commands on the given hosts:')
        info_grouped(msg)
        sys.exit(ret)


def to_version_tuple(v):
    major, minor, hotfix = v.split('.', maxsplit=3)
    return (int(major), int(minor), int(hotfix))


def exit_if_invalid_crate_version(c):
    c.execute("select version['number'] from sys.nodes")
    res = c.fetchall()
    if not all(to_version_tuple(v) >= (0, 57, 3) for (v,) in res):
        error('Some nodes in the cluster run a version lower than 0.57.3.')
        warn('Please upgrade your cluster to the latest 0.57 version first!')
        sys.exit(1)
    if not all(to_version_tuple(v) < (0, 58, 0) for (v,) in res):
        error('Some nodes in the cluster run a version greater of equal than 1.0.0.')
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(prog='migrate.py',
                                     description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--host', type=str, default='localhost:4200')
    parser.add_argument('--self-test', action='count')
    args = parser.parse_args()
    if args.self_test:
        import doctest
        doctest.testmod()
        return

    info('Running migration test against {}', args.host)
    conn = connect(servers=args.host)
    c = conn.cursor()

    exit_if_invalid_crate_version(c)
    exit_if_no_blob_tables(c)
    # TODO: warn that shard allocation should be turned off?
    exit_if_multiple_data_paths(c)
    exit_if_custom_blob_path_set(c)
    ok('No migration required.')
    sys.exit(0)


if __name__ == "__main__":
    main()
