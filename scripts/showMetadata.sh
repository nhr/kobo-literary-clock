#!/bin/sh

BASEDIR="/mnt/onboard/.adds/timelit"
FBINK="$BASEDIR/bin/fbink -q"
TOUCH_DEV="/dev/input/event1"

# drain any lingering touch events from the NickelMenu tap that launched us
sleep 2
timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1

# wait for a touch event
while true; do
	# check if clock is still running
	test -f "$BASEDIR/clockisticking" || exit

	# see what image is shown at the moment
	current=$(cat "$BASEDIR/clockisticking" 2>/dev/null)

	# only continue if a filename is in the clockisticking file
	if [ -z "$current" ]; then
		sleep 1
		continue
	fi

	# wait for touch input (read a single event from the touchscreen)
	dd if="$TOUCH_DEV" bs=24 count=1 2>/dev/null

	# drain remaining touch events from this gesture (1s debounce)
	timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1

	# re-read current image (may have changed during debounce)
	current=$(cat "$BASEDIR/clockisticking" 2>/dev/null)
	[ -z "$current" ] && continue

	# find the matching image with metadata
	currentCredit=$(echo "$current" | sed 's/.png//')_credits.png
	currentCredit=$(echo "$currentCredit" | sed 's|images/|images/metadata/|')

	# show the image with metadata
	$FBINK -g file="$currentCredit"

	# hold for 3 seconds then restore the original image
	sleep 3

	# drain any touch events that occurred during the hold
	timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1

	$FBINK -g file="$current"
done
