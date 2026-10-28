#!/usr/bin/perl
# Writes DelphE's own .build file for EBuild (the make clone of E 3.3a), for the E-VO compiler.
# The dependencies are read from the MODULE lines of the sources, so they cannot go stale:
# run this after changing a MODULE line (BuildMake does not; the Amiga side has no Perl).
#
#   perl tools/MakeBuild.pl            writes .build in the DelphE folder
#
# This is only for building DelphE itself. Projects made with DelphE get their own.
use strict;
use File::Basename;

# kind: m = module (name.m), p = program;  the third entry is extra compiler switches (ADDBUF 3 gives
# the compiler the workspace the big programs need)
my $compiler = 'evo';
my $switches = 'NOPROGRESS';
# "perl tools/MakeBuild.pl debug" makes a build that checks every pointer, array index and the
# stack: a NIL or out-of-range access then stops the program with the line it happened on.
# (Use BuildMake CLEAN after changing between the two: the modules must all be built the same way.)
my $debug = ($ARGV[0] || '') eq 'debug';
$switches .= ' NILCHECK ARRAYCHECK STACKCHECK' if $debug;
my @targets = (
  ['src/FormModel',        'm'], ['src/MForm',     'm'], ['src/Util',      'm'],
  ['src/Toolchain',        'm'], ['src/GenOut',    'm'], ['src/GenRuntime','m'],
  ['src/Generator',        'm'], ['src/GenFiles',  'm'], ['src/UserFile',  'm', 'ADDBUF 3'],
  ['src/Project',          'm'], ['src/Highlight', 'm'], ['src/Builder',   'm'],
  ['src/Preview',          'p'],
  ['src/mcc/Listtree_mcc', 'm'], ['src/mcc/TextEditor_MCC', 'm'], ['src/mcc/Toolbar_mcc', 'm'],
  ['src/designer/Designer','p', 'ADDBUF 3'],
  ['tools/GenTest',        'p', 'ADDBUF 3'], ['tools/MainFormBuilt', 'p', 'ADDBUF 3'],
  ['tools/PenTest',        'p'], ['tools/Bench', 'p'],
  ['dunit/DUnit',          'm', 'ADDBUF 3'], ['dunit/SelfTest', 'p', 'ADDBUF 3'],
  ['tests/Tests',          'p', 'ADDBUF 3'],
);

sub slurp { open(my $f, '<', $_[0]) or die "$_[0]: $!"; local $/; my $t = <$f>; close $f; $t =~ s/\r//g; $t }

# the program or module file a target makes: lower-case .m for modules
sub outfile { my ($base, $kind) = @_; return $kind eq 'm' ? lc($base) . '.m' : $base }

# resolve '*' module paths the way ec does: * is the folder of the source, / goes up
sub resolve {
  my ($srcdir, $name) = @_;
  $name =~ s/^\*//;
  my $p = $srcdir . '/' . $name;
  $p =~ s{//}{/../}g;                      # AmigaDOS "/" at the start of a part = parent
  1 while $p =~ s{[^/]+/\.\./}{};
  return $p;
}

sub deps {
  my ($src) = @_;
  my $t = slurp($src . '.e');
  $t =~ s{(?<!')/\*.*?\*/}{}gs;
  $t =~ s{->[^\n]*}{}g;
  my $dir = dirname($src);
  my @d;
  while ($t =~ /^MODULE\b((?:[^\n]*,[ \t]*\n)*[^\n]*)/mg) {
    my $list = $1;
    while ($list =~ /'(\*[^']*)'/g) {
      my $path = resolve($dir, $1);
      push @d, lc($path) . '.m';
    }
  }
  return @d;
}

my %kind = map { lc($_->[0]) . ($_->[1] eq 'm' ? '.m' : '') => 1 } @targets;
my (@rules, @programs);
foreach my $t (@targets) {
  my ($base, $kind, $flags) = @$t;
  my $out = outfile($base, $kind);
  my @d = deps($base);
  foreach my $d (@d) { die "$base: $d is not a target of this script\n" unless $kind{$d} }
  my $dir  = dirname($base);
  my $name = basename($base);
  my $depth = ($dir eq '.') ? 0 : scalar(split m{/}, $dir);
  my $up   = $depth ? ('/' x $depth) : '';                 # AmigaDOS: one / per level
  my $log  = ($depth ? ('/' x $depth) : '') . 'build.out';
  my $rule = "$out: $base.e";
  $rule .= ' ' . join(' ', @d) if @d;
  $rule .= "\n  cd $dir\n  $compiler $name $switches" . ($flags ? " $flags" : '') . " >> $log\n  cd " . ($up eq '' ? '' : $up) . "\n";
  push @rules, $rule;
  push @programs, $out if $kind eq 'p';
}

# The first rule, "all", is what a plain EBuild run makes: every program, compiled and not run.
# "runtests" is made with "build runtests" (BuildMake runtests, RunTests): it compiles the same and
# runs the smoke test and the unit tests. EBuild can only use a name that is not a file as the first
# rule, or on the command line: as a dependency of another rule it fails with "action failed to build".
my $check = "all: " . join(" ", @programs) . "
  echo \"compiled\"

runtests: dunit/SelfTest tests/Tests tools/GenTest
" . <<'CHK';
  cd tools
  GenTest > /gentest.out
  cd /dunit
  SelfTest > /tests.out
  cd /tests
  Tests >> /tests.out
  cd /
CHK

open(my $o, '>', '.build') or die;
print $o "# Written by tools/MakeBuild.pl from the MODULE lines of the sources: do not edit.\n";
print $o "# Build with:  execute BuildMake      (E-VO: run SetupEvo first)\n\n";
print $o $check, "\n", join("\n", @rules);
close $o;
print "wrote .build with ", scalar(@rules), " rules", ($debug ? " (debug build: NILCHECK ARRAYCHECK STACKCHECK)" : ""), "\n";
