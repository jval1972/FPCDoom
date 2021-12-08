//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2021 by Jim Valavanis
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.
//
//------------------------------------------------------------------------------
//  E-Mail: jimmyvalavanis@yahoo.gr
//  Site  : https://sourceforge.net/projects/fpcdoom/
//------------------------------------------------------------------------------

{$I FPCDoom.inc}

{
   *********************************************************************
   Version: 1998.06.09
   Copyright (C) 1997, 1998 Gertjan Schouten

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   *********************************************************************

   Modified by Matthias K"oppe <mkoeppe@cs.uni-magdeburg.de>:
   Added support for 1-bpp and 4-bpp bitmaps.

   Modified by Carl Eric Codere <ccodere@ieee.org>:
   Fixes for FPC 1.0.x compilation
}

unit t_main;

interface

uses
  d_fpc,
  t_colors;

const
   //        redpos       greenpos     bluepos
   ptRGBl = ( 0 shl 8) + (8 shl 16) + (16 shl 24);
   ptBGRl = (16 shl 8) + (8 shl 16) + ( 0 shl 24);
   ptRGBw = ( 0 shl 8) + (5 shl 16) + (10 shl 24);
   ptBGRw = (10 shl 8) + (5 shl 16) + ( 0 shl 24);

   ptRGB8 = ptRGBl + 8; { 00000000 bbbbbbbb gggggggg rrrrrrrr }
   ptRGB6 = ptRGBl + 6; { 00000000 00bbbbbb 00gggggg 00rrrrrr ** VGA palet layout ** }
   ptRGB5 = ptRGBw + 5; {                   0bbbbbgg gggrrrrr }

   ptBGR8 = ptBGRl + 8; { 00000000 rrrrrrrr gggggggg bbbbbbbb }
   ptBGR6 = ptBGRl + 6; { 00000000 00rrrrrr 00gggggg 00bbbbbb }
   ptBGR5 = ptBGRw + 5; {                   0rrrrrgg gggbbbbb }

   // pixel formats

   pfBGR15 = ptBGRw + 2; { 0rrrrrgg gggbbbbb }
   pfBGR24 = ptBGRl + 3; { rrrrrrrr gggggggg bbbbbbbb }
   pfBGR32 = ptBGRl + 4; { 00000000 rrrrrrrr gggggggg bbbbbbbb }

type
  TPaletType = integer;
  TEncodeColor = function(rgbcolor: integer): integer;
  TPalette = array[0..255] of integer;
  PPalette = ^TPalette;

  PTexture = ^TTexture;

  TTexture = object
  private
    FData: pointer;
    FWidth: word;
    FHeight: word;
    FSize: integer;
    FBytesPerPixel: word;
    FBitsPerPixel: word;
    FEncodeColor: TEncodeColor;
    FPalette: pointer;
    FTransformedPalette: pointer; // For palette change effects
    FPalColor: LongWord;
    FTransparentColor: LongWord;
    FTransparentColor2: LongWord;
    FTransparentColor3: LongWord;
    procedure putPixels1(Source, Dest: Pointer; Count: integer);
    procedure putPixels4(Source, Dest: Pointer; Count: integer);
    procedure putPixels8(Source, Dest: Pointer; Count: integer);
    procedure putPixels15(Source, Dest: Pointer; Count: integer);
    procedure putPixels24(Source, Dest: Pointer; Count: integer);
    procedure putPixels32(Source, Dest: Pointer; Count: integer);
  public
    constructor Create;
    destructor Destroy; virtual;
    procedure Empty;
    function LoadFromFile(const FileName: string): boolean;
    function LoadFromStream(stream: TStream; const alias: string): boolean;
    function GetData: pointer;
    function GetImage: pointer;
    function GetPalette: PPalette;
    function GetTransformedPalette: PPalette;
    function GetWidth: integer;
    function GetHeight: integer;
    function GetSize: integer;
    function HasPalette: boolean;
    procedure GetColumn32(col: integer; size: integer; dest: pointer);
    function GetPalettedColumn32(col: integer; size: integer; dest: pointer; APalColor: LongWord): boolean;
    procedure GetRow32(row: integer; size: integer; dest: pointer);
    function  GetPalettedRow32(row: integer; size: integer; dest: pointer; APalColor: LongWord): boolean;
    procedure AddColorOverlay(const color: LongWord);
    procedure ScaleTo(AWidth, AHeight: word);
    procedure SetWidth(Value: word);
    procedure SetHeight(Value: word);
    procedure SetBytesPerPixel(Value: word);
    function GetBytesPerPixel: word;
    procedure SetPalette(APalette: Pointer; Count:Word; PaletType: TPaletType; RecordSize: word);
    procedure SetPalColor(AColor: LongWord);
    procedure PutPixels(X, Y: Integer; Count: integer; Buffer: Pointer; PixelFormat: integer);
    procedure Adjust32bitTransparency;
    function GetTransparentColor: LongWord;
    procedure SetTransparentColor(const value: LongWord);
    function GetTransparentColor2: LongWord;
    procedure SetTransparentColor2(const value: LongWord);
    function GetTransparentColor3: LongWord;
    procedure SetTransparentColor3(const value: LongWord);
    function Clone: PTexture;
  end;

function T_LoadHiResTexture(const FileName: string): PTexture;

var
  TextureExtensions: TDStringList;

type
  PTextureManager = ^TTextureManager;

  TTextureManager = object
  private
    FFileExt: integer;
  protected
    FBitmap: PTexture;
    FFrame: integer;
    FFrameCount: integer;
    FNext: PTextureManager;
    procedure SetFileExt(const ext: string);
  public
    function LoadFromFile(const FileName: string): boolean;
    function LoadFromStream(Stream: TStream): boolean;
    procedure SetFrame(Value: integer);
    procedure SetNext(Value: PTextureManager);
    function GetFileExt: string;
    function GetBitmap: PTexture;
    function GetFrameCount: integer;
    function GetNext: PTextureManager;
    procedure SetBitmap(Value: PTexture);
    constructor Create;
    function LoadHeader(Stream: TStream): boolean; virtual;
    function LoadImage(Stream: TStream): boolean; virtual;
    destructor Destroy; virtual;
  end;

function GetImageFormat(FileExt: string): PTextureManager;
procedure SetBytesPerPixelAddr(Value: pointer);

procedure T_Init;

procedure T_ShutDown;

var
  preferetexturesnamesingamedirectory: boolean;

implementation

uses
  doomdef,
  i_system,
  t_bmp,
  t_tga,
  t_png,
  t_draw,
  r_hires,
  w_pak;

const
  BytesPerPixel_Addr: PWord = nil;

function pixel15to24(color: word): LongWord; assembler;
asm
  xor  eax, eax
  mov  ax, color
  shl  eax, $6
  shr  ax, $6
  shl  eax, $3
  shl  ah, $3
end;

//
// JVAL
// Load external texture using the PAKFileSystem
//
function T_LoadHiResTexture(const FileName: string): PTexture;
var
  i: integer;
  ext: string;
  tm: PTextureManager;
  done: boolean;
  strm: TPakStream;
  tname: string;
begin
  done := false;
  result := new(PTexture, Create);
  for i := 0 to TextureExtensions.Count - 1 do
  begin
    if done then
      break;
    ext := TextureExtensions[i];
    tm := GetImageFormat(ext);
    if tm <> nil then
    begin
      tm^.SetBitmap(result);
      tname := FileName + ext;
      if preferetexturesnamesingamedirectory then
        strm := TPakStream.Create(tname, pm_prefered, gamedirectories)
      else
        strm := TPakStream.Create(tname, pm_short);
      strm.OnBeginBusy := I_BeginDiskBusy;
      if strm.IOResult = 0 then
        if tm^.LoadFromStream(strm) then
        begin
          printf('  Found external texture %s'#13#10, [tname]);
          done := true;
        end;
      strm.Free;
    end;
  end;

  if not done then
  begin
    dispose(result, Destroy);
    result := nil;
  end;
end;

constructor TTexture.Create;
begin
  Empty;
  FTransparentColor := 0;
  FTransparentColor2 := 0;
  FTransparentColor3 := 0;
end;

destructor TTexture.destroy;
begin
  Empty;
end;

function TTexture.LoadFromFile(const FileName: string): boolean;
var
  i: integer;
  ImageFormat: PTextureManager;
begin
  result := false;
  i := length(FileName);
  while (FileName[i] <> '.') and (i > 0) do
    dec(i);
  if i = 0 then
    exit;
  ImageFormat := GetImageFormat(Copy(FileName, i, Length(FileName)));
  if ImageFormat <> nil then
  begin
    ImageFormat^.setBitmap(@self);
    result := ImageFormat^.LoadFromFile(FileName);
  end;
end;

function TTexture.LoadFromStream(stream: TStream; const alias: string): boolean;
var
  i: integer;
  ImageFormat: PTextureManager;
begin
  result := false;
  i := length(alias);
  while (alias[i] <> '.') and (i > 0) do
    dec(i);
  if i = 0 then
    exit;
  ImageFormat := GetImageFormat(Copy(alias, i, Length(alias)));
  if ImageFormat <> nil then
  begin
    ImageFormat^.SetBitmap(@self);
    result := ImageFormat^.LoadFromStream(stream);
  end;
end;

procedure TTexture.Empty;
begin
  if (FData <> nil) and (FSize > 0) then
    memfree(FData, FSize);
  if FPalette <> nil then
    memfree(FPalette, 256 * SizeOf(integer));
  if FTransformedPalette <> nil then
    memfree(FTransformedPalette, 256 * SizeOf(integer));
  FWidth := 0;
  FHeight := 0;
  FSize := 0;
  if BytesPerPixel_Addr <> nil then
    SetBytesPerPixel(BytesPerPixel_Addr^)
  else
    SetBytesPerPixel(0);
end;

function TTexture.GetData: pointer;
begin
  result := FData;
end;

function TTexture.GetImage: pointer;
begin
  result := pOp(FData, 4);
end;

function TTexture.GetPalette: PPalette;
begin
  if FPalette = nil then
    result := @DefaultPalette
  else
    result := FPalette;
end;

function TTexture.GetTransformedPalette: PPalette;
begin
  if FTransformedPalette = nil then
    result := @DefaultPalette
  else
    result := FTransformedPalette;
end;

function TTexture.GetWidth: integer;
begin
  result := FWidth;
end;

function TTexture.GetHeight: integer;
begin
  result := FHeight;
end;

function TTexture.GetSize: integer;
begin
  result := FSize;
end;

function TTexture.HasPalette: boolean;
begin
  result := FPalette <> nil;
end;

procedure TTexture.GetColumn32(col: integer; size: integer; dest: pointer);
var
  row: integer;
  irow: integer; // Original internal row
  src: pointer;
  dst: pointer;
  srcstep: integer;
begin
  col := col mod FWidth;
  src := pOp(FData, 4 + col * FBytesPerPixel);
  dst := dest;
  row := 0;
  irow := FHeight;
  case FBytesPerPixel of
     1:
      begin
        srcstep := FWidth;
        while row < size do
        begin
          PLongWord(dst)^ := PLongWord(@PPalette(FPalette)[PByte(src)^])^;
          dst := pOp(dst, 4);
          src := pOp(src, srcstep);
          inc(row);
          dec(irow);
          if irow <= 0 then
          begin
            irow := FHeight;
            src := pOp(FData, 4 + col);
          end;
        end;
      end;
     2:
      begin
        srcstep := 2 * FWidth;
        while row < size do
        begin
          PLongWord(dst)^ := pixel15to24(PWord(src)^);
          dst := pOp(dst, 4);
          src := pOp(src, srcstep);
          inc(row);
          dec(irow);
          if irow <= 0 then
          begin
            irow := FHeight;
            src := pOp(FData, 4 + col * 2);
          end;
        end;
      end;
     4:
      begin
        srcstep := 4 * FWidth;
        while row < size do
        begin
          PLongWord(dst)^ := PLongWord(src)^;
          dst := pOp(dst, 4);
          src := pOp(src, srcstep);
          inc(row);
          dec(irow);
          if irow <= 0 then
          begin
            irow := FHeight;
            src := pOp(FData, 4 + col * 4);
          end;
        end;
      end;
  end;
end;

function TTexture.GetPalettedColumn32(col: integer; size: integer; dest: pointer; APalColor: LongWord): boolean;
var
  row: integer;
  irow: integer; // Original internal row
  src: pointer;
  dst: pointer;
  srcstep: integer;
begin
  if FBytesPerPixel = 1 then
  begin
    col := col mod FWidth;
    src := pOp(FData, 4 + col * FBytesPerPixel);
    dst := dest;
    row := 0;
    irow := FHeight;
    srcstep := FWidth;
    SetPalColor(APalColor);
    while row < size do
    begin
      PLongWord(dst)^ := PLongWord(@PPalette(FTransformedPalette)[PByte(src)^])^;
      dst := pOp(dst, 4);
      src := pOp(src, srcstep);
      inc(row);
      dec(irow);
      if irow <= 0 then
      begin
        irow := FHeight;
        src := pOp(FData, 4 + col);
      end;
    end;
    result := true;
  end
  else
    result := false;
end;

procedure TTexture.GetRow32(row: integer; size: integer; dest: pointer);
var
  col: integer;
  icol: integer; // Original internal row
  src: pointer;
  dst: pointer;
begin
  row := row mod FHeight;
  src := pOp(FData, 4 + row * FBytesPerPixel * FWidth);
  dst := dest;
  col := 0;
  icol := FWidth;
  case FBytesPerPixel of
     1:
      begin
        while col < size do
        begin
          PLongWord(dst)^ := PLongWord(@PPalette(FPalette)[PByte(src)^])^;
          dst := pOp(dst, 4);
          src := pOp(src, 1);
          inc(col);
          dec(icol);
          if icol <= 0 then
          begin
            icol := FWidth;
            src := pOp(FData, 4 + row * FWidth);
          end;
        end;
      end;
     2:
      begin
        while col < size do
        begin
          PLongWord(dst)^ := pixel15to24(PWord(src)^);
          dst := pOp(dst, 4);
          src := pOp(src, 2);
          inc(col);
          dec(icol);
          if icol <= 0 then
          begin
            icol := FWidth;
            src := pOp(FData, 4 + 2 * row * FWidth);
          end;
        end;
      end;
     4:
      begin
        while col < size do
        begin
          PLongWord(dst)^ := PLongWord(src)^;
          dst := pOp(dst, 4);
          src := pOp(src, 4);
          inc(col);
          dec(icol);
          if icol <= 0 then
          begin
            icol := FWidth;
            src := pOp(FData, 4 + 4 * row * FWidth);
          end;
        end;
      end;
  end;
end;

function  TTexture.GetPalettedRow32(row: integer; size: integer; dest: pointer; APalColor: LongWord): boolean;
var
  col: integer;
  icol: integer; // Original internal row
  src: pointer;
  dst: pointer;
begin
  if FBytesPerPixel = 1 then
  begin
    row := row mod FHeight;
    src := pOp(FData, 4 + row * FBytesPerPixel * FWidth);
    dst := dest;
    col := 0;
    icol := FWidth;
    SetPalColor(APalColor);
    while col < size do
    begin
      PLongWord(dst)^ := PLongWord(@PPalette(FPalette)[PByte(src)^])^;
      dst := pOp(dst, 4);
      src := pOp(src, 1);
      inc(col);
      dec(icol);
      if icol <= 0 then
      begin
        icol := FWidth;
        src := pOp(FData, 4 + row * FWidth);
      end;
    end;
    result := true;
  end
  else
    result := false;
end;


// JVAL: Unused
procedure TTexture.AddColorOverlay(const color: LongWord);
var
  plw: PLongWord;
  i: integer;
begin
  if (FBytesPerPixel = 4) and (color <> 0) then
  begin
    plw := pOp(FData, 4);
    for i := 0 to FWidth * FHeight - 1 do
    begin
      plw^ := R_ColorAdd(plw^, color);
      inc(plw);
    end;
  end;
end;

procedure TTexture.ScaleTo(AWidth, AHeight: word);
var
  xs, ys, yi, xi, x, y: integer;
  newimage: pointer;
  newsize: integer;
  esi, edi: pointer;
begin
  if FData = nil then
  begin
    SetWidth(AWidth);
    SetHeight(AHeight);
    exit;
  end
  else if (AWidth = FWidth) and (AHeight = FHEIGHT) then
    exit;

  xi := (FWidth shl 16) div aWidth;
  yi := (FHeight shl 16) div aHeight;
  newSize := 4 + AWidth * AHeight * FBytesPerPixel;
  NewImage := malloc(newSize);
  PWord(newImage)^ := AWidth;
  PWord(pOp(newImage, 2))^ := AHeight;
  edi := pOp(newImage, 4);
  ys := 0;
  for y := 0 to AHeight - 1 do
  begin
    esi := pOp(FData, 4 + (ys shr 16) * (fWidth * FBytesPerPixel));
    xs := 0;
    case FBytesPerPixel of
       1:
        for x := 0 to AWidth - 1 do
        begin
          PByteArray(edi)[x] := PByteArray(esi)[xs shr 16];
          xs := xs + xi;
        end;
       2:
        for x := 0 to AWidth - 1 do
        begin
          PWordArray(edi)[x] := PWordArray(esi)[xs shr 16];
          xs := xs + xi;
        end;
       4:
        for x := 0 to AWidth - 1 do
        begin
          PIntegerArray(edi)[x] := PIntegerArray(esi)[xs shr 16];
          xs := xs + xi;
        end;
    end;
    edi := pOp(edi, FBytesPerPixel * AWidth);
    ys := ys + yi;
  end;
  memfree(FData, FSize);
  FData := newImage;
  FWidth := AWidth;
  FHeight := AHeight;
  FSize := NewSize;
end;

procedure TTexture.SetWidth(Value: word);
var
   newImage: pointer;
   y, newSize: integer;
begin
  if Value = FWidth then
    exit;
  if FHeight = 0 then
    fWidth := Value
  else if Value = 0 then
  begin
    if FData <> nil then
      memfree(FData, FSize);
    FData := nil;
    FSize := 0;
    FWidth := Value;
  end
  else
  begin
    newSize := 4 + Value * FHeight * FBytesPerPixel;
    newImage := malloc(newSize);
    PWord(newImage)^ := Value;
    PWord(pOp(newImage, 2))^ := FHeight;
    if FData <> nil then
    begin
      for y := 0 to FHeight - 1 do
      begin
        Move(pOp(FData, 4 + (FBytesPerPixel * FWidth * y))^,
             pOp(newImage, 4 + (FBytesPerPixel * Value * y))^,
             FBytesPerPixel * FWidth);
      end;
      memfree(FData, FSize);
    end;
    FData := newImage;
    FSize := newSize;
    FWidth := Value;
  end;
end;

procedure TTexture.SetHeight(Value: word);
var
  newImage: pointer;
  newSize: integer;
begin
  if Value = FHeight then
    exit;
  if FWidth = 0 then
    FHeight := Value
  else if Value = 0 then
  begin
    if FData <> nil then
      memfree(FData, FSize);
    FData := nil;
    FSize := 0;
    FHeight := Value;
  end
  else
  begin
    newSize := 4 + fWidth * Value * FBytesPerPixel;
    newImage := malloc(newSize);
    if FData <> nil then
    begin
      Move(FData^, newImage^, FSize);
      memfree(FData, FSize);
    end;
    PWord(newImage)^ := FWidth;
    PWord(pOp(newImage, 2))^ := Value;
    FData := newImage;
    FSize := newSize;
    FHeight := Value;
  end;
end;

procedure TTexture.SetBytesPerPixel(Value: word);
begin
  if (FBytesPerPixel <> Value) and (Value > 0) and (Value < 5) then
  begin
    FBytesPerPixel := Value;
    FBitsPerPixel := Value * 8;
    case FBytesPerPixel of
       1: FEncodeColor := @EncodeColor8;
       2: FEncodeColor := @EncodeColor15;
       4: FEncodeColor := @EncodeColor24;
    end;
    if FData <> nil then
      memfree(FData, FSize);
    FData := nil;
    FSize := 0;
    if (FWidth <> 0) and (FHeight <> 0) then
    begin
      FSize := 4 + FWidth * FHeight * FBytesPerPixel;
      FData := malloc(FSize);
      PWord(FData)^ := FWidth;
      PWord(pOp(FData, 2))^ := FHeight;
    end;
  end;
end;

function TTexture.GetBytesPerPixel: word;
begin
  result := FBytesPerPixel;
end;

procedure TTexture.SetPalette(APalette: Pointer; Count: Word; PaletType: TPaletType; RecordSize: Word);
var
  i: integer;
  r, g, b, m: byte;
  rshr, gshr, bshr: word;
begin
  if FPalette = nil then
    FPalette := malloc(256 * SizeOf(integer));
  if FTransformedPalette = nil then
    FTransformedPalette := malloc(256 * SizeOf(integer));
  FPalColor := 0;
  if PaletType > 0 then
  begin
    m := 8 - byte(PaletType);
    rshr := (PaletType shr 8) - m;
    gshr := (PaletType shr 16) - m;
    bshr := (PaletType shr 24) - m;
    m := 255 shl m;
    for i := 0 to Count - 1 do
    begin
      r := (PInteger(APalette)^ shr rshr) and m;
      g := (PInteger(APalette)^ shr gshr) and m;
      b := (PInteger(APalette)^ shr bshr) and m;
      PIntegerArray(FPalette)[i] := (r shl 16) or (g shl 8) or (b);
      APalette := pOp(APalette, RecordSize);
    end;
  end
  else
    Move(APalette^, FPalette^, Count * SizeOf(integer));
end;

procedure TTexture.SetPalColor(AColor: LongWord);
var
  i: integer;
begin
  if FPalColor <> AColor then
  begin
    FPalColor := AColor;
    if FPalColor <> 0 then
    begin
      for i := 0 to 255 do
        PLongWordArray(FTransformedPalette)[i] := R_ColorAdd(FPalColor, PLongWordArray(FPalette)[i]);
    end
    else
      memcpy(FTransformedPalette, FPalette, 255 * SizeOf(LongWord));
  end;
end;

// PUTPIXELS1: by Matthias K"oppe <mkoeppe@cs.uni-magdeburg.de>:

procedure TTexture.PutPixels1(Source, Dest: Pointer; Count: integer);
var
  i, j, c, b: integer;
begin
  for i := 0 to count div 8 - 1 do
  begin
    b := PByte(source)^;
    for j := 0 to 7 do
    begin
      c := FEncodeColor(PIntegerArray(FPalette)[(b shr 7) and 1]);
      Move(c, dest^, FBytesPerPixel);
      dest := pOp(dest, FBytesPerPixel);
      b := b shl 1;
    end;
    Source := pOp(Source, 1);
  end;
  b := PByte(source)^;
  for j := 0 to count and 7 - 1 do
  begin
    c := FEncodeColor(PIntegerArray(FPalette)[(b shr 7) and 1]);
    Move(c, dest^, FBytesPerPixel);
    dest := pOp(dest, FBytesPerPixel);
    b := b shl 1;
  end;
end;

// PUTPIXELS4: by Matthias K"oppe <mkoeppe@cs.uni-magdeburg.de>:

procedure TTexture.PutPixels4(Source, Dest: Pointer; Count: integer);
var
  i, c: integer;
begin
  for i := 0 to count div 2 - 1 do
  begin
    c := FEncodeColor(PIntegerArray(FPalette)[PByte(source)^ shr 4]);
    Move(c, dest^, FBytesPerPixel);
    dest := pOp(dest, FBytesPerPixel);
    c := FEncodeColor(PIntegerArray(FPalette)[PByte(source)^ and 15]);
    Move(c, dest^, FBytesPerPixel);
    dest := pOp(dest, FBytesPerPixel);
    Source := pOp(Source, 1);
  end;
  if count and 1 = 1 then
  begin
    c := FEncodeColor(PIntegerArray(FPalette)[PByte(source)^ shr 4]);
    Move(c, dest^, FBytesPerPixel);
  end;
end;

procedure TTexture.PutPixels8(Source, Dest: Pointer; Count: integer);
var
  i, c: integer;
begin
  for i := 0 to count - 1 do
  begin
    c := FEncodeColor(PIntegerArray(FPalette)[PByte(source)^]);
    Move(c, dest^, FBytesPerPixel);
    dest := pOp(dest, FBytesPerPixel);
    Source := pOp(Source, 1);
  end;
end;

procedure TTexture.PutPixels15(Source, Dest: Pointer; Count: integer);
var
  i, c: integer;
begin
  for i := 0 to count - 1 do
  begin
    c := FEncodeColor(Pixel15to24(PWord(Source)^));
    Move(c, dest^, FBytesPerPixel);
    dest := pOp(dest, FBytesPerPixel);
    Source := pOp(Source, 2);
  end;
end;

procedure TTexture.PutPixels24(Source, Dest: Pointer; Count: integer);
var
  i, c: integer;
begin
  for i := 0 to count - 1 do
  begin
    c := FEncodeColor(PInteger(Source)^);
    Move(c, Dest^, FBytesPerPixel);
    Dest := pOp(Dest, FBytesPerPixel);
    Source := pOp(Source, 3);
  end;
end;

procedure TTexture.PutPixels32(source, dest: pointer; count: integer);
var
  i, c: integer;
begin
  for i := 0 to count - 1 do
  begin
    c := FEncodeColor(PInteger(source)^);
    Move(c, dest^, FBytesPerPixel);
    dest := pOp(dest, FBytesPerPixel);
    Source := pOp(source, 4);
  end;
end;

// PUTPIXELS:
// some mods by Matthias K"oppe <mkoeppe@cs.uni-magdeburg.de>:

procedure TTexture.PutPixels(X, Y: Integer; Count: integer; Buffer: Pointer; PixelFormat: integer);
var
  ofs: pointer;
begin
  ofs := pOp(FData, 4 + (x + y * FWidth) * FBytesPerPixel);
  if PixelFormat and 255 = FBitsPerPixel then
    Move(Buffer^, ofs^, Count * FBytesPerPixel)
  else
  begin
    case Pixelformat and 255 of
       1: putpixels1(Buffer, Ofs, Count);
       4: putpixels4(Buffer, Ofs, Count);
       8: putpixels8(Buffer, Ofs, Count);
      15: putpixels15(Buffer, Ofs, Count);
      24: putpixels24(Buffer, Ofs, Count);
      32: putpixels32(Buffer, Ofs, Count);
    end;
  end;
end;

//
// JVAL: Adjust custom transparent color
//
procedure TTexture.Adjust32bitTransparency;
var
  pdest: PLongWord;
  pdeststop: PLongWord;
begin
  if (FTransparentColor = 0) and (FTransparentColor2 = 0) and (FTransparentColor3 = 0) then
    exit;

  SetBytesPerPixel(4);

  pdest := pOp(Fdata, 4);
  pdeststop := @PLongWordArray(pdest)[FWidth * FHeight];
  while PCAST(pdest) < PCAST(pdeststop) do
  begin
    if pdest^ = FTransparentColor then
      pdest^ := 0
    else if pdest^ = FTransparentColor2 then
      pdest^ := 0
    else if pdest^ = FTransparentColor3 then
      pdest^ := 0;
    inc(pdest);
  end;
end;

function TTexture.GetTransparentColor: LongWord;
begin
  result := FTransparentColor;
end;

procedure TTexture.SetTransparentColor(const value: LongWord);
begin
  FTransparentColor := value;
end;

function TTexture.GetTransparentColor2: LongWord;
begin
  result := FTransparentColor2;
end;

procedure TTexture.SetTransparentColor2(const value: LongWord);
begin
  FTransparentColor2 := value;
end;

function TTexture.GetTransparentColor3: LongWord;
begin
  result := FTransparentColor3;
end;

procedure TTexture.SetTransparentColor3(const value: LongWord);
begin
  FTransparentColor3 := value;
end;

function TTexture.Clone: PTexture;
begin
  result := new(PTexture, Create);
  result.SetBytesPerPixel(FBytesPerPixel);
  result.SetWidth(FWidth);
  result.SetHeight(FHeight);
  if FSize = result.GetSize then
  begin
    if FSize > 0 then
      Move(FData^, result.GetData^, FSize);
    if HasPalette then
      result.SetPalette(FPalette, 256, 0, 0);
  end
  else
  begin
    dispose(result, Destroy);
    result := nil;
  end;
end;

var
  ImageFormats: PTextureManager;

constructor TTextureManager.Create;
begin
  FFrame := 0;
  FBitmap := nil;
  FFileExt := 0;
  FFrameCount := 0;
  FNext := ImageFormats;
  ImageFormats := @self;
end;

procedure TTextureManager.SetNext(Value: PTextureManager);
begin
  FNext := Value;
end;

function TTextureManager.GetFileExt: string;
begin
  result := TextureExtensions[FFileExt];
end;

procedure TTextureManager.SetFileExt(const ext: string);
begin
  FFileExt := TextureExtensions.Add(ext);
end;

function TTextureManager.GetBitmap: PTexture;
begin
  result := FBitmap;
end;

function TTextureManager.GetFrameCount: integer;
begin
  result := fFrameCount;
end;

function TTextureManager.GetNext: PTextureManager;
begin
  result := fNext;
end;

function TTextureManager.LoadFromFile(const FileName: string): boolean;
var
  Stream: TStream;
begin
  Stream := TCachedFile.Create(FileName, fOpenReadOnly, $10000);
  try
    result := LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TTextureManager.LoadFromStream(Stream: TStream): boolean;
begin
  LoadFromStream := false;
  if FBitmap <> nil then
  begin
    SetFrame(0);
    LoadHeader(Stream);
    if FBitmap^.GetData <> nil then
      LoadFromStream := LoadImage(Stream);
   end;
end;

procedure TTextureManager.SetFrame(Value: integer);
begin
  fFrame := Value;
end;

procedure TTextureManager.SetBitmap(Value: PTexture);
begin
  FBitmap := Value;
end;

function TTextureManager.LoadHeader(Stream: TStream): boolean;
begin
  LoadHeader := false;
end;

function TTextureManager.LoadImage(Stream: TStream): boolean;
begin
  LoadImage := false;
end;

destructor TTextureManager.Destroy;
begin
end;

function GetImageFormat(FileExt: string): PTextureManager;
var
  i: integer;
begin
  for i := 1 to Length(FileExt) do
    FileExt[i] := toupper(FileExt[i]);
  result := ImageFormats;
  while result <> nil do
  begin
    if Pos(FileExt, result.GetFileExt) <> 0 then
      break;
    result := result^.getNext;
  end;
end;

procedure setBytesPerPixelAddr(Value: pointer);
begin
  BytesPerPixel_Addr := Value;
end;

var
  tm_bitmap: TBMPTextureManager;
  tm_targa: TTGATextureManager;
  tm_png: TPNGTextureManager;

procedure T_Init;
begin
  TextureExtensions := TDStringList.Create;
  ImageFormats := nil;
  tm_targa.Create;
  tm_bitmap.Create;
  tm_png.Create;

  T_InitDrawTextures;
end;

procedure T_ShutDown;
begin
  TextureExtensions.Free;
  tm_targa.Destroy;
  tm_bitmap.Destroy;
  tm_png.Destroy;

  T_ShutDownDrawTextures;
end;

end.
