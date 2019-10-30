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

unit r_plane;

interface

uses
  m_fixed,
  doomdef, 
  r_data, 
  r_defs;

procedure R_InitPlanes;
procedure R_ClearPlanes;

procedure R_MapPlane(const y: integer; const x1, x2: integer);

procedure R_MakeSpans(x: integer; t1: integer; b1: integer; t2: integer; b2: integer);

procedure R_DrawPlanes;

function R_FindPlane(height: fixed_t; picnum: integer; lightlevel: integer): Pvisplane_t;

function R_CheckPlane(pl: Pvisplane_t; start: integer; stop: integer): Pvisplane_t;

var
//
// Clip values are the solid pixel bounding the range.
//  floorclip starts out SCREENHEIGHT
//  ceilingclip starts out -1
//
  floorclip: packed array[0..MAXWIDTH - 1] of smallint;
  ceilingclip: packed array[0..MAXWIDTH - 1] of smallint;

var
  floorplane: Pvisplane_t;
  ceilingplane: Pvisplane_t;

//
// opening
//

// ?
const
  MAXOPENINGS = MAXWIDTH * MAXHEIGHT;

var
  openings: packed array[0..MAXOPENINGS - 1] of smallint; 
  lastopening: integer;

  yslope: array[0..MAXHEIGHT - 1] of fixed_t;
  distscale: array[0..MAXWIDTH - 1] of fixed_t;

implementation

uses
  d_fpc,
  doomstat,
  tables,
  i_system,
  r_sky,
  r_draw,
  r_main,
  r_things,
  r_hires,
  r_draw_span,
  r_draw_column,
  z_memory,
  w_wad;

// Here comes the obnoxious "visplane".
const
// JVAL - Note about visplanes:
//   Top and Bottom arrays (of visplane_t struct) are now
//   allocated dynamically (using zone memory)
//   Use -zone cmdline param to specify more zone memory allocation
//   if out of memory.
//   See also R_NewVisPlane()
// Now maximum visplanes are 16K (originally 128)
  MAXVISPLANES = 16384;

var
  visplanes: array[0..MAXVISPLANES - 1] of visplane_t;
  lastvisplane: integer;

//
// spanstart holds the start of a plane span
// initialized to 0 at start
//
  spanstart: array[0..MAXHEIGHT - 1] of integer;

//
// texture mapping
//
  planezlight: PBytePArray;
  planeheight: fixed_t;

  cachedheight: array[0..MAXHEIGHT - 1] of fixed_t;
  cacheddistance: array[0..MAXHEIGHT -1] of fixed_t;
  cachedxstep: array[0..MAXHEIGHT - 1] of fixed_t;
  cachedystep: array[0..MAXHEIGHT - 1] of fixed_t;


//
// R_InitPlanes
// Only at game startup.
//
procedure R_InitPlanes;
begin
  // Doh!
end;

//
// R_MapPlane
//
// Uses global vars:
//  planeheight
//  ds_source
//  viewx
//  viewy
//
// BASIC PRIMITIVE
//
procedure R_MapPlane(const y: integer; const x1, x2: integer);
var
  distance: fixed_t;
  index: LongWord;
  ncolornum: integer;
  slope: double;
begin
  if x2 - x1 < 0 then
    exit;

  if y >= viewheight then
    exit;

  if planeheight <> cachedheight[y] then
  begin
    cachedheight[y] := planeheight;
    cacheddistance[y] := FixedMul(planeheight, yslope[y]);
    distance := cacheddistance[y];
    slope := (planeheight / FRACUNIT / abs(centery - y)) * relativeaspect;
    ds_xstep := round(dviewsin * slope);
    ds_ystep := round(dviewcos * slope);
    cachedxstep[y] := ds_xstep;
    cachedystep[y] := ds_ystep;
  end
  else
  begin
    distance := cacheddistance[y];
    ds_xstep := cachedxstep[y];
    ds_ystep := cachedystep[y];
  end;

  ds_xfrac :=  viewx + FixedMul(viewcos, distance) + (x1 - centerx) * ds_xstep;
  ds_yfrac := -viewy - FixedMul(viewsin, distance) + (x1 - centerx) * ds_ystep;

  if fixedcolormap <> nil then
  begin
    ds_colormap := fixedcolormap;
    if videomode = vm32bit then
    begin
      ds_colormap32 := R_GetColormap32(ds_colormap);
      if fixedcolormapnum = INVERSECOLORMAP then
        ds_lightlevel := -1  // Negative value -> Use colormaps
      else
        ds_lightlevel := R_GetColormapLightLevel(ds_colormap);
    end;
  end
  else
  begin
    index := _SHR(distance, LIGHTZSHIFT);

    if index >= MAXLIGHTZ then
      index := MAXLIGHTZ - 1;

    ds_colormap := planezlight[index];
    if videomode = vm32bit then
    begin
      ds_colormap32 := R_GetColormap32(ds_colormap);
      if not forcecolormaps then
      begin
         ncolornum := _SHR(distance, HLL_ZDISTANCESHIFT);
         if ncolornum >= HLL_MAXLIGHTZ then
          ncolornum := HLL_MAXLIGHTZ - 1;
        ds_lightlevel := zlightlevels[ds_llzindex, ncolornum];
      end
      else
      begin
        ds_lightlevel := R_GetColormapLightLevel(ds_colormap);
      end;
    end;
  end;

  ds_y := y;
  ds_x1 := x1;
  ds_x2 := x2;

  // high or low detail
  spanfunc;
end;

//
// R_ClearPlanes
// At begining of frame.
//
procedure R_ClearPlanes;
var
  i: integer;
  angle: angle_t;
begin
  // opening / clipping determination
  for i := 0 to viewwidth - 1 do
  begin
    floorclip[i] := viewheight;
    ceilingclip[i] := -1;
  end;

  lastvisplane := 0;
  lastopening := 0;

  // texture calculation
  ZeroMemory(@cachedheight, SizeOf(cachedheight));

  // left to right mapping
  angle := _SHRW(viewangle - ANG90, ANGLETOFINESHIFT);
end;

//
// R_NewVisPlane
//
// JVAL
//   Create a new visplane
//   Uses zone memory to allocate top and bottom arrays
//
procedure R_NewVisPlane;
begin
  if lastvisplane > maxvisplane then
  begin
    visplanes[lastvisplane].top := Pvisindex_tArray(
      Z_Malloc((SCREENWIDTH + 2) * SizeOf(visindex_t), PU_LEVEL, nil));
    visplanes[lastvisplane].bottom := Pvisindex_tArray(
      Z_Malloc((SCREENWIDTH + 2) * SizeOf(visindex_t), PU_LEVEL, nil));
    maxvisplane := lastvisplane;
  end;

  inc(lastvisplane);
end;

//
// R_FindPlane
//
function R_FindPlane(height: fixed_t; picnum: integer; lightlevel: integer): Pvisplane_t;
var
  check: integer;
begin
  if picnum = skyflatnum then
  begin
    height := 0; // all skys map together
    lightlevel := 0;
  end;

  check := 0;
  result := @visplanes[0];
  while check < lastvisplane do
  begin
    if (height = result.height) and
       (picnum = result.picnum) and
       (lightlevel = result.lightlevel) then
      break;
    inc(check);
    inc(result);
  end;

  if check < lastvisplane then
  begin
    exit;
  end;

  if lastvisplane = MAXVISPLANES then
    I_Error('R_FindPlane(): no more visplanes');

  R_NewVisPlane;

  result.height := height;
  result.picnum := picnum;
  result.lightlevel := lightlevel;
  result.minx := viewwidth;
  result.maxx := -1;

  memset(@result.top[-1], iVISEND, (2 + SCREENWIDTH) * SizeOf(visindex_t));
end;

//
// R_CheckPlane
//
function R_CheckPlane(pl: Pvisplane_t; start: integer; stop: integer): Pvisplane_t;
var
  intrl: integer;
  intrh: integer;
  unionl: integer;
  unionh: integer;
  x: integer;
  pll: Pvisplane_t;
begin
  if start < pl.minx then
  begin
    intrl := pl.minx;
    unionl := start;
  end
  else
  begin
    unionl := pl.minx;
    intrl := start;
  end;

  if stop > pl.maxx then
  begin
    intrh := pl.maxx;
    unionh := stop;
  end
  else
  begin
    unionh := pl.maxx;
    intrh := stop;
  end;

  x := intrl;
  while x <= intrh do
  begin
    if pl.top[x] <> VISEND then
      break
    else
      inc(x);
  end;

  if x > intrh then
  begin
    pl.minx := unionl;
    pl.maxx := unionh;

    // use the same one
    result := pl;
    exit;
  end;

  // make a new visplane

  if lastvisplane = MAXVISPLANES then
    I_Error('R_CheckPlane(): no more visplanes');

  pll := @visplanes[lastvisplane];
  pll.height := pl.height;
  pll.picnum := pl.picnum;
  pll.lightlevel := pl.lightlevel;

  pl := pll;

  R_NewVisPlane;

  pl.minx := start;
  pl.maxx := stop;
  result := pl;

  memset(@result.top[-1], iVISEND, (2 + SCREENWIDTH) * SizeOf(visindex_t));
end;

//
// R_MakeSpans
//
procedure R_MakeSpans(x: integer; t1: integer; b1: integer; t2: integer; b2: integer);
var
  x1: integer;
begin
  x1 := x - 1;
  if t1 < 0 then
    t1 := 0;
  while (t1 < t2) and (t1 <= b1) do
  begin
  // JVAL 9/7/05
    if t1 < viewwidth then
      R_MapPlane(t1, spanstart[t1], x);
    inc(t1);
  end;
  while (b1 > b2) and (b1 >= t1) do
  begin
  // JVAL 9/7/05
    if (b1 >= 0) and (b1 < viewwidth) then
      R_MapPlane(b1, spanstart[b1], x1);
    dec(b1);
  end;

  while (t2 < t1) and (t2 <= b2) do
  begin
  // JVAL 9/7/05
    if t2 < viewwidth then
      spanstart[t2] := x;
    inc(t2);
  end;
  while (b2 > b1) and (b2 >= t2) do
  begin
  // JVAL 9/7/05
    if (b2 >= 0) and (b2 < viewwidth) then
      spanstart[b2] := x;
    dec(b2);
  end;
end;

//
// R_DrawPlanes
// At the end of each frame.
//
procedure R_DrawPlanes;
var
  pl: Pvisplane_t;
  i: integer;
  light: integer;
  x: integer;
  stop: integer;
  angle: integer;
begin
  for i := 0 to lastvisplane - 1 do
  begin
    pl := @visplanes[i];
    if pl.minx > pl.maxx then
      continue;

    // sky flat
    if pl.picnum = skyflatnum then
    begin
      if zaxisshift and (viewangleoffset = 0) then
        dc_iscale := FRACUNIT * 93 div viewheight // JVAL adjust z axis shift also
      else
        dc_iscale := FRACUNIT * 200 div viewheight;

      dc_texturemid := skytexturemid;
      for x := pl.minx to pl.maxx do
      begin
        dc_yl := pl.top[x];
        dc_yh := pl.bottom[x];

        if dc_yl < dc_yh then
        begin
          angle := (viewangle + xtoviewangle[x]) div ANGLETOSKYUNIT;
          dc_texturemod := 0;
          dc_mod := 0;
          dc_x := x;
          R_GetDCs(skytexture, angle);
        // Sky is allways drawn full bright,
        //  i.e. colormaps[0] is used.
        //  Because of this hack, sky is not affected
        //  by INVUL inverse mapping.
        // JVAL
        //  call skycolfunc(), not colfunc(), does not use colormaps!
          skycolfunc;
        end;
      end;
      continue;
    end;

    // regular flat
    R_GetDSs(pl.picnum);

    planeheight := abs(pl.height - viewz);
    light := _SHR(pl.lightlevel, LIGHTSEGSHIFT) + extralight;

    if light >= LIGHTLEVELS then
      light := LIGHTLEVELS - 1;

    if light < 0 then
      light := 0;

    planezlight := @zlight[light];
    ds_llzindex := light;

    pl.top[pl.maxx + 1] := VISEND;
    pl.top[pl.minx - 1] := VISEND;

    stop := pl.maxx + 1;

    for x := pl.minx to stop do
    begin
      R_MakeSpans(x, pl.top[x - 1], pl.bottom[x - 1], pl.top[x], pl.bottom[x]);
    end;

    if ds_source <> nil then
      Z_ChangeTag(ds_source, PU_CACHE);
  end;
end;

end.

