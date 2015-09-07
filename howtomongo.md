# How to do some MongoDB digging of Zonemaster results

## Start MongoDB

    $ mongo
    $ use results
    $ show collections

This selects your results database, and you can look at your collections.


## Some basic results

These tests assume that you have your results in the "domains" collection.


**How many domains are tested in this collection?**

    db.domains.count()

or get the list of domains with only the name:

    db.domains.find( {}, { "name": 1, "_id": 0 } );


**How many domains have warnings?**

    db.domains.find({result: { $elemMatch: { level: 'WARNING' }}}).count()

or

    db.domains.find({ "result.level": "WARNING" }, { "name": 1, "_id": 0 } )


**Find all domains that have ERRORS, and list one of the errors:**

    db.domains.find({ "result.level": "ERROR" }, { "result.$": 1, "name": 1, "_id": 0 } )

(This will not give you all errors in the results.)

The queries that gives you a lot of results will give you a very long list,
use the iterator command "it" to page through them.


**Find all domains using a certain name server:**

    db.domains.find({ "result.args.ns": "ns.example.com"},
      { "name": 1, "result.$.args": 1, "_id": 0 } );

(This depends on Zonemaster logging something with result.args.ns, the project is
working on cleaning up the names in the logging and harmonizing the results.
https://github.com/dotse/zonemaster-engine/issues/102)


**Use aggregate to get all matching log entries with a certain error level:**

    db.domains.aggregate(
      { $match: { "result.level": "ERROR" } },
      { $unwind: "$result" },
      { $match: {"result.level": "ERROR"}},
      { $project: { "name":1, "result": 1, "_id": 0 }} );

This will give you a new document for each log entry matching the query. The last
$project statement can be omitted if you don't need it.

To specify a single domain name to see the ERRORs for:

    db.domains.aggregate(
      { $match: {"name": "example.com", "result.level": "ERROR" } },
      { $unwind: "$result" },
      { $match: {"result.level": "ERROR" } } );


**Get the toplist of domains with most errors:**

Not very useful, but a good example of the query langague used.

    db.domains.aggregate(
      [
        { $unwind : "$result" },
        { $match: { "result.level": "ERROR" } },
        { $group: { _id: "$name", errors: { $sum: 1} } },
        { $sort : { errors : -1 } },
        { $limit : 25 }
      ]
    );


**Calculate total numbers of "errors" grouped by level for domain**

    db.domains.aggregate([
      { $unwind : "$result" },
      { $group: {
        "_id": {
          "name": "$name",
          "level": "$result.level"
        },
        "total": { "$sum": 1 }
      } },
    ]);


**Get the toplist of most popular set of name servers:**

(Requires log data on the DEBUG level, and depends on args.nsnlist to be the the
set of name servers.)

    db.domains.aggregate(
      { $match: { "result.tag": "HAS_GLUE" } },
      { $unwind : "$result" },
      { $match: { "result.tag": "HAS_GLUE" } },
      { $project: { "name": 1, "result.args": 1, "_id": 0 } },
      { $group: { _id: "$result.args.nsnlist", nscount: { $sum: 1 } } },
      { $sort : { nscount : -1 } },
      { $limit: 25 }
    );

**Get the toplist of most popular set of name servers with ERRORs:**

(Requires log data on the DEBUG level.)

    db.domains.aggregate(
      { $match: { "result.level": "ERROR" } },
      { $unwind: "$result" },
      { $match: { "result.args.nsnlist": { $exists: true } } },
      { $project: { "name":1, "result": 1, "_id": 0 } },
      { $group: { _id: "$result.args.nsnlist", nscount: { $sum: 1 } } },
      { $sort: { nscount: -1 } },
      { $limit: 25 }
    );


Same with CRITICAL (harder because lack of nsset, can match source sometimes):

    db.domains.aggregate(
      { $match: { "result.level": "CRITICAL" } },
      { $unwind: "$result" },
      { $match: { "result.args.nsnlist": { $exists: true } } },
      { $project: { "name":1, "result": 1, "_id": 0 } },
      { $group: { _id: "$result.args.nsnlist", nscount: { $sum: 1 } } },
      { $sort: { nscount: -1 } },
      { $limit: 25 }
    );


**Find the name of a CRITICAL domain with a certain nameserver-set:**

    db.domains.aggregate(
      { $match: { "result.level": "CRITICAL" } },
      { $match: { "result.args.source": "ns1.svenska-domaner.se/46.22.119.39" } },
      { $project: { "name": 1, "_id": 0 } }
    );

or

    db.domains.aggregate(
      { $match: { "result.level": "CRITICAL" } },
      { $match: { "result.args.nsnlist": "ns1.loopia.se.,ns2.loopia.se." } },
      { $project: { "name": 1, "_id": 0 } }
    );


**Find domains with a certain nameserver that has ERROR:**

    db.domains.aggregate(
      { $match: { "result.level": "ERROR" } },
      { $unwind: "$result" },
      { $match: { "result.level": "ERROR" } },
      { $match: { "result.args.ns": "ns5.binero.se" } },
      { $sort: { "name": 1 } },
      { $project: { "name":1, "result.tag": 1, "result.args": 1, "_id": 0 } }
    );


**Get the toplist of most common errors:**

    db.domains.aggregate(
      { $unwind: "$result" },
      { $match: { "result.level": "ERROR" } },
      { $group: { _id: "$result.tag", errors: { $sum: 1 } } },
      { $sort: { errors: -1 } },
      { $limit: 25 }
    );


**Find name servers that are open resolvers, and count domains using them:**

    db.domains.aggregate(
      { $match: { "result.tag": "IS_A_RECURSOR" } },
      { $unwind: "$result" },
      { $match: { "result.tag": "IS_A_RECURSOR" } },
      { $project: { "name":1, "result": 1, "_id": 0 } },
      { $group: { _id: "$result.args.ns", nscount: { $sum: 1 } } },
      { $sort: { nscount: -1 } },
      { $limit: 25 }
    );


**Find name servers that have name servers that are not reachable, NS_FAILED:**

    db.domains.aggregate(
      { $match: { "result.tag": "NS_FAILED" } },
      { $unwind: "$result" },
      { $match: { "result.tag": "NS_FAILED" } },
      { $project: { "name":1, "result": 1, "_id": 0 } },
      { $group: { _id: "$result.args.source", nscount: { $sum: 1 } } },
      { $sort: { nscount: -1 } },
      { $limit: 25 }
    );


**Find all domains that has a result tag ...**

    db.domains.aggregate(
      { $match: { "result.tag": "NAMESERVER_NO_TCP_53" } },
      { $unwind : "$result" },
      { $match: { "result.tag": "NAMESERVER_NO_TCP_53" } },
      { $project: { "name": 1, "result.tag": 1, "result.args": 1, "_id": 0 } }
    );


**Group all error levels and count them:**

TODO

    db.domains.aggregate(
      { $unwind : "$result" },
      { $project: { "name": 1, "result.level": 1, "_id": 0 } },
      { $group: { _id: "$result.level", count: { $sum: 1 } } },
      { $sort : { NScount : -1 } }
    );


**Get all unique tags from the collection:**

db.domains.runCommand({ distinct: 'tlds', key: "result.tag" } )


**Count number of domains with a certal log level:**

    db.domain.group( {
      key: { level: 1 },
      reduce: function(cur, result) { result.count += 1 },
      initial: { count: 0 }
    } )

**List only the log levels from current set of domains:**

    db.tlds.distinct( "level" );

**List the current set of log messages from all domains:**

    db.tlds.distinct( "result.tag" );

## Add indices

If you will repeatedly perform certain MongoDB queries, consider adding
and index to your document on the key you will query for:

    > db.domains.ensureIndex( { "result.level": 1 } )
    > db.domains.ensureIndex( { "result.tag": 1 } )

Note that this will result in index entries for each level of the whole
result array.

    > db.domains.ensureIndex( { "name": 1 } )

Creates an index on the domain name.

## Use functions

To use cursors on aggregate queries (see above for examples), you must
use MongoDB 2.6 and above.

Use the cursor:

    > var cursor = db.tlds.find({ "result.level": "ERROR" }, { "result.$": 1, "name": 1, "_id": 0 } );
    > cursor.forEach( function(x) { print(x.name); } );

