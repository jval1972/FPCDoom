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

unit m_defs;

interface

uses
  am_map,
  c_con,
  doomdef,
  d_english,
  e_endoom,
  f_wipe,
  g_game,
  hu_stuff,
  p_mobj_h, 
  p_terrain,
  p_telept,
  p_enemy,
  p_saveg,
  p_pspr,
  i_video, 
  i_system, 
  i_music,
  i_sound,
  m_menu,
  m_misc,
  r_aspect,
  r_defs,
  r_draw,
  r_draw_column,
  r_draw_span,
  r_lightmap,
  r_main,
  r_mirror,
  r_grayscale,
  r_colorsubsampling,
  r_hires,
  r_intrpl,
  r_render,
  r_sky,
  st_stuff,
  s_sound,
  t_main,
  v_intermission,
  v_video;

const
  DFS_NEVER = 0;
  DFS_SINGLEPLAYER = 1;
  DFS_NETWORK = 2;
  DFS_ALWAYS = 3;

type
  ttype_t = (tString, tInteger, tBoolean, tGroup);

  default_t = record
    name: string;
    location: pointer;
    setable: byte;
    defaultsvalue: string;
    defaultivalue: integer;
    defaultbvalue: boolean;
    _type: ttype_t;
  end;
  Pdefault_t = ^default_t;

const
  NUMDEFAULTS = 149;

  defaults: array[0..NUMDEFAULTS - 1] of default_t = (
    (name: 'Display';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'windowwidth';
     location: @WINDOWWIDTH;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: -1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'windowheight';
     location: @WINDOWHEIGHT;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: -1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'screenwidth';
     location: @SCREENWIDTH;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 640;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'screenheight';
     location: @SCREENHEIGHT;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 400;
     defaultbvalue: false;
     _type: tInteger),

     (name: 'fullscreen';
      location: @fullscreen;
      setable: DFS_NEVER;
      defaultsvalue: '';
      defaultivalue: 1;
      defaultbvalue: true;
      _type: tBoolean),

    (name: 'fullscreenexclusive';
     location: @fullscreenexclusive;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'interpolate';
     location: @interpolate;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'fixstallhack';
     location: @fixstallhack;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: '32bittexturepaletteeffects';
     location: @dc_32bittexturepaletteeffects;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'zaxisshift';
     location: @zaxisshift;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'skystretch_pct';
     location: @skystretch_pct;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 50;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'billboardsky';
     location: @billboardsky;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'chasecamera';
     location: @chasecamera;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'chasecamera_viewxy';
     location: @chasecamera_viewxy;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 64;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'chasecamera_viewz';
     location: @chasecamera_viewz;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 16;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'drawfps';
     location: @drawfps;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'wipestyle';
    location: @wipestyle;
    setable: DFS_ALWAYS;
    defaultsvalue: '';
    defaultivalue: 0;
    defaultbvalue: true;
    _type: tInteger),

    (name: 'shademenubackground';
     location: @shademenubackground;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'menubackgroundflat';
     location: @menubackgroundflat;
     setable: DFS_ALWAYS;
     defaultsvalue: DEFMENUBACKGROUNDFLAT;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'displaydiskbusyicon';
     location: @displaydiskbusyicon;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'displayendscreen';
     location: @displayendscreen;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'screenblocks';
     location: @screenblocks;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 11;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'detaillevel';
     location: @detailLevel;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: DL_NORMAL;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'lowrescolumndraw';
     location: @lowrescolumndraw;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'lowresspandraw';
     location: @lowresspandraw;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'uselightmap';
     location: @uselightmap;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'lightmapaccuracymode';
     location: @lightmapaccuracymode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'lightmapcolorintensity';
     location: @lightmapcolorintensity;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 64;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'lightwidthfactor';
     location: @lightwidthfactor;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 5;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'usegamma';
     location: @usegamma;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'forcecolormaps';
     location: @forcecolormaps;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'use32bitfuzzeffect';
     location: @use32bitfuzzeffect;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'usetransparentsprites';
     location: @usetransparentsprites;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'widescreensupport';
     location: @widescreensupport;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'excludewidescreenplayersprites';
     location: @excludewidescreenplayersprites;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'forcedaspect';
     location: @forcedaspectstr;
     setable: DFS_NEVER;
     defaultsvalue: '16/10';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'vid_pillarbox_pct';
     location: @vid_pillarbox_pct;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'vid_letterbox_pct';
     location: @vid_letterbox_pct;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'intermissionstretch_mode';
     location: @intermissionstretch_mode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: Ord(ism_auto);
     defaultbvalue: false;
     _type: tInteger),

    (name: 'statusbarstretch_mode';
     location: @statusbarstretch_mode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: Ord(ism_auto);
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mirrormode';
     location: @mirrormode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'grayscalemode';
     location: @grayscalemode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'colorsubsamplingmode';
     location: @colorsubsamplingmode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'HUD';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'custom_fullscreenhud';
     location: @custom_fullscreenhud;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'custom_fullscreenhud_size';
     location: @custom_fullscreenhud_size;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'custom_hudhelthpos';
     location: @custom_hudhelthpos;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: -1;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'custom_hudarmorpos';
     location: @custom_hudarmorpos;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: -1;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'custom_hudammopos';
     location: @custom_hudammopos;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'custom_hudkeyspos';
     location: @custom_hudkeyspos;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: -1;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'Automap';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'allowautomapoverlay';
     location: @allowautomapoverlay;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

     (name: 'allowautomaprotate';
      location: @allowautomaprotate;
      setable: DFS_ALWAYS;
      defaultsvalue: '';
      defaultivalue: 0;
      defaultbvalue: true;
      _type: tBoolean),

     (name: 'automapgrid';
      location: @automapgrid;
      setable: DFS_ALWAYS;
      defaultsvalue: '';
      defaultivalue: 0;
      defaultbvalue: false;
      _type: tBoolean),

     // Textures
    (name: 'Textures';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'useexternaltextures';
     location: @useexternaltextures;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'preferetexturesnamesingamedirectory';
     location: @preferetexturesnamesingamedirectory;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'extremeflatfiltering';
     location: @extremeflatfiltering;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'smoothskies';
     location: @smoothskies;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

     // Compatibility
    (name: 'Compatibility';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'compatibilitymode';
     location: @compatibilitymode;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'keepcheatsinplayerreborn';
     location: @keepcheatsinplayerreborn;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'allowplayerjumps';
     location: @allowplayerjumps;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'majorbossdeathendsdoom1level';
     location: @majorbossdeathendsdoom1level;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'allowterrainsplashes';
     location: @allowterrainsplashes;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'useteleportzoomeffect';
     location: @useteleportzoomeffect;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'continueafterplayerdeath';
     location: @continueafterplayerdeath;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'loadtracerfromsavedgame';
     location: @loadtracerfromsavedgame;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'loadtargetfromsavedgame';
     location: @loadtargetfromsavedgame;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'weaponbobstrengthpct';
     location: @weaponbobstrengthpct;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 100;
     defaultbvalue: true;
     _type: tInteger),

     // Controls
    (name: 'Controls';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'autorunmode';
     location: @autorunmode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'menukeyescfunc';
     location: @menukeyescfunc;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'Keyboard';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'key_right';
     location: @key_right;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RIGHTARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_left';
     location: @key_left;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_LEFTARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_up';
     location: @key_up;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_UPARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_down';
     location: @key_down;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_DOWNARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_strafeleft';
     location: @key_strafeleft;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord(',');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_straferight';
     location: @key_straferight;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('.');
     defaultbvalue: false;
     _type: tInteger),

     // JVAL Jump
    (name: 'key_jump';
     location: @key_jump;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('a');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_fire';
     location: @key_fire;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RCTRL;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_use';
     location: @key_use;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord(' ');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_strafe';
     location: @key_strafe;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RALT;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_speed';
     location: @key_speed;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RSHIFT;
     defaultbvalue: false;
     _type: tInteger),

     // JVAL Look UP and DOWN using z-axis shift
    (name: 'key_lookup';
     location: @key_lookup;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_PAGEDOWN;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookdown';
     location: @key_lookdown;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_DELETE;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookcenter';
     location: @key_lookcenter;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_INS;
     defaultbvalue: false;
     _type: tInteger),

     // JVAL Look LEFT/RIGHT
    (name: 'key_lookright';
     location: @key_lookright;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_PAGEUP;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookleft';
     location: @key_lookleft;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_HOME;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookforward';
     location: @key_lookforward;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_ENTER;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon0';
     location: @key_weapon0;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('1');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon1';
     location: @key_weapon1;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('2');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon2';
     location: @key_weapon2;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('3');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon3';
     location: @key_weapon3;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('4');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon4';
     location: @key_weapon4;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('5');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon5';
     location: @key_weapon5;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('6');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon6';
     location: @key_weapon6;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('7');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_weapon7';
     location: @key_weapon7;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('8');
     defaultbvalue: false;
     _type: tInteger),

     // Mouse
    (name: 'Mouse';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'use_mouse';
     location: @usemouse;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'mouse_sensitivity';
     location: @mouseSensitivity;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 5;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mouse_sensitivityx';
     location: @mouseSensitivityX;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 5;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mouse_sensitivityy';
     location: @mouseSensitivityY;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 5;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'invertmouselook';
     location: @invertmouselook;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'invertmouseturn';
     location: @invertmouseturn;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'mouseb_fire';
     location: @mousebfire;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mouseb_strafe';
     location: @mousebstrafe;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mouseb_forward';
     location: @mousebforward;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 2;
     defaultbvalue: false;
     _type: tInteger),

     // Joystick
    (name: 'Joystick';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'use_joystick';
     location: @usejoystick;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'joyb_fire';
     location: @joybfire;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_strafe';
     location: @joybstrafe;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_use';
     location: @joybuse;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 3;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_speed';
     location: @joybspeed;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 2;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_jump';
     location: @joybjump;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 4;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_lookleft';
     location: @joyblleft;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 6;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_lookright';
     location: @joyblright;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 7;
     defaultbvalue: false;
     _type: tInteger),

     // Sound
    (name: 'Sound';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'snd_channels';
     location: @numChannels;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 6;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'sfx_volume';
     location: @snd_SfxVolume;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 15;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'music_volume';
     location: @snd_MusicVolume;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 8;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'miditempo';
     location: @miditempo;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 160;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'useexternalwav';
     location: @useexternalwav;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'preferewavnamesingamedirectory';
     location: @preferewavnamesingamedirectory;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

     // Console
    (name: 'Console';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'console_colormap';
     location: @ConsoleColormap;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: NUMCOLORMAPS div 2;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mirror_stdout';
     location: @mirror_stdout;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'keepsavegamename';
     location: @keepsavegamename;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

     // Messages
    (name: 'show_messages';
     location: @showMessages;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'Chat strings';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'chatmacro0';
     location: @chat_macros[0];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO0;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro1';
     location: @chat_macros[1];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO1;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro2';
     location: @chat_macros[2];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO2;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro3';
     location: @chat_macros[3];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO3;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro4';
     location: @chat_macros[4];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO4;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro5';
     location: @chat_macros[5];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO5;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro6';
     location: @chat_macros[6];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO6;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro7';
     location: @chat_macros[7];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO7;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro8';
     location: @chat_macros[8];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO8;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro9';
     location: @chat_macros[9];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO9;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'Randomizer';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'spawnrandommonsters';
     location: @spawnrandommonsters;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

     // System
    (name: 'System';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'safemode';
     location: @safemode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'usemmx';
     location: @usemmx;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'screenshottype';
     location: @screenshottype;
     setable: DFS_ALWAYS;
     defaultsvalue: 'png';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tString),

    (name: 'setrenderingthreads';
     location: @setrenderingthreads;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger)

  );

implementation

end.
