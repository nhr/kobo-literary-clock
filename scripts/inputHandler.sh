#!/bin/sh

# Touch input handler for the literary clock
# Tap zones (Kobo Clara HD, 1072x1448):
#   Bottom edge:     show quote metadata (author/title) for 3 seconds
#   Upper left:      decrease brightness by 10%
#   Upper right:     increase brightness by 10%

BASEDIR="/mnt/onboard/.adds/timelit"
FBINK="$BASEDIR/bin/fbink -q"
TOUCH_DEV="/dev/input/event1"
EVENT_SIZE=16

# Tap zone boundaries
# Clara HD touch coords: X=vertical (0=top, ~1448=bottom), Y=horizontal (0=right, ~1072=left)
UPPER_MAX=300
BOTTOM_MIN=1148
RIGHT_MAX=250
LEFT_MIN=822

# --- Brightness setup ---
BRIGHTNESS_FILE=""
BRIGHTNESS_MAX=100
for path in /sys/class/backlight/mxc_msp430.0 /sys/class/backlight/lm3630a_led; do
	if [ -f "$path/brightness" ]; then
		BRIGHTNESS_FILE="$path/brightness"
		BRIGHTNESS_MAX=$(cat "$path/max_brightness" 2>/dev/null || echo 100)
		break
	fi
done
BRIGHTNESS_STEP=$((BRIGHTNESS_MAX / 10))
[ "$BRIGHTNESS_STEP" -lt 1 ] && BRIGHTNESS_STEP=1

echo "inputHandler started" >&2
echo "BRIGHTNESS_FILE=$BRIGHTNESS_FILE" >&2
echo "BRIGHTNESS_MAX=$BRIGHTNESS_MAX BRIGHTNESS_STEP=$BRIGHTNESS_STEP" >&2

adjust_brightness() {
	echo "adjust_brightness $1" >&2
	[ -z "$BRIGHTNESS_FILE" ] && { echo "no brightness file" >&2; return; }
	current=$(cat "$BRIGHTNESS_FILE" 2>/dev/null || echo 0)
	if [ "$1" = "up" ]; then
		new=$((current + BRIGHTNESS_STEP))
		[ $new -gt $BRIGHTNESS_MAX ] && new=$BRIGHTNESS_MAX
	else
		new=$((current - BRIGHTNESS_STEP))
		[ $new -lt 0 ] && new=0
	fi
	echo "brightness: $current -> $new" >&2
	echo "$new" > "$BRIGHTNESS_FILE"
}

# --- Metadata display ---
show_metadata() {
	current=$(cat "$BASEDIR/clockisticking" 2>/dev/null)
	[ -z "$current" ] && return

	currentCredit=$(echo "$current" | sed 's/.png//')_credits.png
	currentCredit=$(echo "$currentCredit" | sed 's|images/|images/metadata/|')

	$FBINK -g file="$currentCredit"
	sleep 3
	timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1
	$FBINK -g file="$current"
}

# --- Main loop ---

# drain lingering touch events from the NickelMenu tap that launched us
sleep 2
timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1

while true; do
	test -f "$BASEDIR/clockisticking" || exit

	# block until first touch event
	dd if="$TOUCH_DEV" bs=$EVENT_SIZE count=1 of=/tmp/touch_batch 2>/dev/null

	# collect remaining events for this tap (~1 second)
	timeout 1 cat "$TOUCH_DEV" >> /tmp/touch_batch 2>/dev/null

	# parse first finger's tap position
	tap_pos=$(hexdump -v -e '8/1 "%02x" " " 1/2 "%u" " " 1/2 "%u" " " 1/4 "%d" "\n"' \
		/tmp/touch_batch 2>/dev/null | awk '
	BEGIN { x = -1; y = -1 }
	{
		type = $2; code = $3; value = $4
		if (type == 3 && code == 53 && x == -1) x = value
		if (type == 3 && code == 54 && y == -1) y = value
	}
	END { print x " " y }')

	rm -f /tmp/touch_batch

	tap_x=$(echo "$tap_pos" | cut -d' ' -f1)
	tap_y=$(echo "$tap_pos" | cut -d' ' -f2)

	echo "tap x=$tap_x y=$tap_y" >&2

	if [ "$tap_x" -gt $BOTTOM_MIN ]; then
		echo "zone=bottom -> metadata" >&2
		show_metadata
	elif [ "$tap_x" -lt $UPPER_MAX ] && [ "$tap_y" -gt $LEFT_MIN ]; then
		echo "zone=upper_left -> brightness down" >&2
		adjust_brightness down
	elif [ "$tap_x" -lt $UPPER_MAX ] && [ "$tap_y" -lt $RIGHT_MAX ]; then
		echo "zone=upper_right -> brightness up" >&2
		adjust_brightness up
	else
		echo "zone=other -> ignored" >&2
	fi

	# debounce — drain any trailing events
	timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1
done
