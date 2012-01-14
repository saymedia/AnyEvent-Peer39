package AnyEvent::Peer39;

use 5.010;

use Mouse;
use AnyEvent::HTTP;
use Data::Validator;

has base_url => ( is => 'ro', isa => 'Str', required => 1,);
has api_key  => ( is => 'ro', isa => 'Str', required => 1,);
has timeout  => ( is => 'ro', isa => 'Int', default  => 1,);

has targeting_path => (
    is      => 'ro',
    isa     => 'Str',
    default => '/proxy/targeting',
);

has _api_url => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $uri = sprintf "%s%s?cc=%s", 
            $self->base_url,
            $self->targeting_path,
            $self->api_key;
        return $uri;
    }
);

has short_response_format_parser => (
    is      => 'ro',
    isa     => 'RegexpRef',
    default => sub {
        qr/
            ^(?<version>\d+)
            \#(?<resp_type>\d)
            \;(?<lng_code>\w+|00)
            \#(?<cids>[^#]+)
            \#(?<adstats>.*)\#$
        /x;
    }
);

sub get_page_info {
    state $rule = Data::Validator->new(
        'remote_url' => 'Str',
        'cb'         => 'CodeRef',
    )->with('Method');

    my ($self, $args) = $rule->validate(@_);

    my $uri = $self->_build_uri($args->{remote_url});

    http_get $uri, timeout => $self->timeout, sub {
        my ($headers, $body) = @_;

        # XXX waiting for my kvm to be fixed so I can query peer39 endpoint
        #if ($headers->{Status} == 200){
            my $struct = $self->_parse_body($body);
            $args->{cb}->($struct);
        #}else{
        #}
    }
}

sub _build_uri {
    my ($self, $remote_url) = @_;
    return sprintf "%s&pu=%s", $self->_api_url, $remote_url;
}

sub _parse_body {
    my ($self, $body) = @_;
    
    my $re = $self->short_response_format_parser;
    if ($body =~ /$re/){
        return AnyEvent::Peer39::Response->new(
            version  => $+{version},
            type     => $+{resp_type},
            language => $+{lng_code},
            cids     => $+{cids},
            adstats  => $+{adstats},
        );
    }
    return undef;
}

package AnyEvent::Peer39::Response;

use Mouse;
use Mouse::Util::TypeConstraints;

subtype 'CID'      => as 'ArrayRef';
subtype 'Language' => as 'Str' => where {$_ ne 0};

coerce 'CID' => from 'Str' => via {
    my $strs = $_; 
    my @cids = split /;/, $strs;
    @cids = map {
        my ($cat, $indice) = split/:/, $_;
        {categorie => $cat, indice => $indice};
    } @cids;
    return \@cids;
};

coerce 'Language' => from 'Str' => via {return 'Unknown'};

# XXX need to do something with the version number at some point
has version  => (is => 'ro', isa => 'Int', required => 1);
has type     => (is => 'ro', isa => 'Int', required => 1);
has adstats  => (is => 'ro', isa => 'Str');

has cids     => (is => 'ro', isa => 'CID',      required => 1, coerce => 1);
has language => (is => 'ro', isa => 'Language', required => 1, coerce => 1);

sub is_done {
    my $self = shift;
    $self->type == 0 ? return 1 : return 0;
}

sub is_failure {
    my $self = shift;
    $self->type == 1 ? return 1 : return 0;
}

sub is_pending {
    my $self = shift;
    $self->type == 2 ? return 1 : return 0;
}

1;

__END__

=head1 SYNOPSIS

    use strict;
    use warnings;
    use 5.010;

    use AnyEvent::Peer39;
    use AnyEvent;

    my $client = AnyEvent::Peer39->new(
        base_url => 'http://api.peer39.net',
        api_key  => 'secret_key',
    );

    my $cv = AnyEvent->condvar();
    $cv->begin;

    my $cb = sub {
        my $res = shift;
        if ($res->is_done){
            say $res->language;
        }else{
            say "failed";
        }
        $cv->end;
    };

    $client->get_page_info({remote_url => 'http://www.techcrunch.com/', cb => $cb});
    $cv->recv;
