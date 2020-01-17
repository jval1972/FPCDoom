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

unit v_intermission;

interface

procedure V_IntermissionStretch;

procedure V_StatusBarStretch;

type
  intermissionstretchmode_t = (
    ism_none,
    ism_auto,
    ism_5,
    ism_10,
    ism_15,
    ism_20,
    ism_25,
    ism_30,
    ism_40,
    ism_50,
    ism_max
  );

const
  // Intermission stretch modes (for menu) - Intermission screens resize
  isminfo_names: array[Ord(ism_none)..Ord(ism_max) - 1] of string[4] = (
    'NONE',
    'AUTO',
    '5%',
    '10%',
    '15%',
    '20%',
    '25%',
    '30%',
    '40%',
    '50%'
  );

  // Statusbar stretch modes (for menu) - Statusbar size
  ssminfo_names: array[Ord(ism_none)..Ord(ism_max) - 1] of string[4] = (
    'FULL',
    'AUTO',
    '95%',
    '90%',
    '85%',
    '80%',
    '75%',
    '70%',
    '60%',
    '50%'
  );

var
  intermissionstretch_mode: integer = Ord(ism_auto);
  statusbarstretch_mode: integer = Ord(ism_auto);

implementation

uses
  d_fpc,
  doomdef,
  am_map,
  r_data,
  r_draw,
  r_hires,
  r_main,
  st_stuff,
  v_video;

function V_GetISMPct(var mode: integer): integer;
begin
  mode := ibetween(mode, Ord(ism_none), Ord(ism_max) - 1);
  case mode of
    Ord(ism_5): result := 5;
    Ord(ism_10): result := 10;
    Ord(ism_15): result := 15;
    Ord(ism_20): result := 20;
    Ord(ism_25): result := 25;
    Ord(ism_30): result := 30;
    Ord(ism_40): result := 40;
    Ord(ism_50): result := 50;
    Ord(ism_auto):
      begin
        if fullscreen and fullscreenexclusive then
        begin
          result := Round((1 - (4 / 3) / (SCREENWIDTH / SCREENHEIGHT)) * 100);
        end
        else if fullscreen then
        begin
          result := Round((1 - (4 / 3) / (NATIVEWIDTH / NATIVEHEIGHT)) * 100);
        end
        else
        begin
          result := Round((1 - (4 / 3) / (WINDOWWIDTH / WINDOWHEIGHT)) * 100);
        end
      end;
  else
    result := 0;
  end;
end;

procedure V_DoIntermissionStretch(const pct: integer);
var
  x, y: integer;
  bufb, pb: PByteArray;
  bufl, pl: PLongWordArray;
  start, stop: integer;
begin
  if (pct <= 0) or (pct >= 100) then
    exit;

  start := (pct div 2) * SCREENWIDTH div 100;
  stop := SCREENWIDTH - start;

  if videomode = vm32bit then
  begin
    bufl := mallocz(SCREENWIDTH * SizeOf(LongWord));

    for x := 0 to SCREENHEIGHT - 1 do
    begin
      pl := @screen32[x * SCREENWIDTH];
      for y := start to stop do
        bufl[y] := pl[ibetween(SCREENWIDTH * (y - start) div (stop - start + 1), 0, SCREENWIDTH - 1)];
      memcpy(pl, bufl, SCREENWIDTH * SizeOf(LongWord));
    end;

    memfree(bufl, SCREENWIDTH * SizeOf(LongWord));
  end
  else
  begin
    bufb := malloc(SCREENWIDTH * SizeOf(byte));

    for x := 0 to start - 1 do
      bufb[x] := aprox_black;
    for x := stop + 1 to SCREENWIDTH - 1 do
      bufb[x] := aprox_black;

    for x := 0 to SCREENHEIGHT - 1 do
    begin
      pb := @screens[SCN_FG][x * SCREENWIDTH];
      for y := start to stop do
        bufb[y] := pb[ibetween(SCREENWIDTH * (y - start) div (stop - start + 1), 0, SCREENWIDTH - 1)];
      memcpy(pb, bufb, SCREENWIDTH * SizeOf(byte));
    end;

    memfree(bufb, SCREENWIDTH * SizeOf(byte));
  end;
end;

procedure V_IntermissionStretch;
var
  pct: integer;
begin
  pct := V_GetISMPct(intermissionstretch_mode);
  V_DoIntermissionStretch(pct);
end;

procedure V_DoStatusBarStretch(const pct: integer);
var
  x, y: integer;
  bufb, pb: PByteArray;
  bufl, pl: PLongWordArray;
  start, stop: integer;
  l: integer;
begin
  if (pct <= 0) or (pct >= 100) or (screenblocks > 10) then
     if not (amstate = am_only) then
       exit;

  R_FillBackStatusbar;

  l := ((pct div 2) * 320) div 100;
  start := l * SCREENWIDTH div 320;
  stop := SCREENWIDTH - start;

  if videomode = vm32bit then
  begin
    bufl := mallocz(SCREENWIDTH * SizeOf(LongWord));

    for x := V_PreserveY(ST_Y) to SCREENHEIGHT - 1 do
    begin
      pl := @screen32[x * SCREENWIDTH];
      for y := start to stop do
        bufl[y] := pl[ibetween(SCREENWIDTH * (y - start) div (stop - start + 1), 0, SCREENWIDTH - 1)];
      memcpy(pl, bufl, SCREENWIDTH * SizeOf(LongWord));
    end;

    memfree(bufl, SCREENWIDTH * SizeOf(LongWord));
  end
  else
  begin
    bufb := mallocz(SCREENWIDTH * SizeOf(byte));

    for x := 0 to start - 1 do
      bufb[x] := aprox_black;
    for x := stop + 1 to SCREENWIDTH - 1 do
      bufb[x] := aprox_black;

    for x := V_PreserveY(ST_Y) to SCREENHEIGHT - 1 do
    begin
      pb := @screens[SCN_FG][x * SCREENWIDTH];
      for y := start to stop do
        bufb[y] := pb[ibetween(SCREENWIDTH * (y - start) div (stop - start + 1), 0, SCREENWIDTH - 1)];
      memcpy(pb, bufb, SCREENWIDTH * SizeOf(byte));
    end;

    memfree(bufb, SCREENWIDTH * SizeOf(byte));
  end;

  if amstate <> am_only then
  begin
    V_CopyRect(0, 0, SCN_ST2, l, ST_HEIGHT, 0, ST_Y, SCN_FG, true);
    V_CopyRect(320 - l, 0, SCN_ST2, l, ST_HEIGHT, 320 - l, ST_Y, SCN_FG, true);
  end;
end;

procedure V_StatusBarStretch;
var
  pct: integer;
begin
  pct := V_GetISMPct(statusbarstretch_mode);
  V_DoStatusBarStretch(pct);
end;

end.

