FROM python:2.7.14-onbuild

# Install python packages required by helper scripts
COPY bin/requirements.txt /opt/bin/requirements.txt
RUN pip install -r /opt/bin/requirements.txt

COPY ncd-pipeline /opt/ncd-pipeline

WORKDIR /opt/ncd-pipeline

# Copy over scripts and set PATH
COPY bin /opt/bin
ENV PATH /opt/bin:$PATH

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
