===========
csv2json.py
===========

``csv2json.py`` is a Python script to convert csv (output from MySQL) to JSON


For example the following CSV file::

  1,"foo",1414743776000
  2,"bar",\N


can be converted to::

  {"id": 1, "name": "foo", "ts": 1414743776000}
  {"id": 2, "name": "bar", "ts": null}

using the following command::

  $ cat output.csv | python csv2json.py - \
        --columns id:integer name:string ts:timestamp


