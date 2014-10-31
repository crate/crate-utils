======================
JSON conversion script
======================

convert_json.py is a python script to convert MongoDB Extended JSON to JSON
without type information.


For example the following JSON structure::

    {
        "vector": [
            {
            "$int": -67
            },
            {
            "$int": -6
            },
            {
            "$int": -1
            }
        ]
    }

will be converted to::

    {
        "vector": [
            -67,
            -6,
            -1
        ]
    }


Usage
=====

::

    > python convert_json.py -h
    usage: convert_json [-h] [-i [INPUT]] [-o [OUTPUT]]

    optional arguments:
        -h, --help            show this help message and exit
        -i [INPUT], --input [INPUT]
        -o [OUTPUT], --output [OUTPUT]
