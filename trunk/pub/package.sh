#!/bin/sh

p=$1

cd $1
cvs2cl.pl --revisions
cd ..

tar cvf $p.tar `cat $p/MANIFEST`
gzip $p.tar

unix2dos -k `cat $p/MANIFEST`
zip $p.zip -@ < $p/MANIFEST 
dos2unix -k $p/MANIFEST
dos2unix -k `cat $p/MANIFEST`
