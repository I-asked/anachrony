FROM ubuntu:focal

# Install packages required to build Anachrony
# And add the en_US.utf8 locale because it is required and not installed by default in minimal Ubuntu images
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y git build-essential cpio diffstat gawk chrpath texinfo python3 python3-distutils wget shared-mime-info zstd liblz4-tool locales \
    && rm -rf /var/lib/apt/lists/* && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.utf8

WORKDIR /anachrony
