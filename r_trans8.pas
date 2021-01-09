//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
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

unit r_trans8;

// Description
// Transparency for 8 bit color modes

interface

uses
  d_fpc,
  m_fixed;

procedure R_InitTransparency8Tables;

procedure R_FreeTransparency8Tables;

type
  trans8table_t = packed array[0..$FFFF] of byte;
  Ptrans8table_t = ^trans8table_t;

const
  NUMTRANS8TABLES = 8; // Actual tables are NUMTRANS8TABLES + 1

var
  trans8tables: array[0..NUMTRANS8TABLES] of Ptrans8table_t;
  additive8tables: array[0..NUMTRANS8TABLES] of Ptrans8table_t;
  subtractive8tables: array[0..NUMTRANS8TABLES] of Ptrans8table_t;
  trans8tablescalced: boolean = false;
  averagetrans8table: Ptrans8table_t = nil;
  coloraddtrans8table: Ptrans8table_t = nil;
  grayscale8tables: array[1..4] of array[0..$FF] of byte;
  subsampling8tables: array[1..4] of array[0..$FF] of byte;

function R_GetTransparency8table(const factor: fixed_t = FRACUNIT div 2): Ptrans8table_t;

function R_GetAdditive8table(const factor: fixed_t = FRACUNIT div 2): Ptrans8table_t;

function R_GetSubtractive8table(const factor: fixed_t = FRACUNIT div 2): Ptrans8table_t;

function R_FastApproxColorIndex(const c: LongWord): byte; overload;

function R_FastApproxColorIndex(const r, g, b: byte): byte; overload;

implementation

uses
  r_hires,
  v_video,
  z_memory;

const
  FASTTABLESHIFT = 3;
  FASTTABLEBIT = 1 shl FASTTABLESHIFT;
  FASTTABLECHANNEL = 256 div FASTTABLEBIT;
  FASTTABLESIZE = FASTTABLECHANNEL * FASTTABLECHANNEL * FASTTABLECHANNEL;

var
  approxcolorindexarray: array[0..FASTTABLESIZE - 1] of byte;

procedure R_InitTransparency8Tables;
var
  dest: PLongWord;
  src: PByteArray;
  pal: PByteArray; // Palette lump data
  palL: array[0..255] of LongWord; // Longword palette indexes
  i, j, k: integer;
  factor: fixed_t;
  c: LongWord;
  c1: LongWord;
  r, g, b: LongWord;
  r1, g1, b1: LongWord;
  ptrans8: PByte;
  gray1, gray2, gray3, gray4: LongWord;
begin
  if trans8tablescalced then
    exit;

// Expand WAD palette to longword values
  dest := @palL[0];
  pal := V_ReadPalette(PU_STATIC);
  src := pal;
  while PCAST(src) < PCAST(@pal[256 * 3]) do
  begin
    dest^ := (LongWord(src[0]) shl 16) or
             (LongWord(src[1]) shl 8) or
             (LongWord(src[2]));
    inc(dest);
    src := pOp(src, 3);
  end;
  Z_ChangeTag(pal, PU_CACHE);

  for i := 0 to NUMTRANS8TABLES do
  begin
    trans8tables[i] := malloc(SizeOf(trans8table_t));
    ptrans8 := PByte(trans8tables[i]);
    factor := i * (FRACUNIT div NUMTRANS8TABLES);
    for j := 0 to 255 do
    begin
      c1 := palL[j];
      for k := 0 to 255 do
      begin
        c := R_ColorAverageAlpha(palL[k], c1, factor);
        ptrans8^ := V_FindAproxColorIndex(@palL, c) and $FF;
        inc(ptrans8);
      end;
    end;
  end;

  averagetrans8table := trans8tables[NUMTRANS8TABLES div 2];

  ptrans8 := @approxcolorindexarray[0];
  for r := 0 to FASTTABLECHANNEL - 1 do
    for g := 0 to FASTTABLECHANNEL - 1 do
      for b := 0 to FASTTABLECHANNEL - 1 do
      begin
        ptrans8^ := V_FindAproxColorIndex(@palL,
                          r shl (16 + FASTTABLESHIFT) + g shl (8 + FASTTABLESHIFT) + b shl FASTTABLESHIFT +
                          (((1 shl FASTTABLESHIFT) shr 1) shl 16 + ((1 shl FASTTABLESHIFT) shr 1) shl 8 + ((1 shl FASTTABLESHIFT) shr 1))
                    ) and $FF;
        inc(ptrans8);
      end;

  for i := 0 to NUMTRANS8TABLES do
  begin
    additive8tables[i] := malloc(SizeOf(trans8table_t));
    ptrans8 := PByte(additive8tables[i]);
    for j := 0 to 255 do
    begin
      c1 := palL[j];
      r := ((c1 and $FF) * i * (FRACUNIT div NUMTRANS8TABLES)) div FRACUNIT;
      if r > 255 then
        r := 255;
      g := (((c1 shr 8) and $FF) * i * (FRACUNIT div NUMTRANS8TABLES)) div FRACUNIT;
      if g > 255 then
        g := 255;
      b := (((c1 shr 16) and $FF) * i * (FRACUNIT div NUMTRANS8TABLES)) div FRACUNIT;
      if b > 255 then
        b := 255;
      c1 := r + g shl 8 + b shl 16;
      for k := 0 to 255 do
      begin
        c := R_ColorAdd(palL[k], c1);
        ptrans8^ := V_FindAproxColorIndex(@palL, c) and $FF;
        inc(ptrans8);
      end;
    end;
  end;

  for i := 0 to NUMTRANS8TABLES do
  begin
    subtractive8tables[i] := malloc(SizeOf(trans8table_t));
    ptrans8 := PByte(subtractive8tables[i]);
    for j := 0 to 255 do
    begin
      c1 := palL[j];
      r := ((c1 and $FF) * i * (FRACUNIT div NUMTRANS8TABLES)) div FRACUNIT;
      if r > 255 then
        r := 255;
      g := (((c1 shr 8) and $FF) * i * (FRACUNIT div NUMTRANS8TABLES)) div FRACUNIT;
      if g > 255 then
        g := 255;
      b := (((c1 shr 16) and $FF) * i * (FRACUNIT div NUMTRANS8TABLES)) div FRACUNIT;
      if b > 255 then
        b := 255;
      c1 := r + g shl 8 + b shl 16;
      for k := 0 to 255 do
      begin
        c := R_ColorSubtract(palL[k], c1);
        ptrans8^ := V_FindAproxColorIndex(@palL, c) and $FF;
        inc(ptrans8);
      end;
    end;
  end;

  coloraddtrans8table := malloc(SizeOf(trans8table_t));
  ptrans8 := @coloraddtrans8table[0];
  for j := 0 to 255 do
  begin
    c1 := palL[j];
    r := (c1 shr 16) and $ff;
    g := (c1 shr 8) and $ff;
    b := c1 and $ff;
    for k := 0 to 255 do
    begin
      c := R_ColorLightAdd(palL[k], r, g, b);
      ptrans8^ := V_FindAproxColorIndex(@palL, c) and $FF;
      inc(ptrans8);
    end;
  end;

  // Grayscale
  for j := 0 to 255 do
  begin
    c1 := palL[j];
    r := (c1 shr 16) and $ff;
    g := (c1 shr 8) and $ff;
    b := c1 and $ff;

    gray1 := (r + g + b) div 3;  // Average
    if gray1 > 255 then gray1 := 255;
    gray2 := Trunc(r * 0.299 + g * 0.587 + b * 0.114); // Human perceive
    if gray2 > 255 then gray2 := 255;
    gray3 := Trunc(r * 0.2126 + g * 0.7152 + b * 0.0722); // Luma
    if gray3 > 255 then gray3 := 255;
    gray4 := (min3b(r, g, b) + max3b(r, g, b)) div 2; // Desaturation
    if gray4 > 255 then gray4 := 255;

    grayscale8tables[1, j] := V_FindAproxColorIndex(@palL, gray1 + gray1 shl 8 + gray1 shl 16);
    grayscale8tables[2, j] := V_FindAproxColorIndex(@palL, gray2 + gray2 shl 8 + gray2 shl 16);
    grayscale8tables[3, j] := V_FindAproxColorIndex(@palL, gray3 + gray3 shl 8 + gray3 shl 16);
    grayscale8tables[4, j] := V_FindAproxColorIndex(@palL, gray4 + gray4 shl 8 + gray4 shl 16);
  end;

  // Color subsampling
  for j := 0 to 255 do
  begin
    c1 := palL[j];
    r := (c1 shr 16) and $ff;
    g := (c1 shr 8) and $ff;
    b := c1 and $ff;

    r1 := (r shr 4) shl 4 + 8;
    g1 := (g shr 4) shl 4 + 8;
    b1 := (b shr 4) shl 4 + 8;
    subsampling8tables[1, j] := V_FindAproxColorIndex(@palL, r1 shl 16 + g1 shl 8 + b1);

    r1 := (r shr 5) shl 5 + 16;
    g1 := (g shr 5) shl 5 + 16;
    b1 := (b shr 5) shl 5 + 16;
    subsampling8tables[2, j] := V_FindAproxColorIndex(@palL, r1 shl 16 + g1 shl 8 + b1);

    r1 := (r shr 6) shl 6 + 32;
    g1 := (g shr 6) shl 6 + 32;
    b1 := (b shr 6) shl 6 + 32;
    subsampling8tables[3, j] := V_FindAproxColorIndex(@palL, r1 shl 16 + g1 shl 8 + b1);

    r1 := (r div 85) * 85 + 42;
    g1 := (g div 85) * 85 + 42;
    b1 := (b div 85) * 85 + 42;
    subsampling8tables[4, j] := V_FindAproxColorIndex(@palL, r1 shl 16 + g1 shl 8 + b1);
  end;


  trans8tablescalced := true;
end;

function R_FastApproxColorIndex(const c: LongWord): byte;
var
  r, g, b: LongWord;
begin
  b := (c shr FASTTABLESHIFT) and $FF;
  g := (c shr (FASTTABLESHIFT + 8)) and $FF;
  r := (c shr (FASTTABLESHIFT + 16)) and $FF;
  result := approxcolorindexarray[r shl (16 - FASTTABLESHIFT - FASTTABLESHIFT) + g shl (8 - FASTTABLESHIFT) + b];
end;

function R_FastApproxColorIndex(const r, g, b: byte): byte; overload;
var
  r1, g1, b1: LongWord;
begin
  b1 := b shr FASTTABLESHIFT;
  g1 := g shr FASTTABLESHIFT;
  r1 := r shr FASTTABLESHIFT;
  result := approxcolorindexarray[r1 shl (16 - FASTTABLESHIFT - FASTTABLESHIFT) + g1 shl (8 - FASTTABLESHIFT) + b1];
end;

procedure R_FreeTransparency8Tables;
var
  i: integer;
begin
  for i := 0 to NUMTRANS8TABLES do
  begin
    memfree(pointer(trans8tables[i]), SizeOf(trans8table_t));
    memfree(pointer(additive8tables[i]), SizeOf(trans8table_t));
    memfree(pointer(subtractive8tables[i]), SizeOf(trans8table_t));
  end;

  memfree(coloraddtrans8table, SizeOf(trans8table_t));

  averagetrans8table := nil;

  trans8tablescalced := false;
end;

function R_GetTransparency8table(const factor: fixed_t = FRACUNIT div 2): Ptrans8table_t;
var
  idx: integer;
begin
  idx := (factor * NUMTRANS8TABLES) div FRACUNIT;
  if idx < 0 then
    idx := 0
  else if idx > NUMTRANS8TABLES then
    idx := NUMTRANS8TABLES;
  result := trans8tables[idx];
end;

function R_GetAdditive8table(const factor: fixed_t = FRACUNIT div 2): Ptrans8table_t;
var
  idx: integer;
begin
  idx := (factor * NUMTRANS8TABLES) div FRACUNIT;
  if idx < 0 then
    result := additive8tables[0]
  else if idx > NUMTRANS8TABLES then
    result := additive8tables[NUMTRANS8TABLES]
  else
    result := additive8tables[idx];
end;

function R_GetSubtractive8table(const factor: fixed_t = FRACUNIT div 2): Ptrans8table_t;
var
  idx: integer;
begin
  idx := (factor * NUMTRANS8TABLES) div FRACUNIT;
  if idx < 0 then
    result := subtractive8tables[0]
  else if idx > NUMTRANS8TABLES then
    result := subtractive8tables[NUMTRANS8TABLES]
  else
    result := subtractive8tables[idx];
end;

end.

