FROM docs/base:latest
MAINTAINER Mary Anthony <mary@docker.com> (@moxiegirl)

WORKDIR /src

COPY requirements.txt /src/
RUN pip install -r requirements.txt

COPY make.sh /usr/local/bin/

COPY . /src/

ENTRYPOINT ["/usr/local/bin/make.sh"]
