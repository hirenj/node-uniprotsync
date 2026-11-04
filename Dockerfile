FROM node:lts

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

# The orchestrator runs this image with --user <host-uid>:<host-gid> (needed so its /dist bind
# mount, written at runtime, ends up owned by the host user) - but COPY above lands everything in
# /build owned by root, and run_taxonomies.sh writes intermediates (sources/mappings.tsv, json/)
# inside /build itself, not just to /dist. Without this, those writes fail EACCES under a non-root
# --user. a+rwX, not a narrower chmod, since the exact files written vary by taxid run.
RUN chmod -R a+rwX /build

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=

CMD /build/run_taxonomies.sh 9606,7227,6239,284812,559292,9823,10090,10116,10029
