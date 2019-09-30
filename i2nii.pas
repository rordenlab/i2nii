program i2nii;
//
// >fpc i2nii
// >strip ./i2nii
// >./i2nii ./test/sivic.idf


{$mode Delphi} //{$mode objfpc}
{$H+}
{$DEFINE GZIP}
uses
  {$IFDEF UNIX}
  cthreads, 
  {$ENDIF}
  {$IFDEF GZIP}zstream, gziputils, {$ENDIF}
  DateUtils, nifti_types,Classes, SysUtils, nifti_foreign;

const
    kEXIT_SUCCESS = 0;
    kEXIT_FAIL = 1;
    kEXIT_PARTIALSUCCESS = 2; //wrote some but not all files
    
type   
  TUInt32s = array of uint32;
  TInt32s = array of int32;
  TUInt16s = array of uint16;
  TInt16s = array of int16;
  TUInt8s = array of uint8;
  TInt8s = array of int8;
  TFloat32s = array of single;
  TFloat64s = array of double;

procedure printf(s: string);
begin
     writeln(s);
end;

procedure SwapImg(var  rawData: TUInt8s; bitpix: integer);
var
   i16s: TInt16s;
   i32s: TInt32s;
   f64s: TFloat64s;
   i, n: int64;
begin
     if bitpix < 15 then exit;
     if bitpix = 16 then begin
        n := length(rawData) div 2;
        i16s := TInt16s(rawData);
        for i := 0 to (n-1) do
            i16s[i] := swap2(i16s[i]);
     end;
     if bitpix = 32 then begin
        n := length(rawData) div 4;
        i32s := TInt32s(rawData);
        for i := 0 to (n-1) do
            swap4(i32s[i]);
     end;
     if bitpix = 64 then begin
        n := length(rawData) div 8;
        f64s := TFloat64s(rawData);
        for i := 0 to (n-1) do
            Xswap8r(f64s[i]);
     end;
end;

{$IFDEF GZIP}
function HdrVolumes(hdr: TNIfTIhdr): integer;
var
  i: integer;
begin
     result := 1;
     for i := 4 to 7 do
         if hdr.dim[i] > 1 then
            result := result * hdr.dim[i];
end;

function GetCompressedFileInfo(const comprFile: TFileName; var size: int64; var crc32: dword; skip: int64 = 0): int64;
//read GZ footer https://www.forensicswiki.org/wiki/Gzip
type
TGzHdr = packed record
   Signature: Word;
   Method, Flags: byte;
   ModTime: DWord;
   Extra, OS: byte;
 end;
var
  F : File Of byte;
  b: byte;
  i, xtra: word;
  cSz : int64; //uncompressed, compressed size
  uSz: dword;
  Hdr: TGzHdr;
begin
  result := -1;
  size := 0;
  crc32 := 0;
  if not fileexists(comprFile) then exit;
  result := skip;
  FileMode := fmOpenRead;
  Assign (F, comprFile);
  Reset (F);
  cSz := FileSize(F);
  if cSz < (18+skip) then begin
    Close (F);
    exit;
  end;
  seek(F,skip);
  blockread(F, Hdr, SizeOf(Hdr) );
  //n.b. GZ header/footer is ALWAYS little-endian
  {$IFDEF ENDIAN_BIG}
  Hdr.Signature := Swap(Hdr.Signature);
  {$ENDIF}
  if Hdr.Signature = $9C78 then begin
    exit(2);
    //printf('Error: not gz format: deflate with zlib wrapper');
    //UnCompressStream(inStream.Memory, tagBytes, outStream, nil, true);
  end;
  if Hdr.Signature <> $8B1F then begin //hex: 1F 8B
    Close (F);
    exit;
  end;
  //http://www.zlib.org/rfc-gzip.html
  if (Hdr.method <> 8) then
     printf('Expected GZ method 8 (deflate) not '+inttostr(Hdr.method));
  if ((Hdr.Flags and $04) = $04) then begin //FEXTRA
  	blockread(F, xtra, SizeOf(xtra));
  	{$IFDEF ENDIAN_BIG}
  	xtra := Swap(xtra);
  	{$ENDIF}
  	if xtra > 1 then
  		for i := 1 to xtra do
  			blockread(F, b, SizeOf(b));
  end;
  if ((Hdr.Flags and $08) = $08) then begin //FNAME
  	b := 1;
  	while (b <> 0) and (not EOF(F)) do
  		blockread(F, b, SizeOf(b));
  end;
  if ((Hdr.Flags and $10) = $10) then begin //FCOMMENT
  	b := 1;
  	while (b <> 0) and (not EOF(F)) do
  		blockread(F, b, SizeOf(b));
  end;
  if ((Hdr.Flags and $02) = $02) then begin //FHCRC
  	blockread(F, xtra, SizeOf(xtra));
  end;
  result := Filepos(F);
  Seek(F,cSz-8);
  blockread(f, crc32, SizeOf(crc32) );
  blockread(f, uSz, SizeOf(uSz) );
  {$IFDEF ENDIAN_BIG}
  crc32 = Swap(crc32);
  uSz = Swap(uSz);
  {$ENDIF}
  size := uSz; //note this is the MODULUS of the file size, beware for files > 2Gb
  Close (F);
end;


function LoadImgGZ(FileName : AnsiString; swapEndian: boolean; var  rawData: TUInt8s; var lHdr: TNIFTIHdr): boolean;
//foreign: both image and header compressed
var
  Stream: TGZFileStream;
  StreamSize: int64;
  crc32: dword;
  volBytes, offset: int64;
begin
 result := false;
 StreamSize := 0; //unknown
 if lHdr.vox_offset < 0 then begin
   //byteskip = -1
   // this is expressly forbidden in the NRRD specification
   // " skip can be -1. This is valid only with raw encoding"
   // we handle it here because these images are seen in practice
   GetCompressedFileInfo(FileName, StreamSize, crc32);
 end;
 Stream := TGZFileStream.Create (FileName, gzopenread);
 Try
  if (lHdr.bitpix <> 8) and (lHdr.bitpix <> 16) and (lHdr.bitpix <> 24) and (lHdr.bitpix <> 32) and (lHdr.bitpix <> 64) then begin
   printf('Unable to load '+Filename+' - this software can only read 8,16,24,32,64-bit NIfTI files.');
   exit;
  end;
  //read the image data
  volBytes := lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3] * (lHdr.bitpix div 8);
  if HdrVolumes(lHdr) > 1 then
    volBytes := volBytes * HdrVolumes(lHdr);
  offset := round(lHdr.vox_offset);
  if lHdr.vox_offset < 0 then begin
     offset := StreamSize-volBytes;
     if offset < 0 then
       offset := 0; //report sensible error
  end;
  if ((offset+volBytes) < StreamSize) then begin
    printf(format('Uncompressed file too small: expected %d got %d: %s', [offset+volBytes , StreamSize , Filename]));
    exit;
  end;
  Stream.Seek(offset,soFromBeginning);
  SetLength (rawData, volBytes);
  Stream.ReadBuffer (rawData[0], volBytes);
  if swapEndian then
   SwapImg(rawData, lHdr.bitpix);
 Finally
  Stream.Free;
 End;
 result := true;
end;


function LoadHdrRawImgGZ(FileName : AnsiString; swapEndian: boolean; var  rawData: TUInt8s; var lHdr: TNIFTIHdr): boolean;
var
   {$IFNDEF FASTGZ}
   fStream: TFileStream;
   inStream: TMemoryStream;
   {$ENDIF}
   volBytes: int64;
   outStream : TMemoryStream;
label
     123;
begin
 result := false;
 if not fileexists(Filename) then exit;
 if (lHdr.bitpix <> 8) and (lHdr.bitpix <> 16) and (lHdr.bitpix <> 24) and (lHdr.bitpix <> 32) and (lHdr.bitpix <> 64) then begin
   printf('Unable to load '+Filename+' - this software can only read 8,16,24,32,64-bit NIfTI files.');
   exit;
 end;
 volBytes := lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3] * (lHdr.bitpix div 8);
 volBytes := volBytes * HdrVolumes(lHdr);
 outStream := TMemoryStream.Create();
 {$IFDEF FASTGZ}
 result := ExtractGzNoCrc(Filename, outStream, round(lHdr.vox_offset), volBytes);
 {$ELSE}
 fStream := TFileStream.Create(Filename, fmOpenRead);
 fStream.seek(round(lHdr.vox_offset), soFromBeginning);
 inStream := TMemoryStream.Create();
 inStream.CopyFrom(fStream, fStream.Size - round(lHdr.vox_offset));
 result := unzipStream(inStream, outStream);
 fStream.Free;
 inStream.Free;
 if (not result) and (volBytes >=outStream.size) then begin
   printf('unzipStream error but sufficient bytes extracted (perhaps GZ without length in footer)');
   result := true;
 end;
 {$ENDIF}
 if not result then goto 123;
 //showmessage(format('%g  %dx%dx%dx%d ~= %d',[lHdr.vox_offset, lHdr.dim[1],lHdr.dim[2],lHdr.dim[3],lHdr.dim[4], HdrVolumes(lHdr) ]));
 if outStream.Size < volBytes then begin
    result := false;
    printf(format('GZ error expected %d found %d bytes: %s',[volBytes,outStream.Size, Filename]));
    goto 123;
 end;
 SetLength (rawData, volBytes);
 outStream.Position := 0;
 outStream.ReadBuffer (rawData[0], volBytes);
 if swapEndian then
   SwapImg(rawData, lHdr.bitpix);
 123:
   outStream.Free;
end;
{$ENDIF} //GZ

procedure planar3D2RGB8(var  rawData: TUInt8s; var lHdr: TNIFTIHdr);
var
   img: TUInt8s;
   xy, xys, i, j, s, xyz, nBytesS, SamplesPerPixel: int64;
begin
  if lHdr.datatype <> kDT_RGBplanar3D then exit;
  lHdr.datatype := kDT_RGB;
  SamplesPerPixel := 3;
  xy := lHdr.dim[1] * lHdr.dim[2];
  xyz := xy * lHdr.dim[3];
  xys := xy *  SamplesPerPixel;
  nBytesS := xys * lHdr.dim[3] ;
  setlength(img, nBytesS);
  img := Copy(rawData, Low(rawData), Length(rawData));
  j := 0;
  for i := 0 to (xyz-1) do begin
      for s := 0 to (SamplesPerPixel-1) do begin
          rawData[j] := img[i+(s * xyz)] ;
          j := j + 1;
      end;
  end;
  img := nil;
end;

procedure DimPermute2341(var  rawData: TUInt8s; var lHdr: TNIFTIHdr);
//NIfTI demands first three dimensions are spatial, NRRD often makes first dimension non-spatial (e.g. DWI direction)
// This function converts NRRD TXYZ to NIfTI compatible XYZT
var
   i, x,y,z,t,xInc,yInc,zInc,tInc, nbytes: int64;
   i8, o8: TUint8s;
   i16, o16: TUInt16s;
   i32, o32: TUInt32s;
begin
     if HdrVolumes(lHdr) < 2 then exit;
     if (lHdr.bitpix mod 8) <> 0 then exit;
     if (lHdr.bitpix <> 8) and (lHdr.bitpix <> 16) and (lHdr.bitpix <> 32) then exit;
     nbytes := lHdr.Dim[1] * lHdr.Dim[2] * lHdr.Dim[3] * HdrVolumes(lHdr) * (lHdr.bitpix div 8);
     if nbytes < 4 then exit;
     setlength(i8, nbytes);
     i8 := copy(rawData, low(rawData), high(rawData));
     i16 := TUInt16s(i8);
     i32 := TUInt32s(i8);
     o8 := TUInt8s(rawData);
     o16 := TUInt16s(rawData);
     o32 := TUInt32s(rawData);
     t :=  lHdr.Dim[1];
     x :=  lHdr.Dim[2];
     y :=  lHdr.Dim[3];
     z :=  HdrVolumes(lHdr);
     lHdr.Dim[1] := x;
     lHdr.Dim[2] := y;
     lHdr.Dim[3] := z;
     lHdr.Dim[4] := t;
     lHdr.Dim[5] := 1;
     lHdr.Dim[6] := 1;
     lHdr.Dim[7] := 1;
     tInc := 1;
     xInc := t;
     yInc := t * x;
     zInc := t * x * y;
     i := 0;
     if (lHdr.bitpix = 8) then
        for t := 0 to (lHdr.Dim[4]-1) do
            for z := 0 to (lHdr.Dim[3]-1) do
                for y := 0 to (lHdr.Dim[2]-1) do
                    for x := 0 to (lHdr.Dim[1]-1) do begin
                        o8[i] := i8[(x*xInc)+(y*yInc)+(z*zInc)+(t*tInc)];
                        i := i + 1;
                    end;
     if (lHdr.bitpix = 16) then
        for t := 0 to (lHdr.Dim[4]-1) do
            for z := 0 to (lHdr.Dim[3]-1) do
                for y := 0 to (lHdr.Dim[2]-1) do
                    for x := 0 to (lHdr.Dim[1]-1) do begin
                        o16[i] := i16[(x*xInc)+(y*yInc)+(z*zInc)+(t*tInc)];
                        i := i + 1;
                    end;
     if (lHdr.bitpix = 32) then
        for t := 0 to (lHdr.Dim[4]-1) do
            for z := 0 to (lHdr.Dim[3]-1) do
                for y := 0 to (lHdr.Dim[2]-1) do
                    for x := 0 to (lHdr.Dim[1]-1) do begin
                        o32[i] := i32[(x*xInc)+(y*yInc)+(z*zInc)+(t*tInc)];
                        i := i + 1;
                    end;
     i8 := nil;
end;

function saveNii(fnm: string; var oHdr: TNIFTIhdr; var orawVolBytes: TUInt8s): boolean;
var
  mStream : TMemoryStream;
  zStream: TGZFileStream;
  oPad32: Uint32; //nifti header is 348 bytes padded with 4
  lExt,NiftiOutName: string;
begin
 result := true;
 mStream := TMemoryStream.Create;
 oHdr.vox_offset :=  sizeof(oHdr) + 4;
 mStream.Write(oHdr,sizeof(oHdr));
 oPad32 := 4;
 mStream.Write(oPad32, 4);
 mStream.Write(oRawVolBytes[0], length(orawVolBytes));
 oRawVolBytes := nil;
 mStream.Position := 0;
 FileMode := fmOpenWrite;
 NiftiOutName := fnm;
 lExt := uppercase(extractfileext(NiftiOutName));
 if (lExt = '.GZ') or (lExt = '.VOI') then begin  //save gz compressed
    if (lExt = '.GZ') then
       NiftiOutName := ChangeFileExt(NiftiOutName,'.nii.gz'); //img.gz -> img.nii.gz
    zStream := TGZFileStream.Create(NiftiOutName, gzopenwrite);
    zStream.CopyFrom(mStream, mStream.Size);
    zStream.Free;
 end else begin
     if (lExt <> '.NII') then
        NiftiOutName := NiftiOutName + '.nii';
     mStream.SaveToFile(NiftiOutName); //save uncompressed
 end;
 mStream.Free;
 FileMode := fmOpenRead;
end;

function convert2nii(ifnm, outDir: string; isGz: boolean): boolean;
var
  FileName: string;
  lHdr: TNIFTIhdr;
  Stream : TFileStream;
  gzBytes, volBytes, FSz: int64;
  
  ok, swapEndian, isDimPermute2341: boolean;
  rawData: TUInt8s;
begin
     FileName := ifnm;
     result := false;
     if not fileexists(FileName) then begin
        FileName := GetCurrentDir+PathDelim+ FileName;
        if not fileexists(FileName) then begin
           printf('Unable to find "'+ifnm+'"');
           exit;
        end;
     end;
     //expand filenames, optional but makes output easier to parse 'Converted "./test/nrrd.raw.nii"'
     ifnm := ExpandFileName(ifnm);
     //set output directory
     if (outDir <> '') and ((FileGetAttr(outDir) and faDirectory) = 0) then
        outDir := ExtractFilePath(outDir);
     if outDir = '' then
        outDir := ExtractFilePath(ifnm);
     if outDir = '' then 
        outDir := GetCurrentDir();
     if length(outDir) < 1then 
        exit;
     if outDir[length(outDir)] <> pathdelim then
        outDir := outDir + pathdelim;
     outDir := ExpandFileName(outDir);
     FSz := FileGetAttr(extractfilepath(outDir));
     if ((FSz and faReadOnly) <> 0) or ((FSz and faDirectory) = 0) then begin
           printf('Unable to write to output folder "'+outDir+'"');
           exit;     
     end;
     ok := readForeignHeader (FileName, lHdr, gzBytes, swapEndian, isDimPermute2341);
     if not ok then begin
        printf('Unable to interpret header "'+FileName+'"');
        exit;
     end;
     if not fileexists(FileName) then begin
        printf('Unable to find image data "'+FileName+'" described by header "'+ifnm+'"');
        exit;
     end;
     
     {$IFDEF GZIP}
     if gzBytes = K_gzBytes_onlyImageCompressed then
       result := LoadHdrRawImgGZ(FileName, swapEndian,  rawData, lHdr)
     else if gzBytes < 0 then
        result := LoadImgGZ(FileName, swapEndian,  rawData, lHdr)
     {$ELSE}
     if (gzBytes = K_gzBytes_onlyImageCompressed) or (gzBytes < 0) then begin
        printf('Not compiled to read GZip files');
        exit;
     end
     {$ENDIF}
     else  begin
       volBytes := lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3] * (lHdr.bitpix div 8);
       FSz := FSize(FileName);
       if (FSz < (round(lHdr.vox_offset)+volBytes)) then begin
        printf(format('Unable to load '+Filename+' - file size (%d) smaller than expected (%d) ', [FSz, round(lHdr.vox_offset)+volBytes]));
        exit(false);
       end;
       Stream := TFileStream.Create (FileName, fmOpenRead or fmShareDenyWrite);
       Try
        Stream.Seek(round(lHdr.vox_offset),soFromBeginning);
        if lHdr.dim[4] > 1 then
          volBytes := volBytes * lHdr.dim[4];
        SetLength (rawData, volBytes);
        Stream.ReadBuffer (rawData[0], volBytes);
       Finally
        Stream.Free;
       End;
       //showmessage(format('%d  %d',[length(rawData), lHdr.bitpix div 8])); //x24bit
       if swapEndian then
          SwapImg(rawData, lHdr.bitpix);
       result := true;
     end;
     if not result then begin
        printf('Unable to read image data for "'+FileName+'"');
       exit;
     end;
     planar3D2RGB8(rawData, lHdr);
     if isDimPermute2341 then
        DimPermute2341(rawData, lHdr);
     FileName := outDir +  ExtractFileName(FileName);
     FileName := changefileext(FileName, '.nii');
     if isGz then
        FileName := FileName + '.gz';
     if fileexists(FileName) then
        printf('Overwriting "'+FileName+'"');
     saveNii(FileName, lHdr, rawData);
     printf('Converted "'+FileName+'"');
     result := true;
end;


procedure ShowHelp;
var
    exeName, outDir: string;
begin
    exeName := extractfilename(ParamStr(0));
    {$IFDEF WINDOWS}
    exeName := ChangeFileExt(exeName, ''); //i2nii.exe -> i2nii
    {$ENDIF}
    writeln('Chris Rorden''s'+kIVers);
    writeln(format('usage: %s [options] <in_file(s)>', [exeName]));
    writeln(' Options :');
    writeln(' -z : gz compress images (y/n, default n)');
    writeln(' -h : show help');
    writeln(' -o : output directory (omit to save to input folder)');
    writeln(' Examples :');
    writeln(format('  %s -z y ecat.v', [ExeName]));
    writeln(format('  %s img1.pic img2.pic', [ExeName]));
    {$IFDEF WINDOWS}
    OutDir := 'c:\out';
    {$ELSE}
    OutDir := '~/out';
    {$ENDIF}
    writeln(format('  %s -o %s "spaces in name.bvox"', [exeName, outDir]));
    {$IFDEF WINDOWS}
    OutDir := 'c:\my out';
    {$ELSE}
    writeln(format('  %s ./test/sivic.idf', [exeName, outDir]));
    OutDir := '~/my out';
    {$ENDIF}    
    writeln(format('  %s -o "%s" "input.nrrd"', [exeName, outDir]));  
end;

//main loop
var
    nAttempt :integer = 0;
    nOK: integer = 0;
    i: integer;
    s, v: string;
    outDir: string = '';
    c: char;
    isGz: boolean = false;
    isShowHelp: boolean = false;
    startTime : TDateTime;

Begin
    startTime := Now;
    i := 1;
    while i <= ParamCount do begin
        s := ParamStr(i);
        i := i + 1;
        if length(s) < 1 then continue; //possible?
        if s[1] <> '-' then begin
            nAttempt := nAttempt + 1;
            if convert2nii(s, outDir, isGz) then
                nOK := nOK + 1;
            continue;
        end;
        //handle arguments
        if length(s) < 2 then continue; //e.g. 'i2nii ""'
        //one argument functions, "-h"
        c := upcase(s[2]);
        if c =  'H' then begin
            isShowHelp := true;
            continue;
        end;
        //two argument functions e.g. "-z y" 
        if i = ParamCount then continue;
        v := ParamStr(i);
        i := i + 1;
        if length(v) < 1 then continue; //e.g. 'i2nii -o ""'
        if c =  'Z' then
            isGz := upcase(v[1]) = 'Y';
        if c =  'O' then
            outDir := v;
    end; //while
    if (ParamCount = 0) or (isShowHelp) then
        ShowHelp;
    if nOK > 0 then 
        writeln(format('Conversion required %.3f seconds.', [MilliSecondsBetween(Now,startTime)/1000.0]));
    if (nOK = nAttempt) then
        ExitCode := kEXIT_SUCCESS
    else if (nOK = 0) then
        ExitCode := kEXIT_FAIL
    else
        ExitCode := kEXIT_PARTIALSUCCESS;
end.