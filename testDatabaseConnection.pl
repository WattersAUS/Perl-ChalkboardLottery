#!/usr/bin/perl -w
#
#	Program: testDatabaseConnection.pl (2016-11-27) G.J.Watson
#
#	Purpose: test connectivity to the database / tables
#
#	Date		Version		Note
#	==========	=======		================================================================
#	2016-11-21	v1.00		First cut of code (based on old db conn script)
#	2016-11-27	v1.01		Use new Perl DB Classes and add in table access test
#	2016-11-27	v1.02		Retrieve one record from each table
#
use strict;
use DBI;
use lib "./Classes";

## app Version
my $versionId = "1.02";

## db classes
use Lottery::draw_history;
use Lottery::logger;
use Lottery::lottery_draws;
use Lottery::number_usage;

#-----------------------------------------------------------------------------
# print out DEBUG messages allowing for possible date/time stamp inclusion
#-----------------------------------------------------------------------------

sub DebugMessage {
        my $debug_msg = shift;
        print "\nDEBUG: ";
        if (defined($debug_msg)) {
                print $debug_msg;
        }
        print "\n\n";
        return;
}

#-----------------------------------------------------------------------------
# rest of the script
#-----------------------------------------------------------------------------

## mysql user connection details
my $db   = "";
my $user = "";
my $pass = "";
my $host = "";

## SQL query
my $tableQuery = "show tables";

my $dbHandle  = DBI->connect("DBI:mysql:$db:$host", $user, $pass);
my $sqlHandle = $dbHandle->prepare($tableQuery) or die "Can't prepare ".$tableQuery."\nERROR: ".$dbHandle->errstr."\n";

$sqlHandle->execute or die "Can't execute ".$tableQuery."\nERROR: ".$sqlHandle->errstr."\n";

print "\n*******************************************\n";
print "* Database Connection Test          v".$versionId." *\n";
print "*******************************************\n\n";
print "List of tables in Database: ".$db."\n\n";

while (my @row = $sqlHandle->fetchrow_array()) {
    my $tableName = $row[0];
    print "Table: ".$tableName."\n";
}
print "\n";
$sqlHandle->finish;

## use db class to access table and display contents of a single record

my $lottery = new lottery_draws;
$lottery->ResetKEYFIELDS;
$lottery->CreateSELECT;
$lottery->{SQL_STATEMENT}->[0] .= " LIMIT 1";
DebugMessage($lottery->{SQL_STATEMENT}->[0]);
my $stHandle = $dbHandle->prepare($lottery->{SQL_STATEMENT}->[0]);
$stHandle->execute;
while (my @fields = $stHandle->fetchrow) {
    $lottery->DataINITIALISE(@fields);
    $lottery->DataDISPLAY();
}
$stHandle->finish;

##

my $draw_history = new draw_history;
$draw_history->ResetKEYFIELDS;
$draw_history->CreateSELECT;
$draw_history->{SQL_STATEMENT}->[0] .= " LIMIT 1";
DebugMessage($draw_history->{SQL_STATEMENT}->[0]);
$stHandle = $dbHandle->prepare($draw_history->{SQL_STATEMENT}->[0]);
$stHandle->execute;
while (my @fields = $stHandle->fetchrow) {
    $draw_history->DataINITIALISE(@fields);
    $draw_history->DataDISPLAY();
}
$stHandle->finish;

##

my $number_usage = new number_usage;
$number_usage->ResetKEYFIELDS;
$number_usage->CreateSELECT;
$number_usage->{SQL_STATEMENT}->[0] .= " LIMIT 1";
DebugMessage($number_usage->{SQL_STATEMENT}->[0]);
$stHandle = $dbHandle->prepare($number_usage->{SQL_STATEMENT}->[0]);
$stHandle->execute;
while (my @fields = $stHandle->fetchrow) {
    $number_usage->DataINITIALISE(@fields);
    $number_usage->DataDISPLAY();
}
$stHandle->finish;

##

my $logger = new logger;
$logger->ResetKEYFIELDS;
$logger->CreateSELECT;
$logger->{SQL_STATEMENT}->[0] .= " LIMIT 1";
DebugMessage($logger->{SQL_STATEMENT}->[0]);
$stHandle = $dbHandle->prepare($logger->{SQL_STATEMENT}->[0]);
$stHandle->execute;
while (my @fields = $stHandle->fetchrow) {
    $logger->DataINITIALISE(@fields);
    $logger->DataDISPLAY();
}
$stHandle->finish;

##

print "\nEnd of Line...\n\n";

exit(0);
