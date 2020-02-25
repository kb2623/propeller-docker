FROM ubuntu:14.04

ARG AUSER=propeller
ARG AUSER_ID=1000
ARG AGROUP=propellers
ARG AGROUP_ID=1000
ARG AHOME=/home/$AUSER

ARG PREFIX=/usr/local
ARG MAKE_NO_PROC=4

# Install programs
USER root
WORKDIR /root

## Install basic programs
RUN apt update \
 && apt upgrade -y \
 && apt install -y apt-utils \
 && apt install -y sed tar bash curl make wget vim git tmux qt5-default xserver-xorg-dev install '^libxcb.*-dev' libx11-xcb-dev gperf libicu-dev libxslt-dev ruby libglu1-mesa-dev libxrender-dev libxi-dev gcc g++ gdb perl build-essential binutils bison flex expat xterm libncurses5-dev

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

## Install dependencies
RUN wget http://ftp.gnu.org/gnu/texinfo/texinfo-4.13a.tar.gz \
 && tar -zxvf texinfo-4.13a.tar.gz \
 && cd texinfo-4.13 \
 && ./configure \
 && make -j 4 \
 && make install

## Install propeller-gcc compiler
ENV PATH=/opt/parallax:$PATH
RUN git clone https://github.com/parallaxinc/propgcc propgcc \
 && cd propgcc \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/bfd/doc/bfd.texinfo \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/ld/ld.texinfo
 && make -j $MAKE_NO_PROC PREFIX=/opt/parallax

## Install Spin/PASM compiler for the Parallax Propeller
RUN git clone https://github.com/parallaxinc/OpenSpin.git OpenSpin \
 && cd OpenSpin \
 && make -j $MAKE_NO_PROC

## Install Parallax Propeller loader supporting both serial and wifi downloads
ENV OS=linux
RUN git clone https://github.com/parallaxinc/PropLoader.git PropLoader \
 && cd PropLoader \
 && make -j $MAKE_NO_PROC

## Install SimpleIDE
### FIXME install qt5.4 from source because run works only with gui
RUN wget https://download.qt.io/archive/qt/5.4/5.4.0/single/qt-everywhere-opensource-src-5.4.0.tar.gz \
 && tar -zxvf qt-everywhere-opensource-src-5.4.0.tar.gz \
 && cd qt-everywhere-opensource-src-5.4.0 \
 && yes | ./configure -prefix $PWD/qtbase -opensource -nomake tests \
 && make -j $MAKE_NO_PROC \
 && make install
RUN git clone https://github.com/parallaxinc/SimpleIDE.git SimpleIDE \
 && cd SimpleIDE \
 && bash plinrelease.sh

## Clean at the end
RUN rm -rf propgcc OpenSpin PropLoader SimpleIDE

# ENTRYPOINT
USER $AUSER
WORKDIR $AHOME
SHELL ["/bin/bash", "-c"]
VOLUME /tmp/.X11-unix
VOLUME /mnt/data
ENTRYPOINT bash
