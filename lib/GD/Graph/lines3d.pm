#==========================================================================
# Module: GD::Graph::lines3d
#
# Copyright (C) 1999,2000 Wadsack-Allen. All Rights Reserved.
#
# Based on GD::Graph::lines.pm,v 1.10 2000/04/15 mgjv
#          Copyright (c) 1995-1998 Martien Verbruggen
#
#--------------------------------------------------------------------------
# Date		Modification				                                 Author
# -------------------------------------------------------------------------
# 1999SEP18 Created 3D line chart class (this module)                   JAW
# 1999SEP19 Finished overwrite 1 style                                  JAW
# 1999SEP19 Polygon'd linewidth rendering                               JAW
# 2000SEP19 Converted to a GD::Graph class                              JAW
# 2000APR18 Modified for compatibility with GD::Graph 1.30              JAW
#==========================================================================
# TODO
#		* Write a draw_data_set that draws the line so they appear to pass 
#		  through one another. This means drawing a border edge at each 
#		  intersection of the data lines so the points of pass through show.
#		  Probably want to draw all polygons, then run through the data again 
#		  finding intersections of line segments and drawing those edges.
#==========================================================================
package GD::Graph::lines3d;

use strict;
 
use GD;
use GD::Graph::axestype3d;

@GD::Graph::lines3d::ISA = qw( GD::Graph::axestype3d );
$GD::Graph::lines3d::VERSION = '0.40';

my %Defaults = (
	# The depth of the line in their extrusion

	line_depth		=> 10,
);

sub initialise()
{
	my $self = shift;

	my $rc = $self->SUPER::initialise();

	while( my($key, $val) = each %Defaults ) { 
		$self->{$key} = $val 

		# *** [JAW]
		# Should we reset the depth_3d param based on the 
		# line_depth, numsets and overwrite parameters, here?
		#
	} # end while
	
	return $rc;
	
} # end initialize

sub set
{
	my $s = shift;
	my %args = @_;

	$s->{_set_error} = 0;

	for (keys %args) 
	{ 
		/^line_depth$/ and do 
		{
			$s->{line_depth} = $args{$_};
			delete $args{$_};
			next;
		};
	}

	return $s->SUPER::set(%args);
} # end set

# PRIVATE

# [JAW] Changed to draw_data intead of 
# draw_data_set to allow better control 
# of multiple set rendering
sub draw_data
{
	my $self = shift;
	my $d = $self->{_data};
	my $g = $self->{graph};

	$self->draw_data_overwrite( $g, $d );

	# redraw the 'zero' axis, front and right
	if( $self->{zero_axis} ) {
		$g->line( 
			$self->{left}, $self->{zeropoint}, 
			$self->{right}, $self->{zeropoint}, 
			$self->{fgci} );
		$g->line( 
			$self->{right}, $self->{zeropoint}, 
			$self->{right} + $self->{depth_3d}, $self->{zeropoint} - $self->{depth_3d}, 
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

# Copied from MVERB source
sub pick_line_type
{
	my $self = shift;
	my $num = shift;

	ref $self->{line_types} ?
		$self->{line_types}[ $num % (1 + $#{$self->{line_types}}) - 1 ] :
		$num % 4 ? $num % 4 : 4
}

# CONTRIB Jeremy Wadsack
# Added this for overwrite support. Later can 
# do non-overwrite support
sub draw_data_overwrite {
	my $self = shift;
	my $g = shift;
	my $d = shift;

	my $i;
	for $i (1 .. $self->{_data}->num_points()) 
	{
		my $j;
		for $j (1 .. $self->{_data}->num_sets()) 
		{
			my @values = $self->{_data}->y_values($j) or
				return $self->_set_error("Impossible illegal data set: $j",
					$self->{_data}->error);

			next unless defined $values[$i];

			# calculate offset of this line
			# *** Should offset be the max of line_depth 
			#     and depth_3d/numsets? [JAW]
			#
			my $offset = $self->{line_depth} * ($self->{_data}->num_sets() - $j);

			# get the color and type
			my $dsci = $self->set_clr( $self->pick_data_clr($j) );
			my $type = $self->pick_line_type($j);
			
			# get the coordinates
			my ($xb, $yb) = (undef, undef);
			if (defined $values[$i - 1])
			{
				if (defined($self->{x_min_value}) && defined($self->{x_max_value}))
				{
					($xb, $yb) =
						$self->val_to_pixel($self->{_data}->get_x($i - 1), $values[$i - 1], $j);
				}
				else	
				{
					($xb, $yb) = $self->val_to_pixel($i, $values[$i - 1], $j);
				}
			}

			if( defined $xb ) {
				$xb += $offset;
				$yb -= $offset;

				my ($xe, $ye);
				
				if (defined($self->{x_min_value}) && defined($self->{x_max_value}))
				{
					($xe, $ye) = $self->val_to_pixel(
						$self->{_data}->get_x($i), $values[$i], $j);
				}
				else
				{
					($xe, $ye) = $self->val_to_pixel($i+1, $values[$i], $j);
				}
				$xe += $offset;
				$ye -= $offset;

				# draw the line segment
				$self->draw_line( $xb, $yb, $xe, $ye, $type, $dsci ) 
					if defined $xb;
				
				# draw the end caps
				if( $i == $self->{_data}->num_points() - 1 ) {
					my $poly = new GD::Polygon;
					my $lwh = $self->{line_width} / 2;
					$poly->addPt( $xe, $ye - $lwh );
					$poly->addPt( $xe, $ye + $lwh );
					$poly->addPt( $xe + $self->{line_depth}, $ye + $lwh - $self->{line_depth} );
					$poly->addPt( $xe + $self->{line_depth}, $ye - $lwh - $self->{line_depth} );
					$g->filledPolygon( $poly, $dsci );
					$g->polygon( $poly, $self->{fgci} );
				} # end if

			} # end if
		} # end for -- $self->{_data}->num_sets()
	} # end for -- $self->{_data}->num_points()

} # end sub draw_data_overwrite

# [JAW] Modified to work on data point, not data set
# for better rendering results.
# Based on MVERB source
sub draw_line # ($xs, $ys, $xe, $ye, $type, $colour_index)
{
	my $self = shift;
	my ($xs, $ys, $xe, $ye, $type, $clr) = @_;

	my $lw = $self->{line_width};
	my $lts = $self->{line_type_scale};

	my $style = gdStyled;
	my @pattern = ();

	LINE: {

		($type == 2) && do {
			# dashed

			for (1 .. $lts) { push @pattern, $clr }
			for (1 .. $lts) { push @pattern, gdTransparent }

			$self->{graph}->setStyle(@pattern);

			last LINE;
		};

		($type == 3) && do {
			# dotted,

			for (1 .. 2) { push @pattern, $clr }
			for (1 .. 2) { push @pattern, gdTransparent }

			$self->{graph}->setStyle(@pattern);

			last LINE;
		};

		($type == 4) && do {
			# dashed and dotted

			for (1 .. $lts) { push @pattern, $clr }
			for (1 .. 2) 	{ push @pattern, gdTransparent }
			for (1 .. 2) 	{ push @pattern, $clr }
			for (1 .. 2) 	{ push @pattern, gdTransparent }

			$self->{graph}->setStyle(@pattern);

			last LINE;
		};

		# default: solid
		$style = $clr;
	}

	# [JAW] Removed the dataset loop for better results.

	# Need the setstyle to reset 
	$self->{graph}->setStyle(@pattern) if (@pattern);

	# CONTRIB Jeremy Wadsack
	# *** This paints dashed and dotted patterns on the faces of
	#     the polygons. They don't look very good though. Would it
	#     be better to extrude the style as well as the lines?
	#     Otherwise could also be improved by using gdTiled instead of 
	#     gdStyled and making the tile a transform of the line style
	#     for each face.
	
	# make the top/bottom polygon
	my $poly = new GD::Polygon;
	my $lwoff = $lw/2;
	if( ($ys-$ye)/($xe-$xs) > 1 ) {
		$lwoff = -$lwoff;
	} # end if
	$poly->addPt( $xs, $ys - $lwoff );
	$poly->addPt( $xe, $ye - $lwoff );
	$poly->addPt( $xe + $self->{line_depth}, $ye - $lwoff - $self->{line_depth} );
	$poly->addPt( $xs + $self->{line_depth}, $ys - $lwoff - $self->{line_depth} );

	$self->{graph}->filledPolygon( $poly, $style );
	$self->{graph}->polygon( $poly, $self->{fgci} );

	# make the face polygon
	$poly = new GD::Polygon;
	$poly->addPt( $xs, $ys - ($lw/2) );
	$poly->addPt( $xe, $ye - ($lw/2) );
	$poly->addPt( $xe, $ye + ($lw/2) );
	$poly->addPt( $xs, $ys + ($lw/2) );
	$self->{graph}->filledPolygon( $poly, $style );
	$self->{graph}->polygon( $poly, $self->{fgci} );
} # end draw line

# Copied from MVERB source
sub draw_legend_marker # (data_set_number, x, y)
{
	my $self = shift;
	my ($n, $x, $y) = @_;

	my $ci = $self->set_clr($self->pick_data_clr($n));
	my $type = $self->pick_line_type($n);

	$y += int($self->{lg_el_height}/2);

	#  Joe Smith <jms@tardis.Tymnet.COM>
	local($self->{line_width}) = 2;    # Make these show up better

	$self->draw_line(
		$x, $y, 
		$x + $self->{legend_marker_width}, $y,
		$type, $ci
	);
}

1;