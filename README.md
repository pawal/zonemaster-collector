# Zonemaster collector

## Usage

This is a parrallelized collector for performing tests using Zonemaster
and to collect the results from the tests on either disk or a MongoDB.

Simple usage:

    $ ./collect-pl -f input.txt --mongo --db zonemaster --collection results

The default number of threads is 10, so it will run fast. To run more threads,
make sure you have enough memory.

You can also store Zonemaster results on disk instead of using MongoDB:

    $ ./collect-pl -f input.txt -d output --threads 20


## All command line options:

    -n domain       specify name
    -f file.txt     read list of names from file
    -d outdir       create this directory and store result in if reading domains from file
    --mongo         store results in MongoDB
    --db            which MongoDB database
    --collection    which MongoDB collection
    --threads       number of threads
    --level         Zonemaster severity level (default, DEBUG)
    --debug         debug mode


## Analyzing results

See the [How to Mongo](howtomongo.md) document on how to do same fancy
analyzing stuff with MongoDB.

If you want to do the similar type of analysis on the output directory
with files, I recommend the jq CLI tool: http://stedolan.github.io/jq/


## Depencencies

 * MongoDB
 * [zonemaster-engine](https://github.com/dotse/zonemaster-engine)

Other Perl modules:

 * Term::ANSIColor (for "fancy" output)
 * JSON Perl
 * forks (since Zonemaster is not yet 100% thread safe due to Net::LDNS)
