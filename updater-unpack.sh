#! /sbin/sh

FS_ARC="/data/sffe-%DEVICE%-%VERSION%.tar.bz2"
FS_DST="/data/.stowaways/sailfishos"

rm -rf $FS_DST
mkdir -p $FS_DST
tar --numeric-owner -xvjf $FS_ARC -C $FS_DST

rm $FS_ARC

