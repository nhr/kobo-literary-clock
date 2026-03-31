#!/bin/sh

BASEDIR="/mnt/onboard/.adds/timelit"
LOG="$BASEDIR/timelit.log"

# clean up stale clockisticking from an unclean shutdown
if test -f "$BASEDIR/clockisticking"; then
	if pgrep -f "clock_main.sh" > /dev/null 2>&1; then
		exit
	fi
	rm -f "$BASEDIR/clockisticking"
fi

# mark as running immediately, before Nickel dies
touch "$BASEDIR/clockisticking"

# launch the main clock process fully detached from Nickel
setsid sh "$BASEDIR/scripts/clock_main.sh" >> "$LOG" 2>&1 &

exit 0
