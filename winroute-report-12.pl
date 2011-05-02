#!/usr/bin/perl -w
#
#$Id: winroute-report.pl, v 1.2.1, 2011/03/24 12:38:16 camilohe Exp camilohe$
#
# Copyright (c)2011 Camilo E. Hidalgo Estevez <camiloehe@gmail.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the GNU General Public License

##
##  Winroute Top Users, Sites reporting script.
## 
##  Description:
##	This script will parse the specified Winroute logfile and generate an HTML
##	report with top users/sites by visits/size.
##
##  Author:
##	Dave Hope  - http://davehope.co.uk (Author of top-sites-size.pl)
##	Sava Chankov ( Author of squid-report.pl )
##
##  Known Issues:
##	+ Requests to the webserver on the proxy give weird results?
##
##  Changelog:
##	1.0.0 Initial fork of top-sites-size.pl v1.2
##	1.0.1
##		+ Changed code to parse winroute log format. 
##		+ Removed content type checks (content-type field is not available).		
##	1.0.2
##		+ Fixed issue with accessing on ports other than 80 (handle :port in site url).
##		+ Fixed problem with https:// entries in log.
##	1.1.0
##		+ Added users reports.
##		+ Re-orderd optional arguments (report, top -> top, report).
##		+ Updated POD documentation.
##	1.1.1
##		+ Improved debugging support.
##		+ Fixed issue with invalid (non alpha-numeric) user names.
##		+ Fixed issue with invalid (non numeric) http sizes.
##	1.2.0
##		+ Added hosts (IP) reports.
##	1.2.1
##		+ Added HTTP codes reports.
##
##  License:
##  	This program is free software; you can redistribute it and/or modify it
##	under the GNU General Public License.
##
##	This script is based on 'top-sites-size.pl' v1.2 by Dave Hope which can be 
##  found at http://davehope.co.uk and 'squid-report.pl' v1.2 by Sava Chankov and 
##	has been adjusted for my specific requirements.
##
##	The original script can be found here:
##		http://backpan.perl.org/authors/id/S/SA/SAVA/squid-report.pl
##

use strict;

##
# Configuration.
##
my $cfgNumberToShow = 25;
my $cfgOutput =	"winroute-report.html";

# debug anyone? -- from 0 to 9
my $debug = 1;

##
# Stop editing here unless you know what you're doing.
##
my $cfgDate = gmtime;
my ($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus);
my ($cfgSortMethod, $row, $site_url, %sites, $user_name, %users, $dir, $file, $ItemsLeft);
my (%hosts, $host_ip, %codes, $code);

$dir = $ARGV[0];
if (!$dir) {print_usage();}

$cfgNumberToShow = $ARGV[1] unless !$ARGV[1] ;
print "cfgNumberToShow: $cfgNumberToShow \n" if ($debug) ;

$cfgOutput = $dir . ".html";
$cfgOutput = $ARGV[2] unless !$ARGV[2];
print "cfgOutput: $cfgOutput \n" if ($debug) ;

opendir(DIR, $dir) or die "Can't open directory $dir!\n";

##
# Open output file
##
open(OUTPUT, ">$cfgOutput") || die("Cannot open output file $cfgOutput\n");

##
# Print header HTML
##
print OUTPUT <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head profile="http://gmpg.org/xfn/11">
		<title>Winroute Top Users and Sites Report</title>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
		<style type="text/css">
		<!--
			body { font: normal 1.0em 'Trebuchet MS' }
			ul { list-style-type: none }
			ul a { position: absolute; left: 150px }
			#Generated { margin: 0; padding: 0; font-style:italic; border-bottom: 1px solid #cecece; }
			#Footer { color: #cecece; line-height: 150%; border-top: 1px solid #cecece; padding: 0.4em }
		-->
		</style>
	</head>
	<body>
END


##
# Iterate through lines in each file found in $dir
##
while( defined( $file = readdir(DIR) ) ) 
{
	# Skip files not matching http.log[.xyz]
	if ($file !~ m/^http\.log\.?\d*$/)
	{
		print "Skipping file $dir/$file\n" if ($debug);
		next;
	};

	open(LOG, "<$dir/$file") or die "Can't open file $dir/$file!\n";

	print "Parsing file $dir/$file\n" if ($debug);
	
	while(<LOG>)
	{
		# just for readability
		$row = $_;

		# sample line from kerio winroute http log
		# 192.168.206.15 - Admin [16/Feb/2011:17:19:57 -0500] "GET http://z.about.com/6/g/ruby/b/rss2.xml HTTP/1.1" 200 10870 +3
		# parse winroute log line by splitting on white space, not the best way but it works for our purposes.
		($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus) = split(/\s+/, $row);

		print "$ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus\n" if ($debug>7);
		print "$row\n" if ($debug>8);
					
		# Not checking for http:// etc because we want to include CONNECT's and
		# multi-protocol data.
		$url =~ s/https:\/\///;
		$url =~ s/http:\/\///;
		$url =~ s/ftp:\/\///;
#		$url =~ s/www.//;
		$url =~ s/\/$//;

		# If the url is empty (just in case, really! It has to occur in my logs yet ;-)
		# then don't add it to the list.
		if (!$url )
		{
			print "  Empty url:$url\n" if ($debug>1);
			print "    Row: $row\n" if ($debug>3);
			next;
		};

		# If the user is invalid (which occurs occasionally in my logs, no idea
		# why, then don't add it to the list.
		if ($user !~ m/^[a-zA-Z-]+$/) 
		{
			print "  Bad user:$user\n" if ($debug>1);
			print "    IP: $ip, Site: $site_url, Code: $http_code, Size: $http_size\n" if ($debug>2);
			print "    Row: $row\n" if ($debug>3);
			next;
		}

		# If the size is non numeric (which also occurs occasionally in my logs, no idea
		# why, then don't add it to the list.
		if ($http_size !~ m/^[0-9]+$/ )
		{
			print "  Bad size:$http_size\n" if ($debug>1);
			print "    IP: $ip, Site: $site_url, Code: $http_code, Size: $http_size\n" if ($debug>2);
			print "    Row: $row\n" if ($debug>3);
			next;
		}

		# Get the site url, e.g. what is between the second and the third slash in 
		# http://wc.cmc.com.cu:3000/WorldClient.dll?View=Logout
		($site_url) = ($url =~ m{ ([A-Za-z0-9.\-:]+) }x );
		
		# If hash already contains an entry for the exact site url.
		if ($sites{$site_url})
		{
			 $sites{$site_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$sites{$site_url}->{count} = 1;
			print "  Found site:$site_url\n" if ($debug>1);
		}

		# Update size of content for website regardless of content-type.
		if (!$sites{$site_url}->{size})
		{
			$sites{$site_url}->{size} = 0;
		}
		$sites{$site_url}->{size} = $sites{$site_url}->{size} + $http_size;

		# If hash already contains an entry for the user.
		if ($users{$user})
		{
			 $users{$user}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$users{$user}->{count} = 1;
			print "  Found user:$user\n" if ($debug);
		}

		# Update size for user.
		if (!$users{$user}->{size})
		{
			$users{$user}->{size} = 0;
		}
		$users{$user}->{size} = $users{$user}->{size} + $http_size;

		# If hash already contains an entry for the host.
		if ($hosts{$ip})
		{
			 $hosts{$ip}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$hosts{$ip}->{count} = 1;
			print "  Found host:$ip\n" if ($debug>1);
		}

		# Update size for host.
		if (!$hosts{$ip}->{size})
		{
			$hosts{$ip}->{size} = 0;
		}
		$hosts{$ip}->{size} = $hosts{$ip}->{size} + $http_size;

		# If hash already contains an entry for the code.
		if ($codes{$http_code})
		{
			 $codes{$http_code}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$codes{$http_code}->{count} = 1;
			print "  Found code:$http_code\n" if ($debug);
		}

		# Update size for code.
		if (!$codes{$http_code}->{size})
		{
			$codes{$http_code}->{size} = 0;
		}
		$codes{$http_code}->{size} = $codes{$http_code}->{size} + $http_size;
	}
}

print OUTPUT <<END;
	<h1>Winroute Top Users and Sites Report</h1>
	<p id="Generated">Report generated on $cfgDate</p>
	<h1>Top Users by Visits</h1>
	<ul>
END

##
# Iterate through users sorted by visits.
##
$cfgSortMethod = "users_by_visits_then_name";
foreach $user_name ( sort ($cfgSortMethod keys (%users) ) )
{
    # print user with at least 50 hits to filter out spurious (and irrelevant) users
	print OUTPUT "          <li>" . $users{$user_name}->{count} . "<a href=\"" . $user_name . ".html\">" . $user_name . "</a></li>\n";  #if ($users{$user_name}->{count} > 50);
}

print OUTPUT <<END;
	</ul>
	<h1>Top Users by Size</h1>
	<ul>
END

##
# Iterate through users sorted by size.
##
$cfgSortMethod = "users_by_size_then_name";
foreach $user_name ( sort ($cfgSortMethod keys (%users) ) )
{
    # print user with at least 50KB to filter out spurious (and irrelevant) users
	print OUTPUT "          <li>" . format_size($users{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n";  #if ($users{$user_name}->{size} > 50000);
}

print OUTPUT <<END;
	</ul>
	<h1>Top $cfgNumberToShow Sites by Visits</h1>
	<ul>
END

##
# Iterate through visited sites sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$cfgSortMethod = "by_times_visited_then_name";
foreach $site_url ( sort ($cfgSortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		if ($cfgSortMethod eq "by_times_visited_then_name")
		{
			print OUTPUT "		<li>" . $sites{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}
		elsif ($cfgSortMethod eq "by_size_then_name")
		{
			print OUTPUT "          <li>" . format_size($sites{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}

		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1>Top $cfgNumberToShow Sites by Size</h1>
	<ul>
END

##
# Iterate through visited sites sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$cfgSortMethod = "by_size_then_name";
foreach $site_url ( sort ($cfgSortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		if ($cfgSortMethod eq "by_times_visited_then_name")
		{
			print OUTPUT "		<li>" . $sites{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}
		elsif ($cfgSortMethod eq "by_size_then_name")
		{
			print OUTPUT "          <li>" . format_size($sites{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}

		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1>Top $cfgNumberToShow Hosts (IPs) by Visits</h1>
	<ul>
END

##
# Iterate through hosts (IPs) sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$cfgSortMethod = "hosts_by_visits_then_name";
foreach $host_ip ( sort ($cfgSortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "          <li>" . $hosts{$host_ip}->{count} . "<a href=\"" . $host_ip . ".html\">" . $host_ip . "</a></li>\n";  
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1>Top $cfgNumberToShow Hosts (IPs) by Size</h1>
	<ul>
END

##
# Iterate through hosts (IPs) sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$cfgSortMethod = "hosts_by_size_then_name";
foreach $host_ip ( sort ($cfgSortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "          <li>" . format_size($hosts{$host_ip}->{size}) . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a></li>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1>Top $cfgNumberToShow HTTP Codes by Visits</h1>
	<ul>
END

##
# Iterate through codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$cfgSortMethod = "codes_by_visits_then_name";
foreach $code ( sort ($cfgSortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "          <li>" . $codes{$code}->{count} . "<a href=\"" . $code . ".html\">" . $code . "</a></li>\n";  
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1>Top $cfgNumberToShow HTTP Codes by Size</h1>
	<ul>
END

##
# Iterate through codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$cfgSortMethod = "codes_by_size_then_name";
foreach $code ( sort ($cfgSortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "          <li>" . format_size($codes{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		$ItemsLeft--;
	}
}

##
# Print Footer HTML
##
print OUTPUT <<END;
	</ul>
	<div id="Footer">Badly hacked out by <a href="mailto://camiloeh\@gmail.com">Yours truly</a>. 
	Based on the work of <a href="http://davehope.co.uk/projects/perl-squid-reporting/">Dave Hope</a> and 
	<a href="http://backpan.perl.org/authors/id/S/SA/SAVA">Sava Chankov</a>.</div>
	</body>
</html>
END


##
# Sort sites by frequency visited, then alphabetically.
##
sub by_times_visited_then_name {
	$sites{$b}->{count} <=> $sites{$a}->{count} 
		||
	$a cmp $b
}

##
# Sort by size, then alphabetically.
##
sub by_size_then_name {
        $sites{$b}->{size} <=> $sites{$a}->{size}
                ||
        $a cmp $b
}

##
# Sort users by frequency visited, then alphabetically.
##
sub users_by_visits_then_name {
	$users{$b}->{count} <=> $users{$a}->{count} 
		||
	$a cmp $b
}

##
# Sort users by size, then alphabetically.
##
sub users_by_size_then_name {
	$users{$b}->{size} <=> $users{$a}->{size} 
		||
	$a cmp $b
}

##
# Sort hosts by frequency visited, then alphabetically.
##
sub hosts_by_visits_then_name {
	$hosts{$b}->{count} <=> $hosts{$a}->{count} 
		||
	$a cmp $b
}

##
# Sort hosts by size, then alphabetically.
##
sub hosts_by_size_then_name {
	$hosts{$b}->{size} <=> $hosts{$a}->{size} 
		||
	$a cmp $b
}

##
# Sort codes by frequency visited, then alphabetically.
##
sub codes_by_visits_then_name {
	$codes{$b}->{count} <=> $codes{$a}->{count} 
		||
	$a cmp $b
}

##
# Sort codes by size, then alphabetically.
##
sub codes_by_size_then_name {
	$codes{$b}->{size} <=> $codes{$a}->{size} 
		||
	$a cmp $b
}

sub print_usage {
	print "Usage: $0 dir [n] [file] \n";
	print "dir                  the directory with winroute log files\n";
	print "n                    include only the top n sites.\n";
	print "file                 the file name to store the HTML report\n";
	exit();
}

sub format_size{
  my($bytes) = @_;

  return '' if ($bytes eq '');

  my($size);
  $size = $bytes . ' Bytes' if ($bytes < 1024);
  $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
  $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
  $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
  $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);

  return $size;
}

__END__

=pod

=head1 NAME

winroute-report.pl  -- version? who knows or care!


=head1 DESCRIPTION


Processes winroute logs from a given folder and writes out an HTML file with a 
report containing: 


=over 2

=item * the top users by visits.

=item * the top users by size.

=item * the top N sites by visits.

=item * the top N sites by size.

=item * the top N hosts (IP) by visits.

=item * the top N hosts (IP) by size.

=item * the top N HTTP codes by visits.

=item * the top N HTTP codes by size.

=back

Takes as a parameter the directory with winroute logs and optionally 
the number of top sites to show (defaults to 25) and the file name of 
the report (defaults to given log directory.html).

=head1 USAGE

=over 2

=item winroute-report trazas

Parses log files in folder trazas and writes out the report to file trazas.thml including top 25 sites by default.

=item winroute-report trazas 50 report.html 

Parses log files in folder trazas and writes out the report to file report.thml including top 50 sites as specified.

=item winroute-report trazas 20 

Parses log files in folder trazas and writes out the report to file trazas.thml including top 20 sites as specified.

=back

=head1 PREREQUISITES

This script requires the C<strict> module. 

=head1 AUTHORS

Badly hacked out by Camilo E. Hidalgo Estevez C<(camiloeh@gmail.com)>>. 
Based on previous work by:

=over 2
 
=item Dave Hope C<(http://davehope.co.uk/projects/perl-squid-reporting/)>.

=item Sava Chankov C<(http://backpan.perl.org/authors/id/S/SA/SAVA)>.

=back

=head1 NOTES

If you got time and want some fun!?, set the variable C<$debug> to some number from 0 to 9.

And here you have a sample line from the winroute log for reference:

192.168.206.15 - Admin [16/Feb/2011:17:19:57 -0500] "GET http://z.about.com/6/g/ruby/b/rss2.xml HTTP/1.1" 200 10870 +3

=cut