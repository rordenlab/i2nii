#!/bin/sh
# change to working directory to location of command file: http://hints.macworld.com/article.php?story=20041217111834902
here="`dirname \"$0\"`"
cd "$here" || exit 1
rm -rf *.o
rm -rf *.ppu
rm -rf *.nii
rm -rf lib
rm -rf backup
strip i2nii
cd test
rm -rf *.nii
