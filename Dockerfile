FROM node:16-buster

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y less awscli \
#
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*


RUN npm install -g hirenj/node-reciperunner

RUN mkdir -p /build

COPY . /build

WORKDIR /build

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=

CMD /build/run_taxonomies.sh 9606,7227,6239,284812,559292,9823,10090,10116,10029