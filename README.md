## About

i2nii converts several scientific and medical imaging formats to the popular [NIfTI](https://nifti.nimh.nih.gov/nifti-1) format. NIfTI is used by many neuroimaging tools including FSL, SPM, and AFNI. Note that this tool will not convert images from DICOM format, though the companion [dcm2niix](https://github.com/rordenlab/dcm2niix) will. Likewise, it will not convert TIFF or many microscopy formats, though the [Bio-Formats module](https://docs.openmicroscopy.org/bio-formats/5.9.2/supported-formats.html) of [ImageJ/Fiji](https://fiji.sc) can convert these.

i2nii shares the image reading functions of the [MRIcroGL](https://www.nitrc.org/plugins/mwiki/index.php/mricrogl:MainPage) viewer. If you prefer a drag-and-drop graphical user interface, you should use MRIcroGL. In contrast, i2nii is designed to be used from the command line. Compiled excutables are provided for Linux, MacOS and Windows. The source code should compile on a [wide range](https://www.freepascal.org/download.html) of operating systems. 

## Installation

You can get i2nii using two methods:

 - (Recommended) Download latest compiled release from [Github release web page](https://github.com/rordenlab/i2nii/releases).
 - (Recommended) You can also download from the command line for Linux, MacOS and Windows:
   * `curl -fLO https://github.com/rordenlab/i2nii/releases/latest/download/i2nii_lnx.zip`
   * `curl -fLO https://github.com/rordenlab/i2nii/releases/latest/download/i2nii_mac.zip`
   * `curl -fLO https://github.com/rordenlab/i2nii/releases/latest/download/i2nii_win.zip`
 - (Developers) Download the source code from [GitHub](https://github.com/rordenlab/i2nii).

## Usage

```
Chris Rorden's i2nii v1.0.20191007
usage: i2nii [options] <in_file(s)>
 Options :
 -h : show help
 -o : output directory (omit to save to input folder)
 -r : rotation (l/r/n, LAS/RAS/native default n)
       caution: rotation can disrupt slice time correction
 -z : gz compress images (y/n, default n)
 Examples :
  i2nii -z y ecat.v
  i2nii img1.pic img2.pic
  i2nii -o ~/out "spaces in name.bvox"
  i2nii ./test/sivic.idf
  i2nii -o "~/my out" "input.nrrd"
```  

## Limitations

This software is provided as is. There are clear limitations.

 - Many of the file formats are poorly documented. In particular with respect to spatial scale and orientation. Some of these problems are inherent to the format (e.g. [Blender Voxel data](http://pythology.blogspot.com/2014/08/you-can-do-cool-stuff-with-manual.html) contains no spatial information at all). In other cases, this software could be improved to better handle these formats. It is open source, so feel free to contribute. However, due to these limitations, one should take care using this software.
 - The NIfTI format is explicitly designed to store spatial images. Some supported formats handle a much wider range of data. For example, Interfile can encode both raw PET data as well as reconstructed PET spatial images. The NIfTI format is not well suited for the former, though it can cope with the latter.
 
 Note that the `-r` option allows you to specify whether the raw data is stored in [native, LAS, or RAS](https://brainder.org/2012/09/23/the-nifti-file-format/). If rotation is requested, the voxel data is copied losslessly. The image dimensions are permuted and flipped to the orthogonal orientation that best matches the desired storage order. For oblique acquisitions (where the slice angulation is not orthogonal to the scanner bore), the residual rotation is stored in the NIfTI SForm and QForm. Therefore, for software that uses the SForm and QForm information, each of these storage orientations is identical. The pupose of these commands is for simple tools that require specified spatial storage. A limitation of this option is that many supported image formats do not record spatial orientation (as reported in the previous paragraph). 

## Compiling

It is generally recommended that download a pre-compiled executable (see previous section). However, you can compile your own copy from source code.

 - Download and install [FreePascal for your operating system](https://www.freepascal.org/download.html). For Debian-based unix this may be as easy as `sudo apt-get install fp-compiler`. For other operating systems, you may simply want to install FreePascal from the latest [Lazarus distribution](https://sourceforge.net/projects/lazarus/files/).
 - From the terminal, go inside the directory with the source files and run the following commands to build and validate your compilation:

```
fpc i2nii
./i2nii -o ./test/afni.BRIK+orig.BRIK
./i2nii ./test/mgh.mgz 
./i2nii ./test/mha.mha 
./i2nii ./test/nrrd.nhdr
./i2nii -o ./test/sivic.idf
./i2nii ./test/spr.spr
./i2nii ./test/vtk.vtk
```
 

## Supported Image Formats

i2nii should automatically detect and convert the following image formats. Be aware that not all these formats have spatial transformations. Further, support for all features of these formats may be incomplete.

 - [AFNI Brik](https://afni.nimh.nih.gov/pub/dist/doc/program_help/README.attributes.html)(.head).
 - [AIM Scanco Medical µCT or HRpQCT](https://www.researchgate.net/publication/320077296_AIMreader_python_implementation_and_examples)(.aim).
 - [Analyze](http://imaging.mrc-cbu.cam.ac.uk/imaging/FormatAnalyze)(.hdr).
 - [Bio-Rad PIC](https://docs.openmicroscopy.org/bio-formats/5.8.2/formats/bio-rad-pic.html)(.pic).
 - [Blender Voxel data](http://pythology.blogspot.com/2014/08/you-can-do-cool-stuff-with-manual.html)(.bvox).
 - [BrainVoyager VMR](https://support.brainvoyager.com/brainvoyager/automation-development/84-file-formats/343-developer-guide-2-6-the-format-of-vmr-files)(.vmr, .v16).
 - [Concorde/Siemens µPET](https://xmedcon.sourceforge.io/Docs/OptionsMedConFiles)(.img.hdr,.img)
 - [DAT format](https://www.cg.tuwien.ac.at/courses/Visualisierung/Angaben/Bsp1.html#Volums%20Datensätze)(.dat).
 - [DeltaVision](https://docs.openmicroscopy.org/bio-formats/5.8.2/formats/deltavision.html)(.dv).
 - [ECAT](http://nipy.org/nibabel/reference/nibabel.ecat.html)(.v).
 - [FreeSurfer MGH/MGZ Volume](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/MghFormat)(.mgh/.mgz).
 - [Guys Image Processing Lab](http://rview.colin-studholme.net/rview/rv9manual/fileform.html#GIPL)(.gipl).
 - [ICS Image Cytometry Standard](https://onlinelibrary.wiley.com/doi/epdf/10.1002/cyto.990110502)(.ics).
 - [Interfile](https://www.ncbi.nlm.nih.gov/pubmed/2616095)(.varies, limited support).
 - [PVL (Processed VoLume) from Drishti](http://paulbourke.net/dataformats/pvl/)(.nc)
 - [ITK MHA/MHD](https://itk.org/Wiki/MetaIO/Documentation)(.mha/.mhd).
 - [MRC volume](https://mrcfile.readthedocs.io/en/latest/usage_guide.html)(.mrc).
 - [MRTrix volume](https://mrtrix.readthedocs.io/en/latest/getting_started/image_data.html)(.mif/.mih; not all variants supported).
 - [NIfTI](https://brainder.org/2012/09/23/the-nifti-file-format/)(.hdr/.nii/.nii.gz/.voi).
 - [NRRD](http://teem.sourceforge.net/nrrd/format.html)(.nhdr/.nrrd).
 - [PGM](http://paulbourke.net/dataformats/ppm/)(.pgm).
 - [POV-Ray Density_File](https://www.povray.org/documentation/view/3.6.1/374/)(.df3).
 - [Spectroscopic Imaging, Visualization and Computing (SIVIC)](https://radiology.ucsf.edu/research/labs/nelson#accordion-software)(.idf).
 - [Stimulate Sdt](https://www.cmrr.umn.edu/stimulate/stimUsersGuide/node57.html)(.spr/.sdt)
 - [Vaa3D](https://github.com/Vaa3D)(.v3draw).
 - [VFF format from ncaa](https://github.com/SlicerRt/SlicerRT/blob/master/VffFileReader/Logic/vtkSlicerVffFileReaderLogic.cxx)(.vff).
 - [VTK Legacy Voxel Format](https://www.vtk.org/wp-content/uploads/2015/04/file-formats.pdf)(.vtk).
 - [VTK VTI format](https://vtk.org/Wiki/VTK_XML_Formats)(.vti).
 - [XRAW MagicaVoxel minecraft](https://ephtracy.github.io/index.html?page=mv_renderer)(.xraw).
 
If your image format is not supported directly by MRIcroGL, you may want to see if it is supported by the [Bio-Formats module](https://docs.openmicroscopy.org/bio-formats/5.9.2/supported-formats.html) of [ImageJ/Fiji](https://fiji.sc). If so, you can open the image with the module and save it as NIfTI or NRRD to read it with MRIcroGL.

