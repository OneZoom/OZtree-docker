## Creating a bespoke OneZoom instance with your own photos

You can substitute your own photos or images into a docker version of OneZoom by using
the `add_bespoke_images.py` script, in the `OZprivate/ServerScripts/Utilities/` directory.
Images of any size and shape can be used, but it will look better if you use square
images. The higher the image resolution, the more bandwidth it will take to zoom around
the tree; for this reason, on the main OneZoom
site we use thumbnail images whose height and width are only a few hundred pixels.

It is possible to create either a OneZoom instance in which the standard set of images
are *supplemented* by your own images, or one with *only* your own images. The latter is
done by using the `-d` flag when running the `add_bespoke_images.py` script.

### Setup

Your own images should be placed in a specific folder, in jpg format, and named using
the species name (either spaces or underscores can be used in the name, e.g.
`Homo_sapiens.jpg`). Each image can also have a "rating" which,
along with its position on the tree, determines how likely it is to be used as a
representative image of the group in which it occurs (and whether it will be shown
in the set of representative images on higher-level internal nodes of the tree). The
ratings range from 0 (terrible quality) to 50000 (best quality). Your own images
can be given ratings by prefixing the name with a number: e.g. if you have a very good
quality image of a human that you wish to use on your tree, you can give it a rating
of 45000 by naming it `45000_Homo_sapiens.jpg`. Images with no rating will be given a
"standard" rating of 25000.

To place images in the correct place on the tree, the species name needs to be converted
to an "Open Tree Taxonomy" ("OTT") number. This is done in the script by looking up the
species name in the Open Tree of Life
["Taxonomic Name Resolution Service"](https://github.com/OpenTreeOfLife/germinator/wiki/Open-Tree-of-Life-Web-APIs#tnrs-methods)
(TNRS). Since species in different kingdoms (e.g. plants and animals) can have identical
names, it can be helpful to provide a ["taxon context"](OpenTreeOfLife/germinator/wiki/TNRS-API-v3#contexts)
to the TNRS, so that the name-matching
can be accurately targetted at the right taxonomic group. Taxonomic contexts include e.g.
"Vascular plants", "Animals", "Arthropods", "Bacteria", etc. You can specify the taxonomic
context by placing images in a folder by that name. Alternatively, you can look up the
Open Tree Taxonomy number yourself, on the [OpenTree website](https://tree.opentreeoflife.org),
and use that number prefixed by "ott", instead of or in addition to the species name. For
example, the OTT number for humans is 770315, so to avoid using the TNRS, you could name
your file `ott770315.jpg` or `ott770315_Homo_sapiens.jpg` (or `45000_ott770315.jpg` to
give a rating of 45000).

Here is an example of a set of images saved in an `img` directory, some of which will be
looked up using the `Insects` and `Vascular plants` taxon contexts:

```
img/45000_ott770315.jpg
img/Gorilla_gorilla.jpg
img/Vascular plants/Pieris_japonica.jpg.jpg
img/Insects/42000_Pieris_japonica.jpg
img/Insects/Coccinella septempunctata.jpg
```

Note that some species (especially fossil species) may be missing from the OneZoom tree.

#### Source, copyright, and other metadata

If these are your own image thumbails, you are likely to want to show your name and
copyright or licence information on the images (on OneZoom, these will be shown when
you zoom into the copyright symbol, or when you click on it). You can also provide
source information, usually in the form of a URL to the original image.

To specify these, you need to add the information to the image IPTC metadata (this also
means the information is saved with the photos if they are downloaded). You can use
an external photoshop-like editor to do this, by adding the rights to the `credit`
field, the licence to the `copyright notice` field and the source information to the
`source` field. Alternatively, you can use the `set_image_info.py` script, in the
`OZprivate/ServerScripts/Utilities/` directory. For example, you could specify
a specific image cannot be reused by

```
OZprivate/ServerScripts/Utilities/set_image_info.py img/Gorilla_gorilla.jpg \
  -r "© Me" -l "All rights reserved" -s "https://my.source.url/gorilla"
```

Or you could put all low resolution versions in the public domain by making sure the
images are (say) 150x150 pixels, and specifying the entire directory of images

```
OZprivate/ServerScripts/Utilities/set_image_info.py img \
  -r "© Me" -l "Released into the public domain" -s "https://my.source.url"
```

If you don't have a copy of the `set_image_info.py` script, you can run it
within the docker container, e.g. running the following between steps 2 and 3 below (note
the backslashes required to pass the strings through to the docker container:

```
docker exec -it running_onezoom OZprivate/ServerScripts/Utilities/set_image_info.py /tmp/img \
 -r \\"© Me\\" -l \\"Released into the public domain\\" -s \\"https://my.source.url\\"
```

### Installation

Instead of running the image in the normal way, you should use the `-v` option to mount
your local directory of images, say `~/img`, into the docker image, then once the IUCN
processing is finished, you can run the `add_bespoke_images.py` script, having first
installed the python library iptcinfo3 (needed to read the IPTC information). Here are
the steps:

```
# 1) Use the -v option to mount a local directory, here ~/img into /tmp/img on docker
docker run -v ~/img:/tmp/img -p 8080:80 --name running_onezoom onezoom/oztree-complete

# Wait for IUCN processing to finish ("IUCN DONE!" printed; could be 15 minutes or more)
# then run the following 2 commands in a different window

# 2) Install iptcinfo3 on the container
docker exec -it running_onezoom python3 -m pip install iptcinfo3  # May warn about installing as root
# 3) Run `add_bespoke_images.py`. This may take some time to complete: omit the `-d` flag
#    to supplement the existing images with your own rather than removing existing photos
docker exec -it running_onezoom OZprivate/ServerScripts/Utilities/add_bespoke_images.py -d -vv /tmp/img

# 4) Save the running container for reuse
docker commit --change="CMD /sbin/my_init" running_onezoom onezoom/oztree-bespoke-images-with-iucn
```

Then in future you can launch that image using

```
docker run -p 8080:80 onezoom/oztree-bespoke-images-with-iucn
```

Which will run OneZoom with your images embedded in it, and without re-populating the
IUCN data. Note that if you are using the `-d` flag, you can save some space by using the
`onezoom/oztree` docker image in the first step, rather than `onezoom/oztree-complete`.