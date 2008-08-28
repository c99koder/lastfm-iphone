#!/bin/bash
echo Updating project..
svn update > /dev/null
VERSION=`svnversion|sed "s/M//g"`
echo Updated to version $VERSION
mkdir English-$VERSION
for i in `ls Resources/English.lproj/*.xib`; do
ibtool --generate-strings-file English-$VERSION/`basename $i`.strings $i
done
cp Resources/English.lproj/Localizable.strings English-$VERSION/
