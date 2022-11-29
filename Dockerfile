FROM python:3.10-slim-buster as builder

LABEL description="ElastAlert2 Custom Image"
LABEL maintainer="son@tradingstrategy.ai"

COPY . /tmp/elastalert

RUN mkdir -p /opt/elastalert && \
    cd /tmp/elastalert && \
    pip install setuptools wheel && \
    python setup.py sdist bdist_wheel

FROM python:3.10-slim-buster

ARG GID=1000
ARG UID=1000
ARG USERNAME=elastalert

COPY --from=builder /tmp/elastalert/dist/*.tar.gz /tmp/

RUN apt update && apt -y upgrade && \
    apt -y install ssh jq curl gcc libffi-dev && \
    rm -rf /var/lib/apt/lists/* && \
    pip install /tmp/*.tar.gz && \
    rm -rf /tmp/* && \
    apt -y remove gcc libffi-dev && \
    apt -y autoremove && \
    mkdir -p /opt/elastalert && \
    echo "#!/bin/sh" >> /opt/elastalert/run.sh && \
    echo "set -e" >> /opt/elastalert/run.sh && \
    echo "elastalert-create-index --config /opt/elastalert/config.yaml" \
        >> /opt/elastalert/run.sh && \
    echo "elastalert --config /opt/elastalert/config.yaml \"\$@\"" \
        >> /opt/elastalert/run.sh && \
    chmod +x /opt/elastalert/run.sh && \
    groupadd -g ${GID} ${USERNAME} && \
    useradd -u ${UID} -g ${GID} -M -b /opt -s /sbin/nologin \
        -c "ElastAlert 2 User" ${USERNAME}

RUN mkdir /opt/${USERNAME}/.ssh 
ADD ./ssh /opt/${USERNAME}/.ssh
RUN chown ${USERNAME}:${USERNAME} -R /opt/${USERNAME}/.ssh 
RUN chmod 700 /opt/${USERNAME}/.ssh
RUN chmod 600 /opt/${USERNAME}/.ssh/*

USER ${USERNAME}
ENV TZ "UTC"

WORKDIR /opt/elastalert
ENTRYPOINT ["/opt/elastalert/run.sh"]
