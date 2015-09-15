# This docker file draws on following sources:
# https://github.com/io-informatics/transmart-docker/blob/bd13868820ab7b7611bbd0672fe9906a76083842/1.2.4/embedded/Dockerfile
# https://github.com/quartzbio/transmart-docker/blob/15939cd8d09194a6a5c34b8f5a566fad45450745/Dockerfile
# https://wiki.transmartfoundation.org/pages/viewpage.action?pageId=6619205
# https://wiki.transmartfoundation.org/display/TSMTGPL/tranSMART+1.2+INSTALLATION+NOTES+ON+UBUNTU
# and general Docker information at https://docs.docker.com/ (docs)

FROM tomcat:7-jre8
MAINTAINER Terry Weymouth <terry.weymouth@transmartfoundation.org>

# ==================== supporting tools ====================

RUN apt-get update && \
	apt-get install -y \
	build-essential         \
	sudo                    \
	curl                    \
	git                     \
	openjdk-7-jdk           \
	groovy                  \
	php5-cli                \
	php5-json               \
	apache2                 \
	libtcnative-1           \
	xz-utils                \
	rsync                   \
	r-base                  \
	libcairo2-dev           \
	supervisor

#Install R dependencies
ADD biocLite.R /tmp/biocLite.R
ADD install-packages.R /tmp/install-packages.R
RUN echo "r <- getOption('repos'); r['CRAN'] <- 'http://cran.us.r-project.org'; options(repos = r);" > ~/.Rprofile
RUN Rscript /tmp/install-packages.R

## Configure default locale: TODO, put it below, before transmart
RUN sudo bash -c 'echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8'
ENV LC_ALL en_US.UTF-8

# =========== setup USER transmart and home dir =============
RUN useradd -m transmart
# sudo with no password
RUN echo "transmart ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
ENV HOME /home/transmart

USER transmart
WORKDIR /home/transmart

# ================== load transmart data ===================

RUN git clone --progress https://github.com/transmart/transmart-data.git
WORKDIR /home/transmart/transmart-data

RUN php env/vars-ubuntu.php > vars

### STEP: Create transmart database table-spaces and schema
RUN sudo service postgresql start && \
	 sudo -u postgres bash -c \
 	 "source vars; PGSQL_BIN=/usr/bin/ PGDATABASE=template1 make -C ddl/postgres/GLOBAL tablespaces" && \
 	 bash -c "source vars && make -j6 postgres && \
	 make -C ddl/postgres/META fix_permissions fix_owners fix_tablespaces"

### STEP: Prepare ETL environment
# # karl: need xz-utils to uncompress data

#### apparently not needed, dixit Florian, but not sure...
RUN bash -c 'source vars && \
 	make -C env/ data-integration && \
 	make -C env/ update_etl'

# ### STEP:  example studies
# karl: fix, must update the git repo first and re-run data-integration
#RUN git pull origin master && \
#RUN 	bash -c 'source vars && make -C env/ data-integration'

#COPY GSE19976.zip /home/transmart/transmart-data/
#COPY v12_GSE19976_clin.sh /home/transmart/transmart-data/
RUN sudo rm -f /var/run/postgresql/.s* /var/run/postgresql/* /var/lib/postgresql/9.3/main/postmaster.pid && \
 		sudo service postgresql start && bash -c 'source vars && \
 		make -C samples/postgres load_clinical_GSE8581 load_ref_annotation_GSE8581 \
 		load_expression_GSE8581'&& \
 		sudo service postgresql stop

# postgres cleanup: -> non clean shutdown
RUN sudo rm -f /var/run/postgresql/.s* /var/run/postgresql/* /var/lib/postgresql/9.3/main/postmaster.pid

# ==================== set up transmart ====================

### STEP: Copy tranSMART configuration files
RUN sudo bash -c "source vars; TSUSER_HOME=/usr/share/tomcat7/ make -C config/ install"

# create the tomcat tmp dir
RUN sudo mkdir /var/lib/tomcat7/tmp && sudo chown tomcat7:tomcat7 /var/lib/tomcat7/tmp

# ### STEP: Install and run solr
#  karl: N.B, modified to only install
RUN bash -c "source vars; make -C solr/ solr_home"
# karl (from Florian): fix the solr port in groovy config
RUN sudo perl -pi'.bak' -e 's/(def solrPort\s+=\s+)\d+/$1 8983/ ' /usr/share/tomcat7/.grails/transmartConfig/Config.groovy

### STEP: Configure and start Rserve
#  karl: N.B, will just configure it for now
RUN echo 'USER=tomcat7' | sudo tee /etc/default/rserve

### STEP: Deploy tranSMART web application on tomcat.
RUN echo 'JAVA_OPTS="-Xmx4096M -XX:MaxPermSize=1024M"' | sudo tee /usr/share/tomcat7/bin/setenv.sh

### STEP: set permissions on .grails
RUN sudo chown -R tomcat7.tomcat7 /usr/share/tomcat7/.grails

### STEP: transmart WAR (web app archive) 
# N.B: put this as late as possible to make sure that reloading transmart.war minimizes changes and change time
# Currently  this is the latest, successfully built, 1.2.X snapshot version

USER tomcat7
ENV TRANSMART_URL https://ci.transmartfoundation.org/browse/SAND-TRAPP/latestSuccessful/artifact/shared/transmart.war/transmart.war
WORKDIR /var/lib/tomcat7/webapps
RUN rm -f transmart.war && \
	curl -# $TRANSMART_URL > transmart.war

########################### SUPERVISOR ######################################

USER root

RUN apt-get install -y --no-install-recommends supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# ==================== karl: configure postgres for external connections ========
# replace existing listen_addresses entry by our own
RUN perl -i -pe "s/.*listen_addresses.+/listen_addresses = '*'/" /etc/postgresql/9.3/main/postgresql.conf
# allow any connection to postgres
RUN echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/9.3/main/pg_hba.conf

ENV TERM xterm

# for tomcat
EXPOSE 8080
# for solr
EXPOSE 8983

# for postgres
EXPOSE 5432

CMD /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

