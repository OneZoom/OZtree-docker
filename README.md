# OZtree-docker

The Dockerfile in this directory can be used to build a fully functioning OneZoom docker image.

## Creating the sql datafile

To build, the `sql_data` folder should contain a download dump of the public contents of the OneZoom
databases (e.g. without the reservations table contents) in `.sql` format . Such a dump
is not included in this repo as it is large and changable. We suggest naming it something like
"onezoom_prod_2021-04-30.sql"

Appropriate sql dumps can be created using 

```
mysqldump onezoom_prod ordered_leaves ordered_nodes images_by_name images_by_ott quotes tree_startpoints vernacular_by_name vernacular_by_ott -u onezoom -p > onezoom_prod_YYYY-MM-DD.sql
```

or in e.g. SequelAce, by selecting all the tables listed above for export.

Note that if you are exporting
from a mysql 5.7 instance you may need to search and delete the "NO_AUTO_CREATE_USER" string from the sql file
so that the commands are valid for MySQL server 8.0 - this can be done with e.g.
`sed -i 's/NO_AUTO_CREATE_USER//' onezoom_prod_YYYY-MM-DD.sql`.

## Building the image

Once a db dump has been created, the docker image can be generated using 

```
docker build -t onezoom/oztree
```

Which, if done from scratch, will take of the order of 30 minutes to build an image and
load the tables into the database. The image is based off
[onezoom/docker-nginx-web2py-min-mysql](https://hub.docker.com/repository/docker/onezoom/docker-nginx-web2py-min-mysql)
and uses [onezoom/alpine-compass-python-perl-node](https://hub.docker.com/repository/docker/onezoom/alpine-compass-python-perl-node)
to compile the javascript code, scss files, and docs.

## Running the image

When running the generated image, to access the running web server you need to define the http
port to open, e.g. to use 8080, run 

```
docker run -p 8080:80 --name running_onezoom onezoom/oztree
```

(you may also wish to add `-p 3306:3306` if you want to view the database from outside the
docker container). You can then access the OneZoom instance at
[http://localhost:8080](http://localhost:8080) or the
viewer directly at [http://localhost:8080/life](http://localhost:8080/life)

Because we are not allowed to package the IUCN data in this image, when the standard
onezoom/oztree image is run, it waits for the web server to be set up, then downloads the
IUCN data from http://apiv3.iucnredlist.org/ which can take about 10 minutes and makes
several large requests to the IUCN server (outputting console information as it does so).
It can be tedious and unnecessary to have to re-download the IUCN data if you are regularly
starting and stopping the same OneZoom image. To avoid this, once the IUCN processing has
finished (when "IUCN DONE!" is output to the console), you can commit a new image using:

```
docker commit running_onezoom onezoom/oztree-with-iucn
```

then in future you can launch that image using

```
docker run -p 8080:80 onezoom/oztree-with-iucn /sbin/my_init
```

which will run OneZoom without re-populating the IUCN data.

