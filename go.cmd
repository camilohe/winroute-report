@echo off
REM analyze abyss web server logs
if not exist \\cmc1\c$\ goto :nocmc1
call update "\\cmc1\c$\cmc\s\abyss\log" abyss access.*
del abyss\update*
:nocmc1
visitors -A --debug abyss/* > abyss.html
start abyss.html

REM analyze kerio winroute proxy server logs
if not exist \\cmc3\c$\ goto :nocmc3
call update "\\cmc3\c$\Programs\Kerio\WinRoute Firewall\logs" trazas http.log.*
del trazas\update*
:nocmc3
visited -A --debug trazas/* > visited.html
start visited.html

REM generate report via perl script
winroute-report trazas
start trazas.html
