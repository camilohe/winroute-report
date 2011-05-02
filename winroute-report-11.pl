#!/usr/bin/perl -w
#
#$Id: winroute-report.pl, v 1.1, 2011/03/24 12:38:16 camilohe Exp camilohe$
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
##	1.0.0	(Initial fork of top-sites-size.pl v1.2)
##	1.0.1
##		+ Changed code to parse winroute log format. 
##		+ Removed content type checks.		
##	
##	1.0.2
##		+ Fixed issue with accessing on ports other than 80.
##		+ Fixed promblem with https:// entries in log.
##
##	1.1.0
##		+ Added users reports.
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
my $cfgNumberToShow = 50;
###my $cfgLog = "/var/log/squid3/access.log.1";
my $cfgLog = "trazas.0/http.log.30";
###my $cfgOutput =	"/var/www/top-sites-size.htm";
my $cfgOutput =	"winroute-report.htm";

# by_times_visited_then_name or by_size_then_name
my $cfgSortMethod = "by_size_then_name";

# debug anyone?
my $debug = 1;

##
# Stop editing here unless you know what you're doing.
##
my $cfgDate = gmtime;
my $row;
my($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus);
my($site_url, %sites, $user_name, %users);


##
# Open output file
##
open(OUTPUT, ">$cfgOutput") || die("Cannot open output file");


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
			ul b { position: absolute; left: 150px }
			#Generated { margin: 0; padding: 0; font-style:italic }
			#Footer { color: #cecece; line-height: 150%; border-top: 1px solid #cecece; padding: 0.4em }
		-->
		</style>
	</head>
	<body>
	<h1>Top Users by visits</h1>
	<p id="Generated">Report generated on $cfgDate</p>
	<ul>
END


##
# Iterate through lines in http.log
##
open(LOG, "$cfgLog") or die "Can't open file $cfgLog!";
  
while(<LOG>)
{
	$row = $_;

#   sample line from kerio winroute http log
#   192.168.206.15 - Admin [16/Feb/2011:17:19:57 -0500] "GET http://z.about.com/6/g/ruby/b/rss2.xml HTTP/1.1" 200 10870 +3
	($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus) = split(/\s+/, $row);

	if ($debug > 2) 
	{
		print $ip . "," . $user . "," . $url . "," . $http_code . "," . $http_size . "\n";
	}
	
	# Not checking for http:// etc because we want to include CONNECT's and
	# multi-protocol data.
	$url =~ s/https:\/\///;
	$url =~ s/http:\/\///;
	$url =~ s/ftp:\/\///;
	$url =~ s/www.//;
	$url =~ s/\/$//;

	# If the url is empty (which occurs occasionally in my logs, no idea
	# why, then don't add it to the list.
	if (!$url )
	{
		next;
	}

	# Patern match data between slashes.
	($site_url) = ($url =~ m{ ([A-Za-z0-9.\-:]+)}x );

	# If hash already contains an entry for the exact URL.
	if ($sites{$site_url})
	{
		 $sites{$site_url}->{count}++;
	}
	# If no matching entry exists, create one.
	else
	{
		$sites{$site_url}->{count} = 1;
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
	}

	# Update size for user.
	if (!$users{$user}->{size})
	{
		$users{$user}->{size} = 0;
	}
	$users{$user}->{size} = $users{$user}->{size} + $http_size;
	
}

##
# Iterate through users.
##
$cfgSortMethod = "users_by_visits_then_name";
foreach $user_name ( sort ($cfgSortMethod keys (%users) ) )
{
	print OUTPUT "          <li>" . $users{$user_name}->{count} ."<b>" . $user_name . "</b></li>\n";
}

print OUTPUT <<END;
	</ul>
	<h1>Top Users by size</h1>
	<ul>
END

##
# Iterate through users.
##
$cfgSortMethod = "users_by_size_then_name";
foreach $user_name ( sort ($cfgSortMethod keys (%users) ) )
{
	print OUTPUT "          <li>" . format_size($users{$user_name}->{size}) ."<b>" . $user_name . "</b></li>\n";
}

print OUTPUT <<END;
	</ul>
	<h1>Top Sites by visits</h1>
	<ul>
END

##
# Iterate through visited sites.
##
$cfgSortMethod = "by_times_visited_then_name";
foreach $site_url ( sort ($cfgSortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($cfgNumberToShow > 0)
	{
		if ($cfgSortMethod eq "by_times_visited_then_name")
		{
			print OUTPUT "		<li>" . $sites{$site_url}->{count} ."<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}
		elsif ($cfgSortMethod eq "by_size_then_name")
		{
			print OUTPUT "          <li>" . format_size($sites{$site_url}->{size}) ."<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}

		$cfgNumberToShow--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1>Top Sites by size</h1>
	<ul>
END

##
# Iterate through visited sites.
##
$cfgNumberToShow = 50;
$cfgSortMethod = "by_size_then_name";
foreach $site_url ( sort ($cfgSortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($cfgNumberToShow > 0)
	{
		if ($cfgSortMethod eq "by_times_visited_then_name")
		{
			print OUTPUT "		<li>" . $sites{$site_url}->{count} ."<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}
		elsif ($cfgSortMethod eq "by_size_then_name")
		{
			print OUTPUT "          <li>" . format_size($sites{$site_url}->{size}) ."<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		}

		$cfgNumberToShow--;
	}
}

##
# Print Footer HTML
##
print OUTPUT <<END;
	</ul>
	<div id="Footer">Badly hacked by <a href="http://davehope.co.uk">Winroute Top Report Generator</a>.</div>
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

#-----------------------------------------------------------------------------#
# Version: 1.0
# Copyright: Bryant H. McGill - 11c Lower Dorset Street, Dublin 1, Ireland
# Web Address: http://www.bryantmcgill.com/Shazam_Perl_Module/
# Use Terms: Free for non-commercial use, commercial use with notification.
#
# Legal: This code is provided "as is" without warranty of any kind.
# The entire risk of use remains with the recipient.
# In no event shall Bryant McGill be liable for any direct,
# consequential, incidental, special, punitive or other damages.
#-----------------------------------------------------------------------------#
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
