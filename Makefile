DOCKER_NAME:=propeller
DOCKER_TAG:=debian-buster
DOCKER_VOLUME_SRC=/tmp/${DOCKER_NAME}_${DOCKER_NAME}
# User data
DOCKER_USER:=propeller
DOCKER_USER_ID:=1000
DOCKER_GROUP:=propellers
DOCKER_GROUP_ID:=1000

USB_DEVICE:=/dev/ttyUSB0

MAKE_NO_PROC:=3

all: build run

volume:
	mkdir -p ${DOCKER_VOLUME_SRC}
	chown -R ${DOCKER_USER_ID}:${DOCKER_GROUP_ID} ${DOCKER_VOLUME_SRC}

clean_volume: ${DOCKER_VOLUME_SRC}
	rm -rf ${DOCKER_VOLUME_SRC}

build:
	docker build \
		--build-arg AUSER=${DOCKER_USER} \
		--build-arg AUSER_ID=${DOCKER_USER_ID} \
		--build-arg AGROUP=${DOCKER_GROUP} \
		--build-arg AGROUP_ID=${DOCKER_GROUP_ID} \
		--build-arg MAKE_NO_PROC=${MAKE_NO_PROC} \
		-t ${DOCKER_NAME}-image:${DOCKER_TAG} .

xorgHosts:
	xhost +

run:
	docker run -ti --rm \
		-e DISPLAY=${DISPLAY} \
		-v /tmp/.X11-unix:/tmp/.X11-unix:rw \
		-v ${DOCKER_VOLUME_SRC}:/mnt/data \
		--device /dev/dri \
		--device /dev/snd \
		--device ${USB_DEVICE} \
		--hostname=${DOCKER_NAME} \
		--net=host \
		${DOCKER_NAME}-image:${DOCKER_TAG}

clean:
	-make clean_volume
	docker image rm ${DOCKER_NAME}-image:${DOCKER_TAG}
