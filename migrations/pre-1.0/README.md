# Migrate Blob Paths

Script to verify if a manual migration is required to upgrade from CrateDB
`0.57` to `1.0`.

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

After:

    <path.data.1>/    <-- contains blob data
    <path.data.2>/    <-- contains blob data

## Requirements

* Python >= 3.5
* crate

```
python3.5 -m venv env
source env/bin/activate
pip install -r requirements.txt
```

## Usage

```
python migrate.py --help
```

