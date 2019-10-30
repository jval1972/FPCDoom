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

unit p_spec;

interface

uses
  m_fixed,
  d_player, 
  d_think,
  p_mobj_h,
  p_tick,
  r_defs;

//
// End-level timer (-TIMER option)
//

const
//      Define values for map objects
  MO_TELEPORTMAN = 14;

// at game start
procedure P_InitPicAnims;

// at map load
procedure P_SpawnSpecials;

// every tic
procedure P_UpdateSpecials;

// when needed
procedure P_ShootSpecialLine(thing: Pmobj_t; line: Pline_t);

procedure P_CrossSpecialLine(linenum: integer; side: integer; thing: Pmobj_t);

procedure P_PlayerInSpecialSector(player: Pplayer_t);

function twoSided(sector: integer; line: integer): integer;

function getSector(currentSector: integer; line: integer; side: integer): Psector_t;

function getSide(currentSector: integer; line: integer; side: integer): Pside_t;

function P_FindLowestFloorSurrounding(sec: Psector_t): fixed_t;

function P_FindHighestFloorSurrounding(sec: Psector_t): fixed_t;

function P_FindNextHighestFloor(sec: Psector_t; currentheight: integer): fixed_t;

function P_FindLowestCeilingSurrounding(sec: Psector_t): fixed_t;

function P_FindHighestCeilingSurrounding(sec: Psector_t): fixed_t;

function P_FindSectorFromLineTag(line: Pline_t; start: integer): integer;

function P_FindMinSurroundingLight(sector: Psector_t; max: integer): integer;

function getNextSector(line: Pline_t; sec: Psector_t): Psector_t;

//
// SPECIAL
//
function EV_DoDonut(line: Pline_t): integer;

//
// P_LIGHTS
//
type
  fireflicker_t = record
    thinker: thinker_t;
    sector: Psector_t;
    count: integer;
    maxlight: integer;
    minlight: integer;
  end;
  Pfireflicker_t = ^fireflicker_t;

  lightflash_t = record
    thinker: thinker_t;
    sector: Psector_t;
    count: integer;
    maxlight: integer;
    minlight: integer;
    maxtime: integer;
    mintime: integer;
  end;
  Plightflash_t = ^lightflash_t;

  strobe_t = record
    thinker: thinker_t;
    sector: Psector_t;
    count: integer;
    minlight: integer;
    maxlight: integer;
    darktime: integer;
    brighttime: integer;
  end;
  Pstrobe_t = ^strobe_t;

  glow_t = record
    thinker: thinker_t;
    sector: Psector_t;
    minlight: integer;
    maxlight: integer;
    direction: integer;
  end;
  Pglow_t = ^glow_t;

const
  GLOWSPEED = 8;
  STROBEBRIGHT = 5;
  FASTDARK = 15;
  SLOWDARK = 35;

type
  bwhere_e = (
    top,
    middle,
    bottom
  );

  button_t = record
    line: Pline_t;
    where: bwhere_e;
    btexture: integer;
    btimer: integer;
    soundorg: Pmobj_t;
  end;
  Pbutton_t = ^button_t;

const
 // max # of wall switches in a level
  MAXSWITCHES = 50;

 // 4 players, 4 buttons each at once, max.
   MAXBUTTONS = 16;

 // 1 second, in ticks. 
   BUTTONTIME = 1000 div TICKRATE; 


type
//
// P_PLATS
//
  plat_e = (
    up,
    down,
    waiting,
    in_stasis
  );

  plattype_e = (
    perpetualRaise,
    downWaitUpStay,
    raiseAndChange,
    raiseToNearestAndChange,
    blazeDWUS
  );

  plat_t = record
    thinker: thinker_t;
    sector: Psector_t;
    speed: fixed_t;
    low: fixed_t;
    high: fixed_t;
    wait: integer;
    count: integer;
    status: plat_e;
    oldstatus: plat_e;
    crush: boolean;
    tag: integer;
    _type: plattype_e;
  end;
  Pplat_t = ^plat_t;

const
  PLATWAIT = 3;
  PLATSPEED = FRACUNIT;
  MAXPLATS = 512;  // JVAL Originally was 30

type
//
// P_DOORS
//
  vldoor_e = (
    normal,
    close30ThenOpen,
    close,
    open,
    raiseIn5Mins,
    blazeRaise,
    blazeOpen,
    blazeClose
  );

  vldoor_t = record
    thinker: thinker_t;
    _type: vldoor_e;
    sector: Psector_t;
    topheight: fixed_t;
    speed: fixed_t;

    // 1 = up, 0 = waiting at top, -1 = down
    direction: integer;

    // tics to wait at the top
    topwait: integer;
    // (keep in case a door going down is reset)
    // when it reaches 0, start going down
    topcountdown: integer;
  end;
  Pvldoor_t = ^vldoor_t;

const
  VDOORSPEED = FRACUNIT * 2;
  VDOORWAIT = 150;

type
//
// P_CEILNG
//
  ceiling_e = (
    lowerToFloor,
    raiseToHighest,
    lowerAndCrush,
    crushAndRaise,
    fastCrushAndRaise,
    silentCrushAndRaise
  );

  ceiling_t = record
    thinker: thinker_t;
    _type: ceiling_e;
    sector: Psector_t;
    bottomheight: fixed_t;
    topheight: fixed_t;
    speed: fixed_t;
    crush: boolean;
    // 1 = up, 0 = waiting, -1 = down
    direction: integer;

    // ID
    tag: integer;
    olddirection: integer;
  end;
  Pceiling_t = ^ceiling_t;

const
  CEILSPEED = FRACUNIT;
  CEILWAIT = 150;
  MAXCEILINGS = 30;

type
//
// P_FLOOR
//
  floor_e = (
    // lower floor to highest surrounding floor
    lowerFloor,

    // lower floor to lowest surrounding floor
    lowerFloorToLowest,

    // lower floor to highest surrounding floor VERY FAST
    turboLower,

    // raise floor to lowest surrounding CEILING
    raiseFloor,

    // raise floor to next highest surrounding floor
    raiseFloorToNearest,

    // raise floor to shortest height texture around it
    raiseToTexture,

    // lower floor to lowest surrounding floor
    //  and change floorpic
    lowerAndChange,

    raiseFloor24,
    raiseFloor24AndChange,
    raiseFloorCrush,

     // raise to next highest floor, turbo-speed
    raiseFloorTurbo,
    donutRaise,
    raiseFloor512
  );

  stair_e = (
    build8, // slowly build by 8
    turbo16 // quickly build by 16
  );

  floormove_t = record
    thinker: thinker_t;
    _type: floor_e;
    crush: boolean;
    sector: Psector_t;
    direction: integer;
    newspecial: integer;
    texture: smallint;
    floordestheight: fixed_t;
    speed: fixed_t;
  end;
  Pfloormove_t = ^floormove_t;

const
  FLOORSPEED = FRACUNIT;

type
  result_e = (
    ok,
    crushed,
    pastdest
  );

implementation

uses
  d_fpc,
  doomdef,
  doomstat,
  doomdata,
  d_english,
  i_system,
  i_io,
  z_memory,
  m_argv,
  m_rnd,
  w_wad,
  r_data,
  info_h,
  g_game,
  p_setup,
  p_inter,
  p_switch,
  p_ceilng,
  p_plats,
  p_lights,
  p_doors,
  p_floor,
  p_telept,
  s_sound,
// Data.
  sounds;

//
// Animating textures and planes
// There is another anim_t used in wi_stuff, unrelated.
//
type
  anim_t = record
    istexture: boolean;
    picnum: integer;
    basepic: integer;
    numpics: integer;
    speed: integer;
  end;
  Panim_t = ^anim_t;

//
//      source animation definition
//
  animdef_t = record
    istexture: boolean; // if false, it is a flat
    endname: string[8];
    startname: string[8];
    speed: integer;
  end;
  Panimdef_t = ^animdef_t;

const
  MAXANIMS = 32;
  NUMANIMDEFS = 22;

//
// P_InitPicAnims
//

// Floor/ceiling animation sequences,
//  defined by first and last frame,
//  i.e. the flat (64x64 tile) name to
//  be used.
// The full animation sequence is given
//  using all the flats between the start
//  and end entry, in the order found in
//  the WAD file.
//
  animdefs: array[0..NUMANIMDEFS] of animdef_t = (
    (istexture: false; endname: 'NUKAGE3';  startname: 'NUKAGE1';  speed: 8),
    (istexture: false; endname: 'FWATER4';  startname: 'FWATER1';  speed: 8),
    (istexture: false; endname: 'SWATER4';  startname: 'SWATER1';  speed: 8),
    (istexture: false; endname: 'LAVA4';    startname: 'LAVA1';    speed: 8),
    (istexture: false; endname: 'BLOOD3';   startname: 'BLOOD1';   speed: 8),

    // DOOM II flat animations.
    (istexture: false; endname: 'RROCK08';  startname: 'RROCK05';  speed: 8),
    (istexture: false; endname: 'SLIME04';  startname: 'SLIME01';  speed: 8),
    (istexture: false; endname: 'SLIME08';  startname: 'SLIME05';  speed: 8),
    (istexture: false; endname: 'SLIME12';  startname: 'SLIME09';  speed: 8),

    (istexture: true;  endname: 'BLODGR4';  startname: 'BLODGR1';  speed: 8),
    (istexture: true;  endname: 'SLADRIP3'; startname: 'SLADRIP1'; speed: 8),

    (istexture: true;  endname: 'BLODRIP4'; startname: 'BLODRIP1'; speed: 8),
    (istexture: true;  endname: 'FIREWALL'; startname: 'FIREWALA'; speed: 8),
    (istexture: true;  endname: 'GSTFONT3'; startname: 'GSTFONT1'; speed: 8),
    (istexture: true;  endname: 'FIRELAVA'; startname: 'FIRELAV3'; speed: 8),
    (istexture: true;  endname: 'FIREMAG3'; startname: 'FIREMAG1'; speed: 8),
    (istexture: true;  endname: 'FIREBLU2'; startname: 'FIREBLU1'; speed: 8),
    (istexture: true;  endname: 'ROCKRED3'; startname: 'ROCKRED1'; speed: 8),

    (istexture: true;  endname: 'BFALL4';   startname: 'BFALL1';   speed: 8),
    (istexture: true;  endname: 'SFALL4';   startname: 'SFALL1';   speed: 8),
    (istexture: true;  endname: 'WFALL4';   startname: 'WFALL1';   speed: 8),
    (istexture: true;  endname: 'DBRAIN4';  startname: 'DBRAIN1';  speed: 8),

    (istexture: false; endname: '';         startname: '';         speed: 0)
  );

var
  anims: array[0..MAXANIMS - 1] of anim_t;
  lastanim: integer;

const
//
//      Animating line specials
//
  MAXLINEANIMS = 1024; // JVAL Originally was 64

procedure P_InitPicAnims;
var
  i, j: integer;
begin
  //  Init animation
  lastanim := 0;
  i := 0;
  while animdefs[i].speed <> 0 do
  begin
    if animdefs[i].istexture then
    begin
      // different episode ?
      if R_CheckTextureNumForName(animdefs[i].startname) = -1 then
      begin
        inc(i);
        continue;
      end;

      anims[lastanim].picnum := R_TextureNumForName(animdefs[i].endname);
      anims[lastanim].basepic := R_TextureNumForName(animdefs[i].startname);
      anims[lastanim].istexture := true;
      anims[lastanim].numpics := anims[lastanim].picnum - anims[lastanim].basepic + 1;
    end
    else
    begin
      if W_CheckNumForName(animdefs[i].startname) = -1 then
      begin
        inc(i);
        continue;
      end;

      anims[lastanim].picnum := R_FlatNumForName(animdefs[i].endname);
      anims[lastanim].basepic := R_FlatNumForName(animdefs[i].startname);
      anims[lastanim].istexture := false;
      anims[lastanim].numpics := flats[anims[lastanim].picnum].lump - flats[anims[lastanim].basepic].lump + 1;
      // JVAL
      // Create new flats as nessesary
      for j := anims[lastanim].basepic to anims[lastanim].basepic + anims[lastanim].numpics - 1 do
        R_FlatNumForName(W_GetNameForNum(j));
    end;

    if anims[lastanim].numpics < 2 then
      I_Error('P_InitPicAnims(): bad cycle from %s to %s',
        [animdefs[i].startname, animdefs[i].endname]);

    anims[lastanim].speed := animdefs[i].speed;
    inc(lastanim);
    inc(i);
  end;
end;

//
// UTILITIES
//



//
// getSide()
// Will return a side_t*
//  given the number of the current sector,
//  the line number, and the side (0/1) that you want.
//
function getSide(currentSector: integer; line: integer; side: integer): Pside_t;
begin
  result := @sides[(sectors[currentSector].lines[line]).sidenum[side]];
end;

//
// getSector()
// Will return a sector_t*
//  given the number of the current sector,
//  the line number and the side (0/1) that you want.
//
function getSector(currentSector: integer; line: integer; side: integer): Psector_t;
begin
  result := sides[(sectors[currentSector].lines[line]).sidenum[side]].sector;
end;

//
// twoSided()
// Given the sector number and the line number,
//  it will tell you whether the line is two-sided or not.
//
function twoSided(sector: integer; line: integer): integer;
begin
  result := (sectors[sector].lines[line]).flags and ML_TWOSIDED;
end;

//
// getNextSector()
// Return sector_t * of sector next to current.
// NULL if not two-sided line
//
function getNextSector(line: Pline_t; sec: Psector_t): Psector_t;
begin
  if (line.flags and ML_TWOSIDED) = 0 then
    result := nil
  else
  begin
    if line.frontsector = sec then
      result := line.backsector
    else
      result := line.frontsector;
  end;
end;

//
// P_FindLowestFloorSurrounding()
// FIND LOWEST FLOOR HEIGHT IN SURROUNDING SECTORS
//
function P_FindLowestFloorSurrounding(sec: Psector_t): fixed_t;
var
  i: integer;
  check: Pline_t;
  other: Psector_t;
begin
  result := sec.floorheight;

  for i := 0 to sec.linecount - 1 do
  begin
    check := sec.lines[i];
    other := getNextSector(check, sec);

    if other <> nil then
      if other.floorheight < result then
        result := other.floorheight;
  end;
end;

//
// P_FindHighestFloorSurrounding()
// FIND HIGHEST FLOOR HEIGHT IN SURROUNDING SECTORS
//
function P_FindHighestFloorSurrounding(sec: Psector_t): fixed_t;
var
  i: integer;
  check: Pline_t;
  other: Psector_t;
begin
  result := -500 * FRACUNIT;

  for i := 0 to sec.linecount - 1 do
  begin
    check := sec.lines[i];
    other := getNextSector(check, sec);

    if other <> nil then
      if other.floorheight > result then
        result := other.floorheight;
  end;
end;

//
// P_FindNextHighestFloor
// FIND NEXT HIGHEST FLOOR IN SURROUNDING SECTORS
// Note: this should be doable w/o a fixed array.

// 20 adjoining sectors max!  // JVAL changed to 64
const
  MAX_ADJOINING_SECTORS = 64; // JVAL was = 20

function P_FindNextHighestFloor(sec: Psector_t; currentheight: integer): fixed_t;
var
  i: integer;
  h: integer;
  check: Pline_t;
  other: Psector_t;
  height: fixed_t;
  heightlist: array[0..MAX_ADJOINING_SECTORS] of fixed_t;
  maxsecs: integer;
begin
  if G_NeedsCompatibilityMode then
    maxsecs := 20
  else
    maxsecs := MAX_ADJOINING_SECTORS;
  height := currentheight;

  h := 0;
  for i := 0 to sec.linecount - 1 do
  begin
    check := sec.lines[i];
    other := getNextSector(check, sec);

    if other <> nil then
    begin
      if other.floorheight > height then
      begin
        heightlist[h] := other.floorheight;
        inc(h);
      end;

      // Check for overflow. Exit.
      if h >= maxsecs then
      begin
        I_Warning('P_FindNextHighestFloor(): Sector with more than %d adjoining sectors.'#13#10, [maxsecs]);
        break;
      end;
    end;
  end;

  // Find lowest height in list
  if h = 0 then
  begin
    result := currentheight;
    exit;
  end;

  result := heightlist[0];

  // Range checking?
  for i := 1 to h - 1 do
    if heightlist[i] < result then
      result := heightlist[i];
end;

//
// P_FindNextLowestFloor()
//
// Passed a sector and a floor height, returns the fixed point value
// of the largest floor height in a surrounding sector smaller than
// the floor height passed. If no such height exists the floorheight
// passed is returned.
//
// jff 02/03/98 Twiddled Lee's P_FindNextHighestFloor to make this
//
// JVAL BOOM compatibility
//
function P_FindNextLowestFloor(sec: Psector_t; currentheight: fixed_t): fixed_t;
var
  other: Psector_t;
  i: integer;
begin
  i := 0;
  while i < sec.linecount - 1 do
  begin
    other := getNextSector(sec.lines[i], sec);
    if (other <> nil) and (other.floorheight < currentheight) then
    begin
      result := other.floorheight;
      inc(i);
      while i < sec.linecount do
      begin
        other := getNextSector(sec.lines[i], sec);
        if other <> nil then
          if (other.floorheight > result) and (other.floorheight < currentheight) then
            result := other.floorheight;
        inc(i);
      end;
      exit;
    end;
    inc(i);
  end;
  result := currentheight;
end;

//
// P_FindNextLowestCeiling()
//
// Passed a sector and a ceiling height, returns the fixed point value
// of the largest ceiling height in a surrounding sector smaller than
// the ceiling height passed. If no such height exists the ceiling height
// passed is returned.
//
// jff 02/03/98 Twiddled Lee's P_FindNextHighestFloor to make this
//
// JVAL BOOM compatibility
//
function P_FindNextLowestCeiling(sec: Psector_t; currentheight: fixed_t): fixed_t;
var
  other: Psector_t;
  i: integer;
begin
  i := 0;
  while i < sec.linecount - 1 do
  begin
    other := getNextSector(sec.lines[i], sec);
    if (other <> nil) and (other.ceilingheight < currentheight) then
    begin
      result := other.ceilingheight;
      inc(i);
      while i < sec.linecount do
      begin
        other := getNextSector(sec.lines[i], sec);
        if other <> nil then
          if (other.ceilingheight > result) and (other.ceilingheight < currentheight) then
            result := other.ceilingheight;
        inc(i);
      end;
      exit;
    end;
    inc(i);
  end;
  result := currentheight;
end;

//
// P_FindNextHighestCeiling()
//
// Passed a sector and a ceiling height, returns the fixed point value
// of the smallest ceiling height in a surrounding sector larger than
// the ceiling height passed. If no such height exists the ceiling height
// passed is returned.
//
// jff 02/03/98 Twiddled Lee's P_FindNextHighestFloor to make this
//
// JVAL BOOM compatibility
//
function P_FindNextHighestCeiling(sec: Psector_t; currentheight: fixed_t): fixed_t;
var
  other: Psector_t;
  i: integer;
begin
  i := 0;
  while i < sec.linecount - 1 do
  begin
    other := getNextSector(sec.lines[i], sec);
    if (other <> nil) and (other.ceilingheight > currentheight) then
    begin
      result := other.ceilingheight;
      inc(i);
      while i < sec.linecount do
      begin
        other := getNextSector(sec.lines[i], sec);
        if other <> nil then
          if (other.ceilingheight < result) and (other.ceilingheight > currentheight) then
            result := other.ceilingheight;
        inc(i);
      end;
      exit;
    end;
    inc(i);
  end;
  result := currentheight;
end;

//
// FIND LOWEST CEILING IN THE SURROUNDING SECTORS
//
function P_FindLowestCeilingSurrounding(sec: Psector_t): fixed_t;
var
  i: integer;
  check: Pline_t;
  other: Psector_t;
begin
  result := MAXINT;

  for i := 0 to sec.linecount - 1 do
  begin
    check := sec.lines[i];
    other := getNextSector(check, sec);

    if other <> nil then
      if other.ceilingheight < result then
        result := other.ceilingheight;
  end;
end;

//
// FIND HIGHEST CEILING IN THE SURROUNDING SECTORS
//
function P_FindHighestCeilingSurrounding(sec: Psector_t): fixed_t;
var
  i: integer;
  check: Pline_t;
  other: Psector_t;
begin
  result := 0;

  for i := 0 to sec.linecount - 1 do
  begin
    check := sec.lines[i];
    other := getNextSector(check, sec);

    if other <> nil then
      if other.ceilingheight > result then
        result := other.ceilingheight;
  end;
end;

//
// P_FindShortestTextureAround()
//
// Passed a sector number, returns the shortest lower texture on a
// linedef bounding the sector.
//
// Note: If no lower texture exists 32000*FRACUNIT is returned.
//       but if compatibility then MAXINT is returned
//
// jff 02/03/98 Add routine to find shortest lower texture
//
// JVAL BOOM compatibility
//
function P_FindShortestTextureAround(secnum: integer): fixed_t;
var
  side: Pside_t;
  i: integer;
  sec: Psector_t;
begin
  sec := @sectors[secnum];

  result := 32000 * FRACUNIT; //jff 3/13/98 prevent overflow in height calcs

  for i := 0 to sec.linecount - 1 do
    if twoSided(secnum, i) <> 0 then
    begin
      side := getSide(secnum, i, 0);
      if side.bottomtexture > 0 then  //jff 8/14/98 texture 0 is a placeholder
        if textureheight[side.bottomtexture] < result then
          result := textureheight[side.bottomtexture];
      side := getSide(secnum, i, 1);
      if side.bottomtexture > 0 then  //jff 8/14/98 texture 0 is a placeholder
        if textureheight[side.bottomtexture] < result then
          result := textureheight[side.bottomtexture];
    end;

end;


//
// P_FindShortestUpperAround()
//
// Passed a sector number, returns the shortest upper texture on a
// linedef bounding the sector.
//
// Note: If no upper texture exists 32000*FRACUNIT is returned.
//       but if compatibility then MAXINT is returned
//
// jff 03/20/98 Add routine to find shortest upper texture
//
// JVAL BOOM compatibility
//
function P_FindShortestUpperAround(secnum: integer): fixed_t;
var
  side: Pside_t;
  i: integer;
  sec: Psector_t;
begin
  sec := @sectors[secnum];

  result := 32000 * FRACUNIT; //jff 3/13/98 prevent overflow in height calcs

  for i := 0 to sec.linecount - 1 do
    if twoSided(secnum, i) <> 0 then
    begin
      side := getSide(secnum, i, 0);
      if side.toptexture > 0 then  //jff 8/14/98 texture 0 is a placeholder
        if textureheight[side.toptexture] < result then
          result := textureheight[side.toptexture];
      side := getSide(secnum, i, 1);
      if side.toptexture > 0 then  //jff 8/14/98 texture 0 is a placeholder
        if textureheight[side.toptexture] < result then
          result := textureheight[side.toptexture];
    end;

end;

//
// P_FindModelFloorSector()
//
// Passed a floor height and a sector number, return a pointer to a
// a sector with that floor height across the lowest numbered two sided
// line surrounding the sector.
//
// Note: If no sector at that height bounds the sector passed, return NULL
//
// jff 02/03/98 Add routine to find numeric model floor
//  around a sector specified by sector number
// jff 3/14/98 change first parameter to plain height to allow call
//  from routine not using floormove_t
//
// JVAL BOOM compatibility
//
function P_FindModelFloorSector(floordestheight: fixed_t; secnum: integer): Psector_t;
var
  i: integer;
  linecount: integer;

  function _getLcount(const sec: Psector_t): integer;
  begin
    if sec.linecount < linecount then
      result := sec.linecount
    else
      result := linecount;
  end;

begin
  result := @sectors[secnum]; //jff 3/2/98 woops! better do this
  //jff 5/23/98 don't disturb sec->linecount while searching
  // but allow early exit in old demos
  linecount := result.linecount;
  i := 0;
  while i < _getLcount(result) do
  begin
    if twoSided(secnum, i) <> 0 then
    begin
      if pDiff(getSide(secnum, i, 0).sector, sectors, SizeOf(sector_t)) = secnum then
        result := getSector(secnum, i, 1)
      else
        result := getSector(secnum, i, 0);

      if result.floorheight = floordestheight then
        exit;
    end;
  end;
  result := nil;
end;

//
// P_FindModelCeilingSector()
//
// Passed a ceiling height and a sector number, return a pointer to a
// a sector with that ceiling height across the lowest numbered two sided
// line surrounding the sector.
//
// Note: If no sector at that height bounds the sector passed, return NULL
//
// jff 02/03/98 Add routine to find numeric model ceiling
//  around a sector specified by sector number
//  used only from generalized ceiling types
// jff 3/14/98 change first parameter to plain height to allow call
//  from routine not using ceiling_t
//
// JVAL BOOM compatibility
//
function P_FindModelCeilingSector(ceildestheight: fixed_t; secnum: integer): Psector_t;
var
  i: integer;
  linecount: integer;

  function _getLcount(const sec: Psector_t): integer;
  begin
    if sec.linecount < linecount then
      result := sec.linecount
    else
      result := linecount;
  end;

begin
  result := @sectors[secnum]; //jff 3/2/98 woops! better do this
  //jff 5/23/98 don't disturb sec->linecount while searching
  // but allow early exit in old demos
  linecount := result.linecount;
  i := 0;
  while i < _getLcount(result) do
  begin
    if twoSided(secnum, i) <> 0 then
    begin
      if pDiff(getSide(secnum, i, 0).sector, sectors, SizeOf(sector_t)) = secnum then
        result := getSector(secnum, i, 1)
      else
        result := getSector(secnum, i, 0);

      if result.ceilingheight = ceildestheight then
        exit;
    end;
  end;
  result := nil;
end;

//
// RETURN NEXT SECTOR # THAT LINE TAG REFERS TO
//
function P_FindSectorFromLineTag(line: Pline_t; start: integer): integer;
var
  i: integer;
begin
  for i := start + 1 to numsectors - 1 do
    if sectors[i].tag = line.tag then
    begin
      result := i;
      exit;
    end;

  result := -1;
end;

//
// killough 4/16/98: Same thing, only for linedefs
//
// JVAL BOOM compatibility
//
function P_FindLineFromLineTag(line: Pline_t; start: integer): integer;
var
  i: integer;
begin
  for i := start + 1 to numlines - 1 do
    if lines[i].tag = line.tag then
    begin
      result := i;
      exit;
    end;

  result := -1;
end;

//
// Find minimum light from an adjacent sector
//
function P_FindMinSurroundingLight(sector: Psector_t; max: integer): integer;
var
  i: integer;
  line: Pline_t;
  check: Psector_t;
begin
  result := max;
  for i := 0 to sector.linecount - 1 do
  begin
    line := sector.lines[i];
    check := getNextSector(line, sector);

    if check <> nil then
      if check.lightlevel < result then
        result := check.lightlevel;
  end;
end;

//
// EVENTS
// Events are operations triggered by using, crossing,
// or shooting special lines, or by timed thinkers.
//

//
// P_CrossSpecialLine - TRIGGER
// Called every time a thing origin is about
//  to cross a line with a non 0 special.
//
procedure P_CrossSpecialLine(linenum: integer; side: integer; thing: Pmobj_t);
var
  line: Pline_t;
begin
  line := @lines[linenum];

  //  Triggers that other things can activate
  if thing.player = nil then
  begin
    // Things that should NOT trigger specials...
    case thing._type of
      Ord(MT_ROCKET),
      Ord(MT_PLASMA),
      Ord(MT_BFG),
      Ord(MT_TROOPSHOT),
      Ord(MT_HEADSHOT),
      Ord(MT_BRUISERSHOT):
        exit;
    end;

    case line.special of
      39, // TELEPORT TRIGGER
      97, // TELEPORT RETRIGGER
     125, // TELEPORT MONSTERONLY TRIGGER
     126, // TELEPORT MONSTERONLY RETRIGGER
       4, // RAISE DOOR
      10, // PLAT DOWN-WAIT-UP-STAY TRIGGER
      88: // PLAT DOWN-WAIT-UP-STAY RETRIGGER
        ;
      else
        exit;
    end;
  end;


  // Note: could use some const's here.
  case line.special of
  // TRIGGERS.
  // All from here to RETRIGGERS.
     2:
      begin
        // Open Door
        EV_DoDoor(line, open);
        line.special := 0;
      end;

     3:
      begin
        // Close Door
        EV_DoDoor(line, close);
        line.special := 0;
      end;

     4:
      begin
        // Raise Door
        EV_DoDoor(line, normal);
        line.special := 0;
      end;

     5:
      begin
        // Raise Floor
        EV_DoFloor(line, raiseFloor);
        line.special := 0;
      end;

     6:
      begin
        // Fast Ceiling Crush & Raise
        EV_DoCeiling(line, fastCrushAndRaise);
        line.special := 0;
      end;

     8:
      begin
        // Build Stairs
        EV_BuildStairs(line, build8);
        line.special := 0;
      end;

    10:
      begin
        // PlatDownWaitUp
        EV_DoPlat(line, downWaitUpStay, 0);
        line.special := 0;
      end;

    12:
      begin
        // Light Turn On - brightest near
        EV_LightTurnOn(line, 0);
        line.special := 0;
      end;

    13:
      begin
        // Light Turn On 255
        EV_LightTurnOn(line, 255);
        line.special := 0;
      end;

    16:
      begin
        // Close Door 30
        EV_DoDoor(line, close30ThenOpen);
        line.special := 0;
      end;

    17:
      begin
        // Start Light Strobing
        EV_StartLightStrobing(line);
        line.special := 0;
      end;

    19:
      begin
        // Lower Floor
        EV_DoFloor(line, lowerFloor);
        line.special := 0;
      end;

    22:
      begin
        // Raise floor to nearest height and change texture
        EV_DoPlat(line, raiseToNearestAndChange, 0);
        line.special := 0;
      end;

    25:
      begin
        // Ceiling Crush and Raise
        EV_DoCeiling(line, crushAndRaise);
        line.special := 0;
      end;
  
    30:
      begin
        // Raise floor to shortest texture height
        //  on either side of lines.
        EV_DoFloor(line, raiseToTexture);
        line.special := 0;
      end;

    35:
      begin
        // Lights Very Dark
        EV_LightTurnOn(line, 35);
        line.special := 0;
      end;

    36:
      begin
        // Lower Floor (TURBO)
        EV_DoFloor(line, turboLower);
        line.special := 0;
      end;

    37:
      begin
        // LowerAndChange
        EV_DoFloor(line, lowerAndChange);
        line.special := 0;
      end;

    38:
      begin
        // Lower Floor To Lowest
        EV_DoFloor(line, lowerFloorToLowest);
        line.special := 0;
      end;

    39:
      begin
        // TELEPORT!
        EV_Teleport(line, side, thing );
        line.special := 0;
      end;

    40:
      begin
        // RaiseCeilingLowerFloor
        EV_DoCeiling(line, raiseToHighest);
        EV_DoFloor(line, lowerFloorToLowest);
        line.special := 0;
      end;

    44:
      begin
        // Ceiling Crush
        EV_DoCeiling(line, lowerAndCrush);
        line.special := 0;
      end;

    52:
      begin
        // EXIT!
        G_ExitLevel;
      end;

    53:
      begin
        // Perpetual Platform Raise
        EV_DoPlat(line, perpetualRaise, 0);
        line.special := 0;
      end;

    54:
      begin
        // Platform Stop
        EV_StopPlat(line);
        line.special := 0;
      end;

    56:
      begin
        // Raise Floor Crush
        EV_DoFloor(line, raiseFloorCrush);
        line.special := 0;
      end;

    57:
      begin
        // Ceiling Crush Stop
        EV_CeilingCrushStop(line);
        line.special := 0;
      end;

    58:
      begin
        // Raise Floor 24
        EV_DoFloor(line, raiseFloor24);
        line.special := 0;
      end;

    59:
      begin
        // Raise Floor 24 And Change
        EV_DoFloor(line, raiseFloor24AndChange);
        line.special := 0;
      end;

   104:
      begin
        // Turn lights off in sector(tag)
        EV_TurnTagLightsOff(line);
        line.special := 0;
      end;

   108:
      begin
        // Blazing Door Raise (faster than TURBO!)
        EV_DoDoor(line, blazeRaise);
        line.special := 0;
      end;

   109:
      begin
        // Blazing Door Open (faster than TURBO!)
        EV_DoDoor(line, blazeOpen);
        line.special := 0;
      end;

   100:
      begin
        // Build Stairs Turbo 16
        EV_BuildStairs(line, turbo16);
        line.special := 0;
      end;

   110:
      begin
        // Blazing Door Close (faster than TURBO!)
        EV_DoDoor(line, blazeClose);
        line.special := 0;
      end;

   119:
      begin
        // Raise floor to nearest surr. floor
        EV_DoFloor(line, raiseFloorToNearest);
        line.special := 0;
      end;

   121:
      begin
        // Blazing PlatDownWaitUpStay
        EV_DoPlat(line, blazeDWUS, 0);
        line.special := 0;
      end;

   124:
      begin
        // Secret EXIT
        G_SecretExitLevel;
      end;

   125:
      begin
        // TELEPORT MonsterONLY
        if thing.player = nil then
        begin
          EV_Teleport(line, side, thing);
          line.special := 0;
        end;
      end;

   130:
      begin
        // Raise Floor Turbo
        EV_DoFloor(line, raiseFloorTurbo);
        line.special := 0;
      end;

   141:
      begin
        // Silent Ceiling Crush & Raise
        EV_DoCeiling(line, silentCrushAndRaise);
        line.special := 0;
      end;
  
  // RETRIGGERS.  All from here till end.
    72:
      begin
        // Ceiling Crush
        EV_DoCeiling(line, lowerAndCrush);
      end;

    73:
      begin
        // Ceiling Crush and Raise
        EV_DoCeiling(line, crushAndRaise);
      end;

    74:
      begin
        // Ceiling Crush Stop
        EV_CeilingCrushStop(line);
      end;

    75:
      begin
        // Close Door
        EV_DoDoor(line, close);
      end;

    76:
      begin
        // Close Door 30
        EV_DoDoor(line, close30ThenOpen);
      end;

    77:
      begin
        // Fast Ceiling Crush & Raise
        EV_DoCeiling(line, fastCrushAndRaise);
      end;

    79:
      begin
        // Lights Very Dark
        EV_LightTurnOn(line, 35);
      end;

    80:
      begin
        // Light Turn On - brightest near
        EV_LightTurnOn(line, 0);
      end;

    81:
      begin
        // Light Turn On 255
        EV_LightTurnOn(line, 255);
      end;

    82:
      begin
        // Lower Floor To Lowest
        EV_DoFloor(line, lowerFloorToLowest);
      end;

    83:
      begin
        // Lower Floor
        EV_DoFloor(line, lowerFloor);
      end;

    84:
      begin
        // LowerAndChange
        EV_DoFloor(line, lowerAndChange);
      end;

    86:
      begin
        // Open Door
        EV_DoDoor(line, open);
      end;

    87:
      begin
        // Perpetual Platform Raise
        EV_DoPlat(line, perpetualRaise, 0);
      end;

    88:
      begin
        // PlatDownWaitUp
        EV_DoPlat(line, downWaitUpStay, 0);
      end;

    89:
      begin
        // Platform Stop
        EV_StopPlat(line);
      end;
  
    90:
      begin
        // Raise Door
        EV_DoDoor(line, normal);
      end;

    91:
      begin
        // Raise Floor
        EV_DoFloor(line, raiseFloor);
      end;

    92:
      begin
        // Raise Floor 24
        EV_DoFloor(line, raiseFloor24);
      end;

    93:
      begin
        // Raise Floor 24 And Change
        EV_DoFloor(line, raiseFloor24AndChange);
      end;
  
    94:
      begin
        // Raise Floor Crush
        EV_DoFloor(line, raiseFloorCrush);
      end;

    95:
      begin
        // Raise floor to nearest height
        // and change texture.
        EV_DoPlat(line, raiseToNearestAndChange, 0);
      end;

    96:
      begin
        // Raise floor to shortest texture height
        // on either side of lines.
        EV_DoFloor(line, raiseToTexture);
      end;

    97:
      begin
        // TELEPORT!
        EV_Teleport(line, side, thing);
      end;

    98:
      begin
        // Lower Floor (TURBO)
        EV_DoFloor(line, turboLower);
      end;

   105:
      begin
        // Blazing Door Raise (faster than TURBO!)
        EV_DoDoor(line, blazeRaise);
      end;
  
   106:
      begin
        // Blazing Door Open (faster than TURBO!)
        EV_DoDoor(line, blazeOpen);
      end;

   107:
      begin
        // Blazing Door Close (faster than TURBO!)
        EV_DoDoor(line, blazeClose);
      end;

   120:
      begin
        // Blazing PlatDownWaitUpStay.
        EV_DoPlat(line, blazeDWUS, 0);
      end;

   126:
      begin
        // TELEPORT MonsterONLY.
        if thing.player = nil then
          EV_Teleport(line, side, thing);
      end;

   128:
      begin
        // Raise To Nearest Floor
        EV_DoFloor(line, raiseFloorToNearest);
      end;

   129:
      begin
        // Raise Floor Turbo
        EV_DoFloor(line, raiseFloorTurbo);
      end;
  end;
end;

//
// P_ShootSpecialLine - IMPACT SPECIALS
// Called when a thing shoots a special line.
//
procedure P_ShootSpecialLine(thing: Pmobj_t; line: Pline_t);
begin
  //  Impacts that other things can activate.
  if thing.player = nil then
    case line.special of
      46: ; // OPEN DOOR IMPACT
    else
      exit;
    end;

  case line.special of
    24:
      begin
        // RAISE FLOOR
        EV_DoFloor(line, raiseFloor);
        P_ChangeSwitchTexture(line, false);
      end;

    46:
      begin
        // OPEN DOOR
        EV_DoDoor(line, open);
        P_ChangeSwitchTexture(line, true);
      end;

    47:
      begin
        // RAISE FLOOR NEAR AND CHANGE
        EV_DoPlat(line, raiseToNearestAndChange, 0);
        P_ChangeSwitchTexture(line, false);
      end;
  end;
end;

//
// P_PlayerInSpecialSector
// Called every tic frame
//  that the player origin is in a special sector
//
procedure P_PlayerInSpecialSector(player: Pplayer_t);
var
  sector: Psector_t;
begin
  sector := Psubsector_t(player.mo.subsector).sector;

  // Falling, not all the way down yet?
  if player.mo.z <> sector.floorheight then
    exit;

  // Has hitten ground.
  case sector.special of
     5:
      begin
        // HELLSLIME DAMAGE
        if player.powers[Ord(pw_ironfeet)] = 0 then
          if leveltime and $1f = 0 then
            P_DamageMobj(player.mo, nil, nil, 10);
      end;

     7:
      begin
        // NUKAGE DAMAGE
        if player.powers[Ord(pw_ironfeet)] = 0 then
          if leveltime and $1f = 0 then
            P_DamageMobj(player.mo, nil, nil, 5);
      end;

    16, // SUPER HELLSLIME DAMAGE
     4: // STROBE HURT
      begin
        if (player.powers[Ord(pw_ironfeet)] = 0) or
           (P_Random < 5) then
          if leveltime and $1f = 0 then
            P_DamageMobj(player.mo, nil, nil, 20);
      end;

     9:
      begin
        // SECRET SECTOR
        player.secretcount := player.secretcount + 1;
        player._message := MSGSECRETSECTOR;
        sector.special := 0;
      end;

    11:
      begin
        // EXIT SUPER DAMAGE! (for E1M8 finale)
        player.cheats := player.cheats and (not CF_GODMODE);

        if leveltime and $1f = 0 then
          P_DamageMobj(player.mo, nil, nil, 20);

        if player.health <= 10 then
          G_ExitLevel;
      end;

  else
    I_Error('P_PlayerInSpecialSector(): unknown special %d', [sector.special]);
  end;
end;

var
  numlinespecials: smallint;
  linespeciallist: array[0..MAXLINEANIMS - 1] of Pline_t;


//
// P_UpdateSpecials
// Animate planes, scroll walls, etc.
//
var
  levelTimer: boolean;
  levelTimeCount: integer;

procedure P_UpdateSpecials;
var
  anim: Panim_t;
  pic: integer;
  i: integer;
  j: integer;
  line: Pline_t;
  button: Pbutton_t;
begin
  // LEVEL TIMER
  if levelTimer then
  begin
    dec(levelTimeCount);
    if levelTimeCount = 0 then
      G_ExitLevel;
  end;

  // ANIMATE FLATS AND TEXTURES GLOBALLY
  for j := 0 to lastanim - 1 do
  begin
    anim := @anims[j];
    for i := anim.basepic to anim.basepic + anim.numpics - 1 do
    begin
      pic := anim.basepic + ((leveltime div anim.speed + i) mod anim.numpics);
      if anim.istexture then
        texturetranslation[i] := pic
      else
        flats[i].translation := pic;
    end;
  end;

  // ANIMATE LINE SPECIALS
  for i := 0 to numlinespecials - 1 do
  begin
    line := linespeciallist[i];
    case line.special of
      48: inc(sides[line.sidenum[0]].textureoffset, FRACUNIT);
    // JVAL
    // Added new line specials for scrolling
     142: dec(sides[line.sidenum[0]].textureoffset, FRACUNIT);
     143: inc(sides[line.sidenum[0]].rowoffset, FRACUNIT);
     144: dec(sides[line.sidenum[0]].rowoffset, FRACUNIT);
     145: inc(sides[line.sidenum[0]].textureoffset, 2 * FRACUNIT);
     146: dec(sides[line.sidenum[0]].textureoffset, 2 * FRACUNIT);
     147: inc(sides[line.sidenum[0]].rowoffset, 2 * FRACUNIT);
     148: dec(sides[line.sidenum[0]].rowoffset, 2 * FRACUNIT);
    end;
  end;


  // DO BUTTONS
  button := @buttonlist[0];
  for i := 0 to MAXBUTTONS - 1 do
  begin
    if button.btimer <> 0 then
    begin
      button.btimer := buttonlist[i].btimer - 1;

      if button.btimer = 0 then
      begin
        case button.where of
          top:
            sides[button.line.sidenum[0]].toptexture := button.btexture;

          middle:
            sides[button.line.sidenum[0]].midtexture := button.btexture;

          bottom:
            sides[button.line.sidenum[0]].bottomtexture := button.btexture;
        end;
        S_StartSound(Pmobj_t(@button.soundorg), Ord(sfx_swtchn));
        ZeroMemory(button, SizeOf(button_t));
      end;

    end;
    inc(button);
  end;
end;

//
// Special Stuff that can not be categorized
//
function EV_DoDonut(line: Pline_t): integer;
var
  s1: Psector_t;
  s2: Psector_t;
  s3: Psector_t;
  secnum: integer;
  i: integer;
  floor: Pfloormove_t;
begin
  result := 0;
  secnum := P_FindSectorFromLineTag(line, -1);
  while secnum >= 0 do
  begin
    s1 := @sectors[secnum];
    secnum := P_FindSectorFromLineTag(line, secnum);

    // ALREADY MOVING?  IF SO, KEEP GOING...
    if s1.specialdata <> nil then
      continue;

    result := 1;
    s2 := getNextSector(s1.lines[0], s1);
    for i := 0 to s2.linecount - 1 do
    begin
      if (s2.lines[i].flags and ML_TWOSIDED = 0) or
         (s2.lines[i].backsector = s1) then
        continue;
      s3 := s2.lines[i].backsector;

      //  Spawn rising slime
      floor := Z_Malloc(SizeOf(floormove_t), PU_LEVSPEC, nil);
      P_AddThinker(@floor.thinker);
      s2.specialdata := floor;
      floor.thinker._function.acp1 := @T_MoveFloor;
      floor._type := donutRaise;
      floor.crush := false;
      floor.direction := 1;
      floor.sector := s2;
      floor.speed := FLOORSPEED div 2;
      floor.texture := s3.floorpic;
      floor.newspecial := 0;
      floor.floordestheight := s3.floorheight;

      //  Spawn lowering donut-hole
      floor := Z_Malloc(SizeOf(floormove_t), PU_LEVSPEC, nil);
      P_AddThinker(@floor.thinker);
      s1.specialdata := floor;
      floor.thinker._function.acp1 := @T_MoveFloor;
      floor._type := lowerFloor;
      floor.crush := false;
      floor.direction := -1;
      floor.sector := s1;
      floor.speed := FLOORSPEED div 2;
      floor.floordestheight := s3.floorheight;
      break;
    end;
  end;
end;

//
// SPECIAL SPAWNING
//

//
// P_SpawnSpecials
// After the map has been loaded, scan for specials
//  that spawn thinkers
//
// Parses command line parameters.
procedure P_SpawnSpecials;
var
  sector: Psector_t;
  i: integer;
  time: integer;
begin
  if W_CheckNumForName('texture2') < 0 then
    gameepisode := 1; // ???


  // See if -TIMER needs to be used.
  levelTimer := false;

  i := M_CheckParm('-avg');
  if (i <> 0) and (deathmatch <> 0) then
  begin
    levelTimer := true;
    levelTimeCount := 20 * 60 * TICKRATE;
  end;

  i := M_CheckParm('-timer');
  if (i <> 0) and (deathmatch <> 0) then
  begin
    time := atoi(myargv[i + 1]) * 60 * TICKRATE;
    levelTimer := true;
    levelTimeCount := time;
  end;

  //  Init special SECTORs.
  sector := @sectors[0];
  dec(sector);
  for i := 0 to numsectors - 1 do
  begin
    inc(sector);
    if sector.special = 0 then
      continue;

    case sector.special of
     1:
      begin
        // FLICKERING LIGHTS
        P_SpawnLightFlash(sector);
      end;

     2:
      begin
        // STROBE FAST
        P_SpawnStrobeFlash(sector, FASTDARK, 0);
      end;

     3:
      begin
        // STROBE SLOW
        P_SpawnStrobeFlash(sector, SLOWDARK, 0);
      end;

     4:
      begin
        // STROBE FAST/DEATH SLIME
        P_SpawnStrobeFlash(sector, FASTDARK, 0);
        sector.special := 4;
      end;

     8:
      begin
        // GLOWING LIGHT
        P_SpawnGlowingLight(sector);
      end;

     9:
      begin
        // SECRET SECTOR
        inc(totalsecret);
      end;

    10:
      begin
        // DOOR CLOSE IN 30 SECONDS
        P_SpawnDoorCloseIn30(sector);
      end;

    12:
      begin
        // SYNC STROBE SLOW
        P_SpawnStrobeFlash(sector, SLOWDARK, 1);
      end;

    13:
      begin
        // SYNC STROBE FAST
        P_SpawnStrobeFlash(sector, FASTDARK, 1);
      end;

    14:
      begin
        // DOOR RAISE IN 5 MINUTES
        P_SpawnDoorRaiseIn5Mins(sector, i);
      end;

    17:
      begin
        P_SpawnFireFlicker(sector);
      end;
    end;
  end;


    //  Init line EFFECTs
  numlinespecials := 0;
  for i := 0 to numlines - 1 do
  begin
    case lines[i].special of
      48, 142, 143, 144, 145, 146, 147, 148:
        begin
          // EFFECT FIRSTCOL SCROLL+
          linespeciallist[numlinespecials] := @lines[i];
          inc(numlinespecials);
        end;
    end;
  end;


  //  Init other misc stuff
  for i := 0 to MAXCEILINGS - 1 do
    activeceilings[i] := nil;

  for i := 0 to MAXPLATS - 1 do
    activeplats[i] := nil;

  for i := 0 to MAXBUTTONS - 1 do
    ZeroMemory(@buttonlist[i], SizeOf(button_t));

    // UNUSED: no horizonal sliders.
    //  P_InitSlidingDoorFrames();
end;


end.

