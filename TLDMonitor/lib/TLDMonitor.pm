package TLDMonitor;
use Dancer ':syntax';
use MongoDB;
#use Template::Iterator;
use TLDMonitor::Log;

# global options
my $database = 'results';
my $collection = 'tlds';

# runtime variables
my $mongoclient;
my $mongodb;
my $mongocoll;

# Connect to MongoDB
$mongoclient = MongoDB::MongoClient->new( host => 'localhost', port => 27017 );
$mongodb     = $mongoclient->get_database( $database );
$mongocoll   = $mongodb->get_collection( $collection );

our $VERSION = '1.0';

hook after => sub {
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
};

get '/' => sub {
    my $result = $mongocoll->aggregate([
	{ '$project' => { 'name' => 1, 'level' => 1, '_id' => 0 } },
	{ '$sort' => { 'name' => 1 } },
    ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    template 'index', { all => $result };
};

get '/domain/:domain' => sub {
    my $it = $mongocoll->find( {"name" => lc params->{'domain'} } );
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
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.tag' => $tag } },
	{ '$project' => { 'name' => 1, 'level' => 1, '_id' => 0 } },
	{ '$sort' => { 'name' => 1 } },
    ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    template 'index', {
	all => $result,
	title => "Domains with the tag $tag",
    };
};

get '/address/:address' => sub {
    my $address = lc params->{'address'};
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.args.address' => $address } },
	{ '$sort' => { 'name' => 1 } } ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    template 'index', {
	all => $result,
	title => "Domains with the address $address",
    };
};

get '/ns/:ns' => sub {
    my $ns = lc params->{'ns'};
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.args.ns' => $ns } },
	{ '$sort' => { 'name' => 1 } } ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    template 'index', {
	all => $result,
	title => "Domains with the NS $ns",
    };
};

# this is crappy because of how arrays of ASNs are handled
get '/asn/:asn' => sub {
    my $asn = lc params->{'asn'};
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.args.asn' => $asn } },
	{ '$sort' => { 'name' => 1 } } ] );
    header( 'Cache-Control' => 'max-age=3600, must-revalidate' );
    template 'index', {
	all => $result,
	title => "Domains with the ASN $asn",
    };
};

true;
