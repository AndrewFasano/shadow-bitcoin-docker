#!/bin/bash

docker build -t bitcoin ./docker || exit 

docker run -it \
-v "/home/${USER}":"/home/shadow/host" \
-v "/home/${USER}/.inputrc":"/home/shadow/.inputrc" \
-v "/home/${USER}/.vimrc":"/home/shadow/.vimrc" \
-v "/home/${USER}/.bashrc":"/home/shadow/.bashrc" \
bitcoin bash
