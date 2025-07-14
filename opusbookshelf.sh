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

#require.sh parallel
require.sh jq
require.sh ffmpeg
require.sh exiftool

#require.sh node
#require.sh npm
#if ! [[ -x "$(command -v ffmpeg-bar)" ]] ; then
#	sudo npm install --global ffmpeg-progressbar-cli
#fi

# audible download into current dir
# uvx --from audible-cli audible download --all --aaxc -j 1 --ignore-errors -q high


echo " Parsing configuration and commands "

#export DIR_AUDIO="/data/audiobooks"
#export DIR_OPUS="./opusbooks"

export DIR_AUDIO="/data/audible"
export DIR_OPUS="/data/opusbooks"
export DO_CMD="do_list"


# compress audio normalize the volume so all tracks are similar loudness?
#export COMPRESSOR=" -filter_complex compand=attacks=0:points=-80/-900|-45/-15|-27/-9|0/-7|20/-7:gain=5 "
export COMPRESSOR=" "
# 16k quality mono 48000 opus file, bump it to 32k for double the space slightly higher quality etc
export OPUSQUALITY=" -ac 1 -ar 48000 -c:a libopus -b:a 16k "


echo " process data "


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

#echo $ENAM -- $DNAM -- $FNAM
#echo ${EXIF["Artist"]} / ${EXIF["Album"]} / $FNAM

OLDK=`du -k "$1" | cut -f1`
OLDT=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -sexagesimal "$1" 2>/dev/null`

ODIR="$DIR_OPUS/${EXIF["Artist"]}/${EXIF["Album"]}"

# only process if opus does not exist
if [ ! -f "$ODIR/$BNAM.opus" ]; then


echo "IN	${OLDK}KiB ${OLDT} $1"
echo "OUT	...KiB $ODIR/$BNAM.opus"

mkdir -p "$ODIR"
rm -f "./audiobook.opus"
ffmpeg -y -loglevel warning -stats $AUDIBLE -i "$1" $COMPRESSOR $OPUSQUALITY "./audiobook.opus" && mv "./audiobook.opus" "$ODIR/$BNAM.opus"
rm -f "./audiobook.opus"

NEWK=`du -k "$ODIR/$BNAM.opus" | cut -f1`

echo "shrunk	${OLDK}KiB to ${NEWK}KiB "

else

NEWK=`du -k "$ODIR/$BNAM.opus" | cut -f1`
NEWT=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -sexagesimal "$ODIR/$BNAM.opus"`

echo "IN	${OLDK}KiB ${OLDT} $1"
echo "OUT	${NEWK}KiB ${NEWT} $ODIR/$BNAM.opus"

fi

else

echo "IGNORE $1"

fi


}
export -f do_files


find "$DIR_AUDIO" -type f -exec bash -c 'do_files "$0"' {} \;



