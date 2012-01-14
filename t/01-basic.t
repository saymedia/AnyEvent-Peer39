use strict;
use warnings;
use 5.010;

use AnyEvent::Peer39;
use Test::More;

plan tests => 4;

my $client = AnyEvent::Peer39->new(
    api_key => 'secret',
    base_url => 'http://api.peer39.net',
);

my $url = $client->_build_uri('http://foo');
is $url, 'http://api.peer39.net/proxy/targeting?cc=secret&pu=http://foo';

my $body = "004#0;en#3994:90;9408:80;4989:61;4990:61;4991:61;4992:61;5023:61;5021:61;5302:61;8803:61;5344:61;5820:60;5840:60;5841:60;5842:60;6123:60;6124:60;##";

my $struct = $client->_parse_body($body);

isa_ok($struct, 'AnyEvent::Peer39::Response');
is $struct->language, 'en';
is(ref $struct->cids->[0], 'HASH');
