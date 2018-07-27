#!/bin/zsh

# install before use: youtube-viewer, playerctl, mpv, feh (if needed), unclutter (if needed)
# otherwise you need to modify this script

# params
PLAYER="mpv"
PLAYERARGS="--fs --no-audio --no-osc --input-ipc-server=/tmp/mpv.sock --keep-open=yes --pause"
SUFFIX="official"
MPV_CHECK_INTERVAL=0.25
SONG_CHECK_INTERVAL=0.25
USE_BG=0
BG_IMAGE="black.png"
USE_UNCLUTTER=0

exit_cleanup() {
    trap - SIGINT SIGTERM
    echo "cleanup"
    kill -- -$$
}

# run exit_cleanup when interrupted
trap exit_cleanup SIGINT SIGTERM

# show background
if [ $USE_BG = 1 ]; then
  feh -F "$BG_IMAGE" &
fi

# hide cursor
if [ $USE_UNCLUTTER = 1 ]; then
  unclutter -idle 0.01 -root &
fi

reset_song() {
  playerctl stop # stop playback
  playerctl previous
  playerctl stop
  sleep 1
  if [ "$1" != "$(playerctl metadata xesam:artist) $(playerctl metadata xesam:title)" ]; then
    playerctl next
    playerctl stop
  fi
}

# start loop
while true; do
  # check current artist and title for difference between last check
  NEW="$(playerctl metadata xesam:artist) $(playerctl metadata xesam:title)"
  if [ "$NEW" != "$CURRENT" ]; then
    CURRENT="$NEW"

    echo "got new song: $CURRENT"
    killall youtube-viewer > /dev/null
    killall $PLAYER 2> /dev/null
    
    reset_song "$CURRENT"

    echo "starting youtube-viewer"
    youtube-viewer -q --std-input="1" --video-player="$PLAYER" --append-arg="$PLAYERARGS" "$CURRENT $SUFFIX" &

    false
    while [ $? != 0 ]; do
      playerctl stop # stop music if switched between download
      sleep $MPV_CHECK_INTERVAL
      echo "check if $PLAYER is started already"
      pgrep $PLAYER
    done
    echo "found $PLAYER, kill youtube-viewer"
    killall youtube-viewer 2> /dev/null
    # mpv takes a while to open and load the video, so sleep 2 sec
    sleep 2
    echo "start playing music and video"
    playerctl play
    echo cycle pause | socat - /tmp/mpv.sock
  fi
  # set higher if too resource heavy
  sleep $SONG_CHECK_INTERVAL
done
