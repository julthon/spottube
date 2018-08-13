#!/bin/zsh

# install before use: youtube-viewer, playerctl, mpv, feh (if needed), unclutter (if needed)
# otherwise you need to modify this script

# params

# made to modify:
USE_BG=1
USE_UNCLUTTER=0

PLAYER="mpv"
PLAYERARGS="--fs --no-audio --no-osc --input-ipc-server=/tmp/mpv.sock --keep-open=yes --pause"
SUFFIX="official"
DOWNLOAD_CACHE=1
DOWNLOAD_CACHE_DIR="./cache"
MPV_CHECK_INTERVAL=0.25
SONG_CHECK_INTERVAL=0.25
BG_IMAGE="black.png"

exit_cleanup() {
  trap - SIGINT SIGTERM
  echo "cleanup"
  kill -- -$$
}

# run exit_cleanup when interrupted
trap exit_cleanup SIGINT SIGTERM

has_connection() {
  ping -c 1 -W 2 8.8.8.8 > /dev/null 2> /dev/null
  return $?
}

# show background
if [ $USE_BG = 1 ]; then
  feh -F "$BG_IMAGE" &
fi

# hide cursor
if [ $USE_UNCLUTTER = 1 ]; then
  unclutter -root &
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
    FILENAME=$(echo "$CURRENT" | md5sum | cut -d" " -f1 | xargs)

    echo "got new song: $CURRENT -> $FILENAME"
    killall youtube-viewer > /dev/null 2> /dev/null
    killall $PLAYER > /dev/null 2> /dev/null
    
    reset_song "$CURRENT"

    has_connection
    if [ $? != 0 ]; then
      echo "no connection, trying offline"
      if [ -f "$DOWNLOAD_CACHE_DIR/$FILENAME" ]; then
        eval "mpv $PLAYERARGS \"$DOWNLOAD_CACHE_DIR/$FILENAME\"" &
      else
        echo "file not found"
        playerctl play
        continue
      fi
    else
      echo "starting youtube-viewer"
      if [ $DOWNLOAD_CACHE != 0 ]; then
        youtube-viewer -d -dp --skip_if_exists --downloads-dir="$DOWNLOAD_CACHE_DIR" --filename="$FILENAME" -q --std-input="1" --video-player="$PLAYER" --append-arg="$PLAYERARGS" "$CURRENT $SUFFIX" &
      else
        youtube-viewer -q --std-input="1" --video-player="$PLAYER" --append-arg="$PLAYERARGS" "$CURRENT $SUFFIX" &
      fi
    fi

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
