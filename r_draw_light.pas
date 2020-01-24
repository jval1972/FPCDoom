//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2020 by Jim Valavanis
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

unit r_draw_light;


interface

uses
  d_fpc,
  m_fixed;

type
  lightparams_t = record
    lightsourcex: fixed_t;
    lightsourcey: fixed_t;
    r, g, b: byte;
    dl_iscale: fixed_t;
    dl_scale: fixed_t;
    dl_texturemid: fixed_t;
    dl_x: integer;
    dl_yl: integer;
    dl_yh: integer;
    db_min: LongWord;
    db_max: LongWord;
    db_dmin: LongWord;
    db_dmax: LongWord;
    dl_fracstep: fixed_t;
    dl_source32: PLongWordArray;
  end;
  Plightparams_t = ^lightparams_t;

function R_ValidLightColumn(const x: integer): boolean;

// Draw column to the lightmap
procedure R_DrawColumnLightmap(const parms: Plightparams_t);

var
  lcolumn: lightparams_t;

procedure R_InitLightmap;

procedure R_ShutDownLightmap;

procedure R_StartLightmap;

procedure R_StopLightmap;

procedure R_CalcLightmap;

// Flash one lightmap span (8 bit)
procedure R_FlashSpanLightmap8(const pls_y: PInteger);

// Flash one lightmap span (32 bit)
procedure R_FlashSpanLightmap32(const pls_y: PInteger);

// Flash the entire lightmap
procedure R_FlashLightmap;

implementation

uses
  doomdef,
  p_setup,
  r_defs,
  r_draw,
  r_zbuffer,
  r_lightmap,
  r_main,
  r_trans8,
  r_hires,
  r_render;

type
  lightmapitem_t = record
    r, b, g: LongWord;
    numitems: integer;
  end;
  Plightmapitem_t = ^lightmapitem_t;

  lightmapbuffer_t = array[0..MAXWIDTH * MAXHEIGHT] of lightmapitem_t;
  Plightmapbuffer_t = ^lightmapbuffer_t;

const
  LM_STORESHIFT = 5;
  LM_RESTORESHIFT = FRACBITS - LM_STORESHIFT;

var
  LM_YACCURACY: integer = 5;
  LM_YMOD: integer = 2;

var
  lightmapbuffer: Plightmapbuffer_t;
  ylookuplm: array[0..MAXHEIGHT] of Plightmapbuffer_t;
  xcolumnsteplm: array[0..MAXWIDTH] of integer;
  LMWIDTH, LMHEIGHT: integer;
  lightmapactive: boolean = false;
  lm_spartspan: integer = MAXWIDTH + 1;
  lm_stopspan: integer = -1;

function LM_Screen2LMx(const screenx: integer): integer; inline;
begin
  result := screenx;
  if result < 0 then
    result := 0
  else if result >= LMWIDTH then
    result := LMWIDTH - 1;
end;

function LM_Screen2LMy(const screeny: integer): integer; inline;
begin
  result := (screeny + LM_YMOD) div LM_YACCURACY;
  if result < 0 then
    result := 0
  else if result >= LMHEIGHT then
    result := LMHEIGHT - 1;
end;

function R_LightmapBufferAt(const x, y: integer): Plightmapitem_t; inline;
begin
  result := Plightmapitem_t(@((ylookuplm[LM_Screen2LMy(y)]^)[columnofs[LM_Screen2LMx(x)]]));
end;

function R_ValidLightColumn(const x: integer): boolean;
begin
  result := xcolumnsteplm[x] > 0;
end;

procedure R_DrawColumnLightmap(const parms: Plightparams_t);
var
  count, x, y: integer;
  frac: fixed_t;
  fracstep: fixed_t;
  db: Pzbufferitem_t;
  depth: LongWord;
  dbmin, dbmax: LongWord;
  dbdmin, dbdmax: LongWord;
  factor: fixed_t;
  dfactor: fixed_t;
  scale: fixed_t;
  li: Plightmapitem_t;
  dls: fixed_t;
  seg: Pseg_t;
  rendertype: LongWord;
  skip: boolean;
  sameseg: boolean;
begin
  x := parms.dl_x;
  if xcolumnsteplm[x] <= 0 then
    exit;

  count := parms.dl_yh - parms.dl_yl;

  if count < 0 then
    exit;

  frac := parms.dl_texturemid + (parms.dl_yl - centery) * parms.dl_iscale;
  fracstep := parms.dl_fracstep;

  dbmin := parms.db_min;
  dbmax := parms.db_max;
  dbdmin := parms.db_dmin;
  dbdmax := parms.db_dmax;
  scale := parms.dl_scale;
  seg := nil;
  rendertype := 0;
  dfactor := 0;
  skip := false;
  sameseg := false;

  if parms.dl_yl < lm_spartspan then
    lm_spartspan := parms.dl_yl;
  if parms.dl_yh > lm_stopspan then
    lm_stopspan := parms.dl_yh;

  for y := parms.dl_yl to parms.dl_yh do
  begin
    if y mod LM_YACCURACY = LM_YMOD then
    begin
      dls := parms.dl_source32[(LongWord(frac) shr FRACBITS) and 127];
      if dls <> 0 then
      begin
        db := R_ZBufferAt(x, y);
        if ((seg <> db.seg) or (rendertype <> db.rendertype)) and (db.depth >= dbmin) and (db.depth <= dbmax) then
        begin
          sameseg := (seg = db.seg) and (seg <> nil);
          seg := db.seg;
          rendertype := db.rendertype;
          if rendertype = RIT_SPRITE then
            skip := true // we do not cast lights to sprites (why ?)
          else if seg <> nil then
          begin
            if rendertype = RIT_MASKEDWALL then
              skip := R_PointOnSegSide(parms.lightsourcex, parms.lightsourcey, seg) <> R_PointOnSegSide(viewx, viewy, seg)
            else
              skip := R_PointOnSegSide(parms.lightsourcex, parms.lightsourcey, seg);
          end
          else
            skip := false; // we always draw light on spans, wrong! - eg Light source below floor should not cast light
        end;
        if not skip then
        begin
          depth := db.depth;
          if (depth >= dbmin) and (depth <= dbmax) then
          begin
            if not sameseg then
            begin
              dfactor := depth - scale;
              if dfactor < 0 then
                dfactor := FRACUNIT - FixedDiv(-dfactor, dbdmin)
              else
                dfactor := FRACUNIT - FixedDiv(dfactor, dbdmax);
            end;
            if dfactor > 0 then
            begin
              if dfactor > FRACUNIT then
                dfactor := FRACUNIT;
              li := R_LightmapBufferAt(parms.dl_x, y);
              factor := FixedMul(dls, dfactor);
              li.r := li.r + (parms.r * factor) shr LM_STORESHIFT;
              li.g := li.g + (parms.g * factor) shr LM_STORESHIFT;
              li.b := li.b + (parms.b * factor) shr LM_STORESHIFT;
              inc(li.numitems);
            end;
          end;
        end;
      end;
    end;
    inc(frac, fracstep);
  end;
end;

procedure R_CheckLightmapParams;
begin
  if (lightmapaccuracymode < 0) or (lightmapaccuracymode >= NUMLIGHTMAPACCURACYMODES) then
    lightmapaccuracymode := 0;
  if (lightmapcolorintensity < MINLMCOLORSENSITIVITY) or (lightmapcolorintensity > MAXLMCOLORSENSITIVITY) then
    lightmapcolorintensity := DEFLMCOLORSENSITIVITY;
  if (lightwidthfactor < MINLIGHTWIDTHFACTOR) or (lightwidthfactor > MAXLIGHTWIDTHFACTOR) then
    lightwidthfactor := DEFLIGHTWIDTHFACTOR;
end;

procedure R_InitLightmap;
begin
  R_CheckLightmapParams;

  LMWIDTH := SCREENWIDTH;
  LMHEIGHT := SCREENHEIGHT div LM_YACCURACY;
  lightmapbuffer := mallocz((LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
  lightmapactive := false;
end;

procedure R_ShutDownLightmap;
begin
  memfree(lightmapbuffer, (LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
end;

var
  llastviewwidth: integer = -1;
  llastviewheight: integer = -1;
  llastaccuracymode: integer = -1;

  // Called in each render tic before we start lightmap
procedure R_StartLightMap;
var
  i: integer;
begin
  if lightmapactive then
    exit;

  R_CheckLightmapParams;

  lm_spartspan := MAXWIDTH + 1;
  lm_stopspan := -1;
  if (llastviewwidth <> viewwidth) or (llastviewheight <> viewheight) or (llastaccuracymode <> lightmapaccuracymode) then
  begin
    if llastaccuracymode <> lightmapaccuracymode then
    begin
      lightmapaccuracymode := lightmapaccuracymode mod NUMLIGHTMAPACCURACYMODES;
      llastaccuracymode := lightmapaccuracymode;
      LM_YACCURACY := R_CalcLigmapYAccuracy;
      LM_YMOD := LM_YACCURACY div 2;
    end;
    memfree(lightmapbuffer, (LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
    LMWIDTH := viewwidth;
    LMHEIGHT := viewheight div LM_YACCURACY;
    lightmapbuffer := mallocz((LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
    llastviewwidth := viewwidth;
    llastviewheight := viewheight;
    for i := 0 to LMHEIGHT do
      ylookuplm[i] := Plightmapbuffer_t(@lightmapbuffer[i * LMWIDTH]);
  end;
  lightmapactive := true;
end;

procedure R_StopLightmap;
begin
  lightmapactive := false;
  ZeroMemory(lightmapbuffer, (LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
end;

//
// R_CalcLightmap
//
// JVAL:
//   Calculate the ranges in x/width space of lightmap accuracy
//   depending on zbuffer content (R_ZGetCriticalX) and quality step
//
procedure R_CalcLightmap;
var
  x: integer;
  x1: integer;
  xstep: integer;
begin
  for x := 0 to LMWIDTH - LM_YACCURACY - 1 do
  begin
    if R_ZGetCriticalX(x) then
      xcolumnsteplm[x] := 1
    else
      xcolumnsteplm[x] := 0;
  end;

  for x := LMWIDTH - LM_YACCURACY to LMWIDTH do
    xcolumnsteplm[x] := 1;

  for x := 1 to LMWIDTH - LM_YACCURACY - 1 do
  begin
    if xcolumnsteplm[x] = 0 then
    begin
      xstep := 1;
      for x1 := x + 1 to x + LM_YACCURACY - 1 do
      begin
        if xcolumnsteplm[x1] = 0 then
        begin
          xcolumnsteplm[x1] := -1;
          inc(xstep);
        end
        else
          break;
      end;
      if xcolumnsteplm[x - 1] = 1 then
      begin
        xcolumnsteplm[x - 1] := xcolumnsteplm[x - 1] + xstep;
        xcolumnsteplm[x] := -1;
      end
      else
        xcolumnsteplm[x] := xstep;
    end;
  end;
end;

// Flash lightmap span to screen - 8 bit
procedure R_FlashSpanLightmap8(const pls_y: PInteger);
var
  x, i: integer;
  li: Plightmapitem_t;
  r, g, b: LongWord;
  dest: PByte;
  color8: word;
  nsteps: integer;
begin
  dest := @((ylookup8[pls_y^]^)[columnofs[0]]);
  li := R_LightmapBufferAt(0, pls_y^);

  x := 0;
  while x < LMWIDTH do
  begin
    nsteps := xcolumnsteplm[x];
    if (nsteps > 0) and (li.numitems > 0) then
    begin
      r := ((li.r shr LM_RESTORESHIFT) * lightmapcolorintensity) div 256;
      if r > 255 then r := 255;
      g := ((li.g shr LM_RESTORESHIFT) * lightmapcolorintensity) div 256;
      if g > 255 then g := 255;
      b := ((li.b shr LM_RESTORESHIFT) * lightmapcolorintensity) div 256;
      if b > 255 then b := 255;
      color8 := R_FastApproxColorIndex(r, g, b);
      for i := 0 to nsteps - 1 do
      begin
        dest^ := coloraddtrans8table[dest^ * 256 + color8];
        inc(dest);
      end;
    end
    else
      inc(dest, nsteps);

    if nsteps > 0 then
    begin
      inc(x, nsteps);
      inc(li, nsteps);
    end
    else
    begin
      inc(x);
      inc(li);
    end;
  end;
end;

// Flash lightmap span to screen - 32 bit
procedure R_FlashSpanLightmap32(const pls_y: PInteger);
var
  x, i: integer;
  li: Plightmapitem_t;
  r, g, b: LongWord;
  destl: PLongWord;
  nsteps: integer;
begin
  destl := @((ylookup32[pls_y^]^)[columnofs[0]]);
  li := R_LightmapBufferAt(0, pls_y^);

  x := 0;
  while x < LMWIDTH do
  begin
    nsteps := xcolumnsteplm[x];
    if (nsteps > 0) and (li.numitems > 0) then
    begin
      r := ((li.r shr LM_RESTORESHIFT) * lightmapcolorintensity) div 256;
      if r > 255 then r := 255;
      g := ((li.g shr LM_RESTORESHIFT) * lightmapcolorintensity) div 256;
      if g > 255 then g := 255;
      b := ((li.b shr LM_RESTORESHIFT) * lightmapcolorintensity) div 256;
      if b > 255 then b := 255;
      for i := 0 to nsteps - 1 do
      begin
        destl^ := R_ColorLightAdd(destl^, r, g, b);
        inc(destl);
      end;
    end
    else
      inc(destl, nsteps);

    if nsteps > 0 then
    begin
      inc(x, nsteps);
      inc(li, nsteps);
    end
    else
    begin
      inc(x);
      inc(li);
    end;
  end;
end;

procedure R_FlashLightmap;
var
  h: integer;
begin
  if lm_spartspan < 0 then
    lm_spartspan := 0
  else if lm_spartspan >= viewheight then
    lm_spartspan := viewheight - 1;

  if lm_stopspan < 0 then
    lm_stopspan := 0
  else if lm_stopspan >= viewheight then
    lm_stopspan := viewheight - 1;

  for h := lm_spartspan to lm_stopspan do
    R_AddRenderTask(lightmapflashfunc, RF_LIGHTMAP, @h);
end;

end.

