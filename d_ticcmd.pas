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

unit d_ticcmd;

interface

const
  CF_MIRROR = 1;

// The data sampled per tick (single player)
// and transmitted to other peers (multiplayer).
// Mainly movements/button commands per game tick,
// plus a checksum for internal state consistency.
type
  ticcmd_t = packed record
    forwardmove: shortint; // *2048 for move
    sidemove: shortint;    // *2048 for move
    angleturn: smallint;   // <<16 for angle delta
    consistency: smallint; // checks for net game
    chatchar: byte;
    buttons: byte;
    commands: byte;      // JVAL for special commands
    lookupdown16: word;  // JVAL Smooth Look Up/Down
    lookleftright: byte; // JVAL look left/right/forward
    jump: byte;          // JVAL Jump!
    flags: byte;         // JVAL for mirror, etc
  end;
  Pticcmd_t = ^ticcmd_t;

implementation

end.

