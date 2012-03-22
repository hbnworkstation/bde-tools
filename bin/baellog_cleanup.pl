#!/usr/bin/env perl

# The bael log cleanup script.
#
# This script removes (or compresses) files from the specified non-options
# list that have last modification times older than today by the specified
# number of days. By default, the file suffix must match the pattern of
# of suffixes generated by the default bael file observer.
#
# This script also can process all files in a specified directory (or
# directories) whose filename matches an optionally specified pattern. Note
# that the timestamp suffix requirement is still applied and the pattern is
# not used to filter those files specified as non-options on the command line.

use strict;
use warnings;

use File::Find;
use File::stat;
use File::Basename;
use Getopt::Long;
use Time::Local;
use Time::HiRes;

use constant EXIT_FAILURE => -1;
use constant EXIT_SUCCESS => 0;

sub usage(;$);
sub terminate($);

my $argv0 = File::Basename::basename $0;  chomp($argv0);

my $originalCmdline = join(' ', $argv0, @ARGV);

my %opts;
my @files;

Getopt::Long::Configure("bundling");

unless (GetOptions(\%opts,qw[
    debug
    directory|d:s@
    help|h
    force|f
    regex|e=s
    compress|c
    print|p
    quiet|q
    recurse|r
    save|s:s@
    noCommit|N
    noModTime|M
    noSuffixReq|S
    verbose|v
])) {
    usage();
    terminate(EXIT_FAILURE);
}

if (defined $opts{save} and '' eq $opts{save}->[0]) {
    my ($sec, $min, $hr, $dd, $mm, $yyyy) = localtime(time);
    my $today = sprintf "%4d%02d%02d", $yyyy + 1900, $mm + 1, $dd;
    push(@{$opts{save}}, $today);
}

if (defined $opts{noModTime} && defined $opts{noSuffixReq}) {
  die "** ERR: Options --noModTime and --noSuffixReq are mutually exclusive\n";
}

if (defined $opts{print}) {
    $opts{noCommit} = 1;
    $opts{verbose}  = 1;
}

usage() and terminate(EXIT_SUCCESS) if $opts{help};
usage() and terminate(EXIT_SUCCESS) if !@ARGV;

sub usage(;$) {
    my $prog = basename($0);
    print STDERR <<_USAGE_END;
Usage: baellog_cleanup.pl [-chmpqrvMNS] [-s <date>*] [-e <pattern>] [-d <dir>]*
                          <days> <file...>

  --compress     | -c            compress files rather than remove them

  --directory    | -d <dir>      process all files in the specified directory
                                 (see also --recurse)

  --force        | -f            force removal/zip of files without user prompt

  --help         | -h            display usage information (this text)

  --print        | -p            display files to be removed, but do not remove
                                 them (implies --noCommit --verbose)

  --quiet        | -q            suppress output to stdout (DEPRECATED)

  --recurse      | -r            recurse into subdirectories (requires -d)

  --regex        | -e <pattern>  only process files matching 'pattern'

  --save         | -s <YYYYMMDD> do not remove files dated YYYYMMDD (if this
                                 option is omitted "today" is assumed)

  --noCommit     | -N            do not remove or compress any files

  --noModTime    | -M            remove files based on suffix timestamp rather
                                 than last modification time

  --noSuffixReq  | -S            do not require the YYYYMMDD_HHMMSS file suffix

  --verbose      | -v            display output to stdout
_USAGE_END
}

sub terminate($) {
    my ($status) = @_;
    exit($status);
}

sub timestamp {
  my @tm = Time::HiRes::gettimeofday();
  my ($sec, $min, $hr, $dd, $mm, $yyyy) = localtime($tm[0]);
  my $now = sprintf "%4d-%02d-%02d %02d:%02d:%02d.%d",
                     $yyyy + 1900, $mm + 1, $dd, $hr, $min, $sec, $tm[1];
  return $now;
}

sub addFile {
  my $file = $File::Find::name;

  if (-f $file) {
    if (defined $opts{regex}) {
      my $filename = File::Basename::basename($file);
      if ($filename =~ m/$opts{regex}/) {
        push(@files, $file);
      }
    }
    else {
      push(@files, $file);
    }
  }
}

sub formatBytes($) {
  my ($value) = @_;
  return $value . " bytes";
}

# can't use prototype - called via subref
sub compress {
  my ($files_r) = @_;

  return unless scalar @$files_r;

  if ($opts{verbose}) {
    my $command = "gzip ";
    $command .= " -f " if defined $opts{force};

    # buffer like mad
    my $print = "";
    $print .= timestamp() . " $command $_\n" foreach @$files_r;
    print $print;
  }

  unless ($opts{noCommit}) {
    if(defined $opts{force}) {
      system qx{gzip -f @$files_r};
    }
    else {
      system qx{gzip @$files_r};
    }
  }
}

# can't use prototype - called via subref
sub rm {
  my ($files_r) = @_;

  return unless scalar @$files_r;

  if ($opts{verbose}) {
    my $command = "rm ";
    $command .= " -f " if defined $opts{force};

    # buffer like mad
    my $print = "";
    $print .= timestamp() . " $command $_\n" foreach @$files_r;
    print $print;
  }

  unless ($opts{noCommit}) {
    # This assumes the caller did not include read-only files in @$files_r!
    # 'unlink' will remove them unconditionally, so we rely on the caller to
    # have checked $opts{force}.
    unlink(@$files_r);
  }
}

sub processFileList($$$\@) {
  my ($days, $delta, $now, $files) = @_;

  my $totalSize = 0;
  my $numFiles  = 0;

  my $skipReadOnly = !defined $opts{force};

  # Note that $skipReadOnly MUST be checked in this sub - the rm subroutine
  # uses unlink, which is equivalent to "rm -f".
  my $cleanupRoutine = \&rm;

  if (defined $opts{compress}) {
    $cleanupRoutine = \&compress;
  }

  my $suffix = (defined $opts{compress})
             ? qr/.(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$/
             : qr/.(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})(.gz)?$/;
  my @filesToCleanup;

  foreach my $file (@{$files}) {
    print("Processing $file \n") if defined $opts{debug};

    # Except when files are to be compressed, always ignore previously
    # compressed files.
    next if (defined $opts{compress}) && ($file =~ m/(.gz)$/);

    # Amortize the cost of the cleanup operation.
    if (@filesToCleanup > 100) {
      $cleanupRoutine->(\@filesToCleanup);

      @filesToCleanup = ();
    }

    my $suffixTimestamp;

    # File suffix must match the pattern produced by the default bael
    # observer unless 'noSuffixReq' option is set.
    if (!defined $opts{noSuffixReq}) {
        next if $file !~ m/$suffix/;

        if (defined $opts{save}) {
          my $filedate = $1.$2.$3;
          next if scalar(grep /$filedate/, @{$opts{save}});
        }

        $suffixTimestamp = timegm(int($6), int($5),     int($4),
                                  int($3), int($2) - 1, int($1));
    }

    my $st = stat($file);

    # Ignore unmatched glob-style patterns.
    next unless $st;

    my $lastModification = $st->mtime;

    # If we're not going to compress or remove read-only files, skip them.
    # Also, since our sub rm uses unlink, we must make sure readonly files
    # don't wind up in @filesToCleanup.
    next if $skipReadOnly and !-w _;

    my $modTime = ($opts{noModTime} && !$opts{noSuffixReq})
                ? $suffixTimestamp
                : $lastModification;

    if (defined $opts{debug}) {
      print("  Last modified: " . $modTime . "\n");
      print("  Now:           " . $now . "\n");
      print("  Delta:         " . $delta . "\n");
      print("  Difference:    " . ($now - $modTime) . "\n");
    }

    if ($delta < ($now - $modTime)) {
      $totalSize += stat($file)->size;
      ++$numFiles;

      push @filesToCleanup, $file;
    }
  }

  # Clean up any remaining files (in case the total count isn't a multiple of
  # 100).
  $cleanupRoutine->(\@filesToCleanup) if scalar @filesToCleanup;

# if ((!defined $opts{quiet}) && ($numFiles > 0)) {
  if ($numFiles > 0) {
    print(timestamp() . " Processed $numFiles files having "
        . formatBytes($totalSize)
        . "\n");
  }
}

MAIN: {
  print(timestamp() . " Started: $originalCmdline\n");

  foreach my $saveDate (@{$opts{save}}) {
      die "Save date must be in the format YYYYMMDD" if $saveDate !~ m/\d{8}/;
  }

  my $days = shift(@ARGV);

  if ((defined $days) && (1 > $days)) {
    print("<days> must be greater than zero\n");
    usage();
    exit 1;
  }

  my $delta = 60 * 60 * 24 * $days;
  my $now   = time;

  if (defined $opts{directory}) {
    foreach my $dir (@{$opts{directory}}) {
      if (defined $opts{recurse}) {
        File::Find::find({ wanted => \&addFile, follow => 1 }, "$dir");
      }
      else {
        next if (!opendir(DIR, $dir));

        my @dirfiles = ();

        my $regex = qr//;
        $regex = qr/$opts{regex}/ if defined $opts{regex};
        # we can skip read only files here "for free", since -f does a stat
        my $skipReadOnly = !defined $opts{force};

        @dirfiles = map { "$dir/$_" }
                    grep {        m/$opts{regex}/
                           &&  -f "$dir/$_"
                           &&  (-w _ || !$skipReadOnly)
                         } readdir(DIR);

        push(@files, @dirfiles);

        closedir DIR;
      }
    }
    print(timestamp() . " Constructed file list: " . @files . " files\n");
  }

  # Process all files found in any specified directory.
  processFileList($days, $delta, $now, @files);

  # Process all files specified as non-options on the command line.
  processFileList($days, $delta, $now, @ARGV);

  print(timestamp() . " Stopped: $originalCmdline\n");
}
