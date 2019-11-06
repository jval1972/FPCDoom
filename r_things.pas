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

unit r_things;

interface

uses
  d_fpc,
  doomdef,
  m_fixed,
  r_defs;

const
// JVAL Note about visprites
// Now visprites allocated dinamycally using Zone memory
// (Original MAXVISSPRITES was 128)
  MAXVISSPRITES = 16384;

var
  maxvissprite: integer;

procedure R_DrawMaskedColumn(const col: Pcolumn_t; flags: LongWord);
procedure R_DrawMaskedColumn32(const mc2h: integer; flags: LongWord); // Use dc_source32


procedure R_SortVisSprites;

procedure R_AddSprites(sec: Psector_t);
procedure R_InitNegoArray;
procedure R_InitSprites(namelist: PIntegerArray);
procedure R_ClearSprites;
procedure R_DrawMasked;
procedure R_MarkLights;
procedure R_DrawPlayer;

var
  pspritescale: fixed_t;
  pspriteiscale: fixed_t;
  pspriteyscale: fixed_t;
  pspritescalep: fixed_t;
  pspriteiscalep: fixed_t;

var
  mfloorclip: PSmallIntArray;
  mceilingclip: PSmallIntArray;
  spryscale: fixed_t;
  sprtopscreen: fixed_t;

// constant arrays             
//  used for psprite clipping and initializing clipping
  negonearray: packed array[0..MAXWIDTH - 1] of smallint;
  screenheightarray: packed array[0..MAXWIDTH - 1] of smallint;

// variables used to look up
//  and range check thing_t sprites patches
  sprites: Pspritedef_tArray;
  numspritespresent: integer;

implementation

uses
  tables,
  info_h,
  i_system,
  p_mobj_h,
  p_pspr, 
  p_pspr_h,
  p_tick,
  r_data, 
  r_draw, 
  r_main, 
  r_bsp, 
  r_segs,
  r_lightmap,
  r_draw_column,
  r_mirror,
  r_render,
  r_hires,
  r_trans8,
  z_memory,
  w_wad,
  doomstat;

const
  MINZ = FRACUNIT * 4;
  BASEYCENTER = 100;

//
// Sprite rotation 0 is facing the viewer,
//  rotation 1 is one angle turn CLOCKWISE around the axis.
// This is not the same as the angle,
//  which increases counter clockwise (protractor).
// There was a lot of stuff grabbed wrong, so I changed it...
//
var
  spritelights: PBytePArray;

//
// INITIALIZATION FUNCTIONS
//
const
  MAXFRAMES = 29; // Maximun number of frames in sprite

var
  sprtemp: array[0..MAXFRAMES - 1] of spriteframe_t;
  maxframe: integer;
  spritename: string;

//
// R_InstallSpriteLump
// Local function for R_InitSprites.
//
procedure R_InstallSpriteLump(lump: integer;
  frame: LongWord; rotation: LongWord; flipped: boolean);
var
  r: integer;
begin
  if (frame >= MAXFRAMES) or (rotation > 8) then
    I_DevError('R_InstallSpriteLump(): Bad frame characters in lump %d (frame = %d, rotation = %d)'#13#10, [lump, frame, rotation]);

  if integer(frame) > maxframe then
    maxframe := frame;

  if rotation = 0 then
  begin
    // the lump should be used for all rotations
    if sprtemp[frame].rotate = 0 then
      I_Warning('R_InitSprites(): Sprite %s frame %s has multip rot=0 lump'#13#10,
        [spritename, Chr(Ord('A') + frame)]);

    if sprtemp[frame].rotate = 1 then
      I_Warning('R_InitSprites(): Sprite %s frame %s has rotations and a rot=0 lump'#13#10,
        [spritename, Chr(Ord('A') + frame)]);

    sprtemp[frame].rotate := 0;
    for r := 0 to 7 do
    begin
      sprtemp[frame].lump[r] := lump - firstspritelump;
      sprtemp[frame].flip[r] := flipped;
    end;
    exit;
  end;

  // the lump is only used for one rotation
  if sprtemp[frame].rotate = 0 then
    I_DevError('R_InitSprites(): Sprite %s frame %s has rotations and a rot=0 lump'#13#10,
      [spritename, Chr(Ord('A') + frame)]);

  sprtemp[frame].rotate := 1;

  // make 0 based
  dec(rotation);
  if sprtemp[frame].lump[rotation] <> -1 then
    I_DevWarning('R_InitSprites(): Sprite %s : %s : %s has two lumps mapped to it'#13#10,
      [spritename, Chr(Ord('A') + frame), Chr(Ord('1') + rotation)]);

  sprtemp[frame].lump[rotation] := lump - firstspritelump;
  sprtemp[frame].flip[rotation] := flipped;
end;

//
// R_InitSpriteDefs
// Pass a null terminated list of sprite names
//  (4 chars exactly) to be used.
// Builds the sprite rotation matrixes to account
//  for horizontally flipped sprites.
// Will report an error if the lumps are inconsistant.
// Only called at startup.
//
// Sprite lump names are 4 characters for the actor,
//  a letter for the frame, and a number for the rotation.
// A sprite that is flippable will have an additional
//  letter/number appended.
// The rotation character can be 0 to signify no rotations.
//
procedure R_InitSpriteDefs(namelist: PIntegerArray);

  procedure sprtempreset;
  var
    i: integer;
    j: integer;
  begin
    for i := 0 to MAXFRAMES - 1 do
    begin
      sprtemp[i].rotate := -1;
      for j := 0 to 7 do
      begin
        sprtemp[i].lump[j] := -1;
        sprtemp[i].flip[j] := false;
      end;
    end;
  end;

var
  i: integer;
  l: integer;
  intname: integer;
  frame: integer;
  rotation: integer;
  start: integer;
  _end: integer;
  patched: integer;
begin
  // count the number of sprite names

  numspritespresent := 0;
  while namelist[numspritespresent] <> 0 do
    inc(numspritespresent);

  if numspritespresent = 0 then
    exit;

  sprites := Z_Malloc(numspritespresent * SizeOf(spritedef_t), PU_STATIC, nil);
  ZeroMemory(sprites, numspritespresent * SizeOf(spritedef_t));

  start := firstspritelump - 1;
  _end := lastspritelump + 1;

  // scan all the lump names for each of the names,
  //  noting the highest frame letter.
  // Just compare 4 characters as ints
  for i := 0 to numspritespresent - 1 do
  begin
    spritename := Chr(namelist[i]) + Chr(namelist[i] shr 8) + Chr(namelist[i] shr 16) + Chr(namelist[i] shr 24);

    sprtempreset;

    maxframe := -1;
    intname := namelist[i];

    // scan the lumps,
    //  filling in the frames for whatever is found
    for l := start + 1 to _end - 1 do
    begin
      if spritepresent[l - firstspritelump] then

      if lumpinfo[l].v1 = intname then // JVAL
      begin
        frame := Ord(lumpinfo[l].name[4]) - Ord('A');
        rotation := Ord(lumpinfo[l].name[5]) - Ord('0');

        if modifiedgame then
          patched := W_GetNumForName(lumpinfo[l].name)
        else
          patched := l;

        R_InstallSpriteLump(patched, frame, rotation, false);

        if lumpinfo[l].name[6] <> #0 then
        begin
          frame := Ord(lumpinfo[l].name[6]) - Ord('A');
          rotation := Ord(lumpinfo[l].name[7]) - Ord('0');
          R_InstallSpriteLump(l, frame, rotation, true);
        end;
      end;
    end;

    // check the frames that were found for completeness
    if maxframe = -1 then
    begin
      sprites[i].numframes := 0;
      continue;
    end;

    inc(maxframe);

    for frame := 0 to maxframe - 1 do
    begin
      case sprtemp[frame].rotate of
        -1:
          begin
            // no rotations were found for that frame at all
            // JVAL: Changed from I_Error to I_Warning
            I_Warning('R_InitSprites(): No patches found for %s frame %s'#13#10,
              [spritename, Chr(frame + Ord('A'))]);
          end;
         0:
          begin
            // only the first rotation is needed
          end;
         1:
          begin
            // must have all 8 frames
            for rotation := 0 to 7 do
              if sprtemp[frame].lump[rotation] = -1 then
                I_Error('R_InitSprites(): Sprite %s frame %s is missing rotations',
                  [spritename, Chr(frame + Ord('A'))]);
          end;
      end;
    end;

    // allocate space for the frames present and copy sprtemp to it
    sprites[i].numframes := maxframe;
    sprites[i].spriteframes :=
      Z_Malloc(maxframe * SizeOf(spriteframe_t), PU_STATIC, nil);
    memcpy(sprites[i].spriteframes, @sprtemp, maxframe * SizeOf(spriteframe_t));
  end;
end;

//
// GAME FUNCTIONS
//
var
  vissprites: array[0..MAXVISSPRITES - 1] of Pvissprite_t;
  vissprite_p: integer;

procedure R_InitNegoArray;
var
  i: integer;
begin
  for i := 0 to SCREENWIDTH - 1 do
    negonearray[i] := -1;
end;

//
// R_InitSprites
// Called at program start.
//
procedure R_InitSprites(namelist: PIntegerArray);
begin
  R_InitNegoArray;
  R_InitSpriteDefs(namelist);
end;

//
// R_ClearSprites
// Called at frame start.
//
procedure R_ClearSprites;
begin
  vissprite_p := 0;
end;

//
// R_NewVisSprite
//
// JVAL Now we allocate a new visprite dynamically
//
var
  overflowsprite: vissprite_t;

function R_NewVisSprite: Pvissprite_t;
begin
  if vissprite_p = MAXVISSPRITES then
    result := @overflowsprite
  else
  begin
    if vissprite_p > maxvissprite then
    begin
      maxvissprite := vissprite_p;
      vissprites[vissprite_p] := Pvissprite_t(Z_Malloc(SizeOf(vissprite_t), PU_LEVEL, nil));
    end;
    result := vissprites[vissprite_p];
    inc(vissprite_p);
  end;
end;

//
// R_DrawMaskedColumn
// Used for sprites and masked mid textures.
// Masked means: partly transparent, i.e. stored
//  in posts/runs of opaque pixels.
//
procedure R_DrawMaskedColumn(const col: Pcolumn_t; flags: LongWord);
var
  topscreen: int64;
  bottomscreen: int64;
  basetexturemid: fixed_t;
  fc_x, cc_x: integer;
  column: Pcolumn_t;
begin
  basetexturemid := rcolumn.dc_texturemid;

  fc_x := mfloorclip[rcolumn.dc_x];
  cc_x := mceilingclip[rcolumn.dc_x];

  column := col;
  while column.topdelta <> $ff do
  begin
    // calculate unclipped screen coordinates
    // for post
    topscreen := sprtopscreen + int64(spryscale) * int64(column.topdelta);
    bottomscreen := topscreen + int64(spryscale) * int64(column.length);

    rcolumn.dc_yl := FixedInt64(topscreen + (FRACUNIT - 1));
    rcolumn.dc_yh := FixedInt64(bottomscreen - 1);

    if rcolumn.dc_yh >= fc_x then
      rcolumn.dc_yh := fc_x - 1;
    if rcolumn.dc_yl <= cc_x then
      rcolumn.dc_yl := cc_x + 1;

    if rcolumn.dc_yl <= rcolumn.dc_yh then
    begin
      rcolumn.dc_source := PByteArray(integer(column) + 3);
      rcolumn.dc_texturemid := basetexturemid - (column.topdelta * FRACUNIT);
      // Drawn by either R_DrawColumn
      //  or (SHADOW) R_DrawFuzzColumn
      //  or R_DrawColumnAverage
      //  or R_DrawTranslatedColumn
      R_AddRenderTask(colfunc, flags, @rcolumn);
    end;
    column := Pcolumn_t(integer(column) + column.length + 4);
  end;

  rcolumn.dc_texturemid := basetexturemid;
end;

procedure R_DrawPlayerColumn(const col: Pcolumn_t; flags: LongWord);
var
  topscreen: int64;
  bottomscreen: int64;
  basetexturemid: fixed_t;
  fc_x, cc_x: integer;
  column: Pcolumn_t;
begin
  basetexturemid := rcolumn.dc_texturemid;

  fc_x := mfloorclip[rcolumn.dc_x];
  cc_x := mceilingclip[rcolumn.dc_x];
  column := col;
  while column.topdelta <> $ff do
  begin
    // calculate unclipped screen coordinates
    // for post
    topscreen := sprtopscreen + int64(spryscale) * int64(column.topdelta);
    bottomscreen := topscreen + int64(spryscale) * int64(column.length);

    rcolumn.dc_yl := FixedInt64(topscreen + (FRACUNIT - 1));
    rcolumn.dc_yh := FixedInt64(bottomscreen - 1);

    if rcolumn.dc_yh >= fc_x then
      rcolumn.dc_yh := fc_x - 1;
    if rcolumn.dc_yl <= cc_x then
      rcolumn.dc_yl := cc_x + 1;

    if rcolumn.dc_yl <= rcolumn.dc_yh then
    begin
      rcolumn.dc_source := PByteArray(integer(column) + 3);
      rcolumn.dc_texturemid := basetexturemid - (column.topdelta * FRACUNIT);
      // Drawn by either R_DrawColumn
      //  or (SHADOW) R_DrawFuzzColumn
      //  or R_DrawColumnAverage
      //  or R_DrawTranslatedColumn
      colfunc(@rcolumn);
    end;
    column := Pcolumn_t(integer(column) + column.length + 4);
  end;

  rcolumn.dc_texturemid := basetexturemid;
end;

procedure R_DrawMaskedColumn32(const mc2h: integer; flags: LongWord); // Use dc_source32
var
  topscreen: int64;
  bottomscreen: int64;
  basetexturemid: fixed_t;
  fc_x, cc_x: integer;
begin
  basetexturemid := rcolumn.dc_texturemid;

  fc_x := mfloorclip[rcolumn.dc_x];
  cc_x := mceilingclip[rcolumn.dc_x];

  topscreen := sprtopscreen;
  bottomscreen := topscreen + int64(spryscale) * int64(mc2h);

  rcolumn.dc_yl := FixedInt64(topscreen + (FRACUNIT - 1));
  rcolumn.dc_yh := FixedInt64(bottomscreen - 1);

  if rcolumn.dc_yh >= fc_x then
    rcolumn.dc_yh := fc_x - 1;
  if rcolumn.dc_yl <= cc_x then
    rcolumn.dc_yl := cc_x + 1;

  if rcolumn.dc_yl <= rcolumn.dc_yh then
  begin
      // Drawn by either R_DrawColumn
      //  or (SHADOW) R_DrawFuzzColumn
      //  or R_DrawColumnAverage
      //  or R_DrawTranslatedColumn
    R_AddRenderTask(colfunc, flags, @rcolumn);
  end;

  rcolumn.dc_texturemid := basetexturemid;
end;

type
  thingdrawer_t = procedure (const col: Pcolumn_t; flags: LongWord);

// R_DrawVisSprite
//  mfloorclip and mceilingclip should also be set.
//
procedure R_DrawVisSprite(vis: Pvissprite_t; proc: thingdrawer_t);
var
  column: Pcolumn_t;
  texturecolumn: integer;
  frac: fixed_t;
  patch: Ppatch_t;
  xiscale: integer;
  flags: LongWord;
begin
  patch := W_CacheLumpNum(vis.patch + firstspritelump, PU_STATIC);

  rcolumn.dc_colormap := vis.colormap;
  rcolumn.seg := nil;
  rcolumn.rendertype := RIT_SPRITE;

  if videomode = vm32bit then
  begin
    rcolumn.dc_colormap32 := R_GetColormap32(rcolumn.dc_colormap);
    if fixedcolormapnum = INVERSECOLORMAP then
      rcolumn.dc_lightlevel := -1
    else
      rcolumn.dc_lightlevel := R_GetColormapLightLevel(rcolumn.dc_colormap);
  end;

  if rcolumn.dc_colormap = nil then
  begin
    // NULL colormap = shadow draw
    colfunc := fuzzcolfunc;
  end
  else if vis.mobjflags and MF_TRANSLATION <> 0 then
  begin
    colfunc := transcolfunc;
    dc_translation := PByteArray(integer(translationtables) - 256 +
      (_SHR((vis.mobjflags and MF_TRANSLATION), (MF_TRANSSHIFT - 8))));
  end
  else if usetransparentsprites and (vis.mobjflags_ex and MF_EX_TRANSPARENT <> 0) then
  begin
    rcolumn.curtrans8table := R_GetTransparency8table;
    colfunc := averagecolfunc
  end
  else if usetransparentsprites and (vis.mo <> nil) and (vis.mo.renderstyle = mrs_translucent) then
  begin
    rcolumn.dc_alpha := vis.mo.alpha;
    rcolumn.curtrans8table := R_GetTransparency8table(rcolumn.dc_alpha);
    colfunc := alphacolfunc;
  end
  else
    colfunc := maskedcolfunc;

  rcolumn.dc_iscale := FixedDivEx(FRACUNIT, vis.scale);
  rcolumn.dc_texturemid := vis.texturemid;
  frac := vis.startfrac;
  spryscale := vis.scale;
  sprtopscreen := centeryfrac - FixedMul(rcolumn.dc_texturemid, spryscale);

  // set draw flags
  if lightmapaccuracymode = MAXLIGHTMAPACCURACYMODE then
    flags := RF_MASKED or RF_DEPTHBUFFERWRITE
  else
    flags := RF_MASKED;

  xiscale := vis.xiscale;
  rcolumn.dc_x := vis.x1;
  while rcolumn.dc_x <= vis.x2 do
  begin
    texturecolumn := LongWord(frac) shr FRACBITS;

    column := Pcolumn_t(integer(patch) + patch.columnofs[texturecolumn]);
    proc(column, flags);
    frac := frac + xiscale;
    inc(rcolumn.dc_x);
  end;

  Z_ChangeTag(patch, PU_CACHE);
end;

//
//
// R_ProjectSprite
// Generates a vissprite for a thing
//  if it might be visible.
//
procedure R_ProjectSprite(thing: Pmobj_t);
var
  tr_x: fixed_t;
  tr_y: fixed_t;
  gxt: fixed_t;
  gyt: fixed_t;
  tx: fixed_t;
  tz: fixed_t;
  xscale: fixed_t;
  x1: integer;
  x2: integer;
  sprdef: Pspritedef_t;
  sprframe: Pspriteframe_t;
  lump: integer;
  rot: LongWord;
  flip: boolean;
  index: integer;
  vis: Pvissprite_t;
  ang: angle_t;
  iscale: fixed_t;
begin
  if (thing.player = viewplayer) and not chasecamera then
    exit;

  // transform the origin point
  tr_x := thing.x - viewx;
  tr_y := thing.y - viewy;

  gxt := FixedMul(tr_x, viewcos);
  gyt := -FixedMul(tr_y, viewsin);

  tz := gxt - gyt;

  // thing is behind view plane?
  if tz < MINZ then
    exit;

  xscale := FixedDiv(projection, tz);

  gxt := -FixedMul(tr_x, viewsin);
  gyt := FixedMul(tr_y, viewcos);
  tx := -(gyt + gxt);

  // too far off the side?
  if abs(tx) > 4 * tz then
    exit;

  // decide which patch to use for sprite relative to player

  sprdef := @sprites[thing.sprite];

  if sprdef.numframes <= 0 then
  begin
    sprdef := @sprites[Ord(SPR_NULL)];
    sprframe := @sprdef.spriteframes[0];
  end
  else
    sprframe := @sprdef.spriteframes[thing.frame and FF_FRAMEMASK];

  if sprframe = nil then
  begin
    I_DevError('R_ProjectSprite(): Sprite for "%s" is NULL.'#13#10, [thing.info.name]);
    exit;
  end;

  if sprframe.rotate <> 0 then
  begin
    // choose a different rotation based on player view
    ang := R_PointToAngle(thing.x, thing.y);
    rot := _SHRW((ang - thing.angle + LongWord(ANG45 div 2) * 9), 29);
    lump := sprframe.lump[rot];
    flip := sprframe.flip[rot];
  end
  else
  begin
    // use single rotation for all views
    lump := sprframe.lump[0];
    flip := sprframe.flip[0];
  end;

  // calculate edges of the shape
  tx := tx - spriteoffset[lump];
  x1 := FixedInt(centerxfrac + FixedMul(tx, xscale));

  // off the right side?
  if x1 > viewwidth then
    exit;

  tx := tx + spritewidth[lump];
  x2 := FixedInt(centerxfrac + FixedMul(tx, xscale)) - 1;

  // off the left side
  if x2 < 0 then
    exit;

  // store information in a vissprite
  vis := R_NewVisSprite;
  vis.mobjflags := thing.flags;
  vis.mobjflags_ex := thing.flags_ex or thing.state.flags_ex; // JVAL: extended flags passed to vis
  vis.mobjflags2_ex := thing.flags2_ex; // JVAL: extended flags passed to vis
  vis.mo := thing;
  vis._type := thing._type;
  vis.scale := FixedDiv(projectiony, tz); // JVAL For correct aspect
  vis.gx := thing.x;
  vis.gy := thing.y;
  vis.gz := thing.z;
  vis.gzt := thing.z + spritetopoffset[lump];
  vis.texturemid := vis.gzt - viewz;
  vis.texturemid2 := thing.z + 2 * spritetopoffset[lump] - viewz;
  if x1 <= 0 then
    vis.x1 := 0
  else
    vis.x1 := x1;
  if x2 >= viewwidth then
    vis.x2 := viewwidth - 1
  else
    vis.x2 := x2;
  iscale := FixedDiv(FRACUNIT, xscale);

  if flip then
  begin
    vis.startfrac := spritewidth[lump] - 1;
    vis.xiscale := -iscale;
  end
  else
  begin
    vis.startfrac := 0;
    vis.xiscale := iscale;
  end;

  if vis.x1 > x1 then
    vis.startfrac := vis.startfrac + vis.xiscale * (vis.x1 - x1);
  vis.patch := lump;

  // get light level
  if thing.flags and MF_SHADOW <> 0 then
  begin
    // shadow draw
    vis.colormap := nil;
  end
  else if fixedcolormap <> nil then
  begin
    // fixed map
    vis.colormap := fixedcolormap;
  end
  else if thing.frame and FF_FULLBRIGHT <> 0 then
  begin
    // full bright
    vis.colormap := colormaps;
  end
  else
  begin
    // diminished light
    index := _SHR(xscale, LIGHTSCALESHIFT);

    if index >= MAXLIGHTSCALE then
      index := MAXLIGHTSCALE - 1;

    vis.colormap := spritelights[index];
  end;
end;

//
// R_AddSprites
// During BSP traversal, this adds sprites by sector.
//
procedure R_AddSprites(sec: Psector_t);
var
  thing: Pmobj_t;
  lightnum: integer;
begin
  // BSP is traversed by subsector.
  // A sector might have been split into several
  // subsectors during BSP building.
  // Thus we check whether its already added.
  if sec.validcount = validcount then
    exit;

  // Well, now it will be done.
  sec.validcount := validcount;

  lightnum := _SHR(sec.lightlevel, LIGHTSEGSHIFT) + extralight;

  if lightnum <= 0 then
    spritelights := @scalelight[0]
  else if lightnum >= LIGHTLEVELS then
    spritelights := @scalelight[LIGHTLEVELS - 1]
  else
    spritelights := @scalelight[lightnum];

  // Handle all things in sector.
  thing := sec.thinglist;
  while thing <> nil do
  begin
    R_ProjectSprite(thing);
    thing := thing.snext;
  end;
end;

//
// R_DrawPSprite
//
procedure R_DrawPSprite(psp: Ppspdef_t);
var
  tx: fixed_t;
  x1: integer;
  x2: integer;
  sprdef: Pspritedef_t;
  sprframe: Pspriteframe_t;
  lump: integer;
  flip: boolean;
  vis: Pvissprite_t;
  avis: vissprite_t;
begin
  // decide which patch to use

  sprdef := @sprites[Ord(psp.state.sprite)];

  sprframe := @sprdef.spriteframes[psp.state.frame and FF_FRAMEMASK];

  lump := sprframe.lump[0];
  flip := sprframe.flip[0];

  // calculate edges of the shape
  tx := psp.sx - 160 * FRACUNIT;

  tx := tx - spriteoffset[lump];
  x1 := FixedInt(centerxfrac + centerxshift + FixedMul(tx, pspritescalep));

  // off the right side
  if x1 > viewwidth then
    exit;

  tx := tx + spritewidth[lump];
  x2 := FixedInt(centerxfrac + centerxshift + FixedMul(tx, pspritescalep)) - 1;

  // off the left side
  if x2 < 0 then
    exit;

  // store information in a vissprite
  vis := @avis;
  vis.mobjflags := 0;
  vis.mobjflags_ex := 0;
  vis.mobjflags2_ex := 0;
  vis.mo := viewplayer.mo;
  vis._type := Ord(MT_PLAYER);
  vis.texturemid := (BASEYCENTER * FRACUNIT) + FRACUNIT div 2 - (psp.sy - spritetopoffset[lump]);
  if x1 < 0 then
    vis.x1 := 0
  else
    vis.x1 := x1;
  if x2 >= viewwidth then
    vis.x2 := viewwidth - 1
  else
    vis.x2 := x2;
  vis.scale := pspriteyscale;

  if flip xor (mirrormode and MR_WEAPON <> 0) then
  begin
    vis.xiscale := -pspriteiscalep;
    vis.startfrac := spritewidth[lump] - 1;
  end
  else
  begin
    vis.xiscale := pspriteiscalep;
    vis.startfrac := 0;
  end;

  if vis.x1 > x1 then
    vis.startfrac := vis.startfrac + vis.xiscale * (vis.x1 - x1);
  vis.patch := lump;

  if (viewplayer.powers[Ord(pw_invisibility)] > 4 * 32) or
     (viewplayer.powers[Ord(pw_invisibility)] and 8 <> 0) then
  begin
    // shadow draw
    vis.colormap := nil;
  end
  else if fixedcolormap <> nil then
  begin
    // fixed color
    vis.colormap := fixedcolormap;
  end
  else if psp.state.frame and FF_FULLBRIGHT <> 0 then
  begin
    // full bright
    vis.colormap := colormaps;
  end
  else
  begin
    // local light
    vis.colormap := spritelights[MAXLIGHTSCALE - 1];
  end;

  if mirrormode and MR_WEAPON <> 0 then
  begin
    x2 := viewwidth - 1 - vis.x1;
    x1 := viewwidth - 1 - vis.x2;
    vis.x1 := x1;
    vis.x2 := x2;
  end;
  R_DrawVisSprite(vis, @R_DrawPlayerColumn);
end;

//
// R_DrawPlayerSprites
//
procedure R_DrawPlayerSprites;
var
  i: integer;
  lightnum: integer;
begin
  // get light level
  lightnum :=
    _SHR(Psubsector_t(viewplayer.mo.subsector).sector.lightlevel, LIGHTSEGSHIFT) +
      extralight;

  if lightnum <= 0 then
    spritelights := @scalelight[0]
  else if lightnum >= LIGHTLEVELS then
    spritelights := @scalelight[LIGHTLEVELS - 1]
  else
    spritelights := @scalelight[lightnum];

  // clip to screen bounds
  mfloorclip := @screenheightarray;
  mceilingclip := @negonearray;

  // add all active psprites
  if shiftangle < 128 then
    centerxshift := shiftangle * FRACUNIT div 40 * viewwidth
  else
    centerxshift := - (255 - shiftangle) * FRACUNIT div 40 * viewwidth;
  if mirrormode in [MR_WEAPON, MR_ENVIROMENT] then
    centerxshift := -centerxshift;
  for i := 0 to Ord(NUMPSPRITES) - 1 do
  begin
    if viewplayer.psprites[i].state <> nil then
      R_DrawPSprite(@viewplayer.psprites[i]);
  end;
end;

//
// R_SortVisSprites
//
var
  vsprsortedhead: vissprite_t;

procedure R_SortVisSprites;
var
  i: integer;
  count: integer;
  ds: Pvissprite_t;
  best: Pvissprite_t;
  unsorted: vissprite_t;
  bestscale: fixed_t;
begin            
  count := vissprite_p;

  if count = 0 then
    exit;

  unsorted.next := @unsorted;
  unsorted.prev := @unsorted;

  vissprites[0].next := vissprites[1];
  vissprites[0].prev := @unsorted;

  for i := 1 to count - 1 do
  begin
    vissprites[i].next := vissprites[i + 1];
    vissprites[i].prev := vissprites[i - 1];
  end;

  unsorted.prev := vissprites[vissprite_p - 1];
  unsorted.next := vissprites[0];
  vissprites[vissprite_p - 1].next := @unsorted;

  // pull the vissprites out by scale
  vsprsortedhead.next := @vsprsortedhead;
  vsprsortedhead.prev := @vsprsortedhead;
  for i := 0 to count - 1 do
  begin
    bestscale := MAXINT;
    ds := unsorted.next;
    best := nil; // JVAL - > avoid compiler warning
    while ds <> @unsorted do
    begin
      if ds.scale < bestscale then
      begin
        bestscale := ds.scale;
        best := ds;
      end;
      ds := ds.next;
    end;

    if best <> nil then // JVAL - > avoid compiler warning
    begin
      best.next.prev := best.prev;
      best.prev.next := best.next;
      best.next := @vsprsortedhead;
      best.prev := vsprsortedhead.prev;
      vsprsortedhead.prev.next := best;
      vsprsortedhead.prev := best;
    end;
  end;
end;

//
// R_DrawSprite
//

var
  clipbot: packed array[0..MAXWIDTH - 1] of smallint;
  cliptop: packed array[0..MAXWIDTH - 1] of smallint;

procedure R_DrawSprite(spr: Pvissprite_t);
var
  ds: Pdrawseg_t;
  x: integer;
  r1: integer;
  r2: integer;
  scale: fixed_t;
  lowscale: fixed_t;
  silhouette: integer;
  i: integer;
begin
  for x := spr.x1 to spr.x2 do
  begin
    clipbot[x] := -2;
    cliptop[x] := -2;
  end;

  // Scan drawsegs from end to start for obscuring segs.
  // The first drawseg that has a greater scale
  //  is the clip seg.
  for i := ds_p - 1 downto 0 do
  begin
    ds := drawsegs[i];
    // determine if the drawseg obscures the sprite
    if (ds.x1 > spr.x2) or
       (ds.x2 < spr.x1) or
       ((ds.silhouette = 0) and (ds.maskedtexturecol = nil)) then
    begin
      // does not cover sprite
      continue;
    end;

    if ds.x1 < spr.x1 then
      r1 := spr.x1
    else
      r1 := ds.x1;
    if ds.x2 > spr.x2 then
      r2 := spr.x2
    else
      r2 := ds.x2;

    if ds.scale1 > ds.scale2 then
    begin
      lowscale := ds.scale2;
      scale := ds.scale1;
    end
    else
    begin
      lowscale := ds.scale1;
      scale := ds.scale2;
    end;

    if (scale < spr.scale) or
       ((lowscale < spr.scale) and (not R_PointOnSegSide(spr.gx, spr.gy, ds.curline))) then
    begin
      // masked mid texture?
      if ds.maskedtexturecol <> nil then
        R_RenderMaskedSegRange(ds, r1, r2);
      // seg is behind sprite
      continue;
    end;

    // clip this piece of the sprite
    silhouette := ds.silhouette;

    if spr.gz >= ds.bsilheight then
      silhouette := silhouette and (not SIL_BOTTOM);

    if spr.gzt <= ds.tsilheight then
      silhouette := silhouette and (not SIL_TOP);

    if silhouette = 1 then
    begin
      // bottom sil
      for x := r1 to r2 do
        if clipbot[x] = -2 then
          clipbot[x] := ds.sprbottomclip[x];
    end
    else if silhouette = 2 then
    begin
      // top sil
      for x := r1 to r2 do
        if cliptop[x] = -2 then
          cliptop[x] := ds.sprtopclip[x];
    end
    else if silhouette = 3 then
    begin
      // both
      for x := r1 to r2 do
      begin
        if clipbot[x] = -2 then
          clipbot[x] := ds.sprbottomclip[x];
        if cliptop[x] = -2 then
          cliptop[x] := ds.sprtopclip[x];
      end;
    end;
  end;

  // all clipping has been performed, so draw the sprite

  // check for unclipped columns
  for x := spr.x1 to spr.x2 do
  begin
    if clipbot[x] = -2 then
      clipbot[x] := viewheight;

    if cliptop[x] = -2 then
      cliptop[x] := -1;
  end;

  mfloorclip := @clipbot;
  mceilingclip := @cliptop;

  R_DrawVisSprite(spr, @R_DrawMaskedColumn);
end;

//
// R_DrawMasked
//
procedure R_DrawMasked;
var
  spr: Pvissprite_t;
  ds: Pdrawseg_t;
  i: integer;
begin
  if vissprite_p > 0 then
  begin
    // draw all vissprites back to front
    spr := vsprsortedhead.next;
    while spr <> @vsprsortedhead do
    begin
      R_DrawSprite(spr);
      spr := spr.next;
    end;
  end;

  // render any remaining masked mid textures
  colfunc := maskedcolfunc;
  for i := ds_p - 1 downto 0 do
  begin
    ds := drawsegs[i];
    if ds.maskedtexturecol <> nil then
      R_RenderMaskedSegRange(ds, ds.x1, ds.x2);
  end;
end;

procedure R_MarkLights;
var
  spr: Pvissprite_t;
begin
  if vissprite_p > 0 then
  begin
    // draw all vissprites back to front
    spr := vsprsortedhead.next;
    while spr <> @vsprsortedhead do
    begin
      R_MarkDLights(spr.mo);
      spr := spr.next;
    end;
  end;
  R_AddAdditionalLights;
end;

procedure R_DrawPlayer;
var
  old_centery: fixed_t;
  old_centeryfrac: fixed_t;
begin
  // draw the psprites on top of everything
  //  but does not draw on side views
  if (viewangleoffset = 0) and not chasecamera then
  begin
    // Restore z-axis shift
    if zaxisshift then
    begin
      old_centery := centery;
      old_centeryfrac := centeryfrac;
      centery := viewheight div 2;
      centeryfrac := centery * FRACUNIT;
      R_DrawPlayerSprites;
      centery := old_centery;
      centeryfrac := old_centeryfrac;
    end
    else
      R_DrawPlayerSprites;
  end;
end;

end.
