#
#	Module: logger.pm (2016-11-27) G.J.Watson
#
#	Date		Version		Note
#	==========	=======		========================================================================
#	2016-11-27	v1.00		Original
#
package logger;
use TableDefault;

@ISA = ("TableDefault");

my %fields = (
	TABLE_NAME		=> [ undef, undef, 'Q',  -1, -1 ],	# TABLE name
	SQL_STATEMENT	=> [ undef, undef, 'Q',	 -1, -1 ],	# SQL statement
	ident			=> [ undef, undef, 'I',  -1, -1 ],	# integer
	seqnum			=> [ undef, undef, 'A',  -1, -1 ],	# auto increment
	description		=> [ undef, undef, 'S', 255, -1 ],	# character varying(255)
	last_modified	=> [ undef, undef, 'Z',  -1, -1 ],	# date / time
);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	$fields{TABLE_NAME}->[0] = 'logger';
	my $self = {
		%fields
	};
	return bless $self, $class;
}

# end of line

1;
