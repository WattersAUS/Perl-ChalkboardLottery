#
#	Module: draw_history.pm (2016-11-21) G.J.Watson
#
#	Date		Version		Note
#	==========	=======		========================================================================
#	2016-11-21	v1.00		Original
#	2016-11-27	v1.01		Change type of ident from "E" to "I"
#
package draw_history;
use TableDefault;

@ISA = ("TableDefault");

my %fields = (
	TABLE_NAME		=> [ undef, undef, 'Q', -1, -1 ],	# TABLE name
	SQL_STATEMENT	=> [ undef, undef, 'Q', -1, -1 ],	# SQL statement
	ident			=> [ undef, undef, 'I', -1, -1 ],	# ident
	draw			=> [ undef, undef, 'I', -1, -1 ],	# int
	draw_date		=> [ undef, undef, 'D', -1, -1 ],	# date
	last_modified	=> [ undef, undef, 'Z', -1, -1 ],	# date / time
);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	$fields{TABLE_NAME}->[0] = 'draw_history';
	my $self = {
		%fields
	};
	return bless $self, $class;
}

# end of line

1;
