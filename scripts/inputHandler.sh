#!/bin/sh

# Touch input handler for the literary clock
# Single tap: show quote metadata (author/title) for 3 seconds
# Two-finger swipe left-to-right: increase brightness
# Two-finger swipe right-to-left: decrease brightness

BASEDIR="/mnt/onboard/.adds/timelit"
FBINK="$BASEDIR/bin/fbink -q"
TOUCH_DEV="/dev/input/event1"
EVENT_SIZE=16

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

adjust_brightness() {
	[ -z "$BRIGHTNESS_FILE" ] && return
	current=$(cat "$BRIGHTNESS_FILE" 2>/dev/null || echo 0)
	if [ "$1" = "up" ]; then
		new=$((current + BRIGHTNESS_STEP))
		[ $new -gt $BRIGHTNESS_MAX ] && new=$BRIGHTNESS_MAX
	else
		new=$((current - BRIGHTNESS_STEP))
		[ $new -lt 0 ] && new=0
	fi
	echo "$new" > "$BRIGHTNESS_FILE"
}

# --- Metadata display (same logic as showMetadata.sh) ---
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

	# collect remaining events for this gesture (~1 second window)
	timeout 1 cat "$TOUCH_DEV" >> /tmp/touch_batch 2>/dev/null

	# parse the event batch:
	#   hexdump reads 16-byte input_event structs (32-bit ARM):
	#     8 bytes timestamp (ignored) + 2 bytes type + 2 bytes code + 4 bytes value
	#   awk detects multi-touch (ABS_MT_SLOT > 0) and tracks swipe direction
	action=$(hexdump -v -e '8/1 "%02x" " " 1/2 "%u" " " 1/2 "%u" " " 1/4 "%d" "\n"' \
		/tmp/touch_batch 2>/dev/null | awk '
	BEGIN { slot = 0; multitouch = 0; first_x = -1; last_x = -1 }
	{
		type = $2; code = $3; value = $4
		if (type == 3 && code == 47) {
			slot = value
			if (value > 0) multitouch = 1
		}
		if (type == 3 && code == 53 && slot == 0) {
			if (first_x == -1) first_x = value
			last_x = value
		}
	}
	END {
		if (multitouch && first_x >= 0 && last_x >= 0) {
			dx = last_x - first_x
			if (dx > 50) print "bright_up"
			else if (dx < -50) print "bright_down"
			else print "none"
		} else {
			print "tap"
		}
	}')

	rm -f /tmp/touch_batch

	case "$action" in
		tap) show_metadata ;;
		bright_up) adjust_brightness up ;;
		bright_down) adjust_brightness down ;;
	esac

	# debounce — drain any trailing events
	timeout 1 cat "$TOUCH_DEV" > /dev/null 2>&1
done
