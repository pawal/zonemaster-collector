package TLDMonitor::Log;

use 5.14.2;
use warnings;
use strict;
use Moose;
use Switch;

has 'log' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

# formatted output from the log
sub output {
    my $self = shift;

    my @output;
    foreach my $entry ( @{$self->log->{'result'}} ) {
	next if $entry->{'module'} eq 'SYSTEM';
	my $new;
	$new->{'level'} = $entry->{'level'};
	$new->{'module'} = $entry->{'module'};
	$new->{'tag'} = $entry->{'tag'};
	$new->{'args'} = _format_tags( $entry->{'args'}, $entry->{'tag'} );
	push @output, $new;
    }
    return \@output;
}

# same as above, but without formatting
sub raw_output {
    my $self = shift;

    my @output;
    foreach my $entry ( @{$self->log->{'result'}} ) {
	next if $entry->{'module'} eq 'SYSTEM';
	my $new;
	$new->{'level'} = $entry->{'level'};
	$new->{'module'} = $entry->{'module'};
	$new->{'tag'} = $entry->{'tag'};
	$new->{'args'} = $entry->{'args'};
	push @output, $new;
    }
    return \@output;
}

# format the tag content
sub _format_tags {
    my ( $args, $tag ) = @_;
    my $html;
    foreach my $key ( keys %{$args} ) {
	my $content;
	switch( $key ) {
	    case 'ns' { $content = "<a href=\"/ns/".$args->{ $key }."\">".
			    $args->{ $key }."</a>" }
	    case 'nsnlist' { $content = join "$_<br/>",split /,/,$args->{ $key } }
	    case 'nsset'   { $content = join "$_<br/>",split /,/,$args->{ $key } }
	    case 'glue'    { $content = join "$_<br/>",split /;/,$args->{ $key } }
	    case 'names'   { $content = join "$_<br/>",split /[;|,]/,$args->{ $key } }
	    case 'servers'  { $content = join "$_<br/>",split /;/,$args->{ $key } }
	    case 'address' { $content = "<a href=\"/address/".
				 $args->{ $key }."\">".$args->{ $key }."</a>" }
	    case 'asn' {
		if ( $tag eq 'NAMESERVERS_IPV4_WITH_UNIQ_AS' or
		     $tag eq 'NAMESERVERS_IPV6_WITH_UNIQ_AS' or
		     $tag eq 'NAMESERVERS_WITH_UNIQ_AS' ) {
		    $content .= "<a href =\"/asn/".$args->{ $key }."\">".
			$args->{ $key }."</a> ";
		} else {
		    if ( ref( $args->{ $key } ) eq 'ARRAY' ) {
			foreach ( @{ $args->{ $key } } ) {
			    $content .= "<a href=\"/asn/$_\">$_</a> ";
			}
		    }
		}
	    }
	    else { $content = $args->{ $key }; }
	}
	$content = '' if not defined $content;
	$html .= "$key: $content<br>";
    }
    return $html;
}

no Moose; # keywords are removed from the Person package
__PACKAGE__->meta->make_immutable;

1;
