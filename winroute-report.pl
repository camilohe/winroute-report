#!/usr/bin/perl -w
#
#$Id: winroute-report.pl, v 1.64, 2012/07/19 12:28 camilohe Exp camilohe$
#
# Copyright (c)2011 Camilo E. Hidalgo Estevez <camiloehe@gmail.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the GNU General Public License

##
##  Winroute Top Users, Pages reporting script.
## 
##  Description:
##	This script will parse the specified Winroute logfile and generate an HTML
##	report with top users/pages by visits/size.
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
##		+ Fixed issue with accessing on ports other than 80 (handle :port in page url).
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
##		+ Added HTTP codes x Pages reports.
##	1.3.1
##		+ Added Users x Pages reports.
##		+ Added Pages x Users reports.
##	1.3.2
##		+ Added Hosts (IPs)/Pages reports.
##	1.4.0
##		+ Added Pages x Hosts reports.
##		+ Added Pages x Codes reports.
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
##	1.6.2
##		+ Added Methods reports.
##		+ Better perldoc
##	1.6.3
##		+ Added Types reports.
##	1.6.4
##		+ Replaced sites by pages and a few minor changes.
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
my $ver = "1.63";

##
# Stop editing here unless you know what you're doing.
##
my $cfgDate = localtime; # gmtime;
my ($ip, $minus, $user, $datetime, $timezone, $http_method, $url, $http_ver, $http_code, $http_size, $plus);
my ($SortMethod, $row, $page_url, %pages, $dir, $file, $ItemsLeft, $SubItemsLeft);
my (%users, $user_name, %hosts, $host_ip, %codes, $code, $method, $type);
my (%pagesxusers, %pagesxcodes, %pagesxhosts, %usersxpages, %usersxcodes, %hostsxpages, %hostsxcodes);
my (%codesxpages, %codesxusers, %codesxhosts, %methods, %types, %typesxusers, %typesxhosts);

$dir = $ARGV[0];
if (!$dir) {print_usage();}
if ($dir =~ m/[\/\-]\?/ ) {print_usage();}
if ($dir =~ m/[\/\-][hH]/ ) {print_usage();}
if ($dir =~ m/[\/\-][vV]/ ) {print_version();}

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

		# If the user is invalid (which occurs occasionally in my logs, no idea why),
		# then don't add it to the list.
		if ($user !~ m/^[a-zA-Z-]+$/) 
		{
			print "  Bad user:$user\n" if ($debug>1);
			print "    IP: $ip, Page: $page_url, Code: $http_code, Size: $http_size\n" if ($debug>2);
			print "    Row: $row\n" if ($debug>3);
			$bad_lines++;
			next;
		}

		# If the size is non numeric (which also occurs occasionally in my logs, no idea
		# why), then don't add it to the list.
		if ($http_size !~ m/^[0-9]+$/ )
		{
			print "  Bad size:$http_size\n" if ($debug>1);
			print "    IP: $ip, Page: $page_url, Code: $http_code, Size: $http_size\n" if ($debug>2);
			print "    Row: $row\n" if ($debug>3);
			$bad_lines++;
			next;
		}

		# Get the site base url, e.g. what is between the second and the third slash in 
		# http://wc.cmc.com.cu:3000/WorldClient.dll?View=Logout
##		($site_url) = ($url =~ m{ ([A-Za-z0-9\.\-\:]+) }x );

		# Match what is between the second slash and the first question mark or non allowed 
		# character or to the end -- I think ;-) 
##		($page_url) = ($url =~ m{ ([A-Za-z0-9\.\-\:\/\_\%]+) }x );
##		($page_url) = ($url =~ m{ ([A-Za-z0-9\.\-\:\/\_\%\?\&\+\;]+) }x );

		# Remove leading " from http method 
		$http_method =~ s/\"//;

##		$page_url = "$http_method $url";
		$page_url = $url;

		($type) = ($url =~ m{ (\.[A-Za-z0-9]+)$ }x );
		$type =	"n/a" unless ($type);
		print "  Type:$type\n" if ($debug>2);
		
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

		# Count type.
		if (!$types{$type})
		{
			$types{$type}->{count} = 0;
			print "  Found type:$type\n" if ($debug>1);
		}
		$types{$type}->{count}++;
		# Update type size. 
		if (!$types{$type}->{size})
		{
			$types{$type}->{size} = 0;
		}
		$types{$type}->{size} += $http_size;

		# Count type/user.
		if (!$typesxusers{$type}{$user})
		{
			$typesxusers{$type}{$user}->{count} = 0;
			print "  Found type/user:$type/$user\n" if ($debug>1);
		}
		$typesxusers{$type}{$user}->{count}++;
		# Update type/user size. 
		if (!$typesxusers{$type}{$user}->{size})
		{
			$typesxusers{$type}{$user}->{size} = 0;
		}
		$typesxusers{$type}{$user}->{size} += $http_size;

		# Count type/host.
		if (!$typesxhosts{$type}{$ip})
		{
			$typesxhosts{$type}{$ip}->{count} = 0;
			print "  Found type/host:$type/$ip\n" if ($debug>1);
		}
		$typesxhosts{$type}{$ip}->{count}++;
		# Update type/host size. 
		if (!$typesxhosts{$type}{$ip}->{size})
		{
			$typesxhosts{$type}{$ip}->{size} = 0;
		}
		$typesxhosts{$type}{$ip}->{size} += $http_size;

		# If hash already contains an entry for the exact page url.
		if ($pages{$page_url})
		{
			 $pages{$page_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$pages{$page_url}->{count} = 1;
			print "  Found page:$page_url\n" if ($debug>1);
		}
		# Update size of content for webpage regardless of content-type.
		if (!$pages{$page_url}->{size})
		{
			$pages{$page_url}->{size} = 0;
		}
		$pages{$page_url}->{size} = $pages{$page_url}->{size} + $http_size;

		# If hash already contains an entry for the exact page url/user.
		if ($pagesxusers{$page_url}{$user})
		{
			 $pagesxusers{$page_url}{$user}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$pagesxusers{$page_url}{$user}->{count} = 1;
			print "  Found page/user:$page_url/$user\n" if ($debug>1);
		}
		# Update size of content for webpage/user regardless of content-type.
		if (!$pagesxusers{$page_url}{$user}->{size})
		{
			$pagesxusers{$page_url}{$user}->{size} = 0;
		}
		$pagesxusers{$page_url}{$user}->{size} = $pagesxusers{$page_url}{$user}->{size} + $http_size;

		# If hash already contains an entry for the exact page url/code.
		if ($pagesxcodes{$page_url}{$http_code})
		{
			 $pagesxcodes{$page_url}{$http_code}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$pagesxcodes{$page_url}{$http_code}->{count} = 1;
			print "  Found page/code:$page_url/$http_code\n" if ($debug>1);
		}
		# Update size of content for webpage/code regardless of content-type.
		if (!$pagesxcodes{$page_url}{$http_code}->{size})
		{
			$pagesxcodes{$page_url}{$http_code}->{size} = 0;
		}
		$pagesxcodes{$page_url}{$http_code}->{size} = $pagesxcodes{$page_url}{$http_code}->{size} + $http_size;

		# If hash already contains an entry for the exact page url/host.
		if ($pagesxhosts{$page_url}{$ip})
		{
			 $pagesxhosts{$page_url}{$ip}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$pagesxhosts{$page_url}{$ip}->{count} = 1;
			print "  Found page/host:$page_url/$ip\n" if ($debug>1);
		}
		# Update size of content for webpage/code regardless of content-type.
		if (!$pagesxhosts{$page_url}{$ip}->{size})
		{
			$pagesxhosts{$page_url}{$ip}->{size} = 0;
		}
		$pagesxhosts{$page_url}{$ip}->{size} = $pagesxhosts{$page_url}{$ip}->{size} + $http_size;

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

		# If hash already contains an entry for the user/page.
		if ($usersxpages{$user}{$page_url})
		{
			 $usersxpages{$user}{$page_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$usersxpages{$user}{$page_url}->{count} = 1;
			print "  Found user/page:$user/$page_url\n" if ($debug);
		}
		# Update size for user/page.
		if (!$usersxpages{$user}{$page_url}->{size})
		{
			$usersxpages{$user}{$page_url}->{size} = 0;
		}
		$usersxpages{$user}{$page_url}->{size} = $usersxpages{$user}{$page_url}->{size} + $http_size;

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

		# If hash already contains an entry for the host/page.
		if ($hostsxpages{$ip}{$page_url})
		{
			 $hostsxpages{$ip}{$page_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$hostsxpages{$ip}{$page_url}->{count} = 1;
			print "  Found host/page:$ip/$page_url\n" if ($debug);
		}
		# Update size for host/page.
		if (!$hostsxpages{$ip}{$page_url}->{size})
		{
			$hostsxpages{$ip}{$page_url}->{size} = 0;
		}
		$hostsxpages{$ip}{$page_url}->{size} = $hostsxpages{$ip}{$page_url}->{size} + $http_size;

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
		
		# If hash already contains an entry for the code/page.
		if ($codesxpages{$http_code}{$page_url})
		{
			 $codesxpages{$http_code}{$page_url}->{count}++;
		}
		# If no matching entry exists, create one.
		else
		{
			$codesxpages{$http_code}{$page_url}->{count} = 1;
			print "  Found code/page:$http_code/$page_url\n" if ($debug);
		}
		# Update size for code/page.
		if (!$codesxpages{$http_code}{$page_url}->{size})
		{
			$codesxpages{$http_code}{$page_url}->{size} = 0;
		}
		$codesxpages{$http_code}{$page_url}->{size} = $codesxpages{$http_code}{$page_url}->{size} + $http_size;
		
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
		# Update size for code/page.
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
		# Update size for code/page.
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
		<title>Winroute Top Users and Pages Report</title>
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
	<h1>Winroute Top Users and Pages Report</h1>
	<p id="Generated">Report generated on $cfgDate</p>
END

print OUTPUT <<END;
	<h1>Available Reports</h1>
	<ul>
		<li>.<a href="#pages-hits">Top Pages by Visits</a></li>
		<li>.<a href="#pages-size">Top Pages by Size</a></li>
		<li>.<a href="#users-hits">Top Users by Visits</a></li>
		<li>.<a href="#users-size">Top Users by Size</a></li>
		<li>.<a href="#hosts-hits">Top Hosts by Visits</a></li>
		<li>.<a href="#hosts-size">Top Hosts by Size</a></li>
		<li>.<a href="#codes-hits">Top Codes by Visits</a></li>
		<li>.<a href="#codes-size">Top Codes by Size</a></li>
		<li>.<a href="#verbs-hits">Top Methods by Visits</a></li>
		<li>.<a href="#verbs-size">Top Methods by Size</a></li>
		<li>.<a href="#types-hits">Top Types by Visits</a></li>
		<li>.<a href="#types-size">Top Types by Size</a></li>
		<br/>
		<li>.<a href="#pagesxusers-hits">Top Pages/Users by Visits</a></li>
		<li>.<a href="#pagesxusers-size">Top Pages/Users by Size</a></li>
		<li>.<a href="#pagesxhosts-hits">Top Pages/Hosts by Visits</a></li>
		<li>.<a href="#pagesxhosts-size">Top Pages/Hosts by Size</a></li>
		<li>.<a href="#pagesxcodes-hits">Top Pages/Codes by Visits</a></li>
		<li>.<a href="#pagesxcodes-size">Top Pages/Codes by Size</a></li>
		<li>.<a href="#usersxpages-hits">Top Users/Pages by Visits</a></li>
		<li>.<a href="#usersxpages-size">Top Users/Pages by Size</a></li>
		<li>.<a href="#usersxcodes-hits">Top Users/Codes by Visits</a></li>
		<li>.<a href="#usersxcodes-size">Top Users/Codes by Size</a></li>
		<li>.<a href="#hostsxpages-hits">Top Hosts/Pages by Visits</a></li>
		<li>.<a href="#hostsxpages-size">Top Hosts/Pages by Size</a></li>
		<li>.<a href="#hostsxcodes-hits">Top Hosts/Codes by Visits</a></li>
		<li>.<a href="#hostsxcodes-size">Top Hosts/Codes by Size</a></li>
		<li>.<a href="#codesxpages-hits">Top Codes/Pages by Visits</a></li>
		<li>.<a href="#codesxpages-size">Top Codes/Pages by Size</a></li>
		<li>.<a href="#codesxusers-hits">Top Codes/Users by Visits</a></li>
		<li>.<a href="#codesxusers-size">Top Codes/Users by Size</a></li>
		<li>.<a href="#codesxhosts-hits">Top Codes/Hosts by Visits</a></li>
		<li>.<a href="#codesxhosts-size">Top Codes/Hosts by Size</a></li>
		<li>.<a href="#typesxusers-hits">Top Types/Users by Visits</a></li>
		<li>.<a href="#typesxusers-size">Top Types/Users by Size</a></li>
		<li>.<a href="#typesxhosts-hits">Top Types/Hosts by Visits</a></li>
		<li>.<a href="#typesxhosts-size">Top Types/Hosts by Size</a></li>
	</ul>
END

print OUTPUT <<END;
	<h1><a name="pages-hits">Top $cfgNumberToShow Pages by Visits</a></h1>
	<ul>
END

##
# Iterate through pages sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_visits_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "	<li>" . $pages{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a> (". format_size($pages{$page_url}->{size}) .")</li>\n" if ($pages{$page_url}->{count} > $cfgMinHits);
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pages-size">Top $cfgNumberToShow Pages by Size</a></h1>
	<ul>
END

##
# Iterate through pages sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_size_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		print OUTPUT "  <li>" . format_size($pages{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a> (". $pages{$page_url}->{count} .")</li>\n" if ($pages{$page_url}->{size} > $cfgMinSize);
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
	<h1><a name="types-hits">Top File Types by Visits</a></h1>
	<ul>
END

##
# Iterate through methods sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "types_by_visits_then_name";
foreach $type ( sort ($SortMethod keys (%types) ) )
{
	print OUTPUT "  <li>" . $types{$type}->{count} . "<a href=\"#" . $type . "\">" . $type . "</a> (". format_size($types{$type}->{size}) .")</li>\n" if ($types{$type}->{count} > $cfgMinHits); 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="types-size">Top File Types by Size</a></h1>
	<ul>
END

##
# Iterate through methods sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "types_by_size_then_name";
foreach $type ( sort ($SortMethod keys (%types) ) )
{
	print OUTPUT "  <li>" . format_size($types{$type}->{size}) . "<a href=\"#" . $type . "\">" . $type . "</a> (". $types{$type}->{count} .")</li>\n" if ($types{$type}->{size} > $cfgMinSize); 
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pagesxusers-hits">Top $cfgNumberToShow Pages/Users by Visits</a></h1>
	<ul>
END

##
# Iterate through pages/users sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_visits_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($pages{$page_url}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $pages{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $user_name ( sort ( { $pagesxusers{$page_url}{$b}->{count} <=> $pagesxusers{$page_url}{$a}->{count} || $a cmp $b} keys ( %{ $pagesxusers{$page_url} } ) ) )
		{
			next unless $pagesxusers{$page_url}{$user_name}->{count} > $cfgMinHits;
			print OUTPUT "    <li>" . $pagesxusers{$page_url}{$user_name}->{count} . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pagesxusers-size">Top $cfgNumberToShow Pages/Users by Size</a></h1>
	<ul>
END

##
# Iterate through pages/users sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_size_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($pages{$page_url}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($pages{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $user_name ( sort ( { $pagesxusers{$page_url}{$b}->{size} <=> $pagesxusers{$page_url}{$a}->{size} || $a cmp $b} keys ( %{ $pagesxusers{$page_url} } ) ) )
		{
			next unless $pagesxusers{$page_url}{$user_name}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($pagesxusers{$page_url}{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pagesxhosts-hits">Top $cfgNumberToShow Pages/Hosts (IPs) by Visits</a></h1>
	<ul>
END

##
# Iterate through pages/hosts sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_visits_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($pages{$page_url}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $pages{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $ip ( sort ( { $pagesxhosts{$page_url}{$b}->{count} <=> $pagesxhosts{$page_url}{$a}->{count} || $a cmp $b} keys ( %{ $pagesxhosts{$page_url} } ) ) )
		{
			next unless $pagesxhosts{$page_url}{$ip}->{count} > $cfgMinHits;
			print OUTPUT "    <li>" . $pagesxhosts{$page_url}{$ip}->{count} . "<a href=\"#" . $ip . "\">" . $ip . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pagesxhosts-size">Top $cfgNumberToShow Pages/Hosts (IPs) by Size</a></h1>
	<ul>
END

##
# Iterate through pages/hosts sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_size_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($pages{$page_url}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($pages{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $ip ( sort ( { $pagesxhosts{$page_url}{$b}->{size} <=> $pagesxhosts{$page_url}{$a}->{size} || $a cmp $b} keys ( %{ $pagesxhosts{$page_url} } ) ) )
		{
			next unless $pagesxhosts{$page_url}{$ip}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($pagesxhosts{$page_url}{$ip}->{size}) . "<a href=\"#" . $ip . "\">" . $ip . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pagesxcodes-hits">Top $cfgNumberToShow Pages/Codes by Visits</a></h1>
	<ul>
END

##
# Iterate through pages/codes sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_visits_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($pages{$page_url}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $pages{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $code ( sort ( { $pagesxcodes{$page_url}{$b}->{count} <=> $pagesxcodes{$page_url}{$a}->{count} || $a cmp $b} keys ( %{ $pagesxcodes{$page_url} } ) ) )
		{
			next unless $pagesxcodes{$page_url}{$code}->{count} > $cfgMinHits;
			print OUTPUT "    <li>" . $pagesxcodes{$page_url}{$code}->{count} . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="pagesxcodes-size">Top $cfgNumberToShow Pages/Codes by Size</a></h1>
	<ul>
END

##
# Iterate through pages/codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "pages_by_size_then_name";
foreach $page_url ( sort ($SortMethod keys (%pages) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($pages{$page_url}->{size} > $cfgMinSize);
		print OUTPUT "  <li>" . format_size($pages{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
		print OUTPUT "	<ul>\n"; 

		foreach $code ( sort ( { $pagesxcodes{$page_url}{$b}->{size} <=> $pagesxcodes{$page_url}{$a}->{size} || $a cmp $b} keys ( %{ $pagesxcodes{$page_url} } ) ) )
		{
			next unless $pagesxcodes{$page_url}{$code}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($pagesxcodes{$page_url}{$code}->{size}) . "<a href=\"#" . $code . "\">" . $code . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="usersxpages-hits">Top Users/Pages by Visits</a></h1>
	<ul>
END

##
# Iterate through users/pages sorted by visits.
##
$SortMethod = "users_by_visits_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	next unless ($users{$user_name}->{count} > $cfgMinHits);
	print OUTPUT "  <li>" . $users{$user_name}->{count} . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n";  
	print OUTPUT "	<ul>\n"; 

	$SubItemsLeft = $cfgNumberToShow;
	foreach $page_url ( sort ( { $usersxpages{$user_name}{$b}->{count} <=> $usersxpages{$user_name}{$a}->{count} || $a cmp $b } keys ( %{ $usersxpages{$user_name} } ) ) )
	{
		# Only show top x entries.
		if ($SubItemsLeft > 0)
		{
			next unless $usersxpages{$user_name}{$page_url}->{count} > $cfgMinHits;
			print OUTPUT "	  <li>" . $usersxpages{$user_name}{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
			$SubItemsLeft--;
		}
	}
	print OUTPUT "	</ul>\n"; 

}

print OUTPUT <<END;
	</ul>
	<h1><a name="usersxpages-size">Top Users/Pages by Size</a></h1>
	<ul>
END

##
# Iterate through users/pages sorted by size.
##
$SortMethod = "users_by_size_then_name";
foreach $user_name ( sort ($SortMethod keys (%users) ) )
{
	next unless ($users{$user_name}->{size} > $cfgMinSize);
	print OUTPUT "  <li>" . format_size($users{$user_name}->{size}) . "<a href=\"#" . $user_name . "\">" . $user_name . "</a></li>\n"; 
	print OUTPUT "	<ul>\n"; 

	$SubItemsLeft = $cfgNumberToShow;
	foreach $page_url ( sort ( { $usersxpages{$user_name}{$b}->{size} <=> $usersxpages{$user_name}{$a}->{size} || $a cmp $b } keys ( %{ $usersxpages{$user_name} } ) ) )
	{
		# Only show top x entries.
		if ($SubItemsLeft > 0)
		{
			next unless $usersxpages{$user_name}{$page_url}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($usersxpages{$user_name}{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a> (". $usersxpages{$user_name}{$page_url}->{count} .")</li>\n";
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
# Iterate through users/pages sorted by size.
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
	<h1><a name="hostsxpages-hits">Top $cfgNumberToShow Hosts (IPs)/Pages by Visits</a></h1>
	<ul>
END

##
# Iterate through hosts/pages sorted by visits.
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
		foreach $page_url ( sort ( { $hostsxpages{$host_ip}{$b}->{count} <=> $hostsxpages{$host_ip}{$a}->{count} || $a cmp $b } keys ( %{ $hostsxpages{$host_ip} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $hostsxpages{$host_ip}{$page_url}->{count} > $cfgMinHits;
				print OUTPUT "	  <li>" . $hostsxpages{$host_ip}{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
				$SubItemsLeft--;
			}
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="hostsxpages-size">Top $cfgNumberToShow Hosts (IPs)/Pages by Size</a></h1>
	<ul>
END

##
# Iterate through hosts/pages sorted by size.
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
		foreach $page_url ( sort ( { $hostsxpages{$host_ip}{$b}->{size} <=> $hostsxpages{$host_ip}{$a}->{size} || $a cmp $b } keys ( %{ $hostsxpages{$host_ip} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $hostsxpages{$host_ip}{$page_url}->{size} > $cfgMinSize;
				print OUTPUT "     <li>" . format_size($hostsxpages{$host_ip}{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a> (". $hostsxpages{$host_ip}{$page_url}->{count} .")</li>\n";
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
	<h1><a name="codesxpages-hits">Top $cfgNumberToShow HTTP Codes/Pages by Visits</a></h1>
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
		foreach $page_url ( sort ( { $codesxpages{$code}{$b}->{count} <=> $codesxpages{$code}{$a}->{count} || $a cmp $b } keys ( %{ $codesxpages{$code} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $codesxpages{$code}{$page_url}->{count} > $cfgMinHits;
				print OUTPUT "	  <li>" . $codesxpages{$code}{$page_url}->{count} . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n";
				$SubItemsLeft--;
			}
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="codesxpages-size">Top $cfgNumberToShow HTTP Codes/Pages by Size</a></h1>
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
		foreach $page_url ( sort ( { $codesxpages{$code}{$b}->{size} <=> $codesxpages{$code}{$a}->{size} || $a cmp $b } keys ( %{ $codesxpages{$code} } ) ) )
		{
			# Only show top x entries.
			if ($SubItemsLeft > 0)
			{
				next unless $codesxpages{$code}{$page_url}->{size} > $cfgMinSize;
				print OUTPUT "    <li>" . format_size($codesxpages{$code}{$page_url}->{size}) . "<a href=\"http://" . $page_url . "/\">" . $page_url . "</a></li>\n"; 
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

print OUTPUT <<END;
	</ul>
	<h1><a name="typesxusers-hits">Top $cfgNumberToShow File Types/Users by Visits</a></h1>
	<ul>
END

##
# Iterate through types sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "types_by_visits_then_name";
foreach $type ( sort ($SortMethod keys (%types) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($types{$type}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $types{$type}->{count} . "<a href=\"#" . $type . "\">" . $type . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		foreach $user ( sort ( { $typesxusers{$type}{$b}->{count} <=> $typesxusers{$type}{$a}->{count} || $a cmp $b } keys ( %{ $typesxusers{$type} } ) ) )
		{
			next unless $typesxusers{$type}{$user}->{count} > $cfgMinHits;
			print OUTPUT "	 <li>" . $typesxusers{$type}{$user}->{count} . "<a href=\"#" . $user . "/\">" . $user . "</a></li>\n";
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="typesxusers-size">Top $cfgNumberToShow File Types/Users by Size</a></h1>
	<ul>
END

##
# Iterate through codes sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "types_by_size_then_name";
foreach $type ( sort ($SortMethod keys (%types) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($types{$type}->{size} > $cfgMinSize);
		print OUTPUT "	<li>" . format_size($types{$type}->{size}) . "<a href=\"#" . $type . "\">" . $type . "</a></li>\n"; 
		print OUTPUT "	<ul>\n"; 
		
		foreach $user ( sort ( { $typesxusers{$type}{$b}->{size} <=> $typesxusers{$type}{$a}->{size} || $a cmp $b } keys ( %{ $typesxusers{$type} } ) ) )
		{
			next unless $typesxusers{$type}{$user}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($typesxusers{$type}{$user}->{size}) . "<a href=\"#" . $user . "/\">" . $user . "</a></li>\n"; 
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="typesxhosts-hits">Top $cfgNumberToShow File Types/Hosts (IPs) by Visits</a></h1>
	<ul>
END

##
# Iterate through types sorted by visits.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "types_by_visits_then_name";
foreach $type ( sort ($SortMethod keys (%types) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($types{$type}->{count} > $cfgMinHits);
		print OUTPUT "	<li>" . $types{$type}->{count} . "<a href=\"#" . $type . "\">" . $type . "</a></li>\n";  
		print OUTPUT "	<ul>\n"; 

		foreach $host_ip ( sort ( { $typesxhosts{$type}{$b}->{count} <=> $typesxhosts{$type}{$a}->{count} || $a cmp $b } keys ( %{ $typesxhosts{$type} } ) ) )
		{
			next unless $typesxhosts{$type}{$host_ip}->{count} > $cfgMinHits;
			print OUTPUT "	  <li>" . $typesxhosts{$type}{$host_ip}->{count} . "<a href=\"#" . $host_ip . "/\">" . $host_ip . "</a></li>\n";
		}
		print OUTPUT "	</ul>\n"; 
		$ItemsLeft--;
	}
}

print OUTPUT <<END;
	</ul>
	<h1><a name="typesxhosts-size">Top $cfgNumberToShow File Types/Hosts (IPs) by Size</a></h1>
	<ul>
END

##
# Iterate through types sorted by size.
##
$ItemsLeft = $cfgNumberToShow;
$SortMethod = "types_by_size_then_name";
foreach $type ( sort ($SortMethod keys (%types) ) )
{
	# Only show top x entries.
	if ($ItemsLeft > 0)
	{
		next unless ($types{$type}->{size} > $cfgMinSize);
		print OUTPUT "	<li>" . format_size($types{$type}->{size}) . "<a href=\"#" . $type . "\">" . $type . "</a></li>\n"; 
		print OUTPUT "	<ul>\n"; 
		
		foreach $host_ip ( sort ( { $typesxhosts{$type}{$b}->{size} <=> $typesxhosts{$type}{$a}->{size} || $a cmp $b } keys ( %{ $typesxhosts{$type} } ) ) )
		{
			next unless $typesxhosts{$type}{$host_ip}->{size} > $cfgMinSize;
			print OUTPUT "    <li>" . format_size($typesxhosts{$type}{$host_ip}->{size}) . "<a href=\"#" . $host_ip . "/\">" . $host_ip . "</a></li>\n"; 
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
# Sort pages by frequency vipaged, then alphabetically.
##
sub pages_by_visits_then_name {
	$pages{$b}->{count} <=> $pages{$a}->{count} 
		||
	$a cmp $b
}

##
# Sort by size, then alphabetically.
##
sub pages_by_size_then_name {
        $pages{$b}->{size} <=> $pages{$a}->{size}
                ||
        $a cmp $b
}

##
# Sort users by frequency vipaged, then alphabetically.
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
# Sort hosts by frequency vipaged, then alphabetically.
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
# Sort codes by frequency vipaged, then alphabetically.
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
# Sort verbs by frequency vipaged, then alphabetically.
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

##
# Sort types by frequency vipaged, then alphabetically.
##
sub types_by_visits_then_name {
	$types{$b}->{count} <=> $types{$a}->{count} 
		||
	$a cmp $b;
}
##
# Sort types by size, then alphabetically.
##
sub types_by_size_then_name {
	$types{$b}->{size} <=> $types{$a}->{size} 
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

sub print_version {
	print "$0 version: $ver";
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

winroute-report.pl  -- a winroute proxy log analizer


=head1 DESCRIPTION


Processes winroute logs from a given folder and writes out an HTML file with a 
report containing: 

=over 2

=item * Top Pages by Visits

=item * Top Pages by Size

=item * Top Users by Visits

=item * Top Users by Size

=item * Top Hosts by Visits

=item * Top Hosts by Size

=item * Top Codes by Visits

=item * Top Codes by Size

=item * Top Methods by Visits

=item * Top Methods by Size

=item * Top Types by Visits

=item * Top Types by Size

=item * Top Pages/Users by Visits

=item * Top Pages/Users by Size

=item * Top Pages/Hosts by Visits

=item * Top Pages/Hosts by Size

=item * Top Pages/Codes by Visits

=item * Top Pages/Codes by Size

=item * Top Users/Pages by Visits

=item * Top Users/Pages by Size

=item * Top Users/Codes by Visits

=item * Top Users/Codes by Size

=item * Top Hosts/Pages by Visits

=item * Top Hosts/Pages by Size

=item * Top Hosts/Codes by Visits

=item * Top Hosts/Codes by Size

=item * Top Codes/Pages by Visits

=item * Top Codes/Pages by Size

=item * Top Codes/Users by Visits

=item * Top Codes/Users by Size

=item * Top Codes/Hosts by Visits

=item * Top Codes/Hosts by Size

=back

=head1 USAGE

=item winroute-report <logdir> [[N] reportfile]

=over 2

=item * logdir 

The directory with winroute logs 

=item * N

The number of top items to show (defaults to 100) 

=item * reportfile

The file name of the report (defaults to logsdir.html).

=back

=head1 SAMPLES

=over 2

=item winroute-report trazas

Parses log files in folder trazas and writes out the report to file trazas.thml including top 100 pages by default.

=item winroute-report trazas 50 report.html 

Parses log files in folder trazas and writes out the report to file report.thml including top 50 pages as specified.

=item winroute-report trazas 20 

Parses log files in folder trazas and writes out the report to file trazas.thml including top 20 pages as specified.

=back

=head1 PREREQUISITES

This script requires the C<strict> module. 

=head1 AUTHORS

Badly hacked out by Camilo Ernesto Hidalgo Estevez C<(camilohe@gmail.com)>>. 
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
