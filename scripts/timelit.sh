#!/bin/sh

BASEDIR="/mnt/onboard/.adds/timelit"
FBINK="$BASEDIR/bin/fbink -q"

# if the Kobo is not being used as clock, then just quit
test -f "$BASEDIR/clockisticking" || exit

# find the current minute of the day
MinuteOTheDay="$(date +"%H%M")"

# collect matching images into a list
IMGLIST=$(ls "$BASEDIR/images/quote_${MinuteOTheDay}_"*.png 2>/dev/null)

if [ -z "$IMGLIST" ]; then
	echo "no images for $MinuteOTheDay" >&2
	exit
fi

# randomly pick one image (awk random, no shuf dependency)
ThisMinuteImage=$(echo "$IMGLIST" | awk 'BEGIN{srand()}{a[NR]=$0}END{print a[int(rand()*NR)+1]}')

echo "$ThisMinuteImage" > "$BASEDIR/clockisticking"

# clear the screen and show the image
echo "displaying $ThisMinuteImage" >&2
$FBINK -c
$FBINK -g file="$ThisMinuteImage"
