package Test2::Tools::FFI;

use strict;
use warnings;
use 5.010;
use base qw( Exporter );
use FFI::Platypus;
use FFI::CheckLib 0.11 ();
use File::Basename ();
use Cwd ();
use File::Glob ();

# ABSTRACT: Tools for testing FFI
# VERSION

our @EXPORT = qw( ffi );

=head1 SYNOPSIS

In your t/ffi/test.c:

 int
 mytest()
 {
   return 42;
 }

In your t/mytest.t:

 use Test2::V0;
 use Test2::Tools::FFI;

 is(
   ffi->test->function( mytest => [] => 'int')->call,
   42,
 );
 
 done_testing;

=head1 DESCRIPTION

This Test2 Tools module provide some basic tools for testing FFI modules.

=cut

sub ffi
{
  state $singleton;

  unless($singleton)
  {
    $singleton = bless {}, 'Test2::Tools::FFI::Single';
  }

  $singleton;
}

my $ffi = FFI::Platypus->new;
$ffi->package;
$ffi->function(t2t_init => [] => 'void')->call;

package Test2::Tools::FFI::Single;

=head1 FUNCTIONS

=head2 ffi->runtime

 my $ffi = ffi->runtime;

Returns a L<FFI::Platypus> instance connected to the runtime for your module.

=cut

sub runtime
{
  my($self) = @_;

  $self->{runtime} ||= (sub {
    my $ffi = Test2::Tools::FFI::Platypus->new;

    my @dll = File::Glob::bsd_glob("blib/lib/auto/share/dist/*/lib/*");
    if(@dll)
    {
      $ffi->lib(@dll);
      return $ffi;
    }

    @dll = File::Glob::bsd_glob("share/lib/*");
    if(@dll)
    {
      $ffi->lib(@dll);
      return $ffi;
    }
    $ffi;
  })->();
}

=head2 ffi->test

 my $ffi = ffi->test;

Returns a L<FFI::Platypus> instance connected to the test for your module.

=cut

sub test
{
  my($self) = @_;

  $self->{test} ||= do {
    my $ffi = Test2::Tools::FFI::Platypus->new;
    my @lib = FFI::CheckLib::find_lib(
      lib => '*',
      libpath => 't/ffi/_build',
      systempath => [],
    );
    Carp::croak("unable to find test lib in t/ffi/_build")
      unless @lib;
    $ffi->lib(@lib);
    $ffi;
  };
}

=head2 ffi->combined

 my $ffi = ffi->combined;

Return a L<FFI::Platypus> instance with the combined test and runtime libraries for your module.

=cut

sub combined
{
  my($self) = @_;

  $self->{combined} ||= do {
    my $rt = $self->runtime;
    my $t  = $self->test;
    my $ffi = Test2::Tools::FFI::Platypus->new;
    $ffi->lib($rt->lib, $t->lib);
    $ffi;
  };
}

package Test2::Tools::FFI::Platypus;

use base qw( FFI::Platypus );
use Test2::API ();

sub symbol_ok
{
  my($self, $symbol_name, $test_name) = @_;

  $test_name ||= "Library has symbol: $symbol_name";
  my $address = $self->find_symbol($symbol_name);

  my $ctx = Test2::API::context();
  if($address)
  {
    $ctx->pass_and_release($test_name);
  }
  else
  {
    $ctx->fail_and_release($test_name, map { "looked in $_" } $self->lib);
  }
}

1;
