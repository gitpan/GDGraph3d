#==========================================================================
# Module: GIFgraph::lines3d
#
# Copyright (C) 1999,2000 Wadsack-Allen. All Rights Reserved.
#
# Based on GD::Graph::lines.pm,v 1.5 2000/01/07 13:44:42 mgjv
#          Copyright (c) 1995-1998 Martien Verbruggen
#
#--------------------------------------------------------------------------
# Date		Modification				                  Author
# -------------------------------------------------------------------------
# 1999SEP18 Created 3D line chart class (this module) JAW
# 1999SEP19 Finished overwrite 1 style                JAW
# 1999SEP19 Polygon'd linewidth rendering             JAW
# 2000SEP19 Converted to a GD::Graph class            JAW
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
$GD::Graph::lines3d::VERSION = '0.33';

my %Defaults = (
	# The depth of the line in their extrusion

	line_depth		=> 10,
);

sub initialise()
{
	my $self = shift;

	$self->SUPER::initialise();

	my $key;
	foreach $key (keys %Defaults)
	{
		$self->set( $key => $Defaults{$key} );
		
		# *** [JAW]
		# Should we reset the depth_3d param based on the 
		# line_depth, numsets and overwrite parameters, here?
		#
	}
}

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
}

# PRIVATE

# [JAW] Changed to draw_data intead of 
# draw_data_set to allow better control 
# of multiple set rendering
sub draw_data # GD::Image, \@data
{
	my $s = shift;
	my $d = shift;
	my $g = $s->{graph};

	$s->draw_data_overwrite( $g, $d );

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

sub pick_line_type
{
	my $s = shift;
	my $num = shift;

	ref $s->{line_types} ?
		$s->{line_types}[ $num % (1 + $#{$s->{line_types}}) - 1 ] :
		$num % 4 ? $num % 4 : 4
}

# CONTRIB Jeremy Wadsack
# Added this for overwrite support. Later can 
# do non-overwrite support
sub draw_data_overwrite {
	my $s = shift;
	my $g = shift;
	my $d = shift;

	my $i;
	for $i (1 .. $s->{numpoints}) 
	{
		my $j;
		for $j (1 .. $s->{numsets}) 
		{
			next unless (defined $d->[$j][$i]);
			# calculate offset of this line
			# *** Should offset be the max of line_depth 
			#     and depth_3d/numsets? [JAW]
			#
			my $offset = $s->{line_depth} * ($s->{numsets} - $j);

			# get the color and type
			my $dsci = $s->set_clr( $s->pick_data_clr($j) );
			my $type = $s->pick_line_type($j);
			
			# get the coordinates
			my ($xb, $yb) = (defined $d->[$j][$i-1]) ?
				$s->val_to_pixel( $i, $d->[$j][$i-1], $j) :
				(undef, undef);

			if( defined $xb ) {
				$xb += $offset;
				$yb -= $offset;

				my ($xe, $ye) = $s->val_to_pixel($i+1, $d->[$j][$i], $j);
				$xe += $offset;
				$ye -= $offset;

				# draw the line segment
				$s->draw_line( $xb, $yb, $xe, $ye, $type, $dsci ) 
					if defined $xb;
				
				if( $i == $s->{numpoints} ) {
					# draw the end caps
					my $poly = new GD::Polygon;
					my $lwh = $s->{line_width} / 2;
					$poly->addPt( $xe, $ye - $lwh );
					$poly->addPt( $xe, $ye + $lwh );
					$poly->addPt( $xe + $s->{line_depth}, $ye + $lwh - $s->{line_depth} );
					$poly->addPt( $xe + $s->{line_depth}, $ye - $lwh - $s->{line_depth} );
					$g->filledPolygon( $poly, $dsci );
					$g->polygon( $poly, $s->{fgci} );
				} # end if
			} # end if
		} # end for (numsets)
   }

} # end sub draw_data_overwrite

sub draw_line # ($xs, $ys, $xe, $ye, $type, $colour_index)
{
	my $s = shift;
	my ($xs, $ys, $xe, $ye, $type, $clr) = @_;
	my $g = $s->{graph};

	my $lw = $s->{line_width};
	my $lts = $s->{line_type_scale};

	my $style = gdStyled;
	my @pattern = ();

	LINE: {

		($type == 2) && do {
			# dashed

			for (1 .. $lts) { push(@pattern, $clr) }
			for (1 .. $lts) { push(@pattern, gdTransparent) }

			$g->setStyle(@pattern);

			last LINE;
		};

		($type == 3) && do {
			# dotted,

			for (1 .. 2) { push(@pattern, $clr) }
			for (1 .. 2) { push(@pattern, gdTransparent) }

			$g->setStyle(@pattern);

			last LINE;
		};

		($type == 4) && do {
			# dashed and dotted

			for (1 .. $lts) { push(@pattern, $clr) }
			for (1 .. 2) 	{ push(@pattern, gdTransparent) }
			for (1 .. 2) 	{ push(@pattern, $clr) }
			for (1 .. 2) 	{ push(@pattern, gdTransparent) }

			$g->setStyle(@pattern);

			last LINE;
		};

		# default: solid
		$style = $clr;
	}

	# [JAW] Removed the dataset loop for better results.

	# Need the setstyle to reset 
	$g->setStyle(@pattern) if (@pattern);

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
	$poly->addPt( $xe + $s->{line_depth}, $ye - $lwoff - $s->{line_depth} );
	$poly->addPt( $xs + $s->{line_depth}, $ys - $lwoff - $s->{line_depth} );

	$g->filledPolygon( $poly, $style );
	$g->polygon( $poly, $s->{fgci} );

	# make the face polygon
	$poly = new GD::Polygon;
	$poly->addPt( $xs, $ys - ($lw/2) );
	$poly->addPt( $xe, $ye - ($lw/2) );
	$poly->addPt( $xe, $ye + ($lw/2) );
	$poly->addPt( $xs, $ys + ($lw/2) );
	$g->filledPolygon( $poly, $style );
	$g->polygon( $poly, $s->{fgci} );
}

sub draw_legend_marker # (data_set_number, x, y)
{
	my $s = shift;
	my $n = shift;
	my $x = shift;
	my $y = shift;

	my $ci = $s->set_clr($s->pick_data_clr($n));
	my $type = $s->pick_line_type($n);

	$y += int($s->{lg_el_height}/2);

	#  Joe Smith <jms@tardis.Tymnet.COM>
	local($s->{line_width}) = 2;    # Make these show up better

	$s->draw_line(
		$x, $y, 
		$x + $s->{legend_marker_width}, $y,
		$type, $ci
	);
}

1;
