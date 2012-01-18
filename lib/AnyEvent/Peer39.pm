package AnyEvent::Peer39;

use 5.010;

use Mouse;
use AnyEvent::HTTP;
use Data::Validator;
use Mouse::Util::TypeConstraints;

subtype 'CallBack'
    => as 'Object'
    => where {
        $_->meta->has_method('on_failure') && $_->meta->has_method('on_complete')
    };

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
        'cb'         => 'CallBack',
    )->with('Method');

    my ($self, $args) = $rule->validate(@_);

    my $uri = $self->_build_uri($args->{remote_url});

    http_get $uri, timeout => $self->timeout, sub {
        my ($body, $headers) = @_;

        if ($headers->{'content-type'} and $headers->{'content-type'} eq 'text/xml'){
            (my $reason) = $body =~ /message="([^\"]+)"/;
            return $args->{cb}->on_failure($reason);
        }

        my $struct = $self->_parse_body($body);
        $args->{cb}->on_complete($struct);
    }
}

sub _build_uri {
    my ($self, $remote_url) = @_;
    return sprintf "%s&pu=%s", $self->_api_url, $remote_url;
}

sub _parse_body {
    my ($self, $body) = @_;
    
    # meh
    $body =~ s/\r\n//;

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
subtype 'Language' => as 'Str' => where {$_ ne "00"};

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

    use AnyEvent;
    use AnyEvent::Peer39;
    use Mouse::Object;

    my $client = AnyEvent::Peer39->new(
        base_url => 'http://sandbox.api.peer39.net:8080',
        api_key  => 'NwH7OeBv/4cSJEcpby8fbowEVshWUO5xu1soA12uAYU=',
    );

    my $cv = AnyEvent->condvar();
    $cv->begin;

    my $cb = Mouse::Object->new();
    $cb->meta->add_method(
        on_complete => sub {
            my ($self, $res) = @_;
            if ($res->is_done){
                say "Done ! language is ".$res->language;
            }else{
                say "Not done yet";
            }
            $cv->end;
        }
    );
    $cb->meta->add_method(
        on_failure => sub {
            my ($self, $res) = @_;
            say "not ok -> $res";
            $cv->end;
        }
    );

    $client->get_page_info({
        remote_url => 'http://www.techcrunch.com/', 
        cb         => $cb
    });

    $cv->recv;

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 base_url (string)

Your base url to access the service

=head2 api_key (string)

Your API key to access the service

=head2 timeout (int)

Timeout, default 1 second

=head2 targeting_path (string)

path to reach the targeting path, default is B</proxy/targeting>

=head2 short_response_format_parser (regex)

regex to parse the short format

=head1 METHODS

=head2 get_page_info (remote_url => $url, cb => $cb)

=over 4

=item B<remote_url> (string)

=item B<cb> (object) should implement at least two methods: B<on_complete> and B<on_failure>

=back

