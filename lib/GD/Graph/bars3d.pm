#==========================================================================
# Module: GD::Graph::bars3d
#
# Copyright (C) 1999,2000 Wadsack-Allen. All Rights Reserved.
#
# Based on GD::Graph::bars.pm,v 1.16 2000/03/18 10:58:39 mgjv
#          Copyright (c) 1995-1998 Martien Verbruggen
#
#--------------------------------------------------------------------------
# Date      Modification                                             Author
# -------------------------------------------------------------------------
# 1999SEP18 Created 3D bar chart class (this module)                    JAW
# 1999SEP19 Rewrote to include a single bar-drawing                     JAW
#           function and process all bars in series
# 1999SEP19 Implemented support for overwrite 2 style                   JAW
# 1999SEP19 Fixed a bug in color cycler (colors were off by 1)          JAW
# 2000JAN19 Converted to GD::Graph class                                JAW
# 2000MAR10 Fixed bug where bars ran off bottom of chart                JAW
# 2000APR18 Modified to be compatible with GD::Graph 1.30               JAW
#==========================================================================
package GD::Graph::bars3d;

use strict;

use GD::Graph::axestype3d;
use GD::Graph::utils qw(:all);
use GD::Graph::colour qw(:colours);

@GD::Graph::bars3d::ISA = qw(GD::Graph::axestype3d);
$GD::Graph::bars3d::VERSION = '0.40';

my %Defaults = (
	# Spacing between the bars
	bar_spacing 	=> 0,
	
	# The 3-d extrusion depth of the bars
	bar_depth => 10,
);

sub initialise
{
	my $self = shift;

	my $rc = $self->SUPER::initialise();

	while( my($key, $val) = each %Defaults ) { 
		$self->{$key} = $val 
	} # end while

	return $rc;
} # end initialise

sub set
{
	my $s = shift;
	my %args = @_;

	$s->{_set_error} = 0;

	for (keys %args) 
	{ 
		/^bar_depth$/ and do 
		{
			$s->{bar_depth} = $args{$_};
			delete $args{$_};
			next;
		};
	}

	return $s->SUPER::set(%args);
}


# CONTRIB Jeremy Wadsack
# This is a complete overhaul of the original GD::Graph::bars
# design, because all versions (overwrite = 0, 1, 2) 
# require that the bars be drawn in a loop of point over sets
sub draw_data
{
	my $self = shift;
	my $g = $self->{graph};

	my $bar_s = _round($self->{bar_spacing}/2);

	my $zero = $self->{zeropoint};

	my $i;
	for $i (0 .. $self->{_data}->num_points()) 
	{
		my ($xp, $t);
		my $overwrite = 0;
		$overwrite = $self->{overwrite} if defined $self->{overwrite};
		
		my $j;
		for $j (1 .. $self->{_data}->num_sets()) 
		{
			my $value = $self->{_data}->get_y( $j, $i );
			next unless defined $value;

			my $bottom = $self->_get_bottom($j, $i);
	
			$value = $self->{_data}->get_y_cumulative($j, $i)
				if ($self->{cumulate});

			# Pick a data colour
			my $dsci = $self->set_clr($self->pick_data_clr($j));

			# contrib "Bremford, Mike" <mike.bremford@gs.com>
			my $brci = $self->set_clr($self->pick_border_clr($j));

			# cycle_clrs option sets the color based on the point, 
			# not the dataset.
			$dsci = $self->set_clr($self->pick_data_clr($i + 1))
				if $self->{cycle_clrs};
			$brci = $self->set_clr($self->pick_data_clr($i + 1))
				if $self->{cycle_clrs} > 1;


			# If two axes and on second set, adjust zero point
			if( $self->{two_axes} ) {
				(undef, $bottom) = $self->val_to_pixel(1, 0, $j);
			} # end if

			# get coordinates of top and center of bar
			($xp, $t) = $self->val_to_pixel($i + 1, $value, $j);

			# calculate offsets of this bar
			my $x_offset = 0;
			my $y_offset = 0;
			if( $overwrite == 1 ) {
				$x_offset = $self->{bar_depth} * ($self->{numsets} - $j);
				$y_offset = $self->{bar_depth} * ($self->{numsets} - $j);
			}
			$t -= $y_offset;


			# calculate left and right of bar
			my ($l, $r);
			if( (ref $self eq 'GD::Graph::mixed') || ($overwrite >= 1) )
			{
				$l = $xp - _round($self->{x_step}/2) + $bar_s + $x_offset;
				$r = $xp + _round($self->{x_step}/2) - $bar_s + $x_offset;
			}
			else
			{
				$l = $xp 
					- _round($self->{x_step}/2)
					+ _round(($j - 1) * $self->{x_step}/$self->{_data}->num_sets())
					+ $bar_s + $x_offset;
				$r = $xp 
					- _round($self->{x_step}/2)
					+ _round($j * $self->{x_step}/$self->{_data}->num_sets())
					- $bar_s + $x_offset;
			}

			# calculate new top
			$t -= ($zero - $bottom) if ($self->{overwrite} == 2);

			if ($value >= 0)
			{
				# draw the positive bar
				$self->draw_bar( $g, $l, $t, $r, $bottom-$y_offset, $dsci, $brci, 0 )
			}
			else
			{
				# draw the negative bar
				$self->draw_bar( $g, $l, $bottom-$y_offset, $r, $t, $dsci, $brci, -1 )
			}

			# reset $bottom to the top
			$bottom = $t if ($self->{overwrite} == 2);
		}
	}


	# redraw the 'zero' axis, front and right
	if( $self->{zero_axis} ) {
		$g->line( 
			$self->{left}, $self->{zeropoint}, 
			$self->{right}, $self->{zeropoint}, 
			$self->{fgci} );
		$g->line( 
			$self->{right}, $self->{zeropoint}, 
			$self->{right}+$self->{depth_3d}, $self->{zeropoint}-$self->{depth_3d}, 
			$self->{fgci} );
	} # end if

	# redraw the box face
	if ( $self->{box_axis} ) {
		# Axes box
		$g->rectangle($self->{left}, $self->{top}, $self->{right}, $self->{bottom}, $self->{fgci});
		$g->line($self->{right}, $self->{top}, $self->{right} + $self->{depth_3d}, $self->{top} - $self->{depth_3d}, $self->{fgci});
		$g->line($self->{right}, $self->{bottom}, $self->{right} + $self->{depth_3d}, $self->{bottom} - $self->{depth_3d}, $self->{fgci});
	} # end if

	return $self;
	
} # end draw_data

# CONTRIB Jeremy Wadsack
# This function draws a bar at the given 
# coordinates. This is called in all three 
# overwrite modes.
sub draw_bar {
	my $self = shift;
	my $g = shift;
	my( $l, $t, $r, $b, $dsci, $brci, $neg ) = @_;
	
	# get depth of the bar
	my $depth = $self->{bar_depth};

	# get the bar shadow depth and color
	my $bsd = $self->{shadow_depth};
	my $bsci = $self->set_clr(_rgb($self->{shadowclr}));

	my( $xi );

	# shadow
	if( $bsd > 0 ) {
		my $sb = $b - $depth;
		my $st = $t - $depth + $bsd;
		
		if( $neg != 0 ) {
			$st -= $bsd;
			if( $self->{zero_axis_only} ) {
				$sb += $bsd;
			} else {
				$sb = _min($b-$depth+$bsd, $self->{bottom}-$depth);
			} # end if
		} # end if

		# ** If this isn't the back bar, then no side shadow should be 
		#    drawn or else the top should be lowered by 
		#    ($bsd * dataset_num), it should be drawn on the back surface, 
		#    and a shadow should be drawn behind the front bar if the 
		#    bar is positive and the back is negative.
		
		$g->filledRectangle($l+$depth+$bsd,
		                    $st,
		                    $r+$depth+$bsd,
		                    $sb,
		                    $bsci);

		# Only draw bottom shadow if at the bottom and has bottom 
		# axis. Always draw top shadow
		if( ($neg == 0) || ($sb >= $self->{bottom}-$depth) ) {
			my $poly = new GD::Polygon;
			$poly->addPt( $r, $b );
			$poly->addPt( $r+$bsd, $b );
			$poly->addPt( $r+$depth+$bsd, $b-$depth );
			$poly->addPt( $r+$depth, $b-$depth );
			$g->filledPolygon( $poly, $bsci );
		} # end if

	} # end if


	# side
	my $poly = new GD::Polygon;
	$poly->addPt( $r, $t );
	$poly->addPt( $r+$depth, $t-$depth );
	$poly->addPt( $r+$depth, $b-$depth );
	$poly->addPt( $r, $b );
	$g->filledPolygon( $poly, $dsci );
	$g->polygon( $poly, $brci );

	# top
	#	-- only draw negative tops if the bar starts at zero
	if( ($neg == 0) || ($t <= $self->{zeropoint}) ) {
		$poly = new GD::Polygon;
		$poly->addPt( $l, $t );
		$poly->addPt( $l+$depth, $t-$depth );
		$poly->addPt( $r+$depth, $t-$depth );
		$poly->addPt( $r, $t );
		$g->filledPolygon( $poly, $dsci );
		$g->polygon( $poly, $brci );
	} # end if

	# face
	$g->filledRectangle( $l, $t, $r, $b, $dsci );
	$g->rectangle( $l, $t, $r, $b, $brci );

} # end draw_bar

1;
