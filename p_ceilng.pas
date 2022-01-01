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

unit p_ceilng;

interface

uses
  z_memory,
  p_spec,
  r_defs,
  s_sound,
// State.
  doomstat,
// Data.
  sounds;

var
  activeceilings: array[0..MAXCEILINGS - 1] of Pceiling_t;

procedure T_MoveCeiling(ceiling: Pceiling_t);

function EV_DoCeiling(line: Pline_t; _type: ceiling_e): integer;

procedure P_AddActiveCeiling(c: Pceiling_t);

function EV_CeilingCrushStop(line: Pline_t): integer;

implementation

uses
  m_fixed,
  p_mobj_h,
  p_tick,
  p_setup,
  p_floor;

//
// Add an active ceiling
//
procedure P_AddActiveCeiling(c: Pceiling_t);
var
  i: integer;
begin
  for i := 0 to MAXCEILINGS - 1 do
    if activeceilings[i] = nil then
    begin
      activeceilings[i] := c;
      exit;
    end;
end;

//
// Remove a ceiling's thinker
//
procedure P_RemoveActiveCeiling(c: Pceiling_t);
var
  i: integer;
begin
  for i := 0 to MAXCEILINGS - 1 do
    if activeceilings[i] = c then
    begin
      activeceilings[i].sector.specialdata := nil;
      P_RemoveThinker(@activeceilings[i].thinker);
      activeceilings[i] := nil;
      exit;
    end;
end;

//
// Restart a ceiling that's in-stasis
//
procedure P_ActivateInStasisCeiling(line: Pline_t);
var
  i: integer;
begin
  for i := 0 to MAXCEILINGS - 1 do
    if (activeceilings[i] <> nil) and
       (activeceilings[i].tag = line.tag) and
       (activeceilings[i].direction = 0) then
    begin
      activeceilings[i].direction := activeceilings[i].olddirection;
      activeceilings[i].thinker._function.acp1 := @T_MoveCeiling;
    end;
end;

//
// T_MoveCeiling
//
procedure T_MoveCeiling(ceiling: Pceiling_t);
var
  res: result_e;
begin
  case ceiling.direction of
    0:
    // IN STASIS
      begin
      end;
    1:
    // UP
      begin
        res := T_MovePlane(ceiling.sector,
          ceiling.speed,
          ceiling.topheight,
          false, 1, ceiling.direction);

        if leveltime and 7 = 0 then
        begin
          if ceiling._type <> silentCrushAndRaise then
            S_StartSound(Pmobj_t(@ceiling.sector.soundorg),
              Ord(sfx_stnmov));
        end;

        if res = pastdest then
        begin
          case ceiling._type of
            raiseToHighest:
              P_RemoveActiveCeiling(ceiling);
            silentCrushAndRaise:
              begin
                S_StartSound(Pmobj_t(@ceiling.sector.soundorg), Ord(sfx_pstop));
                ceiling.direction := -1;
              end;
            fastCrushAndRaise,
            crushAndRaise:
              ceiling.direction := -1;
          end;
        end;
      end;
   -1:
    // DOWN
      begin
        res := T_MovePlane(ceiling.sector,
          ceiling.speed,
          ceiling.bottomheight,
          ceiling.crush, 1, ceiling.direction);

        if leveltime and 7 = 0 then
        begin
          if ceiling._type <> silentCrushAndRaise then
            S_StartSound(Pmobj_t(@ceiling.sector.soundorg), Ord(sfx_stnmov));
        end;

        if res = pastdest then
        begin
          case ceiling._type of
            silentCrushAndRaise:
              begin
                S_StartSound(Pmobj_t(@ceiling.sector.soundorg), Ord(sfx_pstop));
                ceiling.speed := CEILSPEED;
                ceiling.direction := 1;
              end;
            crushAndRaise:
              begin
                ceiling.speed := CEILSPEED;
                ceiling.direction := 1;
              end;
            fastCrushAndRaise:
              begin
                ceiling.direction := 1;
              end;
            lowerAndCrush,
            lowerToFloor:
              P_RemoveActiveCeiling(ceiling);
          end;
        end
        else // ( res <> pastdest )
        begin
          if res = crushed then
          begin
            case ceiling._type of
              silentCrushAndRaise,
              crushAndRaise,
              lowerAndCrush:
                ceiling.speed := CEILSPEED div 8;
            end;
          end;
        end;
      end;
  end;
end;

//
// EV_DoCeiling
// Move a ceiling up/down and all around!
//
function EV_DoCeiling(line: Pline_t; _type: ceiling_e): integer;
var
  initial: boolean;
  secnum: integer;
  sec: Psector_t;
  ceiling: Pceiling_t;
begin
  secnum := -1;
  result := 0;

  // Reactivate in-stasis ceilings...for certain types.
  case _type of
    fastCrushAndRaise,
    silentCrushAndRaise,
    crushAndRaise:
      P_ActivateInStasisCeiling(line);
  end;

  initial := true;
  while (secnum >= 0) or initial do
  begin
    initial := false;
    secnum := P_FindSectorFromLineTag(line, secnum);
    if secnum < 0 then
      break;

    sec := @sectors[secnum];
    if sec.specialdata <> nil then
      continue;

    // new door thinker
    result := 1;
    ceiling := Z_Malloc(SizeOf(ceiling_t), PU_LEVSPEC, nil);
    P_AddThinker(@ceiling.thinker);
    sec.specialdata := ceiling;
    ceiling.thinker._function.acp1 := @T_MoveCeiling;
    ceiling.sector := sec;
    ceiling.crush := false;

    case _type of
      fastCrushAndRaise:
        begin
          ceiling.crush := true;
          ceiling.topheight := sec.ceilingheight;
          ceiling.bottomheight := sec.floorheight + (8 * FRACUNIT);
          ceiling.direction := -1;
          ceiling.speed := CEILSPEED * 2;
        end;

      silentCrushAndRaise,
      crushAndRaise:
        begin
          ceiling.crush := true;
          ceiling.topheight := sec.ceilingheight;
          ceiling.bottomheight := sec.floorheight;
          if _type <> lowerToFloor then
            ceiling.bottomheight := ceiling.bottomheight + 8 * FRACUNIT;
          ceiling.direction := -1;
          ceiling.speed := CEILSPEED;
        end;
      lowerAndCrush,
      lowerToFloor:
        begin
          ceiling.bottomheight := sec.floorheight;
          if _type <> lowerToFloor then
            ceiling.bottomheight := ceiling.bottomheight + 8 * FRACUNIT;
          ceiling.direction := -1;
          ceiling.speed := CEILSPEED;
        end;

      raiseToHighest:
        begin
          ceiling.topheight := P_FindHighestCeilingSurrounding(sec);
          ceiling.direction := 1;
          ceiling.speed := CEILSPEED;
        end;
    end;

    ceiling.tag := sec.tag;
    ceiling._type := _type;
    P_AddActiveCeiling(ceiling);
  end;
end;

//
// EV_CeilingCrushStop
// Stop a ceiling from crushing!
//
function EV_CeilingCrushStop(line: Pline_t): integer;
var
  i: integer;
begin
  result := 0;
  for i := 0 to MAXCEILINGS - 1 do
    if (activeceilings[i] <> nil) and
       (activeceilings[i].tag = line.tag) and
       (activeceilings[i].direction <> 0) then
    begin
      activeceilings[i].olddirection := activeceilings[i].direction;
      activeceilings[i].thinker._function.acv := nil;
      activeceilings[i].direction := 0; // in-stasis
      result := 1;
    end;
end;

end.
