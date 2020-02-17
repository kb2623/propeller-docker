FROM debian:buster-slim

ARG AUSER=propeller
ARG AUSER_ID=1000
ARG AGROUP=propellers
ARG AGROUP_ID=1000
ARG AHOME=/home/$AUSER

ARG NODE_VERSION=12.x
ARG PREFIX=/usr/local

# Install programs
USER root
WORKDIR /root

## Install basic programs
RUN apt update \
 && apt upgrade -y \
 && apt install -y apt-utils bash \
 && apt install -y gettext libbsd-dev texinfo vim-gtk3 git curl tmux universal-ctags fonts-firacode gcc g++ qt5-default build-essential linux-headers-$(uname -r) autoconf gdb make gawk gnat bison byacc m4 flex expect xserver-xorg-dev binutils \
 && apt clean

## Install Node.js and NPM
RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION -o nodesource_setup.sh \
 && bash nodesource_setup.sh \
 && apt update \
 && apt upgrade -y \
 && apt install -y nodejs \
 && npm install \
 && apt clean

# Make skel dir
USER root
WORKDIR /etc/skel
SHELL ["/bin/bash", "-c"]

ADD .vimrc .
ADD .bashrc .
ADD .tmux.conf .
RUN curl -fLo .vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Create a user and install git programs
USER root
WORKDIR /root
SHELL ["/bin/bash", "-c"]

## Create a new user
ADD createuser.sh /root
RUN chmod a+x createuser.sh \
 && ./createuser.sh $AUSER $AUSER_ID $AGROUP $AGROUP_ID $AHOME \
 && rm createuser.sh
RUN mkdir -p /mnt/data \
 && chown -R $AUSER:$AGROUP /mnt/data \
 && ln -s /mnt/data $AHOME/data \
 && chown $AUSER:$AGROUP $AHOME/data

## Install propeller-gcc compiler
RUN git clone https://github.com/parallaxinc/propgcc.git propgcc \
 && cd propgcc \
 && make PREFIX=$PREFIX ERROR_ON_WARNING=no

## Install Spin/PASM compiler for the Parallax Propeller
RUN git clone https://github.com/parallaxinc/OpenSpin.git OpenSpin \
 && cd OpenSpin \
 && make

## Install Parallax Propeller loader supporting both serial and wifi downloads
RUN git clone https://github.com/parallaxinc/PropLoader.git PropLoader \
 && cd PropLoader \
 && make

## Install SimpleIDE
RUN git clone https://github.com/parallaxinc/SimpleIDE.git SimpleIDE \
 && cd SimpleIDE \
 && make

## Install Parallax IDE
RUN git clone https://github.com/parallaxinc/Parallax-IDE.git ParallaxIDE \
 && cd ParallaxIDE \
 && npm cache clean \
 && npm install \
 && npm run build

# ENTRYPOINT
USER $AUSER
WORKDIR $AHOME
SHELL ["/bin/bash", "-c"]
VOLUME /tmp/.X11-unix
VOLUME /mnt/data
ENTRYPOINT bash
