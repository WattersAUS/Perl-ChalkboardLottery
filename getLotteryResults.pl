#!/usr/bin/perl -w
#
#	Program: updateLotteryResults.pl (2016-11-21) G.J.Watson
#
#	Purpose: download / parse / store results from the lottery games
#
#	Date		Version		Note
#	==========	=======		==================================================
#	2016-11-21	v0.01		First cut of code
#	2016-11-27	v0.02		First attempt at basic functionality
#	2016-11-28	v0.03		Moved logger write to sqlBuffer
#

use lib "./Classes";

use strict;
use vars qw($optDebug $optEmail $optHelp $optMailServer $optInsert $optTimestamp);
use Getopt::Std;
use DBI;
use File::Basename;
use MIME::Lite;

#-----------------------------------------------------------------------------
# ok here's the db objects to access
#-----------------------------------------------------------------------------

use Lottery::draw_history;
use Lottery::lottery_draws;
use Lottery::number_usage;

#-----------------------------------------------------------------------------
# only globals in the whole program (I hope)
#-----------------------------------------------------------------------------

my $version_id = "0.03";

#-----------------------------------------------------------------------------
# this holds sql statements batched up (bit like a transaction for each line)
#-----------------------------------------------------------------------------

my @sqlBuffer = qw();

#-----------------------------------------------------------------------------
# this holds the messages to be mailed to Shiny Ideas
#-----------------------------------------------------------------------------

my @mail_buffer = qw();

#-----------------------------------------------------------------------------
# special DEBUG message for help function
#-----------------------------------------------------------------------------

sub debugHelpMessage {
    my $debugMsg = shift;
    if (defined($debugMsg)) {
        print $debugMsg;
    }
    print "\n";
    return;
}

#-----------------------------------------------------------------------------
# print out DEBUG messages allowing for possible date/time stamp inclusion
#-----------------------------------------------------------------------------

sub debugMessage {
    my $debugMsg = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    if ($optTimestamp) {
		printf "[ %4d-%02d-%02d %02d:%02d:%02d ] ", $year+1900,$mon+1,$mday,$hour,$min,$sec;
    }
    print "DEBUG: ";
    if (defined($debugMsg)) {
            print $debugMsg;
    }
    print "\n";
    return;
}

#-----------------------------------------------------------------------------
# build a 'draw_history' record
#-----------------------------------------------------------------------------

sub buildNewDrawHistory {
	my $draw        = shift;
	my $drawDate    = shift;
	my $drawHistory = new draw_history;
	$drawHistory->draw($draw);
	$drawHistory->draw_date($drawDate);
	$drawHistory->CreateINSERT;
	push(@sqlBuffer, $drawHistory->{SQL_STATEMENT}->[0]);
	return;
}

#-----------------------------------------------------------------------------
# build a 'number_usage' record
#-----------------------------------------------------------------------------

sub buildNewNumberUsage {
    my $ident       = shift;
	my $draw        = shift;
	my $number      = shift;
	my $isSpecial   = shift;
	my $numberUsage = new number_usage;
    $numberUsage->ident($ident);
	$numberUsage->draw($draw);
	$numberUsage->number($number);
	$numberUsage->is_special($isSpecial);
	$numberUsage->CreateINSERT;
	push(@sqlBuffer, $numberUsage->{SQL_STATEMENT}->[0]);
	return;
}

#-----------------------------------------------------------------------------
# write to logger table
#-----------------------------------------------------------------------------

sub writeToLogger {
	my $dbHandle = shift;
	my $message  = shift;
	my $logger   = new logger;
	$logger->logger_description($message);
	$logger->logger_timestamp("now()");
	$logger->CreateINSERT;
	debugMessage($logger->{SQL_STATEMENT}->[0]) if ($optDebug);
    push(@sqlBuffer, $logger->{SQL_STATEMENT}->[0]);
	return;
}

#-----------------------------------------------------------------------------
# email to selected user
#-----------------------------------------------------------------------------

sub sendEmailMessage {
	my $fromWho = shift;
	my $toWhom  = shift;
	my $subject = shift;
	my $body    = shift;
	debugMessage("Sending mail message to ".$toWhom." (".$subject.")") if ($optDebug);
	my $mailMsg = MIME::Lite->new(
			From	=>	$fromWhom,
			To		=>	$toWhom,
			Subject	=>	$subject,
			Type	=>	'multipart/mixed'
	) or debugMessage("Failed to send mail message to ".$toWhom." (".$subject.")") if ($optDebug);
	$mailMsg->attach(
			Type	=>	'text/plain',
			Data	=>	$body
	);
	$mailMsg->send();
	return;
}

#-----------------------------------------------------------------------------
# break out and execute the 'wget' to retrieve the page containing results
#  wget https://url -O filename.txt
#-----------------------------------------------------------------------------

sub getResultsPage {
    my $url  = shift;
    my $file = shift;
    my $rc = system("wget", $url, , "-O", $file);
    die "system() call to execute 'wget' failed with status ".$rc unless $rc == 0;
    return;
}

#-----------------------------------------------------------------------------
# parse the file that will contain the lottery results and pass back to caller
#-----------------------------------------------------------------------------

sub extractResultsFromPage {
    my $draws = shift;
    my $file  = shift;

    # hold results here

    my @numbers = qw();
    my @special = qw();
    my $date    = "";

    # for the draw we are processing we need to know numbers/specials

    my $numbers     = $draws->{numbers}->[0];
    my $numbersTag  = $draws->{description}->[0];
    my $specials    = $draws->{specials}->[0];
    my $specialsTag = $draws->{specials_tag}->[0];

    # start extracting

    return (@numbers, @special, $date);
}

#-----------------------------------------------------------------------------
# we should now have an array full of SQL commands to apply to the DB
# if we don't have any ACTIVITY records then don't apply any
#
# after use make sure we zap it
#-----------------------------------------------------------------------------

sub processLotteryDraws {
    my $dbHandle = shift;

# iterate through configured lottery draws, we will get the 'next' draw
# as we expect to already have the draw set in the db

    my $draws = new lottery_draws;
    $draws->ResetKEYFIELDS;
    $draws->DataSAVE;
    $draws->CreateSELECT;
    debugMessage($draws->{SQL_STATEMENT}->[0]) if ($optDebug);
    my $sth = $dbHandle->prepare($draws->{SQL_STATEMENT}->[0]);
    $sth->execute;
    while (my @fields = $sth->fetchrow) {
        $draws->DataINITIALISE(@fields);
        $draws->DataSAVE;
        my $description  = $draws->{description}->[0];
        my $draw         = $draws->{draw}->[0];
        my $base_url     = $draws->{base_url}->[0];

# now we need to prep settings to get the page for the next draw, using the url and filename

        $draw++;
        my $filename     = lc($description);
        $filename        =~ s/\s/_/g;
        $filename        .= ".".$draw;
        my $url          = $base_url;
        $url             =~ s/DRAWNUMBER/$draw/g;
        debugMessage("Ready to process (".$draws->{description}->[0]."), draw (".$draw."), into file (".$filename."), using url (".$url.")") if ($optDebug);
        getResultsPage($url, $filename)
        if ! -f $filename {
            debugMessage("ERROR: Unable to find file (".$filename.") to process...\n");
        } else {
            my (@resultNumbers, @specialNumbers, $drawDate) = extractResultsFromPage($draws, $filename);
        }
    }
    $sth->finish;
    return;
}

#-----------------------------------------------------------------------------
# we should now have an array full of SQL commands to apply to the DB
# if we don't have any ACTIVITY records then don't apply any
#
# after use make sure we zap it
#-----------------------------------------------------------------------------

sub processSQLBuffer {
	my $dbHandle = shift;
    my $count    = 0;
	foreach my $sql_statement (@sqlBuffer) {
		debugMessage($sql_statement) if ($optDebug);
		if ($optInsert) {
			my $sth = $dbHandle->prepare($sql_statement);
			$sth->execute;
            $count++;
		}
	}
	@sqlBuffer = qw();
	return $count;
}

#-----------------------------------------------------------------------------
# db connection vars / command line params
#-----------------------------------------------------------------------------

my $db   = "shinyide2_lottery";
my $user = "shinyide2_ro";
my $pass = "R3l9c675";
my $host = "10.169.0.121";

#-----------------------------------------------------------------------------
# check for any command line params and set appropriately
#-----------------------------------------------------------------------------

getopts('dehim:t');

# help screen

if (defined($optHelp)) {
	debugHelpMessage("\n\n\tLottery Data Upload Utility ".$version_id);
	debugHelpMessage("\t================================");
	debugHelpMessage( "\t-i (Activate Writing to DB)");
	debugHelpMessage( "\t-h (view this HELP Mode)");
	debugHelpMessage( "\t-d (turn on DEBUG Mode)");
	debugHelpMessage( "\t-e (turn on EMAIL Mode)");
	debugHelpMessage( "\t-t (turn on date/time stamp on DEBUG messages)");
	debugHelpMessage( "\t-m <SMTP-server> (use this SMTP address and not SENDMAIL)\n\n");
	exit(0);
}

# date/time stamp on DEBUG messages

if (defined($optTimestamp)) {
	debugMessage("Date/Time Stamp Active") if ($optDebug);
} else {
    debugMessage("Date/Time Stamp Inactive") if ($optDebug);
}

# email mode

if (defined($optEmail)) {
	debugMessage("Email Sending Active") if ($optDebug);
} else {
	debugMessage("Email Sending Inactive") if ($optDebug);
}

if (defined($optMailServer)) {
	debugMessage("Mail Server: ".$opt_m) if ($optDebug);
	MIME::Lite->send('smtp', $opt_m, Timeout=>60);
}

#-----------------------------------------------------------------------------
# main code
#-----------------------------------------------------------------------------

my $dbHandle = DBI->connect("DBI:mysql:".$db.":".$host, $user, $pass);
if (! $dbHandle) {
    debugMessage("Can't get access to the database\n") if ($optDebug);
} else {

    # opened the db successfully, so now we can process the draws

    debugMessage("Querying database for draws to process...") if ($optDebug);
    processLotteryDraws($dbHandle);

    # done, close the db and get out of here!

    $dbHandle->disconnect();
    debugMessage("Closed database connection...") if ($optDebug);
}

debugMessage("End of line...") if ($optDebug);

# End of Line.....
