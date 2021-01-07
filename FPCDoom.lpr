//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
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

{$IFDEF DELPHI}
Error: Use you must use FPC to compile this project.
{$ENDIF}

{$DEFINE FPC}

{$I FPCDoom.inc}

program FPCDoom;

{$R FPCDoom.res}

uses
  am_map in 'am_map.pas',
  c_cmds in 'c_cmds.pas',
  c_con in 'c_con.pas',
  deh_main in 'deh_main.pas',
  d_english in 'd_english.pas',
  d_event in 'd_event.pas',
  d_fpc in 'd_fpc.pas',
  d_items in 'd_items.pas',
  d_main in 'd_main.pas',
  d_net in 'd_net.pas',
  d_player in 'd_player.pas',
  d_think in 'd_think.pas',
  d_ticcmd in 'd_ticcmd.pas',
  doomdata in 'doomdata.pas',
  doomdef in 'doomdef.pas',
  doomstat in 'doomstat.pas',
  doomtype in 'doomtype.pas',
  e_endoom in 'e_endoom.pas',
  f_finale in 'f_finale.pas',
  f_wipe in 'f_wipe.pas',
  g_game in 'g_game.pas',
  hu_lib in 'hu_lib.pas',
  hu_stuff in 'hu_stuff.pas',
  i_input in 'i_input.pas',
  i_io in 'i_io.pas',
  i_main in 'i_main.pas',
  i_midi in 'i_midi.pas',
  i_music in 'i_music.pas',
  i_net in 'i_net.pas',
  i_sound in 'i_sound.pas',
  i_system in 'i_system.pas',
  i_video in 'i_video.pas',
  DirectX in 'DirectX.pas',
  info in 'info.pas',
  info_h in 'info_h.pas',
  info_rnd in 'info_rnd.pas',
  m_argv in 'm_argv.pas',
  m_bbox in 'm_bbox.pas',
  m_cheat in 'm_cheat.pas',
  m_defs in 'm_defs.pas',
  m_fixed in 'm_fixed.pas',
  m_menu in 'm_menu.pas',
  m_misc in 'm_misc.pas',
  m_rnd in 'm_rnd.pas',
  m_stack in 'm_stack.pas',
  m_vectors in 'm_vectors.pas',
  p_ceilng in 'p_ceilng.pas',
  p_doors in 'p_doors.pas',
  p_enemy in 'p_enemy.pas',
  p_extra in 'p_extra.pas',
  p_floor in 'p_floor.pas',
  p_inter in 'p_inter.pas',
  p_lights in 'p_lights.pas',
  p_local in 'p_local.pas',
  p_map in 'p_map.pas',
  p_maputl in 'p_maputl.pas',
  p_mobj in 'p_mobj.pas',
  p_mobj_h in 'p_mobj_h.pas',
  p_plats in 'p_plats.pas',
  p_pspr in 'p_pspr.pas',
  p_pspr_h in 'p_pspr_h.pas',
  p_saveg in 'p_saveg.pas',
  p_setup in 'p_setup.pas',
  p_sight in 'p_sight.pas',
  p_spec in 'p_spec.pas',
  p_switch in 'p_switch.pas',
  p_telept in 'p_telept.pas',
  p_terrain in 'p_terrain.pas',
  p_tick in 'p_tick.pas',
  p_user in 'p_user.pas',
  r_aspect in 'r_aspect.pas',
  r_bsp in 'r_bsp.pas',
  r_data in 'r_data.pas',
  r_defs in 'r_defs.pas',
  r_draw in 'r_draw.pas',
  r_draw_column in 'r_draw_column.pas',
  r_draw_span in 'r_draw_span.pas',
  r_externaltextures in 'r_externaltextures.pas',
  r_hires in 'r_hires.pas',
  r_intrpl in 'r_intrpl.pas',
  r_main in 'r_main.pas',
  r_mmx in 'r_mmx.pas',
  r_plane in 'r_plane.pas',
  r_segs in 'r_segs.pas',
  r_sky in 'r_sky.pas',
  r_things in 'r_things.pas',
  r_trans8 in 'r_trans8.pas',
  r_render in 'r_render.pas',
  r_lights in 'r_lights.pas',
  r_lightmap in 'r_lightmap.pas',
  r_draw_light in 'r_draw_light.pas',
  r_mirror in 'r_mirror.pas',
  r_grayscale in 'r_grayscale.pas',
  r_colorsubsampling in 'r_colorsubsubling.pas',
  r_zbuffer in 'r_zbuffer.pas',
  rtl_types in 'rtl_types.pas',
  sounds in 'sounds.pas',
  s_sound in 's_sound.pas',
  sc_actordef in 'sc_actordef.pas',
  sc_engine in 'sc_engine.pas',
  sc_params in 'sc_params.pas',
  sc_tokens in 'sc_tokens.pas',
  st_lib in 'st_lib.pas',
  st_stuff in 'st_stuff.pas',
  t_bmp in 't_bmp.pas',
  t_colors in 't_colors.pas',
  t_draw in 't_draw.pas',
  t_main in 't_main.pas',
  t_png in 't_png.pas',
  t_tga in 't_tga.pas',
  tables in 'tables.pas',
  v_intermission in 'v_intermission.pas',
  v_screenresolution in 'v_screenresolution.pas',
  v_video in 'v_video.pas',
  w_wad in 'w_wad.pas',
  w_pak in 'w_pak.pas',
  wi_stuff in 'wi_stuff.pas',
  z_memory in 'z_memory.pas', r_renderstyle;

var
  Saved8087CW: Word;

begin
  { Save the current FPU state and then disable FPU exceptions }
  Saved8087CW := Default8087CW;
  Set8087CW($133f); { Disable all fpu exceptions }

  DoomMain;

  { Reset the FPU to the previous state }
  Set8087CW(Saved8087CW);

end.
