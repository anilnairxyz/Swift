#------------------------------------------------------------------------------ 
# Retrieve command line argument
#------------------------------------------------------------------------------ 
use strict;
my $specfile = $ARGV[0];

############################################################################### 
# PARSING PORTION of the SCRIPT
############################################################################### 
# Read in the target specfile into an array of lines
open(INFILE, $specfile) or dienice ("$specfile open failed");
my @spec_data = <INFILE>;
close(INFILE);

#------------------------------------------------------------------------------ 
# Read INTERFACE Names
#------------------------------------------------------------------------------
my @data = @spec_data;
clean (\@data, 0, scalar(@data));
my $scope_begin = find_label (\@data, ".INTERFACE");
my $scope_end = find_label (\@data, ".END INTERFACE");

# couldn't locate '.INTERFACE' so quit
if ($scope_begin == -1) {
	print("Unable to proceed -no occurance of '.INTERFACE' in $specfile.\n");
	exit;
}
# couldn't locate '.END INTERFACE' so quit
if ($scope_end == -1) {
	print("Unable to proceed -no occurance of '.END INTERFACE' in $specfile.\n");
	exit;
}

# collect interface names
my %if_size;
my @regif_in_signal;
my @regif_out_signal;
my %regif_range;
my %regif_name;
my %regif_type;
push @regif_in_signal, ("Clk_free", "Clk_gated", "ResetAX", "RegAddr", "WriteData", "WriteEn", "ReadEn", "ByteEn", "RegTestMode");
push @regif_out_signal, ("ReadData", "Response");
foreach my $i (@regif_in_signal) { $regif_name{$i} = $i; }
foreach my $i (@regif_out_signal) { $regif_name{$i} = $i; }
for (my $line = $scope_begin; $line < $scope_end; $line++) {
	$data[$line] =~ s/--.*//;                 		#strip trailing -- comments
	if ($data[$line] =~ m/map.*/i) {
		if ($data[$line] =~ m/map\s+(\S+)\s+(\S+)/i) {
			$if_size{$1} = $2;
		} else {
	       		print("Unable to proceed -The spec for INTERFACE MAP looks incorrect.\n");
	       		exit;
		}
	} elsif ($data[$line] =~ m/port.*/i) {
		if ($data[$line] =~ m/port\s+(\S+)\s+(\S+)/i) {
			$regif_name{$1} = $2;
		} else {
	       		print("Unable to proceed -The spec for INTERFACE PORT looks incorrect.\n");
	       		exit;
		}
	}
}
$regif_range{"WriteData"} = "\(".($if_size{"DSize"}-1)." downto 0\)";
$regif_range{"ReadData"} = "\(".($if_size{"DSize"}-1)." downto 0\)";
$regif_range{"RegAddr"} = "\(".($if_size{"ASize"}-1)." downto 0\)";
$regif_range{"ByteEn"} = "\(".($if_size{"DSize"}/8-1)." downto 0\)";
$regif_range{"Response"} = "\(1 downto 0\)";

#------------------------------------------------------------------------------ 
# Read REGISTER Names
#------------------------------------------------------------------------------

my @data = @spec_data;
clean (\@data, 0, scalar(@data));
my $scope_begin = find_label (\@data, ".REGISTER");
my $scope_end = find_label (\@data, ".END REGISTER");

# couldn't locate '.REGISTER' so quit
if ($scope_begin == -1) {
	print("Unable to proceed -no occurance of '.REGISTER' in $specfile.\n");
	exit;
}
# couldn't locate '.END REGISTER' so quit
if ($scope_end == -1) {
	print("Unable to proceed -no occurance of '.END REGISTER' in $specfile.\n");
	exit;
}

# Remove comments not belonging to current scope
my @data = @spec_data;
clean (\@data, 0, $scope_begin);
clean (\@data, $scope_end, scalar(@data));

# collect register names
my @register;                                                # list of registers
my %reg_addr;                                                # register address
my %reg_comment;                                             # Comment array
my %reg_range;					             # Register Range
my %reg_clear_addr;                                          # clear register address

my %reg_field;                                               # register fields
my %field_reset;                                             # reset value
my %field_range;                                             # range of register
my %field_mode;                                              # RWI etc
my %field_size;                                              # size of register
my %field_clearing;					     # Field clearing signal / interrupt

my $x = 0;
my $y = 0;
my $k = 0;
my @temp_array;

for (my $line = $scope_begin; $line < $scope_end; $line++) {

      if ($data[$line] =~ m/^--.*/) {
         push @temp_array, $data[$line];
      }  

      $data[$line] =~ s/--.*//;		               #strip trailing -- comments
      if ($data[$line] =~ m/map.*/i) {
	if ($data[$line] =~ m/map\s+(\S+)\s+(\S+)/i)
	{
		push @register, $1; my $temp_var; my $temp2 = $2;
		if ($if_size{"Address"} =~ m/H/i) { $temp_var = hex "$temp2"; } else { $temp_var = $2; }
		$reg_addr{$register[$x]} = constify ($temp_var, $register[$x], "_ADDR");
                $y = $x++;
                $k = 0;
                $reg_range{$register[$x]} = 0;
	} else {
	        print("Unable to proceed -The spec for register $x looks incorrect.\n");
	        exit;
        }
      $reg_comment{$register[$y]} = join "\n", @temp_array;
      @temp_array = ();
      }
      if ($data[$line] =~ m/port.*/i) {
	if ($data[$line] =~ m/port\s+(\S+)\s+(\S+):(\S+)\s+(\S+)\s+(\S+)/i)
	{
		my ($temp1, $temp2, $temp3, $temp4, $temp5) = ($1, $2, $3, $4, $5);
                push @{$reg_field{$register[$y]}}, $temp1;
		$field_range{$reg_field{$register[$y]}[$k]} = "\($temp2 downto $temp3\)";
		my $temp_var = $temp2-$temp3;
		$field_size{$reg_field{$register[$y]}[$k]} = "\($temp_var downto 0\)";
		$field_reset{$reg_field{$register[$y]}[$k]} = $temp4;
		$field_mode{$reg_field{$register[$y]}[$k]} = $temp5;
                $k = $k + 1;
                if ($temp2 > $reg_range{$register[$y]}) {
                	$reg_range{$register[$y]} = $temp2;
                }
	}
	elsif ($data[$line] =~ m/port\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i)
	{
		my ($temp1, $temp2, $temp3, $temp4) = ($1, $2, $3, $4);
                push @{$reg_field{$register[$y]}}, $temp1;
		$field_range{$reg_field{$register[$y]}[$k]} = "\(" . constify("$temp2", $reg_field{$register[$y]}[$k], "_WIDTH-1 downto 0") . "\)";
		$field_reset{$reg_field{$register[$y]}[$k]} = $temp3;
		$field_mode{$reg_field{$register[$y]}[$k]} = $temp4;
                $k = $k + 1;
                if ($temp2 > $reg_range{$register[$y]}) {
                	$reg_range{$register[$y]} = $temp2;
                }
	} else {
	        print("Unable to proceed -The spec for register $register[$y] looks incorrect.\n");
	        exit;
	}
      }
      if ($data[$line] =~ m/signal\s+(\S+)/i) {
	my $temp_var = $k - 1;
	$field_clearing{$reg_field{$register[$y]}[$temp_var]} = $1;
      }
      if ($data[$line] =~ m/clear\s+(\S+)/i) {
	my $temp1 = $1; my $temp_var;
	if ($if_size{"Address"} =~ m/H/i) { $temp_var = hex "$temp1"; } else { $temp_var = $temp1; }
	$reg_clear_addr{$register[$y]} = $temp_var;
      }
}
foreach my $i (@register) {
	unless ($reg_range{$i} == 0) {
		$reg_range{$i} = "\($reg_range{$i} downto 0\)";
	}
}

#------------------------------------------------------------------------------ 
# Read MEMORY Names
#------------------------------------------------------------------------------
my @data = @spec_data;
clean (\@data, 0, scalar(@data));
my $scope_begin = find_label (\@data, ".MEMORY");
my $scope_end = find_label (\@data, ".END MEMORY");

# collect memory names
my @memory;                                                     # list of memories
my %mem_addr;                                                   # memory address
my %mem_addr_range;                                             # memory address range
my %mem_acc;                                                    # memory acc ddress
my %mem_inc;                                                    # memory inc address
my %mem_dec;                                                    # memory dec address
my %mem_width;							# memory size
my %mem_type;							# memory type
my %mem_wrap;							# memory type
for (my $line = $scope_begin; $line < $scope_end; $line++) {
	$data[$line] =~ s/--.*//;                 		#strip trailing -- comments
	if ($data[$line] =~ m/map\s+(\S+)/i) {
		push @memory, $1;
	} elsif ($data[$line] =~ m/port\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i) {
		my ($temp1, $temp2, $temp3, $temp4) = ($1, $2, $3, $4);
		$temp3 =~ s/:/ downto /;
		my $temp_var;
		if ($if_size{"Address"} =~ m/H/i) { $temp_var = hex "$temp2"; } else { $temp_var = $temp2; }
		if ($temp1 =~ m/Addr/i) {
			$mem_addr{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_addr_range{"@memory[scalar(@memory)-1]"} = $temp3;
			$mem_type{"@memory[scalar(@memory)-1]"} = "M";
		} elsif ($temp1 =~ m/Acc/i) {
			$mem_acc{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_width{"@memory[scalar(@memory)-1]"} = $temp3;
			$mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."A";
		} elsif ($temp1 =~ m/Inc/i) {
			$mem_inc{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_width{"@memory[scalar(@memory)-1]"} = $temp3;
			$mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."I";
                        if ($temp1 =~ m/w/i) { 
                                  $mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."W"; 
                                  $mem_wrap{"@memory[scalar(@memory)-1]"} = $temp4-1;
                        }
		} elsif ($temp1 =~ m/Dec/i) {
			$mem_dec{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_width{"@memory[scalar(@memory)-1]"} = $temp3-1;
			$mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."D";
                        if ($temp1 =~ m/w/i) { 
                                  $mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."W"; 
                                  $mem_wrap{"@memory[scalar(@memory)-1]"} = $temp4-1;
                        }
		} else {	
			print("Unable to proceed - The memory declaration for memory @memory[scalar(@memory)-1] is incorrect\n");
			exit;
		}
	} elsif ($data[$line] =~ m/port\s+(\S+)\s+(\S+)\s+(\S+)/i) {
		my ($temp1, $temp2, $temp3) = ($1, $2, $3);
		$temp3 =~ s/:/ downto /;
		my $temp_var;
		if ($if_size{"Address"} =~ m/H/i) { $temp_var = hex "$temp2"; } else { $temp_var = $temp2; }
		if ($temp1 =~ m/Addr/i) {
			$mem_addr{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_addr_range{"@memory[scalar(@memory)-1]"} = $temp3;
			$mem_type{"@memory[scalar(@memory)-1]"} = "M";
		} elsif ($temp1 =~ m/Acc/i) {
			$mem_acc{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_width{"@memory[scalar(@memory)-1]"} = $temp3;
			$mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."A";
		} elsif ($temp1 =~ m/Inc/i) {
			$mem_inc{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_width{"@memory[scalar(@memory)-1]"} = $temp3;
			$mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."I";
		} elsif ($temp1 =~ m/Dec/i) {
			$mem_dec{"@memory[scalar(@memory)-1]"} = $temp_var;
			$mem_width{"@memory[scalar(@memory)-1]"} = $temp3-1;
			$mem_type{"@memory[scalar(@memory)-1]"} = $mem_type{"@memory[scalar(@memory)-1]"}."D";
		} else {	
			print("Unable to proceed - The memory declaration for memory @memory[scalar(@memory)-1] is incorrect\n");
			exit;
		}
	}
}

#------------------------------------------------------------------------------ 
# Read ID Register
#------------------------------------------------------------------------------
my @data = @spec_data;
clean (\@data, 0, scalar(@data));
my $scope_begin = find_label (\@data, ".ID");
my $scope_end = find_label (\@data, ".END ID");

# collect memory names
my $id;                                                     # Id name
my $id_addr;
my %id_fields = ('VCPr' => 0, 'VCNum' => 0, 'VC_Ver_MSB' => 0, 'VC_Ver_LSB' => 0, 'VC_Info_0' => 0,
		 'VC_Info_1' => 0, 'VC_Info_2' => 0, 'VC_Info_En' => 0);
for (my $line = $scope_begin; $line < $scope_end; $line++) {
	$data[$line] =~ s/--.*//;                 		#strip trailing -- comments
	if ($data[$line] =~ m/map\s+(\S+)\s+(\S+)/i) {
		my ($temp1, $temp2) = ($1, $2);
		$id =  $temp1;
		my $temp_var;
		if ($if_size{"Address"} =~ m/H/i) { $temp_var = hex "$temp2"; } else { $temp_var = $temp2; }
		$id_addr = $temp_var;
	} elsif ($data[$line] =~ m/port\s+(\S+)\s+(\S+)/i) {
		my ($temp1, $temp2) = ($1, $2);
		foreach my $i (keys(%id_fields)) {
			if ($temp1 =~ m/$i/i) { 
				if ($temp2 =~ m/\?+/) { $id_fields{$i} = $i; } else {$id_fields{$i} = $temp2; }
			}
		}
	}
}

#------------------------------------------------------------------------------ 
# Read MODULE Names
#------------------------------------------------------------------------------
my @data = @spec_data;
clean (\@data, 0, scalar(@data));
my $scope_begin = find_label (\@data, ".MODULE");
my $scope_end = find_label (\@data, ".END MODULE");

# couldn't locate '.MODULE' so quit
if ($scope_begin == -1) {
	print("Unable to proceed -no occurance of '.MODULE' in $specfile.\n");
	exit;
}
# couldn't locate '.END MODULE' so quit
if ($scope_end == -1) {
	print("Unable to proceed -no occurance of '.END MODULE' in $specfile.\n");
	exit;
}

# collect module names
my %module = ('top' => 'top', 'name' => 'name', 'comp' => 'comp');
for (my $line = $scope_begin; $line < $scope_end; $line++) {
	$data[$line] =~ s/--.*//;                 		#strip trailing -- comments
	if ($data[$line] =~ m/map\s+(\S+)\s+(\S+)/i)
	{
		$module{$1} = $2;
	}
}
$module{'comp'} = "$module{'top'}_components";
for (my $line = $scope_begin; $line < $scope_end; $line++) {
	$data[$line] =~ s/--.*//;                 		#strip trailing -- comments
	if ($data[$line] =~ m/map\s+(\S+)\s+(\S+)/i)
	{
		$module{$1} = $2;
	}
}
$module{'regif'} = "$module{'name'}"."_swift";

#------------------------------------------------------------------------------ 
# Declare signals
#------------------------------------------------------------------------------
foreach my $i (@register) {
	clr_loop: for my $j (0 .. $#{$reg_field{$i}}) {
		if ($field_clearing{$reg_field{$i}[$j]}) {
			foreach my $k (@regif_in_signal) {
				if ($field_clearing{$reg_field{$i}[$j]} =~ m/^$k$/i) {
					next clr_loop;
				}
			}
		push @regif_in_signal, $field_clearing{$reg_field{$i}[$j]};
		}
	}
}
#------------------------------------------------------------------------------ 
# Check for Illegal Modes
#------------------------------------------------------------------------------ 
foreach my $i (@register) {
	my $repeated_regs = 0;
	my $repeated_addrs = 0;
	for my $j (0 .. $#{$reg_field{$i}}) {
		my $repeated_names = 0;
		if (($field_mode{$reg_field{$i}[$j]} =~ m/((H.*F)|(F.*H)|(F.*I)|(I.*F)|(H.*I)|(I.*H))/i)
			or ($field_mode{$reg_field{$i}[$j]} =~ m/((F.*S)|(S.*F)|(S.*I)|(I.*S))/i)) {
			print("Unable to proceed - $reg_field{$i}[$j] - has illegal mode\n");
			exit;
		}
		foreach my $k (@register) {
			for my $l (0 .. $#{$reg_field{$i}}) {
				if ($reg_field{$i}[$j] =~ m/^$reg_field{$k}[$l]$/i) { $repeated_names++; }
			}
		}
		if ($repeated_names > 1) {
			print("Unable to proceed - illegal naming : $reg_field{$i}[$j] - is repeated $repeated_names times\n");
			exit;
		}
	}
	foreach my $k (@register) { if ($i =~ m/^$k$/i) { $repeated_regs++; } }
	if ($repeated_regs > 1) {
		print("Unable to proceed - illegal naming : $i - is repeated $repeated_regs times\n");
		exit;
	}
	foreach my $k (@register) {
		if (($reg_addr{$i} =~ m/^$reg_addr{$k}$/i) or ($reg_addr{$i} =~ m/^$reg_clear_addr{$k}$/i)) { $repeated_addrs++; }
	}
	foreach my $k (%mem_addr) { if ($reg_addr{$i} =~ m/^$k$/i) { $repeated_addrs++; } }
	foreach my $k (%mem_acc) { if ($reg_addr{$i} =~ m/^$k$/i) { $repeated_addrs++; } }
	foreach my $k (%mem_inc) { if ($reg_addr{$i} =~ m/^$k$/i) { $repeated_addrs++; } }
	foreach my $k (%mem_dec) { if ($reg_addr{$i} =~ m/^$k$/i) { $repeated_addrs++; } }

	if ($repeated_addrs > 1) {
		print("Unable to proceed - illegal addressing : Address $reg_addr{$i} - is repeated $repeated_addrs times\n");
		exit;
	}
}

#------------------------------------------------------------------------------ 
# Obtain Internal SIGNAL Names
#------------------------------------------------------------------------------
my @int_signal;
my %int_signal_range;
my %int_signal_type;
my %int_signal_name;
foreach my $i (@register) {
	push @int_signal, "$i\_en";
	if ($reg_clear_addr{$i}) {
		push @int_signal, "$i\_clr_en";
	}
}
foreach my $i (@register) {
	push @int_signal, "$i";
        $int_signal_range{$i} = $reg_range{$i};
}
foreach my $j (@memory) {
	push @int_signal, "$j\_req_int";
}
push @int_signal, "ByteEn_mask";
$int_signal_range{"ByteEn_mask"} = "\(".($if_size{"DSize"}-1)." downto 0\)";
push @int_signal, "ByteEn_maskX";
$int_signal_range{"ByteEn_maskX"} = "\(".($if_size{"DSize"}-1)." downto 0\)";
push @int_signal, "ReadData_int";
$int_signal_range{"ReadData_int"} = "\(".($if_size{"DSize"}-1)." downto 0\)";
push @int_signal, "response_int";
$int_signal_range{"response_int"} = "(1 downto 0)";
push @int_signal, "add_latency";
push @int_signal, "add_latency_d1";
if (scalar(@memory)) {
	push @int_signal, "mem_ack_r1";
	push @int_signal, "mem_ack_r2";
}	
push @int_signal, "address_error";
if ($id) { push @int_signal, ("$id\_en", "$id\_r_d");
        $int_signal_range{"$id\_r_d"} = "(".($if_size{"DSize"}-1)." downto 0)"; }


############################################################################### 
# REGIF VHDL GENERATING PORTION of the SCRIPT
############################################################################### 
#------------------------------------------------------------------------------ 
# Set output file names
#------------------------------------------------------------------------------
my $regiffile = "$module{'regif'}".".vhdl";
my @regiflines;

# Read in the present output regiffile into an array of lines
open(INFILE, $regiffile) or dienice ("SWIFT file open failed");
my @spec_data = <INFILE>;
close(INFILE);
my @data = @spec_data;

# Strip newlines
foreach (@data) { chomp; }

# Print the header
reghd_loop: for (my $line = 0; $line < scalar(@data); $line++) {
        if ($data[$line] =~ m/^--/) {
                push @regiflines, "$data[$line]";
        } else {
		last reghd_loop;
        }
}

# Print library declarations
push @regiflines, library_dec ($module{'top'}, $module{'name'}, $module{'comp'}, $id);

# Print entity declaration
push @regiflines, "\nentity $module{'regif'} is";
if ($id) { push @regiflines, id_reg_gens(\%id_fields); }
push @regiflines, "  port (";
foreach my $i (@register) {
	for my $j (0 .. $#{$reg_field{$i}}) {
		if ($field_mode{$reg_field{$i}[$j]} =~ m/H/i) {
			my $temp_var = "$reg_field{$i}[$j]"."_wire";
			push @regif_in_signal, $temp_var;
			if ($field_size{$reg_field{$i}[$j]} =~ m/downto/i) {
				$regif_range {$temp_var} = $field_size{$reg_field{$i}[$j]};
			}
		}
	}
}
Mem_loop: foreach my $i (@memory) {
	push @regif_out_signal, "$i\_req";
	push @regif_out_signal, "$i\_wenX";
	push @regif_out_signal, "$i\_w_d";
	push @regif_out_signal, "$i\_byte_en";
	push @regif_in_signal, "$i\_r_d";
	push @regif_in_signal, "$i\_ack";
	push @regif_out_signal, "$i\_addr_reg";
	push @int_signal, "$i\_addr";
	push @int_signal, "$i\_addr_en";
	push @int_signal, "$i\_en";
	if ($mem_inc{$i}) { push @int_signal, "$i\_inc_en"; }
	if ($mem_dec{$i}) {push @int_signal, "$i\_dec_en"; }
	$int_signal_range{"$i\_addr"} = "\($mem_addr_range{$i}\)";
	$regif_range{"$i\_r_d"} = "\(".($mem_width{$i}-1)." downto 0\)";
	$regif_range{"$i\_w_d"} = "\(".($mem_width{$i}-1)." downto 0\)";
	$regif_range{"$i\_byte_en"} = "\(".(divide($mem_width{$i},8)-1)." downto 0\)";
	$regif_range{"$i\_addr_reg"} = "\($mem_addr_range{$i}\)";
}
signalgen_loop: foreach my $i (@register) {
	for my $j (0 .. $#{$reg_field{$i}}) {
		push @regif_out_signal, "$reg_field{$i}[$j]_reg";
		$regif_range{"$reg_field{$i}[$j]_reg"} = $field_size{$reg_field{$i}[$j]};
	}
}
my @temp_array = (@regif_in_signal, @regif_out_signal);
my $max_size = maxlength (\@temp_array, \%regif_name);
push @regiflines, portmapper ("   ", \@regif_in_signal, \%regif_name, \%regif_range, \%regif_type, ": in ", $max_size+20);
push @regiflines, portmapper ("   ", \@regif_out_signal, \%regif_name, \%regif_range, \%regif_type, ": out", $max_size+20);
@regiflines[scalar(@regiflines)-1] =~ s/;$/ \);/;
push @regiflines, "end $module{'regif'};";

# Print architecture declaration
push @regiflines, "\narchitecture rtl of $module{'regif'} is\n";
#if ($id) { push @regiflines, id_reg_comp(); }
# Print signal definitions
my $max_size = maxlength (\@int_signal, \%int_signal_name);
push @regiflines, portmapper ("  signal", \@int_signal, \%int_signal_name, \%int_signal_range, \%int_signal_type, ": ", $max_size+20);
## Print architecture body
push @regiflines, "\nbegin";

if ($id) { push @regiflines, id_reg_inst($id, \%id_fields, \%regif_name); }

foreach my $i (@register) {
        my $nocom;
	push @regiflines, "\n";
	push @regiflines, "-" x 80 ."\n-- SW accessible register $i";
	push @regiflines, $reg_comment{$i};
	push @regiflines, "-" x 80;
	for my $j (0 .. $#{$reg_field{$i}}) {
                if ($nocom) {
       	                push @regiflines, "-" x 80 ."\n-- Field $reg_field{$i}[$j] of register $i";
        	        push @regiflines, "-" x 80;
                }
                $nocom = 1;
		if ($field_mode{$reg_field{$i}[$j]} =~ m/H|I|F/i) {
			push @regiflines, "reg_$reg_field{$i}[$j] : process ($regif_name{'ResetAX'}, $regif_name{'Clk_free'})\nbegin";
		} else {
			push @regiflines, "reg_$reg_field{$i}[$j] : process ($regif_name{'ResetAX'}, $regif_name{'Clk_gated'})\nbegin";
		}
		push @regiflines, "if ($regif_name{'ResetAX'} = '0') then";
		if ($field_reset{$reg_field{$i}[$j]} =~ m/^0+$/) {
			if ($field_range{$reg_field{$i}[$j]} =~ m/downto/i) {
				push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= (others => '0');";
			} else {
				unless ($reg_range{$i}) {
					push @regiflines, "    $i <= '0';";
				} else {
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= '0';";
				}
			}
		} else {
			if ($field_range{$reg_field{$i}[$j]} =~ m/downto/i) {
				push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= \"$field_reset{$reg_field{$i}[$j]}\";";
			} else {
				unless ($reg_range{$i}) {
					push @regiflines, "    $i <= \'$field_reset{$reg_field{$i}[$j]}\';";
				} else {
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= \'$field_reset{$reg_field{$i}[$j]}\';";
				}
			}
		}
		if ($field_mode{$reg_field{$i}[$j]} =~ m/H|I|F/i) {
			push @regiflines, "elsif ($regif_name{'Clk_free'}'event and $regif_name{'Clk_free'} = '1') then";
		} else {
			push @regiflines, "elsif ($regif_name{'Clk_gated'}'event and $regif_name{'Clk_gated'} = '1') then";
		}
		if ($field_mode{$reg_field{$i}[$j]} =~ m/W/i) {
			push @regiflines, "  if (($i\_en and $regif_name{'WriteEn'}) = '1') then";
		} else {
			push @regiflines, "  if (($i\_en and $regif_name{'WriteEn'} and $regif_name{'RegTestMode'}) = '1') then";
		}
		if ($field_mode{$reg_field{$i}[$j]} =~ m/H/i) {
			if ($field_mode{$reg_field{$i}[$j]} =~ m/S/i) {
				unless ($reg_range{$i}) {
				        push @regiflines, "    $i <= $reg_field{$i}[$j]_wire or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
					push @regiflines, "  elsif (($i\_clr_en and $regif_name{'WriteEn'}) = '1') then";
					push @regiflines, "    $i <= $reg_field{$i}[$j]_wire and not(ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
				} else {
			        	push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= $reg_field{$i}[$j]_wire or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
					push @regiflines, "  elsif (($i\_clr_en and $regif_name{'WriteEn'}) = '1') then";
					push @regiflines, "     $i$field_range{$reg_field{$i}[$j]} <= $reg_field{$i}[$j]_wire and not(ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
				}
			} else {
			        unless ($reg_range{$i}) {
			        	push @regiflines, "    $i <= ($reg_field{$i}[$j]_wire and ByteEn_mask$field_range{$reg_field{$i}[$j]}) or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
			        } else {
			        	push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= ($reg_field{$i}[$j]_wire and ByteEn_mask$field_range{$reg_field{$i}[$j]}) or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
			        }
                        }
		} else {
			if ($field_mode{$reg_field{$i}[$j]} =~ m/S/i) {
				unless ($reg_range{$i}) {
					push @regiflines, "    $i <= $i or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
					push @regiflines, "  elsif (($i\_clr_en and $regif_name{'WriteEn'}) = '1') then";
					push @regiflines, "    $i <= $i and not(ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
				} else {
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= $i$field_range{$reg_field{$i}[$j]} or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
					push @regiflines, "  elsif (($i\_clr_en and $regif_name{'WriteEn'}) = '1') then";
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= $i$field_range{$reg_field{$i}[$j]} and not(ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
				}
			} else {
				unless ($reg_range{$i}) {
					push @regiflines, "    $i <= ($i and ByteEn_mask$field_range{$reg_field{$i}[$j]}) or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
				} else {
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= ($i$field_range{$reg_field{$i}[$j]} and ByteEn_mask$field_range{$reg_field{$i}[$j]}) or (ByteEn_maskX$field_range{$reg_field{$i}[$j]} and $regif_name{'WriteData'}$field_range{$reg_field{$i}[$j]});";
				}
			}
		}
		if ($field_mode{$reg_field{$i}[$j]} =~ m/H/i) {
			unless ($reg_range{$i}) {
				push @regiflines, "  else\n    $i <= $reg_field{$i}[$j]_wire;";
			} else {
				push @regiflines, "  else\n    $i$field_range{$reg_field{$i}[$j]} <= $reg_field{$i}[$j]_wire;";
			}
		} elsif ($field_mode{$reg_field{$i}[$j]} =~ m/F/i) {
			push @regiflines, "  else";
			if ($field_range{$reg_field{$i}[$j]} =~ m/downto/i) {
				push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= (others => '0');";
			} else {
				unless ($reg_range{$i}) {
					push @regiflines, "    $i <= '0';";
				} else {
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= '0';";
				}
			}
		} elsif ($field_mode{$reg_field{$i}[$j]} =~ m/I/i) {
			if ($field_clearing{$reg_field{$i}[$j]}) {
				push @regiflines, "  elsif $field_clearing{$reg_field{$i}[$j]} = '1' then";
			} else {
				print("Unable to proceed - $reg_field{$i}[$j] - is signal cleared (I), but the clearing signal has not been defined\n");
				exit;
			}
			if ($field_range{$reg_field{$i}[$j]} =~ m/downto/i) {
				push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= (others => '0');";
			} else {
				unless ($reg_range{$i}) {
					push @regiflines, "    $i <= '0';";
				} else {
					push @regiflines, "    $i$field_range{$reg_field{$i}[$j]} <= '0';";
				}
			}
		}
		push @regiflines, "  end if;";
		push @regiflines, "end if;";
		push @regiflines, "end process reg_$reg_field{$i}[$j];\n";
		if ($field_size{$reg_field{$i}[$j]}) {
			push @regiflines, "$reg_field{$i}[$j]\_reg$field_size{$reg_field{$i}[$j]} <= $i$field_range{$reg_field{$i}[$j]};\n";
		} else {
			unless ($reg_range{$i}) {
				push @regiflines, "$reg_field{$i}[$j]\_reg <= $i;\n";
			} else {
				push @regiflines, "$reg_field{$i}[$j]\_reg <= $i$field_range{$reg_field{$i}[$j]};\n";
			}
		}
	}
}

foreach my $i (@memory) {
	push @regiflines, "\n";
	push @regiflines, "-" x 80 ."\n-- Memory address register for $i";
	push @regiflines, "-" x 80;
	push @regiflines, "mem_$i : process ($regif_name{'ResetAX'}, $regif_name{'Clk_gated'})\nbegin";
	push @regiflines, "if ($regif_name{'ResetAX'} = '0') then";
	push @regiflines, "    $i\_addr <= (others => '0');";
	push @regiflines, "elsif ($regif_name{'Clk_gated'}'event and $regif_name{'Clk_gated'} = '1') then";
	push @regiflines, "  if (($i\_addr_en and $regif_name{'WriteEn'}) = '1') then";
	push @regiflines, "    $i\_addr <= (($i\_addr and ByteEn_mask($mem_addr_range{$i})) or (ByteEn_maskX($mem_addr_range{$i}) and $regif_name{'WriteData'}($mem_addr_range{$i})));";
	if ($mem_inc{$i}) {
		if ($mem_width{$i} > 16) {
			push @regiflines, "  elsif ((($i\_inc_en and mem_ack_r1) = '1') and ($regif_name{'ByteEn'}(".($if_size{"DSize"}/8-1)." downto ".($if_size{"DSize"}/8-2).") = \"11\")) then";
		} else {
			push @regiflines, "  elsif ($i\_inc_en and mem_ack_r1) = '1' then";
		}
	        if ($mem_type{$i} =~ m/W/i) {
			push @regiflines, "    if (conv_integer(unsigned($i\_addr)) = $mem_wrap{$i}) then";
			push @regiflines, "      $i\_addr <= (others => '0');";
			push @regiflines, "    else";
			push @regiflines, "      $i\_addr <= $i\_addr + 1;";
			push @regiflines, "    end if;";
                } else {
			push @regiflines, "    $i\_addr <= $i\_addr + 1;";
                }
	}
	if ($mem_dec{$i}) {
		if ($mem_width{$i} > 16) {
			push @regiflines, "  elsif ((($i\_inc_en and mem_ack_r1) = '1') and ($regif_name{'ByteEn'}(1 downto 0) = \"11\")) then";
		} else {
			push @regiflines, "  elsif ($i\_dec_en and mem_ack_r1) = '1' then";
		}
	        if ($mem_type{$i} =~ m/W/i) {
			push @regiflines, "    if ($i\_addr = ($i\_addr'range => '0') then";
			push @regiflines, "      $i\_addr <= std_logic_vector(to_unsigned($mem_wrap{$i}, $i\_addr'range));";
			push @regiflines, "    else";
			push @regiflines, "      $i\_addr <= $i\_addr - 1;";
			push @regiflines, "    end if;";
                } else {
			push @regiflines, "    $i\_addr <= $i\_addr - 1;";
                }
	}
	push @regiflines, "  end if;";
	push @regiflines, "end if;";
	push @regiflines, "end process mem_$i;\n";
	push @regiflines, "$i\_addr_reg <= $i\_addr;";
}
# Print EnableGen process
push @regiflines, "\n"."--"."#"x 78 ."--";
push @regiflines, "-- EnableGen generates register enable signals from $regif_name{'RegAddr'} for each register.";
push @regiflines, "--"."#"x 78 ."--";
push @regiflines, "EnableGen : process ($regif_name{'RegAddr'}";
if ((scalar(@memory)) or ($id)) { push @regiflines, "                    , $regif_name{'WriteEn'}"; }
if ($id) 			{ push @regiflines, "                    , $regif_name{'ReadEn'}"; }
$k = 0;
foreach my $j (@memory) {
	if ($mem_width{$j} > $k) {$k = $mem_width{$j}}
}	
if (scalar(@memory)) 		{ push @regiflines, "                    , $regif_name{'WriteData'}\(".($k-1)." downto 0\), $regif_name{'ByteEn'}\(".(divide($k,8)-1)." downto 0\)"; }
push @regiflines, "                    )";
push @regiflines, "begin";

my @temp_array; my %array_type; my %dummy;
foreach my $i (@register) {
	push @temp_array, "  $i\_en";
	$array_type{"  $i\_en"} = "<= '0';";
	if ($reg_clear_addr{$i}) {
		push @temp_array, "  $i\_clr_en";
		$array_type{"  $i\_clr_en"} = "<= '0';";
	}
}
if ($id) {
	push @temp_array, "  $id\_en";
	$array_type{"  $id\_en"} = "<= '0';";
}
foreach my $i (@memory) {
	my @temp_var = ("_addr_en", "_en");
	if ($mem_inc{$i}) { push @temp_var, "_inc_en"; }
	if ($mem_dec{$i}) { push @temp_var, "_dec_en"; }
	foreach my $j (@temp_var) {
		push @temp_array, "  $i$j";
		$array_type{"  $i$j"} = "<= '0';";
	}
	foreach my $j ("_wenX") {
		push @temp_array, "  $i$j";
		$array_type{"  $i$j"} = "<= '1';";
	}
	push @temp_array, "  $i\_w_d";
	$array_type{"  $i\_w_d"} = "<= (others => '0');";
	push @temp_array, "  $i\_byte_en";
	$array_type{"  $i\_byte_en"} = "<= (others => '0');";
}
push @temp_array, "  address_error";
$array_type{"  address_error"} = "<= '0';";
my $max_size = maxlength (\@temp_array, \%dummy);
push @regiflines, genmapper (\@temp_array, \%array_type, \%dummy, $max_size+5);
push @regiflines, "    case conv_integer(unsigned($regif_name{'RegAddr'})) is";

my @sub_array; my %sub_yes; my %pre_array; my %dummy;

engen_loop: foreach my $j (@register) {
	push @sub_array, "       when $reg_addr{$j} =>";
	push @sub_array, "$j\_en <= '1';";
	$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
	$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
	if ($reg_clear_addr{$j}) {
		push @sub_array, "       when $reg_clear_addr{$j} =>";
		push @sub_array, "$j\_clr_en <= '1';";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
	}
}
if ($id) {
	push @sub_array, "       when $id_addr =>";
	push @sub_array, "$id\_en <= $regif_name{'ReadEn'} or $regif_name{'WriteEn'};";
	$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
	$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
}
mem_engen_loop: foreach my $j (@memory) {
	push @sub_array, "       when $mem_addr{$j} =>";
	push @sub_array, "$j\_addr_en <= '1';";
	$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
	$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
	if ($mem_type{$j} =~ m/A/i) {
		push @sub_array, "       when $mem_acc{$j} =>";
		foreach my $i ("_en") {
			push @sub_array, "$j$i <= $regif_name{'ByteEn'}(0) or $regif_name{'ByteEn'}(1);";
			$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
			$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		}
		push @sub_array, "$j\_wenX <= not $regif_name{'WriteEn'};";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		push @sub_array, "$j\_w_d <= $regif_name{'WriteData'}\(".($mem_width{$j}-1)." downto 0\);";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		push @sub_array, "$j\_byte_en <= $regif_name{'ByteEn'}\(".(divide($mem_width{$j},8)-1)." downto 0\);";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
	}
	if ($mem_type{$j} =~ m/I/i) {
		push @sub_array, "       when $mem_inc{$j} =>";
		foreach my $i ("_en", "_inc_en") {
			push @sub_array, "$j$i <= $regif_name{'ByteEn'}(0) or $regif_name{'ByteEn'}(1);";
			$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
			$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		}
		push @sub_array, "$j\_wenX <= not $regif_name{'WriteEn'};";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		push @sub_array, "$j\_w_d <= $regif_name{'WriteData'}\(".($mem_width{$j}-1)." downto 0\);";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		push @sub_array, "$j\_byte_en <= $regif_name{'ByteEn'}\(".(divide($mem_width{$j},8)-1)." downto 0\);";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
	}
	if ($mem_type{$j} =~ m/D/i) {
		push @sub_array, "       when $mem_dec{$j} =>";
		foreach my $i ("_en", "_dec_en") {
			push @sub_array, "$j$i <= $regif_name{'ByteEn'}(0) or $regif_name{'ByteEn'}(1);";
			$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
			$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		}
		push @sub_array, "$j\_wenX <= not $regif_name{'WriteEn'};";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		push @sub_array, "$j\_w_d <= $regif_name{'WriteData'}\(".($mem_width{$j}-1)." downto 0\);";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
		push @sub_array, "$j\_byte_en <= $regif_name{'ByteEn'}\(".(divide($mem_width{$j},8)-1)." downto 0\);";
		$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
		$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];
	}
}
push @sub_array, "       when others =>";
push @sub_array, "address_error <= '1';";
$sub_yes{@sub_array[scalar(@sub_array)-1]} = "1";
$pre_array{@sub_array[scalar(@sub_array)-1]} = @sub_array[scalar(@sub_array)-1];

my $max_size = maxlength (\@sub_array, \%dummy);
push @regiflines, genmapper (\@sub_array, \%pre_array, \%sub_yes, $max_size+10);
push @regiflines, "    end case;\nend process EnableGen;\n";

# Print ReadMux process
push @regiflines, "\n"."--"."#"x 78 ."--";
push @regiflines, "-- ReadMux-process is a multiplexer, which selects the correct databus";
push @regiflines, "-- coming from the module. Selection is done with RegAddr, when ReadEn";
push @regiflines, "-- is active. Unknown address will raise the ReadError flag.";
push @regiflines, "--"."#"x 78 ."--";
push @regiflines, "ReadMux : process ($regif_name{'RegAddr'},";
foreach my $i (@register) {
for my $j (0 .. $#{$reg_field{$i}}) {
		unless ($reg_range{$i}) {
			push @regiflines, "                  $i,";
		} else {
			push @regiflines, "                  $i$field_range{$reg_field{$i}[$j]},";
		}
	}
}
if ($id) {
	push @regiflines, "                  $id\_r_d,";
}
foreach my $j (@memory) {
	push @regiflines, "                  $j\_addr,";
	push @regiflines, "                  $j\_r_d,";
}
@regiflines[scalar(@regiflines)-1] =~ s/,$//;
push @regiflines, "                  )";
push @regiflines, "begin";
push @regiflines, "  ReadData_int   <= (others => '0');";
push @regiflines, "  add_latency    <= '0';";
push @regiflines, "  case conv_integer(unsigned($regif_name{'RegAddr'})) is";

rdengen_loop: foreach my $i (@register) {
	unique_reg_loop: for my $j (0 .. $#{$reg_field{$i}}) {
		push @regiflines, "    when $reg_addr{$i} => ";
		last unique_reg_loop;
	}
	for my $j (0 .. $#{$reg_field{$i}}) {
		unless ($reg_range{$i}) {
			push @regiflines, "             ReadData_int$field_range{$reg_field{$i}[$j]} <= $i;";
		} else {
			push @regiflines, "             ReadData_int$field_range{$reg_field{$i}[$j]} <= $i$field_range{$reg_field{$i}[$j]};";
		}
	}
        if ($reg_clear_addr{$i}) {
                push @regiflines, "    when $reg_clear_addr{$i} =>";
	        for my $j (0 .. $#{$reg_field{$i}}) {
	       	        unless ($reg_range{$i}) {
	        		push @regiflines, "             ReadData_int$field_range{$reg_field{$i}[$j]} <= not($i);";
	        	} else {
	        		push @regiflines, "             ReadData_int$field_range{$reg_field{$i}[$j]} <= not($i$field_range{$reg_field{$i}[$j]});";
	        	}
	        }
        }
	latency_loop: for my $j (0 .. $#{$reg_field{$i}}) {
		if ($field_mode{$reg_field{$i}[$j]} =~ m/L/i) {
		push @regiflines, "             add_latency <= '1';";
		last latency_loop;
		}
	}

}
if ($id) {
	push @regiflines, "    when $id_addr => ";
	push @regiflines, "             ReadData_int(".($if_size{"DSize"}-1)." downto 0) <= $id\_r_d;";
}
rdmemgen_loop: foreach my $j (@memory) {
	push @regiflines, "    when $mem_addr{$j} =>";
	push @regiflines, "             ReadData_int\($mem_addr_range{$j}\) <= $j\_addr;";
	if ($mem_type{$j} =~ m/A/i) {
		push @regiflines, "    when $mem_acc{$j} =>";
		push @regiflines, "             ReadData_int\(".($mem_width{$j}-1)." downto 0\) <= $j\_r_d;";
	}
	if ($mem_type{$j} =~ m/I/i) {
		push @regiflines, "    when $mem_inc{$j} =>";
		push @regiflines, "             ReadData_int\(".($mem_width{$j}-1)." downto 0\) <= $j\_r_d;";
	}
	if ($mem_type{$j} =~ m/D/i) {
		push @regiflines, "    when $mem_dec{$j} =>";
		push @regiflines, "             ReadData_int\(".($mem_width{$j}-1)." downto 0\) <= $j\_r_d;";
	}
}
push @regiflines, "    when others =>\n             null;\n    end case;\nend process ReadMux;\n";
push @regiflines, "$regif_name{'ReadData'} <= ReadData_int and ByteEn_maskX;\n";

# Print Memory related processes
if (scalar(@memory)) {
	push @regiflines, "\n"."--"."#"x 78 ."--";
	push @regiflines, "-- Memory access related processes";
	push @regiflines, "--"."#"x 78 ."--";
	push @regiflines, "pro_mem_ack : process ($regif_name{'ResetAX'}, $regif_name{'Clk_gated'})\nbegin";
	push @regiflines, "if ($regif_name{'ResetAX'} = '0') then";
	push @regiflines, "  mem_ack_r1 <= '0';";
	push @regiflines, "  mem_ack_r2 <= '0';";
	push @regiflines, "elsif ($regif_name{'Clk_gated'}'event and $regif_name{'Clk_gated'} = '1') then";
	my @temp_array;
	foreach my $j (@memory) {
		push @temp_array, "$j\_ack";
	}
	push @regiflines, "  mem_ack_r1 <= " .(join " or ", @temp_array). ";";
	push @regiflines, "  mem_ack_r2 <= mem_ack_r1;";
	push @regiflines, "end if;";
	push @regiflines, "end process pro_mem_ack;\n";
}
	
# Print Memory req generation process
if (scalar(@memory)) {
	foreach my $j (@memory) {
		push @regiflines, "\n"."--"."#"x 78 ."--";
		push @regiflines, "-- Memory request generation processes for $j";
		push @regiflines, "--"."#"x 78 ."--";
		push @regiflines, "$j\_req_pro : process ($j\_en, $regif_name{'ReadEn'}, $regif_name{'WriteEn'}, mem_ack_r1, mem_ack_r2)\nbegin";
		push @regiflines, "  if ((mem_ack_r1 or mem_ack_r2) = '1') then";
		push @regiflines, "    $j\_req_int <= '0';";
		push @regiflines, "  elsif (($j\_en and ($regif_name{'ReadEn'} or $regif_name{'WriteEn'})) = '1') then";
		push @regiflines, "    $j\_req_int <= '1';";
		push @regiflines, "  else";
		push @regiflines, "    $j\_req_int <= '0';";
		push @regiflines, "  end if;";
		push @regiflines, "end process $j\_req_pro;\n";
		push @regiflines, "$j\_req <= $j\_req_int;\n";
	}
}
	
# Response generating process
push @regiflines, "\n"."--"."#"x 78 ."--";
push @regiflines, "-- Response generating process";
push @regiflines, "--"."#"x 78 ."--";
push @regiflines, "pro_resp : process ($regif_name{'ReadEn'}, $regif_name{'WriteEn'}, address_error"; 
if (scalar(@memory)) {
	my @temp_array;
	foreach my $j (@memory) {
		push @temp_array, "$j\_en";
	}
	push @regiflines, "                    , mem_ack_r2, " .(join ", ", @temp_array); 
}
push @regiflines, "                    )\nbegin";
push @regiflines, "  if (($regif_name{'ReadEn'} or $regif_name{'WriteEn'}) = '1') then";
push @regiflines, "    if (address_error = '1') then";
push @regiflines, "      response_int <= \"11\";";
if (scalar(@memory)) {
	my @temp_array;
	foreach my $j (@memory) {
		push @temp_array, "$j\_en";
	}
	push @regiflines, "    elsif ((" .(join " or ", @temp_array). ") = '1') then";
	push @regiflines, "      if (mem_ack_r2 = '1') then";
	push @regiflines, "        response_int <= \"01\";";
	push @regiflines, "      else";
	push @regiflines, "        response_int <= \"00\";";
	push @regiflines, "      end if;";
}
push @regiflines, "    else";
push @regiflines, "      response_int <= \"01\";";
push @regiflines, "    end if;";
push @regiflines, "  else";
push @regiflines, "      response_int <= \"00\";";
push @regiflines, "  end if;";
push @regiflines, "end process pro_resp;\n";

# Response latency generating process
push @regiflines, "\n"."--"."#"x 78 ."--";
push @regiflines, "-- Response latency generating process";
push @regiflines, "--"."#"x 78 ."--";
push @regiflines, "pro_res_lat : process ($regif_name{'ResetAX'}, $regif_name{'Clk_free'})\nbegin";
push @regiflines, "if ($regif_name{'ResetAX'} = '0') then";
push @regiflines, "  add_latency_d1 <= '0';";
push @regiflines, "elsif ($regif_name{'Clk_free'}'event and $regif_name{'Clk_free'} = '1') then";
push @regiflines, "  if add_latency = '1' and $regif_name{'ReadEn'} = '1' then";
push @regiflines, "    add_latency_d1 <= not add_latency_d1;";
push @regiflines, "  else";
push @regiflines, "    add_latency_d1 <= '0';";
push @regiflines, "  end if;";
push @regiflines, "end if;";
push @regiflines, "end process pro_res_lat;\n";
push @regiflines, "Response <= \"00\" when (add_latency = '1' and add_latency_d1 = '0' and $regif_name{'ReadEn'} = '1') else response_int;";

# The ByteEn_mask generating lines
for my $j (0 .. $if_size{"DSize"}/8-1 ) {
	my $d = $j*8; my $u = $d + 7;
	push @regiflines, "ByteEn_mask($u downto $d) <= \"00000000\" when ByteEn($j) = '1' else \"11111111\";";
}
my $temp_var = $if_size{DSize}-1;
push @regiflines, "ByteEn_maskX($temp_var downto 0) <= not ByteEn_mask;";
# Print architecture end
push @regiflines, "\nend rtl;";

#------------------------------------------------------------------------------ 
# Test output - useful for debugging
#------------------------------------------------------------------------------
#foreach my $i (@register) {
#	print "$i => $reg_addr{$i} => $reg_range{$i}\n";
#	for my $j (0 .. $#{$reg_field{$i}}) {
#		print "$i => $reg_field{$i}[$j] => $field_range{$reg_field{$i}[$j]} => $field_reset{$reg_field{$i}[$j]}";
#		print " => $field_mode{$reg_field{$i}[$j]}\n";
#	}
#}
#
#foreach my $i (@memory) {
#	print "$i => $mem_addr{$i} => $mem_addr_range{$i}\n";
#	print "$i => $mem_inc{$i} => $mem_width{$i}\n";
#	print "$i => $mem_dec{$i} => $mem_width{$i}\n";
#	print "$i => $mem_acc{$i} => $mem_width{$i}\n";
#}
#
#foreach my $i (keys(%id_fields)) {
#  print "$i \t=> $id_fields{$i}\n";
#}
#
#foreach my $i (keys(%module)) {
#  print "$i \t=> $module{$i}\n";
#}
#

#my $modif= join "\n", @modiflines;
#print ("$modif\n");


#------------------------------------------------------------------------------ 
# Writing to output regiffile
#------------------------------------------------------------------------------
open (OUTFILE, ">$regiffile");
my $out= join "\n", @regiflines;

print OUTFILE ("$out\n");
close (OUTFILE);

exit;

############################################################################### 
# SUB ROUTINES
############################################################################### 
#------------------------------------------------------------------------------ 
# Generic Error and Exit routine 
#------------------------------------------------------------------------------

sub dienice {
	my($errmsg) = @_;
	print"$errmsg\n";
	exit;
}

#------------------------------------------------------------------------------ 
# Library declaration
#------------------------------------------------------------------------------
sub library_dec {
	my ($module_top, $module_name, $module_comp, $id) = @_;
	my @data = "\nlibrary ieee;";
	push @data, "USE ieee.std_logic_1164.all;";
	push @data, "USE ieee.std_logic_arith.all;";
	push @data, "USE ieee.std_logic_unsigned.all;";
	push @data, "library $module_top"."_lib;";
	push @data, "USE $module_top"."_lib.$module_comp.all;";
	return @data;
}

#------------------------------------------------------------------------------ 
# General mapping
#------------------------------------------------------------------------------
sub genmapper {
	my ($subject, $predicate, $sub_no, $col_indent) = @_;
        my @data; my $s; my $p;
        foreach my $i (@$subject) {
		unless ($$sub_no{$i}) { $s = $i; } else { $s = ""; }
		push @data, join ' 'x ($col_indent - length($s)), "$s", "$$predicate{$i}";
	}
	return @data;
}

#------------------------------------------------------------------------------ 
# Port mapping
#------------------------------------------------------------------------------
sub portmapper {
	my ($decl, $signal_list, $signal_name, $signal_range, $signal_type, $io, $col_indent) = @_;
        my @data;
        foreach my $i (@$signal_list) {
                if ($$signal_type{$i}) {
                	if ($$signal_name{$i}) {
				push @data, join ' 'x ($col_indent - length($$signal_name{$i})), "$decl $$signal_name{$i}", "$io $$signal_type{$i};";
			} else {
				push @data, join ' 'x ($col_indent - length($i)), "$decl $i", "$io $$signal_type{$i};";
			}
                } elsif ($$signal_range{$i} =~ m/downto/) {
                	if ($$signal_name{$i}) {
				push @data, join ' 'x ($col_indent - length($$signal_name{$i})), "$decl $$signal_name{$i}", "$io std_logic_vector$$signal_range{$i};";
			} else {
				push @data, join ' 'x ($col_indent - length($i)), "$decl $i", "$io std_logic_vector$$signal_range{$i};";
			}
		} else {
                	if ($$signal_name{$i}) {
				push @data, join ' 'x ($col_indent - length($$signal_name{$i})), "$decl $$signal_name{$i}", "$io std_logic;";
			} else {
				push @data, join ' 'x ($col_indent - length($i)), "$decl $i", "$io std_logic;";
			}
		}
	}
	return @data;
}

#------------------------------------------------------------------------------ 
# Divide
#------------------------------------------------------------------------------
sub divide {
	my ($num, $denom) = @_;
        my $result;
        if ($num % $denom) {
              $result = ($num - ($num % $denom)) / $denom + 1;
	} else {
              $result = $num / $denom;
        }
	return $result;
}

#------------------------------------------------------------------------------ 
# Max length
#------------------------------------------------------------------------------
sub maxlength {
	my ($data, $signal_name) = @_;
	my $max_size = 0;
	foreach my $i (@$data) {
               	if ($$signal_name{$i}) {
			if (length($$signal_name{$i}) > $max_size) {
				$max_size = length($$signal_name{$i});
			}
		} else {
			if (length($i) > $max_size) {
				$max_size = length($i);
			}
		}
	}
	return $max_size;
}

#---------------------------------------------------------------
# Clean comments and carriage returns
#---------------------------------------------------------------
sub clean {
	# Strip newlines and comments
        my ($data, $start, $end) = @_;
	foreach (@$data) { chomp; }
	for (my $line = $start; $line < $end; $line++) {
		@$data[$line] =~ s/--.*//;
	}
}

#---------------------------------------------------------------
# Find specified label
#---------------------------------------------------------------
sub find_label {
	# initialize counters
        my ($data, $pattern) = @_;
	my $found_line = -1;
	# locate PATTERN in specfile
	find_loop: for (my $line = 0; $line < scalar(@$data); $line++) {
		if (@$data[$line] =~ m/$pattern/) {
			$found_line = $line;
                        last find_loop;
		}
	}
        return $found_line;
}

#---------------------------------------------------------------
# Modify name
#---------------------------------------------------------------
sub constify {
        my ($range, $name, $const) = @_;
        my $temp_var = $name;
	if ($range =~ m/\?+/) {
		$temp_var =~ tr/[a-z]/[A-Z]/; 
		$range = "$temp_var"."$const";
	}
        return $range;
}

#---------------------------------------------------------------
# ID register generic at top level
#---------------------------------------------------------------
sub id_reg_gens {
	my ($fields) = @_;
        my $num = 0; my @data; my $j = 0; my $m;
		foreach my $i (keys(%$fields)) {
			if ($$fields{$i} =~ m/$i/i) {
                        	unless ($num) {push @data, "  generic ("; }
                                $num = $num + 1;
                        }
                }
		foreach my $i (keys(%$fields)) {
                        if ($$fields{$i} =~ m/VCPr/i)          { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VCPr             : integer range 0  to ((2**16)-1)$m           -- Location name                      ";}
                        elsif ($$fields{$i} =~ m/VCNum/i)      { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VCNum            : integer range 0  to ((2**16)-1)$m           -- (sub-module ID-number) => 16 bits  ";}
                        elsif ($$fields{$i} =~ m/VC_Ver_MSB/i) { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VC_Ver_MSB       : integer range 0  to ((2**8)-1)$m            -- (sub-module release)   => 8 bits   ";}
                        elsif ($$fields{$i} =~ m/VC_Ver_LSB/i) { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VC_Ver_LSB       : integer range 0  to ((2**8)-1)$m            -- (sub-module version)   => 8 bits   ";}
                        elsif ($$fields{$i} =~ m/VC_Info_0/i)  { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VC_Info_0        : integer$m                                   -- (module specific info) => 32 bits  ";}
                        elsif ($$fields{$i} =~ m/VC_Info_1/i)  { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VC_Info_1        : integer$m                                   -- (module specific info) => 32 bits  ";}
                        elsif ($$fields{$i} =~ m/VC_Info_2/i)  { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VC_Info_2        : integer$m                                   -- (module specific info) => 32 bits  ";}
                        elsif ($$fields{$i} =~ m/VC_Info_En/i) { $j++; if ($j == $num) {$m = " );"} else {$m = ";  "} push @data, "    VC_Info_En       : integer range 0  to ((2**2)-1)$m            -- # of data words used of words 5 - 7";}
                }
	return @data;
}
#---------------------------------------------------------------
# ID register component
#---------------------------------------------------------------
sub id_reg_comp {
        my @data;
	push @data, "\ncomponent w_common_id_reg_$if_size{\"DSize\"} is";
   	push @data, "  generic (";
   	push @data, "    VCPr        : integer range 0  to ((2**16)-1);  -- Location name";
   	push @data, "    VCNum       : integer range 0  to ((2**16)-1);  -- (sub-module ID-number) => 16 bits";
   	push @data, "    VC_Ver_MSB  : integer range 0  to ((2**8)-1);   -- (sub-module release)   => 8 bits";
   	push @data, "    VC_Ver_LSB  : integer range 0  to ((2**8)-1);   -- (sub-module version)   => 8 bits";
   	push @data, "    VC_Info_0   : integer ;                         -- (module specific info) => 32 bits";
   	push @data, "    VC_Info_1   : integer ;                         -- (module specific info) => 32 bits";
   	push @data, "    VC_Info_2   : integer ;                         -- (module specific info) => 32 bits";
   	push @data, "    VC_Info_En  : integer range 0  to ((2**2)-1)    -- # of data words used of words 5 - 7 ";
    	push @data, "  );";
   	push @data, "  port(";
    	push @data, "    ResetAX     : in std_logic;    -- Asyncronous reset";
    	push @data, "    Clk         : in std_logic;    -- Bus domain clock ";
    	push @data, "    IDREGEn     : in std_logic;";
    	push @data, "    ReadEn      : in std_logic;";
    	push @data, "    WriteData   : in std_logic_vector(".($if_size{"DSize"}-1)." downto 0);";
    	push @data, "    ByteEn      : in std_logic_vector(1 downto 0);";
    	push @data, "    DataOut     : out std_logic_vector(".($if_size{"DSize"}-1)." downto 0)";
     	push @data, "  );";
	push @data, "end component;\n";
	return @data;
}

#---------------------------------------------------------------
# ID register instance
#---------------------------------------------------------------
sub id_reg_inst {
	my ($name, $fields, $signals) = @_;
        my @data;
	push @data, "\ninst_w_common_id_reg_$if_size{\"DSize\"} : w_common_id_reg_$if_size{\"DSize\"}";
   	push @data, "  generic map(";
   	push @data, "    VCPr        => $$fields{'VCPr'},";
   	push @data, "    VCNum       => $$fields{'VCNum'},";
   	push @data, "    VC_Ver_MSB  => $$fields{'VC_Ver_MSB'},";
   	push @data, "    VC_Ver_LSB  => $$fields{'VC_Ver_LSB'},";
   	push @data, "    VC_Info_0   => $$fields{'VC_Info_0'},";
   	push @data, "    VC_Info_1   => $$fields{'VC_Info_1'},";
   	push @data, "    VC_Info_2   => $$fields{'VC_Info_2'},";
   	push @data, "    VC_Info_En  => $$fields{'VC_Info_En'}";
    	push @data, "  )";
   	push @data, "  port map(";
    	push @data, "    ResetAX     => $$signals{'ResetAX'},";
    	push @data, "    Clk         => $$signals{'Clk_free'},";
    	push @data, "    IDREGEn     => $name\_en,";
    	push @data, "    ReadEn      => $$signals{'ReadEn'},";
    	push @data, "    WriteData   => $$signals{'WriteData'},";
    	push @data, "    ByteEn      => \"11\",";
    	push @data, "    DataOut     => $name\_r_d";
     	push @data, "  );";
	return @data;
}
