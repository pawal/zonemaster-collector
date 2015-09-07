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

our $VERSION = '0.1';

get '/' => sub {
    my @all = $mongocoll->query()->fields({ 'name' => 1, '_id' => 0 })->all;
    template 'index', { all => \@all };
};

get '/domain/:domain' => sub {
    my $it = $mongocoll->find( {"name" => lc params->{'domain'} } );
    my $log = $it->next;
    my $logarray = $log->{'result'};
    my $logobj = TLDMonitor::Log->new(log => $log);
    template 'domain', {
	domain => lc params->{'domain'},
	log => $logobj->output };
};

get '/address/:address' => sub {
    my $address = lc params->{'address'};
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.args.address' => $address } } ] );
    template 'index', {
	all => $result,
	title => "Domains with the address $address",
    };
};

get '/ns/:ns' => sub {
    my $ns = lc params->{'ns'};
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.args.ns' => $ns } } ] );
    template 'index', {
	all => $result,
	title => "Domains with the NS $ns",
    };
};

# this is crappy because of how arrays of ASNs are handled
get '/asn/:asn' => sub {
    my $asn = lc params->{'asn'};
    my $result = $mongocoll->aggregate([
	{ '$match'   => { 'result.args.asn' => $asn } } ] );
    template 'index', {
	all => $result,
	title => "Domains with the ASN $asn",
    };
};

true;
