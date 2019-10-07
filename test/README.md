## About

Sample images for validating i2nii. These are based on a [DICOM from a GE scanner](https://www.nitrc.org/plugins/mwiki/index.php/dcm2nii:MainPage#Archival_MRI). For example `i2nii -o ./test/sivic.idf` should create a NIfTI image sivic.nii.

## Installation

You can get MRIcroGL using three methods:

 - [afni.BRIK+orig.BRIK](https://afni.nimh.nih.gov/pub/dist/doc/program_help/README.attributes.html) was converted with [3dcopy (19.2.24)](https://afni.nimh.nih.gov/pub/dist/doc/program_help/3dcopy.html).
 - [mgh.mgz](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/MghFormat) was converted with [Slicer (4.10.2)](https://www.slicer.org).
 - [mha.mha](https://itk.org/Wiki/ITK/MetaIO/Documentation) was converted with [Slicer (4.10.2)](https://www.slicer.org).
 - [nrrd.nhdr/img.gz](http://teem.sourceforge.net/nrrd/format.html) was converted with [dcm2niix (v1.0.20190902)](https://github.com/rordenlab/dcm2niix).
 - sivic.idf/.int2 was converted with [SIVIC](https://github.com/SIVICLab/sivic) 0.9.105.
 - [spr.spr/.sdt](https://www.cmrr.umn.edu/stimulate/stimUsersGuide/node57.html) was converted with [Slicer (4.10.2)](https://www.slicer.org).
 - [vtk.vtk](https://www.vtk.org/wp-content/uploads/2015/04/file-formats.pdf) was converted with [Slicer (4.10.2)](https://www.slicer.org).
 - DICOM.zip is an archive of the original DICOM data. i2nii can not read DICOM images, but you can convert these with [dcm2niix](https://github.com/rordenlab/dcm2niix).
  
