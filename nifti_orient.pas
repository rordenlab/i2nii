unit nifti_orient;
{$IFDEF FPC}{$mode objfpc}{$ENDIF}
{$H+}
{$Include isgui.inc}
interface

uses
  VectorMath, SimdUtils, nifti_types, nifti_foreign,
  Classes, SysUtils;


procedure SaveRotated(var rawVolBytes: TUInt8s; var hdr : TNIFTIhdr; isSaveRightToLeft: boolean = false);


implementation

procedure printf(s: string);
begin
    {$IFDEF GUI}
     {$IFDEF UNIX} writeln(s); {$ENDIF}
    {$ELSE}
    writeln(s);
    {$ENDIF}
end;

procedure Mat2QForm(m: TMat4; var hdr: TNIFTIhdr);
var
  i,j: integer;
  m44 :mat44;
  dumdx, dumdy, dumdz: single;
begin
   for i := 0 to 3 do
       for j := 0 to 3 do
           m44[i,j] := m[i,j];
   nifti_mat44_to_quatern( m44 , hdr.quatern_b, hdr.quatern_c, hdr.quatern_d,hdr.qoffset_x,hdr.qoffset_y,hdr.qoffset_z, dumdx, dumdy, dumdz,hdr.pixdim[0]) ;
   hdr.qform_code := hdr.sform_code;
end;

procedure Mat2SForm(m: TMat4; var hdr: TNIFTIhdr);
begin
 hdr.srow_x[0] := m[0,0]; hdr.srow_x[1] := m[0,1]; hdr.srow_x[2] := m[0,2]; hdr.srow_x[3] := m[0,3];
 hdr.srow_y[0] := m[1,0]; hdr.srow_y[1] := m[1,1]; hdr.srow_y[2] := m[1,2]; hdr.srow_y[3] := m[1,3];
 hdr.srow_z[0] := m[2,0]; hdr.srow_z[1] := m[2,1]; hdr.srow_z[2] := m[2,2]; hdr.srow_z[3] := m[2,3];
end;

procedure ApplyVolumeReorient(perm: TVec3i; outR: TMat4; var fDim: TVec3i; var fScale : TVec3; var fHdr  : TNIFTIhdr; var rawVolBytes: TUInt8s);
var
   flp: TVec3i;
    inScale: TVec3;
    inDim, inStride, outStride : TVec3i;
    i8: UInt8;
    i16: Int16;
    i32: Int32;
    half, mx: int64;
    in8: TUInt8s;
    in16, out16: TInt16s;
    in32, out32: TInt32s;
    in24, out24: TRGBs;
    inperm: TVec3i;
    xOffset, yOffset, zOffset: array of int64;
    voxOffset, byteOffset, volBytes,vol, volumesLoaded,  x,y,z, i: int64;
begin
  if (perm.x = 1) and (perm.y = 2) and (perm.z = 3) then begin
     Mat2SForm(outR, fHdr); //could skip: no change!
    exit;
  end;
  inperm := perm;
  printf(format('Reorient Dimensions %d %d %d', [perm.x, perm.y, perm.z]));
 for i := 0 to 2 do begin
       flp.v[i] := 0;
       if (perm.v[i] < 0) then flp.v[i] := 1;
       perm.v[i] := abs(perm.v[i]);
   end;
  if (perm.x = perm.y) or (perm.x = perm.z) or (perm.y = perm.z) or ((perm.x+perm.y+perm.z) <> 6 ) then begin
     Mat2SForm(outR, fHdr); //could skip: bogus
    exit;
  end;
  inDim := fDim;
 inStride.x := 1;
 inStride.y := inDim.x;
 inStride.z := inDim.x * inDim.y;
 outStride.x := inStride.v[perm.x-1];
 outStride.y := inStride.v[perm.y-1];
 outStride.z := inStride.v[perm.z-1];
 //set outputs
 fDim.x := inDim.v[perm.x-1];
 fDim.y := inDim.v[perm.y-1];
 fDim.z := inDim.v[perm.z-1];
 inscale := fScale;
 fScale.x := inScale.v[perm.x-1];
 fScale.y := inScale.v[perm.y-1];
 fScale.z := inScale.v[perm.z-1];
 volBytes := fHdr.Dim[1]*fHdr.Dim[2]*fHdr.Dim[3]* (fHdr.bitpix shr 3);
 volumesLoaded := length(rawVolBytes) div volBytes;
 Mat2SForm(outR, fHdr);
 Mat2QForm(outR, fHdr);
 if (fHdr.bitpix <> 24) and (inperm.x = -1) and (inperm.y = 2) and (inperm.z = 3) and (fDim.x > 2) then begin
    //optimize most common case of left-right mirror: no need to copy memory, 240ms -> 170ms
     half := (fDim.x-1) div 2; // [0 1 2]
     mx := fDim.x - 1;
     i := 0;
     {$DEFINE OLD8} //no benefit of line copies
     {$IFDEF OLD8}
     setlength(in8, fDim.x);
     if (fHdr.bitpix = 8) then begin
       for vol := 1 to volumesLoaded do
           for z := 0 to (fDim.z - 1) do
               for y := 0 to (fDim.y - 1) do begin
                   for x := 0 to half do begin
                       i8 := rawVolBytes[i+(mx-x)];
                       rawVolBytes[i+(mx-x)] := rawVolBytes[i+x];
                       rawVolBytes[i+x] := i8;
                   end;
                   i := i + fDim.x;
               end;
     end;
     {$ELSE}
     if (fHdr.bitpix = 8) then begin
       setlength(in8, fDim.x);
       for vol := 1 to volumesLoaded do
          for z := 0 to (fDim.z - 1) do
              for y := 0 to (fDim.y - 1) do begin
                  in8 := Copy(rawVolBytes, i, mx+1);
                  for x := 0 to mx do
                      rawVolBytes[i+x] := rawVolBytes[i+(mx-x)];
                  i := i + fDim.x;
              end;
       in8 := nil;
     end;
     {$ENDIF}
     if (fHdr.bitpix = 16) then begin
       out16 := TInt16s(rawVolBytes);
       for vol := 1 to volumesLoaded do
           for z := 0 to (fDim.z - 1) do
               for y := 0 to (fDim.y - 1) do begin
                   for x := 0 to half do begin
                      i16 := out16[i+(mx-x)];
                      out16[i+(mx-x)] := out16[i+x];
                      out16[i+x] := i16;
                   end;
                   i := i + fDim.x;
               end;
     end;
     if (fHdr.bitpix = 32) then begin
       out32 := TInt32s(rawVolBytes);
       for vol := 1 to volumesLoaded do
           for z := 0 to (fDim.z - 1) do
               for y := 0 to (fDim.y - 1) do begin
                   for x := 0 to half do begin
                       i32 := out32[i+(mx-x)];
                       out32[i+(mx-x)] := out32[i+x];
                       out32[i+x] := i32;
                   end;
                   i := i + fDim.x;
               end;
     end;
     exit;
 end;
 //setup lookup tables
 setlength(xOffset, fDim.x);
 if flp.x = 1 then begin
    for x := 0 to (fDim.x - 1) do
        xOffset[fDim.x-1-x] := x*outStride.x;
 end else
     for x := 0 to (fDim.x - 1) do
         xOffset[x] := x*outStride.x;
 setlength(yOffset, fDim.y);
 if flp.y = 1 then begin
    for y := 0 to (fDim.y - 1) do
        yOffset[fDim.y-1-y] := y*outStride.y;
 end else
     for y := 0 to (fDim.y - 1) do
         yOffset[y] := y*outStride.y;
 setlength(zOffset, fDim.z);
 if flp.z = 1 then begin
    for z := 0 to (fDim.z - 1) do
        zOffset[fDim.z-1-z] := z*outStride.z;
 end else
     for z := 0 to (fDim.z - 1) do
         zOffset[z] := z*outStride.z;
 //copy data
 SetLength(in8, volBytes);
 if volumesLoaded < 1 then exit;
 for vol := 1 to volumesLoaded do begin
   byteOffset := (vol-1) * volBytes;
   voxOffset := fHdr.Dim[1]*fHdr.Dim[2]*fHdr.Dim[3]* (vol-1);
   in8 := Copy(rawVolBytes, byteOffset, volBytes);
   if fHdr.bitpix = 8 then begin
      i := voxOffset;
      for z := 0 to (fDim.z - 1) do
          for y := 0 to (fDim.y - 1) do
              for x := 0 to (fDim.x - 1) do begin
                rawVolBytes[i] := in8[xOffset[x]+yOffset[y]+zOffset[z]];
                i := i + 1;
              end;
   end;
   if fHdr.bitpix = 16 then begin
      in16 := TInt16s(in8);
      out16 := TInt16s(rawVolBytes);
      i := voxOffset;
      for z := 0 to (fDim.z - 1) do
          for y := 0 to (fDim.y - 1) do
              for x := 0 to (fDim.x - 1) do begin
                out16[i] := in16[xOffset[x]+yOffset[y]+zOffset[z]];
                i := i + 1;
              end;
   end;
   if fHdr.bitpix = 24 then begin
      in24 := TRGBs(in8);
      out24 := TRGBs(rawVolBytes);
      i := voxOffset;
      for z := 0 to (fDim.z - 1) do
          for y := 0 to (fDim.y - 1) do
              for x := 0 to (fDim.x - 1) do begin
                out24[i] := in24[xOffset[x]+yOffset[y]+zOffset[z]];
                i := i + 1;
              end;
   end;
   if fHdr.bitpix = 32 then begin
      in32 := TInt32s(in8);
      out32 := TInt32s(rawVolBytes);
      i := voxOffset;
      for z := 0 to (fDim.z - 1) do
          for y := 0 to (fDim.y - 1) do
              for x := 0 to (fDim.x - 1) do begin
                out32[i] := in32[xOffset[x]+yOffset[y]+zOffset[z]];
                i := i + 1;
              end;
   end;
 end; //for vol 1..volumesLoaded
 xOffset := nil;
 yOffset := nil;
 zOffset := nil;
 in8 := nil;
 fHdr.dim[1] := fDim.X;
 fHdr.dim[2] := fDim.Y;
 fHdr.dim[3] := fDim.Z;
 //shuffle pixdim
 inScale[0] := fHdr.pixdim[1];
 inScale[1] := fHdr.pixdim[2];
 inScale[2] := fHdr.pixdim[3];
 fHdr.pixdim[1] := inScale.v[perm.x-1];
 fHdr.pixdim[2] := inScale.v[perm.y-1];
 fHdr.pixdim[3] := inScale.v[perm.z-1];
 //showmessage(format('%g %g %g', [fHdr.qoffset_x, fHdr.qoffset_y, fHdr.qoffset_z]));
end;

function EstimateReorient(dim : TVec3i; R: TMat4; out residualR: TMat4; out perm : TVec3i; isSaveRightToLeft: boolean = false) : boolean;
//compute dimension permutations and flips to reorient volume to standard space
//From Xiangrui Li's BSD 2-Clause Licensed code
// https://github.com/xiangruili/dicm2nii/blob/master/nii_viewer.m
var
  a, rotM: TMat4;
  i,j: integer;
  flp,ixyz : TVec3i;
begin
  result := false;
  a := TMat4.Identity;
  //memo1.lines.add(writeMat('R',R));
  for i := 0 to 3 do
      for j := 0 to 3 do
          a[i,j] := abs(R[i,j]);
  //memo1.lines.add(writeMat('a',a));
  //first column = x
  ixyz.x := 1;
  if (a[1,0] > a[0,0]) then ixyz.x := 2;
  if (a[2,0] > a[0,0]) and (a[2,0]> a[1,0]) then ixyz.x := 3;
  //second column = y: constrained as must not be same row as x
  if (ixyz.x = 1) then begin
     if (a[1,1] > a[2,1]) then
        ixyz.y := 2
     else
         ixyz.y := 3;
  end else if (ixyz.x = 2) then begin
     if (a[0,1] > a[2,1]) then
        ixyz.y := 1
     else
         ixyz.y := 3;
  end else begin //ixyz.x = 3
     if (a[0,1] > a[1,1]) then
        ixyz.y := 1
     else
         ixyz.y := 2;
  end;
  //third column = z:constrained as x+y+z = 1+2+3 = 6
  ixyz.z := 6 - ixyz.y - ixyz.x;
  perm.v[ixyz.x-1] := 1;
  perm.v[ixyz.y-1] := 2;
  perm.v[ixyz.z-1] := 3;
  //sort columns  R(:,1:3) = R(:,perm);
  rotM := R;
  for i := 0 to 3 do
      for j := 0 to 2 do
          R[i,j] := rotM[i,perm.v[j]-1];
  //compute if dimension is flipped
  if isSaveRightToLeft then
    if R[0,0] < 0 then flp.x := 0 else flp.x := 1
  else //
    if R[0,0] < 0 then flp.x := 1 else flp.x := 0;
  if R[1,1] < 0 then flp.y := 1 else flp.y := 0;
  if R[2,2] < 0 then flp.z := 1 else flp.z := 0;
  if (perm.x = 1) and (perm.y = 2) and (perm.z = 3) and (flp.x = 0) and (flp.y = 0) and (flp.z = 0) then exit;//already oriented correctly
  result := true; //reorient required!
  rotM := TMat4.Identity;
  rotM[0,0] := 1-flp.x*2;
  rotM[1,1] := 1-flp.y*2;
  rotM[2,2] := 1-flp.z*2;
  rotM[0,3] := ((dim.v[perm.x-1])-1) * flp.x;
  rotM[1,3] := ((dim.v[perm.y-1])-1) * flp.y;
  rotM[2,3] := ((dim.v[perm.z-1])-1) * flp.z;
  residualR := rotM.Inverse;
  residualR *= R;
  for i := 0 to 2 do
      if (flp.v[i] <> 0) then perm.v[i] := -perm.v[i];
end;

function SForm2Mat(hdr: TNIFTIhdr): TMat4;
begin
  result := TMat4.Identity;
  result[0,0] := hdr.srow_x[0]; result[0,1] := hdr.srow_x[1]; result[0,2] := hdr.srow_x[2]; result[0,3] := hdr.srow_x[3];
  result[1,0] := hdr.srow_y[0]; result[1,1] := hdr.srow_y[1]; result[1,2] := hdr.srow_y[2]; result[1,3] := hdr.srow_y[3];
  result[2,0] := hdr.srow_z[0]; result[2,1] := hdr.srow_z[1]; result[2,2] := hdr.srow_z[2]; result[2,3] := hdr.srow_z[3];
end; 

procedure SaveRotated(var rawVolBytes: TUInt8s; var hdr : TNIFTIhdr; isSaveRightToLeft: boolean = false);
var
   R, Rout: TMat4;
   fDim: TVec3i; 
   fScale: TVec3;
   perm: TVec3i;
begin
     if hdr.sform_code = kNIFTI_XFORM_UNKNOWN then exit;
     R := SForm2Mat(hdr);
     fDim.x := hdr.dim[1];
     fDim.y := hdr.dim[2];
     fDim.z := hdr.dim[3];
     fScale.x := 1;
     fScale.x := 2;
     fScale.x := 3;
     if not EstimateReorient(fDim, R, Rout, perm, isSaveRightToLeft)  then exit;
     ApplyVolumeReorient(perm, Rout, fDim, fScale, hdr, rawVolBytes);   
end;

end.

