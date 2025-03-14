#!/bin/bash

    set -o nounset   # disallow usage of unset vars  ( set -u )
    set -o errexit   # Exit immediately if a pipeline returns non-zero.  ( set -e )
    set -o errtrace  # Allow the above trap be inherited by all functions in the script.  ( set -E )
    set -o pipefail  # Return value of a pipeline is the value of the last (rightmost) command to exit with a non-zero status
    IFS=$'\n\t'      # Set $IFS to only newline and tab.

    # shellcheck disable=SC2034
    cr=$'\n'

    function black() { if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[30m$1\x1B[0m"; else echo "$1"; fi  }
    function red()   { if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[31m$1\x1B[0m"; else echo "$1"; fi; }
    function green() { if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[32m$1\x1B[0m"; else echo "$1"; fi; }
    function yellow(){ if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[33m$1\x1B[0m"; else echo "$1"; fi; }
    function blue()  { if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[34m$1\x1B[0m"; else echo "$1"; fi; }
    function purple(){ if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[35m$1\x1B[0m"; else echo "$1"; fi; }
    function cyan()  { if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[36m$1\x1B[0m"; else echo "$1"; fi; }
    function white() { if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then echo -e "\x1B[37m$1\x1B[0m"; else echo "$1"; fi; }


cd "$(dirname "$0")" || exit 1


##########################################################################################################################################################

function header() { echo "" ; printf '=%.0s' {1..80} && printf '\n' ; echo "> $1" ; printf '=%.0s' {1..80} && printf '\n' ; echo "" ; }

##########################################################################################################################################################

cname="joplin-sync"

server="https://notes.blackforestbytes.com/"
acc_mail="$( cat account.env )"
acc_pass="$( cat password.env )"
acc_encr="$( cat encryption.env )"

container="registry.blackforestbytes.com/mikescher/joplin-git-sync:latest"

echo "> Stop dangling container"

if docker ps -a --format '{{.Names}}' | grep -q "^$cname$"; then
    docker stop "$cname" || true
    docker rm   "$cname" || true
else
    echo "Container '$cname' does not exist. Skipping stop and remove."
fi

echo "> Start container"

docker pull "$container"

docker run --detach --name "$cname" --volume "$(pwd):/portal" --volume "$(pwd)/joplin_cache:/home/u0/.config/joplin" "$container" noop

function __trap_failed {
    # scnsend "Joplin sync failed on line $(caller)"
    docker stop "$cname" || true
    docker rm   "$cname" || true
}
trap __trap_failed ERR

reinit="0"

if [ ! -f "joplin_cache/__init" ]; then

    header "Login + Setup"

    reinit="1"

    docker exec "$cname" "/usr/bin/joplin" config "sync.target"     "9" ; echo -n "."
    
    docker exec "$cname" "/usr/bin/joplin" config "sync.interval"   "0" ; echo -n "."
    
    docker exec "$cname" "/usr/bin/joplin" config "sync.9.path"     "$server"   ; echo -n "."
    docker exec "$cname" "/usr/bin/joplin" config "sync.9.username" "$acc_mail" ; echo -n "."
    docker exec "$cname" "/usr/bin/joplin" config "sync.9.password" "$acc_pass" ; echo -n "."
    
    docker exec "$cname" "/usr/bin/joplin" config "revisionService.enabled"   "false" ; echo -n "."
    docker exec "$cname" "/usr/bin/joplin" config "revisionService.ttlDays"   "0"     ; echo -n "."

    touch "joplin_cache/__init"

else

    green "Found __init file -- will skip setup"

fi

echo ""

header "Config"

docker exec "$cname" "/usr/bin/joplin" config 

header "Sync"

docker exec "$cname" "/usr/bin/joplin" sync

header "List"

docker exec "$cname" "/usr/bin/joplin" ls / --long

header "Status"

docker exec "$cname" "/usr/bin/joplin" status

header "Decrypt"

if [ "$reinit" == "1" ]; then

    echo "... Set E2EE PW"

    # TODO this sucks - this way we create a new masterkey instead of inputting the pw of the existing one
    #      I _really_ don't want that (and the docs say `e2ee decrypt --password ".."` shoudl work - but it doesnt)
    #      So for now this is commented out - when someone deletes the joplin_cache, he has to run ./sync with an TTY
    #      and manually input the master pw.
    # docker exec "$cname" "/usr/bin/joplin" e2ee enable --password "$acc_encr"
    
    docker exec -it "$cname" "/usr/bin/joplin" e2ee decrypt --retry-failed-items 

else

    docker exec "$cname" "/usr/bin/joplin" e2ee decrypt --retry-failed-items 

fi

header "List"

docker exec "$cname" "/usr/bin/joplin" ls / --long

header "Status"

docker exec "$cname" "/usr/bin/joplin" status

header "Export"

docker exec "$cname" rm    -rf "/portal/notes"
docker exec "$cname" mkdir -p  "/portal/notes"

docker exec "$cname" "/usr/bin/joplin" export "/portal/notes" --format "md_frontmatter"

header "Stop container"

docker stop "$cname"
docker rm   "$cname"

header "Sync files to repo"

cd "notes_git"

git reset HEAD --hard
git pull --force
git reset origin/master --hard

cd ".."

rm -rf -v "notes_git"/*

cp -r -v "notes"/* "notes_git"

header "Commit & Push"

cd "notes_git"

chown 1000:1000 . -R

if [ -n "$(git status --porcelain)" ]; then

    git add -v .

    msg="Automatic Joplin Mirroring via cronjob"
    msg="$( printf "%s\n"                 "$msg"                                     )"
    msg="$( printf "%s\n# Timestamp: %s"  "$msg"  "$( date +"%Y-%m-%d %H:%M:%S%z" )" )"
    msg="$( printf "%s\n# Provider: %s"   "$msg"  "Joplin"                           )"
    msg="$( printf "%s\n# Server: %s"     "$msg"  "$server"                          )"
    msg="$( printf "%s\n# Account: %s"    "$msg"  "$acc_mail"                        )"
    msg="$( printf "%s\n# Hostname: %s"   "$msg"  "$(hostname)"                      )"

    git commit -m "$msg"
    git push origin master

else
    echo "No changes to commit - skip"
fi

header "Done."

