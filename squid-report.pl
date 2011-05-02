#!/usr/bin/perl
#
#$Id: squid-report.pl,v 1.2 2003/07/16 14:38:08 sava Exp sava $
#
# Copyright (c)2003 Sava Chankov <sava@blueboard.biz>, BlueBoard Ltd. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the GNU General Public License

use strict;

use Time::localtime;

my($date, $tm, $row, $dir, $file);

#
#sample line from squid log
#1058276932.838   2291 192.168.1.4 TCP_MISS/200 4106 GET http://www.seriouswheels.com/1994-Vector.htm - DIRECT/www.seriouswheels.com text/html
#
#log file fields
#$epoch_time_miliseconds - epoch time with miliseconds precision
#$ip - the host requesting page from squid
#
my($epoch_time_miliseconds, $unknown_integer1, $ip, $tcp_and_http_code);
my($unknown_integer2, $http_method, $url, $minus, $squid_method_site_url, $content_type);

my($site_url, %sites);

$dir = $ARGV[0];
if (!$dir) {print_usage();}
opendir(DIR, $dir) or die "Can't open directory $dir!\n";

print <<END;
<html>
  <head>
    <title>Sites sorted by frequency of visiting</title>
  </head>
  <body>
END

while( defined($file = readdir(DIR)) ) {
	open(LOG, "<$dir/$file") or die "Can't open file $dir/$file!";
  
  while(<LOG>){
    $row = $_;

    ($epoch_time_miliseconds, $unknown_integer1, $ip, $tcp_and_http_code,
     $unknown_integer2, $http_method, $url, $minus, $squid_method_site_url, $content_type) = split(/\s+/, $row);

    $tm = localtime($epoch_time_miliseconds);
    $date = ($tm->year + 1900) . '/' . ($tm->mon + 1) . '/' . ( $tm->mday);

    #get the site url, e.g. what is between the second and the third slash in 
    #http://www.seriouswheels.com/1994-Vector.htm 
    ($site_url) = ($url =~ m{
  													  http://
                              ([A-Za-z0-9.\-]+)
                              /
                            }x
                  );
		if($content_type =~ m{text/html}) {
      if ($sites{$site_url}) {
	      $sites{$site_url}->{count}++;
      }
      else
      {
        $sites{$site_url}->{count} = 1;
        $sites{$site_url}->{date} = $date;
      }
    }
  }
}

foreach $site_url (  sort (by_times_visited_then_name keys (%sites) ) ) {
	print "    Visited: " . $sites{$site_url}->{count} ." times <a href=\"http://" . $site_url . "/\">" . $site_url . "</a>";
  print " Last visited: ". $sites{$site_url}->{date} ." <br/>\n" ;
} 
print <<END;
  </body>
</html>
END

sub print_usage {
	print "Usage: $0 dir\n";
  print "dir                  the directory with squid log files\n";
  print "Prints HTML page on stdout with links to web sites, sorted by frequency of\n";
  print "visiting.\n";
  exit();
}

#most frequently visited sites on top of the listing,
#sites visited equal times are sorted alphabetically
sub by_times_visited_then_name {
	$sites{$b}->{count} <=> $sites{$a}->{count} 
		||
	$a cmp $b
}

=head1 NAME

squid-report

=head1 DESCRIPTION


Processes squid logs and prints a HTML page on stdout with links to web sites, 
sorted by frequency of visiting, the number of times visited
and last visited date. Counts only html requests.
Here is a sample line from the squid log:

1058276932.838   2291 192.168.1.4 TCP_MISS/200 4106 GET http://www.seriouswheels.com/1994-Vector.htm - DIRECT/www.seriouswheels.com text/html

Takes as a parameter the directory with squid logs.

=head1 PREREQUISITES


This script requires the C<strict> and C<Time::localtime> module. 

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

CPAN/Administrative