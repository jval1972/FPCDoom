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

unit v_screenresolution;

interface

function V_SetScreenResolution(const newwidth, newheight: integer): boolean;

implementation

uses
  am_map,
  doomdef,
  c_con,
  i_video,
  r_main,
  r_zbuffer,
  r_draw,
  r_draw_column,
  r_draw_light,
  r_externaltextures,
  r_things,
  r_render,
  r_plane,
  v_video;

function V_SetScreenResolution(const newwidth, newheight: integer): boolean;
var
  nwidth, nheight: integer;
begin
  result := false;

  if (SCREENWIDTH = newwidth) and (SCREENHEIGHT = newheight) then
    exit;

  nwidth := newwidth and not 1;
  if nwidth > MAXWIDTH then
    nwidth := MAXWIDTH
  else if nwidth < MINWIDTH then
    nwidth := MINWIDTH;

  nheight := newheight and not 1;
  if nheight > MAXHEIGHT then
    nwidth := MAXHEIGHT
  else if nheight < MINHEIGHT then
    nheight := MINHEIGHT;

  if nheight > nwidth then
    nheight := nwidth;

  if (SCREENWIDTH <> nwidth) or (SCREENHEIGHT <> nheight) then
  begin
    R_WaitTasks;             // Wait for running rendering tasks
    R_ShutDownZBuffer;       // Shut down depthbuffer
    R_ShutDownLightmap;      // Shut down lightmap
    R_ClearVisPlanes;        // Clear visplanes (free ::top & ::bottom arrays)
    R_Clear32Cache;          // JVAL: unneeded ?
    AM_Stop;                 // Stop the automap

    I_ShutDownGraphics;      // Shut down graphics

    SCREENWIDTH := nwidth;
    SCREENHEIGHT := nheight;

    V_ReInit;                // Recreate screens

    I_InitGraphics;          // Initialize graphics

    needsstatusbarback := true; // Redraw statusbar background
    AM_Start;                // Start the automap
    C_AdjustScreenSize;
    setsizeneeded := true;   // Set-up new SCREENWIDTH & SCREENHEIGHT
    R_InitZBuffer;           // Initialize the depth-buffer
    R_InitLightmap;          // Initialize the lightmap
    R_InitFuzzTable;         // Re-calculate fuzz tabble offsets
    R_InitNegoArray;         // Re-calculate the nego-array
    result := true;
  end;
end;

end.

