//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2022 by Jim Valavanis
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

unit r_grayscale;

interface

uses
  d_fpc;

var
  grayscalemode: integer = 0;

//==============================================================================
// R_GrayScaleBuffer8
//
// Grayscale buffer - 8 bit
//
//==============================================================================
procedure R_GrayScaleBuffer8(const y: PInteger);

//==============================================================================
// R_GrayScaleBuffer32
//
// Grayscale buffer - 32 bit
//
//==============================================================================
procedure R_GrayScaleBuffer32(const y: PInteger);

//==============================================================================
//
// R_GrayScaleBuffer
//
//==============================================================================
procedure R_GrayScaleBuffer;

implementation

uses
  r_draw,
  r_main,
  r_trans8,
  r_render;

//==============================================================================
// R_GrayScaleBuffer8
//
// Grayscale buffer - 8 bit
//
//==============================================================================
procedure R_GrayScaleBuffer8(const y: PInteger);
var
  i: integer;
  pb: PByteArray;
  pgray: PByteArray;
begin
  pb := @((ylookup8[y^]^)[columnofs[0]]);
  pgray := @grayscale8tables[grayscalemode];
  for i := 0 to viewwidth - 1 do
    pb[i] := pgray[pb[i]];
end;

//==============================================================================
//
// R_Grayscale1
//
//==============================================================================
function R_Grayscale1(const c: LongWord): LongWord;
var
  r, g, b: byte;
  gray: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  gray := (r + g + b) div 3;  // Average
  if gray > 255 then gray := 255;
  result := gray + gray shl 8 + gray shl 16;
end;

//==============================================================================
//
// R_Grayscale2
//
//==============================================================================
function R_Grayscale2(const c: LongWord): LongWord;
var
  r, g, b: byte;
  gray: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  gray := Trunc(r * 0.299 + g * 0.587 + b * 0.114); // Human perceive
  if gray > 255 then gray := 255;
  result := gray + gray shl 8 + gray shl 16;
end;

//==============================================================================
//
// R_Grayscale3
//
//==============================================================================
function R_Grayscale3(const c: LongWord): LongWord;
var
  r, g, b: byte;
  gray: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  gray := Trunc(r * 0.2126 + g * 0.7152 + b * 0.0722); // Luma
  if gray > 255 then gray := 255;
  result := gray + gray shl 8 + gray shl 16;
end;

//==============================================================================
//
// R_Grayscale4
//
//==============================================================================
function R_Grayscale4(const c: LongWord): LongWord;
var
  r, g, b: byte;
  gray: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  gray := (min3b(r, g, b) + max3b(r, g, b)) div 2; // Desaturation
  if gray > 255 then gray := 255;
  result := gray + gray shl 8 + gray shl 16;
end;

type
  grayscalecolorfunc_t = function (const c: LongWord): LongWord;

var
  grayscalecolorfunc: grayscalecolorfunc_t;

//==============================================================================
// R_GrayScaleBuffer32
//
// Grayscale buffer - 32 bit
//
//==============================================================================
procedure R_GrayScaleBuffer32(const y: PInteger);
var
  i: integer;
  pl: PLongWordArray;
begin
  pl := @((ylookup32[y^]^)[columnofs[0]]);
  for i := 0 to viewwidth - 1 do
    pl[i] := grayscalecolorfunc(pl[i]);
end;

//==============================================================================
//
// R_GrayScaleBuffer
//
//==============================================================================
procedure R_GrayScaleBuffer;
var
  y: integer;
begin
  grayscalemode := grayscalemode mod 5;
  if grayscalemode = 0 then
    exit;

  // Determine function to use
  case grayscalemode of
   1: grayscalecolorfunc := @R_Grayscale1;
   2: grayscalecolorfunc := @R_Grayscale2;
   3: grayscalecolorfunc := @R_Grayscale3;
   4: grayscalecolorfunc := @R_Grayscale4;
  end;

  for y := 0 to viewheight - 1 do
    R_AddRenderTask(grayscalefunc, RF_GRAYSCALE, @y);
end;

end.

