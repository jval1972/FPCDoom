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

This is a source port of the game Doom developed in FPC/Lazarus.

Features:
 - High screen resolutions
 - Improved light effects
 - Dynamic lightmap
 - Uncapped framerate
 - Multithreading rendering
 - Automap rotation & overlay
 - Console to execute commands
 - Raised static limits
 - Dehacked/BEX support

History - Change log
--------------------

MAX screen resolution raised up to 4096x2560.
Openings are dynamically allocated, depending on screen resolution.
Mouse x/y sensitivities are now saved correctly to the defaults file.
Added displaydiskbusyicon console variable. When is set to true it will display the disk busy icon.
BACKUPTICS limit raised from 12 to 64.
Customizable fullscreen HUD. (Options/Display/Appearence/HUD menu)

Version 1.12.2.100 (20191112)
----------------------------
Support for DOOMWADPATH enviroment variable.
Search for installed steam applications to find wad files.
Light effects optimizations.
Change screen resolution from the menu.
Screenshots in png format, option to change screenshot format.
Fixed automap grid rotation. Grid can be enabled from the Menu (Options/Display/Automap) & will be preserved in defaults file.
Fixed the behaviour of allowautomapoverlay console variable.
Fixed "stairs create unknown sector types" bug (https://doomwiki.org/wiki/Stairs_create_unknown_sector_types)
Removed limit on intercepts.
Preserve target and tracer of mobj in saved games. Added loadtracerfromsavedgame & loadtargetfromsavedgame console variables. 
Added wipe styles: fade, slide down and fizzle. Added wipestyle console variable. Can be changed from the Menu (Options/Display/Appearence) & will be preserved in defaults file.
Mouse sensitivities (global, x axis & y axis) moved to a separate submenu in Controls menu.

Version 1.12.1.76 (20191029)
----------------------------
Fixes to the PNG texture loading.
Better support for midi files.
Multithreading rendering.
Improved light effects (lightmap).
Mirror mode with demo compatibility.
Grayscale mode.
Color reduction effect.
X-Axis & Y-Axis mouse sensitivity.
Key bindings for player control.

Version 1.11.1.38 (20180128)
----------------------------
Small fixes to player sprites drawing

Version 1.11.1.18 (20180114)
----------------------------
First public release


