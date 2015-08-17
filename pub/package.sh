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

d=\$
main=`head -1 $p/MANIFEST`
grep "${d}Id:" $main | head -1 | perl -ne 'print /Id:\D*(\d+\.\d+)/ ? $1 : "unknown"' > $p.VER
