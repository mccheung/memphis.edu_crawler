#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
#use LWP::UserAgent;
use YAML::Syck;
use WWW::Mechanize::GZip;
use HTML::TreeBuilder;
use HTML::FormatText;

use Digest::MD5 qw/md5_hex/;
my $use_proxy = 0;

my $m_url = 'http://memphis.edu';
my $file = 'status.yaml';
my $urls = LoadFile($file);

unless ( exists $urls->{ no } && @{ $urls->{ no } }) {
  push @{$urls->{ no }}, $m_url;
  $urls->{ all }{ md5_hex( $m_url ) } = $m_url;
}


local $SIG{INT} = sub {
    my ($message) = @_;
    # log the message
    print "Programer die\n";
    save_status( $file, $urls );
    exit 0;
};

my $ua = WWW::Mechanize::GZip->new(
  agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:32.0) Gecko/20100101 Firefox/32.0',
);
$ua->proxy( ['http', 'https'], 'socks://127.0.0.1:9090' ) if $use_proxy;

while ( my $url = get_no_url() ) {
  print "$url\n";

  my $resp = $ua->get( $url );

  unless ( $resp->is_success ) {
    print "Get URL: $url FAIL\n";
    sleep( int( rand( 10 ) ) );
    next;
  }


  my $tree = HTML::TreeBuilder->new_from_content( $resp->content );

  my @links = $tree->look_down( _tag => 'a' );

  foreach my $link ( @links ){
    my $txt = $link->{ _content }->[0];
    my $link_url = $link->{ href };
    next unless $link_url;
    $link_url = $m_url . $link_url unless $link_url =~ /^http/;

    # Ignore all not http://memphis.edu links
    next if $link_url =~ /jpg$/;
    next if $link_url =~ /png$/;
    next if $link_url =~ /gif$/;

    if ( $link_url =~ /memphis\.edu/ ){
      set_urls( $link_url, $txt );
    }
  }


  my $article_file_name = get_file_name( $url );

  if ( $article_file_name ) {
    my $article_content = get_article_content( $resp );
    save_article_content( $article_file_name, $article_content, $url );
  }

  set_url_yes( $url );
  sleep( int( rand( 10 ) ) );
}

save_status( $file, $urls );


sub save_article_content {
  my ( $file, $article, $url ) = @_;

  open my $fh, '>', $file || die "$!\n";
  print $fh "$url\n\n";
  print $fh $article;
  close $fh;

}


sub get_file_name {
  my $url = shift;
  my $url_md5 = md5_hex( $url );
  my $file = $urls->{ link_text }->{ $url_md5 } || $url_md5;

  $file = join( '', ('./articles/', $file,  '.html') );
  return $file;
}

sub get_article_content {
  my $resp = shift;
  my $tree = HTML::TreeBuilder->new_from_content( $resp->content );
  my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
  return $formatter->format( $tree );
}


sub save_status{
  my ( $file, $data ) = @_;
  DumpFile($file, $data);
}

sub get_no_url {
  return shift @{$urls->{ no }};
}

sub set_urls {
  my ( $url, $name ) = @_;
  _set_url( $url, $name );
}

sub set_url_yes {
  push @{ $urls->{ yes } }, shift;
}

sub _set_url {
  my $url = shift;
  my $name = shift;

  my $url_md5 = md5_hex( $url );
  unless ( _is_exists_url( $url, $url_md5 ) ) {
    push @{$urls->{ no }}, $url;
    $urls->{ all }->{ $url_md5 } = $url;
  }

  # save link's text
  $urls->{ links_text }->{ $url_md5 } = $name;
}

sub _is_exists_url {
  my ($url, $url_md5 ) = @_;

  return 1 if exists $urls->{ all }->{ $url_md5 };
  return 0;
}


__END__

$url->{ no }  所有未处理的 url
$url->{ yes } 所有已处理的 url
$url->{ all }->{ url_md5 } 所有已经存在的 url

