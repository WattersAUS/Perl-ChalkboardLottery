#
#  Module: lottery_draws.pm
#    Desc: description module for lottery_draws table
# Version: v1.04
#

package lottery_draws;
use TableDefault;

@ISA = ("TableDefault");

my %fields = (
	TABLE_NAME		=> [ undef, undef, 'Q', -1, -1 ],	# TABLE name
	SQL_STATEMENT	=> [ undef, undef, 'Q', -1, -1 ],	# SQL statement
	ident			=> [ undef, undef, 'A', -1, -1 ],	# ident
	description		=> [ undef, undef, 'S', 64, -1 ],	# character varying(64)
	draw			=> [ undef, undef, 'I', -1, -1 ],	# int
	numbers			=> [ undef, undef, 'I', -1, -1 ],	# int
	upper_number	=> [ undef, undef, 'I', -1, -1 ],	# int
	numbers_tag		=> [ undef, undef, 'S', 32, -1 ],	# character varying(32)
	specials		=> [ undef, undef, 'I', -1, -1 ],	# int
	upper_special	=> [ undef, undef, 'I', -1, -1 ],	# int
	specials_tag	=> [ undef, undef, 'S', 32, -1 ],	# character varying(32)
	is_bonus		=> [ undef, undef, 'I', -1, -1 ],	# int
	base_url		=> [ undef, undef, 'S', 32, -1 ],	# character varying(32)
	last_modified	=> [ undef, undef, 'Z', -1, -1 ],	# DateTime
	end_date        => [ undef, undef, 'D', -1, -1 ],	# Date
);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	$fields{TABLE_NAME}->[0] = 'lottery_draws';
	my $self = {
		%fields
	};
	return bless $self, $class;
}

# end of line

1;
