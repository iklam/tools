#! /bin/sh

[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
vncconfig -iconic &

if test "$TESTIT" = "true"; then
    xterm
else 
    gnome-panel &
    ( LANG="en_US.UTF-8" /usr/bin/dbus-launch /usr/bin/gnome-terminal ) &
    xterm &
    metacity
fi
