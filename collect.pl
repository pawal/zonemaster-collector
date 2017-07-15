#!/usr/bin/perl

use 5.014002;

#use forks;
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use MongoDB;
use Zonemaster;
use Zonemaster::Logger::Entry;
use Term::ANSIColor;
use JSON::PP;
use Pod::Usage;
use Getopt::Long;
use Data::Dumper; # not for debugging

# global program parameters
my $parallel = 10;      # number of threads
my $DEBUG    = 0;       # set to true if you want some debug output
my $level    = 'NOTICE'; # error level (DEBUG, NOTICE, INFO, WARNING, ERROR, CRITICAL)
my $outdir;             # output directory
my $filename;           # or filename
my $mongo;              # use MongoDB storage
my $database;           # which MongoDB database
my $collection;         # which MongoDB collection, WARNING - will be ERASED
my $append   = 0;       # Don't empty storage before running

# runtime variables
my $queue = Thread::Queue->new();
my %numeric = Zonemaster::Logger::Entry->levels;

sub runQueue {
    if ( defined $outdir ) {
	die "cannot create directory $outdir: $!" if not mkdir $outdir;
    } elsif ( not defined $mongo ) {
	die "No backend storage defined";
    }

    die 'no file for runQueue()'         if not defined $filename;
    say "Creating runqueue";
    open FILE, "$filename" or die "Cannot read file $filename: $!";
    while ( <FILE> ) {
	$queue->enqueue($_);
    }
    close FILE;

    say "Creating threads";
    threads->create( {}, 'processDomain' ) for ( 1 .. $parallel );

    # print status while there are running threads
    while( threads->list(threads::running) != 0 ) {
	print color 'yellow';
	print "Pending: ".$queue->pending()." - Running: ".threads->list( threads::running )."\n";
	print color 'reset';
	sleep( 2 );
    }

    # end running queue
    print color 'red';
    say "Waiting to finish the last items in the queue";
    # TODO: for some reasons this join() stuff sigfaults on my machine...
    # searching the web indicates an internal glibc problem
    $_->join foreach threads->list; #block until all threads done
    print color 'reset';
}

# run a test for a domain, output JSON
sub runTest {
    my ( $domain ) = @_;
    my @log;
    print color 'reset';
    say threads->tid().": $domain" if defined $filename; # only if many
    eval {
	Zonemaster->reset();
	@log = Zonemaster->test_zone( $domain );
    };
    if ( $@ ) {
	my $err = $@;
	say STDERR "Exited early for $domain: " . $err->message;
    }
    my $maxlevel = Zonemaster::logger->get_max_level();
    my $result = Zonemaster->logger->json( $level );
    return ( $result, $maxlevel );
}

sub processDomain {
    # init mongodb connection first in thread
    my ( $mongoclient, $mongodb, $mongocoll);
    if( defined $mongo and not defined $mongoclient) {
	say "Connecting to MongoDB" if $DEBUG;
	$mongoclient = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	$mongodb     = $mongoclient->get_database( $database );
	$mongocoll   = $mongodb->get_collection( $collection );
	#	$mongocoll->remove(); # YES, we remove all from collection first...
    }

    # begin dequeuing and processing
    while ( defined ( my $domain = $queue->dequeue_nb ) ) {
	chomp $domain;
	$domain =~ s/(.*)\.$/$1/;        # drop terminating dot
	return if not length( $domain ); # can be root or empty line

	# run actual test
	my ( $result, $level ) = runTest( $domain );

	# output result
	if( defined $outdir ) {
	    open(OUT, '>', "$outdir/$domain") or die $!;
	    print OUT $result;
	    close(OUT);
	} elsif ( defined $mongo ) {
	    $result = JSON::PP->new->utf8->decode( $result );
	    $mongocoll->insert( { 'name' => $domain,
				  'level' => $level,
				  'result' => $result } );
	}
    }
    say "Ending thread" if $DEBUG;
    threads->exit();
}

sub main {
    # non-global program parameters
    my $help = 0;
    my $name;
    GetOptions( 'help|?'       => \$help,
	        'name|n=s'     => \$name,
	        'file|f=s'     => \$filename,
	        'outdir|d=s'   => \$outdir,
	        'mongo'        => \$mongo,
	        'collection=s' => \$collection,
	        'db=s'         => \$database,
		'append'       => \$append,
	        'threads=i'    => \$parallel,
	        'level|l=s'    => \$level,
	        'debug'        => \$DEBUG )
	or pod2usage( 2 );
    pod2usage( 1 ) if( $help );
    pod2usage( 1 ) if( not defined $name and not defined $filename );
    pod2usage( 1 ) if( not defined $numeric{ uc $level } );
    if( defined $mongo and (
	    not defined $database or not defined $collection ) ) {
	say "Must defined database and collection if using MongoDB";
	exit;
    }

    # Clear MongoDB collection before running
    if( defined $mongo ) {
	my $mc  = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	my $mdb = $mc->get_database( $database );
	my $mcl = $mdb->get_collection( $collection );
	$mcl->remove() unless $append; # YES, we remove all from collection first (unless append)
    }

    if( defined $name ) {
	my ( $result, $level) = runTest( $name );
	print "Level: $level\n";
	print Dumper( from_json( $result ) );
    } elsif ( defined $filename or defined $mongo ) {
	runQueue( $filename );
    } else {
	say "No storage defined";
    }
    
}

main();


=head1 NAME

collect.pl

=head1 SYNOPSIS

   collect.pl.pl -n domain

    -n domain       specify name
    -f file.txt     read list of names from file
    -d outdir       create this directory and store result in if reading domains from file
    --mongo         store results in MongoDB
    --db            which MongoDB database
    --collection    which MongoDB collection
    --append        don't clear storage before running
    --threads       number of threads
    --level         Zonemaster severity level (default, DEBUG)
    --debug         debug mode

=head1 DESCRIPTION

   gets Zonemaster results for domain (outputs JSON)

   A collection of tests from file can also be store in the file system
   or in a MongoDB database collection.

   For file storage:

   collect.pl -f domains.txt -d output

   MongoDB:

   collect.pl -f domains.txt --mongo --db domains --collection results

=head1 AUTHOR

   Patrik Wallstrom <pawal@iis.se>

=cut
