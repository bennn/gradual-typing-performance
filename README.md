gradual-typing-performance : remove-io
===

This is an experimental branch.

It removes all I/O from the timed parts of the benchmarks.
Hoping this does not change the results but we will see.




# I/O Action Table

Key:
- IO is the kind of input/output action the benchmark does
  - `print` : prints output
  - `file I` : reads from a file
  - `file O` : writes to a file
  - `random` : invokes a (seeded) random number generator

- `action` is what I did to remove the IO
  - `removed` : the IO is just gone
  - `pre-load` : I now read the file into a list before the timed computation
  - `API` : an existing interface had to change to get the IO out of the timed
    computation
  - `replay` : I recorded values from the "IO", saved them to a file,
    and for the benchmark read this file to a list & use it

NOTE:
- dungeon originally used random variables, but these were removed long ago


| Benchmark  | IO                           | action           |
|------------+------------------------------+------------------|
| sieve      | print                        | removed          |
| forth      | file I                       | pre-load         |
| fsm        | random                       | replay           |
| fsmoo      | random                       | replay           |
| mbta       |                              | N/A              |
| morsecode  |                              | N/A              |
| zombie     | file I                       | pre-load         |
| zordoz     | file I                       | pre-load, API    |
| lnm        | file I/O                     | pre-load, API    |
| suffixtree | file I                       | pre-load         |
| kcfa       |                              | N/A              |
| snake      | file I, random               | pre-load, replay |
| take5      |                              | N/A              |
| tetris     | file I, random               | pre-load, replay |
| synth      | random                       | replay           |
| gregor     | current-inexact-milliseconds |                  |
| quadBG     | file O                       | remove           |
| quadMB     | file O                       | remove           |
| dungeon    |                              | N/A              |
| acquire    | random                       | replay           |
