############################################################
#
# Module: GD::Graph::pie3d
#
# Description: 
# This is merely a wrapper around GD::Graph::pie that forces 
# the 3d option for pie charts.
#
# Created: 2000.Jan.19 by Jeremy Wadsack for Wadsack-Allen Digital Group
# 	Copyright (C) 2000 Wadsack-Allen. All rights reserved.
############################################################
# Date      Modification                               Author
# ----------------------------------------------------------
# 2000APR18 Modified to be compatible w/ GD::Graph 1.30  JAW
############################################################
package GD::Graph::pie3d;

use strict;
use GD;
use GD::Graph;
use GD::Graph::pie;
use Carp;

@GD::Graph::pie3d::ISA = qw( GD::Graph::pie );
$GD::Graph::pie3d::VERSION = '0.40';

my %Defaults = (
	'3d'        => 1,
);

sub initialise {
	my $self = shift;
	my $rc = $self->SUPER::initialise();
	while( my($key, $val) = each %Defaults ) { 
		$self->{$key} = $val;
	} # end while
	return $rc;
} # end initialise

# Inherit everything else from GD::Graph::pie

1;
