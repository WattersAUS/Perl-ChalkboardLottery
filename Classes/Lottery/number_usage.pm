#
#	Module: number_usage.pm (2016-11-21) G.J.Watson
#
#	Date		Version		Note
#	==========	=======		========================================================================
#	2016-11-21	v1.00		Original
#
package number_usage;
use TableDefault;

@ISA = ("TableDefault");

my %fields = (
	TABLE_NAME		=> [ undef, undef, 'Q', -1, -1 ],	# TABLE name
	SQL_STATEMENT	=> [ undef, undef, 'Q', -1, -1 ],	# SQL statement
	ident			=> [ undef, undef, 'E', -1, -1 ],	# ident
	draw			=> [ undef, undef, 'I', -1, -1 ],	# int
	number			=> [ undef, undef, 'I', -1, -1 ],	# int
	is_special		=> [ undef, undef, 'B', -1, -1 ],	# int
);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	$fields{TABLE_NAME}->[0] = 'number_usage';
	my $self = {
		%fields
	};
	return bless $self, $class;
}

# end of line

1;
