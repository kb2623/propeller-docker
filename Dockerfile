FROM debian:buster-slim

ARG AUSER=propeller
ARG AUSER_ID=1000
ARG AGROUP=propellers
ARG AGROUP_ID=1000
ARG AHOME=/home/$AUSER

# Install programs
USER root
WORKDIR /root

RUN apt update \
 && apt install -y ca-certificates vim-gtk3 git bash curl tmux universal-ctags fonts-firacode gcc g++ qt5-default gdb make xserver-xorg-dev \
 && apt clean

# Make skel dir
USER root
WORKDIR /etc/skel
SHELL ["/bin/bash", "-c"]

ADD .vimrc .
ADD .bashrc .
ADD .tmux.conf .
RUN curl -fLo .vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Create a user
USER root
WORKDIR /root
SHELL ["/bin/bash", "-c"]

ADD createuser.sh /root
RUN chmod a+x createuser.sh \
 && ./createuser.sh $AUSER $AUSER_ID $AGROUP $AGROUP_ID $AHOME \
 && rm createuser.sh
RUN mkdir -p /mnt/data \
 && chown -R $AUSER:$AGROUP /mnt/data \
 && ln -s /mnt/data $AHOME/data \
 && chown $AUSER:$AGROUP $AHOME/data

# Make propeller
USER $AUSER
WORKDIR $AHOME
SHELL ["/bin/bash", "-c"]

## Install propeller-gcc compiler
RUN git clone https://github.com/parallaxinc/propgcc.git propgcc \
 && cd propgcc \
 && make \
 && make install

## Install Spin/PASM compiler for the Parallax Propeller
RUN git clone https://github.com/parallaxinc/OpenSpin.git OpenSpin \
 && cd OpenSpin \
 && make \
 && make install

## Install Parallax Propeller loader supporting both serial and wifi downloads
RUN git clone https://github.com/parallaxinc/PropLoader.git PropLoader \
 && cd PropLoader \
 && make \
 && make install

## Install SimpleIDE
RUN git clone https://github.com/parallaxinc/SimpleIDE.git SimpleIDE \
 && cd SimpleIDE \
 && make \
 && make install

# ENTRYPOINT
USER $AUSER
WORKDIR $AHOME
SHELL ["/bin/bash", "-c"]
VOLUME /tmp/.X11-unix
VOLUME /mnt/data
ENTRYPOINT bash
