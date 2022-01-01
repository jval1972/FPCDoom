//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2022 by Jim Valavanis
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

unit p_switch;

interface

uses
  r_defs,
  p_mobj_h,
  p_spec;

procedure P_InitSwitchList;

procedure P_ChangeSwitchTexture(line: Pline_t; useAgain: boolean);

function P_UseSpecialLine(thing: Pmobj_t; line: Pline_t; side: integer): boolean;

var
  buttonlist: array[0..MAXBUTTONS - 1] of button_t;

implementation

uses
  doomdata,
  p_setup,
  p_lights,
  p_plats,
  p_doors,
  p_ceilng,
  p_floor,
  i_system,
  doomdef,
  g_game,
  s_sound,
  r_data,
// Data
  sounds,
// State
  doomstat;

type
//
// P_SWITCH
//
  switchlist_t = record
    name1: string[8];
    name2: string[8];
    episode: smallint;
  end;
  Pswitchlist_t = ^switchlist_t;

const
  NUMSWITCHLIST = 41;

  alphSwitchList: array[0..NUMSWITCHLIST - 1] of switchlist_t = (
    // Doom shareware episode 1 switches
    (name1: 'SW1BRCOM'; name2: 'SW2BRCOM'; episode: 1),
    (name1: 'SW1BRN1';  name2: 'SW2BRN1';  episode: 1),
    (name1: 'SW1BRN2';  name2: 'SW2BRN2';  episode: 1),
    (name1: 'SW1BRNGN'; name2: 'SW2BRNGN'; episode: 1),
    (name1: 'SW1BROWN'; name2: 'SW2BROWN'; episode: 1),
    (name1: 'SW1COMM';  name2: 'SW2COMM';  episode: 1),
    (name1: 'SW1COMP';  name2: 'SW2COMP';  episode: 1),
    (name1: 'SW1DIRT';  name2: 'SW2DIRT';  episode: 1),
    (name1: 'SW1EXIT';  name2: 'SW2EXIT';  episode: 1),
    (name1: 'SW1GRAY';  name2: 'SW2GRAY';  episode: 1),
    (name1: 'SW1GRAY1'; name2: 'SW2GRAY1'; episode: 1),
    (name1: 'SW1METAL'; name2: 'SW2METAL'; episode: 1),
    (name1: 'SW1PIPE';  name2: 'SW2PIPE';  episode: 1),
    (name1: 'SW1SLAD';  name2: 'SW2SLAD';  episode: 1),
    (name1: 'SW1STARG'; name2: 'SW2STARG'; episode: 1),
    (name1: 'SW1STON1'; name2: 'SW2STON1'; episode: 1),
    (name1: 'SW1STON2'; name2: 'SW2STON2'; episode: 1),
    (name1: 'SW1STONE'; name2: 'SW2STONE'; episode: 1),
    (name1: 'SW1STRTN'; name2: 'SW2STRTN'; episode: 1),

    // Doom registered episodes 2&3 switches
    (name1: 'SW1BLUE';  name2: 'SW2BLUE';  episode: 2),
    (name1: 'SW1CMT';   name2: 'SW2CMT';   episode: 2),
    (name1: 'SW1GARG';  name2: 'SW2GARG';  episode: 2),
    (name1: 'SW1GSTON'; name2: 'SW2GSTON'; episode: 2),
    (name1: 'SW1HOT';   name2: 'SW2HOT';   episode: 2),
    (name1: 'SW1LION';  name2: 'SW2LION';  episode: 2),
    (name1: 'SW1SATYR'; name2: 'SW2SATYR'; episode: 2),
    (name1: 'SW1SKIN';  name2: 'SW2SKIN';  episode: 2),
    (name1: 'SW1VINE';  name2: 'SW2VINE';  episode: 2),
    (name1: 'SW1WOOD';  name2: 'SW2WOOD';  episode: 2),

    // Doom II switches
    (name1: 'SW1PANEL'; name2: 'SW2PANEL'; episode: 3),
    (name1: 'SW1ROCK';  name2: 'SW2ROCK';  episode: 3),
    (name1: 'SW1MET2';  name2: 'SW2MET2';  episode: 3),
    (name1: 'SW1WDMET'; name2: 'SW2WDMET'; episode: 3),
    (name1: 'SW1BRIK';  name2: 'SW2BRIK';  episode: 3),
    (name1: 'SW1MOD1';  name2: 'SW2MOD1';  episode: 3),
    (name1: 'SW1ZIM';   name2: 'SW2ZIM';   episode: 3),
    (name1: 'SW1STON6'; name2: 'SW2STON6'; episode: 3),
    (name1: 'SW1TEK';   name2: 'SW2TEK';   episode: 3),
    (name1: 'SW1MARB';  name2: 'SW2MARB';  episode: 3),
    (name1: 'SW1SKULL'; name2: 'SW2SKULL'; episode: 3),

    (name1: '';         name2: '';         episode: -1)
  );

var
  switchlist: array[0..2 * MAXSWITCHES - 1] of integer;
  numswitches: integer;

//
// P_InitSwitchList
// Only called at game initialization.
//
procedure P_InitSwitchList;
var
  i: integer;
  index: integer;
  episode: integer;
begin

  if (gamemode = registered) or (gamemode = retail) then
    episode := 2
  else if gamemode = commercial then
    episode := 3
  else
    episode := 1;

  index := 0;
  for i := 0 to MAXSWITCHES - 1 do
  begin
    if alphSwitchList[i].episode = -1 then
    begin
      numswitches := index div 2;
      switchlist[index] := -1;
      break;
    end;

    if alphSwitchList[i].episode <= episode then
    begin
      switchlist[index] := R_TextureNumForName(alphSwitchList[i].name1);
      inc(index);
      switchlist[index] := R_TextureNumForName(alphSwitchList[i].name2);
      inc(index);
    end;
  end;
end;

//
// Start a button counting down till it turns off.
//
procedure P_StartButton(line: Pline_t; w: bwhere_e; texture: integer; time: integer);
var
  i: integer;
begin
  // See if button is already pressed
  for i := 0 to MAXBUTTONS - 1 do
    if (buttonlist[i].btimer <> 0) and (buttonlist[i].line = line) then
      exit;

  for i := 0 to MAXBUTTONS - 1 do
  begin
    if buttonlist[i].btimer = 0 then
    begin
      buttonlist[i].line := line;
      buttonlist[i].where := w;
      buttonlist[i].btexture := texture;
      buttonlist[i].btimer := time;
      buttonlist[i].soundorg := Pmobj_t(@line.frontsector.soundorg);
      exit;
    end;
  end;

  I_Error('P_StartButton(): no button slots left!');
end;

//
// Function that changes wall texture.
// Tell it if switch is ok to use again (1=yes, it's a button).
//
procedure P_ChangeSwitchTexture(line: Pline_t; useAgain: boolean);
var
  texTop: integer;
  texMid: integer;
  texBot: integer;
  i: integer;
  sound: integer;
  sdnum: integer;
begin
  if not useAgain then
    line.special := 0;

  sdnum := line.sidenum[0];
  texTop := sides[sdnum].toptexture;
  texMid := sides[sdnum].midtexture;
  texBot := sides[sdnum].bottomtexture;

  sound := Ord(sfx_swtchn);

  // EXIT SWITCH?
  if line.special = 11 then
    sound := Ord(sfx_swtchx);

  for i := 0 to numswitches * 2 - 1 do
  begin
    if switchlist[i] = texTop then
    begin
      S_StartSound(buttonlist[0].soundorg, sound);
      sides[line.sidenum[0]].toptexture := switchlist[i xor 1];

      if useAgain then
        P_StartButton(line, top, switchlist[i], BUTTONTIME);

      exit;
    end
    else
    begin
      if switchlist[i] = texMid then
      begin
        S_StartSound(buttonlist[0].soundorg, sound);
        sides[line.sidenum[0]].midtexture := switchlist[i xor 1];

        if useAgain then
          P_StartButton(line, middle, switchlist[i], BUTTONTIME);

        exit;
      end
      else
      begin
        if switchlist[i] = texBot then
        begin
          S_StartSound(buttonlist[0].soundorg, sound);
          sides[line.sidenum[0]].bottomtexture := switchlist[i xor 1];

          if useAgain then
            P_StartButton(line, bottom, switchlist[i], BUTTONTIME);

          exit;
        end;
      end;
    end;
  end;
end;

//
// P_UseSpecialLine
// Called when a thing uses a special line.
// Only the front sides of lines are usable.
//
function P_UseSpecialLine(thing: Pmobj_t; line: Pline_t; side: integer): boolean;
begin
  // Err...
  // Use the back sides of VERY SPECIAL lines...
  if side <> 0 then
  begin
    case line.special of
      124:
        // Sliding door open&close
        // UNUSED?
        ;
      else
      begin
        result := false;
        exit;
      end;
    end;
  end;


  // Switches that other things can activate.
  if thing.player = nil then
  begin
    // never open secret doors
    if line.flags and ML_SECRET <> 0 then
    begin
      result := false;
      exit;
    end;

    case line.special of
       1:; // MANUAL DOOR RAISE
      32:; // MANUAL BLUE
      33:; // MANUAL RED
      34:; // MANUAL YELLOW
    else
      begin
        result := false;
        exit;
      end;
    end;
  end;

  // do something
  case line.special of
  // MANUALS
     1, // Vertical Door
    26, // Blue Door/Locked
    27, // Yellow Door /Locked
    28, // Red Door /Locked

    31, // Manual door open
    32, // Blue locked door open
    33, // Red locked door open
    34, // Yellow locked door open

   117, // Blazing door raise
   118: // Blazing door open
      EV_VerticalDoor(line, thing);

  //UNUSED - Door Slide Open&Close
  // case 124:
  // EV_SlidingDoor (line, thing);
  // break;

  // SWITCHES
     7:
      begin
        // Build Stairs
        if EV_BuildStairs(line, build8) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;
     9:
      begin
        // Change Donut
        if EV_DoDonut(line) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;
    11:
      begin
        // Exit level
        P_ChangeSwitchTexture(line, false);
        G_ExitLevel;
      end;

    14:
      begin
        // Raise Floor 32 and change texture
        if EV_DoPlat(line, raiseAndChange, 32) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    15:
      begin
        // Raise Floor 24 and change texture
        if EV_DoPlat(line, raiseAndChange, 24) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    18:
      begin
        // Raise Floor to next highest floor
        if EV_DoFloor(line, raiseFloorToNearest) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    20:
      begin
        // Raise Plat next highest floor and change texture
        if EV_DoPlat(line, raiseToNearestAndChange, 0) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    21:
      begin
        // PlatDownWaitUpStay
        if EV_DoPlat(line, downWaitUpStay, 0) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    23:
      begin
        // Lower Floor to Lowest
        if EV_DoFloor(line, lowerFloorToLowest) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    29:
      begin
        // Raise Door
        if EV_DoDoor(line, normal) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    41:
      begin
        // Lower Ceiling to Floor
        if EV_DoCeiling(line, lowerToFloor) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    71:
      begin
        // Turbo Lower Floor
        if EV_DoFloor(line, turboLower) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    49:
      begin
        // Ceiling Crush And Raise
        if EV_DoCeiling(line, crushAndRaise) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    50:
      begin
        // Close Door
        if EV_DoDoor(line, close) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

    51:
      begin
        // Secret EXIT
        P_ChangeSwitchTexture(line, false);
        G_SecretExitLevel;
      end;

    55:
      begin
        // Raise Floor Crush
        if EV_DoFloor(line, raiseFloorCrush) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   101:
      begin
        // Raise Floor
        if EV_DoFloor(line, raiseFloor) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   102:
      begin
        // Lower Floor to Surrounding floor height
        if EV_DoFloor(line, lowerFloor) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   103:
      begin
        // Open Door
        if EV_DoDoor(line, open) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   111:
      begin
        // Blazing Door Raise (faster than TURBO!)
        if EV_DoDoor(line, blazeRaise) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   112:
      begin
        // Blazing Door Open (faster than TURBO!)
        if EV_DoDoor(line, blazeOpen) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   113:
      begin
        // Blazing Door Close (faster than TURBO!)
        if EV_DoDoor(line, blazeClose) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   122:
      begin
        // Blazing PlatDownWaitUpStay
        if EV_DoPlat(line, blazeDWUS, 0) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   127:
      begin
        // Build Stairs Turbo 16
        if EV_BuildStairs(line, turbo16) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   131:
      begin
        // Raise Floor Turbo
        if EV_DoFloor(line, raiseFloorTurbo) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   133, // BlzOpenDoor BLUE
   135, // BlzOpenDoor RED
   137: // BlzOpenDoor YELLOW
      begin
        if EV_DoLockedDoor(line, blazeOpen, thing) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

   140:
      begin
        // Raise Floor 512
        if EV_DoFloor(line, raiseFloor512) <> 0 then
          P_ChangeSwitchTexture(line, false);
      end;

  // BUTTONS
    42:
      begin
        // Close Door
        if EV_DoDoor(line, close) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    43:
      begin
        // Lower Ceiling to Floor
        if EV_DoCeiling(line, lowerToFloor) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    45:
      begin
        // Lower Floor to Surrounding floor height
        if EV_DoFloor(line, lowerFloor) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    60:
      begin
        // Lower Floor to Lowest
        if EV_DoFloor(line, lowerFloorToLowest) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    61:
      begin
        // Open Door
        if EV_DoDoor(line, open) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    62:
      begin
        // PlatDownWaitUpStay
        if EV_DoPlat(line, downWaitUpStay, 1) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    63:
      begin
        // Raise Door
        if EV_DoDoor(line, normal) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    64:
      begin
        // Raise Floor to ceiling
        if EV_DoFloor(line, raiseFloor) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    66:
      begin
        // Raise Floor 24 and change texture
        if EV_DoPlat(line, raiseAndChange, 24) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    67:
      begin
        // Raise Floor 32 and change texture
        if EV_DoPlat(line, raiseAndChange, 32) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    65:
      begin
        // Raise Floor Crush
        if EV_DoFloor(line, raiseFloorCrush) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    68:
      begin
        // Raise Plat to next highest floor and change texture
        if EV_DoPlat(line, raiseToNearestAndChange, 0) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    69:
      begin
        // Raise Floor to next highest floor
        if EV_DoFloor(line, raiseFloorToNearest) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    70:
      begin
        // Turbo Lower Floor
        if EV_DoFloor(line, turboLower) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

   114:
      begin
        // Blazing Door Raise (faster than TURBO!)
        if EV_DoDoor(line, blazeRaise) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

   115:
      begin
        // Blazing Door Open (faster than TURBO!)
        if EV_DoDoor(line, blazeOpen) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

   116:
      begin
        // Blazing Door Close (faster than TURBO!)
        if EV_DoDoor(line, blazeClose) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

   123:
      begin
        // Blazing PlatDownWaitUpStay
        if EV_DoPlat(line, blazeDWUS, 0) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

   132:
      begin
        // Raise Floor Turbo
        if EV_DoFloor(line, raiseFloorTurbo) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

    99, // BlzOpenDoor BLUE
   134, // BlzOpenDoor RED
   136: // BlzOpenDoor YELLOW
      begin
        if EV_DoLockedDoor(line, blazeOpen, thing) <> 0 then
          P_ChangeSwitchTexture(line, true);
      end;

   138:
      begin
        // Light Turn On
        EV_LightTurnOn(line, 255);
        P_ChangeSwitchTexture(line, true);
      end;

   139:
      begin
        // Light Turn Off
        EV_LightTurnOn(line, 35);
        P_ChangeSwitchTexture(line, true);
      end;
  end;
  result := true;
end;



end.
