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
 - Custom defined actors (ACTORDEF)

History - Change log
--------------------
Support for the wait keyword in ACTORDEF.
Corrected states initialization for DEHEXTRA.
Faster and safer thread de-allocation.
Fixed bug in png image handling.
Fixed bug that could rarely cause infinite loop in DEHACKED lumps.
Recognizes multiple SUBMITNEWFRAMES commands in DEHACKED.
Fixed potential memory corruption problem in R_MakeSpans() in 4k resolution.

version 1.13.17.133 (20210110)
------------------------------
Key bindings can now accept SHIFT & CTRL keys.
Displays a warning if no player start found.
A_Detonate(), A_Mushroom(), A_BetaSkullAttack() & A_FireOldBFG() codepointers.
Extra sprites for use in Dehacked.
100 extra mobjinfo for use in Dehacked.
Extra states (up to 4000) for use in Dehacked.
Added -noactordef command line parameter, prevent parsing of ACTORDEF lumps.
Added -nodehextra command line parameter, prevent creating additional states & things for DEHEXTRA.
Extra sounds for Dehacked FRE000-FREE199 (indexed at 500-699).
Support for multiple DEHACKED files inside WAD.
No delay to return to desktop when finished.
Does not play menu sound on end screen.
Added A_Spawn, A_Face, A_Scratch, A_RandomJump & A_LineEffect functions.

version 1.13.16.128 (20201228)
------------------------------
Corrected dehacked parsing of the "CODEP FRAME" keyword.
Prevent infinite loop for erronous A_Chase() placement.
Fixed serious bug while deallocating thinkers.

Version 1.12.6.127 (20200630)
----------------------------
Avoid crash in false ML_TWOSIDED flag in P_RecursiveSound()
Fixes to uncapped framerate, runs smoother.

Version 1.12.6.126 (20200405)
----------------------------
Added check to avoid crash in linedefs without front side.
Billboard sky mode.
Corrected typos in the camera menu.
Changed Zaxis uncapped framerate logic.

Version 1.12.6.125 (20200202)
----------------------------
New logic in uncapped framerate calculations. Runs smoother.

Version 1.12.6.124 (20200124)
----------------------------
Fixed glitch in sky drawing, it was ignoring visplanes with 1 px height.
Fixed volume in midi files.
Support for extended help screens (HELP01 thru HELP99). See also https://www.doomworld.com/forum/topic/111465-boom-extended-help-screens-an-undocumented-feature/
Fixed glitches in sprite drawing.

Version 1.12.5.121 (20191230)
----------------------------
Fixed uncapped framerate glitch in teleporting monsters.

Version 1.12.5.120 (20191217)
----------------------------
Added option in the Menu to change the key for upper level menu from BACKSPACE to ESC as suggested by slayermbm (Options/Controls/Go to upper level menu).
Key bindings for weapon select.
Stops music in ENDOOM screen.
Added freeze console command
Fixed transparency in 8 bit color mode.
Renderstyle ADD & RenderStyle translucent
Added +monster and +projectile keywords in ACTORDEF
Added replaces keyword in ACTORDEF
Support "-" before a flag to remove it in ACTORDEF flags.
Support for SCALE keyword in ACTOR definitions inside ACTORDEF lumps. Default is 1.0
Added A_SpawnItemEx ACTORDEF function.


Version 1.12.4.118 (20191203)
----------------------------
Fixed non working plats & ceilings (thanks to slayermbm - https://www.doomworld.com/forum/topic/98789-fpcdoom-1124117-updated-dec-2-2019/?do=findComment&comment=2050845)

Version 1.12.4.117 (20191202)
----------------------------
Fixed music volume control. Now changing the music volume, does not affect the sfx volume.

Version 1.12.4.116 (20191201)
----------------------------
Corrections to menu thermo drawing.
The chase camera z can be changed in steps of 4 instead of 8 from the menu.
Fixed bug in DOOM2 map06. 

Version 1.12.4.115 (20191124)
----------------------------
Fixes to sky drawing.

Version 1.12.3.114 (20191122)
----------------------------
MAX screen resolution raised up to 4096x2560.
Openings are dynamically allocated, depending on screen resolution.
Mouse x/y sensitivities are now saved correctly to the defaults file.
Added displaydiskbusyicon console variable. When is set to true it will display the disk busy icon.
Customizable fullscreen HUD. (Options/Display/Appearence/HUD menu)
Fullscreen mode can be shared or exclusive. 
Fullscreen setting moved from Options/Display/Advanced to Options/Detail menu.
Teleport zoom effect. Added useteleportzoomeffect console variable. Can be set thru the menu (Options/Compatibility). 
Added lowrescolumndraw & lowresspandraw console variables. When are set to true, the rendering accuracy drops to gain performance.
Added weaponbobstrengthpct console variable. Controls the weapon bob strength effect. Can be set from 0% to 150%. Default is 100%.
Changed the drawfps console variable's default value to false.
Changed the zaxisshift (Look Up/Down) console variable's default value to false.
Configurable sky stretch when look up/down is enabled. (Options/Display/Advanced/Camera, console variable skystretch_pct)
Zaxisshift option renamed to Look Up/Down and moved to Options/Display/Advanced/Camera menu.
Chase camera position can be configured thru the menus. (Options/Display/Advanced/Camera, console variables chasecamera_viewxy & chasecamera_viewz)
New menu for setting the aspect ratio (Options/Display/Advanced/Aspect Ratio).
Intermission screens aspect ratio correction. Can be configured from the menu. (Options/Display/Advanced/Aspect ratio)
Statusbar aspect ratio correction. Can be configured from the menu. (Options/Display/HUD)
Added setrenderingthreads console variable. When not zero it will force the number of threads to use for rendering. Can be configured thru the menu (Options/Display Options/Advanced). Note that rendering threads must be at least 2 no more than 256.
By using SHIFT + ENTER in a menu choice, the setting is changed backwards. This applies to slides & multiple settings menu items.
Mirror mode can be configured from Options/Display/Advanced/Mirror menu. Added option for sky mirror.
Portions of source code reformated to prepare alternate executable targets (win 64bit & maybe linux).

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


