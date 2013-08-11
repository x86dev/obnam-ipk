About
=====

A build, IPK packaging and installation script for Obnam backup.

This script mainly is for building Obnam on ARM-based devices
(like Marvell Kirkwood mv6282 on various Synology NASes). It also
resolves the necessary dependencies, does some patching (if required)
and outputs an installable .IPK file as a result.

You can get Obnam backup here: http://liw.fi/obnam/

Pre-built .IPK packages
========================

Pre-build IPK packages for ARMv5 are available for download 
within this repository [here](ipk).

I'll update them as soon as I got time and and a new Obnam version was released. 
The goal here is to make Obnam available on ARM platforms with as little modifications
as possible.

Please report bugs about those IPK packages, and also let me know if you're already
using them on a different platform / NAS as initially intended.

Usage
=====

For script usage, see the command line help with "--help". Tested
on x86_64 (Debian) and Synology DSM 4.1 with Optware installed.
