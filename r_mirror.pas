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

unit r_mirror;

interface

uses
  d_fpc;

const
  MR_NONE = 0;
  MR_ENVIROMENT = 1;
  MR_WEAPON = 2;
  MR_SKY = 4;

var
  mirrormode: integer = 0;

// Mirror buffer - 8 bit
procedure R_MirrorBuffer8(const y: PInteger);

// Mirror buffer - 32 bit
procedure R_MirrorBuffer32(const y: PInteger);

procedure R_MirrorBuffer;

implementation

uses
  r_draw,
  r_main,
  r_render;

// Mirror buffer - 8 bit
procedure R_MirrorBuffer8(const y: PInteger);
var
  i: integer;
  pb: PByteArray;
  tmp: byte;
begin
  pb := @((ylookup8[y^]^)[columnofs[0]]);
  for i := 0 to viewwidth div 2 - 1 do
  begin
    tmp := pb[i];
    pb[i] := pb[viewwidth - i - 1];
    pb[viewwidth - i - 1] := tmp;
  end;
end;

// Mirror buffer - 32 bit
procedure R_MirrorBuffer32(const y: PInteger);
var
  i: integer;
  pl: PLongWordArray;
  tmp: LongWord;
begin
  pl := @((ylookup32[y^]^)[columnofs[0]]);
  for i := 0 to viewwidth div 2 - 1 do
  begin
    tmp := pl[i];
    pl[i] := pl[viewwidth - i - 1];
    pl[viewwidth - i - 1] := tmp;
  end;
end;

procedure R_MirrorBuffer;
var
  y: integer;
begin
  for y := 0 to viewheight - 1 do
    R_AddRenderTask(mirrorfunc, RF_MIRRORBUFFER, @y);
end;


end.

