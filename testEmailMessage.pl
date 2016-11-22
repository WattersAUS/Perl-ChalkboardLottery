#!/usr/bin/perl -w
#
#	Program: testEmailMessage.pl (2016-11-22) G.J.Watson
#
#	Purpose: send a test email message to shiny-ideas gmail address
#
#	Date		Version		Note
#	==========	=======		===================================================================================
#	2016-11-22	v0.01		First cut of code
#

use strict;
use vars qw($opt_h $opt_d $opt_e $opt_t $opt_m);
use Getopt::Std;
use MIME::Lite;

#-----------------------------------------------------------------------------
# only globals in the whole program (I hope)
#-----------------------------------------------------------------------------

my $version_id = "0.01";

#-----------------------------------------------------------------------------
# special DEBUG message for help function
#-----------------------------------------------------------------------------

sub DebugHelpMessage {
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

sub DebugMessage {
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
# email to selected user
#-----------------------------------------------------------------------------

sub SendEmailMessage {
	my $from_who = shift;
	my $to_who   = shift;
	my $subject  = shift;
	my $body     = shift;
	DebugMessage("Sending mail message to ".$to_who." (".$subject.")") if ($opt_d);
	my $mail_msg = MIME::Lite->new(
			From	=>	$from_who,
			To		=>	$to_who,
			Subject	=>	$subject,
			Type	=>	'multipart/mixed'
	) or DebugMessage("Failed to send mail message to ".$to_who." (".$subject.")") if ($opt_d);
	$mail_msg->attach(
			Type	=>	'text/plain',
			Data	=>	$body
	);
	$mail_msg->send();
	return;
}

#-----------------------------------------------------------------------------
# check for any command line params and set appropriately
#-----------------------------------------------------------------------------

getopts('hdetm:');

# help screen

if (defined($opt_h)) {
	DebugHelpMessage("\n\n\tSite Data Import Utility ".$version_id." for MAP Project");
	DebugHelpMessage("\t=============================================");
	DebugHelpMessage( "\t-h (view this HELP Mode)");
	DebugHelpMessage( "\t-d (turn on DEBUG Mode)");
	DebugHelpMessage( "\t-e (turn on EMAIL Mode)");
	DebugHelpMessage( "\t-t (turn on date/time stamp on DEBUG messages)");
	DebugHelpMessage( "\t-m <SMTP-server> (use this SMTP address and not SENDMAIL)\n\n");
	exit(0);
}

# date/time stamp on DEBUG messages

if (defined($opt_t)) {
		DebugMessage("Date/Time Stamp Active") if ($opt_d);
} else {
        DebugMessage("Date/Time Stamp Inactive") if ($opt_d);
}

# email mode

if (defined($opt_e)) {
	DebugMessage("Email Sending Active") if ($opt_d);
} else {
	DebugMessage("Email Sending Inactive") if ($opt_d);
}

if (defined($opt_m)) {
	DebugMessage("Mail Server: ".$opt_m) if ($opt_d);
	MIME::Lite->send('smtp', $opt_m, Timeout=>60);
}

#-----------------------------------------------------------------------------
# main code
#-----------------------------------------------------------------------------

my $email_to   = "shiny.ideas.uk@gmail.com"
my $email_from = "test@shiny-ideas.tech"
my $subject    = "Test Email Message"
my $body       = "Body of the email test message..."

DebugMessage("Attempting to send test email message...") if ($opt_d);
SendEmailMessage($email_to, $email_from, $subject, $body);
DebugMessage("End of Line.....");

# End of Line.....
