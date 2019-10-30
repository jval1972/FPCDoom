//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2018 by Jim Valavanis
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
  r_main;

// Column drawers
procedure R_DrawColumnMedium;
procedure R_DrawColumnHi;

// Masked column drawing functions
procedure R_DrawMaskedColumnNormal;
procedure R_DrawMaskedColumnHi32;

// Alpha column drawers (transparency effects)
procedure R_DrawColumnAlphaMedium;
procedure R_DrawColumnAlphaHi;

// Average column drawers (transparency effects)
procedure R_DrawColumnAverageMedium;
procedure R_DrawColumnAverageHi;

// The Spectre/Invisibility effect.
procedure R_InitFuzzTable;
procedure R_DrawFuzzColumn;
procedure R_DrawFuzzColumn32;
procedure R_DrawFuzzColumnHi;

// Sky column drawing functions
// Sky column drawers
procedure R_DrawSkyColumn;
procedure R_DrawSkyColumnHi;

// Light column drawing functions (32 bit only)
procedure R_DrawWhiteLightColumnHi;
procedure R_DrawRedLightColumnHi;
procedure R_DrawGreenLightColumnHi;
procedure R_DrawBlueLightColumnHi;
procedure R_DrawYellowLightColumnHi;

// Draw with color translation tables,
//  for player sprite rendering,
//  Green/Red/Blue/Indigo shirts.
procedure R_DrawTranslatedColumn;
procedure R_DrawTranslatedColumnHi;

var
//
// R_DrawColumn
// Source is the top of the column to scale.
//
  dc_colormap: PByteArray;
  dc_colormap32: PLongWordArray;
  dc_lightlevel: fixed_t;
  dc_llindex: integer;

  dc_iscale: fixed_t;
  dc_texturemid: fixed_t;
  dc_x: integer;
  dc_yl: integer;
  dc_yh: integer;
  dc_mod: integer; // JVAL for hi resolution
  dc_texturemod: integer; // JVAL for external textures
  dc_texturefactorbits: integer; // JVAL for hi resolution
  dc_palcolor: LongWord;
  dc_alpha: fixed_t;

const
  MAXTEXTUREFACTORBITS = 3; // JVAL: Allow hi resolution textures x 8 

var
// first pixel in a column (possibly virtual)
  dc_source: PByteArray;
  dc_source32: PLongWordArray;

implementation

uses
  doomdef,
  r_data,
  r_draw,
  r_trans8,
  r_hires,
  v_video;

//
// A column is a vertical slice/span from a wall texture that,
//  given the DOOM style restrictions on the view orientation,
//  will always have constant z depth.
// Thus a special case loop for very fast rendering can
//  be used. It has also been used with Wolfenstein 3D.
//
procedure R_DrawColumnMedium;
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
begin
  count := dc_yh - dc_yl;

  // Zero length, column does not exceed a pixel.
  if count < 0 then
    exit;

  // Framebuffer destination address.
  // Use ylookup LUT to avoid multiply with ScreenWidth.
  // Use columnofs LUT for subwindows?
  dest := @((ylookup[dc_yl]^)[columnofs[dc_x]]);

  // Determine scaling,
  //  which is the only mapping to be done.
  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  // Inner loop that does the actual texture mapping,
  //  e.g. a DDA-lile scaling.
  // This is as fast as it gets.
  while frac <= fraclimit do
  begin
  // Re-map color indices from wall texture column
  //  using a lighting/special effects LUT.
    dest^ := dc_colormap[dc_source[(LongWord(frac) shr FRACBITS) and 127]];

    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  and_mask: integer;
begin 
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;

  if dc_texturefactorbits > 0 then
  begin
    fracstep := fracstep * (1 shl dc_texturefactorbits);
    frac := frac * (1 shl dc_texturefactorbits);
    and_mask := 128 * (1 shl dc_texturefactorbits) - 1;
  end
  else
    and_mask := 127;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    destl^ := R_ColorLightEx(dc_source32[(LongWord(frac) shr FRACBITS) and and_mask], dc_lightlevel);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawMaskedColumnNormal;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    destl^ := R_ColorLightEx(curpal[dc_source[(LongWord(frac) shr FRACBITS) and 127]], dc_lightlevel);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawMaskedColumnHi32;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  and_mask: integer;
  c: LongWord;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;

  if dc_texturefactorbits > 0 then
  begin
    fracstep := fracstep * (1 shl dc_texturefactorbits);
    frac := frac * (1 shl dc_texturefactorbits);
    and_mask := 128 * (1 shl dc_texturefactorbits) - 1;
  end
  else
    and_mask := 127;

  fraclimit := frac + count * fracstep;
  while frac <= fraclimit do
  begin
    c := dc_source32[(LongWord(frac) shr FRACBITS) and and_mask];
    if c <> 0 then
      destl^ := R_ColorLightEx(c, dc_lightlevel);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAlphaMedium;
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  dest := @((ylookup[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    dest^ := curtrans8table[(dest^ shl 8) + dc_colormap[dc_source[(LongWord(frac) shr FRACBITS) and 127]]];
    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAlphaHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + fracstep * count;

  while frac < fraclimit do
  begin
    destl^ := R_ColorAverage(destl^, dc_colormap32[dc_source[(LongWord(frac) shr FRACBITS) and 127]], dc_alpha);
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAverageMedium;
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  dest := @((ylookup[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    dest^ := averagetrans8table[(dest^ shl 8) + dc_colormap[dc_source[(LongWord(frac) shr FRACBITS) and 127]]];
    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawColumnAverageHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    destl^ := R_ColorMidAverage(destl^, dc_colormap32[dc_source[(LongWord(frac) shr FRACBITS) and 127]]);
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

var
  fuzzpos: integer = 0;

//
// Framebuffer postprocessing.
// Creates a fuzzy image by copying pixels
//  from adjacent ones to left and right.
// Used with an all black colormap, this
//  could create the SHADOW effect,
//  i.e. spectres and invisible players.
//
procedure R_DrawFuzzColumn;
var
  count: integer;
  i: integer;
  dest: PByteArray;
begin
  // Adjust borders. Low...
  if dc_yl = 0 then
    dc_yl := 1;

  // .. and high.
  if dc_yh = viewheight - 1 then
    dc_yh := viewheight - 2;

  count := dc_yh - dc_yl;

  // Zero length.
  if count < 0 then
    exit;

  // Does not work with blocky mode.
  dest := @((ylookup[dc_yl]^)[columnofs[dc_x]]);

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

procedure R_DrawFuzzColumn32;
var
  count: integer;
  i: integer;
  destl: PLongWordArray;
begin
  if dc_yl = 0 then
    dc_yl := 1;

  if dc_yh = viewheight - 1 then
    dc_yh := viewheight - 2;

  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  for i := 0 to count do
  begin
    destl[0] := R_ColorLight(destl[sfuzzoffset[fuzzpos]], $C000);
    destl := @destl[SCREENWIDTH];
    inc(fuzzpos);
    if fuzzpos = FUZZTABLE then
      fuzzpos := 0;
  end;
end;

procedure R_DrawFuzzColumnHi;
var
  count: integer;
  i: integer;
  destl: PLongWord;
begin
  // Adjust borders. Low...
  if dc_yl = 0 then
    dc_yl := 1;

  // .. and high.
  if dc_yh = viewheight - 1 then
    dc_yh := viewheight - 2;

  count := dc_yh - dc_yl;

  // Zero length.
  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  for i := 0 to count do
  begin
    destl^ := R_FuzzLight(destl^);
    inc(destl, SCREENWIDTH);
  end;
end;

procedure R_InitFuzzTable;
var
  i: integer;
begin
  for i := 0 to FUZZTABLE - 1 do
    sfuzzoffset[i] := fuzzoffset[i] * SCREENWIDTH;
end;

//
// Sky Column
//
procedure R_DrawSkyColumn;
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  dest := @((ylookup[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    // Invert Sky Texture if below horizont level
    spot := LongWord(frac) shr FRACBITS;
    if spot > 127 then
      spot := 127 - (spot and 127);

    dest^ := dc_source[spot];

    inc(dest, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawSkyColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;
  and_mask: integer;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;

  fracstep := fracstep * (1 shl dc_texturefactorbits);
  frac := frac * (1 shl dc_texturefactorbits);
  fraclimit := frac + count * fracstep;
  and_mask := 128 * (1 shl dc_texturefactorbits) - 1;

  while frac <= fraclimit do
  begin
    // Invert Sky Texture if below horizont level
    spot := LongWord(frac) shr FRACBITS;
    if spot > and_mask then
      spot := and_mask - (spot and and_mask);
    destl^ := dc_source32[spot];
    inc(destl, SCREENWIDTH);
    inc(frac, fracstep);
  end;
end;

procedure R_DrawWhiteLightColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;

  c: LongWord;
  lfactor: fixed_t;
  r1, g1, b1: byte;
  r, g, b: LongWord;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    spot := (LongWord(frac) shr FRACBITS) and 255;
    lfactor := dc_source32[spot];
    c := destl^;
    r1 := c;
    g1 := c shr 8;
    b1 := c shr 16;
    r := (r1 * lfactor) shr FRACBITS;
    if r > 255 then
      r := 255;
    g := (g1 * lfactor) shr FRACBITS;
    if g > 255 then
      g := 255;
    b := (b1 * lfactor) shr FRACBITS;
    if b > 255 then
      b := 255;
    destl^ := r + g shl 8 + b shl 16;
    inc(destl, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

procedure R_DrawRedLightColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;

  c: LongWord;
  lfactor: fixed_t;
  r1, g1, b1: byte;
  r, g, b: LongWord;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    spot := (LongWord(frac) shr FRACBITS) and 255;
    lfactor := dc_source32[spot];
    c := destl^;
    r1 := c;
    g1 := c shr 8;
    b1 := c shr 16;
    r := r1;
    g := g1;
    b := (b1 * lfactor) shr FRACBITS;
    if b > 255 then
      b := 255;
    destl^ := r + g shl 8 + b shl 16;
    inc(destl, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

procedure R_DrawGreenLightColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;

  c: LongWord;
  lfactor: fixed_t;
  r1, g1, b1: byte;
  r, g, b: LongWord;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    spot := (LongWord(frac) shr FRACBITS) and 255;
    lfactor := dc_source32[spot];
    c := destl^;
    r1 := c;
    g1 := c shr 8;
    b1 := c shr 16;
    r := r1;
    g := (g1 * lfactor) shr FRACBITS;
    if g > 255 then
      g := 255;
    b := b1;
    destl^ := r + g shl 8 + b shl 16;
    inc(destl, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

procedure R_DrawBlueLightColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;

  c: LongWord;
  lfactor: fixed_t;
  r1, g1, b1: byte;
  r, g, b: LongWord;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    spot := (LongWord(frac) shr FRACBITS) and 255;
    lfactor := dc_source32[spot];
    c := destl^;
    r1 := c;
    g1 := c shr 8;
    b1 := c shr 16;
    r := (r1 * lfactor) shr FRACBITS;
    if r > 255 then
      r := 255;
    g := g1;
    b := b1;
    destl^ := r + g shl 8 + b shl 16;
    inc(destl, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

procedure R_DrawYellowLightColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  fraclimit: fixed_t;
  spot: integer;

  c: LongWord;
  lfactor: fixed_t;
  r1, g1, b1: byte;
  r, g, b: LongWord;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;
  fraclimit := frac + count * fracstep;

  while frac <= fraclimit do
  begin
    spot := (LongWord(frac) shr FRACBITS) and 255;
    lfactor := dc_source32[spot];
    c := destl^;
    r1 := c;
    g1 := c shr 8;
    b1 := c shr 16;
    r := r1;
    g := (g1 * lfactor) shr FRACBITS;
    if g > 255 then
      g := 255;
    b := (b1 * lfactor) shr FRACBITS;
    if b > 255 then
      b := 255;
    destl^ := r + g shl 8 + b shl 16;
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

procedure R_DrawTranslatedColumn;
var
  count: integer;
  dest: PByte;
  frac: fixed_t;
  fracstep: fixed_t;
  i: integer;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  // FIXME. As above.
  dest := @((ylookup[dc_yl]^)[columnofs[dc_x]]);

  // Looks familiar.
  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;

  // Here we do an additional index re-mapping.
  for i := 0 to count do
  begin
    // Translation tables are used
    //  to map certain colorramps to other ones,
    //  used with PLAY sprites.
    // Thus the "green" ramp of the player 0 sprite
    //  is mapped to gray, red, black/indigo.
    dest^ := dc_colormap[dc_translation[dc_source[LongWord(frac) shr FRACBITS]]];
    inc(dest, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;

procedure R_DrawTranslatedColumnHi;
var
  count: integer;
  destl: PLongWord;
  frac: fixed_t;
  fracstep: fixed_t;
  i: integer;
begin
  count := dc_yh - dc_yl;

  if count < 0 then
    exit;

  // FIXME. As above.
  destl := @((ylookupl[dc_yl]^)[columnofs[dc_x]]);

  // Looks familiar.
  fracstep := dc_iscale;
  frac := dc_texturemid + (dc_yl - centery) * fracstep;

  // Here we do an additional index re-mapping.
  for i := 0 to count do
  begin
    // Translation tables are used
    //  to map certain colorramps to other ones,
    //  used with PLAY sprites.
    // Thus the "green" ramp of the player 0 sprite
    //  is mapped to gray, red, black/indigo.
    destl^ := dc_colormap32[dc_translation[dc_source[LongWord(frac) shr FRACBITS]]];
    inc(destl, SCREENWIDTH);

    inc(frac, fracstep);
  end;
end;


end.

