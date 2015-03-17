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

**How many domains have warnings?**

    db.domains.find({result: { $elemMatch: { level: 'ERROR' }}}).count()

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

**Use aggregate to get all matching log entries with a certain error level:**

    db.domains.aggregate(
      { $match: { "name": "example.com", "result.level": "ERROR" } },
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

    db.domains.aggregate(
      [
        { $unwind : "$result" },
        { $match: { "result.level": "ERROR" } },
        { $group: { _id: "$name", errors: { $sum: 1} } },
        { $sort : { errors : -1 } },
        { $limit : 25 }
      ]
    );
		    
**Get the toplist of most popular set of name servers:**

    db.domains.aggregate(
      { $match: { "result.tag": "HAS_GLUE" } },
      { $unwind : "$result" },
      { $match: { "result.tag": "HAS_GLUE" } },
      { $project: { "name": 1, "result.args": 1, "_id": 0 } },
      { $group: { _id: "$result.args.ns", nscount: { $sum: 1 } } },
      { $sort : { nscount : -1 } },
      { $limit: 25 }
    );

**Get the toplist of most popular set of name servers with ERRORs:**

    db.domains.aggregate(
      { $match: { "result.tag": "HAS_GLUE", "result.level": "ERROR" } },
      { $unwind : "$result" },
      { $match: { "result.tag": "HAS_GLUE" } },
      { $project: { "name": 1, "result.args": 1, "_id": 0 } },
      { $group: { _id: "$result.args.ns", nscount: { $sum: 1 } } },
      { $sort : { nscount : -1 } },
      { $limit: 25 }
    );

**Get the toplist of most common errors:**

    db.tlds.aggregate(
      { $unwind: "$result" },
      { $match: { "result.level": "ERROR" } },
      { $group: { _id: "$result.tag", errors: { $sum: 1 } } },
      { $sort: { errors: -1 } },
      { $limit: 25 }
    );


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

