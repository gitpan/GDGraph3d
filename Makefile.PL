use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	'NAME'	=> 'GD::Graph',
	'VERSION_FROM' => 'lib/GD/Graph/axestype3d.pm', # finds $VERSION
	'DISTNAME' => 'GD-Graph3d',

	($] >= 5.005 ?
		('ABSTRACT'		=> 'Creates 3D charts with GD::Graph and GD.',
		 'AUTHOR'		=> 'Jeremy Wadsack <dgsupport@wadsack-allen.com>',
		) : ()
	),

	'PREREQ_PM'			=> { 
	'GD' => '1.18', 
	'GD::Text::Align' => undef,
	},

	'dist'    			=> {
	'COMPRESS' 		=> 'gzip -9f',
	'SUFFIX'   		=> 'gz', 
	},

	'clean'   => { 'FILES' => join(" ", @clean), },

);
