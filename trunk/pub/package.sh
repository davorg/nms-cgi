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

main=`head -1 $p/MANIFEST`;
grep '$Id: package.sh,v 1.2 2002-08-18 08:53:00 davorg Exp $main | head -1 | perl -ne '/\$Id: package.sh,v 1.2 2002-08-18 08:53:00 davorg Exp $1' > $p.VER
