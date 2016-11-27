#!/usr/bin/perl -w

use strict;
use DBI;
use lib "./Classes";

## app Version
my $versionId = "1.01";

## db classes
use Lottery::lottery_draws;

## mysql user connection details
my $db ="shinyide2_lottery";
my $user = "shinyide2_ro";
my $pass = "R3l9c675";
my $host="10.169.0.121";

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

## use db class to access table and display contents

my $lottery = new lottery_draws;
$lottery->ResetKEYFIELDS;
$lottery->CreateSELECT;

#print "Statement : ".$lottery->{SQL_STATEMENT}->[0]."\n\n";
my $stHandle = $dbHandle->prepare($lottery->{SQL_STATEMENT}->[0]);
$stHandle->execute;
while (my @fields = $stHandle->fetchrow) {
    $lottery->DataINITIALISE(@fields);
    $lottery->DataDISPLAY();
}
$stHandle->finish;

print "\nEnd of Line...\n\n";

exit(0);
