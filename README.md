NAME
    winroute-report.pl -- version? who knows or care!

[![Build Status](https://travis-ci.org/camilohe/winroute-report.svg?branch=master)](https://travis-ci.org/camilohe/winroute-report)

DESCRIPTION
    Processes winroute logs from a given folder and writes out an HTML file
    with a report containing:

    * Top Sites by Visits
    * Top Sites by Size
    * Top Users by Visits
    * Top Users by Size
    * Top Hosts by Visits
    * Top Hosts by Size
    * Top Codes by Visits
    * Top Codes by Size
    * Top Methods by Visits
    * Top Methods by Size
    * Top Sites/Users by Visits
    * Top Sites/Users by Size
    * Top Sites/Hosts by Visits
    * Top Sites/Hosts by Size
    * Top Sites/Codes by Visits
    * Top Sites/Codes by Size
    * Top Users/Sites by Visits
    * Top Users/Sites by Size
    * Top Users/Codes by Visits
    * Top Users/Codes by Size
    * Top Hosts/Sites by Visits
    * Top Hosts/Sites by Size
    * Top Hosts/Codes by Visits
    * Top Hosts/Codes by Size
    * Top Codes/Sites by Visits
    * Top Codes/Sites by Size
    * Top Codes/Users by Visits
    * Top Codes/Users by Size
    * Top Codes/Hosts by Visits
    * Top Codes/Hosts by Size

USAGE
    winroute-report <logdir> [[N] reportfile]

    * logdir
      The directory with winroute logs

    * N
      The number of top items to show (defaults to 100)

    * reportfile
      The file name of the report (defaults to logsdir.html).

SAMPLES
    winroute-report trazas
      Parses log files in folder trazas and writes out the report to file
      trazas.thml including top 100 sites by default.

    winroute-report trazas 50 report.html
      Parses log files in folder trazas and writes out the report to file
      report.thml including top 50 sites as specified.

    winroute-report trazas 20
      Parses log files in folder trazas and writes out the report to file
      trazas.thml including top 20 sites as specified.

PREREQUISITES
    This script requires the "strict" module.

AUTHORS
    Badly hacked out by Camilo E. Hidalgo Estevez <camiloeh@gmail.com>.
    Based on previous work by:

    Dave Hope <http://davehope.co.uk/projects/perl-squid-reporting/>.
    Sava Chankov <http://backpan.perl.org/authors/id/S/SA/SAVA>.

NOTES
    If you got time and want some fun!?, set the variable $debug to some
    number from 0 to 9.

    And here you have a sample line from the winroute log for reference:

    192.168.206.15 - Admin [16/Feb/2011:17:19:57 -0500] "GET http://z.about.com/6/g/ruby/b/rss2.xml HTTP/1.1" 200 10870 +3

