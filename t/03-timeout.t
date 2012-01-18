use strict;
use warnings;
use 5.010;

use Test::TCP;
use Test::More;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy);
use Test::Requires { 'Plack::Request' => '0.99' };
use Mouse::Object;

use AnyEvent::Peer39;

plan tests => 1;

test_tcp(
    client => sub {
        my $port = shift;
        my $url = "http://localhost:$port";

        my $client = AnyEvent::Peer39->new(
            api_key  => 'secret',
            base_url => $url,
        );
        my $cv = AE::cv;
        $cv->begin;

        my $cb = Mouse::Object->new();
        $cb->meta->add_method(on_complete => sub {});
        $cb->meta->add_method(
            on_failure => sub {
                is $_[1], 'Connection timed out';
                $cv->end;
            }
        );
        $client->get_page_info({
            remote_url => 'http://foo',
            cb         => $cb
        });
        $cv->recv;
    },
    server => sub {
        my $port = shift;

        my $app = builder {
            mount '/proxy/targeting' => sub {
                return sub {
                    sleep 2;
                    return shift->([204, [], ['']]);
                }
            }
        };

        my $server = Plack::Handler::Twiggy->new(
            host => '127.0.0.1',
            port => $port,
        )->run($app);
    },
);
