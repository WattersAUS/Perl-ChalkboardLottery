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
#	2016-11-28	v0.03		Moved logger write to sql_buffer
#

use lib "./Classes";

use strict;
use vars qw($opt_s $opt_b $opt_u $opt_p $opt_d $opt_e $opt_h $opt_m $opt_i $opt_t);
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

my @sql_buffer = qw();

#-----------------------------------------------------------------------------
# this holds the messages to be mailed to Shiny Ideas
#-----------------------------------------------------------------------------

my @mail_buffer = qw();

#-----------------------------------------------------------------------------
# special DEBUG message for help function
#-----------------------------------------------------------------------------

sub debugHelpMessage {
        my $debug_msg = shift;
        if (defined($debug_msg)) {
                print $debug_msg;
        }
        print "\n";
        return;
}

#-----------------------------------------------------------------------------
# print out DEBUG messages allowing for possible date/time stamp inclusion
#-----------------------------------------------------------------------------

sub debugMessage {
        my $debug_msg = shift;
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
        if ($opt_t) {
			printf "[ %4d-%02d-%02d %02d:%02d:%02d ] ", $year+1900,$mon+1,$mday,$hour,$min,$sec;
        }
        print "DEBUG: ";
        if (defined($debug_msg)) {
                print $debug_msg;
        }
        print "\n";
        return;
}

#-----------------------------------------------------------------------------
# build a 'draw_history' record
#-----------------------------------------------------------------------------

sub buildNewDrawHistory {
	my $draw         = shift;
	my $draw_date    = shift;
	my $draw_history = new draw_history;
	$draw_history->draw($draw);
	$draw_history->draw_date($draw_date);
	$draw_history->CreateINSERT;
	push(@sql_buffer, $draw_history->{SQL_STATEMENT}->[0]);
	return;
}

#-----------------------------------------------------------------------------
# build a 'number_usage' record
#-----------------------------------------------------------------------------

sub buildNewNumberUsage {
    my $ident        = shift;
	my $draw         = shift;
	my $number       = shift;
	my $is_special   = shift;
	my $number_usage = new number_usage;
    $number_usage->ident($ident);
	$number_usage->draw($draw);
	$number_usage->number($number);
	$number_usage->is_special($is_special);
	$number_usage->CreateINSERT;
	push(@sql_buffer, $number_usage->{SQL_STATEMENT}->[0]);
	return;
}

#-----------------------------------------------------------------------------
# write to logger table
#-----------------------------------------------------------------------------

sub writeToLogger {
	my $dbHandle = shift;
	my $site_id  = shift;
	my $message  = shift;
	my $logger   = new logger;
	$logger->site_id($site_id);
	$logger->logger_description($message);
	$logger->logger_timestamp("now()");
	$logger->CreateINSERT;
	debugMessage($logger->{SQL_STATEMENT}->[0]) if ($opt_d);
    push(@sql_buffer, $logger->{SQL_STATEMENT}->[0]);
#	if ($opt_i) {
#		my $sth = $dbHandle->prepare($logger->{SQL_STATEMENT}->[0]);
#		$sth->execute;
#		$sth->finish;
#	}
	return;
}

#-----------------------------------------------------------------------------
# email to selected user
#-----------------------------------------------------------------------------

sub sendEmailMessage {
	my $from_who = shift;
	my $to_who   = shift;
	my $subject  = shift;
	my $body     = shift;
	debugMessage("Sending mail message to ".$to_who." (".$subject.")") if ($opt_d);
	my $mail_msg = MIME::Lite->new(
			From	=>	$from_who,
			To		=>	$to_who,
			Subject	=>	$subject,
			Type	=>	'multipart/mixed'
	) or debugMessage("Failed to send mail message to ".$to_who." (".$subject.")") if ($opt_d);
	$mail_msg->attach(
			Type	=>	'text/plain',
			Data	=>	$body
	);
	$mail_msg->send();
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
    debugMessage($draws->{SQL_STATEMENT}->[0]) if ($opt_d);
    my $sth = $dbHandle->prepare($draws->{SQL_STATEMENT}->[0]);
    $sth->execute;
    while (my @fields = $sth->fetchrow) {
        $draws->DataINITIALISE(@fields);
        $draws->DataSAVE;
        my $description  = $draws->{description}->[0];
        my $draw         = $draws->{draw}->[0];
        my $numbers      = $draws->{numbers}->[0];
        my $numbers_tag  = $draws->{description}->[0];
        my $specials     = $draws->{specials}->[0];
        my $specials_tag = $draws->{specials_tag}->[0];
        my $base_url     = $draws->{base_url}->[0];

# now we need to prep settings to get the page for the next draw, using the url and filename

        $draw++;
        my $filename     = lc($description);
        $filename        =~ s/\s/_/g;
        $filename        .= ".".$draw;
        my $url          = $base_url;
        $url             =~ s/DRAWNUMBER/$draw/g;
        debugMessage("Ready to process (".$draws->{description}->[0]."), draw (".$draw."), into file (".$filename."), using url (".$url.")") if ($opt_d);
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
	foreach my $sql_statement (@sql_buffer) {
		debugMessage($sql_statement) if ($opt_d);
		if ($opt_i) {
			my $sth = $dbHandle->prepare($sql_statement);
			$sth->execute;
            $count++;
		}
	}
	@sql_buffer = qw();
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

if (defined($opt_h)) {
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

if (defined($opt_t)) {
		debugMessage("Date/Time Stamp Active") if ($opt_d);
} else {
        debugMessage("Date/Time Stamp Inactive") if ($opt_d);
}

# email mode

if (defined($opt_e)) {
	debugMessage("Email Sending Active") if ($opt_d);
} else {
	debugMessage("Email Sending Inactive") if ($opt_d);
}

if (defined($opt_m)) {
	debugMessage("Mail Server: ".$opt_m) if ($opt_d);
	MIME::Lite->send('smtp', $opt_m, Timeout=>60);
}

#-----------------------------------------------------------------------------
# main code
#-----------------------------------------------------------------------------

my $dbHandle = DBI->connect("DBI:mysql:".$db.":".$host, $user, $pass);
if (! $dbHandle) {
	debugMessage("Can't get access to the database\n") if ($opt_d);
} else {

    # opened the db successfully, so now we can process the draws

    debugMessage("Querying database for draws to process...") if ($opt_d);
    processLotteryDraws($dbHandle);

    # done, close the db and get out of here!

    $dbHandle->disconnect();
    debugMessage("Closed database connection...") if ($opt_d);
}

debugMessage("End of line...") if ($opt_d);

# End of Line.....
