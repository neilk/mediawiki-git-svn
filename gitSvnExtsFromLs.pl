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

my $ipDir = getcwd();
my $gitExtDir = "$ipDir/extensionsGit";
my $baseUrl = "svn+ssh://$user\@svn.wikimedia.org/svnroot/mediawiki/trunk/extensions";

makeExtReposFromLocalSettings( $ipDir, $gitExtDir, $baseUrl, $minRev );


sub makeExtReposFromLocalSettings() {
  my ($ipDir, $gitExtDir, $baseUrl, $minRev) = @_;

  my %ext = getExtensionsRequiredEarliestRevision( $ipDir, $baseUrl );
   
  if ( ! -d $gitExtDir ) {
    mkdir $gitExtDir or die $!;
  }

  while ( my ( $ext, $props ) = each %ext ) {
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
  open my $fh, "|-", "svn log $extUrl" or die "can't get log for $extUrl -- $!";
  my $rev = undef;
  while (<$fh>) {
    /^r(\d+)/ and $rev = $1;
  }
  close $fh or die $!;
  return $rev;
}

sub getExtensionsRequired { 
  my ($ipDir) = @_; 
  my @ext = ();
  open my $fh, '<', "$ipDir/LocalSettings.php" or die "can't open LocalSettings -- $!";
  while (<$fh>) {
    if ( $_ =~ /require\(/ ) {
      $_ =~ /extensions\/(\w+)/;
      push @ext, $1;
    }
  }
  close $fh or die $!;
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

sub sys {
  my ($cmd) = @_;
  warn "$cmd...\n";
  system( $cmd ) and die $!;
}
