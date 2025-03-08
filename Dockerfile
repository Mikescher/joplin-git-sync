FROM debian:latest

RUN useradd u0 && mkdir /home/u0 && chown u0:u0 /home/u0/

RUN apt-get update && apt-get install -y npm make vim && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN su -c 'NPM_CONFIG_PREFIX=~/.joplin-bin npm install -g node-pre-gyp node-gyp' u0

RUN su -c 'NPM_CONFIG_PREFIX=~/.joplin-bin npm install -g joplin' u0

RUN ln -s "/home/u0/.joplin-bin/bin/joplin" "/usr/bin/joplin"

COPY run.sh /run.sh
RUN chmod +Xx /run.sh

USER u0

ENTRYPOINT [ "/bin/bash", "/run.sh" ]



