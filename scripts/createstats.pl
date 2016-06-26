#!/usr/bin/env perl

use strict;
use warnings;

use MongoDB;
use Pod::Usage;
use Getopt::Long;
use List::MoreUtils qw(uniq);;

use Data::Dumper;

# global program parameters
my $db = 'marknad';
my $collection;
my $suffix = '_stats'; # suffix for new statistics collections
my $topmax = 100;      # max length of toplist
my $append = 0;        # append to the new collection, no deletes
my $verbose = 1;
my $DEBUG = 0;

# runtime variables
my $mongoclient;
my $mongodb;

# asn->{v4|v6|total}->[{asn},{count}]
sub asnAnalyze {
    my $c = shift;
    my $asnStats;
    
    my $it = $c->find( );
    while ( my $log = $it->next ) {
	print $c->name.": ".$log->{'name'} if $DEBUG;
	my ( @asn_t, @asn_4, @asn_6 );
	foreach ( @{ $log->{ 'result' } } ) {
	    my $tag = $_->{'tag'};
	    # collect ASN for domain
	    if ( $tag eq 'IPV4_ASN' ) {
		# separate for IPv4
		@asn_4 = @{ $_->{'args'}->{'asn'} };
	    }
	    elsif ( $tag eq 'IPV6_ASN' ) {
		# separate for IPv6
		@asn_6 = @{ $_->{'args'}->{'asn'} };
	    }
	}

	# collect all categories
	@asn_t = uniq ( @asn_4, @asn_6 );
	map { $asnStats->{'total'}->{$_}++ } @asn_t;
	map { $asnStats->{'v4'}->{$_}++ }    @asn_4;
	map { $asnStats->{'v6'}->{$_}++ }    @asn_6;
	map { print " $_"; } @asn_t if $DEBUG;
	print "\n" if $DEBUG;
    }

    # sort into toplists
    my $toplist;
    foreach my $tag ( qw/total v4 v6/ ) {
	my $i = 0;
	foreach my $as ( sort { $asnStats->{$tag}->{$b} <=>
				    $asnStats->{$tag}->{$a} }
			 keys %{$asnStats->{$tag}} ) {
	    push @{$toplist->{$tag}}, { 'asn' => $as, 'count' => $asnStats->{$tag}->{$as} };
	    last if ++$i > $topmax;
	}
    }
    return $toplist;
}

# tags->{critical|errors|warnings ...}->[{tag},{count}]
sub tagsAnalyze {
    my $c = shift;
    my $errorStats;

    my $it = $c->find( );
    while ( my $log = $it->next ) {
	my $tlog;
	# stats per log
	foreach ( @{ $log->{'result'} } ) {
	    $tlog->{ $_->{'level'} }->{ $_->{'tag'} }++;
	}
	# stats per domain from tlog
	foreach my $lvl ( keys %{ $tlog } ) {
	    foreach my $tag ( keys %{ $tlog->{$lvl} } ) {
		$errorStats->{$lvl}->{$tag}++;
	    }
	}
    }

    # sort into toplists
    my $toplist;
    foreach my $level ( keys %{$errorStats} ) {
	my $i = 0;
	foreach my $tag ( sort { $errorStats->{$level}->{$b} <=>
				 $errorStats->{$level}->{$a} }
			  keys %{$errorStats->{$level}} ) {
	    push @{$toplist->{$level}}, {
		'tag'   => $tag,
		'count' => $errorStats->{$level}->{$tag}
	    };
	    last if ++$i > $topmax;
	}
    }

    return $toplist;
}

# tag: ns, {nameserver|v4|v6}->[{ns},{count}]
sub nsAnalyze {
    my $c = shift;
    my $nsStats;

    my $it = $c->find( );
    while ( my $log = $it->next ) {
	my $ns; # local ns-counter
	# stats per log
	foreach ( @{ $log->{'result'} } ) {
	    next if $_->{'module'} eq 'SYSTEM';
	    if ( defined $_->{'args'}->{'ns'} ) {
		my $name = $_->{'args'}->{'ns'};
		my $addr = $_->{'args'}->{'address'};
		next if $name =~ /;/ or $name =~ /\//; # because ns is not fixed
		$ns->{'nameserver'}->{$name}++ if length( $name );
		if ( defined $addr ) {
		    $ns->{'v6'}->{$addr}++ if $addr =~ /:/;
		    $ns->{'v4'}->{$addr}++ if $addr =~ /\./;
		}
	    }
	}
	# stats per domain från $ns
	foreach my $key ( keys %{$ns} ) {
	    foreach my $p ( keys %{$ns->{$key}} ) {
		$nsStats->{$key}->{$p}++;
	    }
	}
    }

    # sort into toplists
    my $toplist;
    foreach my $tag ( keys %{$nsStats} ) {
	my $i = 0;
	foreach my $addr ( sort { $nsStats->{$tag}->{$b} <=>
				  $nsStats->{$tag}->{$a} }
			  keys %{$nsStats->{$tag}} ) {
	    push @{$toplist->{$tag}}, {
		'ns'   => $addr,
		'count' => $nsStats->{$tag}->{$addr}
	    };
	    last if ++$i > $topmax;
	}
    }

    # optional filtering of the long tail can be done here

    return $toplist;
}

sub analyzeCollection {
    my $coll = shift;

    print "Analyzing $coll\n" if $verbose;
    my $c      = $mongodb->get_collection( $coll );
    my $cstats = $mongodb->get_collection( $coll.$suffix );
    $cstats->drop if not $append;

    writeData( $cstats, asnAnalyze ( $c ), 'asn' );
    writeData( $cstats, tagsAnalyze( $c ), 'tags' );
    writeData( $cstats, nsAnalyze  ( $c ), 'ns' );
}

sub writeData {
    my $c = shift;
    my $data = shift;
    my $tag = shift;

    my $id = $c->insert( { 'tag' => $tag, 'data' => $data } );
    print "$id inserted for $tag\n" if $verbose;
    return $id;
}

sub createCollection {
    my $name = shift;

    return $db->get_collection( $name );
}

sub main {
    my $help = 0;
    GetOptions( 'help|?'     => \$help,
	        'db=s'       => \$db,
	        'c=s'        => \$collection,
		's|suffix=s' => \$suffix,
		't|top=s'    => \$topmax,
		'v|verbose'  => \$verbose,
		'debug|D'   => \$DEBUG )
	or pod2usage( 2 );
    pod2usage( 1 ) if ( $help );

    $mongoclient = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
    $mongodb     = $mongoclient->get_database( $db );

    # start doing analysis
    if ( not defined $collection ) {
	my @collections = $mongodb->collection_names;
	# iterate through ALL collections from the db
	foreach my $coll ( @collections ) {
	     # skip collections we dont need
	    next if $coll eq 'system.indexes' or $coll =~ /$suffix$/;
	    analyzeCollection( $coll );
	}
    } else {
	analyzeCollection( $collection );
    }
}

main();

=head1 NAME

createstats.pl

=head1 SYNOPSIS

   createstats.pl --db database

    --help          this help
    --db database   which mongodb database to connect to
    -c collection   only run stats on this collection
    -s suffix       use this "_suffix" to store the new collection
    -t n
    --top n         max length of toplists
    --verbose       verbose mode
    --debug         debug mode

=head1 DESCRIPTION

   Generates statistics as metadata on a Zonemaster collection from
   a MongoDB database.

   The default use is to collect statistics from all collections in
   a database. Statistics are for example the number of errors, the
   count of all ASN found and so on.

=head1 AUTHOR

   Patrik Wallstrom <pawal@blipp.com>

=cut
