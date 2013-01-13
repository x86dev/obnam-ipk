obnam_build
===========

A build, IPK packaging and installation script for Obnam backup.

This script mainly is for building Obnam on ARM-based devices
(like Marvell Kirkwood mv6282 on various Synology NASes). It also
resolves the necessary dependencies, does some patching (if required)
and outputs an installable .IPK file as a result.

You can get Obnam backup here: http://liw.fi/obnam/

For script usage, see the command line help with "--help". Tested
on x86_64 (Debian) and Synology DSM 4.1 with Optware installed.
