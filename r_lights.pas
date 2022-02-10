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

unit r_lights;

interface

uses
  d_fpc;

const
  LIGHTBOOSTSIZE = 128;

type
  lpost_t = record
    topdelta: integer;
    length: integer;   // length data bytes follows
  end;
  Plpost_t = ^lpost_t;

var
  lightexturelookup: array[0..LIGHTBOOSTSIZE - 1] of lpost_t;
  lighttexture: PLongWordArray = nil;

//==============================================================================
//
// R_InitLightTexture
//
//==============================================================================
procedure R_InitLightTexture;

//==============================================================================
//
// R_ShutDownLightTexture
//
//==============================================================================
procedure R_ShutDownLightTexture;

implementation

//==============================================================================
// R_InitLightTexture
//
// R_InitLights
//
//==============================================================================
procedure R_InitLightTexture;
var
  i, j: integer;
  dist: double;
  c: LongWord;
begin
  if lighttexture = nil then
    lighttexture := PLongWordArray(malloc(LIGHTBOOSTSIZE * LIGHTBOOSTSIZE * SizeOf(LongWord)));
  for i := 0 to LIGHTBOOSTSIZE - 1 do
  begin
    lightexturelookup[i].topdelta := MAXINT;
    lightexturelookup[i].length := 0;
    for j := 0 to LIGHTBOOSTSIZE - 1 do
    begin
      dist := sqrt(sqr(i - (LIGHTBOOSTSIZE shr 1)) + sqr(j - (LIGHTBOOSTSIZE shr 1)));
      if dist <= (LIGHTBOOSTSIZE shr 1) then
      begin
        inc(lightexturelookup[i].length);
        c := Round(dist * 4);
        if c > 255 then
          c := 0
        else
          c := 255 - c;
        lighttexture[i * LIGHTBOOSTSIZE + j] := c * 255;
        if j < lightexturelookup[i].topdelta then
          lightexturelookup[i].topdelta := j;
      end
      else
        lighttexture[i * LIGHTBOOSTSIZE + j] := 0;
    end;
  end;
end;

//==============================================================================
//
// R_ShutDownLightTexture
//
//==============================================================================
procedure R_ShutDownLightTexture;
begin
  if lighttexture <> nil then
    memfree(lighttexture, LIGHTBOOSTSIZE * LIGHTBOOSTSIZE * SizeOf(LongWord));
end;

end.
