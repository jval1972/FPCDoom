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

unit r_intrpl;

// JVAL
// Frame interpolation to exceed the 35fps limit
//

interface

uses
    m_fixed;

//==============================================================================
//
// R_InitInterpolations
//
//==============================================================================
procedure R_InitInterpolations;

//==============================================================================
//
// R_ResetInterpolationBuffer
//
//==============================================================================
procedure R_ResetInterpolationBuffer;

//==============================================================================
//
// R_StoreInterpolationData
//
//==============================================================================
procedure R_StoreInterpolationData;

//==============================================================================
//
// R_RestoreInterpolationData
//
//==============================================================================
procedure R_RestoreInterpolationData;

//==============================================================================
//
// R_Interpolate
//
//==============================================================================
function R_Interpolate: boolean;

//==============================================================================
//
// R_InterpolateTicker
//
//==============================================================================
procedure R_InterpolateTicker;

//==============================================================================
//
// R_SetInterpolateSkipTicks
//
//==============================================================================
procedure R_SetInterpolateSkipTicks(const ticks: integer);

var
  interpolate: boolean;
  didinterpolations: boolean;
  ticfrac: fixed_t;
  interpolationstoretime: fixed_t = 0;

implementation

uses
  d_fpc,
  d_player,
  d_think,
  c_cmds,
  m_misc,
  g_game,
  i_system,
  p_setup,
  p_tick,
  p_mobj,
  p_mobj_h,
  p_telept,
  p_pspr_h,
  p_pspr,
  r_defs,
  tables;

type
  itype = (iinteger, ismallint, ibyte, iangle, imobj);

  // Interpolation item
  //  Holds information about the previous and next values and interpolation type
  iitem_t = record
    lastaddress: pointer;
    address: pointer;
    case _type: itype of
      iinteger: (iprev, inext: integer);
      ismallint: (siprev, sinext: smallint);
      ibyte: (bprev, bnext: byte);
      iangle: (aprev, anext: LongWord);
  end;
  Piitem_t = ^iitem_t;
  iitem_tArray = array[0..$FFFF] of iitem_t;
  Piitem_tArray = ^iitem_tArray;

  // Interpolation structure
  //  Holds the global interpolation items list
  istruct_t = record
    numitems: integer;
    realsize: integer;
    items: Piitem_tArray;
  end;

const
  IGROWSTEP = 256;

var
  istruct: istruct_t;
  imobjs: array[0..$FFFF] of Pmobj_t;
  numismobjs: integer;

//==============================================================================
//
// CmdInterpolate
//
//==============================================================================
procedure CmdInterpolate(const parm: string = '');
var
  newval: boolean;
begin
  if parm = '' then
  begin
    printf('Current setting: interpolate = %s.'#13#10, [truefalseStrings[interpolate]]);
    exit;
  end;

  newval := C_BoolEval(parm, interpolate);
  if newval <> interpolate then
  begin
    interpolate := newval;
    R_SetInterpolateSkipTicks(1);
  end;

  CmdInterpolate;
end;

//==============================================================================
//
// R_InitInterpolations
//
//==============================================================================
procedure R_InitInterpolations;
begin
  istruct.numitems := 0;
  istruct.realsize := 0;
  istruct.items := nil;
  ZeroMemory(@imobjs, SizeOf(imobjs));
  numismobjs := 0;
  C_AddCmd('interpolate, interpolation, setinterpolation, r_interpolate', @CmdInterpolate);
end;

//==============================================================================
//
// R_ResetInterpolationBuffer
//
//==============================================================================
procedure R_ResetInterpolationBuffer;
begin
  memfree(istruct.items, istruct.realsize * SizeOf(iitem_t));
  {$IFNDEF FPC}
  istruct.items := nil;
  {$ENDIF}
  istruct.numitems := 0;
  istruct.realsize := 0;
  numismobjs := 0;
end;

//==============================================================================
//
// R_InterpolationCalcIF
//
//==============================================================================
function R_InterpolationCalcIF(const prev, next: fixed_t; const frac: fixed_t): fixed_t; {$IFDEF FPC}inline;{$ENDIF}
begin
  if next = prev then
    result := prev
  else
    result := prev + Round((next - prev) / FRACUNIT * frac);
end;

//==============================================================================
//
// R_InterpolationCalcSIF
//
//==============================================================================
function R_InterpolationCalcSIF(const prev, next: smallint; const frac: fixed_t): smallint; {$IFDEF FPC}inline;{$ENDIF}
begin
  if next = prev then
    result := prev
  else
    result := prev + Round((next - prev) / FRACUNIT * frac);
end;

//==============================================================================
//
// R_InterpolationCalcI
//
//==============================================================================
procedure R_InterpolationCalcI(const pi: Piitem_t; const frac: fixed_t); {$IFDEF FPC}inline;{$ENDIF}
begin
  if pi.inext = pi.iprev then
    exit;

  PInteger(pi.address)^ := pi.iprev + Round((pi.inext - pi.iprev) / FRACUNIT * frac);
end;

//==============================================================================
//
// R_InterpolationCalcSI
//
//==============================================================================
procedure R_InterpolationCalcSI(const pi: Piitem_t; const frac: fixed_t); {$IFDEF FPC}inline;{$ENDIF}
begin
  if pi.sinext = pi.siprev then
    exit;

  PSmallInt(pi.address)^ := pi.siprev + Round((pi.sinext - pi.siprev) / FRACUNIT * frac);
end;

//==============================================================================
//
// R_InterpolationCalcB
//
//==============================================================================
function R_InterpolationCalcB(const prev, next: byte; const frac: fixed_t): byte; {$IFDEF FPC}inline;{$ENDIF}
begin
  if next = prev then
    result := prev
  else if (next = 0) or (prev = 0) then // Hack for player.lookleftright
    result := next
  else if ((next > 247) and (prev < 8)) or ((next < 8) and (prev > 247)) then // Hack for player.lookleftright
    result := 0
  else
    result := prev + (next - prev) * frac div FRACUNIT;
end;

//==============================================================================
//
// R_InterpolationCalcA
//
//==============================================================================
function R_InterpolationCalcA(const prev, next: angle_t; const frac: fixed_t): angle_t; {$IFDEF FPC}inline;{$ENDIF}
var
  prev_e, next_e, mid_e: Extended;
begin
  if prev = next then
    result := prev
  else
  begin
    if ((prev < ANG90) and (next > ANG270)) or
       ((next < ANG90) and (prev > ANG270)) then
    begin
      prev_e := prev / ANGLE_MAX;
      next_e := next / ANGLE_MAX;
      if prev > next then
        next_e := next_e + 1.0
      else
        prev_e := prev_e + 1.0;

      mid_e := prev_e + (next_e - prev_e) / FRACUNIT * frac;
      if mid_e > 1.0 then
        mid_e := mid_e - 1.0;
      result := Round(mid_e * ANGLE_MAX);
    end
    else if prev > next then
    begin
      result := prev - Round((prev - next) / FRACUNIT * frac);
    end
    else
    begin
      result := prev + Round((next - prev) / FRACUNIT * frac);
    end;
  end;
end;

//==============================================================================
//
// R_AddInterpolationItem
//
//==============================================================================
procedure R_AddInterpolationItem(const addr: pointer; const typ: itype); {$IFDEF FPC}inline;{$ENDIF}
var
  newrealsize: integer;
  pi: Piitem_t;
begin
  if typ = imobj then
  begin
    imobjs[numismobjs] := addr;
    if numismobjs < $FFFF then
      inc(numismobjs);
    Pmobj_t(addr).prevx := Pmobj_t(addr).nextx;
    Pmobj_t(addr).prevy := Pmobj_t(addr).nexty;
    Pmobj_t(addr).prevz := Pmobj_t(addr).nextz;
    Pmobj_t(addr).prevangle := Pmobj_t(addr).nextangle;
    Pmobj_t(addr).nextx := Pmobj_t(addr).x;
    Pmobj_t(addr).nexty := Pmobj_t(addr).y;
    Pmobj_t(addr).nextz := Pmobj_t(addr).z;
    Pmobj_t(addr).nextangle := Pmobj_t(addr).angle;
    inc(Pmobj_t(addr).intrplcnt);
    exit;
  end;

  if istruct.realsize <= istruct.numitems then
  begin
    newrealsize := istruct.realsize + IGROWSTEP;
    {$IFNDEF FPC}istruct.items := {$ENDIF}realloc(istruct.items, istruct.realsize * SizeOf(iitem_t), newrealsize * SizeOf(iitem_t));
    ZeroMemory(@istruct.items[istruct.realsize], IGROWSTEP * SizeOf(iitem_t));
    istruct.realsize := newrealsize;
  end;
  pi := @istruct.items[istruct.numitems];
  pi.lastaddress := pi.address;
  pi.address := addr;
  pi._type := typ;
  case typ of
    iinteger:
      begin
        pi.iprev := pi.inext;
        pi.inext := PInteger(addr)^;
      end;
    ismallint:
      begin
        pi.siprev := pi.sinext;
        pi.sinext := PSmallInt(addr)^;
      end;
    ibyte:
      begin
        pi.bprev := pi.bnext;
        pi.bnext := PByte(addr)^;
      end;
    iangle:
      begin
        pi.aprev := pi.anext;
        pi.anext := Pangle_t(addr)^;
      end;
  end;
  inc(istruct.numitems);
end;

var
  prevtic: fixed_t = 0;

// JVAL: Skip interpolation if we have teleport
var
  skipinterpolationticks: integer = -1;

//==============================================================================
//
// R_StoreInterpolationData
//
//==============================================================================
procedure R_StoreInterpolationData;
var
  sec: Psector_t;
  li: Pline_t;
  si: PSide_t;
  i, j: integer;
  player: Pplayer_t;
  th: Pthinker_t;
begin
  if prevtic > 0 then
    if gametic = prevtic then
      exit;

  prevtic := gametic;
  istruct.numitems := 0;
  numismobjs := 0;

  // Interpolate player
  player := @players[displayplayer];
  R_AddInterpolationItem(@player.lookupdown, iinteger); // JVAL Look Up/Down
  R_AddInterpolationItem(@player.lookleftright, ibyte);
  R_AddInterpolationItem(@player.viewz, iinteger);
  R_AddInterpolationItem(@teleporttics[displayplayer], iinteger);

  // Interpolate Sectors
  sec := @sectors[0];
  for i := 0 to numsectors - 1 do
  begin
    R_AddInterpolationItem(@sec.floorheight, iinteger);
    R_AddInterpolationItem(@sec.ceilingheight, iinteger);
    R_AddInterpolationItem(@sec.lightlevel, ismallint);
    inc(sec);
  end;

  for i := 0 to Ord(NUMPSPRITES) - 1 do
  begin
    // Customizable player bob
    R_AddInterpolationItem(@psprdefs[displayplayer, i].r_sx, iinteger);
    R_AddInterpolationItem(@psprdefs[displayplayer, i].r_sy, iinteger);
  end;

  // Interpolate Lines
  li := @lines[0];
  for i := 0 to numlines - 1 do
  begin
    if li.special <> 0 then
      for j := 0 to 1 do
      begin
        if li.sidenum[j] > -1 then
        begin
          si := @sides[li.sidenum[j]];
          R_AddInterpolationItem(@si.textureoffset, iinteger);
          R_AddInterpolationItem(@si.rowoffset, iinteger);
        end;
      end;
    inc(li);
  end;

  // Map Objects
  th := thinkercap.next;
  while (th <> nil) and (th <> @thinkercap) do
  begin
    if @th._function.acp1 = @P_MobjThinker then
      R_AddInterpolationItem(th, imobj);
    th := th.next;
  end;
end;

//==============================================================================
//
// R_RestoreInterpolationData
//
//==============================================================================
procedure R_RestoreInterpolationData;
var
  i: integer;
  pi: Piitem_t;
  mo: Pmobj_t;
begin
  pi := @istruct.items[0];
  for i := 0 to istruct.numitems - 1 do
  begin
    case pi._type of
      iinteger: PInteger(pi.address)^ := pi.inext;
      ismallint: PSmallInt(pi.address)^ := pi.sinext;
      ibyte: PByte(pi.address)^ := pi.bnext;
      iangle: Pangle_t(pi.address)^ := pi.anext;
    end;
    inc(pi);
  end;

  for i := 0 to numismobjs - 1 do
  begin
    mo := imobjs[i];
    mo.x := mo.nextx;
    mo.y := mo.nexty;
    mo.z := mo.nextz;
    mo.angle := mo.nextangle;
  end;
end;

//==============================================================================
//
// R_Interpolate
//
//==============================================================================
function R_Interpolate: boolean;
var
  i: integer;
  pi: Piitem_t;
  fractime: fixed_t;
  mo: Pmobj_t;
begin
  if skipinterpolationticks >= 0 then
  begin
    result := false;
    exit;
  end;

  fractime := I_GetFracTime;
  ticfrac := fractime - interpolationstoretime;
  if ticfrac > FRACUNIT then
  begin
  // JVAL
  // frac > FRACUNIT should rarelly happen,
  // we don't calc, we just use the Xnext values for interpolation frame
    result := false;
  end
  else
  begin
    result := true;
    pi := @istruct.items[0];
    for i := 0 to istruct.numitems - 1 do
    begin
      if pi.address = pi.lastaddress then
      begin
        case pi._type of
          iinteger: R_InterpolationCalcI(pi, ticfrac);
          ismallint: R_InterpolationCalcSI(pi, ticfrac);
          ibyte: PByte(pi.address)^ := R_InterpolationCalcB(pi.bprev, pi.bnext, ticfrac);
          iangle: PAngle_t(pi.address)^ := R_InterpolationCalcA(pi.aprev, pi.anext, ticfrac);
        end;
      end;
      inc(pi);
    end;
    for i := 0 to numismobjs - 1 do
    begin
      mo := imobjs[i];
      if mo.intrplcnt > 1 then
      begin
        mo.x := R_InterpolationCalcIF(mo.prevx, mo.nextx, ticfrac);
        mo.y := R_InterpolationCalcIF(mo.prevy, mo.nexty, ticfrac);
        mo.z := R_InterpolationCalcIF(mo.prevz, mo.nextz, ticfrac);
        mo.angle := R_InterpolationCalcA(mo.prevangle, mo.nextangle, ticfrac);
      end;
    end;
  end;
end;

//==============================================================================
//
// R_InterpolateTicker
//
//==============================================================================
procedure R_InterpolateTicker;
begin
  if skipinterpolationticks >= 0 then
    dec(skipinterpolationticks);
end;

//==============================================================================
//
// R_SetInterpolateSkipTicks
//
//==============================================================================
procedure R_SetInterpolateSkipTicks(const ticks: integer);
begin
  skipinterpolationticks := ticks;
end;

end.

