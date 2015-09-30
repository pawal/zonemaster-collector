package TLDMonitor::Log;

use 5.14.2;
use warnings;
use strict;
use Moose;
use Switch;

has 'log' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

sub output {
    my $self = shift;

    my @output;
    foreach my $entry ( @{$self->log->{'result'}} ) {
	next if $entry->{'module'} eq 'SYSTEM';
	my $new;
	$new->{'level'} = $entry->{'level'};
	$new->{'module'} = $entry->{'module'};
	$new->{'tag'} = $entry->{'tag'};
	$new->{'args'} = _format_tags( $entry->{'args'} );
	push @output, $new;
    }
    return \@output;
}

sub _format_tags {
    my $args = shift;
    my $html;
    foreach my $key ( keys %{$args} ) {
	my $content;
	switch( $key ) {
	    case 'ns' { $content = "<a href=\"/ns/".$args->{ $key }."\">".
			    $args->{ $key }."</a>" }
	    case 'address' { $content = "<a href=\"/address/".
				 $args->{ $key }."\">".$args->{ $key }."</a>" }
	    case 'asn' {
		foreach ( @{ $args->{ $key } } ) {
		    $content .= "<a href=\"/asn/$_\">$_</a> ";
		}
	    }
	    else { $content = $args->{ $key }; }
	}
	$html .= "$key: $content<br>";
    }
    return $html;
}

no Moose; # keywords are removed from the Person package
__PACKAGE__->meta->make_immutable;

1;
