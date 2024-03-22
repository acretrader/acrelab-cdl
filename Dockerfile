#sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin STEPS:
# 1. Navigate to flavortown/gssurgo directory
# 2. docker build --no-cache -t gssurgo_ingest:latest .
# 3. docker run --network=host -it --rm gssurgo_ingest:latest -v /path/to/gssurgo_conus_zip_files:/home/gssurgo_raw_data/. /bin/bash

# REQUIREMENTS:
# .netrc file with personal access token to GitHub stored in flavortown/gssurgo directory
# .pgpass file with PostgreSQL connection creds stored in flavortown/gssurgo directory

# Use alpine for acrectl install
FROM alpine as acrectl-build

RUN apk --no-progress update && \
apk --no-progress add git zsh skopeo github-cli jq gojq jo curl && \
apk --no-progress --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing add hub && \
/bin/sh -c "$(/usr/bin/wget -qO - https://acrectl.sh/install/Linux-alpine.sh)"          

# Use osgeo/gdal as the base image
FROM ghcr.io/osgeo/gdal:latest as base

# Set the working directory inside the container
WORKDIR /home

# Copy files from the local directory into the container's working directory
COPY --from=acrectl-build /usr/bin/acrectl /usr/bin/acrectl                                                                                           
COPY .netrc /root/.netrc
COPY .pgpass /root/.pgpass

RUN chmod 600 /root/.pgpass
RUN chmod 600 /root/.netrc

# update and install CLI utilities
RUN apt-get update 
RUN apt-get install -y zip
RUN apt-get install -y postgresql-client
RUN apt-get install -y git
RUN apt-get install -y inetutils-ping
RUN apt-get install -y zsh 
RUN apt-get install -y vim
RUN apt-get install -y groff
RUN apt-get install -y wget
RUN apt-get install -y curl
RUN apt-get install -y unzip
RUN apt-get install -y --no-install-recommends gdal-bin
RUN apt-get install -y build-essential
RUN apt-get install -y libsqlite3-dev 
RUN apt-get install -y pgloader 
RUN apt-get install -y libsqlite3-mod-spatialite 
RUN apt-get install -y ca-cacert 
RUN apt-get install -y zlib1g-dev 

# zsh environment
ENV SHELL=zsh
RUN chsh -s $(which zsh)

# Python and environment management
RUN curl https://pyenv.run | sh
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.${SHELL##*/}rc
RUN echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.${SHELL##*/}rc
RUN echo 'eval "$(pyenv init -)"' >> ~/.${SHELL##*/}rc
RUN exec $SHELL

# Install Python Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
RUN echo "export PATH="/home/john/.local/bin:$PATH"" >> ~/.${SHELL##*/}rc
RUN exec $SHELL

# GitHub repositories
RUN git clone https://github.com/acretrader/acreops-migrate.git

# ------------------------------- APPLICATION SPECIFIC CODE ----------------------------------
# Application/job specific files
COPY ./cdl_california_crop_merge/ /home/cdl/
COPY ./cdl_ingest/ /home/cdl/
COPY ./pyproject.toml /home/cdl/

