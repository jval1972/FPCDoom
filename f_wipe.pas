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

unit f_wipe;

interface

procedure wipe_StartScreen;

procedure wipe_EndScreen;

function wipe_Ticker(ticks: integer): boolean;

type
  wipestyle_t = (
    // weird screen melt
    wipestyle_Melt,
    // fade
    wipestyle_Fade,
    // slide down
    wipestyle_SlideDown,
    // Wolf3D
    wipestyle_Fizzle,
    NUMWIPESTYLES
  );

var
  wipestyle: integer = Ord(wipestyle_Melt);

implementation

uses
  d_fpc,
  doomdef,
  m_rnd,
  m_fixed,
  r_hires,
  i_video,
  v_video,
  z_memory;

//
//                       SCREEN WIPE PACKAGE
//

var
  wipe_scr_start: PLongWordArray;
  wipe_scr_end: PLongWordArray;
  wipefrac: fixed_t = 0;

var
  yy: Pfixed_tArray;
  vy: fixed_t;

type
  fizzlearray_t = array[0..319, 0..199] of integer;
  Pfizzlearray_t = ^fizzlearray_t;

var
  fizzlearray: Pfizzlearray_t;

procedure wipe_initMelt;
var
  i, r: integer;
  py, py1: Pfixed_t;
  SHEIGHTS: array[0..MAXWIDTH - 1] of integer;
  RANDOMS: array[0..319] of byte;
  x, y: LongWord;
  rndval: LongWord;
  lsb: byte;
  step: integer;
begin
  for i := 0 to SCREENWIDTH - 1 do
    SHEIGHTS[i] := Trunc(i * 320 / SCREENWIDTH);
  for i := 0 to 319 do
    RANDOMS[i] := I_Random;

  wipefrac := FRACUNIT;

  // copy start screen to main screen
  memcpy(screen32, wipe_scr_start, SCREENWIDTH * SCREENHEIGHT * SizeOf(LongWord));

  // setup initial column positions
  // (y<0 => not ready to scroll yet)
  yy := Z_Malloc(SCREENWIDTH * SizeOf(fixed_t), PU_STATIC, nil);
  py := @yy[0];
  py1 := py;

  py^ := -(RANDOMS[0] mod 16);
  for i := 1 to SCREENWIDTH - 1 do
  begin
    inc(py);
    r := (RANDOMS[SHEIGHTS[i]] mod 3) - 1;
    py^ := py1^ + r;
    if py^ > 0 then
      py^ := 0
    else if py^ = -16 then
      py^ := -15;
    inc(py1);
  end;

// JVAL change wipe timing
  vy := FRACUNIT * SCREENHEIGHT div 200;
  py := @yy[0];
  for i := 0 to SCREENWIDTH - 1 do
  begin
    py^ := py^ * vy;
    inc(py);
  end;
  
  for i := 1 to SCREENWIDTH - 1 do
    if SHEIGHTS[i - 1] = SHEIGHTS[i] then
      yy[i] := yy[i - 1];

// Setup fizzle table
// Algorithm by Fabien Sanglard
// Adapted from http://fabiensanglard.net/fizzlefade/index.php
  step := 0;
  fizzlearray := Z_Malloc(SizeOf(fizzlearray_t), PU_STATIC, nil);
  rndval := 1;
  repeat
    y := rndval and $FF;
    x := (rndval and $1FF00) shr 8;
    lsb  := rndval and 1;
    rndval := rndval shr 1;
    if lsb <> 0 then
      rndval := rndval xor $12000;
    if (x < 320) and (y < 200) then
    begin
      fizzlearray[x, y] := step;
      inc(step);
    end;
  until rndval = 1;
end;

function wipe_doMelt(ticks: integer): integer;
var
  i: integer;
  j: integer;
  dy: fixed_t;
  sidx: PLongWord;
  didx: PLongWord;
  py: Pfixed_t;
  pos: integer;
begin
  result := 1;

  while ticks > 0 do
  begin
    py := @yy[0];
    for i := 0 to SCREENWIDTH - 1 do
    begin
      if py^ < 0 then
      begin
        py^ := py^ + vy;
        result := 0;
      end
      else if py^ < SCREENHEIGHT * FRACUNIT then
      begin
        if py^ <= 15 * vy then
          dy := py^ + vy
        else
          dy := 8 * vy;
        if (py^ + dy) >= SCREENHEIGHT * FRACUNIT then
          dy := SCREENHEIGHT * FRACUNIT - py^;
        if ticks = 1 then
        begin
          pos := py^ div FRACUNIT;
          sidx := @wipe_scr_end[i];
          didx := @screen32[i];
          for j := 0 to pos - 1 do
          begin
            didx^ := sidx^;
            inc(didx, SCREENWIDTH);
            inc(sidx, SCREENWIDTH);
          end;
          sidx := @wipe_scr_start[i];
          for j := pos to SCREENHEIGHT - 1 do
          begin
            didx^ := sidx^;
            inc(didx, SCREENWIDTH);
            inc(sidx, SCREENWIDTH);
          end;
        end;

        py^ := py^ + dy;

        result := 0;
      end;
      inc(py);
    end;
    dec(ticks);
  end;
end;

function wipe_doFade(ticks: integer): integer;
var
  i: integer;
begin
  result := 1;

  if wipefrac = 0 then
    exit;

  wipefrac := wipefrac - ticks * 4096;
  if wipefrac < 0 then
    wipefrac := 0;

  for i := 0 to SCREENWIDTH * SCREENHEIGHT - 1 do
    screen32[i] := R_ColorAverageAlpha(wipe_scr_end[i], wipe_scr_start[i], wipefrac);

  if wipefrac > 0 then
    result := 0;
end;

function wipe_doSlideDown(ticks: integer): integer;
var
  i: integer;
  y: integer;
begin
  result := 1;

  if wipefrac = 0 then
    exit;

  wipefrac := wipefrac - ticks * 3121;
  if wipefrac < 0 then
    wipefrac := 0;

  y := SCREENHEIGHT - Trunc(wipefrac * SCREENHEIGHT / FRACUNIT);

  for i := 0 to y * SCREENWIDTH - 1 do
    screen32[i] := wipe_scr_end[SCREENWIDTH * (SCREENHEIGHT - y) + i];
  for i := y * SCREENWIDTH to SCREENWIDTH * SCREENHEIGHT - 1 do
    screen32[i] := wipe_scr_start[i - y * SCREENWIDTH];

  if wipefrac > 0 then
    result := 0;
end;

function wipe_doFizzle(ticks: integer): integer;
var
  x, y: integer;
  fizzfrac: integer;
  idx: integer;
begin
  result := 1;

  if wipefrac = 0 then
    exit;

  wipefrac := wipefrac - ticks * 4096;

  if wipefrac < 0 then
    wipefrac := 0;

  fizzfrac := Round(wipefrac / (320 * 200) * FRACUNIT);

  for x := 0 to SCREENWIDTH  - 1 do
    for y := 0 to SCREENHEIGHT - 1 do
    begin
      idx := y * SCREENWIDTH + x;
      if fizzlearray[Trunc(x * 320 / SCREENWIDTH), Trunc(y * 200 / SCREENHEIGHT)] > fizzfrac then
        screen32[idx] := wipe_scr_end[idx]
      else
        screen32[idx] := wipe_scr_start[idx]
    end;

  if wipefrac > 0 then
    result := 0;
end;

procedure wipe_exitMelt;
begin
  Z_Free(yy);
  Z_Free(fizzlearray);
  memfree(wipe_scr_start, SCREENWIDTH * SCREENHEIGHT * SizeOf(LongWord));
  memfree(wipe_scr_end, SCREENWIDTH * SCREENHEIGHT * SizeOf(LongWord));
end;

procedure wipe_StartScreen;
begin
  wipe_scr_start := malloc(SCREENWIDTH * SCREENHEIGHT * SizeOf(LongWord));
  I_ReadScreen32(wipe_scr_start);
end;

procedure wipe_EndScreen;
begin
  wipe_scr_end := malloc(SCREENWIDTH * SCREENHEIGHT * SizeOf(LongWord));
  I_ReadScreen32(wipe_scr_end);
end;

// when zero, stop the wipe
var
  wiping: boolean = false;

type
  wipeproc_t = function (ticks: integer): integer;

function wipe_Ticker(ticks: integer): boolean;
var
  wipeproc: wipeproc_t;
begin
  // initial stuff
  if not wiping then
  begin
    wiping := true;
    wipe_initMelt;
  end;

  case wipestyle of
    Ord(wipestyle_Melt): wipeproc := @wipe_doMelt;
    Ord(wipestyle_Fade): wipeproc := @wipe_doFade;
    Ord(wipestyle_SlideDown): wipeproc := @wipe_doSlideDown;
    Ord(wipestyle_Fizzle): wipeproc := @wipe_doFizzle;
  else
    wipeproc := @wipe_doMelt;
  end;

  // do a piece of wipe-in
  if wipeproc(ticks) <> 0 then
  begin
    // final stuff
    wiping := false;
    wipe_exitMelt;
  end;

  result := not wiping;
end;

end.
