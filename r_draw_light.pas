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

// Draw column to the lightmap
procedure R_DrawColumnLightmap(const parms: Plightparams_t);

var
  lcolumn: lightparams_t;

procedure R_InitLightmap;

procedure R_ShutDownLightmap;

procedure R_StartLightmap;

procedure R_StopLightmap;

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
  r_depthbuffer,
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
  LM_STOREBITS = 6;
  LM_RESTOREBITS = FRACBITS - LM_STOREBITS;

var
  LM_ACCURACY: integer = 5;
  LM_MOD: integer = 2;

var
  lightmapbuffer: Plightmapbuffer_t;
  ylookuplm: array[0..MAXHEIGHT] of Plightmapbuffer_t;
  LMWIDTH, LMHEIGHT: integer;
  lightmapactive: boolean = false;
  lm_spartspan: integer = MAXWIDTH + 1;
  lm_stopspan: integer = -1;

function LM_Screen2LMx(const screenx: integer): integer; inline;
begin
  result := (screenx + LM_MOD) div LM_ACCURACY;
  if result < 0 then
    result := 0
  else if result >= LMWIDTH then
    result := LMWIDTH - 1;
end;

function LM_Screen2LMy(const screeny: integer): integer; inline;
begin
  result := (screeny + LM_MOD) div LM_ACCURACY;
  if result < 0 then
    result := 0
  else if result >= LMHEIGHT then
    result := LMHEIGHT - 1;
end;

function R_LightmapBufferAt(const x, y: integer): Plightmapitem_t; inline;
begin
  result := Plightmapitem_t(@((ylookuplm[LM_Screen2LMy(y)]^)[columnofs[LM_Screen2LMx(x)]]));
end;

procedure R_DrawColumnLightmap(const parms: Plightparams_t);
var
  count, y: integer;
  frac: fixed_t;
  fracstep: fixed_t;
  db: Pdepthbufferitem_t;
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
  renderskip: boolean;
begin
  if parms.dl_x mod LM_ACCURACY <> LM_MOD then
    Exit;

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
  renderskip := false;

  if parms.dl_yl < lm_spartspan then
    lm_spartspan := parms.dl_yl;
  if parms.dl_yh > lm_stopspan then
    lm_stopspan := parms.dl_yh;

  for y := parms.dl_yl to parms.dl_yh do
  begin
    dls := parms.dl_source32[(LongWord(frac) shr FRACBITS) and 127];
    if dls <> 0 then
    begin
      db := R_DepthBufferAt(parms.dl_x, y);
      if (seg <> db.seg) or (rendertype <> db.rendertype) then
      begin
        seg := db.seg;
        rendertype := db.rendertype;
        if rendertype = RIT_SPRITE then
          renderskip := true // we do not cast lights to sprites (why ?)
        else if seg <> nil then
        begin
          if rendertype = RIT_MASKEDWALL then
            renderskip := R_PointOnSegSide(parms.lightsourcex, parms.lightsourcey, seg) <> R_PointOnSegSide(viewx, viewy, seg)
          else
            renderskip := R_PointOnSegSide(parms.lightsourcex, parms.lightsourcey, seg);
        end
        else
          renderskip := false; // we always draw light on spans, wrong! ?
      end;
      if not renderskip then
      begin
        depth := db.depth;
        factor := 0;
        if (depth >= dbmin) and (depth <= dbmax) then
        begin
          dfactor := depth - scale;
          if dfactor < 0 then
            dfactor := FRACUNIT - FixedDiv(-dfactor, dbdmin)
          else
            dfactor := FRACUNIT - FixedDiv(dfactor, dbdmax);
          if dfactor > 0 then
          begin
            factor := FixedMul(dls, dfactor) shr LM_STOREBITS;
            li := R_LightmapBufferAt(parms.dl_x, y);
            li.r := li.r + parms.r * factor;
            li.g := li.g + parms.g * factor;
            li.b := li.b + parms.b * factor;
            inc(li.numitems);
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

  LMWIDTH := SCREENWIDTH div LM_ACCURACY;
  LMHEIGHT := SCREENHEIGHT div LM_ACCURACY;
  lightmapbuffer := mallocz((LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
  lightmapactive := false;
end;

procedure R_ShutDownLightmap;
begin
  memfree(lightmapbuffer, (LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
end;

const
  LM_INTENSITYPRECALCSIZE = FRACUNIT div MAXLMCOLORSENSITIVITY;

var
  lmintensitytable: array[0..LM_INTENSITYPRECALCSIZE - 1] of byte;

procedure R_ComputeLightmapIntensityTable;
var
  i: integer;
  x: LongWord;
begin
  for i := 0 to LM_INTENSITYPRECALCSIZE - 1 do
  begin
    x := (i * lightmapcolorintensity) div 256;
    if x < 255 then
      lmintensitytable[i] := x
    else
      lmintensitytable[i] := 255;
  end;
end;

var
  llastviewwindowy: integer = -1;
  llastviewheight: integer = -1;
  llastaccuracymode: integer = -1;
  llastcolorintensity: integer = -1;

  // Called in each render tic before we start lightmap
procedure R_StartLightMap;
var
  i: integer;
begin
  if lightmapactive then
    exit;

  R_CheckLightmapParams;

  if llastcolorintensity <> lightmapcolorintensity then
  begin
    llastcolorintensity := lightmapcolorintensity;
    R_ComputeLightmapIntensityTable;
  end;

  lm_spartspan := MAXWIDTH + 1;
  lm_stopspan := -1;
  if (llastviewwindowy <> viewwindowy) or (llastviewheight <> viewheight) or (llastaccuracymode <> lightmapaccuracymode) then
  begin
    if llastaccuracymode <> lightmapaccuracymode then
    begin
      lightmapaccuracymode := lightmapaccuracymode mod NUMLIGHTMAPACCURACYMODES;
      llastaccuracymode := lightmapaccuracymode;
      case lightmapaccuracymode of
        0: LM_ACCURACY := 5;
        1: LM_ACCURACY := 3;
        2: LM_ACCURACY := 1;
      else LM_ACCURACY := 1;
      end;
      LM_MOD := LM_ACCURACY div 2;
    end;
    memfree(lightmapbuffer, (LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
    LMWIDTH := viewwidth div LM_ACCURACY;
    LMHEIGHT := viewheight div LM_ACCURACY;
    lightmapbuffer := mallocz((LMWIDTH + 1) * (LMHEIGHT + 1) * SizeOf(lightmapitem_t));
    llastviewwindowy := viewwindowy;
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

// Flash lightmap span to screen - 8 bit
procedure R_FlashSpanLightmap8(const pls_y: PInteger);
var
  x, i: integer;
  li: Plightmapitem_t;
  r, g, b: LongWord;
  dest: PByte;
  color8: word;
begin
  dest := @((ylookup[pls_y^]^)[columnofs[0]]);
  li := R_LightmapBufferAt(0, pls_y^);
  for x := 0 to LMWIDTH - 1 do
  begin
    if li.numitems > 0 then
    begin
      r := (li.r div LM_ACCURACY) shr LM_RESTOREBITS;
      if r < LM_INTENSITYPRECALCSIZE then r := lmintensitytable[r] else r := 255;
      g := (li.g div LM_ACCURACY) shr LM_RESTOREBITS;
      if g < LM_INTENSITYPRECALCSIZE then g := lmintensitytable[g] else g := 255;
      b := (li.b div LM_ACCURACY) shr LM_RESTOREBITS;
      if b < LM_INTENSITYPRECALCSIZE then b := lmintensitytable[b] else b := 255;
      color8 := R_FastApproxColorIndex(r, g, b);
      for i := 0 to LM_ACCURACY - 1 do
      begin
        dest^ := coloraddtrans8table[dest^ * 256 + color8];
        inc(dest);
      end;
    end
    else
      inc(dest, LM_ACCURACY);
    inc(li);
  end;
end;

// Flash lightmap span to screen - 32 bit
procedure R_FlashSpanLightmap32(const pls_y: PInteger);
var
  x, i: integer;
  li: Plightmapitem_t;
  r, g, b: LongWord;
  destl: PLongWord;
begin
  destl := @((ylookup32[pls_y^]^)[columnofs[0]]);
  li := R_LightmapBufferAt(0, pls_y^);
  for x := 0 to LMWIDTH - 1 do
  begin
    if li.numitems > 0 then
    begin
      r := (li.r div LM_ACCURACY) shr LM_RESTOREBITS;
      if r < LM_INTENSITYPRECALCSIZE then r := lmintensitytable[r] else r := 255;
      g := (li.g div LM_ACCURACY) shr LM_RESTOREBITS;
      if g < LM_INTENSITYPRECALCSIZE then g := lmintensitytable[g] else g := 255;
      b := (li.b div LM_ACCURACY) shr LM_RESTOREBITS;
      if b < LM_INTENSITYPRECALCSIZE then b := lmintensitytable[b] else b := 255;
      for i := 0 to LM_ACCURACY - 1 do
      begin
        destl^ := R_ColorLightAdd(destl^, r, g, b);
        inc(destl);
      end;
    end
    else
      inc(destl, LM_ACCURACY);
    inc(li);
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

