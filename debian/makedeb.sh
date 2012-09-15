#!/bin/sh
mydate=`date +%Y%m%d%H%M`
mynamedeb="traco-$mydate.deb"
mynametgz="traco-$mydate.tgz"
mysrc=/home/vdr/tracodev
mydst=/home/vdr/debian/traco
mynewversion="Version: $mydate";

files="tracoadm.pl tracosrv.pl"
libs="Traco.pm Tracoio.pm Tracoxml.pm Tracoprofile.pm Tracorenamefile.pm"
cfgs="traco.conf reccmds.traco.conf"

if [ -f traco/DEBIAN/md5sums ] ; then
        rm traco/DEBIAN/md5sums
fi

for f in $files ; do 
        echo "copy program $f"
        cp $mysrc/$f $mydst/usr/bin

        echo "set correct permmissions for $f"
        chmod 755 $mydst/usr/bin/$f

        echo "add checksum to DEBIAN/md5sums for $f"
        md5sum "$mydst/usr/bin/$f" >> traco/DEBIAN/md5sums
done

for l in $libs ; do
        echo "copy library $l"
        cp $mysrc/$l $mydst/usr/lib/perl5/Traco

        echo "set correct permmissions for $l"
        chmod 644 $mydst/usr/lib/perl5/Traco/$l

        echo "add checksum to DEBIAN/md5sums for $l"
        md5sum $mydst/usr/lib/perl5/Traco/$l >> traco/DEBIAN/md5sums
done
        echo "copy config files"
        cp $ymsrc/etc/vdr/traco.conf $mydst/etc/vdr/traco.conf.sample
        cp $ymsrc/etc/vdr/command-hooks/reccmds.traco.conf $mydst/etc/vdr/command-hooks/reccmds.traco.conf.sample
        md5sum $mydst/etc/vdr/traco.conf.sample >> traco/DEBIAN/md5sums
        md5sum $mydst/etc/vdr/command-hooks/reccmds.traco.conf.sample >> traco/DEBIAN/md5sums

echo "change DEBIAN/control Version to new $mynewversion"
perl replace_version.pl "$mynewversion"

echo "build package $mynamedeb"
dpkg -b ./traco $mynamedeb
echo "build package $mynametgz" 
tar -czvf $mynametgz ./traco


