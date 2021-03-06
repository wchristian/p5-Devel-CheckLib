package Helper;
use strict;
# compatible use warnings
BEGIN{ if (not $] < 5.006) { require warnings; warnings->import } }

use Config;
use Cwd;
use Exporter;
use IO::File;
use File::Spec::Functions qw/catfile canonpath/;
use File::Temp qw/tempdir/;

use vars qw/@EXPORT @ISA/;
@ISA = qw/Exporter/;
@EXPORT = qw(
    create_testlib 
    find_compiler
    find_binary
);

my $orig_wd = cwd;

BEGIN { require Devel::CheckLib; } # for _quiet_system()
sub _quiet_system {
    goto &Devel::CheckLib::_quiet_system;
}

#--------------------------------------------------------------------------#
# create_testlib( 'bazbam' )
#
# takes a library name and compiles a simple library with two functions, 
# foo() (which returns 0) and libversion() (which returns 42), in a temp
# directory and returns the temp directory.  Returns undef if something
# went wrong
#--------------------------------------------------------------------------#

sub create_testlib {
    my ($libname) = (@_);
    return unless $libname;
    my $tempdir = tempdir(CLEANUP => 1, TEMPLATE => "Devel-Assert-testlib-XXXXXXXX");
    chdir $tempdir;
    my $code_fh = IO::File->new("${libname}.c", ">");
    print {$code_fh} "int libversion() { return 42; }\nint foo() { return 0; }\n";
    $code_fh->close;
    
    my $cc = $Config{cc};
    my $rv = 
        $cc eq 'gcc'    ? _gcc_lib( $libname )  :
        $cc eq 'cc'     ? _gcc_lib( $libname )  :
        $cc eq 'cl'     ? _cl_lib( $libname )   :
                          undef         ;     

    chdir $orig_wd;
    return $rv ? canonpath($tempdir) : undef;
}

sub _gcc_lib {
    my ($libname) = @_;
    my $cc = find_compiler() or return;
    my $ar = find_binary('ar') or return;
    my $ranlib = find_binary('ranlib') or return;

    _quiet_system("$cc -c ${libname}.c") and return;
    _quiet_system("$ar rc lib${libname}.a ${libname}.o") and return;
    _quiet_system("$ranlib lib${libname}.a") and return;
    return -f "lib${libname}.a"
}

sub _cl_lib {
    my ($libname) = @_;
    my $cc = find_compiler() or return;
    my $ar = find_binary('lib') or return;

    _quiet_system($cc, '/c',  "${libname}.c") and return;
    _quiet_system($ar, "${libname}.obj") and return;
    return -f "${libname}.lib";
}

#--------------------------------------------------------------------------#
# find_binary, find_compiler
#
# Returns absolute path to an executable file in $ENV{PATH} or undef 
# if it can't be found.  find_binary() takes a program argument;
# find_compiler takes no arguments and just returns the path to $Config{cc}
#--------------------------------------------------------------------------#

sub find_binary {
    my ($program) = @_;
    if ($Config{_exe} && $program !~ /$Config{_exe}$/) {
        $program .= $Config{_exe};
    }
    for my $path ( split /$Config{path_sep}/, $ENV{PATH} ) {
        my $binary = catfile( $path, $program );
        return $binary if -x $binary;
    }
    return;
}

sub find_compiler {
    return find_binary($Config{cc});
}

1; # must be true
