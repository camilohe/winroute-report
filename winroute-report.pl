#!/usr/bin/perl -w
#
#$Id: winroute-report.pl, v 1.6.1, 2011/04/14 11:25 camilohe Exp camilohe$
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
##		+ Added hosts (IPs) reports.
##	1.2.1
##		+ Added HTTP codes reports.
##	1.3.0
##		+ Added HTTP codes x Sites reports.
##	1.3.1
##		+ Added Users x Sites reports.
##		+ Added Sites x Users reports.
##	1.3.2
##		+ Added Hosts (IPs)/Sites reports.
##	1.4.0
##		+ Added Sites x Hosts reports.
##		+ Added Sites x Codes reports.
##	1.4.1
##		+ Added Available Reports.
##	1.5.0
##		+ Added filtering out items below mininum hits/size.
##	1.5.1
##		+ Fixed some bugs.
##		+ Raised cfgNumberToShow to 50, cfgMinHits to 100 and cfgMinSize to 100 KB.
##	1.6.0
##		+ Reordered reports.
##		+ Added Users x Codes reports.
##		+ Added Hosts x Codes reports.
##		+ Added Codes x Users reports.
##		+ Added Codes x Hosts reports.
##		+ Added filtering out second level items below mininum hits/size.
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
my $cfgNumberToShow = 100;   # show top 100 only
my $cfgMinHits = 100;       # require at least 100 hits to show
my $cfgMinSize = 100 * 1024;    # require at least 100 KB to show
my $cfgOutput =	"winroute-report.html";

# debug anyone? -- from 0 to 9
my $debug = 0;

##
# Stop editing here unless you know what you're doing.
##
my $cfgDate = localtime; # gmtime;
my ($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus);
my ($SortMethod, $row, $site_url, %sites, $dir, $file, $ItemsLeft, $SubItemsLeft);
my (%users, $user_name, %hosts, $host_ip, %codes, $code, $method);
my (%sitesxusers, %sitesxcodes, %sitesxhosts, %usersxsites, %usersxcodes, %hostsxsites, %hostsxcodes);
my (%codesxsites, %codesxusers, %codesxhosts, %methods);

$dir = $ARGV[0];
if (!$dir) {print_usage();}

$cfgNumberToShow = $ARGV[1] unless !$ARGV[1] ;
print "cfgNumberToShow: $cfgNumberToShow \n" if ($debug) ;

$cfgOutput = $dir . ".html";
$cfgOutput = $ARGV[2] unless !$ARGV[2];
print "cfgOutput: $cfgOutput \n" if ($debug) ;

opendir(DIR, $dir) or die "Can't open directory $dir!\n";

# initialize line counters
my $lines = 0;
my $bad_lines = 0;

# start timer
my $start_run = time();

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
		# count line
		$lines++;

		# sample line from kerio winroute http log
		# 192.168.206.15 - Admin [16/Feb/2011:17:19:57 -0500] "GET http://z.about.com/6/g/ruby/b/rss2.xml HTTP/1.1" 200 10870 +3
		# parse winroute log line by splitting on white space, not the best way but it works for our purposes.
		($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus) = split(/\s+/, $row);

		print "$ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus\n" if ($debug>7);
		print "$row\n" if ($debug>8);
					
		# Remove https://, http://, ftp://
##		$url =~ s/https:\/\///;
##		$url =~ s/http:\/\///;
##		$url =~ s/ftp:\/\///;
		# Remove www.
#		$url =~ s/www.//;
		# Remove trailing slash
##		$url =~ s/\/$//;

		# If the url is empty (just in case, really! It has to occur in my logs yet ;-)
		# then don't add it to the list.
		if (!$url )
		{
			print "  Empty url:$url\n" if ($debug>1);
			print "    Row: $row\n" if ($debug>3);
			$bad_lines++;
			next;
		};

		# If the user is invalid (which occurs occasionally in my logs, no idea
		# why, then don't add it to the list.
		if ($user !~ m/^[a-zA-Z-]+$/) 
		{
			print "  Bad user:$user\n" if ($debug>1);
			print "    IP: $ip, Site: $site_url, Code: $http_code, Size: $http_size\n" if ($debug>2);
			print "    Row: $row\n" if ($debug>3);
			$bad_lines++;
			next;
		}

		# If the size is non numeric (which also occurs occasionally in my logs, no idea
		# why, then don't add it to the list.
		if ($http_size !~ m/^[0-9]+$/ )
		{
			print "  Bad size:$http_size\n" if ($debug>1);
			print "    IP: $ip, Site: $site_url, Code: $http_code, Size: $http_size\n" if ($debug>2);
			print "    Row: $row\n" if ($debug>3);
			$bad_lines++;
			next;
		}

		# Get the site base url, e.g. what is between the second and the third slash in 
		# http://wc.cmc.com.cu:3000/WorldClient.dll?View=Logout
##		($site_url) = ($url =~ m{ ([A-Za-z0-9\.\-\:]+) }x );

		# Match what is between the second slash and the first question mark or non allowed 
		# character or to the end -- I think ;-) 
##		($site_url) = ($url =~ m{ ([A-Za-z0-9\.\-\:\/\_\%]+) }x );
##		($site_url) = ($url =~ m{ ([A-Za-z0-9\.\-\:\/\_\%\?\&\+\;]+) }x );

		# Remove leading " from http method 
		$http_method =~ s/\"//;

##		$site_url = "$http_method $url";
		$site_url = $url;
		
		# Count method.
		if (!$methods{$http_method})
		{
			$methods{$http_method}->{count} = 0;
			print "  Found method:$http_method\n" if ($debug>1);
		}
		$methods{$http_method}->{count}++;

		# Update method size. 
		if (!$methods{$http_method}->{size})
		{
			$methods{$http_method}->{size} = 0;
		}
		$methods{$http_method}->{size} += $http_size;

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

		# If hash already contains an entry for the exact site url/user.
		if ($sitesxusers{$site_url}{$user})
		{
			 $sitesxusers{$site_url}{$user}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$sitesxusers{$site_url}{$user}->{count} = 1;
			print "  Found site/user:$site_url/$user\n" if ($debug>1);
		}
		# Update size of content for website/user regardless of content-type.
		if (!$sitesxusers{$site_url}{$user}->{size})
		{
			$sitesxusers{$site_url}{$user}->{size} = 0;
		}
		$sitesxusers{$site_url}{$user}->{size} = $sitesxusers{$site_url}{$user}->{size} + $http_size;

		# If hash already contains an entry for the exact site url/code.
		if ($sitesxcodes{$site_url}{$http_code})
		{
			 $sitesxcodes{$site_url}{$http_code}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$sitesxcodes{$site_url}{$http_code}->{count} = 1;
			print "  Found site/code:$site_url/$http_code\n" if ($debug>1);
		}
		# Update size of content for website/code regardless of content-type.
		if (!$sitesxcodes{$site_url}{$http_code}->{size})
		{
			$sitesxcodes{$site_url}{$http_code}->{size} = 0;
		}
		$sitesxcodes{$site_url}{$http_code}->{size} = $sitesxcodes{$site_url}{$http_code}->{size} + $http_size;

		# If hash already contains an entry for the exact site url/host.
		if ($sitesxhosts{$site_url}{$ip})
		{
			 $sitesxhosts{$site_url}{$ip}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$sitesxhosts{$site_url}{$ip}->{count} = 1;
			print "  Found site/host:$site_url/$ip\n" if ($debug>1);
		}
		# Update size of content for website/code regardless of content-type.
		if (!$sitesxhosts{$site_url}{$ip}->{size})
		{
			$sitesxhosts{$site_url}{$ip}->{size} = 0;
		}
		$sitesxhosts{$site_url}{$ip}->{size} = $sitesxhosts{$site_url}{$ip}->{size} + $http_size;

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

		# If hash already contains an entry for the user/site.
		if ($usersxsites{$user}{$site_url})
		{
			 $usersxsites{$user}{$site_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$usersxsites{$user}{$site_url}->{count} = 1;
			print "  Found user/site:$user/$site_url\n" if ($debug);
		}
		# Update size for user/site.
		if (!$usersxsites{$user}{$site_url}->{size})
		{
			$usersxsites{$user}{$site_url}->{size} = 0;
		}
		$usersxsites{$user}{$site_url}->{size} = $usersxsites{$user}{$site_url}->{size} + $http_size;

		# If hash already contains an entry for the user/code.
		if ($usersxcodes{$user}{$http_code})
		{
			 $usersxcodes{$user}{$http_code}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$usersxcodes{$user}{$http_code}->{count} = 1;
			print "  Found user/code:$user/$http_code\n" if ($debug);
		}
		# Update size for user/code.
		if (!$usersxcodes{$user}{$http_code}->{size})
		{
			$usersxcodes{$user}{$http_code}->{size} = 0;
		}
		$usersxcodes{$user}{$http_code}->{size} = $usersxcodes{$user}{$http_code}->{size} + $http_size;

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

		# If hash already contains an entry for the host/site.
		if ($hostsxsites{$ip}{$site_url})
		{
			 $hostsxsites{$ip}{$site_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$hostsxsites{$ip}{$site_url}->{count} = 1;
			print "  Found host/site:$ip/$site_url\n" if ($debug);
		}
		# Update size for host/site.
		if (!$hostsxsites{$ip}{$site_url}->{size})
		{
			$hostsxsites{$ip}{$site_url}->{size} = 0;
		}
		$hostsxsites{$ip}{$site_url}->{size} = $hostsxsites{$ip}{$site_url}->{size} + $http_size;

		# If hash already contains an entry for the host/code.
		if ($hostsxcodes{$ip}{$http_code})
		{
			 $hostsxcodes{$ip}{$http_code}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$hostsxcodes{$ip}{$http_code}->{count} = 1;
			print "  Found host/code:$ip/$http_code\n" if ($debug);
		}
		# Update size for host/code.
		if (!$hostsxcodes{$ip}{$http_code}->{size})
		{
			$hostsxcodes{$ip}{$http_code}->{size} = 0;
		}
		$hostsxcodes{$ip}{$http_code}->{size} = $hostsxcodes{$ip}{$http_code}->{size} + $http_size;

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
		
		# If hash already contains an entry for the code/site.
		if ($codesxsites{$http_code}{$site_url})
		{
			 $codesxsites{$http_code}{$site_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$codesxsites{$http_code}{$site_url}->{count} = 1;
			print "  Found code/site:$http_code/$site_url\n" if ($debug);
		}
		# Update size for code/site.
		if (!$codesxsites{$http_code}{$site_url}->{size})
		{
			$codesxsites{$http_code}{$site_url}->{size} = 0;
		}
		$codesxsites{$http_code}{$site_url}->{size} = $codesxsites{$http_code}{$site_url}->{size} + $http_size;
		
		# If hash already contains an entry for the code/user.
		if ($codesxusers{$http_code}{$user})
		{
			 $codesxusers{$http_code}{$user}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$codesxusers{$http_code}{$user}->{count} = 1;
			print "  Found code/user:$http_code/$user\n" if ($debug);
		}
		# Update size for code/site.
		if (!$codesxusers{$http_code}{$user}->{size})
		{
			$codesxusers{$http_code}{$user}->{size} = 0;
		}
		$codesxusers{$http_code}{$user}->{size} = $codesxusers{$http_code}{$user}->{size} + $http_size;
				
		# If hash already contains an entry for the code/host.
		if ($codesxhosts{$http_code}{$ip})
		{
			 $codesxhosts{$http_code}{$ip}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$codesxhosts{$http_code}{$ip}->{count} = 1;
			print "  Found code/host:$http_code/$ip\n" if ($debug);
		}
		# Update size for code/site.
		if (!$codesxhosts{$http_code}{$ip}->{size})
		{
			$codesxhosts{$http_code}{$ip}->{size} = 0;
		}
		$codesxhosts{$http_code}{$ip}->{size} = $codesxhosts{$http_code}{$ip}->{size} + $http_size;
				
	}
}

# print parsing stats
my $end_run = time();
my $run_time = $end_run - $start_run;
print "$lines lines processed in $run_time seconds\n";
print "$bad_lines invalid lines were skipped\n";

$start_run = time();

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
			body { font: normal 0.8em 'Trebuchet MS' }
			ul { list-style-type: none }
			ul a { position: absolute; left: 180px }
			ul ul a { position: absolute; left: 220px }
			#Generated { margin: 0; padding: 0; font-style:italic; border-bottom: 1px solid #cecece; }
			#Footer { color: #cecece; line-height: 150%; border-top: 1px solid #cecece; padding: 0.4em }
		-->
		</style>
	</head>
	<body>
END

print OUTPUT <<END;
	<h1>Winroute Top Users and Sites Report</h1>
	<p id="Generated">Report generated on $cfgDate</p>
END

print OUTPUT <<END;
	<h1>Available Reports</h1>
	<ul>
		<li>.<a href="#sites-hits">Top Sites by Visits</a></li>
		<li>.<a href="#sites-size">Top Sites by Size</a></li>
		<li>.<a href="#users-hits">Top Users by Visits</a></li>
		<li>.<a href="#users-size">Top Users by Size</a></li>
		<li>.<a href="#hosts-hits">Top Hosts by Visits</a></li>
		<li>.<a href="#hosts-size">Top Hosts by Size</a></li>
		<li>.<a href="#codes-hits">Top Codes by Visits</a></li>
		<li>.<a href="#codes-size">Top Codes by Size</a></li>
		<li>.<a href="#verbs-hits">Top Methods by Visits</a></li>
		<li>.<a href="#verbs-size">Top Methods by Size</a></li>
		<br/>
		<li>.<a href="#sitesxusers-hits">Top Sites/Users by Visits</a></li>
		<li>.<a href="#sitesxusers-size">Top Sites/Users by Size</a></li>
		<li>.<a href="#sitesxhosts-hits">Top Sites/Hosts by Visits</a></li>
		<li>.<a href="#sitesxhosts-size">Top Sites/Hosts by Size</a></li>
		<li>.<a href="#sitesxcodes-hits">Top Sites/Codes by Visits</a></li>
		<li>.<a href="#sitesxcodes-size">Top Sites/Codes by Size</a></li>
		<li>.<a href="#usersxsites-hits">Top Users/Sites by Visits</a></li>
		<li>.<a href="#usersxsites-size">Top Users/Sites by Size</a></li>
		<li>.<a href="#usersxcodes-hits">Top Users/Codes by Visits</a></li>
		<li>.<a href="#usersxcodes-size">Top Users/Codes by Size</a></li>
		<li>.<a href="#hostsxsites-hits">Top Hosts/Sites by Visits</a></li>
		<li>.<a href="#hostsxsites-size">Top Hosts/Sites by Size</a></li>
		<li>.<a href="#hostsxcodes-hits">Top Hosts/Codes by Visits</a></li>
		<li>.<a href="#hostsxcodes-size">Top Hosts/Codes by Size</a></li>
		<li>.<a href="#codesxsites-hits">Top Codes/Sites by Visits</a></li>
		<li>.<a href="#codesxsites-size">Top Codes/Sites by Size</a></li>
		<li>.<a href="#codesxusers-hits">Top Codes/Users by Visits</a></li>
		<li>.<a href="#codesxusers-size">Top Codes/Users by Size</a></li>
		<li>.<a href="#codesxhosts-hits">Top Codes/Hosts by Visits</a></li>
		<li>.<a href="#codesxhosts-size">Top Codes/Hosts by Size</a></li>
	</ul>
END

print OUTPUT <<END;
	<h1><a name="sites-hits">Top $cfgNumberToShow Sites by Visits</a></h1>
	<ul>
END

##
# Iterate through sites sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_visits_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "	<li>" . $sites{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a> (". format_size($sites{$site_url}->{size}) .")</li>\n" if ($sites{$site_url}->{count} > $cfgMinHits);
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sites-size">Top $cfgNumberToShow Sites by Size</a></h1>
	<ul>
END

##
# Iterate through sites sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_size_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "  <li>" . format_size($sites{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a> (". $sites{$site_url}->{count} .")</li>\n" if ($sites{$site_url}->{size} > $cfgMinSize);
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="users-hits">Top Users by Visits</a></h1>
	<ul>
END

##
# Iterate through users sorted by visits.
##
$SortMethod = "users_by_visits_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	print OUTPUT "   <li>" . $users{$user_name}->{count} . "<a href=\"#" . $user_name . "\">" . $user_name . "</a> (". format_size($users{$user_name}->{size}) .")</li>\n" if ($users{$user_name}->{count} > $cfgMinHits);
}

print OUTPUT <<END;
	</ul>
	<h1><a name="users-size">Top Users by Size</a></h1>
	<ul>
END

##
# Iterate through users sorted by size.
##
$SortMethod = "users_by_size_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	print OUTPUT "  <li>" . format_size($users{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a> (". $users{$user_name}->{count} .")</li>\n" if ($users{$user_name}->{size} > $cfgMinSize);
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hosts-hits">Top $cfgNumberToShow Hosts (IPs) by Visits</a></h1>
	<ul>
END

##
# Iterate through hosts (IPs) sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "hosts_by_visits_then_name";
foreach $host_ip ( sort ($SortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "  <li>" . $hosts{$host_ip}->{count} . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a> (". format_size($hosts{$host_ip}->{size}) .")</li>\n" if ($hosts{$host_ip}->{count} > $cfgMinHits);
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hosts-size">Top $cfgNumberToShow Hosts (IPs) by Size</a></h1>
	<ul>
END

##
# Iterate through hosts (IPs) sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "hosts_by_size_then_name";
foreach $host_ip ( sort ($SortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "  <li>" . format_size($hosts{$host_ip}->{size}) . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a> (". $hosts{$host_ip}->{count} .")</li>\n" if ($hosts{$host_ip}->{size} > $cfgMinSize); 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codes-hits">Top HTTP Codes by Visits</a></h1>
	<ul>
END

##
# Iterate through codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_visits_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	print OUTPUT "  <li>" . $codes{$code}->{count} . "<a href=\"#" . $code . "\">" . $code . "</a> (". format_size($codes{$code}->{size}) .")</li>\n" if ($codes{$code}->{count} > $cfgMinHits); 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codes-size">Top HTTP Codes by Size</a></h1>
	<ul>
END

##
# Iterate through codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_size_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	print OUTPUT "  <li>" . format_size($codes{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a> (". $codes{$code}->{count} .")</li>\n" if ($codes{$code}->{size} > $cfgMinSize); 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="verbs-hits">Top HTTP Methods by Visits</a></h1>
	<ul>
END

##
# Iterate through methods sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "verbs_by_visits_then_name";
foreach $method ( sort ($SortMethod keys (%methods) ) )
{
	print OUTPUT "  <li>" . $methods{$method}->{count} . "<a href=\"#" . $method . "\">" . $method . "</a> (". format_size($methods{$method}->{size}) .")</li>\n" if ($methods{$method}->{count} > $cfgMinHits); 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="verbs-size">Top HTTP Methods by Size</a></h1>
	<ul>
END

##
# Iterate through methods sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "verbs_by_size_then_name";
foreach $method ( sort ($SortMethod keys (%methods) ) )
{
	print OUTPUT "  <li>" . format_size($methods{$method}->{size}) . "<a href=\"#" . $method . "\">" . $method . "</a> (". $methods{$method}->{count} .")</li>\n" if ($methods{$method}->{size} > $cfgMinSize); 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sitesxusers-hits">Top $cfgNumberToShow Sites/Users by Visits</a></h1>
	<ul>
END

##
# Iterate through sites/users sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_visits_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($sites{$site_url}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $sites{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $user_name ( sort ( { $sitesxusers{$site_url}{$b}->{count} <=> $sitesxusers{$site_url}{$a}->{count} || $a cmp $b} keys ( %{ $sitesxusers{$site_url} } ) ) )
		{
			next unless $sitesxusers{$site_url}{$user_name}->{count} > $cfgMinHits;
			print OUTPUT "    <li>" . $sitesxusers{$site_url}{$user_name}->{count} . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sitesxusers-size">Top $cfgNumberToShow Sites/Users by Size</a></h1>
	<ul>
END

##
# Iterate through sites/users sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_size_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($sites{$site_url}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($sites{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $user_name ( sort ( { $sitesxusers{$site_url}{$b}->{size} <=> $sitesxusers{$site_url}{$a}->{size} || $a cmp $b} keys ( %{ $sitesxusers{$site_url} } ) ) )
		{
			next unless $sitesxusers{$site_url}{$user_name}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($sitesxusers{$site_url}{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sitesxhosts-hits">Top $cfgNumberToShow Sites/Hosts (IPs) by Visits</a></h1>
	<ul>
END

##
# Iterate through sites/hosts sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_visits_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($sites{$site_url}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $sites{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $ip ( sort ( { $sitesxhosts{$site_url}{$b}->{count} <=> $sitesxhosts{$site_url}{$a}->{count} || $a cmp $b} keys ( %{ $sitesxhosts{$site_url} } ) ) )
		{
			next unless $sitesxhosts{$site_url}{$ip}->{count} > $cfgMinHits;
			print OUTPUT "    <li>" . $sitesxhosts{$site_url}{$ip}->{count} . "<a href=\"#" . $ip . "\">" . $ip . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sitesxhosts-size">Top $cfgNumberToShow Sites/Hosts (IPs) by Size</a></h1>
	<ul>
END

##
# Iterate through sites/hosts sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_size_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($sites{$site_url}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($sites{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $ip ( sort ( { $sitesxhosts{$site_url}{$b}->{size} <=> $sitesxhosts{$site_url}{$a}->{size} || $a cmp $b} keys ( %{ $sitesxhosts{$site_url} } ) ) )
		{
			next unless $sitesxhosts{$site_url}{$ip}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($sitesxhosts{$site_url}{$ip}->{size}) . "<a href=\"#" . $ip . "\">" . $ip . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sitesxcodes-hits">Top $cfgNumberToShow Sites/Codes by Visits</a></h1>
	<ul>
END

##
# Iterate through sites/codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_visits_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($sites{$site_url}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $sites{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $code ( sort ( { $sitesxcodes{$site_url}{$b}->{count} <=> $sitesxcodes{$site_url}{$a}->{count} || $a cmp $b} keys ( %{ $sitesxcodes{$site_url} } ) ) )
		{
			next unless $sitesxcodes{$site_url}{$code}->{count} > $cfgMinHits;
			print OUTPUT "    <li>" . $sitesxcodes{$site_url}{$code}->{count} . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="sitesxcodes-size">Top $cfgNumberToShow Sites/Codes by Size</a></h1>
	<ul>
END

##
# Iterate through sites/codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "sites_by_size_then_name";
foreach $site_url ( sort ($SortMethod keys (%sites) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($sites{$site_url}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($sites{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $code ( sort ( { $sitesxcodes{$site_url}{$b}->{size} <=> $sitesxcodes{$site_url}{$a}->{size} || $a cmp $b} keys ( %{ $sitesxcodes{$site_url} } ) ) )
		{
			next unless $sitesxcodes{$site_url}{$code}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($sitesxcodes{$site_url}{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="usersxsites-hits">Top Users/Sites by Visits</a></h1>
	<ul>
END

##
# Iterate through users/sites sorted by visits.
##
$SortMethod = "users_by_visits_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	next unless ($users{$user_name}->{count} > $cfgMinHits);
	print OUTPUT "  <li>" . $users{$user_name}->{count} . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n";  
	print OUTPUT "	<ul>\n"; 

	$SubItemsLeft = $cfgNumberToShow;
	foreach $site_url ( sort ( { $usersxsites{$user_name}{$b}->{count} <=> $usersxsites{$user_name}{$a}->{count} || $a cmp $b } keys ( %{ $usersxsites{$user_name} } ) ) )
	{
		# Only show top x entries.
		if ($SubItemsLeft > 0)
		{
			next unless $usersxsites{$user_name}{$site_url}->{count} > $cfgMinHits;
			print OUTPUT "	  <li>" . $usersxsites{$user_name}{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
			$SubItemsLeft--;
		}
	}
	print OUTPUT "	</ul>\n"; 

}

print OUTPUT <<END;
	</ul>
	<h1><a name="usersxsites-size">Top Users/Sites by Size</a></h1>
	<ul>
END

##
# Iterate through users/sites sorted by size.
##
$SortMethod = "users_by_size_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	next unless ($users{$user_name}->{size} > $cfgMinSize);
	print OUTPUT "  <li>" . format_size($users{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
	print OUTPUT "	<ul>\n"; 

	$SubItemsLeft = $cfgNumberToShow;
	foreach $site_url ( sort ( { $usersxsites{$user_name}{$b}->{size} <=> $usersxsites{$user_name}{$a}->{size} || $a cmp $b } keys ( %{ $usersxsites{$user_name} } ) ) )
	{
		# Only show top x entries.
		if ($SubItemsLeft > 0)
		{
			next unless $usersxsites{$user_name}{$site_url}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($usersxsites{$user_name}{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a> (". $usersxsites{$user_name}{$site_url}->{count} .")</li>\n";
			$SubItemsLeft--;
		}
	}
	print OUTPUT "	</ul>\n"; 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="usersxcodes-hits">Top Users/Code by Visits</a></h1>
	<ul>
END

##
# Iterate through users/code sorted by visits.
##
$SortMethod = "users_by_visits_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	next unless ($users{$user_name}->{count} > $cfgMinHits);
	print OUTPUT "  <li>" . $users{$user_name}->{count} . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
	print OUTPUT "	<ul>\n"; 

	foreach $code ( sort ( { $usersxcodes{$user_name}{$b}->{count} <=> $usersxcodes{$user_name}{$a}->{count} || $a cmp $b } keys ( %{ $usersxcodes{$user_name} } ) ) )
	{
		next unless $usersxcodes{$user_name}{$code}->{count} > $cfgMinHits;
		print OUTPUT "	 <li>" . $usersxcodes{$user_name}{$code}->{count} . "<a href=\"#" . $code . "/\">" . $code . "</a></li>\n";
	}
	print OUTPUT "	</ul>\n"; 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="usersxcodes-size">Top Users/Codes by Size</a></h1>
	<ul>
END

##
# Iterate through users/sites sorted by size.
##
$SortMethod = "users_by_size_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	next unless ($users{$user_name}->{size} > $cfgMinSize);
	print OUTPUT "  <li>" . format_size($users{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a> (". $users{$user_name}->{count} .")</li>\n"; 
	print OUTPUT "	<ul>\n"; 

	$SubItemsLeft = $cfgNumberToShow;
	foreach $code ( sort ( { $usersxcodes{$user_name}{$b}->{size} <=> $usersxcodes{$user_name}{$a}->{size} || $a cmp $b } keys ( %{ $usersxcodes{$user_name} } ) ) )
	{
		next unless $usersxcodes{$user_name}{$code}->{size} > $cfgMinSize;
		print OUTPUT "   <li>" . format_size($usersxcodes{$user_name}{$code}->{size}) . "<a href=\"#" . $code . "/\">" . $code . "</a></li>\n";
	}
	print OUTPUT "	</ul>\n"; 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hostsxsites-hits">Top $cfgNumberToShow Hosts (IPs)/Sites by Visits</a></h1>
	<ul>
END

##
# Iterate through hosts/sites sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "hosts_by_visits_then_name";
foreach $host_ip ( sort ($SortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($hosts{$host_ip}->{count} > $cfgMinHits);
		print OUTPUT "  <li>" . $hosts{$host_ip}->{count} . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		$SubItemsLeft = $cfgNumberToShow;
		foreach $site_url ( sort ( { $hostsxsites{$host_ip}{$b}->{count} <=> $hostsxsites{$host_ip}{$a}->{count} || $a cmp $b } keys ( %{ $hostsxsites{$host_ip} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $hostsxsites{$host_ip}{$site_url}->{count} > $cfgMinHits;
				print OUTPUT "	  <li>" . $hostsxsites{$host_ip}{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
				$SubItemsLeft--;
			}
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hostsxsites-size">Top $cfgNumberToShow Hosts (IPs)/Sites by Size</a></h1>
	<ul>
END

##
# Iterate through hosts/sites sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "hosts_by_size_then_name";
foreach $host_ip ( sort ($SortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($hosts{$host_ip}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($hosts{$host_ip}->{size}) . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a> (". $hosts{$host_ip}->{count} .")</li>\n"; 
		print OUTPUT "	<ul>\n"; 

		$SubItemsLeft = $cfgNumberToShow;
		foreach $site_url ( sort ( { $hostsxsites{$host_ip}{$b}->{size} <=> $hostsxsites{$host_ip}{$a}->{size} || $a cmp $b } keys ( %{ $hostsxsites{$host_ip} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $hostsxsites{$host_ip}{$site_url}->{size} > $cfgMinSize;
				print OUTPUT "     <li>" . format_size($hostsxsites{$host_ip}{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a> (". $hostsxsites{$host_ip}{$site_url}->{count} .")</li>\n";
				$SubItemsLeft--;
			}
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hostsxcodes-hits">Top $cfgNumberToShow Hosts (IPs)/Codes by Visits</a></h1>
	<ul>
END

##
# Iterate through hosts (IPs)/Codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "hosts_by_visits_then_name";
foreach $host_ip ( sort ($SortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($hosts{$host_ip}->{count} > $cfgMinHits);
		print OUTPUT "  <li>" . $hosts{$host_ip}->{count} . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		foreach $code ( sort ( { $hostsxcodes{$host_ip}{$b}->{count} <=> $hostsxcodes{$host_ip}{$a}->{count} || $a cmp $b } keys ( %{ $hostsxcodes{$host_ip} } ) ) )
		{
			next unless $hostsxcodes{$host_ip}{$code}->{count} > $cfgMinHits;
			print OUTPUT "	  <li>" . $hostsxcodes{$host_ip}{$code}->{count} . "<a href=\"#" . $code . "/\">" . $code . "</a></li>\n";
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hostsxcodes-size">Top $cfgNumberToShow Hosts (IPs)/Code by Size</a></h1>
	<ul>
END

##
# Iterate through hosts (IPs)/Codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "hosts_by_size_then_name";
foreach $host_ip ( sort ($SortMethod keys (%hosts) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($hosts{$host_ip}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($hosts{$host_ip}->{size}) . "<a href=\"#" . $host_ip . "\">" . $host_ip . "</a></li>\n"; 
		print OUTPUT "	<ul>\n"; 

		foreach $code ( sort ( { $hostsxcodes{$host_ip}{$b}->{size} <=> $hostsxcodes{$host_ip}{$a}->{size} || $a cmp $b } keys ( %{ $hostsxcodes{$host_ip} } ) ) )
		{
			next unless $hostsxcodes{$host_ip}{$code}->{size} > $cfgMinSize;
			print OUTPUT "     <li>" . format_size($hostsxcodes{$host_ip}{$code}->{size}) . "<a href=\"#" . $code . "/\">" . $code . "</a></li>\n";
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxsites-hits">Top $cfgNumberToShow HTTP Codes/Sites by Visits</a></h1>
	<ul>
END

##
# Iterate through codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_visits_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($codes{$code}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $codes{$code}->{count} . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		$SubItemsLeft = $cfgNumberToShow;
		foreach $site_url ( sort ( { $codesxsites{$code}{$b}->{count} <=> $codesxsites{$code}{$a}->{count} || $a cmp $b } keys ( %{ $codesxsites{$code} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $codesxsites{$code}{$site_url}->{count} > $cfgMinHits;
				print OUTPUT "	  <li>" . $codesxsites{$code}{$site_url}->{count} . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n";
				$SubItemsLeft--;
			}
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxsites-size">Top $cfgNumberToShow HTTP Codes/Sites by Size</a></h1>
	<ul>
END

##
# Iterate through codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_size_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($codes{$code}->{size} > $cfgMinSize);
		print OUTPUT "	<li>" . format_size($codes{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		print OUTPUT "	<ul>\n"; 

		$SubItemsLeft = $cfgNumberToShow;
		foreach $site_url ( sort ( { $codesxsites{$code}{$b}->{size} <=> $codesxsites{$code}{$a}->{size} || $a cmp $b } keys ( %{ $codesxsites{$code} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $codesxsites{$code}{$site_url}->{size} > $cfgMinSize;
				print OUTPUT "    <li>" . format_size($codesxsites{$code}{$site_url}->{size}) . "<a href=\"http://" . $site_url . "/\">" . $site_url . "</a></li>\n"; 
				$SubItemsLeft--;
			}
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxusers-hits">Top $cfgNumberToShow HTTP Codes/Users by Visits</a></h1>
	<ul>
END

##
# Iterate through codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_visits_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($codes{$code}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $codes{$code}->{count} . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		foreach $user ( sort ( { $codesxusers{$code}{$b}->{count} <=> $codesxusers{$code}{$a}->{count} || $a cmp $b } keys ( %{ $codesxusers{$code} } ) ) )
		{
			next unless $codesxusers{$code}{$user}->{count} > $cfgMinHits;
			print OUTPUT "	 <li>" . $codesxusers{$code}{$user}->{count} . "<a href=\"#" . $user . "/\">" . $user . "</a></li>\n";
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxusers-size">Top $cfgNumberToShow HTTP Codes/Users by Size</a></h1>
	<ul>
END

##
# Iterate through codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_size_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($codes{$code}->{size} > $cfgMinSize);
		print OUTPUT "	<li>" . format_size($codes{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		print OUTPUT "	<ul>\n"; 
		
		foreach $user ( sort ( { $codesxusers{$code}{$b}->{size} <=> $codesxusers{$code}{$a}->{size} || $a cmp $b } keys ( %{ $codesxusers{$code} } ) ) )
		{
			next unless $codesxusers{$code}{$user}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($codesxusers{$code}{$user}->{size}) . "<a href=\"#" . $user . "/\">" . $user . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxhosts-hits">Top $cfgNumberToShow HTTP Codes/Hosts (IPs) by Visits</a></h1>
	<ul>
END

##
# Iterate through codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_visits_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($codes{$code}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $codes{$code}->{count} . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		foreach $host_ip ( sort ( { $codesxhosts{$code}{$b}->{count} <=> $codesxhosts{$code}{$a}->{count} || $a cmp $b } keys ( %{ $codesxhosts{$code} } ) ) )
		{
			next unless $codesxhosts{$code}{$host_ip}->{count} > $cfgMinHits;
			print OUTPUT "	  <li>" . $codesxhosts{$code}{$host_ip}->{count} . "<a href=\"#" . $host_ip . "/\">" . $host_ip . "</a></li>\n";
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxhosts-size">Top $cfgNumberToShow HTTP Codes/Hosts (IPs) by Size</a></h1>
	<ul>
END

##
# Iterate through codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "codes_by_size_then_name";
foreach $code ( sort ($SortMethod keys (%codes) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($codes{$code}->{size} > $cfgMinSize);
		print OUTPUT "	<li>" . format_size($codes{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		print OUTPUT "	<ul>\n"; 
		
		foreach $host_ip ( sort ( { $codesxhosts{$code}{$b}->{size} <=> $codesxhosts{$code}{$a}->{size} || $a cmp $b } keys ( %{ $codesxhosts{$code} } ) ) )
		{
			next unless $codesxhosts{$code}{$host_ip}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($codesxhosts{$code}{$host_ip}->{size}) . "<a href=\"#" . $host_ip . "/\">" . $host_ip . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

##
# Print Footer HTML
##
print OUTPUT <<END;
	</ul>
	<div id="Footer">Very badly hacked out by <a href="mailto://camiloeh\@gmail.com">Yours truly</a>. 
	Based on the work of <a href="http://davehope.co.uk/projects/perl-squid-reporting/">Dave Hope</a> and 
	<a href="http://backpan.perl.org/authors/id/S/SA/SAVA">Sava Chankov</a>.</div>
	</body>
</html>
END

# reporting stats
$end_run = time();
$run_time = $end_run - $start_run;
print "report creation took $run_time seconds\n";

##
# Sort sites by frequency visited, then alphabetically.
##
sub sites_by_visits_then_name {
	$sites{$b}->{count} <=> $sites{$a}->{count} 
		||
	$a cmp $b
}

##
# Sort by size, then alphabetically.
##
sub sites_by_size_then_name {
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
	$a cmp $b;
}

##
# Sort codes by size, then alphabetically.
##
sub codes_by_size_then_name {
	$codes{$b}->{size} <=> $codes{$a}->{size} 
		||
	$a cmp $b;
}

##
# Sort verbs by frequency visited, then alphabetically.
##
sub verbs_by_visits_then_name {
	$methods{$b}->{count} <=> $methods{$a}->{count} 
		||
	$a cmp $b;
}
##
# Sort verbs by size, then alphabetically.
##
sub verbs_by_size_then_name {
	$methods{$b}->{size} <=> $methods{$a}->{size} 
		||
	$a cmp $b;
}


sub print_usage {
	print "Usage: $0 dir [n] [file] \n";
	print "Where:\n";
	print "    dir  - the directory with winroute log files\n";
	print "    n    - show only the top n items.\n";
	print "    file - the file name to store the HTML report\n";
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