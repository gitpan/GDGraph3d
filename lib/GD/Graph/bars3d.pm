#==========================================================================
# Module: GIFgraph::bars3d
#
# Copyright (C) 1999,2000 Wadsack-Allen. All Rights Reserved.
#
# Based on GD::Graph::bars.pm,v 1.5 2000/01/07 13:44:42 mgjv
#          Copyright (c) 1995-1998 Martien Verbruggen
#
#--------------------------------------------------------------------------
# Date      Modification                                            Author
# -------------------------------------------------------------------------
# 1999SEP18 Created 3D bar chart class (this module)                JAW
# 1999SEP19 Rewrote to include a single bar-drawing                 JAW
#           function and process all bars in series
# 1999SEP19 Implemented support for overwrite 2 style               JAW
# 1999SEP19 Fixed a bug in color cycler (colors were off by 1)      JAW
# 2000JAN19 Converted to GD::Graph class                            JAW
#==========================================================================
package GD::Graph::bars3d;

use strict;

use GD::Graph::axestype3d;
use GD::Graph::utils qw(:all);
use GD::Graph::colour qw(:colours);

@GD::Graph::bars3d::ISA = qw(GD::Graph::axestype3d);
$GD::Graph::bars3d::VERSION = '0.32';

my %Defaults = (
	# Spacing between the bars
	bar_spacing 	=> 0,
	
	# The 3-d extrusion depth of the bars
	bar_depth => 10,
);

sub initialise()
{
	my $self = shift;

	$self->SUPER::initialise();

	my $key;
	foreach $key (keys %Defaults)
	{
		$self->set( $key => $Defaults{$key} );
	}
}

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
# This is a complete overhaul of the original GD::Graph
# bars design, because all versions (overwrite = 0, 1, 2) 
# require that the bars be drawn in a loop of point over sets
sub draw_data
{
	my $s = shift;
	my $d = shift;
	my $g = $s->{graph};

	my $bar_s = _round($s->{bar_spacing}/2);

	my $zero = $s->{zeropoint};

	my $i;
	for $i (0 .. $s->{numpoints}) 
	{
		my $bottom = $zero;
		my ($xp, $t);
		my $overwrite = 0;
		$overwrite = $s->{overwrite} if defined $s->{overwrite};
		
		my $j;
		for $j (1 .. $s->{numsets}) 
		{
			next unless (defined $d->[$j][$i]);

			# get data colour
			my $dsci = $s->set_clr( $s->pick_data_clr($j) );
			
			# contrib "Bremford, Mike" <mike.bremford@gs.com>
			my $brci = $s->set_clr( $s->pick_border_clr($j) );

			# cycle_clrs option sets the color based on the point, 
			# not the dataset.
			if( $s->{cycle_clrs} == 1 ) {
				$dsci = $s->set_clr( $s->pick_data_clr($i + 1) );
				$brci = $s->set_clr( $s->pick_border_clr( $i + 1 ) );
			} # end if


			# If two axes and on second set, adjust zero point
			if( $s->{two_axes} ) {
				(undef, $bottom) = $s->val_to_pixel(1, 0, $j);
			} # end if

			# get coordinates of top and center of bar
			($xp, $t) = $s->val_to_pixel($i + 1, $d->[$j][$i], $j);

			# calculate offsets of this bar
			my $x_offset = 0;
			my $y_offset = 0;
			if( $overwrite == 1 ) {
				$x_offset = $s->{bar_depth} * ($s->{numsets} - $j);
				$y_offset = $s->{bar_depth} * ($s->{numsets} - $j);
			}
			$t -= $y_offset;


			# calculate left and right of bar
			my ($l, $r);
			if( ($s->{mixed}) || ($overwrite >= 1) )
			{
				$l = $xp - _round($s->{x_step}/2) + $bar_s + $x_offset;
				$r = $xp + _round($s->{x_step}/2) - $bar_s + $x_offset;
			}
			else
			{
				$l = $xp 
					- _round($s->{x_step}/2)
					+ _round(($j - 1) * $s->{x_step}/$s->{numsets})
					+ $bar_s + $x_offset;
				$r = $xp 
					- _round($s->{x_step}/2)
					+ _round($j * $s->{x_step}/$s->{numsets})
					- $bar_s + $x_offset;
			}

			# calculate new top
			$t -= ($zero - $bottom) if ($s->{overwrite} == 2);

			if ($d->[$j][$i] >= 0)
			{
				# draw the positive bar
				$s->draw_bar( $g, $l, $t, $r, $bottom-$y_offset, $dsci, $brci, 0 )
			}
			else
			{
				# draw the negative bar
				$s->draw_bar( $g, $l, $bottom-$y_offset, $r, $t, $dsci, $brci, -1 )
			}

			# reset $bottom to the top
			$bottom = $t if ($s->{overwrite} == 2);
		}
	}


	# redraw the 'zero' axis, front and right
	if( $s->{zero_axis} ) {
		$g->line( 
			$s->{left}, $s->{zeropoint}, 
			$s->{right}, $s->{zeropoint}, 
			$s->{fgci} );
		$g->line( 
			$s->{right}, $s->{zeropoint}, 
			$s->{right}+$s->{depth_3d}, $s->{zeropoint}-$s->{depth_3d}, 
			$s->{fgci} );
	} # end if

	# redraw the box face
	if ( $s->{box_axis} ) {
		# Axes box
		$g->rectangle($s->{left}, $s->{top}, $s->{right}, $s->{bottom}, $s->{fgci});
	} # end if

} # end draw_data

# CONTRIB Jeremy Wadsack
# This function draws a bar at the given 
# coordinates. This is called in all three 
# overwrite modes.
sub draw_bar {
	my $s = shift;
	my $g = shift;
	my( $l, $t, $r, $b, $dsci, $brci, $neg ) = @_;
	
	# get depth of the bar
	my $depth = $s->{bar_depth};

	# get the bar shadow depth and color
	my $bsd = $s->{shadow_depth};
	my $bsci = $s->set_clr(_rgb($s->{shadowclr}));

	my( $xi );

	# shadow
	if( $bsd > 0 ) {
		my $sb = $b - $depth;
		my $st = $t - $depth + $bsd;
		
		if( $neg != 0 ) {
			$st -= $bsd;
			if( $s->{zero_axis_only} ) {
				$sb += $bsd;
			} else {
				$sb = _min($b-$depth+$bsd, $s->{bottom}-$depth);
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
		if( ($neg == 0) || ($sb >= $s->{bottom}-$depth) ) {
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
	if( ($neg == 0) || ($t <= $s->{zeropoint}) ) {
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