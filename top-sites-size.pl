#!/usr/bin/perl -wT
##
##  Squid Top Sites reporting script.
## 
##  Description:
##	This script will parse the specified squid logfile and count up the
##	frequency a URL occurs to provide a list of most frequently accessed
##	sites.
##
##  Author:
##	Dave Hope  - http://davehope.co.uk
##	Sava Chankov ( Author of squid-report.pl )
##
##  Known Issues:
##	+ Requests to the webserver on the proxy give weird results?
##
##  Changelog:
##	1.0.0	(Initial fork of squid-report.pl v1.2)
##	1.0.1
##		+ Changed to have configuration held in-file.
##		+ Removed last-visited date.
##		+ Consolidated sites with/without www.		
##		+ Improved UI slightly.
##	1.0.2
##		+ Fixed issue with accessing on ports other than 80.
##		+ Fixed promblem with ftp:// entries in log.
##
##	1.2.0
##		+ Added ability to sort by size, rather than frequency.
##
##  License:
##  	This program is free software; you can redistribute it and/or modify it
##	under the GNU General Public License.
##
##	This script is based on  'squid-report.pl' v1.2 by Sava Chankov and has
##	been adjusted for my specific requirements.
##
##	The original script can be found here:
##		http://backpan.perl.org/authors/id/S/SA/SAVA/squid-report.pl
##

use strict;

##
# Configuration.
##
my $cfgNumberToShow = 250;
my $cfgLog = "/var/log/squid3/access.log.1";
my $cfgOutput =	"/var/www/top-sites-size.htm";

# by_times_visited_then_name or by_size_then_name
my $cfgSortMethod = "by_size_then_name";


##
# Stop editing here unless you know what you're doing.
##
my $cfgDate = gmtime;
my $row;
my($epoch_time_miliseconds, $unknown_integer1, $ip, $tcp_and_http_code);
my($unknown_integer2, $http_method, $url, $minus, $squid_method_site_url, $content_type);
my($site_url, %sites);


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
		<title>Squid Top-Site Report</title>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
		<style type="text/css">
		<!--
			body { font: normal 1.0em 'Trebuchet MS' }
			ul { list-style-type: none }
			ul a { position: absolute; left: 150px }
			#Generated { margin: 0; padding: 0; font-style:italic }
			#Footer { color: #cecece; line-height: 150%; border-top: 1px solid #cecece; padding: 0.4em }
		-->
		</style>
	</head>
	<body>
	<h1>Most frequently visites sites</h1>
	<p id="Generated">Report generated on $cfgDate</p>
	<ul>
END


##
# Iterate through lines inaccess.log
##
open(LOG, "$cfgLog") or die "Can't open file $cfgLog!";
  
while(<LOG>)
{
	$row = $_;

	($epoch_time_miliseconds, $unknown_integer1, $ip, $tcp_and_http_code, $unknown_integer2, $http_method, $url, $minus, $squid_method_site_url, $content_type) = split(/\s+/, $row);

	# Not checking for http:// etc because we want to include CONNECT's and
	# multi-protocol data.
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

	# Only match html content.
	if($content_type =~ m{text/html})
	{
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
	}

	# Update size of content for website regardless of content-type.
	if (!$sites{$site_url}->{size})
	{
		$sites{$site_url}->{size} = 0;
	}
	$sites{$site_url}->{size} = $sites{$site_url}->{size} + $unknown_integer2;
}


##
# Iterate through visited sites.
##
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
	<div id="Footer">Producted by <a href="http://davehope.co.uk">Squid Top-Site Report Generator</a>.</div>
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
