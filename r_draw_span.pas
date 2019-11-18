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

unit r_draw_span;

interface

uses
  d_fpc,
  m_fixed;

type
  dsscale_t = (ds64x64, ds128x128, ds256x256, ds512x512, NUMDSSCALES);

type
  dsscaleinfo_t = record
    frac: integer;
    yshift: integer;
    yand: integer;
    dand: integer;
  end;
  Pdsscaleinfo_t = ^dsscaleinfo_t;

const
  DSSCALEINFO: array[ds64x64..ds512x512] of dsscaleinfo_t = (
    (frac: 1; yshift: 10; yand:   4032; dand:  63;),
    (frac: 2; yshift:  9; yand:  16256; dand: 127;),
    (frac: 4; yshift:  8; yand:  65280; dand: 255;),
    (frac: 8; yshift:  7; yand: 261632; dand: 511;)
  );

const
  dsscalesize: array[0..Ord(NUMDSSCALES) - 1] of integer = (
     64 *  64,
    128 * 128,
    256 * 256,
    512 * 512
  );


type
  spanparams_t = record
    ds_source: pointer; // start of a 64*64 tile image
    ds_y: integer;
    ds_x1: integer;
    ds_x2: integer;
    ds_colormap: PByteArray;
    ds_xfrac: fixed_t;
    ds_yfrac: fixed_t;
    ds_xstep: fixed_t;
    ds_ystep: fixed_t;
    ds_scale: dsscale_t;
    ds_lightlevel: fixed_t;
    ds_planeheight: fixed_t;
  end;
  Pspanparams_t = ^spanparams_t;

// Span blitting for rows, floor/ceiling.
// No Sepctre effect needed.
procedure R_DrawSpanMedium(const parms: Pspanparams_t);

procedure R_DrawSpanNormal(const parms: Pspanparams_t);

var
  ds_llzindex: fixed_t; // Lightlevel index for z axis
  rspan: spanparams_t;
  lowresspandraw: boolean = false;

implementation

uses
  r_draw,
  r_hires;

//
// R_DrawSpan
// With DOOM style restrictions on view orientation,
//  the floors and ceilings consist of horizontal slices
//  or spans with constant z depth.
// However, rotation around the world z axis is possible,
//  thus this mapping, while simpler and faster than
//  perspective correct texture mapping, has to traverse
//  the texture at an angle in all but a few cases.
// In consequence, flats are not stored by column (like walls),
//  and the inner loop has to step in texture space u and v.
//

//
// Draws the actual span (Medium resolution).
//
procedure R_DrawSpanMedium(const parms: Pspanparams_t);
var
  xfrac: fixed_t;
  yfrac: fixed_t;
  xstep: fixed_t;
  ystep: fixed_t;
  dest: PByte;
  count: integer;
  psi: Pdsscaleinfo_t;
  ds_source8: PByteArray;
  b: byte;
begin
  // We do not check for zero spans here?
  count := parms.ds_x2 - parms.ds_x1;

  dest := @((ylookup[parms.ds_y]^)[columnofs[parms.ds_x1]]);

  psi := @DSSCALEINFO[parms.ds_scale];
  xfrac := parms.ds_xfrac * psi.frac;
  yfrac := parms.ds_yfrac * psi.frac;
  xstep := parms.ds_xstep * psi.frac;
  ystep := parms.ds_ystep * psi.frac;
  ds_source8 := parms.ds_source;

  if lowresspandraw and (count > 1) then
  begin
    xfrac := xfrac + xstep div 2;
    yfrac := yfrac + ystep div 2;
    xstep := xstep * 2;
    ystep := ystep * 2;
    while count > 0 do
    begin
      b := parms.ds_colormap[ds_source8[_SHR(yfrac, psi.yshift) and psi.yand + _SHR(xfrac, FRACBITS) and psi.dand]];
      dest^ := b;
      inc(dest);
      dest^ := b;
      inc(dest);

      // Next step in u,v.
      xfrac := xfrac + xstep;
      yfrac := yfrac + ystep;
      dec(count, 2);
    end;
    xstep := xstep div 2;
    ystep := ystep div 2;
    xfrac := xfrac - xstep div 2;
    yfrac := yfrac - ystep div 2;
  end;

  while count >= 0 do
  begin
    dest^ := parms.ds_colormap[ds_source8[_SHR(yfrac, psi.yshift) and psi.yand + _SHR(xfrac, FRACBITS) and psi.dand]];
    inc(dest);

    // Next step in u,v.
    xfrac := xfrac + xstep;
    yfrac := yfrac + ystep;
    dec(count);
  end;
end;

//
// Draws the actual span (Normal resolution).
//
procedure R_DrawSpanNormal(const parms: Pspanparams_t);
var
  xfrac: fixed_t;
  yfrac: fixed_t;
  xstep: fixed_t;
  ystep: fixed_t;
  destl: PLongWord;
  count: integer;
  psi: Pdsscaleinfo_t;
  ds_source32: PLongWordArray;
  l: LongWord;
begin
  // We do not check for zero spans here?
  count := parms.ds_x2 - parms.ds_x1;

  destl := @((ylookup32[parms.ds_y]^)[columnofs[parms.ds_x1]]);
  psi := @DSSCALEINFO[parms.ds_scale];
  xfrac := parms.ds_xfrac * psi.frac;
  yfrac := parms.ds_yfrac * psi.frac;
  xstep := parms.ds_xstep * psi.frac;
  ystep := parms.ds_ystep * psi.frac;
  ds_source32 := parms.ds_source;

  if lowresspandraw and (count > 1) then
  begin
    xfrac := xfrac + xstep div 2;
    yfrac := yfrac + ystep div 2;
    xstep := xstep * 2;
    ystep := ystep * 2;
    while count > 0 do
    begin
      l := R_ColorLightEx(ds_source32[_SHR(yfrac, psi.yshift) and psi.yand + _SHR(xfrac, FRACBITS) and psi.dand], parms.ds_lightlevel);
      destl^ := l;
      inc(destl);
      destl^ := l;
      inc(destl);

      // Next step in u,v.
      xfrac := xfrac + xstep;
      yfrac := yfrac + ystep;
      dec(count, 2);
    end;
    xstep := xstep div 2;
    ystep := ystep div 2;
    xfrac := xfrac - xstep div 2;
    yfrac := yfrac - ystep div 2;
  end;

  while count >= 0 do
  begin
    destl^ := R_ColorLightEx(ds_source32[_SHR(yfrac, psi.yshift) and psi.yand + _SHR(xfrac, FRACBITS) and psi.dand], parms.ds_lightlevel);
    inc(destl);

    // Next step in u,v.
    xfrac := xfrac + xstep;
    yfrac := yfrac + ystep;
    dec(count);
  end;
end;

end.

