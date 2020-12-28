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
//  Foundation, inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.
//
//------------------------------------------------------------------------------
//  E-Mail: jimmyvalavanis@yahoo.gr
//  Site  : https://sourceforge.net/projects/fpcdoom/
//------------------------------------------------------------------------------

{$I FPCDoom.inc}

unit r_colorsubsampling;

interface

uses
  d_fpc;

var
  colorsubsamplingmode: integer = 0;

// Subsampling buffer - 8 bit
procedure R_SubsamplingBuffer8(const y: PInteger);

// Subsampling buffer - 32 bit
procedure R_SubsamplingBuffer32(const y: PInteger);

procedure R_SubsamplingBuffer;

implementation

uses
  r_draw,
  r_main,
  r_trans8,
  r_render;

// Subsampling buffer - 8 bit
procedure R_SubsamplingBuffer8(const y: PInteger);
var
  i: integer;
  pb: PByteArray;
  pquant: PByteArray;
begin
  pb := @((ylookup8[y^]^)[columnofs[0]]);
  pquant := @subsampling8tables[colorsubsamplingmode];
  for i := 0 to viewwidth - 1 do
    pb[i] := pquant[pb[i]];
end;

function R_SubSample1(const c: LongWord): LongWord;
var
  r, g, b: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  r := (r shr 4) shl 4 + 8;
  g := (g shr 4) shl 4 + 8;
  b := (b shr 4) shl 4 + 8;
  result := b + g shl 8 + r shl 16;
end;

function R_SubSample2(const c: LongWord): LongWord;
var
  r, g, b: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  r := (r shr 5) shl 5 + 16;
  g := (g shr 5) shl 5 + 16;
  b := (b shr 5) shl 5 + 16;
  result := b + g shl 8 + r shl 16;
end;

function R_SubSample3(const c: LongWord): LongWord;
var
  r, g, b: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  r := (r shr 6) shl 6 + 32;
  g := (g shr 6) shl 6 + 32;
  b := (b shr 6) shl 6 + 32;
  result := b + g shl 8 + r shl 16;
end;

function R_SubSample4(const c: LongWord): LongWord;
var
  r, g, b: LongWord;
begin
  r := (c shr 16) and $ff;
  g := (c shr 8) and $ff;
  b := c and $ff;
  r := (r div 85) * 85 + 42;
  g := (g div 85) * 85 + 42;
  b := (b div 85) * 85 + 42;
  result := b + g shl 8 + r shl 16;
end;

type
  subsamplecoloritemfunc_t = function (const c: LongWord): LongWord;

var
  subsamplecoloritemfunc: subsamplecoloritemfunc_t;

// Subsampling buffer - 32 bit
procedure R_SubsamplingBuffer32(const y: PInteger);
var
  i: integer;
  pl: PLongWordArray;
begin
  pl := @((ylookup32[y^]^)[columnofs[0]]);
  for i := 0 to viewwidth - 1 do
    pl[i] := subsamplecoloritemfunc(pl[i]);
end;

procedure R_SubsamplingBuffer;
var
  y: integer;
begin
  colorsubsamplingmode := colorsubsamplingmode mod 5;
  if colorsubsamplingmode = 0 then
    exit;

  // Determine function to use
  case colorsubsamplingmode of
   1: subsamplecoloritemfunc := @R_SubSample1;
   2: subsamplecoloritemfunc := @R_SubSample2;
   3: subsamplecoloritemfunc := @R_SubSample3;
   4: subsamplecoloritemfunc := @R_SubSample4;
  end;

  for y := 0 to viewheight - 1 do
    R_AddRenderTask(subsamplecolorfunc, RF_COLORSUBSAMPLING, @y);
end;


end.

