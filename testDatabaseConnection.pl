#!/usr/bin/perl -w
 
use DBI;
 
## mysql user database name
my $db ="shinyide2_lottery";

## mysql database user name
my $user = "shinyide2_access";
 
## mysql database password
my $pass = "2dkh7Gk6SKB";
 
## user hostname : This should be "localhost" but it can be diffrent too
my $host="10.169.0.121";
 
## SQL query
my $query = "show tables";
 
my $dbh = DBI->connect("DBI:mysql:$db:$host", $user, $pass);
$sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
 
my $rv = $sqlQuery->execute or die "can't execute the query: $sqlQuery->errstr";
 
print "*******************************************\n";
print "*        Database Connection Test         *\n";
print "*******************************************\n\n";

print "List of tables in Database: ".$db."\n\n";

while (@row= $sqlQuery->fetchrow_array()) {
	my $table = $row[0];
	print $table."\n";
}
print "\n";
 
my $rc = $sqlQuery->finish;
exit(0);
