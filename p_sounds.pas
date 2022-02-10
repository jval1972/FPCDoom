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

unit p_sounds;

interface

uses
  p_mobj_h;

//==============================================================================
//
// A_SeeSound
//
//==============================================================================
procedure A_SeeSound(actor: Pmobj_t; origin: Pmobj_t); overload;

//==============================================================================
//
// A_SeeSound
//
//==============================================================================
procedure A_SeeSound(actor: Pmobj_t); overload;

//==============================================================================
//
// A_PainSound
//
//==============================================================================
procedure A_PainSound(actor: Pmobj_t; origin: Pmobj_t); overload;

//==============================================================================
//
// A_PainSound
//
//==============================================================================
procedure A_PainSound(actor: Pmobj_t); overload;

//==============================================================================
//
// A_AttackSound
//
//==============================================================================
procedure A_AttackSound(actor: Pmobj_t; origin: Pmobj_t); overload;

//==============================================================================
//
// A_AttackSound
//
//==============================================================================
procedure A_AttackSound(actor: Pmobj_t); overload;

//==============================================================================
//
// A_MeleeSound
//
//==============================================================================
procedure A_MeleeSound(actor: Pmobj_t; origin: Pmobj_t); overload;

//==============================================================================
//
// A_MeleekSound
//
//==============================================================================
procedure A_MeleekSound(actor: Pmobj_t); overload;

//==============================================================================
//
// A_DeathSound
//
//==============================================================================
procedure A_DeathSound(actor: Pmobj_t; origin: Pmobj_t); overload;

//==============================================================================
//
// A_DeathSound
//
//==============================================================================
procedure A_DeathSound(actor: Pmobj_t); overload;

//==============================================================================
//
// A_ActiveSound
//
//==============================================================================
procedure A_ActiveSound(actor: Pmobj_t; origin: Pmobj_t); overload;

//==============================================================================
//
// A_ActiveSound
//
//==============================================================================
procedure A_ActiveSound(actor: Pmobj_t); overload;

implementation

uses
  info_h,
  p_extra,
  s_sound;

//==============================================================================
//
// A_SeeSound
//
//==============================================================================
procedure A_SeeSound(actor: Pmobj_t; origin: Pmobj_t);
begin
  if actor.info.seesound = 0 then
    exit;

  if actor.info.flags_ex and MF_EX_RANDOMSEESOUND <> 0 then
    P_RandomSound(origin, actor.info.seesound)
  else
    S_StartSound(origin, actor.info.seesound);
end;

//==============================================================================
//
// A_SeeSound
//
//==============================================================================
procedure A_SeeSound(actor: Pmobj_t);
begin
  if (actor._type = Ord(MT_SPIDER)) or (actor._type = Ord(MT_CYBORG)) or (actor.info.flags_ex and MF_EX_BOSS <> 0) then
    A_SeeSound(actor, nil)
  else
    A_SeeSound(actor, actor);
end;

//==============================================================================
//
// A_PainSound
//
//==============================================================================
procedure A_PainSound(actor: Pmobj_t; origin: Pmobj_t);
begin
  if actor.info.painsound = 0 then
    exit;

  if actor.info.flags_ex and MF_EX_RANDOMPAINSOUND <> 0 then
    P_RandomSound(origin, actor.info.painsound)
  else
    S_StartSound(origin, actor.info.painsound);
end;

//==============================================================================
//
// A_PainSound
//
//==============================================================================
procedure A_PainSound(actor: Pmobj_t);
begin
  if (actor._type = Ord(MT_SPIDER)) or (actor._type = Ord(MT_CYBORG)) or (actor.info.flags_ex and MF_EX_BOSS <> 0) then
    A_PainSound(actor, nil)
  else
    A_PainSound(actor, actor);
end;

//==============================================================================
//
// A_AttackSound
//
//==============================================================================
procedure A_AttackSound(actor: Pmobj_t; origin: Pmobj_t);
begin
  if actor.info.attacksound = 0 then
    exit;

  if actor.info.flags_ex and MF_EX_RANDOMATTACKSOUND <> 0 then
    P_RandomSound(origin, actor.info.attacksound)
  else
    S_StartSound(origin, actor.info.attacksound);
end;

//==============================================================================
//
// A_AttackSound
//
//==============================================================================
procedure A_AttackSound(actor: Pmobj_t);
begin
  if (actor._type = Ord(MT_SPIDER)) or (actor._type = Ord(MT_CYBORG)) or (actor.info.flags_ex and MF_EX_BOSS <> 0) then
    A_AttackSound(actor, nil)
  else
    A_AttackSound(actor, actor);
end;

//==============================================================================
//
// A_MeleeSound
//
//==============================================================================
procedure A_MeleeSound(actor: Pmobj_t; origin: Pmobj_t);
begin
  if actor.info.meleesound = 0 then
    exit;

  if actor.info.flags_ex and MF_EX_RANDOMMELEESOUND <> 0 then
    P_RandomSound(origin, actor.info.meleesound)
  else
    S_StartSound(origin, actor.info.meleesound);
end;

//==============================================================================
//
// A_MeleekSound
//
//==============================================================================
procedure A_MeleekSound(actor: Pmobj_t);
begin
  if (actor._type = Ord(MT_SPIDER)) or (actor._type = Ord(MT_CYBORG)) or (actor.info.flags_ex and MF_EX_BOSS <> 0) then
    A_MeleeSound(actor, nil)
  else
    A_MeleeSound(actor, actor);
end;

//==============================================================================
//
// A_DeathSound
//
//==============================================================================
procedure A_DeathSound(actor: Pmobj_t; origin: Pmobj_t);
begin
  if actor.info.deathsound = 0 then
    exit;

  if actor.info.flags_ex and MF_EX_RANDOMDEATHSOUND <> 0 then
    P_RandomSound(origin, actor.info.deathsound)
  else
    S_StartSound(origin, actor.info.deathsound);
end;

//==============================================================================
//
// A_DeathSound
//
//==============================================================================
procedure A_DeathSound(actor: Pmobj_t);
begin
  if (actor._type = Ord(MT_SPIDER)) or (actor._type = Ord(MT_CYBORG)) or (actor.info.flags_ex and MF_EX_BOSS <> 0) then
    A_DeathSound(actor, nil)
  else
    A_DeathSound(actor, actor);
end;

//==============================================================================
//
// A_ActiveSound
//
//==============================================================================
procedure A_ActiveSound(actor: Pmobj_t; origin: Pmobj_t);
begin
  if actor.info.activesound = 0 then
    exit;

  if actor.info.flags_ex and MF_EX_RANDOMACTIVESOUND <> 0 then
    P_RandomSound(origin, actor.info.activesound)
  else
    S_StartSound(origin, actor.info.activesound);
end;

//==============================================================================
//
// A_ActiveSound
//
//==============================================================================
procedure A_ActiveSound(actor: Pmobj_t);
begin
  if (actor._type = Ord(MT_SPIDER)) or (actor._type = Ord(MT_CYBORG)) or (actor.info.flags_ex and MF_EX_BOSS <> 0) then
    A_ActiveSound(actor, nil)
  else
    A_ActiveSound(actor, actor);
end;

end.
