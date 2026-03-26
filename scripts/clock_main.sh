#!/bin/sh

# Main clock process — runs detached from Nickel via setsid
# Nickel lifecycle handling based on KOReader's koreader.sh / nickel.sh

BASEDIR="/mnt/onboard/.adds/timelit"
FBINK="$BASEDIR/bin/fbink -q"
LOG="$BASEDIR/timelit.log"

# clear log on startup — steady-state output goes to /dev/null
# so only startup/shutdown messages accumulate here
: > "$LOG"

echo "=== $(date) ===" >> "$LOG"
echo "clock_main.sh starting (PID $$)" >> "$LOG"

# give NickelMenu a moment to finish spawning us
sleep 1

# flush disks before killing Nickel (avoids trashing its DB)
sync
echo "sync done" >> "$LOG"

# kill Nickel and all companion processes (matches KOReader's approach)
killall -q -TERM nickel hindenburg sickel fickel strickel fontickel \
	adobehost foxitpdf iink dhcpcd-dbus dhcpcd bluealsa bluetoothd \
	fmon nanoclock.lua 2>> "$LOG"
echo "Sent SIGTERM to Nickel and companions" >> "$LOG"

# wait for Nickel to actually die (up to 4 seconds)
kill_timeout=0
while killall -0 nickel 2>/dev/null; do
	if [ $kill_timeout -ge 4 ]; then
		echo "WARNING: Nickel still alive after 4s" >> "$LOG"
		break
	fi
	sleep 1
	kill_timeout=$((kill_timeout + 1))
done
echo "Nickel stopped (waited ${kill_timeout}s)" >> "$LOG"

# remove Nickel's FIFO so udev/udhcpc scripts don't hang
rm -f /tmp/nickel-hardware-status

# prevent the device from going to sleep
echo unlock > /sys/power/state-extended 2>/dev/null

# clear display
$FBINK -c

# start touch handler in background
sh "$BASEDIR/scripts/showMetadata.sh" > /dev/null 2>&1 &

echo "Entering clock loop" >> "$LOG"

# main clock loop
while test -f "$BASEDIR/clockisticking"; do
	# display current quote
	sh "$BASEDIR/scripts/timelit.sh" > /dev/null 2>&1

	# sleep until the next minute boundary, checking for exit every 5s
	cur_sec=$(date +%S)
	# seconds remaining in this minute (strip leading zero for arithmetic)
	remaining=$((60 - ${cur_sec#0}))
	elapsed=0
	while [ $elapsed -lt $remaining ]; do
		sleep 5
		test -f "$BASEDIR/clockisticking" || break
		elapsed=$((elapsed + 5))
	done
done

echo "Clock loop exited, restarting Nickel" >> "$LOG"

# re-enable sleep
echo lock > /sys/power/state-extended 2>/dev/null

$FBINK -c

# recreate Nickel's FIFO (as rcS does) so udev can write to it
rm -f /tmp/nickel-hardware-status
mkfifo /tmp/nickel-hardware-status

# flush before restarting
sync

# restart Nickel and its companion (matches KOReader's nickel.sh)
export LD_LIBRARY_PATH="/usr/local/Kobo"
/usr/local/Kobo/hindenburg &
LIBC_FATAL_STDERR_=1 /usr/local/Kobo/nickel -platform kobo -skipFontLoad &
udevadm trigger &

echo "Nickel restart initiated" >> "$LOG"
