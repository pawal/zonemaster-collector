package TLDMonitor;

#use Dancer2 ':syntax';
use Dancer2;
use MongoDB;
use TLDMonitor::Log;

our $VERSION = '1.0';

# global options
my $database   = 'results';
my $collection = 'tlds';
my $stats      = $collection.'_stats';

# runtime variables
my $mongoclient;
my $mongodb;

# Connect to MongoDB
$mongoclient = MongoDB->connect();
$mongodb     = $mongoclient->get_database( $database );

get '/' => sub {
    my $c = $mongodb->get_collection( $collection );
    my $result = $c->aggregate([
	{ '$project' => { 'name' => 1, 'level' => 1, '_id' => 0 } },
	{ '$sort' => { 'name' => 1 } },
    ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @data = $result->all;
    template 'index', { all => \@data };
};

get '/domain/:domain.json' => sub {
    my $c = $mongodb->get_collection( $collection );
    my $it = $c->find( {"name" => lc params->{'domain'} } );
    my $log = $it->next;
    my $logarray = $log->{'result'};
    my $logobj = TLDMonitor::Log->new(log => $log);
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    header( 'Content-Type'  => 'application/json' );
    to_json( $logobj->raw_output );
};

get '/domain/:domain' => sub {
    my $c = $mongodb->get_collection( $collection );
    my $it = $c->find( {"name" => lc params->{'domain'} } );
    my $log = $it->next;
    my $logarray = $log->{'result'};
    my $logobj = TLDMonitor::Log->new(log => $log);
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    template 'domain', {
	domain => lc params->{'domain'},
	log => $logobj->output };
};

get '/tag/:tag' => sub {
    my $tag = uc params->{'tag'};
    my $c = $mongodb->get_collection( $collection );
    my $result = $c->aggregate([
	{ '$match'   => { 'result.tag' => $tag } },
	{ '$project' => { 'name' => 1, 'level' => 1, '_id' => 0 } },
	{ '$sort' => { 'name' => 1 } },
    ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @data = $result->all;
    template 'index', {
	all => \@data,
	title => "Domains with the tag $tag",
    };
};

get '/address/:address' => sub {
    my $address = lc params->{'address'};
    my $c = $mongodb->get_collection( $collection );
    my $result = $c->aggregate([
	{ '$match'   => { 'result.args.address' => $address } },
	{ '$sort' => { 'name' => 1 } } ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @data = $result->all;
    template 'index', {
	all => \@data,
	title => "Domains with the address $address",
    };
};

get '/ns/:ns' => sub {
    my $ns = lc params->{'ns'};
    my $c = $mongodb->get_collection( $collection );
    my $result = $c->aggregate([
	{ '$match'   => { 'result.args.ns' => $ns } },
	{ '$sort' => { 'name' => 1 } } ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @data = $result->all;
    template 'index', {
	all => \@data,
	title => "Domains with the NS $ns",
    };
};

get '/asn/:asn' => sub {
    my $asn = lc params->{'asn'};
    my $c = $mongodb->get_collection( $collection );
    my $result = $c->aggregate([
	{ '$match'   => { 'result.args.asn' => $asn } },
	{ '$sort' => { 'name' => 1 } } ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @data = $result->all;
    template 'index', {
	all => \@data,
	title => "Domains with the ASN $asn",
    };
};

get '/toplist/asn' => sub{
    # connect to stats collection
    my $c = $mongodb->get_collection( $stats );
    my $result = $c->aggregate([
	{ '$match'   => { 'tag' => 'asn' } } ]);
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @all = $result->all;
    template 'toplist_asn', {
	all => $all[0]->{'data'},
	stats => 'asn',
	title => 'ASN Toplists',
    };
};

get '/toplist/ns' => sub{
    # connect to stats collection
    my $c = $mongodb->get_collection( $stats );
    my $result = $c->aggregate([
	{ '$match'   => { 'tag' => 'ns' } } ]);
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @all = $result->all;
    template 'toplist_ns', {
	all => $all[0]->{'data'},
	stats => 'ns',
	title => 'Name Server Toplist',
    };
};

get '/toplist/tags' => sub{
    # connect to stats collection
    my $c = $mongodb->get_collection( $stats );
    my $result = $c->aggregate([
	{ '$match'   => { 'tag' => 'tags' } } ]);
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    my @all = $result->all;
    template 'toplist_tags', {
	all => $all[0]->{'data'},
	stats => 'ns',
	title => 'Log Tags Toplist',
    };
};

get '/about/zonemaster' => sub{ template 'about_zm.tt'; };
get '/about/tldmonitor' => sub{ template 'about_tldmon.tt'; };
true;
