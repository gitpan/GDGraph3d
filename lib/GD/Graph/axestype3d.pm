#==========================================================================
# Module: GIFgraph::axestype3d
#
# Copyright (C) 1999,2000 Wadsack-Allen. All Rights Reserved.
#
# Based on axestype.pm,v 1.10 2000/01/09 12:43:58 mgjv
#          Copyright (c) 1995-1998 Martien Verbruggen
#
#--------------------------------------------------------------------------
# Date		Modification				                  Author
# -------------------------------------------------------------------------
# 1999SEP18 Created 3D axestype base class (this      JAW
#           module) changes noted in comments.
# 1999OCT15 Fixed to include all GIFgraph functions   JAW
#           necessary for PNG support.
# 2000JAN19 Converted to GD::Graph sublcass           JAW
# 2000FEB21 Fixed bug in y-labels' height             JAW
#==========================================================================
# TODO
#		* Modify to use true 3-d extrusions at any theta and phi
#==========================================================================
package GD::Graph::axestype3d;

use strict;
 
use GD::Graph;
use GD::Graph::axestype;
use GD::Graph::utils qw(:all);
use Carp;

@GD::Graph::axestype3d::ISA = qw(GD::Graph::axestype);
$GD::Graph::axestype3d::VERSION = '0.34';

# Commented inheritance from GD::Graph::axestype unless otherwise noted.

use constant PI => 4 * atan2(1,1);

my %Defaults = (
	# Only default here is depth_3d, rest inherited
	depth_3d					=> 20,
);

# Inherit _has_default 


# Can't inherit initialise, because %Defaults is referenced file-
# specific, not class specific.
sub initialise
{
	my $self = shift;

	$self->SUPER::initialise();

	while (my($key, $val) = each %Defaults) 
		{ $self->{$key} = $val }
}

# PUBLIC
# Inherit plot
# Inherit set
# Inherit setup_text
# Inherit set_x_label_font
# Inherit set_y_label_font
# Inherit set_x_axis_font
# Inherit set_y_axis_font
# Inherit set_legend
# Inherit set_legend_font


# PRIVATE

# inherit check_data from GD::Graph

sub setup_coords
{
	my $s = shift;
	my $data = shift;

	# Do some sanity checks
	$s->{two_axes} = 0 if ( $s->{numsets} != 2 || $s->{two_axes} < 0 );
	$s->{two_axes} = 1 if ( $s->{two_axes} > 1 );

	delete $s->{y_label2} unless ($s->{two_axes});

	# Set some heights for text
	$s->{tfh} = 0 unless $s->{title};
	$s->{xlfh} = 0 unless $s->{x_label};

	# Make sure the y1 axis has a label if there is one set for y in
	# general
	$s->{y1_label} = $s->{y_label} 
		if ( ! $s->{y1_label} && $s->{y_label} );

	# Set axis tick text heights and widths to 0 if they don't need to
	# be plotted.
	$s->{xafh} = 0, $s->{xafw} = 0 unless $s->{x_plot_values}; 
	$s->{yafh} = 0, $s->{yafw} = 0 unless $s->{y_plot_values};

	# Get the height of the space needed for the X axis tick text
	$s->{x_axis_label_height} = $s->get_x_axis_label_height($data);

	# CONTRIB Jeremy Wadsack
	# Calculate the 3d-depth of the graph
	# Note this sets a minimum depth of ~20 pixels
	if (!defined $s->{x_tick_number}) {
		my $depth = _max( $s->{bar_depth}, $s->{line_depth} );
	   $s->{depth_3d} = _max( $depth, $s->{depth_3d} );
	} # end if
	
	# calculate the top and bottom of the bounding box for the graph
	$s->{bottom} = $s->{height} - $s->{b_margin} - 1 -
		# X axis tick labels
		( $s->{x_axis_label_height} ? $s->{x_axis_label_height} : 0) -
		# X axis label
		( $s->{xlfh} ? $s->{xlfh} + $s->{text_space} : 0 );

	$s->{top} = $s->{t_margin} +
				( $s->{tfh} ? $s->{tfh} + $s->{text_space} : 0 );
	# Make sure the text for the y axis tick markers fits on the canvas
	$s->{top} = $s->{yafh}/2 if ( $s->{top} == 0 );

	# CONTRIB Jeremy Wadsack
	# adjust for top of 3-d extrusion
	$s->{top} += $s->{depth_3d};

	$s->set_max_min($data);

	# Create the labels for the y_axes, and calculate the max length

	$s->create_y_labels();
	$s->create_x_labels(); # CONTRIB Scott Prahl

	# calculate the left and right of the bounding box for the graph
	#my $ls = $s->{yafw} * $s->{y_label_len}[1];
	my $ls = $s->{y_label_len}[1];
	$s->{left} = $s->{l_margin} +
				 # Space for tick values
				 ( $ls ? $ls + $s->{axis_space} : 0 ) +
				 # Space for the Y axis label
				 ( $s->{y1_label} ? $s->{ylfh} + $s->{text_space} : 0 );

	#$ls = $s->{yafw} * $s->{y_label_len}[2] if $s->{two_axes};
	$ls = $s->{y_label_len}[2] if $s->{two_axes};
	$s->{right} = $s->{width} - $s->{r_margin} - 1 -
				  $s->{two_axes} * (
					  ( $ls ? $ls + $s->{axis_space} : 0 ) +
					  ( $s->{y2_label} ? $s->{ylfh} + $s->{text_space} : 0 )
				  );

	# CONTRIB Jeremy Wadsack
	# adjust for right of 3-d extrusion
	$s->{right} -= $s->{depth_3d};

	# CONTRIB Scott Prahl
	# make sure that we can generate valid x tick marks
	undef($s->{x_tick_number}) if $s->{numpoints} < 2;
	undef($s->{x_tick_number}) if (
			!defined $s->{x_max} || 
			!defined $s->{x_min} ||
			$s->{x_max} == $s->{x_min}
		);

	# calculate the step size for x data
	# CONTRIB Changes by Scott Prahl
	if (defined $s->{x_tick_number})
	{
		my $delta = ($s->{right} - $s->{left})/($s->{x_max} - $s->{x_min});
		$s->{x_offset} = 
			($s->{true_x_min} - $s->{x_min}) * $delta + $s->{left};
		$s->{x_step} = 
			($s->{true_x_max} - $s->{true_x_min}) * $delta/$s->{numpoints};
	}
	else
	{
		$s->{x_step} = ($s->{right} - $s->{left})/($s->{numpoints} + 2);
		$s->{x_offset} = $s->{left};
	}

	# get the zero axis level
	my $dum;
	($dum, $s->{zeropoint}) = $s->val_to_pixel(0, 0, 1);

	# Check the size
	croak "Vertical size too small"
		if ( ($s->{bottom} - $s->{top}) <= 0 );

	croak "Horizontal size too small"	
		if ( ($s->{right} - $s->{left}) <= 0 );

	# More sanity checks
	$s->{x_label_skip} = 1 		if ( $s->{x_label_skip} < 1 );
	$s->{y_label_skip} = 1 		if ( $s->{y_label_skip} < 1 );
	$s->{y_tick_number} = 1		if ( $s->{y_tick_number} < 1 );
}

# Inherit create_y_labels
# Inherit create_x_labels
# Inherit get_x_axis_label_height

# inherit open_graph from GD::Graph

sub draw_text
{
	my $s = shift;

	if ($s->{title})
	{
		my $xc = $s->{left} + ($s->{right} - $s->{left})/2;
		$s->{gdta_title}->set_align('top', 'center');
		$s->{gdta_title}->set_text($s->{title});
		$s->{gdta_title}->draw($xc, $s->{t_margin});
	}

	# X label
	if (defined $s->{x_label}) 
	{
		$s->{gdta_x_label}->set_text($s->{x_label});
		$s->{gdta_x_label}->set_align('bottom', 'left');
		my $tx = $s->{left} +
			$s->{x_label_position} * ($s->{right} - $s->{left}) - 
			$s->{x_label_position} * $s->{gdta_x_label}->get('width');
		$s->{gdta_x_label}->draw($tx, $s->{height} - $s->{b_margin});
	}

	# Y labels
	if (defined $s->{y1_label}) 
	{
		$s->{gdta_y_label}->set_text($s->{y1_label});
		$s->{gdta_y_label}->set_align('top', 'left');
		my $tx = $s->{l_margin};
		my $ty = $s->{bottom} -
			$s->{y_label_position} * ($s->{bottom} - $s->{top}) + 
			$s->{y_label_position} * $s->{gdta_y_label}->get('width');
		$s->{gdta_y_label}->draw($tx, $ty, PI/2);
	}
	if ( $s->{two_axes} && defined $s->{y2_label} ) 
	{
		$s->{gdta_y_label}->set_text($s->{y2_label});
		$s->{gdta_y_label}->set_align('bottom', 'left');
		my $tx = $s->{width} - $s->{r_margin};
		my $ty = $s->{bottom} -
			$s->{y_label_position} * ($s->{bottom} - $s->{top}) + 
			$s->{y_label_position} * $s->{gdta_y_label}->get('width');
		$s->{gdta_y_label}->draw($tx, $ty, PI/2);
	}
}

#
# CONTRIB Jeremy Wadsack
# Added drawing for entire bounding cube for 3-d extrusion
#
sub draw_axes
{
	my $s = shift;
	my $d = shift;
	my $g = $s->{graph};

	my ($l, $r, $b, $t) = 
		( $s->{left}, $s->{right}, $s->{bottom}, $s->{top} );
	my $depth = $s->{depth_3d};

	if ( $s->{box_axis} ) 
	{
		if( $s->{boxci} ) {
			# Back box
			$g->filledRectangle($l+$depth+1, $t-$depth+1, $r+$depth-1, $b-$depth-1, $s->{boxci});

			# Left side
			my $poly = new GD::Polygon;
			$poly->addPt( $l, $t );
			$poly->addPt( $l + $depth, $t - $depth );
			$poly->addPt( $l + $depth, $b - $depth );
			$poly->addPt( $l, $b );
			$g->filledPolygon( $poly, $s->{boxci} );

			# Right side
			$poly = new GD::Polygon;
			$poly->addPt( $r, $t );
			$poly->addPt( $r + $depth, $t - $depth );
			$poly->addPt( $r + $depth, $b - $depth );
			$poly->addPt( $r, $b );
			$g->filledPolygon( $poly, $s->{boxci} );

			# Bottom
			$poly = new GD::Polygon;
			$poly->addPt( $l, $b );
			$poly->addPt( $l + $depth, $b - $depth );
			$poly->addPt( $r + $depth, $b - $depth );
			$poly->addPt( $r, $b );
			$g->filledPolygon( $poly, $s->{boxci} );
		} # end if

		# Back box
		$g->rectangle($l+$depth, $t-$depth, $r+$depth, $b-$depth, $s->{fgci});
		
		# Connecting frame
		$g->line($l, $t, $l + $depth, $t - $depth, $s->{fgci});
		$g->line($r, $t, $r + $depth, $t - $depth, $s->{fgci});
		$g->line($l, $b, $l + $depth, $b - $depth, $s->{fgci});
		$g->line($r, $b, $r + $depth, $b - $depth, $s->{fgci});

		# Axes box
		$g->rectangle($l, $t, $r, $b, $s->{fgci});
	}
	else
	{
		# Y axis
		my $poly = new GD::Polygon;
		$poly->addPt( $l, $t );
		$poly->addPt( $l, $b );
		$poly->addPt( $l + $depth, $b - $depth );
		$poly->addPt( $l + $depth, $t - $depth );
		$g->polygon( $poly, $s->{fgci} );
		
		# X axis
		if( !$s->{zero_axis_only} ) {
			$poly = new GD::Polygon;
			$poly->addPt( $l, $b );
			$poly->addPt( $r, $b );
			$poly->addPt( $r + $depth, $b - $depth );
			$poly->addPt( $l + $depth, $b - $depth );
			$g->polygon( $poly, $s->{fgci} );
		} # end if
		
		# Second Y axis
		if( $s->{two_axes} ){
			$poly = new GD::Polygon;
			$poly->addPt( $r, $b );
			$poly->addPt( $r, $t );
			$poly->addPt( $r + $depth, $t - $depth );
			$poly->addPt( $r + $depth, $b - $depth );
			$g->polygon( $poly, $s->{fgci} );
		} # end if
	}

	if ($s->{zero_axis} or $s->{zero_axis_only})
	{
		my ($x, $y) = $s->val_to_pixel(0, 0, 1);
		my $poly = new GD::Polygon;
		$poly->addPt( $l, $y );
		$poly->addPt( $r, $y );
		$poly->addPt( $r + $depth, $y - $depth );
		$poly->addPt( $l + $depth, $y - $depth);
		$g->polygon( $poly, $s->{fgci} );
	}
}

#
# Ticks and values for y axes
#
sub draw_y_ticks # \@data
{
	my $s = shift;
	my $d = shift;

	my $t;
	foreach $t (0 .. $s->{y_tick_number}) 
	{
		my $a;
		foreach $a (1 .. ($s->{two_axes} + 1)) 
		{
			my $value = $s->{y_values}[$a][$t];
			my $label = $s->{y_labels}[$a][$t];
			
			my ($x, $y) = $s->val_to_pixel(0, $value, $a);
			$x = ($a == 1) ? $s->{left} : $s->{right};

			# CONTRIB Jeremy Wadsack
			# Draw on the back of the extrusion
			$x += $s->{depth_3d};
			$y -= $s->{depth_3d};

			if ($s->{y_long_ticks}) 
			{
				$s->{graph}->line( 
					$x, $y, 
					$x + $s->{right} - $s->{left}, $y, 
					$s->{fgci} 
				) unless ($a-1);
				# CONTRIB Jeremy Wadsack
				# Draw conector ticks
				$s->{graph}->line( 
					$x - $s->{depth_3d}, $y + $s->{depth_3d},
					$x, $y, 
					$s->{fgci} 
				) unless ($a-1);
			} 
			else 
			{
				$s->{graph}->line( 
					$x, $y, 
					$x + (3 - 2 * $a) * $s->{y_tick_length}, $y, 
					$s->{fgci} 
				);
				# CONTRIB Jeremy Wadsack
				# Draw conector ticks
				$s->{graph}->line( 
					$x - $s->{depth_3d}, $y + $s->{depth_3d},
					$x - $s->{depth_3d} + (3 - 2 * $a) * $s->{y_tick_length}, $y + $s->{depth_3d} - (3 - 2 * $a) * $s->{y_tick_length},
					$s->{fgci} 
				);
			}

			next 
				if ( $t % ($s->{y_label_skip}) || ! $s->{y_plot_values} );

			$s->{gdta_y_axis}->set_text($label);
			$s->{gdta_y_axis}->set_align('center', 
				$a == 1 ? 'right' : 'left');
			$x -= (3 - 2 * $a) * $s->{axis_space};
			# CONTRIB Jeremy Wadsack
			# Subtract 3-d extrusion width from left axis label
			# (it was added for ticks)
			$x -= (2 - $a) * $s->{depth_3d};

			# CONTRIB Jeremy Wadsack
			# Add 3-d extrusion height to label
			# (it was subtracted for ticks)
			$y += $s->{depth_3d};
			$s->{gdta_y_axis}->draw($x, $y);
		}
	}
}

#
# Ticks and values for x axes
#
sub draw_x_ticks # \@data
{
	my $s = shift;
	my $d = shift;

	my $i;
	for $i (0 .. $s->{numpoints}) 
	{
		my ($x, $y) = $s->val_to_pixel($i + 1, 0, 1);

		$y = $s->{bottom} unless $s->{zero_axis_only};

		# CONTRIB  Damon Brodie for x_tick_offset
		next if (!$s->{x_all_ticks} and 
				($i - $s->{x_tick_offset}) % $s->{x_label_skip} and 
				$i != $s->{numpoints} 
			);

		# CONTRIB Jeremy Wadsack
		# Draw on the back of the extrusion
		$x += $s->{depth_3d};
		$y -= $s->{depth_3d};

		if ($s->{x_ticks})
		{

			if ($s->{x_long_ticks})
			{
				# CONTRIB Jeremy Wadsack
				# Move up by 3d depth
				$s->{graph}->line($x, $s->{bottom} - $s->{depth_3d}, $x, $s->{top} - $s->{depth_3d},
					$s->{fgci});
				# CONTRIB Jeremy Wadsack
				# Draw conector ticks
				$s->{graph}->line( 
					$x - $s->{depth_3d}, $y + $s->{depth_3d},
					$x, $y, 
					$s->{fgci} 
				);
			}
			else
			{
				$s->{graph}->line($x, $y, $x, $y - $s->{x_tick_length},
					$s->{fgci});
				# CONTRIB Jeremy Wadsack
				# Draw conector ticks
				$s->{graph}->line( 
					$x - $s->{depth_3d}, $y + $s->{depth_3d},
					$x - $s->{depth_3d} + $s->{x_tick_length}, $y + $s->{depth_3d} - $s->{x_tick_length},
					$s->{fgci} 
				);
			}
		}

		# CONTRIB Damon Brodie for x_tick_offset
		next if 
			($i - $s->{x_tick_offset}) % ($s->{x_label_skip}) and 
			$i != $s->{numpoints};

		$s->{gdta_x_axis}->set_text($d->[0][$i]);

		# CONTRIB Jeremy Wadsack
		# Subtract 3-d extrusion width from left label
		# Add 3-d extrusion height to left label
		# (they were changed for ticks)
		$x -= $s->{depth_3d};
		$y += $s->{depth_3d};

		my $yt = $y + $s->{axis_space};

		if ($s->{x_labels_vertical})
		{
			$s->{gdta_x_axis}->set_align('center', 'right');
			$s->{gdta_x_axis}->draw($x, $yt, PI/2);
		}
		else
		{
			$s->{gdta_x_axis}->set_align('top', 'center');
			$s->{gdta_x_axis}->draw($x, $yt);
		}
	}
}


# CONTRIB Scott Prahl
# Assume x array contains equally spaced x-values
# and generate an appropriate axis
#
sub draw_x_ticks_number # \@data
{
	my $s = shift;
	my $d = shift;

	my $i;
	for $i (0 .. $s->{x_tick_number})
	{
		my $value = $s->{numpoints}
					* ($s->{x_values}[$i] - $s->{true_x_min})
					/ ($s->{true_x_max} - $s->{true_x_min});

		my $label = $s->{x_labels}[$i];

		my ($x, $y) = $s->val_to_pixel($value + 1, 0, 1);

		$y = $s->{bottom} unless $s->{zero_axis_only};

		if ($s->{x_ticks})
		{
			if ($s->{x_long_ticks})
			{
				$s->{graph}->line($x, $s->{bottom}, 
					$x, $s->{top},$s->{fgci});
				# CONTRIB Jeremy Wadsack
				# Draw conector ticks
				$s->{graph}->line( 
					$x - $s->{depth_3d}, $y + $s->{depth_3d},
					$x, $y, 
					$s->{fgci} 
				);
			}
			else
			{
				$s->{graph}->line( $x, $y, 
					$x, $y - $s->{x_tick_length}, $s->{fgci} );
				# CONTRIB Jeremy Wadsack
				# Draw conector ticks
				$s->{graph}->line( 
					$x - $s->{depth_3d}, $y + $s->{depth_3d},
					$x - $s->{depth_3d} + $s->{tick_length}, $y + $s->{depth_3d} - $s->{tick_length},
					$s->{fgci} 
				);
			}
		}

		next
			if ( $i%($s->{x_label_skip}) and $i != $s->{x_tick_number} );

		$s->{gdta_x_axis}->set_text($label);

		# CONTRIB Jeremy Wadsack
		# Subtract 3-d extrusion width from left label
		# Add 3-d extrusion height to left label
		# (they were changed for ticks)
		$x -= $s->{depth_3d};
		$y += $s->{depth_3d};

		if ($s->{x_labels_vertical})
		{
			$s->{gdta_x_axis}->set_align('center', 'right');
			my $yt = $y + $s->{text_space}/2;
			$s->{gdta_x_axis}->draw($x, $yt, PI/2);
		}
		else
		{
			$s->{gdta_x_axis}->set_align('top', 'center');
			my $yt = $y + $s->{text_space}/2;
			$s->{gdta_x_axis}->draw($x, $yt);
		}
	}
}

# Inherit draw_ticks
# Inherit draw_data
# Inherit draw_data_set
# Inherit set_max_min
# Inherit get_max_y
# Inherit get_min_y
# Inherit get_max_min_y_all
# Inherit _best_ends 
# Inherit val_to_pixel
# Inherit setup_legend
# Inherit draw_legend
# Inherit draw_legend_marker

1;
