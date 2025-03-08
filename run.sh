#!/bin/bash

if [ "$*" == "noop" ]; then
    tail -F /dev/null
    exit
fi

if [ "$*" == "bash" ]; then
    /bin/bash
    exit
fi

if [ "$*" == "sh" ]; then
    /bin/sh
    exit
fi

cmd="/usr/bin/joplin"

for arg in "$@"; do
    cmd=$( printf "%s %q" "$cmd" "$arg" )
done

su -c "${cmd}" u0


