#!/usr/bin/perl

use 5.014002;

use forks;
use strict;
use warnings;

use MongoDB;
use Zonemaster;
use Zonemaster::Logger::Entry;
use Thread::Queue;
use Term::ANSIColor;
use JSON -support_by_pp;
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

# runtime variables
my $mongoclient;
my $mongodb;
my $mongocoll;
my $queue = Thread::Queue->new();
my %numeric = Zonemaster::Logger::Entry->levels;

$SIG{PIPE} = \&nullHandler;
$SIG{INT}  = \&friendlyQuit;

# handle PIPE signal
sub tonull {
    say "SIGPIPE received";
}

# handle SIGINT
sub friendlyQuit {
    # TODO: can we do something better?
    print color 'reset';
    print "Quitting\n";
}

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
    threads->create( {'stack_size' => 32*4096}, 'processDomain' ) for ( 1 .. $parallel );

    while( threads->list(threads::running) != 0 and $queue->pending() ) {
	print color 'yellow';
	print "Pending: ".$queue->pending()." - Running: ".threads->list( threads::running )."\n";
	print color 'reset';
	sleep( 2 );
    }
    print color 'red';
    print "Waiting to finish the last items in the queue\n";
    $_->join foreach threads->list; #block until all threads done
    print color 'reset';
}

# run a test for a domain, output JSON
sub runTest {
    my ( $domain ) = @_;
    my @log;
    print color 'reset';
    say $domain;
    eval {
	Zonemaster->reset();
	@log = Zonemaster->test_zone( $domain );
    };
    if ( $@ ) {
	my $err = $@;
	say STDERR "Exited early for $domain: " . $err->message;
    }
    return Zonemaster->logger->json( $level );
}

sub processDomain {
    while (defined(my $domain = $queue->dequeue_nb)) {
	chomp $domain;
	my $result = runTest( $domain );

	if( defined $mongo and not defined $mongoclient) {
	    $mongoclient = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
	    $mongodb     = $mongoclient->get_database( $database );
	    $mongocoll   = $mongodb->get_collection( $collection );
	    #	$mongocoll->remove(); # YES, we remove all from collection first...
	}

	# output result
	if( defined $outdir ) {
	    open(OUT, '>', "$outdir/$domain") or die $!;
	    print OUT $result;
	    close(OUT);
	} elsif ( defined $mongo ) {
	    $result = JSON->new->utf8->decode( $result );
	    $mongocoll->insert( { 'name' => $domain, 'result' => $result } );
	}
    }
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
	my $mdb = $mongoclient->get_database( $database );
	my $mcl = $mongodb->get_collection( $collection );
	$mcl->remove(); # YES, we remove all from collection first...
    }

    if( defined $name ) {
	my $result = runTest( $name );
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
