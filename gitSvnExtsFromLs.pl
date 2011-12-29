#!/usr/bin/env perl

# execute this script in $IP, i.e. the dir containing your MediaWiki LocalSettings.php
# creates git repos for each of the extensions required in LocalSettings.php, under $IP/extensionsGit
# then do whatever you need to make extensionsGit your extensions dir
# if you are placing it inside another git repo, you may need to add it to .gitignore

use strict;
use warnings qw/all/;

use Cwd qw/getcwd/;

# configuration
my $user = 'neilk';
my $minRev = 50000;

# all else should be good below, if you have a typical layout
debugSetup();

my $ipDir = getcwd();
my $gitExtDir = "$ipDir/extensionsGit";
my $baseUrl = "svn+ssh://$user\@svn.wikimedia.org/svnroot/mediawiki/trunk/extensions";

makeExtReposFromLocalSettings( $ipDir, $gitExtDir, $baseUrl, $minRev );


sub makeExtReposFromLocalSettings {
  my ($ipDir, $gitExtDir, $baseUrl, $minRev) = @_;

  my %ext = getExtensionsRequiredEarliestRevision( $ipDir, $baseUrl );
   
  if ( ! -d $gitExtDir ) {
    mkdir $gitExtDir or die $!;
  }

  while ( my ( $ext, $props ) = each %ext ) {
    debug( ">> make git repo for $ext" );
    makeGitRepo( $gitExtDir, $ext, $props, $minRev );
  }
}


sub getExtensionsRequiredEarliestRevision {
  my ($ipDir, $baseUrl) = @_;
  my %extRev = ();
  foreach my $ext ( getExtensionsRequired( $ipDir ) ) {
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

sub getExtensionsRequired { 
  my ($ipDir) = @_; 
  my @ext = ();
  open my $fh, '<', "$ipDir/LocalSettings.php" or die "can't open LocalSettings -- $!";
  while (<$fh>) {
    if ( $_ =~ /require(?:_once)\s*\(.*\/extensions\/(\w+)/ ) {
      push @ext, $1;
    }
  }
  close $fh or die $!;
  debug( "required extensions: " . (join ", ", @ext ) . "\n" );
  return @ext;
}

sub makeGitRepo {
  my ($gitExtDir, $ext, $props, $minRev) = @_;
  my $url = $props->{'url'};
  my $rev = $props->{'rev'};
  chdir $gitExtDir or die $!;
  $rev = int($rev);
  if ( $rev < $minRev ) {
    $rev = $minRev;
  }
  sys( "git svn clone -r $rev:HEAD $url" );
  chdir "$gitExtDir/$ext" or die $!;
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
