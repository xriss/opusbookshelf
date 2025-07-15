# opusbookshelf

Simpleish bash script to download and batch convert audio book files 
from audible into opus for use as an audiobookshelf library.


The following steps will let you opus your audible library into 
something that audiobookshelf will accept.

Clone this repo and cd into it

	git clone https://github.com/xriss/opusbookshelf.git
	cd opusbookshelf

Create a local configuration file

	./opusbookshelf.sh save
	
Edit the config file as you see fit, if you do not change anything we 
will download and convert into sub directories.

Login to audible

	./opusbookshelf.sh save

You must answer all the riddle correctly to get past this step, we are 
just running audible-cli using uvx like so "uvx --from audible-cli 
audible" so you can try rawdoging that instead. For me the "login with 
external browser?" worked, so I recomend saying yes to that.

Download from audible

	./opusbookshelf.sh audible
	
This will of course take some time and you might want to rawdog 
audible-cli instead.

Convert audible files to opus

	./opusbookshelf.sh opus

This should just work with any audio files that have reasonable tags, 
so the input files could be sourced from anywhere not just audible. If 
it does not try to convert an audio file then it is probably missing 
tags.

Check the file with exiftool and make sure it has an Artist and an 
Album tag set as we use/require these to build the output directory 
structure that audiobookshelf expects. No tags, no output.
