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

unit r_sky;

interface

uses
  r_hires;

// SKY, store the number for name.
const
  SKYFLATNAME = 'F_SKY1';

// The sky map is 256*128*4 maps.
  ANGLETOSKYSHIFT = 22;
  ANGLETOSKYUNIT = 1 shl 22;

const
  ORIGINALSKYSIZE = 128;
  SKYSIZE = 256;
  SKYTRNTARGETSIZE = 400;

type
  skytransarray_t = array[0..SKYSIZE * (1 shl MAXTEXTUREFACTORBITS) - 1] of integer;
  Pskytransarray_t = ^skytransarray_t;

var
  skyflatnum: integer;
  skytexture: integer;
  skytexturemid: integer;
  skystretch_pct: integer = 100;
  skytranstable: array[0..MAXTEXTUREFACTORBITS] of skytransarray_t;
  billboardsky: boolean = false;

procedure R_InitSkyMap;

procedure R_CalcSkyStretch;

implementation

uses
  d_fpc,
  doomdef,
  m_fixed; // Needed for FRACUNIT.

//
// R_InitSkyMap
// Called whenever the view size changes.
//
procedure R_InitSkyMap;
begin
  skytexturemid := 100 * FRACUNIT;
end;

var
  oldskystretch_pct: integer = -1;
  oldzaxisshift: boolean = false;
  target: PIntegerArray;

procedure R_CalcSkyStretch;
var
  i, j, x, f, d: integer;
  start, minstart: integer;
begin
  skystretch_pct := ibetween(skystretch_pct, 0, 100);
  if (skystretch_pct = oldskystretch_pct) and (zaxisshift = oldzaxisshift) then
    exit;

  oldzaxisshift := zaxisshift;
  oldskystretch_pct := skystretch_pct;

  if zaxisshift then
  begin
    f := 1 shl MAXTEXTUREFACTORBITS;
    target := mallocz(f * SKYTRNTARGETSIZE * SizeOf(integer));

    // JVAL Leave 8 * f pixels at 0 %
    minstart := f * (SKYTRNTARGETSIZE - SKYSIZE + 8);
    start := minstart + Trunc((skystretch_pct / 100) * (f * SKYTRNTARGETSIZE - minstart));

    for i := f * SKYTRNTARGETSIZE - 1 downto start do
      target[i] := i - f * SKYTRNTARGETSIZE + f * SKYSIZE;
    for i := 0 to start - 1 do
      target[i] := Trunc(i * (start - f * SKYTRNTARGETSIZE + f * SKYSIZE) / start);

    for i := f * SKYTRNTARGETSIZE - 1 downto 0 do
     skytranstable[MAXTEXTUREFACTORBITS][Trunc(i * SKYSIZE / SKYTRNTARGETSIZE)] := Trunc(target[i] * ORIGINALSKYSIZE / SKYSIZE);

    for x := 0 to MAXTEXTUREFACTORBITS - 1 do
    begin
      f := 1 shl x;
      d := 1 shl (MAXTEXTUREFACTORBITS - x);
      for i := 0 to f * SKYSIZE - 1 do
      begin
        skytranstable[x][i] := 0;
        for j := 0 to d - 1 do
          skytranstable[x][i] := skytranstable[x][i] + skytranstable[MAXTEXTUREFACTORBITS][i * d + j];
        skytranstable[x][i] := Trunc(skytranstable[x][i] / d / d);
      end;
    end;

    memfree(target, f * SKYTRNTARGETSIZE * SizeOf(integer));

  end
  else
  begin
    for x := 0 to MAXTEXTUREFACTORBITS do
    begin
      f := 1 shl x;

      for i := 0 to f * SKYSIZE - 1 do
        skytranstable[x][i] := i div 2;

    end;
  end;
end;

end.

