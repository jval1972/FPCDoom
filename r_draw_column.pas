//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2019 by Jim Valavanis
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

unit r_draw_column;

interface

uses
  d_fpc,
  m_fixed,
  r_main,
  r_trans8,
  r_defs;

type
  columnparams_t = record
  // first pixel in a column (possibly virtual)
    dc_source: pointer;
    dc_colormap: PByteArray;
    dc_colormap32: PLongWordArray;
    dc_lightlevel: fixed_t;
    dc_iscale: fixed_t;
    dc_texturemid: fixed_t;
    dc_x: integer;
    dc_yl: integer;
    dc_yh: integer;
    dc_mod: integer; // JVAL for hi resolution
    dc_texturemod: integer; // JVAL for external textures
    dc_texturefactorbits: integer; // JVAL for hi resolution
    dc_alpha: fixed_t;
    curtrans8table: Ptrans8table_t;
    seg: Pseg_t;
    rendertype: LongWord;
  end;
  Pcolumnparams_t = ^columnparams_t;

// Column drawers
procedure R_DrawColumnMedium(const parms: Pcolumnparams_t);
procedure R_DrawColumnHi(const parms: Pcolumnparams_t);

// Masked column drawing functions
procedure R_DrawMaskedColumnNormal(const parms: Pcolumnparams_t);
procedure R_DrawMaskedColumnHi32(const parms: Pcolumnparams_t);

// Alpha column drawers (transparency effects)
procedure R_DrawColumnAlphaMedium(const parms: Pcolumnparams_t);
procedure R_DrawColumnAlphaHi(const parms: Pcolumnparams_t);

// Average column drawers (transparency effects)
procedure R_DrawColumnAverageMedium(const parms: Pcolumnparams_t);
procedure R_DrawColumnAverageHi(const parms: Pcolumnparams_t);

// The Spectre/Invisibility effect.
procedure R_InitFuzzTable;
procedure R_DrawFuzzColumn(const parms: Pcolumnparams_t);
procedure R_DrawFuzzColumn32(const parms: Pcolumnparams_t);
procedure R_DrawFuzzColumnHi(const parms: Pcolumnparams_t);

// Sky column drawing functions
// Sky column drawers
procedure R_DrawSkyColumn(const parms: Pcolumnparams_t);
procedure R_DrawSkyColumnHi(const parms: Pcolumnparams_t);

// Draw with color translation tables,
//  for player sprite rendering,
//  Green/Red/Blue/Indigo shirts.
procedure R_DrawTranslatedColumn(const parms: Pcolumnparams_t);
procedure R_DrawTranslatedColumnHi(const parms: Pcolumnparams_t);

var
  dc_llindex: integer;
  rcolumn: columnparams_t;
  lowrescolumndraw: boolean = false;

implementation

uses
  doomdef,
  m_rnd,
  r_data,
  r_draw,
  r_hires,
  r_sky,
  v_video;

//
// A column is a vertical slice/span from a wall texture that,
//  given the DOOM style restrictions on the view orientation,
//  will always have constant z depth.
// Thus a special case loop for very fast rendering can
//  be used. It has also been used with Wolfenstein 3D.
//
procedure R_DrawColumnMedium(const parms: Pcolumnparams_t);
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
  b: byte;
begin
  count := parms.dc_yh - parms.dc_yl;

  // Zero length, column does not exceed a pixel.
  if count < 0 then
    exit;

  // Framebuffer destination address.
  // Use ylookup LUT to avoid multiply with ScreenWidth.
  // Use columnofs LUT for subwindows?
  dest := @((ylookup[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  // Determine scaling,
  //  which is the only mapping to be done.
  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  // Inner loop that does the actual texture mapping,
  //  e.g. a DDA-lile scaling.
  // This is as fast as it gets.

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
    // Re-map color indices from wall texture column
    //  using a lighting/special effects LUT.
      b := parms.dc_colormap[dc_source8[(LongWord(frac) shr FRACBITS) and 127]];
      dest^ := b;
      inc(dest, SCREENWIDTH);
      dest^ := b;
      inc(dest, SCREENWIDTH);
      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  while frac <= fracstop do
  begin
  // Re-map color indices from wall texture column
  //  using a lighting/special effects LUT.
    dest^ := parms.dc_colormap[dc_source8[(LongWord(frac) shr FRACBITS) and 127]];

    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnHi(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  and_mask: integer;
  dc_source32: PLongWordArray;
  l: LongWord;
begin 
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;

  if parms.dc_texturefactorbits > 0 then
  begin
    fracstep := fracstep * (1 shl parms.dc_texturefactorbits);
    frac := frac * (1 shl parms.dc_texturefactorbits);
    and_mask := 128 * (1 shl parms.dc_texturefactorbits) - 1;
  end
  else
    and_mask := 127;
  fracstop := frac + count * fracstep;
  dc_source32 := parms.dc_source;

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
      l := R_ColorLightEx(dc_source32[(LongWord(frac) shr FRACBITS) and and_mask], parms.dc_lightlevel);
      destl^ := l;
      inc(destl, SCREENWIDTH);
      destl^ := l;
      inc(destl, SCREENWIDTH);
      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  while frac <= fracstop do
  begin
    destl^ := R_ColorLightEx(dc_source32[(LongWord(frac) shr FRACBITS) and and_mask], parms.dc_lightlevel);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawMaskedColumnNormal(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
  l: LongWord;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
      l := R_ColorLightEx(curpal[dc_source8[(LongWord(frac) shr FRACBITS) and 127]], parms.dc_lightlevel);
      destl^ := l;
      inc(destl, SCREENWIDTH);
      destl^ := l;
      inc(destl, SCREENWIDTH);
      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  while frac <= fracstop do
  begin
    destl^ := R_ColorLightEx(curpal[dc_source8[(LongWord(frac) shr FRACBITS) and 127]], parms.dc_lightlevel);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawMaskedColumnHi32(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  and_mask: integer;
  c, l: LongWord;
  dc_source32: PLongWordArray;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;

  if parms.dc_texturefactorbits > 0 then
  begin
    fracstep := fracstep * (1 shl parms.dc_texturefactorbits);
    frac := frac * (1 shl parms.dc_texturefactorbits);
    and_mask := 128 * (1 shl parms.dc_texturefactorbits) - 1;
  end
  else
    and_mask := 127;

  fracstop := frac + count * fracstep;
  dc_source32 := parms.dc_source;

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
      c := dc_source32[(LongWord(frac) shr FRACBITS) and and_mask];
      if c <> 0 then
      begin
        l := R_ColorLightEx(c, parms.dc_lightlevel);
        destl^ := l;
        inc(destl, SCREENWIDTH);
        destl^ := l;
        inc(destl, SCREENWIDTH);
      end
      else
        inc(destl, 2 * SCREENWIDTH);
      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  while frac <= fracstop do
  begin
    c := dc_source32[(LongWord(frac) shr FRACBITS) and and_mask];
    if c <> 0 then
      destl^ := R_ColorLightEx(c, parms.dc_lightlevel);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAlphaMedium(const parms: Pcolumnparams_t);
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  dest := @((ylookup[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  while frac <= fracstop do
  begin
    dest^ := parms.curtrans8table[(dest^ shl 8) + parms.dc_colormap[dc_source8[(LongWord(frac) shr FRACBITS) and 127]]];
    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAlphaHi(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + fracstep * count;
  dc_source8 := parms.dc_source;

  while frac <= fracstop do
  begin
    destl^ := R_ColorAverage(destl^, parms.dc_colormap32[dc_source8[(LongWord(frac) shr FRACBITS) and 127]], parms.dc_alpha);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAverageMedium(const parms: Pcolumnparams_t);
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  dest := @((ylookup[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  while frac <= fracstop do
  begin
    dest^ := averagetrans8table[(dest^ shl 8) + parms.dc_colormap[dc_source8[(LongWord(frac) shr FRACBITS) and 127]]];
    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAverageHi(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  while frac <= fracstop do
  begin
    destl^ := R_ColorMidAverage(destl^, parms.dc_colormap32[dc_source8[(LongWord(frac) shr FRACBITS) and 127]]);
    inc(destl, SCREENWIDTH);
    frac := frac + fracstep;
  end;
end;

//
// Spectre/Invisibility.
//
const
  FUZZTABLE = 50;
  FUZZOFF = 1;


  fuzzoffset: array[0..FUZZTABLE - 1] of integer = (
    FUZZOFF,-FUZZOFF, FUZZOFF,-FUZZOFF, FUZZOFF, FUZZOFF,-FUZZOFF,
    FUZZOFF, FUZZOFF,-FUZZOFF, FUZZOFF, FUZZOFF, FUZZOFF,-FUZZOFF,
    FUZZOFF, FUZZOFF, FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,
    FUZZOFF,-FUZZOFF,-FUZZOFF, FUZZOFF, FUZZOFF, FUZZOFF, FUZZOFF,-FUZZOFF,
    FUZZOFF,-FUZZOFF, FUZZOFF, FUZZOFF,-FUZZOFF,-FUZZOFF, FUZZOFF,
    FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF,-FUZZOFF, FUZZOFF, FUZZOFF,
    FUZZOFF, FUZZOFF,-FUZZOFF, FUZZOFF, FUZZOFF,-FUZZOFF, FUZZOFF
  );

var
  sfuzzoffset: array[0..FUZZTABLE - 1] of integer;

procedure R_InitFuzzTable;
var
  i: integer;
begin
  for i := 0 to FUZZTABLE - 1 do
    sfuzzoffset[i] := fuzzoffset[i] * SCREENWIDTH;
end;

//
// Framebuffer postprocessing.
// Creates a fuzzy image by copying pixels
//  from adjacent ones to left and right.
// Used with an all black colormap, this
//  could create the SHADOW effect,
//  i.e. spectres and invisible players.
//
procedure R_DrawFuzzColumn(const parms: Pcolumnparams_t);
var
  count: integer;
  i: integer;
  dest: PByteArray;
  fuzzpos: integer;
begin
  // Adjust borders. Low...
  if parms.dc_yl = 0 then
    parms.dc_yl := 1;

  // .. and high.
  if parms.dc_yh = viewheight - 1 then
    parms.dc_yh := viewheight - 2;

  count := parms.dc_yh - parms.dc_yl;

  // Zero length.
  if count < 0 then
    exit;

  fuzzpos := I_Random;
  fuzzpos := fuzzpos mod FUZZTABLE;

  // Does not work with blocky mode.
  dest := @((ylookup[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  // Looks like an attempt at dithering,
  //  using the colormap #6 (of 0-31, a bit
  //  brighter than average).
  for i := 0 to count do
  begin
    // Lookup framebuffer, and retrieve
    //  a pixel that is either one column
    //  left or right of the current one.
    // Add index from colormap to index.
    dest[0] := colormaps[6 * 256 + dest[sfuzzoffset[fuzzpos]]];
    dest := @dest[SCREENWIDTH];
    // Clamp table lookup index.
    inc(fuzzpos);
    if fuzzpos = FUZZTABLE then
      fuzzpos := 0;
  end;
end;

procedure R_DrawFuzzColumn32(const parms: Pcolumnparams_t);
var
  count: integer;
  i: integer;
  destl: PLongWordArray;
  fuzzpos: integer;
begin
  if parms.dc_yl = 0 then
    parms.dc_yl := 1;

  if parms.dc_yh = viewheight - 1 then
    parms.dc_yh := viewheight - 2;

  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  fuzzpos := I_Random;
  fuzzpos := fuzzpos mod FUZZTABLE;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  for i := 0 to count do
  begin
    destl[0] := R_ColorLight(destl[sfuzzoffset[fuzzpos]], $C000);
    destl := @destl[SCREENWIDTH];
    inc(fuzzpos);
    if fuzzpos = FUZZTABLE then
      fuzzpos := 0;
  end;
end;

procedure R_DrawFuzzColumnHi(const parms: Pcolumnparams_t);
var
  count: integer;
  i: integer;
  destl: PLongWord;
begin
  count := parms.dc_yh - parms.dc_yl;

  // Zero length.
  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  for i := 0 to count do
  begin
    destl^ := R_FuzzLight(destl^);
    inc(destl, SCREENWIDTH);
  end;
end;

//
// Sky Column
//
procedure R_DrawSkyColumn(const parms: Pcolumnparams_t);
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  spot: integer;
  dc_source8: PByteArray;
  b: byte;
  strn: Pskytransarray_t;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  dest := @((ylookup[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;
  strn := @skytranstable[0];

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
      // Invert Sky Texture if below horizont level
      spot := LongWord(frac) shr (FRACBITS - 1);
      if spot > 255 then
        spot := 255 - (spot and 255);

      b := dc_source8[strn[spot]];
      dest^ := b;
      inc(dest, SCREENWIDTH);
      dest^ := b;
      inc(dest, SCREENWIDTH);
      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  while frac <= fracstop do
  begin
    // Invert Sky Texture if below horizont level
    spot := LongWord(frac) shr (FRACBITS - 1);
    if spot > 255 then
      spot := 255 - (spot and 255);

    dest^ := dc_source8[strn[spot]];

    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawSkyColumnHi(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  factor: integer;
  spot: integer;
  and_mask: integer;
  dc_source32: PLongWordArray;
  l: LongWord;
  strn: Pskytransarray_t;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;

  factor := 1 shl parms.dc_texturefactorbits;
  fracstep := fracstep * factor;
  frac := frac * factor;
  fracstop := frac + count * fracstep;
  and_mask := 256 * factor - 1;

  dc_source32 := parms.dc_source;
  strn := @skytranstable[parms.dc_texturefactorbits];

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac <= fracstop do
    begin
      // Invert Sky Texture if below horizont level
      spot := LongWord(frac) shr (FRACBITS - 1);
      if spot > and_mask then
        spot := and_mask - (spot and and_mask);
      l := dc_source32[strn[spot]];
      destl^ := l;
      inc(destl, SCREENWIDTH);
      destl^ := l;
      inc(destl, SCREENWIDTH);
      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  while frac <= fracstop do
  begin
    // Invert Sky Texture if below horizont level
    spot := LongWord(frac) shr (FRACBITS - 1);
    if spot > and_mask then
      spot := and_mask - (spot and and_mask);
    destl^ := dc_source32[strn[spot]];
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

//
// R_DrawTranslatedColumn
// Used to draw player sprites
//  with the green colorramp mapped to others.
// Could be used with different translation
//  tables, e.g. the lighter colored version
//  of the BaronOfHell, the HellKnight, uses
//  identical sprites, kinda brightened up.
//

procedure R_DrawTranslatedColumn(const parms: Pcolumnparams_t);
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
  b: byte;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  // FIXME. As above.
  dest := @((ylookup[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  // Looks familiar.
  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
      // Translation tables are used
      //  to map certain colorramps to other ones,
      //  used with PLAY sprites.
      // Thus the "green" ramp of the player 0 sprite
      //  is mapped to gray, red, black/indigo.
      b := parms.dc_colormap[dc_translation[dc_source8[LongWord(frac) shr FRACBITS]]];
      dest^ := b;
      inc(dest, SCREENWIDTH);
      dest^ := b;
      inc(dest, SCREENWIDTH);

      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  // Here we do an additional index re-mapping.
  while frac <= fracstop do
  begin
    // Translation tables are used
    //  to map certain colorramps to other ones,
    //  used with PLAY sprites.
    // Thus the "green" ramp of the player 0 sprite
    //  is mapped to gray, red, black/indigo.
    dest^ := parms.dc_colormap[dc_translation[dc_source8[LongWord(frac) shr FRACBITS]]];
    inc(dest, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

procedure R_DrawTranslatedColumnHi(const parms: Pcolumnparams_t);
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fracstop: fixed_t;
  dc_source8: PByteArray;
  l: LongWord;
begin
  count := parms.dc_yh - parms.dc_yl;

  if count < 0 then
    exit;

  // FIXME. As above.
  destl := @((ylookup32[parms.dc_yl]^)[columnofs[parms.dc_x]]);

  // Looks familiar.
  fracstep := parms.dc_iscale;
  frac := parms.dc_texturemid + (parms.dc_yl - centery) * fracstep;
  fracstop := frac + count * fracstep;
  dc_source8 := parms.dc_source;

  if lowrescolumndraw and (count > 0) then
  begin
    frac := frac + fracstep div 2;
    fracstep := fracstep * 2;
    while frac < fracstop do
    begin
      // Translation tables are used
      //  to map certain colorramps to other ones,
      //  used with PLAY sprites.
      // Thus the "green" ramp of the player 0 sprite
      //  is mapped to gray, red, black/indigo.
      l := parms.dc_colormap32[dc_translation[dc_source8[LongWord(frac) shr FRACBITS]]];
      destl^ := l;
      inc(destl, SCREENWIDTH);
      destl^ := l;
      inc(destl, SCREENWIDTH);

      inc(frac, fracstep);
    end;
    fracstep := fracstep div 2;
    frac := frac - fracstep div 2;
  end;

  // Here we do an additional index re-mapping.
  while frac <= fracstop do
  begin
    // Translation tables are used
    //  to map certain colorramps to other ones,
    //  used with PLAY sprites.
    // Thus the "green" ramp of the player 0 sprite
    //  is mapped to gray, red, black/indigo.
    destl^ := parms.dc_colormap32[dc_translation[dc_source8[LongWord(frac) shr FRACBITS]]];
    inc(destl, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

end.

