#!/usr/bin/env bash

# first install a require script that should work on multiple flavors of linux
if ! [[ -x "$(command -v require.sh)" ]] ; then

	echo " we need sudo to install require.sh to /usr/local/bin from https://github.com/xriss/require.sh "
	echo " if this scares you then add a dummy require.sh and provide the dependencies yourself "
	sudo wget -O /usr/local/bin/require.sh https://raw.githubusercontent.com/xriss/require.sh/main/require.sh
	sudo chmod +x /usr/local/bin/require.sh

fi
require.sh jq
require.sh ffmpeg
require.sh exiftool
require.sh uvx

# Parsing configuration and commands
if [ -f "$0.env.sh" ]; then
	oldenv=$(declare -p -x)
	source "$0.env.sh" # read default env settings from this_script.env.sh
	eval "$oldenv"
fi

if [[ -n $1 ]]; then
	DO_CMD=$1
fi

export DIR_AUDIO=${DIR_AUDIO:-"./audible"}
export DIR_OPUS=${DIR_OPUS:-"./opusbooks"}
export DO_CMD=${DO_CMD:-"help"}

# compress audio normalize the volume so all tracks are similar loudness?
#export COMPRESSOR=" -filter_complex compand=attacks=0:points=-80/-900|-45/-15|-27/-9|0/-7|20/-7:gain=5 "
# 16k quality mono 48000 opus file, bump it to 32k for double the space slightly higher quality etc
export OPUSK=${OPUSK:-"16k"}

if [[ $DO_CMD =~ save ]] ; then
	echo "# env values for opusbookshelf.sh" >"$0.env.sh"
	echo "export DIR_AUDIO=$DIR_AUDIO" >>"$0.env.sh"
	echo "export DIR_OPUS=$DIR_OPUS" >>"$0.env.sh"
	echo "export OPUSK=$OPUSK" >>"$0.env.sh"
	if [[ -n $OPUSQUALITY ]]; then
		echo "export OPUSQUALITY=$OPUSQUALITY" >>"$0.env.sh"
	fi
	if [[ -n $COMPRESSOR ]]; then
		echo "export COMPRESSOR=$COMPRESSOR" >>"$0.env.sh"
	fi
	cat "$0.env.sh"
	exit 0
fi

# these defaults will not be automatically written to the env.sh file
export OPUSQUALITY=${OPUSQUALITY:-" -ac 1 -ar 48000 -c:a libopus -b:a $OPUSK "}
export COMPRESSOR=${COMPRESSOR:-" "}


do_files() {

DNAM=$(dirname "$1")
FNAM=$(basename "$1")
BNAM=${FNAM%.*}
ENAM=${FNAM##*.}

declare -A EXIF
while IFS=': ' read -r key value; do
	EXIF["$key"]="$value"
done < <(exiftool -s "$1")
    
if [[ ${EXIF["MIMEType"]} =~ (audio|video)/.* ]] && [[ -n ${EXIF["Artist"]} ]] && [[ -n ${EXIF["Album"]} ]] ; then

	AUDIBLE=""

	if [ -f "$DNAM/$BNAM.voucher" ]; then # audible-cli keys

		AUDIBLE_KEY=` jq -r ".content_license.license_response.key" "$DNAM/$BNAM.voucher" `
		AUDIBLE_IV=`  jq -r ".content_license.license_response.iv"  "$DNAM/$BNAM.voucher" `
		AUDIBLE=" -audible_key $AUDIBLE_KEY -audible_iv $AUDIBLE_IV "

	fi

	OLDK=`du -k "$1" | cut -f1`
	OLDT=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -sexagesimal "$1" 2>/dev/null`
	ODIR="$DIR_OPUS/${EXIF["Artist"]}/${EXIF["Album"]}"
	NEWK="0"
	NEWT="0"
	if [ -f "$ODIR/$BNAM.opus" ]; then # audible-cli keys
		NEWK=`du -k "$ODIR/$BNAM.opus" | cut -f1 2>/dev/null`
		NEWT=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -sexagesimal "$ODIR/$BNAM.opus" 2>/dev/null`
	fi

	if [[ $DO_CMD == "list" ]] ; then

		echo "IN	${OLDK}KiB ${OLDT} $1"
		echo "OUT	${NEWK}KiB ${NEWT} $ODIR/$BNAM.opus"
	fi
	
	if [[ $DO_CMD == "opus" ]] ; then

		# only process if opus does not exist
		if [ ! -f "$ODIR/$BNAM.opus" ]; then

			echo "IN	${OLDK}KiB ${OLDT} $1"
			echo "OUT	...KiB $ODIR/$BNAM.opus"

			mkdir -p "$ODIR"
			rm -f "./audiobook.opus"
			ffmpeg -y -loglevel warning -stats $AUDIBLE -i "$1" $COMPRESSOR $OPUSQUALITY "./audiobook.opus" && mv "./audiobook.opus" "$ODIR/$BNAM.opus"
			rm -f "./audiobook.opus"

			NEWK=`du -k "$ODIR/$BNAM.opus" | cut -f1`

			echo "size=	${OLDK}KiB to ${NEWK}KiB "

		else

			echo "IN	${OLDK}KiB ${OLDT} $1"
			echo "OUT	${NEWK}KiB ${NEWT} $ODIR/$BNAM.opus"

		fi

	fi

else

	echo "IGNORE $1"

fi


}
export -f do_files


if [[ $DO_CMD =~ (list|opus) ]] ; then

	echo " searching $DIR_AUDIO/ for audio files "
	echo " output filenames will be generated using Artist and Album tags to an opus file in $DIR_OPUS "
	if [[ $DO_CMD =~ list ]] ; then
		echo " Basic information about both files will be listed "
	fi
	if [[ $DO_CMD =~ opus ]] ; then
		echo " the files will then be encoded to opus using the following ffmpeg settings "
		echo " $COMPRESSOR $OPUSQUALITY "
	fi
	
	find "$DIR_AUDIO/" -type f -exec bash -c 'do_files "$0"' {} \;

	exit 0
fi

if [[ $DO_CMD =~ login ]] ; then

	echo " logging into audible using audible-cli "

	uvx --from audible-cli audible quickstart

	exit 0
fi

if [[ $DO_CMD =~ audible ]] ; then

	echo " downloading all audible files into $DIR_AUDIO/ using audible-cli "

	mkdir -p "$DIR_AUDIO/"
	cd "$DIR_AUDIO/"
	uvx --from audible-cli audible download --all --aaxc -j 1 --ignore-errors -q high

	exit 0
fi

cat <<EOF

opusbookshelf.sh is a simple script to download audible books and convert 
them to opus for use in audiobookshelf using audible-cli and ffmpeg

defaults will be sourced and rewriten to opusbookshelf.sh.env.sh if it 
exists. to initalise this file use the save action

	./opusbookshelf.sh save

./opusbookshelf.sh.env.sh may then be edited to change the default 
input and output paths etc. Current options are :

	DIR_AUDIO=./audiobooks
		The directory to search for audio files in or to create and 
		download audible files into.

	DIR_OPUS=./opusbooks
		The directory to create and fill with output opus files

	OPUSK=16k
		Quality of opus file, 16k is the default, change it to 24k or 
		32k if you feel this is not enough and you do not mind larger 
		files.
		
	COMPRESSOR=" "
		Setup a compressor or any ffmpeg filter, for use when 
		converting to opus eg the following will dynamically adjust 
		audio volume
	COMPRESSOR=" -filter_complex compand=attacks=0:points=-80/-900|-45/-15|-27/-9|0/-7|20/-7:gain=5 "

	OPUSQUALITY=" -ac 1 -ar 48000 -c:a libopus -b:a \$OPUSK "
		For more control over the opus output than just adjusting the 
		quility, eg you want stereo or to adjust the 48k sample rate. 
		This will overide the OPUSK setting if set.

Alternatively these may just be passed as environment args, eg :

	DIR_AUDIO=./input DIR_OPUS=./output OPUSK=32k ./opusbookshelf.sh save

Which will set and use the save action to save them as defaults for 
future invocations.


Finally we must chose and action from the following which will default 
to help.

	./opusbookshelf.sh help
		Print this help.

	./opusbookshelf.sh save
		Save current settings as default in ./opusbookshelf.sh.env.sh 

	./opusbookshelf.sh list
		List all the files we can find in DIR_AUDIO with basic 
		information about how we would convert them. We use exiftool 
		and ffprobe so this can take some time.

	./opusbookshelf.sh login
		Interctive login to audible usding audible-cli, must be run 
		before you can download audible files.

	./opusbookshelf.sh audible
		Download all your books from audible using audible-cli, shold 
		be save to stop and restart this process part way through unti 
		it completes.

	./opusbookshelf.sh opus
		Convert all books found in DIR_AUDIO into opus files in 
		DIR_OPUS, we will not overwrite opus files and will not store 
		partially converted files so it is "safe" to stop this and 
		restart it to continue its work.
	
EOF


