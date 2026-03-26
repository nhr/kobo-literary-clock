#!/bin/sh

BASEDIR="/mnt/onboard/.adds/timelit"
LOG="$BASEDIR/timelit.log"

# if already running, do nothing (user can't reach NickelMenu anyway)
test -f "$BASEDIR/clockisticking" && exit

# mark as running immediately, before Nickel dies
touch "$BASEDIR/clockisticking"

# launch the main clock process fully detached from Nickel
setsid sh "$BASEDIR/scripts/clock_main.sh" >> "$LOG" 2>&1 &

exit 0
