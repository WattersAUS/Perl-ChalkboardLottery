#
#	Module: TableDefault.pm (2003-02-24) G.J.Watson
#
#	Purpose: Generic OOPS module for interface to TABLE data in SQL db
#
#	Date		Version		Note
#	========== ===== ========================================================================
#	2003-02-24 v1.00 Initial cut of code
#	2003-03-20 v1.01 Alter Boolean type handling to match data retutn from SELECT statements
#						        i.e. TRUE = 1 and FALSE = 0
#	2003-08-27 v1.02 Change the way we handle 'null'
#	2016-11-27 v1.04 Add Auto Increment field ("A")
#

package TableDefault;
use Carp;

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	my $self = {
	};
	return bless $self, $class;
}

sub FormatDATA {
	my $self = shift;
	my $value = shift;
	my $format = shift;
	my $string = qw();
	if ($value eq "null") {
		$string = "null";
	} else {
		if (($format eq "I") or ($format eq "F") or ($format eq "A")) {
			$string = $value;
		} else {
			if (($format eq "S") or ($format eq "X") or ($format eq "M")) {
				if ($format ne "M") {
					$value =~ s/\'/\\\'/g;
				}
				$string = "'".$value."'";
			} else {
				if (($format eq "D") or ($format eq "T") or ($format eq "Z")) {
					if ($value ne "now()") {
						$string = "'".$value."'";
					} else {
						$string = $value;
					}
				} else {
					if ($format eq "B") {
						if ($value != 1) {
							$string = "FALSE";
						} else {
							$string = "TRUE";
						}
					}
				}
			}
		}
	}
	return $string;
}

sub DataDISPLAY {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	foreach $key (@keys) {
		if ($self->{$key}->[2] eq "I") {
			print "Int:\t\t";
		} else {
			if ($self->{$key}->[2] eq "S") {
				print "String (".$self->{$key}->[3]."):\t";
			} else {
				if ($self->{$key}->[2] eq "D") {
					print "Date:\t\t";
				} else {
					if ($self->{$key}->[2] eq "T") {
						print "Time:\t\t";
					} else {
						if ($self->{$key}->[2] eq "F") {
							print "Float:\t\t";
						} else {
							if ($self->{$key}->[2] eq "B") {
								print "Bool:\t\t";
							} else {
								if ($self->{$key}->[2] eq "X") {
									print "Text:\t\t";
								} else {
									if ($self->{$key}->[2] eq "M") {
										print "Money:\t\t";
									} else {
										if ($self->{$key}->[2] eq "Q") {
											print "SQL:\t\t";
										} else {
											if ($self->{$key}->[2] eq "Z") {
												print "DateTime:\t";
											} else {
												if ($self->{$key}->[2] eq "A") {
													print "Auto I:\t\t";
												} else {
													print "*****:\t\t";
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
		if (defined($self->{$key}->[0])) {
			print "$key\t=> $self->{$key}->[0]\n";
		} else {
			print "$key\t=> Undefined\n";
		}
	}
}

sub DataINITIALISE {
	my $self = shift;
	my @data = @_;
	my $count = 0;
	my @keys = sort keys(%$self);
	foreach $key (@keys) {
		if ($self->{$key}->[2] ne "Q") {
			$self->{$key}->[0] = $data[$count];
			$count++;
		}
	}
}

sub DataSAVE {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	foreach $key (@keys) {
		if ($self->{$key}->[2] ne "Q") {
			if (defined($self->{$key}->[0])) {
				$self->{$key}->[1] = $self->{$key}->[0];
			}
		}
	}
}

sub ResetKEYFIELDS {
	my $self = shift;
	my @keys = sort keys(%$self);
	foreach $key (@keys) {
		$self->{$key}->[4] = -1;
	}
}

sub SetKEYFIELDS {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	foreach $key (@keys) {
		$self->{$key}->[4] = 0;
	}
}

sub CreateCONDITION {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	if (defined($self->{SQL_STATEMENT}->[0])) {
		my $statement_val = qw();
		foreach $key (@keys) {
			if ($self->{$key}->[2] ne "Q") {
				if ($self->{$key}->[4] > -1 ) {
					if (defined $statement_val) {
						$statement_val .= " AND ";
					} else {
						$statement_val = " WHERE ";
					}
					if (defined($self->{$key}->[1])) {
						$statement_val .= $key." = ".$self->FormatDATA($self->{$key}->[1], $self->{$key}->[2]);
					}
				}
			}
		}
		if (defined($statement_val)) {
			$self->{SQL_STATEMENT}->[0] .= $statement_val;
		}
	}
}

sub CreateSELECT {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	$self->{SQL_STATEMENT}->[0] = undef;
	my $statement = qw();
	foreach $key (@keys) {
		if ($self->{$key}->[2] ne "Q") {
			if (defined($statement)) {
				$statement .= ", ".$key;
			} else {
				$statement = " ".$key;
			}
		}
	}
	if (defined($statement)) {
		$self->{SQL_STATEMENT}->[0] = "SELECT".$statement." FROM ".$self->{TABLE_NAME}->[0];
	}
}

sub CreateINSERT {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	$self->{SQL_STATEMENT}->[0] = undef;
	my $statement = qw();
	foreach $key (@keys) {
		if (($self->{$key}->[2] ne "Q") and ($self->{$key}->[2] ne "A")) {
			if (defined($self->{$key}->[0])) {
				if (defined($statement)) {
					$statement .= ", ".$key;
				} else {
					$statement = " ".$key;
				}
			}
		}
	}
	if (defined($statement)) {
		my $statement_val = qw();
		foreach $key (@keys) {
			if ($self->{$key}->[2] ne "Q") {
				if (defined($self->{$key}->[0])) {
					if (defined($statement_val)) {
						$statement_val .= ", ";
					} else {
						$statement_val = " ";
					}
					$statement_val .= $self->FormatDATA($self->{$key}->[0], $self->{$key}->[2]);
				}
			}
		}
		$self->{SQL_STATEMENT}->[0] = "INSERT INTO ".$self->{TABLE_NAME}->[0]." (".$statement." ) VALUES (".$statement_val." )";
	}
}

sub CreateUPDATE {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	$self->{SQL_STATEMENT}->[0] = undef;
	my $statement = qw();
	foreach $key (@keys) {
		if ($self->{$key}->[2] ne "Q") {
			if (defined($self->{$key}->[0])) {
				if (defined($self->{$key}->[1])) {
					if ($self->{$key}->[0] ne $self->{$key}->[1]) {
						if (defined($statement)) {
							$statement .= ", ".$key." = ";
						} else {
							$statement = $key." = ";
						}
						$statement .= $self->FormatDATA($self->{$key}->[0], $self->{$key}->[2]);
					}
				} else {
					if (defined($statement)) {
						$statement .= ", ".$key." = ";
					} else {
						$statement = $key." = ";
					}
					$statement .= $self->FormatDATA($self->{$key}->[0], $self->{$key}->[2]);
				}
			}
		}
	}
	if (defined $statement) {
		$self->{SQL_STATEMENT}->[0] = "UPDATE ".$self->{TABLE_NAME}->[0]." SET ".$statement;
	}
}

sub CreateDELETE {
	my $self = shift;
	my @keys;
	if (@_ == 0) {
		@keys = sort keys(%$self);
	} else {
		@keys = @_
	}
	$self->{SQL_STATEMENT}->[0] = "DELETE FROM ".$self->{TABLE_NAME}->[0];
}

sub DESTROY {
}

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) || croak "$self is not an object";
	my $name = $AUTOLOAD;
	$name =~ s/.*://;					# strip fully qualified portion
	unless (exists $self->{$name}) {
		croak "Can't access `$name` field in object of class $type";
	}
	if (@_) {
		my $data = shift;
		if ($self->{$name}->[2] eq "S") {
			if ($self->{$name}->[3] > 0) {
				return $self->{$name}->[0] = substr($data, 0, $self->{$name}->[3]);
			} else {
				return $self->{$name}->[0] = undef;
			}
		} else {
			return $self->{$name}->[0] = $data;
		}
	} else {
		return $self->{$name}->[0];
	}
}

# end of line

1;
