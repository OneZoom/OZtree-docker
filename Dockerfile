# syntax=docker/dockerfile:1

# This dockerfile intended to be built in this directory as
# docker build -t onezoom/oztree .

# To force a refresh of the image, e.g. if the OneZoom or web2py versions have changed,
# you may need to clear all caches, using `docker builder prune -a`
#
# When running the image, to access the running web server you need to define the http
# port to open, e.g. to use 8080, run `docker run -p 8080:80 onezoom/oztree` or in the
# Docker GUI app, select the Optional Settings when choosing how to run the image and
# specify  e.g port 8080 as a Local Host post corresponding to the container port 80.
# You can then access the OneZoom instance at http://localhost:8080 or the
# viewer directly at http://localhost:8080/life
#
# Because we are not allowed to package the IUCN data in this image, when the standard
# onezoom/oztree image is run, after the web server is set up, it downloads the IUCN
# data from http://apiv3.iucnredlist.org/. If you are starting and stopping OneZoom
# instances many times, it can be tedious to have to re-download the IUCN data each time,
# so once IUCN processing has finished, you might want to commit the image and change the
# default CMD so that IUCN is not queried on startup:
#   docker commit --change="CMD /sbin/my_init" running_image_name onezoom/oztree-with-iucn
# then you can simply launch that image using
#   docker run -p 8080:80 onezoom/oztree-with-iucn
# which will run OneZoom without re-populating the IUCN data


## First stage - download Web2py + OneZoom and compile
#   Here we download the latest web2py and OneZoom versions from github, and compile the site

FROM onezoom/alpine-compass-python-perl-node:12 as compile_web2py
WORKDIR /opt/tmp
RUN git clone --recursive https://github.com/web2py/web2py.git --depth 1 --branch v2.21.1 --single-branch web2py
WORKDIR /opt
ENV WEB2PY_MIN=1
RUN if [ "${WEB2PY_MIN}" == true ]; then \
      cd tmp/web2py; \
      python3 scripts/make_min_web2py.py ../../tmp/web2py-min; \
      mv ../../tmp/web2py-min ../../web2py; \
      cd ../../; \
    else \
      mv tmp/web2py web2py; \
    fi; \
    rm -rf tmp
WORKDIR web2py/applications
RUN git clone https://github.com/OneZoom/OZtree.git --single-branch OZtree
WORKDIR OZtree
RUN git fetch --tags
RUN cp _COPY_CONTENTS_TO_WEB2PY_DIR/routes.py ../../
# install node modules outside of current dir, so they aren't copied over
RUN mkdir /tmp/node_modules && ln -s /tmp/node_modules ./node_modules
RUN npm install
RUN grunt prod


## Second stage - create database files & populate database
#   Here we run a webserver, access the OneZoom site (which creates the DB tables)
#   and then overwrite the necessary tables with a recent DB dump in sql_data

FROM onezoom/docker-nginx-web2py-min-mysql:8.0 as base

FROM base as create_database
ENV MYSQL_DATABASE=OneZoom
ENV MYSQL_USERNAME=oz
ENV MYSQL_PASSWORD=passwd
ENV MYSQL_ROOT_PASSWORD=passwd
ENV WEB2PY_ADMIN=passwd
VOLUME ["/sql_data"]
COPY --from=compile_web2py /opt/web2py /opt/web2py
COPY sql_data /sql_data
WORKDIR /opt/web2py/applications/OZtree
COPY appconfig.ini private/appconfig.ini
# Poll to check when the webserver is ready and OZtree is accessible, then access it so that
# web2py can create the database description files. Then upload all sql dumps into the DB.
RUN /sbin/my_init & \
    until curl -N -i -s -L http://localhost/OZtree | head -n 1  | cut -d ' ' -f2 | grep -q 200; \
      do \
        sleep 10;\
        echo " $(date +'%T'): waiting for server ... "; \
      done; \
    echo "Server active - waiting 5 secs for web2py to create database description files"; \
    sleep 5; \
    echo "Reading .sql files from /sql_data/ into database (could take e.g. 20 mins) ..."; \
    for filename in /sql_data/*.sql; do \
      echo "... loading $filename"; \
      mysql "${MYSQL_DATABASE}" -h localhost -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" \
        < "$filename"; \
    done; \
    echo "Force setting indexes - 1091 ERRORs about failing to DROP indexes are harmless and can be ignored"; \
    mysql "${MYSQL_DATABASE}" -f -h localhost -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" \
      < OZprivate/ServerScripts/SQL/create_db_indexes.sql;
# We seem to need a blank CMD here to force the next FROM to be treated as a separate stage
CMD sh


## Third stage - copy app & created files into new image. No db name or username needed
##  as these should already be present in the DB files loaded into MYSQL_DATA_DIR

FROM base as final
ENV MYSQL_DATABASE=''
ENV MYSQL_USERNAME=''
ENV MYSQL_PASSWORD=''
# use a permanent data dir (i.e. not /var/lib/mysql) so the data is not overwritten
ENV MYSQL_DATA_DIR=/var/lib/mysql_permanent
# copy the DB files from the previous image
COPY --from=create_database "/var/lib/mysql" "${MYSQL_DATA_DIR}"
# copy the compiled app including db description files
WORKDIR /opt/web2py/
COPY --from=create_database /opt/web2py ./
# copy JPG images (if any) from the img directory on the 
WORKDIR applications/OZtree
COPY img static/FinalOutputs/img
# Remove the line "url_base = //images.onezoom.org/" if there are directories in static/FinalOutputs/img
# Which will make the OneZoom instance include any JPGs from the Local Host in the docker image
RUN if [ -n "$(ls -d static/FinalOutputs/img/*)" ]; then sed -i "/^url_base/d" private/appconfig.ini ; fi;
# Uncomment 3306 line below & publish the port (-p 3306:3306) to be able to access the DB
# EXPOSE 3306
EXPOSE 80
CMD ( \
      until curl -N -i -s -L http://localhost/OZtree | head -n 1  | cut -d ' ' -f2 | grep -q 200; \
        do \
          sleep 10;\
          echo 'Waiting for server... '; \
        done; \
      echo 'Server active - downloading and processing IUCN data (~15 mins)'; \
      python3 -u /opt/web2py/applications/OZtree/OZprivate/ServerScripts/Utilities/IUCNquery.py -v; \
      echo 'IUCN DONE! OneZoom should be available on localhost under the port you specified'; \
    ) & exec /sbin/my_init
