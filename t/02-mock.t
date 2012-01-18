use strict;
use warnings;
use 5.010;

use Test::TCP;
use YAML::Syck;
use Test::More;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };
use Mouse::Object;

use AnyEvent::Peer39;

plan tests => 2;

my %tests = (
    'secret' => { pu => 'http://foo', status => 'done' },
    'secre'  => { pu => 'http://foo', status => 'error' },
);

test_tcp(
    client => sub {
        my $port = shift;
        my $url = "http://localhost:$port";

        foreach my $test (keys %tests){
            my $client = AnyEvent::Peer39->new(
                api_key  => $test,
                base_url => $url,
            );
            my $cv = AE::cv;
            $cv->begin;

            my $cb = Mouse::Object->new();
            $cb->meta->add_method(
                on_complete => sub {
                    my ($self, $res) = @_;
                    if ($tests{$test}->{status} eq 'done'){
                        ok $res->is_done;
                    }else{
                        fail "this test should fail";
                    }
                    $cv->end;
                }
            );
            $cb->meta->add_method(
                on_failure => sub {
                    my ($self, $res) = @_;
                    if ($tests{$test}->{status} eq 'error'){
                        is $res, 'Authentication Error';
                    }else{
                        fail "this test should not fail";
                    }
                    $cv->end;
                }
            );
            $client->get_page_info({
                remote_url => $tests{$test}->{pu},
                cb         => $cb
            });
            $cv->recv;
        }
    },
    server => sub {
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
                    my $headers = defined $content->{headers} ?  $content->{headers} : [];
                    return $respond->([200, $headers, [$content->{body}]]);
                }
            }
        };

        my $server = Plack::Handler::Twiggy->new(
            host => '127.0.0.1',
            port => $port,
        )->run($app);
    },
);
