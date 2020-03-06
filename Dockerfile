FROM debian:sid

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

RUN apt-get update \
 && apt-get install -y --no-install-recommends apt-utils ca-certificates netbase curl wget sed bash gnupg bzip2 apt-transport-https

SHELL ["/bin/bash", "-c"]

## Install basic programs
RUN sed -i '$ a deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20170101/ jessie main contrib non-free' /etc/apt/sources.list \
 && sed -i '$ a deb-src [check-valid-until=no] http://snapshot.debian.org/archive/debian/20170101/ jessie main contrib non-free' /etc/apt/sources.list \
 && sed -i '$ a deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20170101/ jessie/updates main contrib non-free' /etc/apt/sources.list \
 && sed -i '$ a deb-src [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20170101/ jessie/updates main contrib non-free' /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends tar git vim-gtk gcc-4.9 g++-4.9 make \
 && update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-4.9 100 \
 && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 100 \
 && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-4.9 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 100 \
 && apt-get install -y --no-install-recommends bison flex gperf perl python ruby libncurses5-dev expat

ADD files/.vimrc /etc/skel
ADD files/.bashrc /etc/skel
ADD files/.tmux.conf /etc/skel
RUN mkdir -p /etc/skel/.vim/autoload \
 && cd /etc/skel/.vim/autoload \
 && wget https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
 && sed -i '$ a export QT_X11_NO_MITSHM=1' /etc/skel/.profile \
 && sed -i '$ a export PATH=${PROPELLER_PREFIX}/bin:${PATH}' /etc/skel/.profile

## Create a new user
ADD createuser.sh /root
RUN chmod a+x createuser.sh \
 && ./createuser.sh $AUSER $AUSER_ID $AGROUP $AGROUP_ID $AHOME \
 && rm createuser.sh
RUN mkdir -p /mnt/data \
 && chown -R $AUSER:$AGROUP /mnt/data \
 && ln -s /mnt/data $AHOME/data \
 && chown $AUSER:$AGROUP $AHOME/data

# Create a user and install git programs
USER root
WORKDIR /tmp

## Install dependencies
RUN wget http://ftp.gnu.org/gnu/texinfo/texinfo-4.13a.tar.gz \
 && tar -zxvf texinfo-4.13a.tar.gz \
 && rm texinfo-4.13a.tar.gz
RUN cd texinfo-4.13 \
 && ./configure \
 && make -j $MAKE_NO_PROC \
 && make install \
 && rm -rf texinfo-4.13

## Install propeller-gcc compiler
ENV PATH="${PROPELLER_PREFIX}/bin:$PATH"
RUN git clone https://github.com/parallaxinc/propgcc propgcc
RUN cd propgcc \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/bfd/doc/bfd.texinfo \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/ld/ld.texinfo \
 && make PREFIX="${PROPELLER_PREFIX}" ERROR_ON_WARNING=no
RUN rm -rf propgcc

## Install Spin/PASM compiler for the Parallax Propeller
RUN git clone https://github.com/parallaxinc/OpenSpin.git OpenSpin
RUN cd OpenSpin \
 && make -j $MAKE_NO_PROC

## Install Parallax Propeller loader supporting both serial and wifi downloads
ENV OS=linux
RUN git clone https://github.com/parallaxinc/PropLoader.git PropLoader
RUN cd PropLoader \
 && make -j $MAKE_NO_PROC

## Install SimpleIDE
### Dependencies
RUN apt-get install -y qt5-default libxcb1 libxcb1-dev libx11-xcb1 libx11-xcb-dev libxcb-keysyms1 libxcb-keysyms1-dev libxcb-image0 libxcb-image0-dev libxcb-shm0 libxcb-shm0-dev libxcb-render-util0 libxcb-render-util0-dev libxcb-xfixes0-dev libxrender-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-glx0-dev
RUN wget https://download.qt.io/archive/qt/5.4/5.4.2/single/qt-everywhere-opensource-src-5.4.2.tar.gz \
 && tar zxvf qt-everywhere-opensource-src-5.4.2.tar.gz \
 && rm qt-everywhere-opensource-src-5.4.2.tar.gz
RUN cd qt-everywhere-opensource-src-5.4.2 \
 && ./configure -prefix "${PROPELLER_PREFIX}" -release -opensource -confirm-license -static -qt-xcb -no-glib -no-pulseaudio -no-alsa -opengl desktop -nomake examples -nomake tests \
 && make -j $MAKE_NO_PROC \
 && make install
RUN rm -rf qt-everywhere-opensource-src-5.4.2

### Install SimpleIDE
ENV QT_X11_NO_MITSHM=1
RUN wget http://downloads.parallax.com/plx/software/side/101rc1/simple-ide_1-0-1-rc1_amd64.deb
RUN dpkg -i ./simple-ide_1-0-1-rc1_amd64.deb || apt-get install -f -y
RUN rm simple-ide_1-0-1-rc1_amd64.deb

# TODO Build IDE from source for better compatibility
#RUN git clone https://github.com/parallaxinc/SimpleIDE.git SimpleIDE
#RUN cd SimpleIDE \
#&& sed -i '44,54d' plinrelease.sh
#&& bash plinrelease.sh

# ENTRYPOINT
USER $AUSER
WORKDIR $AHOME
VOLUME /tmp/.X11-unix
VOLUME /mnt/data
ENTRYPOINT bash

# vim: tabstop=1 expandtab shiftwidth=1 softtabstop=1
