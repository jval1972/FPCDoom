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

unit r_segs;

interface

uses
  d_fpc,
  m_fixed,
  tables,
  r_defs;

procedure R_RenderMaskedSegRange(const ds: Pdrawseg_t; const x1, x2: integer);

procedure R_StoreWallRange(const start: integer; const stop: integer);

var
// angle to line origin
  rw_angle1: angle_t;
  
  rw_normalangle: angle_t;

//
// Regular world public
//
  rw_distance: fixed_t;

  walllights: PBytePArray;

procedure R_CalcSeg(const seg: Pseg_t);

implementation

uses
  doomtype, 
  doomdef,
  doomdata,
  r_main,
  r_data, 
  r_bsp,
  r_render,
  r_sky, 
  r_things, 
  r_draw,
  r_plane,
  r_hires,
  r_draw_column,
  r_lightmap,
  r_mirror,
  z_memory;

procedure R_CalcSeg(const seg: Pseg_t);
var
  dx, dy: double;
  sq: double;
begin
  dx := seg.v2.r_x - seg.v1.r_x;
  dy := seg.v2.r_y - seg.v1.r_y;
  sq := dx * dx + dy * dy;
  if sq = 0.0 then
    seg.inv_length := 10000000000.0
  else
    seg.inv_length := 1 / sqrt(sq);
  seg.r_normalangle := R_PointToAngle(seg.v1.r_x, seg.v1.r_y, seg.v2.r_x, seg.v2.r_y) + ANG90;
end;

function R_CalcSegOffset(const seg: Pseg_t): fixed_t;
var
  dx, dy, dx1, dy1: double;
begin
  dx := seg.v2.r_x - seg.v1.r_x;
  dy := seg.v2.r_y - seg.v1.r_y;
  dx1 := viewx - seg.v1.r_x;
  dy1 := viewy - seg.v1.r_y;
  result := trunc((dx * dx1 + dy * dy1) * seg.inv_length);
  if result < 0 then
    result := -result;
end;

//
// R_DistToSeg by entryway
//
// https://www.doomworld.com/forum/topic/70288-dynamic-wiggletall-sector-fix-for-fixed-point-software-renderer/?do=findComment&comment=1340433
function R_DistToSeg(const seg: Pseg_t): fixed_t;
var
  dx, dy, dx1, dy1: double;
begin
  if seg.v1.r_y = seg.v2.r_y then
  begin
    result := viewy - seg.v1.r_y;
    if result < 0 then
      result := -result;
    exit;
  end;

  if seg.v1.r_x = seg.v2.r_x then
  begin
    result := viewx - seg.v1.r_x;
    if result < 0 then
      result := -result;
    exit;
  end;

  dx := seg.v2.r_x - seg.v1.r_x;
  dy := seg.v2.r_y - seg.v1.r_y;
  dx1 := viewx - seg.v1.r_x;
  dy1 := viewy - seg.v1.r_y;
  result := trunc((dy * dx1 - dx * dy1) * seg.inv_length);
  if result < 0 then
    result := -result;
end;

var
  maskedtexturecol: PSmallIntArray; // JVAL : declared in r_defs

// True if any of the segs textures might be visible.
  segtextured: boolean;

// False if the back side is the same plane.
  markfloor: boolean;
  markceiling: boolean;

  maskedtexture: boolean;
  toptexture: integer;
  bottomtexture: integer;
  midtexture: integer;

//
// regular wall
//
  rw_x: integer;
  rw_stopx: integer;
  rw_centerangle: angle_t;
  rw_offset: fixed_t;
  rw_scale: fixed_t;
  rw_scalestep: fixed_t;
  rw_midtexturemid: fixed_t;
  rw_toptexturemid: fixed_t;
  rw_bottomtexturemid: fixed_t;

  worldtop: integer;
  worldbottom: integer;
  worldhigh: integer;
  worldlow: integer;

var
  rw_scale_dbl: double;
  rw_scalestep_dbl: double;

  worldhigh_dbl: double;
  worldlow_dbl: double;

  pixhigh_dbl: double;
  pixlow_dbl: double;
  pixhighstep_dbl: double;
  pixlowstep_dbl: double;

  topfrac_dbl: double;
  topstep_dbl: double;

  bottomfrac_dbl: double;
  bottomstep_dbl: double;

// OPTIMIZE: closed two sided lines as single sided

//
// R_RenderMaskedSegRange
//
procedure R_RenderMaskedSegRange(const ds: Pdrawseg_t; const x1, x2: integer);
var
  index: integer;
  col: Pcolumn_t;
  lightnum: integer;
  texnum: integer;
  i: integer;
  use32: boolean;
  mc2height: integer;
  texturecolumn: integer;
begin
  // Calculate light table.
  // Use different light tables
  //   for horizontal / vertical / diagonal. Diagonal?
  // OPTIMIZE: get rid of LIGHTSEGSHIFT globally
  curline := ds.curline;
  frontsector := curline.frontsector;
  backsector := curline.backsector;
  texnum := texturetranslation[curline.sidedef.midtexture];

  rcolumn.seg := curline; // we do not need it
  rcolumn.rendertype := RIT_MASKEDWALL;
  R_GetDCs(texnum, 0); // JVAL Also precache external texture if not loaded
  use32 := (videomode = vm32bit) and (PCAST(textures[texnum].texture32) > $1);
  if use32 then
  begin
    mc2height := textures[texnum].height;
    colfunc := maskedcolfunc2;
  end
  else
  begin
    mc2height := 0;
    colfunc := maskedcolfunc;
  end;

  lightnum := _SHR(frontsector.lightlevel, LIGHTSEGSHIFT) + extralight;

  if curline.v1.r_y = curline.v2.r_y then
    dec(lightnum)
  else if curline.v1.r_x = curline.v2.r_x then
    inc(lightnum);

  if lightnum < 0 then
    lightnum := 0
  else if lightnum >= LIGHTLEVELS then
    lightnum := LIGHTLEVELS - 1;

  walllights := @scalelight[lightnum];

  dc_llindex := lightnum;

  maskedtexturecol := ds.maskedtexturecol;

  rw_scalestep := ds.scalestep;
  spryscale := ds.scale1 + (x1 - ds.x1) * rw_scalestep;
  mfloorclip := ds.sprbottomclip;
  mceilingclip := ds.sprtopclip;

  // find positioning
  if curline.linedef.flags and ML_DONTPEGBOTTOM <> 0 then
  begin
    if frontsector.floorheight > backsector.floorheight then
      rcolumn.dc_texturemid := frontsector.floorheight
    else
      rcolumn.dc_texturemid := backsector.floorheight;
    rcolumn.dc_texturemid := rcolumn.dc_texturemid + textureheight[texnum] - viewz;
  end
  else
  begin
    if frontsector.ceilingheight < backsector.ceilingheight then
      rcolumn.dc_texturemid := frontsector.ceilingheight
    else
      rcolumn.dc_texturemid := backsector.ceilingheight;
    rcolumn.dc_texturemid := rcolumn.dc_texturemid - viewz;
  end;
  rcolumn.dc_texturemid := rcolumn.dc_texturemid + curline.sidedef.rowoffset;

  if fixedcolormap <> nil then
    rcolumn.dc_colormap := fixedcolormap;

  if videomode = vm32bit then
  begin
    rcolumn.dc_colormap32 := R_GetColormap32(rcolumn.dc_colormap);
    if fixedcolormapnum = INVERSECOLORMAP then
      rcolumn.dc_lightlevel := -1
    else
      rcolumn.dc_lightlevel := R_GetColormapLightLevel(rcolumn.dc_colormap);
  end;

  // draw the columns
  for i := x1 to x2 do
  begin
    rcolumn.dc_x := i;
    // calculate lighting
    if maskedtexturecol[rcolumn.dc_x] <> MAXSHORT then
    begin
      if fixedcolormap = nil then
      begin
        if not forcecolormaps then
        begin
          index := _SHR(spryscale, HLL_LIGHTSCALESHIFT + 2) * 320 div SCREENWIDTH;
          if index >= HLL_MAXLIGHTSCALE then
            index := HLL_MAXLIGHTSCALE - 1;
          rcolumn.dc_lightlevel := scalelightlevels[dc_llindex, index];
        end;
        index := _SHR(spryscale, LIGHTSCALESHIFT) * 320 div SCREENWIDTH;

        if index >=  MAXLIGHTSCALE then
          index := MAXLIGHTSCALE - 1;

        rcolumn.dc_colormap := walllights[index];
        if videomode = vm32bit then
          rcolumn.dc_colormap32 := R_GetColormap32(rcolumn.dc_colormap);
      end;

      sprtopscreen := centeryfrac - FixedMul(rcolumn.dc_texturemid, spryscale);
      rcolumn.dc_iscale := LongWord($ffffffff) div LongWord(spryscale);

      texturecolumn := maskedtexturecol[rcolumn.dc_x] shr DC_HIRESBITS;

      if use32 then
      begin
        rcolumn.dc_mod := 0;
        rcolumn.dc_texturemod := maskedtexturecol[rcolumn.dc_x] and (DC_HIRESFACTOR - 1);
        R_GetDCs(texnum, texturecolumn);
        R_DrawMaskedColumn32(mc2height, renderflags_masked);
      end
      else
      begin
        // draw the texture
        col := pOp(R_GetColumn(texnum, texturecolumn), -3);
        R_DrawMaskedColumn(col, renderflags_masked);
      end;
      maskedtexturecol[rcolumn.dc_x] := MAXSHORT;
    end;
    spryscale := spryscale + rw_scalestep;
  end;
end;

//
// R_RenderSegLoop
// Draws zero, one, or two textures (and possibly a masked
//  texture) for walls.
// Can draw or mark the starting pixel of floor and ceiling
//  textures.
// CALLED: CORE LOOPING ROUTINE.
//
const
  HEIGHTBITS = 12;
  HEIGHTUNIT = 1 shl HEIGHTBITS;
  WORLDBIT = 16 - HEIGHTBITS;
  WORLDUNIT = 1 shl WORLDBIT;

// Find the column if we are in mirror mode
function R_MirrorTextureColumn(const seg: Pseg_t; const tc: fixed_t): fixed_t;
var
  offs: fixed_t;
  len: integer;
begin
  if mirrormode and MR_ENVIROMENT = 0 then
    result := tc
  else
  begin
    offs := seg.sidedef.textureoffset;
    len := seg.linedef.len;
    result := (len + 2 * offs) div FRACUNIT - tc;
  end;
end;

procedure R_RenderSegLoop;
var
  angle: angle_t;
  index: integer;
  yl: integer;
  yh: integer;
  mid: integer;
  texturecolumn: fixed_t;
  texturecolumnhi: smallint;
  top: integer;
  bottom: integer;
  pceilingclip: PSmallInt;
  pfloorclip: PSmallInt;
  rwx, rwstopx: integer;
begin
  texturecolumn := 0; // shut up compiler warning
  texturecolumnhi := 0;
  rwx := rw_x;
  rwstopx := rw_stopx;
  pceilingclip := @ceilingclip[rwx];
  pfloorclip := @floorclip[rwx];
  rcolumn.seg := curline;
  rcolumn.rendertype := RIT_WALL;
  while rwx < rwstopx do
  begin
    // mark floor / ceiling areas
    yl := Trunc((topfrac_dbl + (HEIGHTUNIT - 1)) / HEIGHTUNIT);

    // no space above wall?
    if yl <= pceilingclip^ then
      yl := pceilingclip^ + 1;

    if markceiling then
    begin
      top := pceilingclip^ + 1;
      bottom := yl - 1;

      if bottom >= pfloorclip^ then
        bottom := pfloorclip^ - 1;

      if top <= bottom then
      begin
        ceilingplane.top[rwx] := top;
        ceilingplane.bottom[rwx] := bottom;
      end;
      // SoM: this should be set here
      pceilingclip^ := bottom;
    end;

    yh := Trunc(bottomfrac_dbl / HEIGHTUNIT);

    if yh >= pfloorclip^ then
      yh := pfloorclip^ - 1;

    if markfloor then
    begin
      top := yh + 1;
      bottom := pfloorclip^ - 1;
      if top <= pceilingclip^ then
        top := pceilingclip^ + 1;
      if top <= bottom then
      begin
        floorplane.top[rwx] := top;
        floorplane.bottom[rwx] := bottom;
      end;
      // SoM: this should be set here to prevent overdraw
      pfloorclip^ := top;
    end;

    // texturecolumn and lighting are independent of wall tiers
    if segtextured then
    begin
      // calculate texture offset
      angle := _SHRW(rw_centerangle + xtoviewangle[rwx], ANGLETOFINESHIFT);
      texturecolumn := rw_offset - FixedMul(finetangent[angle], rw_distance);
      rcolumn.dc_texturemod := 0;
      rcolumn.dc_mod := 0;

      texturecolumnhi := texturecolumn shr (FRACBITS - DC_HIRESBITS);
      texturecolumn := texturecolumn shr FRACBITS;
      // calculate lighting
      index := _SHR(trunc(rw_scale_dbl * 320 / SCREENWIDTH), LIGHTSCALESHIFT);

      if index >=  MAXLIGHTSCALE then
        index := MAXLIGHTSCALE - 1;

      rcolumn.dc_colormap := walllights[index];
      if videomode = vm32bit then
      begin
        rcolumn.dc_colormap32 := R_GetColormap32(rcolumn.dc_colormap);
        if (not forcecolormaps) and (fixedcolormap = nil) then
        begin
          index := trunc(rw_scale_dbl * 320 / (1 shl (HLL_LIGHTSCALESHIFT + 2)) / SCREENWIDTH);
          if index >= HLL_MAXLIGHTSCALE then
            index := HLL_MAXLIGHTSCALE - 1
          else if index < 0 then
            index := 0;
          rcolumn.dc_lightlevel := scalelightlevels[dc_llindex, index];
        end
        else if fixedcolormapnum = INVERSECOLORMAP then
          rcolumn.dc_lightlevel := -1
        else
          rcolumn.dc_lightlevel := R_GetColormapLightLevel(rcolumn.dc_colormap);
      end;

      rcolumn.dc_x := rwx;
      if (rw_scale_dbl < 4) and (rw_scale_dbl > -4) then
      begin
        if rw_scale_dbl > 0 then
          rcolumn.dc_iscale := MAXINT div 2
        else
          rcolumn.dc_iscale := -MAXINT div 2
      end
      else
      begin
        rcolumn.dc_iscale := trunc($100000000 / rw_scale_dbl);
        if rcolumn.dc_iscale > MAXINT div 2 then
          rcolumn.dc_iscale := MAXINT div 2
        else if rcolumn.dc_iscale < -MAXINT div 2 then
          rcolumn.dc_iscale := -MAXINT div 2
      end;
      if (rcolumn.dc_iscale < 4) and (rcolumn.dc_iscale > -4) then
      begin
        if rcolumn.dc_iscale > 0 then
          rcolumn.dc_iscale := 4
        else
          rcolumn.dc_iscale := -4
      end;
    end;

    // draw the wall tiers
    if midtexture <> 0 then
    begin
      // single sided line
      rcolumn.dc_yl := yl;
      rcolumn.dc_yh := yh;
      rcolumn.dc_texturemid := rw_midtexturemid;
      R_GetDCs(midtexture, R_MirrorTextureColumn(curline, texturecolumn));
      R_AddRenderTask(wallcolfunc, renderflags_wall, @rcolumn);
      pceilingclip^ := viewheight;
      pfloorclip^ := -1;
    end
    else
    begin
      // two sided line
      if toptexture <> 0 then
      begin
        // top wall
        mid := Trunc(pixhigh_dbl / HEIGHTUNIT);
        pixhigh_dbl := pixhigh_dbl + pixhighstep_dbl;

        if mid >= pfloorclip^ then
          mid := pfloorclip^ - 1;

        if mid >= yl then
        begin
          rcolumn.dc_yl := yl;
          rcolumn.dc_yh := mid;
          rcolumn.dc_texturemid := rw_toptexturemid;
          R_GetDCs(toptexture, R_MirrorTextureColumn(curline, texturecolumn));
          R_AddRenderTask(wallcolfunc, renderflags_wall, @rcolumn);
          pceilingclip^ := mid;
        end
        else
          pceilingclip^ := yl - 1;
      end
      else
      begin
        // no top wall
        if markceiling then
          pceilingclip^ := yl - 1;
      end;

      if bottomtexture <> 0 then
      begin
        // bottom wall
        mid := Trunc((pixlow_dbl + HEIGHTUNIT - 1) / HEIGHTUNIT);
        pixlow_dbl := pixlow_dbl + pixlowstep_dbl;

        // no space above wall?
        if mid <= pceilingclip^ then
          mid := pceilingclip^ + 1;

        if mid <= yh then
        begin
          rcolumn.dc_yl := mid;
          rcolumn.dc_yh := yh;
          rcolumn.dc_texturemid := rw_bottomtexturemid;
          R_GetDCs(bottomtexture, R_MirrorTextureColumn(curline, texturecolumn));
          R_AddRenderTask(wallcolfunc, renderflags_wall, @rcolumn);
          pfloorclip^ := mid;
        end
        else
          pfloorclip^ := yh + 1;
      end
      else
      begin
        // no bottom wall
        if markfloor then
          pfloorclip^ := yh + 1;
      end;

      if maskedtexture then
      begin
        // save texturecol
        // for backdrawing of masked mid texture
        maskedtexturecol[rwx] := texturecolumnhi;
      end;
    end;

    rw_scale_dbl := rw_scale_dbl + rw_scalestep_dbl;
    topfrac_dbl := topfrac_dbl + topstep_dbl;
    bottomfrac_dbl := bottomfrac_dbl + bottomstep_dbl;
    inc(rwx);
    inc(pceilingclip);
    inc(pfloorclip);
  end;

end;

//
// R_StoreWallRange
// A wall segment will be drawn
//  between start and stop pixels (inclusive).
//
procedure R_StoreWallRange(const start: integer; const stop: integer);
var
  vtop: fixed_t;
  lightnum: integer;
  pds: Pdrawseg_t;
  rw_scale_dbl2: double;
  worldtop_dbl: Double;
  worldbottom_dbl: Double;
begin
  // don't overflow and crash
  if ds_p = MAXDRAWSEGS then
    exit;

  // JVAL
  // Now drawsegs is an array of pointer to drawseg_t
  // Dynamically allocation using zone
  if ds_p > max_ds_p then
  begin
    drawsegs[ds_p] := Z_Malloc(SizeOf(drawseg_t), PU_LEVEL, nil);
    max_ds_p := ds_p;
  end;
  pds := drawsegs[ds_p];

  sidedef := curline.sidedef;
  linedef := curline.linedef;

  // mark the segment as visible for auto map
  linedef.flags := linedef.flags or ML_MAPPED;

  // calculate rw_distance for scale calculation
  rw_normalangle := curline.r_normalangle;

  rw_distance := R_DistToSeg(curline);

  rw_x := start;
  pds.x1 := rw_x;
  pds.x2 := stop;
  pds.curline := curline;
  rw_stopx := stop + 1;

  // calculate scale at both ends and step
  rw_scale_dbl := R_ScaleFromGlobalAngle_DBL(viewangle + xtoviewangle[start]);
  rw_scale := trunc(rw_scale_dbl);
  pds.scale1 := rw_scale;

  if stop > start then
  begin
    rw_scale_dbl2 := R_ScaleFromGlobalAngle_DBL(viewangle + xtoviewangle[stop]);
    rw_scalestep_dbl := (rw_scale_dbl2 - rw_scale_dbl) / (stop - start);
    pds.scale2 := trunc(rw_scale_dbl2);
    rw_scalestep := trunc(rw_scalestep_dbl);
    pds.scalestep := rw_scalestep;
  end
  else
  begin
    pds.scale2 := pds.scale1;
    pds.scalestep := 0;
  end;

  // calculate texture boundaries
  //  and decide if floor / ceiling marks are needed
  worldtop := frontsector.ceilingheight - viewz;
  worldbottom := frontsector.floorheight - viewz;

  midtexture := 0;
  toptexture := 0;
  bottomtexture := 0;
  maskedtexture := false;
  pds.maskedtexturecol := nil;

  if backsector = nil then
  begin
    // single sided line
    midtexture := texturetranslation[sidedef.midtexture];
    // a single sided line is terminal, so it must mark ends
    markfloor := true;
    markceiling := true;
    if linedef.flags and ML_DONTPEGBOTTOM <> 0 then
    begin
      vtop := frontsector.floorheight + textureheight[sidedef.midtexture];
      // bottom of texture at bottom
      rw_midtexturemid := vtop - viewz;
    end
    else
    begin
      // top of texture at top
      rw_midtexturemid := worldtop;
    end;
    rw_midtexturemid := rw_midtexturemid + sidedef.rowoffset;

    pds.silhouette := SIL_BOTH;
    pds.sprtopclip := @screenheightarray;
    pds.sprbottomclip := @negonearray;
    pds.bsilheight := MAXINT;
    pds.tsilheight := MININT;
  end
  else
  begin
    // two sided line
    pds.sprtopclip := nil;
    pds.sprbottomclip := nil;
    pds.silhouette := 0;

    if frontsector.floorheight > backsector.floorheight then
    begin
      pds.silhouette := SIL_BOTTOM;
      pds.bsilheight := frontsector.floorheight;
    end
    else if backsector.floorheight > viewz then
    begin
      pds.silhouette := SIL_BOTTOM;
      pds.bsilheight := MAXINT;
    end;

    if frontsector.ceilingheight < backsector.ceilingheight then
    begin
      pds.silhouette := pds.silhouette or SIL_TOP;
      pds.tsilheight := frontsector.ceilingheight;
    end
    else if backsector.ceilingheight < viewz then
    begin
      pds.silhouette := pds.silhouette or SIL_TOP;
      pds.tsilheight := MININT;
    end;

    if backsector.ceilingheight <= frontsector.floorheight then
    begin
      pds.sprbottomclip := @negonearray;
      pds.bsilheight := MAXINT;
      pds.silhouette := pds.silhouette or SIL_BOTTOM;
    end;

    if backsector.floorheight >= frontsector.ceilingheight then
    begin
      pds.sprtopclip := @screenheightarray;
      pds.tsilheight := MININT;
      pds.silhouette := pds.silhouette or SIL_TOP;
    end;

    worldhigh := backsector.ceilingheight - viewz;
    worldlow := backsector.floorheight - viewz;

    // hack to allow height changes in outdoor areas
    if (frontsector.ceilingpic = skyflatnum) and
       (backsector.ceilingpic = skyflatnum) then
    begin
      worldtop := worldhigh;
    end;

    if (backsector.ceilingheight <= frontsector.floorheight) or
       (backsector.floorheight >= frontsector.ceilingheight) then
    begin
      // closed door
      markceiling := true;
      markfloor := true;
    end
    else
    begin
      markfloor := (worldlow <> worldbottom) or
                   (backsector.floorpic <> frontsector.floorpic) or
                   (backsector.lightlevel <> frontsector.lightlevel);

      markceiling := (worldhigh <> worldtop) or
                     (backsector.ceilingpic <> frontsector.ceilingpic) or
                     (backsector.lightlevel <> frontsector.lightlevel);
    end;

    if worldhigh < worldtop then
    begin
      // top texture
      toptexture := texturetranslation[sidedef.toptexture];
      if linedef.flags and ML_DONTPEGTOP <> 0 then
      begin
        // top of texture at top
        rw_toptexturemid := worldtop;
      end
      else
      begin
        vtop := backsector.ceilingheight + textureheight[sidedef.toptexture];

        // bottom of texture
        rw_toptexturemid := vtop - viewz;
      end
    end;

    if worldlow > worldbottom then
    begin
      // bottom texture
      bottomtexture := texturetranslation[sidedef.bottomtexture];

      if linedef.flags and ML_DONTPEGBOTTOM <> 0 then
      begin
        // bottom of texture at bottom
        // top of texture at top
        rw_bottomtexturemid := worldtop;
      end
      else // top of texture at top
        rw_bottomtexturemid := worldlow;
    end;
    rw_toptexturemid := rw_toptexturemid + sidedef.rowoffset;
    rw_bottomtexturemid := rw_bottomtexturemid + sidedef.rowoffset;

    // allocate space for masked texture tables
    if sidedef.midtexture <> 0 then
    begin
      // masked midtexture
      maskedtexture := true;
      maskedtexturecol := PSmallIntArray(@openings[lastopening - rw_x]);
      pds.maskedtexturecol := maskedtexturecol;
      lastopening := lastopening + rw_stopx - rw_x;
    end;
  end;

  // calculate rw_offset (only needed for textured lines)
  segtextured := ((midtexture or toptexture or bottomtexture) <> 0) or maskedtexture;

  if segtextured then
  begin
    rw_offset := R_CalcSegOffset(curline);

    if LongWord(rw_normalangle - rw_angle1) < ANG180 then
      rw_offset := -rw_offset;

    rw_offset := rw_offset + sidedef.textureoffset + curline.offset;
    rw_centerangle := ANG90 + viewangle - rw_normalangle;

    // calculate light table
    //  use different light tables
    //  for horizontal / vertical / diagonal
    // OPTIMIZE: get rid of LIGHTSEGSHIFT globally
    if fixedcolormap = nil then
    begin
      lightnum := _SHR(frontsector.lightlevel, LIGHTSEGSHIFT) + extralight;

      if curline.v1.r_y = curline.v2.r_y then
        dec(lightnum)
      else if curline.v1.r_x = curline.v2.r_x then
        inc(lightnum);

      if lightnum < 0 then
        lightnum := 0
      else if lightnum >= LIGHTLEVELS then
        lightnum := LIGHTLEVELS - 1;
      walllights := @scalelight[lightnum];

      dc_llindex := lightnum;
    end;
  end;

  // if a floor / ceiling plane is on the wrong side
  //  of the view plane, it is definitely invisible
  //  and doesn't need to be marked.


  if frontsector.floorheight >= viewz then
  begin
    // above view plane
    markfloor := false;
  end;

  if (frontsector.ceilingheight <= viewz) and
     (frontsector.ceilingpic <> skyflatnum) then
  begin
    // below view plane
    markceiling := false;
  end;


  // calculate incremental stepping values for texture edges
  worldtop_dbl := worldtop / WORLDUNIT;
  worldbottom_dbl := worldbottom / WORLDUNIT;

  worldtop := worldtop div WORLDUNIT;
  worldbottom := worldbottom div WORLDUNIT;

  topstep_dbl := - rw_scalestep_dbl / FRACUNIT * worldtop_dbl;
  topfrac_dbl := (centeryfrac / WORLDUNIT) - worldtop_dbl / FRACUNIT * rw_scale_dbl;
  bottomstep_dbl := - rw_scalestep_dbl / FRACUNIT * worldbottom_dbl;
  bottomfrac_dbl := (centeryfrac / WORLDUNIT) - worldbottom_dbl / FRACUNIT * rw_scale_dbl;

  if backsector <> nil then
  begin
    worldhigh_dbl := worldhigh / WORLDUNIT;
    worldlow_dbl := worldlow / WORLDUNIT;
    worldhigh := worldhigh div WORLDUNIT;
    worldlow := worldlow div WORLDUNIT;

    if worldhigh_dbl < worldtop_dbl then
    begin
      pixhigh_dbl := (centeryfrac / WORLDUNIT) - worldhigh_dbl / FRACUNIT * rw_scale_dbl;
      pixhighstep_dbl := -rw_scalestep_dbl / FRACUNIT * worldhigh_dbl;
    end;

    if worldlow_dbl > worldbottom_dbl then
    begin
      pixlow_dbl := (centeryfrac / WORLDUNIT) - worldlow_dbl / FRACUNIT * rw_scale_dbl;
      pixlowstep_dbl := -rw_scalestep_dbl / FRACUNIT * worldlow_dbl;
    end;
  end;

  // render it
  if markceiling then
    ceilingplane := R_CheckPlane(ceilingplane, rw_x, rw_stopx - 1);

  if markfloor then
    floorplane := R_CheckPlane(floorplane, rw_x, rw_stopx - 1);

  R_RenderSegLoop;

  // JVAL: Changed to fix accuracy for masked textures
  // This fixes some glitches in 2s lines with midtexture (eg BOOMEDIT.WAD)
  if maskedtexture then
  begin
    rw_scale := R_ScaleFromGlobalAngle(viewangle + xtoviewangle[start]);
    pds.scale1 := rw_scale;

    if stop > start then
    begin
      pds.scale2 := R_ScaleFromGlobalAngle(viewangle + xtoviewangle[stop]);
      rw_scalestep := (pds.scale2 - rw_scale) div (stop - start);
      pds.scalestep := rw_scalestep;
    end
    else
    begin
      pds.scale2 := pds.scale1;
      pds.scalestep := 0;
    end;
  end;

  // save sprite clipping info
  if ((pds.silhouette and SIL_TOP <> 0) or maskedtexture) and
     (pds.sprtopclip = nil) then
  begin
    memcpy(@openings[lastopening], @ceilingclip[start], SizeOf(ceilingclip[0]) * (rw_stopx - start));
    pds.sprtopclip := PSmallIntArray(@openings[lastopening - start]);
    lastopening := lastopening + rw_stopx - start;
  end;

  if ((pds.silhouette and SIL_BOTTOM <> 0) or maskedtexture) and
     (pds.sprbottomclip = nil) then
  begin
    memcpy(@openings[lastopening], @floorclip[start], SizeOf(floorclip[0]) * (rw_stopx - start));
    pds.sprbottomclip := PSmallIntArray(@openings[lastopening - start]);
    lastopening := lastopening + rw_stopx - start;
  end;

  if maskedtexture and (pds.silhouette and SIL_TOP = 0) then
  begin
    pds.silhouette := pds.silhouette or SIL_TOP;
    pds.tsilheight := MININT;
  end;
  if maskedtexture and (pds.silhouette and SIL_BOTTOM = 0) then
  begin
    pds.silhouette := pds.silhouette or SIL_BOTTOM;
    pds.bsilheight := MAXINT;
  end;
  inc(ds_p);
end;


end.
