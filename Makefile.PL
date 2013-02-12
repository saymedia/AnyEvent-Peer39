use ExtUtils::MakeMaker;
WriteMakefile(
    NAME          => 'AnyEvent::Peer39',
    VERSION_FROM  => 'lib/AnyEvent/Peer39.pm',
    ABSTRACT_FROM => 'lib/AnyEvent/Peer39.pm',
    AUTHOR        => 'SayMedia',
    PREREQ_PM     => {
        Mouse           => 0,
        AnyEvent::HTTP  => 0,
        Data::Validator => 0,
        URI::Escape => 0,
    },
    BUILD_REQUIRES => {
        Test::TCP => 0,
        YAML::Syck => 0,
        Test::Requires => 0,
        Plack => 0,
        Plack::Request => '0.99',
        Plack::Handler::Twiggy => 0,
    },
);
