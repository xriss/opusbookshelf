#!/usr/bin/env bash

echo " Preparing to opusbookshelf first we must check and install dependencies "

# first install a require script that should work on multiple flavors of linux
if ! [[ -x "$(command -v require.sh)" ]] ; then

	echo " we need sudo to install require.sh to /usr/local/bin from https://github.com/xriss/require.sh "
	echo " if this scares you then add a dummy require.sh and provide the dependencies yourself "
	sudo wget -O /usr/local/bin/require.sh https://raw.githubusercontent.com/xriss/require.sh/main/require.sh
	sudo chmod +x /usr/local/bin/require.sh

fi

#install dependencies using require.sh

require.sh parallel
require.sh ffmpeg
require.sh exiftool

require.sh node
require.sh npm
if ! [[ -x "$(command -v ffmpeg-bar)" ]] ; then
	sudo npm install --global ffmpeg-progressbar-cli
fi


echo " Parsing configuration and commands "

export DIR_AUDIO="/data/audiobooks"
export DIR_OPUS="/data/opusbooks"
export DO_CMD="do_list"


echo " Now it is time to process data "


do_files() {

DNAM=$(dirname "$1")
FNAM=$(basename "$1")
BNAM=${FNAM%.*}
ENAM=${FNAM##*.}

declare -A EXIF
while IFS=': ' read -r key value; do
	EXIF["$key"]="$value"
done < <(exiftool -s "$1")
    
if [[ ${EXIF["MIMEType"]} == audio/* ]] && [[ -n ${EXIF["Artist"]} ]] && [[ -n ${EXIF["Album"]} ]] ; then

#echo $ENAM -- $DNAM -- $FNAM
#echo ${EXIF["Artist"]} / ${EXIF["Album"]} / $FNAM

ODIR="$DIR_OPUS/${EXIF["Artist"]}/${EXIF["Album"]}"

# only if opus does not exist
if [ ! -f "$ODIR/$BNAM.opus" ]; then

echo "$ODIR"
mkdir -p "$ODIR"
echo "$1" ">>into>>" "$ODIR/$BNAM.opus"
rm -f "./audiobook.opus"
ffmpeg-bar -i "$1" -filter_complex "compand=attacks=0:points=-80/-900|-45/-15|-27/-9|0/-7|20/-7:gain=5" -ac 1 -c:a libopus -b:a 16k "./audiobook.opus"
mv "./audiobook.opus" "$ODIR/$BNAM.opus"
rm -f "./audiobook.opus"

fi

fi


}
export -f do_files


find "$DIR_AUDIO" -type f -exec bash -c 'do_files "$0"' {} \;



