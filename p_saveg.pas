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

unit p_saveg;

interface

uses
  d_fpc;

//==============================================================================
// P_ArchivePlayers
//
// Persistent storage/archiving.
// These are the load / save game routines.
//
//==============================================================================
procedure P_ArchivePlayers;

//==============================================================================
//
// P_UnArchivePlayers
//
//==============================================================================
procedure P_UnArchivePlayers;

//==============================================================================
//
// P_ArchiveWorld
//
//==============================================================================
procedure P_ArchiveWorld;

//==============================================================================
//
// P_UnArchiveWorld
//
//==============================================================================
procedure P_UnArchiveWorld;

//==============================================================================
//
// P_ArchiveThinkers
//
//==============================================================================
procedure P_ArchiveThinkers;

//==============================================================================
//
// P_UnArchiveThinkers
//
//==============================================================================
procedure P_UnArchiveThinkers;

//==============================================================================
//
// P_ArchiveSpecials
//
//==============================================================================
procedure P_ArchiveSpecials;

//==============================================================================
//
// P_UnArchiveSpecials
//
//==============================================================================
procedure P_UnArchiveSpecials;

var
  save_p: PByteArray;
  savegameversion: integer;

var
  loadtracerfromsavedgame: boolean = true;
  loadtargetfromsavedgame: boolean = true;

implementation

uses
  doomdef,
  d_player,
  d_think,
  g_game,
  m_fixed,
  info_h,
  info,
  i_system,
  p_pspr_h,
  p_setup,
  p_mobj_h,
  p_mobj,
  p_tick,
  p_maputl,
  p_spec,
  p_lights,
  p_ceilng,
  p_doors,
  p_floor,
  p_plats,
  r_defs,
  z_memory;

//==============================================================================
// PADSAVEP
//
// Pads save_p to a 4-byte boundary
//  so that the load/save works on SGI&Gecko.
//
//==============================================================================
procedure PADSAVEP(var prt: PByteArray);
begin
  prt := PByteArray(integer(prt) + ((4 - (integer(prt) and 3) and 3)));
end;

//==============================================================================
//
// P_ArchivePlayers
//
//==============================================================================
procedure P_ArchivePlayers;
var
  i: integer;
  j: integer;
  dest: Pplayer_t;
begin
  for i := 0 to MAXPLAYERS - 1 do
  begin
    if not playeringame[i] then
      continue;

    PADSAVEP(save_p);

    dest := Pplayer_t(save_p);
    memcpy(dest, @players[i], SizeOf(player_t));
    save_p := pOp(save_p, SizeOf(player_t));
    for j := 0 to Ord(NUMPSPRITES) - 1 do
      if dest.psprites[j].state <> nil then
        dest.psprites[j].state := Pstate_t(pDiff(dest.psprites[j].state, @states[0], SizeOf(dest.psprites[j].state^)));
  end;
end;

//==============================================================================
//
// P_UnArchivePlayers
//
//==============================================================================
procedure P_UnArchivePlayers;
var
  i: integer;
  j: integer;
begin
  for i := 0 to MAXPLAYERS - 1 do
  begin
    if not playeringame[i] then
      continue;

    PADSAVEP(save_p);

    if savegameversion = VERSION then
    begin
      memcpy(@players[i], save_p, SizeOf(player_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(player_t));
    end
    else
      I_Error('P_UnArchivePlayers(): Unsupported saved game version: %d', [savegameversion]);

    // will be set when unarc thinker
    players[i].mo := nil;
    players[i]._message := '';
    players[i].attacker := nil;

    for j := 0 to Ord(NUMPSPRITES) - 1 do
      if players[i].psprites[j].state <> nil then
        players[i].psprites[j].state := @states[PCAST(players[i].psprites[j].state)];
  end;
end;

//==============================================================================
//
// P_ArchiveWorld
//
//==============================================================================
procedure P_ArchiveWorld;
var
  i: integer;
  j: integer;
  sec: Psector_t;
  li: Pline_t;
  si: Pside_t;
  put: PSmallIntArray;
begin
  put := PSmallIntArray(save_p);

  // do sectors
  i := 0;
  while i < numsectors do
  begin
    sec := Psector_t(@sectors[i]);
    put[0] := sec.floorheight div FRACUNIT;
    put := @put[1];
    put[0] := sec.ceilingheight div FRACUNIT;
    put := @put[1];
    put[0] := sec.floorpic;
    put := @put[1];
    put[0] := sec.ceilingpic;
    put := @put[1];
    put[0] := sec.lightlevel;
    put := @put[1];
    put[0] := sec.special; // needed?
    put := @put[1];
    put[0] := sec.tag;  // needed?
    put := @put[1];
    inc(i);
  end;

  // do lines
  i := 0;
  while i < numlines do
  begin
    li := Pline_t(@lines[i]);
    put[0] := li.flags;
    put := @put[1];
    put[0] := li.special;
    put := @put[1];
    put[0] := li.tag;
    put := @put[1];
    for j := 0 to 1 do
    begin
      if li.sidenum[j] = -1 then
        continue;

      si := @sides[li.sidenum[j]];

      put[0] := si.textureoffset div FRACUNIT;
      put := @put[1];
      put[0] := si.rowoffset div FRACUNIT;
      put := @put[1];
      put[0] := si.toptexture;
      put := @put[1];
      put[0] := si.bottomtexture;
      put := @put[1];
      put[0] := si.midtexture;
      put := @put[1];
    end;
    inc(i);
  end;

  save_p := PByteArray(put);
end;

//==============================================================================
//
// P_UnArchiveWorld
//
//==============================================================================
procedure P_UnArchiveWorld;
var
  i: integer;
  j: integer;
  sec: Psector_t;
  li: Pline_t;
  si: Pside_t;
  get: PSmallIntArray;
begin
  get := PSmallIntArray(save_p);

  // do sectors
  i := 0;
  while i < numsectors do
  begin
    sec := Psector_t(@sectors[i]);
    sec.floorheight := get[0] * FRACUNIT;
    get := @get[1];
    sec.ceilingheight := get[0] * FRACUNIT;
    get := @get[1];
    sec.floorpic := get[0];
    get := @get[1];
    sec.ceilingpic := get[0];
    get := @get[1];
    sec.lightlevel := get[0];
    get := @get[1];
    sec.special := get[0]; // needed?
    get := @get[1];
    sec.tag := get[0]; // needed?
    get := @get[1];
    sec.specialdata := nil;
    sec.soundtarget := nil;
    inc(i);
  end;

  // do lines
  i := 0;
  while i < numlines do
  begin
    li := Pline_t(@lines[i]);
    li.flags := get[0];
    get := @get[1];
    li.special := get[0];
    get := @get[1];
    li.tag := get[0];
    get := @get[1];
    for j := 0 to 1 do
    begin
      if li.sidenum[j] = -1 then
        continue;
      si := @sides[li.sidenum[j]];
      si.textureoffset := get[0] * FRACUNIT;
      get := @get[1];
      si.rowoffset := get[0] * FRACUNIT;
      get := @get[1];
      si.toptexture := get[0];
      get := @get[1];
      si.bottomtexture := get[0];
      get := @get[1];
      si.midtexture := get[0];
      get := @get[1];
    end;
    inc(i);
  end;
  save_p := PByteArray(get);
end;

//
// Thinkers
//
type
  thinkerclass_t = (tc_end, tc_mobj);

//==============================================================================
//
// P_ArchiveThinkers
//
//==============================================================================
procedure P_ArchiveThinkers;
var
  th: Pthinker_t;
  mobj: Pmobj_t;
  lst: TDPointerList;
  old_p: PByteArray;
begin
  // Preserve target & tracer on saved games
  old_p := save_p;
  lst := TDPointerList.Create;
  lst.AddItem(nil);

  // save off the current thinkers
  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th._function.acp1 = @P_MobjThinker then
    begin
      lst.AddItem(th);
      save_p[0] := Ord(tc_mobj);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      mobj := Pmobj_t(save_p);
      memcpy(mobj, th, SizeOf(mobj_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(mobj_t));
      mobj.state := Pstate_t(pDiff(mobj.state, @states[0], SizeOf(state_t)));

      if mobj.player <> nil then
        mobj.player := Pplayer_t(pDiff(mobj.player, @players[0], SizeOf(player_t)) + 1);
    end;
  // I_Error ("P_ArchiveThinkers: Unknown thinker function");
    th := th.next;
  end;

  // Preserve target & tracer on saved games
  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th._function.acp1 = @P_MobjThinker then
    begin
      old_p := @old_p[1];
      PADSAVEP(old_p);
      mobj := Pmobj_t(old_p);
      {$IFNDEF FPC}old_p := {$ENDIF}incp(old_p, SizeOf(mobj_t));
      mobj.tracer := Pmobj_t((lst.IndexOf(mobj.tracer) and $FFFF) or (LongWord(mobj.state) shl 16));
      mobj.target := Pmobj_t((lst.IndexOf(mobj.target) and $FFFF) or (LongWord(mobj.state) shl 16));
    end;
    th := th.next;
  end;
  lst.Free;

  // add a terminating marker
  save_p[0] := Ord(tc_end);
  save_p := @save_p[1];
end;

// P_UnArchiveThinkers
//
//==============================================================================
procedure P_UnArchiveThinkers;
var
  tclass: byte;
  currentthinker: Pthinker_t;
  next: Pthinker_t;
  mobj: Pmobj_t;
  lst: TDPointerList;
  i, idx, idxstate: integer;
begin
  // remove all the current thinkers
  currentthinker := thinkercap.next;
  while currentthinker <> @thinkercap do
  begin
    next := currentthinker.next;

    if @currentthinker._function.acp1 = @P_MobjThinker then
      P_RemoveMobj(Pmobj_t(currentthinker))
    else
      Z_Free(currentthinker);

    currentthinker := next;
  end;
  P_InitThinkers;

  // Preserve target & tracer on saved games
  lst := TDPointerList.Create;
  lst.AddItem(nil);

  // read in saved thinkers
  while true do
  begin
    tclass := save_p[0];
    save_p := @save_p[1];
    case tclass of
      Ord(tc_end):
        break; // end of list

      Ord(tc_mobj):
        begin
          PADSAVEP(save_p);
          mobj := Z_Malloc(SizeOf(mobj_t), PU_LEVEL, nil);
          lst.AddItem(mobj);

          if savegameversion = VERSION then
          begin
            memcpy(mobj, save_p, SizeOf(mobj_t));
            {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(mobj_t));
          end
          else
            I_Error('P_UnArchiveThinkers(): Unsupported saved game version: %d', [savegameversion]);

          mobj.state := @states[PCAST(mobj.state)];
          if mobj.player <> nil then
          begin
            mobj.player := @players[PCAST(mobj.player) - 1];

            Pplayer_t(mobj.player).mo := mobj;
          end;
          P_SetThingPosition(mobj);
          mobj.info := @mobjinfo[Ord(mobj._type)];
          mobj.floorz := Psubsector_t(mobj.subsector).sector.floorheight;
          mobj.ceilingz := Psubsector_t(mobj.subsector).sector.ceilingheight;
          @mobj.thinker._function.acp1 := @P_MobjThinker;
          P_AddThinker(@mobj.thinker);
        end;
      else
        I_Error('P_UnArchiveThinkers(): Unknown tclass %d in savegame', [tclass]);
    end;
  end;

  // Preserve target & tracer on saved games
  for i := 1 to lst.Count - 1 do
  begin
    mobj := lst.Pointers[i];

    if loadtracerfromsavedgame then
    begin
      idx := LongWord(mobj.tracer) and $FFFF;
      idxstate := LongWord(mobj.tracer) shr 16;
      mobj.tracer := nil;
      if (idx >= 1) and (idx < lst.Count) and (@states[idxstate] = mobj.state) then
        mobj.tracer := lst.Pointers[idx];
    end
    else
      mobj.tracer := nil;

    if loadtargetfromsavedgame then
    begin
      idx := LongWord(mobj.target) and $FFFF;
      idxstate := LongWord(mobj.target) shr 16;
      mobj.target := nil;
      if (idx >= 1) and (idx < lst.Count) and (@states[idxstate] = mobj.state) then
        mobj.target := lst.Pointers[idx];
    end
    else
      mobj.target := nil;

  end;

  lst.Free;
end;

//
// P_ArchiveSpecials
//
type
  specials_e = (
    tc_ceiling,
    tc_door,
    tc_floor,
    tc_plat,
    tc_flash,
    tc_strobe,
    tc_glow,
    tc_fireflicker, // JVAL correct T_FireFlicker savegame bug
    tc_endspecials
  );

//==============================================================================
// P_ArchiveSpecials
//
// Things to handle:
//
// T_MoveCeiling, (ceiling_t: sector_t * swizzle), - active list
// T_VerticalDoor, (vldoor_t: sector_t * swizzle),
// T_MoveFloor, (floormove_t: sector_t * swizzle),
// T_LightFlash, (lightflash_t: sector_t * swizzle),
// T_StrobeFlash, (strobe_t: sector_t *),
// T_Glow, (glow_t: sector_t *),
// T_PlatRaise, (plat_t: sector_t *), - active list
//
//==============================================================================
procedure P_ArchiveSpecials;
var
  th: Pthinker_t;
  th1: Pthinker_t;
  ceiling: Pceiling_t;
  door: Pvldoor_t;
  floor: Pfloormove_t;
  plat: Pplat_t;
  flash: Plightflash_t;
  strobe: Pstrobe_t;
  glow: Pglow_t;
  flicker: Pfireflicker_t;
  i: integer;
begin
  // save off the current thinkers
  th1 := thinkercap.next;
  while th1 <> @thinkercap do
  begin
    th := th1;
    th1 := th1.next;
    if not Assigned(th._function.acv) then
    begin
      i := 0;
      while i < MAXCEILINGS do
      begin
        if activeceilings[i] = Pceiling_t(th) then
          break;
        inc(i);
      end;

      if i < MAXCEILINGS then
      begin
        save_p[0] := Ord(tc_ceiling);
        save_p := @save_p[1];
        PADSAVEP(save_p);
        ceiling := Pceiling_t(save_p);
        memcpy(ceiling, th, SizeOf(ceiling_t));
        {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(ceiling_t));
        ceiling.sector := Psector_t(pDiff(ceiling.sector, @sectors[0], SizeOf(sector_t)));
      end;
      continue;
    end;

    if @th._function.acp1 = @T_MoveCeiling then
    begin
      save_p[0] := Ord(tc_ceiling);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      ceiling := Pceiling_t(save_p);
      memcpy(ceiling, th, SizeOf(ceiling_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(ceiling_t));
      ceiling.sector := Psector_t(pDiff(ceiling.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_VerticalDoor then
    begin
      save_p[0] := Ord(tc_door);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      door := Pvldoor_t(save_p);
      memcpy(door, th, SizeOf(vldoor_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(vldoor_t));
      door.sector := Psector_t(pDiff(door.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_MoveFloor then
    begin
      save_p[0] := Ord(tc_floor);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      floor := Pfloormove_t(save_p);
      memcpy(floor, th, SizeOf(floormove_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(floormove_t));
      floor.sector := Psector_t(pDiff(floor.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_PlatRaise then
    begin
      save_p[0] := Ord(tc_plat);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      plat := Pplat_t(save_p);
      memcpy(plat, th, SizeOf(plat_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(plat_t));
      plat.sector := Psector_t(pDiff(plat.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_LightFlash then
    begin
      save_p[0] := Ord(tc_flash);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      flash := Plightflash_t(save_p);
      memcpy(flash, th, SizeOf(lightflash_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(lightflash_t));
      flash.sector := Psector_t(pDiff(flash.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_StrobeFlash then
    begin
      save_p[0] := Ord(tc_strobe);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      strobe := Pstrobe_t(save_p);
      memcpy(strobe, th, SizeOf(strobe_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(strobe_t));
      strobe.sector := Psector_t(pDiff(strobe.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_Glow then
    begin
      save_p[0] := Ord(tc_glow);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      glow := Pglow_t(save_p);
      memcpy(glow, th, SizeOf(glow_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(glow_t));
      glow.sector := Psector_t(pDiff(glow.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

    if @th._function.acp1 = @T_FireFlicker then
    begin
      save_p[0] := Ord(tc_fireflicker);
      save_p := @save_p[1];
      PADSAVEP(save_p);
      flicker := Pfireflicker_t(save_p);
      memcpy(flicker, th, SizeOf(fireflicker_t));
      {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(fireflicker_t));
      flicker.sector := Psector_t(pDiff(flicker.sector, @sectors[0], SizeOf(sector_t)));
      continue;
    end;

  end;

  // add a terminating marker
  save_p[0] := Ord(tc_endspecials);
  save_p := @save_p[1];
end;

//==============================================================================
//
// P_UnArchiveSpecials
//
//==============================================================================
procedure P_UnArchiveSpecials;
var
  tclass: byte;
  ceiling: Pceiling_t;
  door: Pvldoor_t;
  floor: Pfloormove_t;
  plat: Pplat_t;
  flash: Plightflash_t;
  strobe: Pstrobe_t;
  glow: Pglow_t;
  flicker: Pfireflicker_t;
begin
  // read in saved thinkers
  while true do
  begin
    tclass := save_p[0];
    save_p := @save_p[1];
    case tclass of
      Ord(tc_endspecials):
        exit; // end of list

      Ord(tc_ceiling):
        begin
          PADSAVEP(save_p);
          ceiling := Z_Malloc(SizeOf(ceiling_t), PU_LEVEL, nil);
          memcpy(ceiling, save_p, SizeOf(ceiling_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(ceiling_t));
          ceiling.sector := @sectors[PCAST(ceiling.sector)];
          ceiling.sector.specialdata := ceiling;

          if Assigned(ceiling.thinker._function.acp1) then // JVAL works ???
            @ceiling.thinker._function.acp1 := @T_MoveCeiling;

          P_AddThinker(@ceiling.thinker);
          P_AddActiveCeiling(ceiling);
        end;

      Ord(tc_door):
        begin
          PADSAVEP(save_p);
          door := Z_Malloc(SizeOf(vldoor_t), PU_LEVEL, nil);
          memcpy(door, save_p, SizeOf(vldoor_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(vldoor_t));
          door.sector := @sectors[PCAST(door.sector)];
          door.sector.specialdata := door;
          @door.thinker._function.acp1 := @T_VerticalDoor;
          P_AddThinker(@door.thinker);
        end;

      Ord(tc_floor):
        begin
          PADSAVEP(save_p);
          floor := Z_Malloc(SizeOf(floormove_t), PU_LEVEL, nil);
          memcpy(floor, save_p, SizeOf(floormove_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(floormove_t));
          floor.sector := @sectors[PCAST(floor.sector)];
          floor.sector.specialdata := floor;
          @floor.thinker._function.acp1 := @T_MoveFloor;
          P_AddThinker(@floor.thinker);
        end;

      Ord(tc_plat):
        begin
          PADSAVEP(save_p);
          plat := Z_Malloc(SizeOf(plat_t), PU_LEVEL, nil);
          memcpy(plat, save_p, SizeOf(plat_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(plat_t));
          plat.sector := @sectors[PCAST(plat.sector)];
          plat.sector.specialdata := plat;

          if Assigned(plat.thinker._function.acp1) then  // JVAL ??? from serialization
            @plat.thinker._function.acp1 := @T_PlatRaise;

          P_AddThinker(@plat.thinker);
          P_AddActivePlat(plat);
        end;

      Ord(tc_flash):
        begin
          PADSAVEP(save_p);
          flash := Z_Malloc(Sizeof(lightflash_t), PU_LEVEL, nil);
          memcpy(flash, save_p, SizeOf(lightflash_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(lightflash_t));
          flash.sector := @sectors[PCAST(flash.sector)];
          @flash.thinker._function.acp1 := @T_LightFlash;
          P_AddThinker(@flash.thinker);
        end;

      Ord(tc_strobe):
        begin
          PADSAVEP(save_p);
          strobe := Z_Malloc(SizeOf(strobe_t), PU_LEVEL, nil);
          memcpy(strobe, save_p, SizeOf(strobe_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(strobe_t));
          strobe.sector := @sectors[PCAST(strobe.sector)];
          @strobe.thinker._function.acp1 := @T_StrobeFlash;
          P_AddThinker(@strobe.thinker);
        end;

      Ord(tc_glow):
        begin
          PADSAVEP(save_p);
          glow := Z_Malloc(SizeOf(glow_t), PU_LEVEL, nil);
          memcpy(glow, save_p, SizeOf(glow_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(glow_t));
          glow.sector := @sectors[PCAST(glow.sector)];
          @glow.thinker._function.acp1 := @T_Glow;
          P_AddThinker(@glow.thinker);
        end;

      Ord(tc_fireflicker):
        begin
          PADSAVEP(save_p);
          flicker := Z_Malloc(SizeOf(fireflicker_t), PU_LEVEL, nil);
          memcpy(flicker, save_p, SizeOf(fireflicker_t));
          {$IFNDEF FPC}save_p := {$ENDIF}incp(save_p, SizeOf(fireflicker_t));
          @flicker.thinker._function.acp1 := @T_FireFlicker;
          flicker.sector := @sectors[PCAST(flicker.sector)];
          P_AddThinker(@flicker.thinker);
        end;

      else
        I_Error('P_UnarchiveSpecials(): Unknown tclass %d in savegame', [tclass]);
    end;
  end;
end;

end.
