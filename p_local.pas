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

unit p_local;

interface

uses
  doomtype,
  m_fixed,
  p_mobj_h,
  r_defs;

const
  TOCENTER = -8;
  TOFORWARD = -8;

  FLOATSPEED = FRACUNIT * 4;

// Player VIEWHEIGHT
  PVIEWHEIGHT = 41 * FRACUNIT;

// mapblocks are used to check movement
// against lines and things
  MAPBLOCKUNITS = 128;
  MAPBLOCKSIZE = MAPBLOCKUNITS * FRACUNIT;

  MAPBLOCKSHIFT = FRACBITS + 7;
  MAPBMASK = MAPBLOCKSIZE - 1;
  MAPBTOFRAC = MAPBLOCKSHIFT - FRACBITS;

// player radius for movement checking
  PLAYERRADIUS = 16 * FRACUNIT;

// MAXRADIUS is for precalculated sector block boxes
// the spider demon is larger,
// but we do not have any moving sectors nearby
  MAXRADIUS = 32 * FRACUNIT;

  GRAVITY = FRACUNIT;
  MAXMOVE = 30 * FRACUNIT;

  USERANGEINT = 64;
  USERANGE = USERANGEINT * FRACUNIT;
  MELEERANGE = 64 * FRACUNIT;
  MISSILERANGE = (32 * 64) * FRACUNIT;

// follow a player exlusively for 3 seconds
  BASETHRESHOLD = 100;

  ONFLOORZ = MININT;
  ONCEILINGZ = MAXINT;

  ONFLOATZ = MAXINT - 1;

type
  divline_t = record
    x: fixed_t;
    y: fixed_t;
    dx: fixed_t;
    dy: fixed_t;
  end;
  Pdivline_t = ^divline_t;

  thingORline_t = record
    case integer of
      0: (thing: Pmobj_t);
      1: (line: Pline_t);
    end;

  intercept_t = record
    frac: fixed_t; // along trace line
    isaline: boolean;
    d: thingORline_t;
  end;
  Pintercept_t = ^intercept_t;
  intercept_tArray = array[0..$FFFF] of intercept_t;
  Pintercept_tArray = ^intercept_tArray;

type
  traverser_t = function(f: Pintercept_t): boolean;
  ltraverser_t = function(p: Pline_t): boolean;
  ttraverser_t = function(p: Pmobj_t): boolean;

const
  PT_ADDLINES = 1;
  PT_ADDTHINGS = 2;
  PT_EARLYOUT = 4;

//==============================================================================
//
// MapBlockInt
//
//==============================================================================
function MapBlockInt(const x: integer): integer;

//==============================================================================
//
// MapToFrac
//
//==============================================================================
function MapToFrac(const x: integer): integer;

implementation

//==============================================================================
//
// MapBlockInt
//
//==============================================================================
function MapBlockInt(const x: integer): integer; assembler;
asm
  sar eax, MAPBLOCKSHIFT
end;

//==============================================================================
//
// MapToFrac
//
//==============================================================================
function MapToFrac(const x: integer): integer; assembler;
asm
  sar eax, MAPBTOFRAC
end;

end.

