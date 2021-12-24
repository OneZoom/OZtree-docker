# OZtree-docker

The OneZoom tree of life explorer provides an easy way to navigate the evolutionary tree that connects all living things.  It is a product of the OneZoom not for profit organisation registered in the UK. Our mission is to advance the education of the public in the subjects of evolution, biodiversity and conservation of the variety of life on earth.

You are looking either at a fully functional OneZoom tree of life explorer docker image, or the code required to make such an image.
If you are visiting this page to find out how to run an already-downloaded docker image
of OneZoom, e.g. downloaded from [docker hub](https://hub.docker.com) then go straight to
[Running the image](#running-the-image). 

Please note that the image contains both OneZoom software (use of which is subject to the OneZoom license https://www.onezoom.org/OZtree/static/downloads/OneZoom_License_V1.pdf) and third party data sources including images (please see https://www.onezoom.org/data_sources.html for more information).

Carry on reading if you want to find out how to create an image for yourself from the GitHub repository.

## Creating the sql datafile

To build, the `sql_data` folder should contain a download dump of the public contents of the OneZoom
databases (e.g. without the reservations table contents and without the IUCN data) in `.sql` format.
Such a dump is not included in this repo as it is large and changable. We suggest naming it
something like "onezoom_prod_2021-04-30.sql"

Appropriate sql dumps can be created from a running OneZoom database (e.g. `onezoom_dev`), ideally
after swapping all the the `ordered_nodes.IUCNxxx` columns for NULL:

```
update ordered_nodes set iucnNE = NULL, iucnDD = NULL, iucnLC = NULL, iucnNT = NULL, iucnVU = NULL, iucnEN = NULL, iucnCR = NULL, iucnEW = NULL, iucnEX = NULL;
```

Then doing

```
mysqldump onezoom_dev ordered_leaves ordered_nodes images_by_name images_by_ott quotes tree_startpoints vernacular_by_name vernacular_by_ott prices banned -u onezoom -p > onezoom_dev_YYYY-MM-DD.sql
```

or in e.g. SequelAce, by selecting all the tables listed above for export.

Note that if you are exporting
from a mysql 5.7 instance you may need to search and delete the "NO_AUTO_CREATE_USER" string from the sql file
so that the commands are valid for MySQL server 8.0 - this can be done with e.g.
`sed -i '' -e 's/NO_AUTO_CREATE_USER//' onezoom_prod_YYYY-MM-DD.sql`.

## Downloading thumbnails (optional)

If any folders exist in the top level directory called `img`, they are treated as containing
a large number of thumbnail images for use in OneZoom, and the
docker image will be built with these folders and their contents embedded in it. The folders
within the `img` directory correspond to the folder structure used by OneZoom: i.e.
top level folders are labelled by the image `src` (a number, specified
by the `src_flags` variable in `OZtree/models/_OZglobals.py`) then in a folder named
using the last 3 digits of the filename, then the numerically named image file itself).

Each thumbnail is associated with particular Creative Commons or public domain license, as
detailed in the database. The easiest way to see the license & source information for a 
thumbnail is to run the docker image and look at `tree/pic_info` page on the served-up site,
for example for `image_id=31652931` and `src=99`

```
http://localhost:${HTTP_PORT}/tree/pic_info/99/31652931.jpg
```

Assuming you have access to a OneZoom server with the correct images, and in your ssh
config file you have set up `OneZoom` as a host name to connect to this OneZoom server via
the correct port, you can create the img directory via rsync+ssh. For example, this is
what we run from within the main `OZtree-docker` directory:

```
OZtree_dir="OneZoomComplete/applications/OZtree"
rsync -av -e ssh web2py@OneZoom:${OZtree_dir}/static/FinalOutputs/img/ ./img
```

## Building the image

Once a db dump has been created, the docker image can be generated using 

```
if [ -n "$(ls -d img/*)" ]; then
  docker build -t onezoom/oztree-complete .
else
  docker build -t onezoom/oztree .
fi

```

Which, if done from scratch, will take of the order of 30 minutes to build an image and
load the tables into the database. The image is based off
[onezoom/docker-nginx-web2py-min-mysql](https://hub.docker.com/repository/docker/onezoom/docker-nginx-web2py-min-mysql)
and uses [onezoom/alpine-compass-python-perl-node](https://hub.docker.com/repository/docker/onezoom/alpine-compass-python-perl-node)
to compile the javascript code, scss files, and docs.

## Running the image

When running the generated image, you will need internet access to populate IUCN
information (see below), and also, if you have downloaded the version without embedded
images, to view the OneZoom image thumbnails.
You will also need to define the web server port to open. For example, to use 8080, run 

```
docker run -p 8080:80 --name running_onezoom onezoom/oztree-complete
```

(if running from the GUI, you can use the Optional Settings tab to map port 80 on the
container to e.g. 8080 on the local host)

### Accessing the database (optional)

If you want to access the database from outside the docker container, you may also wish
to add `-p 3306:3306` to the command, in which case you can access the database on port 3306 with the username
and password specified by the variables `MYSQL_USERNAME` and `MYSQL_PASSWORD` initially defined
in the [Dockerfile](Dockerfile#L64))

Once running, you can access the OneZoom instance at [http://localhost:8080](http://localhost:8080)
or the viewer directly at [http://localhost:8080/life](http://localhost:8080/life). However,
before doing this you may wish to wait about 15 mins for the IUCN data to be filled out
correctly (see the next paragraph).

### IUCN (extinction risk) data

The leaves in OneZoom are coloured by IUCN red list status. However, we are not allowed
to package the IUCN data in this image (this would also risk packaging information which
would become out of date). Therefore, when the standard `onezoom/oztree` image is run,
it waits for the web server to be set up, then downloads the IUCN data from
http://apiv3.iucnredlist.org/. This can take about 15 minutes and makes several large
requests to the IUCN server (outputting console information as it does so). It can be
tedious and unnecessary to have to re-download the IUCN data if you are regularly
starting and stopping the same OneZoom image. To avoid this, once the IUCN processing has
finished (when "IUCN DONE!" is output to the console), you can commit a new image using:

```
docker commit --change="CMD /sbin/my_init" running_onezoom onezoom/oztree-complete-with-iucn
```

then in future you can launch that image using

```
docker run -p 8080:80 onezoom/oztree-complete-with-iucn
```

which will run OneZoom without re-populating the IUCN data.

