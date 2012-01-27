#!/usr/bin/env perl

# execute this script in $IP, i.e. the dir containing your MediaWiki LocalSettings.php
#
# with arguments on the command line, will simply install those extensions into extensions
# 
# if executed with flag --localsettings then it will obtain a list of extensions to get from LocalSettings.php
# and create the extensions in $IP/extensionsgit


use strict;
use warnings qw/all/;

use Cwd qw/getcwd/;
use Getopt::Long;

# configuration
my $minRev = 50000;

# all else should be good below, if you have a typical layout
debugSetup();

my $user = $ENV{"USER"};
my $ipDir = getcwd();
my $extDir = "$ipDir/extensions";
my $baseUrl = "svn+ssh://$user\@svn.wikimedia.org/svnroot/mediawiki/trunk/extensions";

my $localSettings = 0;

my $result = GetOptions( 
  "user=s" => \$user,
  "ip=s" => \$ipDir, 
  "extdir=s" => \$extDir,
  "baseurl=s" => \$baseUrl,
  "user=s" => \$user,
  "minrev=i" => \$minRev,
  "localsettings" => \$localSettings,
);

if ( $localSettings ) {  
  makeExtReposFromLocalSettings( $ipDir, $extDir, $baseUrl, $minRev );
} else {
  makeExtRepos( \@ARGV, $baseUrl, $extDir, $minRev );
}

# the end



sub makeExtReposFromLocalSettings {
  my ($ipDir, $extDir, $baseUrl, $minRev) = @_;
  my @extFromLocalSettings = getExtensionsFromLocalSettings( $ipDir );
  makeExtRepos( \@extFromLocalSettings, $baseUrl, $extDir . "git", $minRev );
}

sub getExtensionsFromLocalSettings { 
  my ($ipDir) = @_; 
  my @ext = ();
  my $localSettingsFile = "$ipDir/LocalSettings.php";
  open my $fh, '<', $localSettingsFile or die "can't open LocalSettings -- $!";
  while (<$fh>) {
    if ( $_ =~ /require(?:_once)\s*\(.*\/extensions\/(\w+)/ ) {
      push @ext, $1;
    }
  }
  close $fh or die $!;
  debug( "required extensions: " . (join ", ", @ext ) . "\n" );
  return @ext;
}


sub makeExtRepos {
  my ( $exts, $baseUrl, $extDir, $minRev ) = @_;
 
  if ( ! -d $extDir ) {
    mkdir $extDir or die $!;
  }

  my %ext = getExtensionsEarliestRevision( $exts, $baseUrl );

  while ( my ( $ext, $props ) = each %ext ) {
    debug( ">> make git repo for $ext" );
    makeGitRepo( $extDir, $ext, $props, $minRev );
  }

}

sub getExtensionsEarliestRevision {
  my ($exts, $baseUrl) = @_;
  my %extRev = ();
  foreach my $ext ( @$exts ) {
    my $extUrl = "$baseUrl/$ext";
    my $rev = getEarliestRev( $extUrl );
    if ( ! defined $rev ) {
      warn "couldn't find earliest revision for $ext";
    } else {
      $extRev{$ext} = { rev => $rev, url => $extUrl };
    }
  }
  return %extRev;
}

sub getEarliestRev {
  my ( $extUrl ) = @_;
  debug( ">> get earliest rev for $extUrl" );
  open my $fh, "-|", "svn log $extUrl" or die "can't get log for $extUrl -- $!";
  my $rev = undef;
  my $debugTick = getDebugTicker(10);
  while (<$fh>) {
    /^r(\d+)/ and $rev = $1;
    $debugTick->();
  }
  debug("rev = $rev");
  close $fh or die $!;
  return $rev;
}

sub makeGitRepo {
  my ($extDir, $ext, $props, $minRev) = @_;
  my $url = $props->{'url'};
  my $rev = $props->{'rev'};
  chdir $extDir or die $!;
  $rev = int($rev);
  if ( $rev < $minRev ) {
    $rev = $minRev;
  }
  sys( "git svn clone -r $rev:HEAD $url" );
  chdir "$extDir/$ext" or die $!;
  sys( "git svn rebase " );
}

sub debugSetup {
  if ($ENV{'DEBUG'} ) {
    my $old_fh = select(STDERR);
    $| = 1;
    select($old_fh);
  }
}

sub debug {
  if ( $ENV{'DEBUG'} ) {
    warn( $_[0] . "\n" );
  }
}

sub getDebugTicker {
  my ($count) = @_;
  my $iter = 0;
  return sub {
    if ( $iter++ % $count == 0 && $ENV{'DEBUG'} ) {
      print STDERR ".";
    }
  }
}


sub sys {
  my ($cmd) = @_;
  warn "$cmd...\n";
  system( $cmd ) and die $!;
}
