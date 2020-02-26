FROM debian:jessie

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
 && apt install -y apt-utils sed tar curl bash git vim-gtk build-essential \
 && apt install -y bison flex gperf perl python ruby libncurses5-dev expat qt5-default

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
RUN curl -O http://ftp.gnu.org/gnu/texinfo/texinfo-4.13a.tar.gz \
 && tar -zxvf texinfo-4.13a.tar.gz
RUN cd texinfo-4.13 \
 && ./configure \
 && make -j $MAKE_NO_PROC \
 && make install

## Install propeller-gcc compiler
ENV PATH="${PROPELLER_PREFIX}/bin:$PATH"
RUN git clone https://github.com/parallaxinc/propgcc propgcc
RUN cd propgcc \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/bfd/doc/bfd.texinfo \
 && sed -i -e 's/@colophon/@@colophon/' -e 's/doc@cygnus.com/doc@@cygnus.com/' binutils/ld/ld.texinfo \
 && make PREFIX="${PROPELLER_PREFIX}" ERROR_ON_WARNING=no

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
#RUN curl -O https://download.qt.io/archive/qt/5.4/5.4.0/single/qt-everywhere-opensource-src-5.4.0.tar.gz \
#&& tar -zxvf qt-everywhere-opensource-src-5.4.0.tar.gz \
#&& cd qt-everywhere-opensource-src-5.4.0 \
#&& ./configure -prefix QtNew -release -opensource -confirm-license -static -qt-xcb -no-glib -no-pulseaudio -no-alsa -opengl desktop -nomake examples -nomake tests \
#&& make -j $MAKE_NO_PROC \
#&& make install
### FIXME install qt5.4 from source because run works only with gui
RUN git clone https://github.com/parallaxinc/SimpleIDE.git SimpleIDE
RUN cd SimpleIDE \
 && bash plinrelease.sh

# ENTRYPOINT
USER $AUSER
WORKDIR $AHOME
SHELL ["/bin/bash", "-c"]
VOLUME /tmp/.X11-unix
VOLUME /mnt/data
ENTRYPOINT bash
