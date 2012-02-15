
use 5.10.0;
use common::sense;
use Test::TCP;
use YAML::Syck;
use Test::More;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy);
use Test::Requires { 'Plack::Request' => '0.99' };
use Mouse::Object;

use AnyEvent::Peer39;

plan tests => 3;

my @tests = (
    {
        key  => "secre",
        url  => "http://foo",
        type => "failure",
    },
    {
        key  => "secret",
        url  => "http://foo",
        type => "success",
    },
);

sub client {
    my $port     = shift;
    my $endpoint = "http://localhost:$port";

    my $cv = AE::cv;

    for my $test (@tests) {
        $cv->begin;

        my $client = AnyEvent::Peer39->new(
            api_key  => $test->{key},
            base_url => $endpoint,
        );

        $client->get_page_info(
            remote_url => $test->{url},
            cb         => sub {
                my ($response) = @_;

                given ($test->{type}) {
                    when ("failure") {
                        ok $response->is_failure, "Expected failure";
                        is $response->message, "Authentication Error";
                    }
                    when ("success") {
                        ok $response->is_success, "Expected success";
                    }
                    default {
                        fail "Broken plan";
                    }
                }

                $cv->end;
            },
        );
    }

    $cv->recv;
}

sub server {
    my $port = shift;

    my $app = builder {
        mount '/proxy/targeting' => sub {
            my $env = shift;
            my $req = Plack::Request->new($env);
            my $key = $req->param('cc');

            return sub {
                my $respond = shift;

                my $file = 't/data/'.$key;
                my $content = LoadFile($file);
                my $headers = $content->{headers} // [];
                return $respond->([200, $headers, [$content->{body}]]);
            }
        }
    };

    my $server = Plack::Handler::Twiggy->new(
        host => '127.0.0.1',
        port => $port,
    )->run($app);
}

test_tcp(
    client => \&client,
    server => \&server,
);
