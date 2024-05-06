Anachrony build system
======================

**Anachrony** is a free and open-source smartwatch platform based on AsteroidOS, OpenEmbedded and B2G.

You can fully build a flashable image from source with the following commands, but be careful it will take several hours:

    . ./prepare-build.sh <your machine id, e.g., dory>
    bitbake anachrony-image
