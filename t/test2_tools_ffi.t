use Test2::V0 -no_srand => 1;
use Test2::Plugin::FFI::Package;
use Test2::Tools::FFI;

subtest 'ffi->runtime' => sub {

  my $ffi = ffi->runtime;
  isa_ok $ffi, 'FFI::Platypus';
  eval { $ffi->function(t2t_init => [] => 'void') };
  is $@, '';

  ffi->runtime->symbol_ok('t2t_init');

  is(
    intercept { ffi->runtime->symbol_ok('xxx') },
    array {
      event Fail => sub {
        call name => 'Library has symbol: xxx';
        call facet_data => hash {
          field info => array {
            item {details => match qr{looked in .*/.*t2t}, debug => 1, tag => 'DIAG' };
          };
          etc;
        };
      };
      end;
    },
  );

};

subtest 'ffi->test' => sub {

  my $ffi = ffi->test;
  isa_ok $ffi, 'FFI::Platypus';
  is(
    $ffi->function(myanswer => [] => 'int')->call,
    42,
  );

  ffi->test->symbol_ok('myanswer');

};

subtest 'ffi->combined' => sub {

  my $ffi = ffi->combined;
  isa_ok $ffi, 'FFI::Platypus';

  eval { $ffi->function(t2t_init => [] => 'void') };
  is $@, '';

  is(
    $ffi->function(myanswer => [] => 'int')->call,
    42,
  );

  ffi->combined->symbol_ok('t2t_init');
  ffi->combined->symbol_ok('myanswer');
};

subtest 'diagnostic callbacks' => sub {

  my $ffi = $Test2::Tools::FFI::ffi;

  my $set_location = $ffi->function(t2t_set_location => ['string', 'string', 'int', 'string'] => 'void');
  $set_location->call('c', 'foo.c', 42, 'myfunc');

  is(
    intercept {
      $ffi->function(t2t_note => ['string'] => 'void')->call('a note')
    },
    array {
      event Note => sub {
        call message => 'a note';
        call facet_data => hash {
          field trace => hash {
            field frame => [qw( c foo.c 42 myfunc )];
            etc;
          };
          etc;
        };
      };
      end;
    },
  );

  $set_location->call('c', 'foo2.c', 56, 'myfunc3');

  is(
    intercept {
      $ffi->function(t2t_diag => ['string'] => 'void')->call('a diag')
    },
    array {
      event Diag => sub {
        call message => 'a diag';
        call facet_data => hash {
          field trace => hash {
            field frame => [qw( c foo2.c 56 myfunc3 )];
            etc;
          };
          etc;
        };
      };
      end;
    },
  );

  $ffi->function(t2t_clear_location => [] => 'void')->call;

};

subtest 'call diagnostics from c' => sub {
  skip_all 'todo';
  ok 1;
  ffi->test->function(test_diagnostics => [] => 'void')->call;
};

done_testing
