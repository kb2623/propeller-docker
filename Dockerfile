FROM ubuntu:16.04

ARG AUSER=propeller
ARG AUSER_ID=1000
ARG AGROUP=propellers
ARG AGROUP_ID=1000
ARG AHOME=/home/$AUSER

ARG PROPELLER_PREFIX=/usr/local
ARG MAKE_NO_PROC=4

# Install programs
USER root
WORKDIR /root

## Install basic programs
RUN apt update \
 && apt install -y apt-utils \
 && apt install -y sed tar wget curl bash git bison build-essential flex gperf ibgstreamer-plugins-base0.10-dev libasound2-dev libatkmm-1.6-dev libbz2-dev libcap-dev libcups2-dev libdrm-dev libegl1-mesa-dev libfontconfig1-dev libfreetype6-dev libgcrypt11-dev libglu1-mesa-dev libgstreamer0.10-dev libicu-dev libnss3-dev libpci-dev libpulse-dev libssl-dev libudev-dev libx11-dev libx11-xcb-dev libxcb-composite0 libxcb-composite0-dev libxcb-cursor-dev libxcb-cursor0 libxcb-damage0 libxcb-damage0-dev libxcb-dpms0 libxcb-dpms0-dev libxcb-dri2-0 libxcb-dri2-0-dev libxcb-dri3-0 libxcb-dri3-dev libxcb-ewmh-dev libxcb-ewmh2 libxcb-glx0 libxcb-glx0-dev libxcb-icccm4 libxcb-icccm4-dev libxcb-image0 libxcb-image0-dev libxcb-keysyms1 libxcb-keysyms1-dev libxcb-present-dev libxcb-present0 libxcb-randr0 libxcb-randr0-dev libxcb-record0 libxcb-record0-dev libxcb-render-util0 libxcb-render-util0-dev libxcb-render0 libxcb-render0-dev libxcb-res0 libxcb-res0-dev libxcb-screensaver0 libxcb-screensaver0-dev libxcb-shape0 libxcb-shape0-dev libxcb-shm0 libxcb-shm0-dev libxcb-sync-dev libxcb-sync0-dev libxcb-sync1 libxcb-util-dev libxcb-util0-dev libxcb-util1 libxcb-xevie0 libxcb-xevie0-dev libxcb-xf86dri0 libxcb-xf86dri0-dev libxcb-xfixes0 libxcb-xfixes0-dev libxcb-xinerama0 libxcb-xinerama0-dev libxcb-xkb-dev libxcb-xkb1 libxcb-xprint0 libxcb-xprint0-dev libxcb-xtest0 libxcb-xtest0-dev libxcb-xv0 libxcb-xv0-dev libxcb-xvmc0 libxcb-xvmc0-dev libxcb1 libxcb1-dev libxcomposite-dev libxcursor-dev libxdamage-dev libxext-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev libxslt-dev libxss-dev libxtst-dev perl python ruby binutils libncurses5-dev expat gcc-4.7 g++-4.7

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
 && make -j $MAKE_NO_PROC \
 && make install

## Install propeller-gcc compiler
ENV PATH="${PROPELLER_PREFIX}/bin:$PATH"
RUN git clone https://github.com/parallaxinc/propgcc propgcc \
 && cd propgcc \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/bfd/doc/bfd.texinfo \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/ld/ld.texinfo \
 && make -j $MAKE_NO_PROC PREFIX="${PROPELLER_PREFIX}" ERROR_ON_WARNING=no

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
RUN wget https://download.qt.io/archive/qt/5.4/5.4.0/single/qt-everywhere-opensource-src-5.4.0.tar.gz \
 && tar -zxvf qt-everywhere-opensource-src-5.4.0.tar.gz \
 && cd qt-everywhere-opensource-src-5.4.0 \
 && ./configure -prefix QtNew -release -opensource -confirm-license -static -qt-xcb -no-glib -no-pulseaudio -no-alsa -opengl desktop -nomake examples -nomake tests \
 && make -j $MAKE_NO_PROC \
 && make install
### FIXME install qt5.4 from source because run works only with gui
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
