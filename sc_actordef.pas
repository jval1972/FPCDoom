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

unit sc_actordef;

interface

uses
  d_fpc;

//==============================================================================
//
// SC_ParseActordefLumps
//
//==============================================================================
procedure SC_ParseActordefLumps;

//==============================================================================
//
// SC_Init
//
//==============================================================================
procedure SC_Init;

//==============================================================================
//
// SC_ShutDown
//
//==============================================================================
procedure SC_ShutDown;

//==============================================================================
//
// SC_SoundAlias
//
//==============================================================================
function SC_SoundAlias(const snd: string): string;

implementation

uses
  d_main,
  deh_main,
  m_fixed,
  i_system,
  info,
  r_renderstyle,
  rtl_types,
  sc_engine,
  w_wad;

var
  soundaliases: TDStringList;

const
  MAXSTATES = 512;

//==============================================================================
//
// fixsndaliasstr
//
//==============================================================================
function fixsndaliasstr(const src: string): string;
var
  i: integer;
begin
  result := src;
  for i := 1 to length(result) do
  begin
    if result[i] = '\' then
      result[i] := '/'
    else if result[i] in ['"', '{', '}'] then
      result[i] := ' '
    else
      result[i] := toupper(result[i]);
  end;
end;

//==============================================================================
//
// SC_SoundAlias
//
//==============================================================================
function SC_SoundAlias(const snd: string): string;
var
  check: string;
  id: integer;
begin
  if snd = '' then
  begin
    result := '0';
    exit;
  end;

  check := fixsndaliasstr(snd);
  if firstword(check) = '$RANDOM' then
    check := secondword(check);
  id := soundaliases.IndexOfName(check);
  if id >= 0 then
  begin
    result := soundaliases.Values[check];
    if (length(result) > 8) or (Pos('/', result) > 0) then
    begin
      id := soundaliases.IndexOfName(result);
      if id >= 0 then
        result := soundaliases.Values[result];
    end;
    if (length(result) > 8) or (Pos('/', result) > 0) then
    begin
      I_Warning('SC_SoundAlias(): Sound %s has length %d > 8.'#13#10, [result, length(result)]);
      result := '0';
    end;
    exit;
  end;

  if Pos('/', snd) > 0 then
  begin
    I_Warning('SC_SoundAlias(): Sound %s does not have a corresponding alias.'#13#10, [snd]);
    result := '0';
    exit;
  end;

  if length(snd) > 8 then
  begin
    I_Warning('SC_SoundAlias(): Sound %s has length %d > 8.'#13#10, [snd, length(snd)]);
    result := '0';
    exit;
  end;

  result := snd;
end;

type
  TActordefScriptEngine = class(TScriptEngine)
  public
    function MatchFlag(const flag: string): boolean;
    function MatchFlagEx(const flag_ex: string): boolean;
    function MatchFlag2Ex(const flag2_ex: string): boolean;
  end;

//==============================================================================
//
// TActordefScriptEngine.MatchFlag
//
//==============================================================================
function TActordefScriptEngine.MatchFlag(const flag: string): boolean;
begin
  result :=
    MatchString(flag) or MatchString('+' + flag) or
    MatchString('MF_' + flag) or MatchString('+MF_' + flag);
end;

//==============================================================================
//
// TActordefScriptEngine.MatchFlagEx
//
//==============================================================================
function TActordefScriptEngine.MatchFlagEx(const flag_ex: string): boolean;
begin
  result :=
    MatchString(flag_ex) or MatchString('+' + flag_ex) or
    MatchString('MF_' + flag_ex) or MatchString('+MF_' + flag_ex) or
    MatchString('MF_EX_' + flag_ex) or MatchString('+MF_EX_' + flag_ex);
end;

//==============================================================================
//
// TActordefScriptEngine.MatchFlag2Ex
//
//==============================================================================
function TActordefScriptEngine.MatchFlag2Ex(const flag2_ex: string): boolean;
begin
  result :=
    MatchString(flag2_ex) or MatchString('+' + flag2_ex) or
    MatchString('MF2_' + flag2_ex) or MatchString('+MF2_' + flag2_ex) or
    MatchString('MF2_EX_' + flag2_ex) or MatchString('+MF2_EX_' + flag2_ex);
end;

const
  ORIGINALSTATEMARKER = $FFFFF;
  ACTORDEFLUMPNAME = 'ACTORDEF';
  SNDINFOLUMPNAME = 'SNDINFO';

//==============================================================================
//
// SC_ParseActordefLump
//
//==============================================================================
procedure SC_ParseActordefLump(const in_text: string);
var
  mobj: rtl_mobjinfo_t;
  sc: TActordefScriptEngine;
  foundstates: boolean;
  numstates: integer;
  m_states: array[0..MAXSTATES - 1] of rtl_state_t;
  res: string;
  ismissile: boolean;
  i, idx: integer;
  state_tokens: TDStringList;

  function MatchFlags: boolean;
  var
    i: integer;
    flag: string;
  begin
    for i := 0 to mobj_flags.Count - 1 do
    begin
      flag := mobj_flags[i];
      if Pos('MF_', flag) = 1 then
        flag := Copy(flag, 4, length(flag) - 3);
      if sc.MatchFlag(flag) then
      begin
        mobj.flags := mobj.flags + flag + ' ';
        result := true;
        exit;
      end;
    end;

    result := false;
  end;

  function RemoveFlag(const inp: string; const aflag: string): string;
  var
    sctmp: TScriptEngine;
    acheck, icheck: string;
  begin
    result := '';
    acheck := strupper(aflag);
    if Pos('MF2_EX_', acheck) = 1 then
      acheck := Copy(acheck, 8, length(acheck) - 7)
    else if Pos('MF_EX_', acheck) = 1 then
      acheck := Copy(acheck, 7, length(acheck) - 6)
    {$IFDEF HERETIC_OR_HEXEN}
    else if Pos('MF2_', acheck) = 1 then
      acheck := Copy(acheck, 5, length(acheck) - 4)
    {$ENDIF}
    else if Pos('MF_', acheck) = 1 then
      acheck := Copy(acheck, 4, length(acheck) - 3);
    sctmp := TScriptEngine.Create(inp);
    while sctmp.GetString do
    begin
      icheck := strupper(sctmp._String);
      if (icheck <> acheck) and
         (icheck <> 'MF_' + acheck) and
         (icheck <> 'MF2_' + acheck) and
         (icheck <> 'MF_EX_' + acheck) and
         (icheck <> 'MF2_EX_' + acheck) then
        result := result + icheck + ' ';
    end;
    sctmp.Free;
  end;

  function MatchFlags_Delete: boolean;
  var
    i: integer;
    flag: string;
    check: string;
  begin
    check := sc._String;
    if Pos('-', check) <> 1 then
    begin
      result := false;
      exit;
    end;
    if Pos('+', check) = 1 then
    begin
      result := false;
      exit;
    end;

    for i := 0 to mobj_flags.Count - 1 do
    begin
      flag := mobj_flags[i];
      if Pos('MF_', flag) = 1 then
        flag := Copy(flag, 4, length(flag) - 3);
      if sc.MatchFlag('-' + flag) then
      begin
        mobj.flags := RemoveFlag(mobj.flags, flag);
        result := true;
        exit;
      end;
    end;

    result := false;
  end;

  function MatchFlagsEx: boolean;
  var
    i: integer;
    flag: string;
  begin
    for i := 0 to mobj_flags_ex.Count - 1 do
    begin
      flag := mobj_flags_ex[i];
      if Pos('MF_EX_', flag) = 1 then
        flag := Copy(flag, 7, length(flag) - 6)
      else if Pos('MF_', flag) = 1 then
        flag := Copy(flag, 4, length(flag) - 3);
      if sc.MatchFlagEx(flag) then
      begin
        mobj.flags_ex := mobj.flags_ex + flag + ' ';
        result := true;
        exit;
      end;
    end;

    result := false;
  end;

  function MatchFlagsEx_Delete: boolean;
  var
    i: integer;
    flag: string;
    check: string;
  begin
    check := sc._String;
    if Pos('-', check) <> 1 then
    begin
      result := false;
      exit;
    end;
    if Pos('+', check) = 1 then
    begin
      result := false;
      exit;
    end;

    for i := 0 to mobj_flags_ex.Count - 1 do
    begin
      flag := mobj_flags_ex[i];
      if Pos('MF_EX_', flag) = 1 then
        flag := Copy(flag, 7, length(flag) - 6)
      else if Pos('MF_', flag) = 1 then
        flag := Copy(flag, 4, length(flag) - 3);
      if sc.MatchFlagEx('-' + flag) then
      begin
        mobj.flags_ex := RemoveFlag(mobj.flags_ex, flag);
        result := true;
        exit;
      end;
    end;

    result := false;
  end;

  function MatchFlags2Ex: boolean;
  var
    i: integer;
    flag: string;
  begin
    for i := 0 to mobj_flags2_ex.Count - 1 do
    begin
      flag := mobj_flags2_ex[i];
      if Pos('MF2_EX_', flag) = 1 then
        flag := Copy(flag, 8, length(flag) - 7)
      else if Pos('MF_EX_', flag) = 1 then
        flag := Copy(flag, 7, length(flag) - 6)
      else if Pos('MF2_', flag) = 1 then
        flag := Copy(flag, 5, length(flag) - 4)
      else if Pos('MF_', flag) = 1 then
        flag := Copy(flag, 4, length(flag) - 3);
      if sc.MatchFlag2Ex(flag) then
      begin
        mobj.flags2_ex := mobj.flags2_ex + flag + ' ';
        result := true;
        exit;
      end;
    end;

    result := false;
  end;

  function MatchFlags2Ex_Delete: boolean;
  var
    i: integer;
    flag: string;
    check: string;
  begin
    check := sc._String;
    if Pos('-', check) <> 1 then
    begin
      result := false;
      exit;
    end;
    if Pos('+', check) = 1 then
    begin
      result := false;
      exit;
    end;

    for i := 0 to mobj_flags2_ex.Count - 1 do
    begin
      flag := mobj_flags2_ex[i];
      if Pos('MF2_EX_', flag) = 1 then
        flag := Copy(flag, 8, length(flag) - 7)
      else if Pos('MF_EX_', flag) = 1 then
        flag := Copy(flag, 7, length(flag) - 6)
      else if Pos('MF2_', flag) = 1 then
        flag := Copy(flag, 5, length(flag) - 4)
      else if Pos('MF_', flag) = 1 then
        flag := Copy(flag, 4, length(flag) - 3);
      if sc.MatchFlag2Ex('-' + flag) then
      begin
        mobj.flags2_ex := RemoveFlag(mobj.flags2_ex, flag);
        result := true;
        exit;
      end;
    end;

    result := false;
  end;

  function ParseState(const base: integer): boolean;
  var
    sprite: string;
    frames: string;
    tics: integer;
    action: string;
    i: integer;
    gotostr: string;
    offs: integer;
    bright: boolean;
    stmp: string;
    _end: boolean;
    p: integer;
  begin
    result := false;
    if sc._Finished then
      exit;
    sc.GetString;
    if sc.MatchString('loop') then
    begin
      m_states[numstates - 1].nextstate := base;
      exit;
    end
    else if sc.MatchString('stop') then
    begin
      if numstates > 0 then
        m_states[numstates - 1].nextstate := -1; // S_NULL
      exit;
    end
    else if sc.MatchString('wait') then
    begin
      if numstates > 0 then
        m_states[numstates - 1].nextstate := numstates - 1; // Same state
      exit;
    end
    else if sc.MatchString('goto') then
    begin
      gotostr := strupper(sc.GetStringEOL);
      p := Pos('//', gotostr);
      if p > 0 then
        gotostr := Copy(gotostr, 1, p - 1);
      if Pos('SPAWN', gotostr) = 1 then
      begin
        if length(gotostr) > 5 then
          offs := atoi(strremovespaces(Copy(gotostr, 6, Length(gotostr) - 5)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.spawnstate + offs;
      end
      else if Pos('SEE', gotostr) = 1 then
      begin
        if length(gotostr) > 3 then
          offs := atoi(strremovespaces(Copy(gotostr, 4, Length(gotostr) - 3)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.seestate + offs;
      end
      else if Pos('MELEE', gotostr) = 1 then
      begin
        if length(gotostr) > 5 then
          offs := atoi(strremovespaces(Copy(gotostr, 6, Length(gotostr) - 5)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.meleestate + offs;
      end
      else if Pos('MISSILE', gotostr) = 1 then
      begin
        if length(gotostr) > 7 then
          offs := atoi(strremovespaces(Copy(gotostr, 8, Length(gotostr) - 7)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.missilestate + offs;
      end
      else if Pos('PAIN', gotostr) = 1 then
      begin
        if length(gotostr) > 4 then
          offs := atoi(strremovespaces(Copy(gotostr, 5, Length(gotostr) - 4)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.painstate + offs;
      end
      else if Pos('DEATH', gotostr) = 1 then
      begin
        if length(gotostr) > 5 then
          offs := atoi(strremovespaces(Copy(gotostr, 6, Length(gotostr) - 5)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.deathstate + offs;
      end
      else if Pos('XDEATH', gotostr) = 1 then
      begin
        if length(gotostr) > 6 then
          offs := atoi(strremovespaces(Copy(gotostr, 7, Length(gotostr) - 6)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.xdeathstate + offs;
      end
      else if Pos('RAISE', gotostr) = 1 then
      begin
        if length(gotostr) > 5 then
          offs := atoi(strremovespaces(Copy(gotostr, 6, Length(gotostr) - 5)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.raisestate + offs;
      end
      else if Pos('HEAL', gotostr) = 1 then
      begin
        if length(gotostr) > 4 then
          offs := atoi(strremovespaces(Copy(gotostr, 5, Length(gotostr) - 4)))
        else
          offs := 0;
        m_states[numstates - 1].nextstate := mobj.healstate + offs;
      end
      else
      begin
        I_Warning('SC_ActordefToDEH(): Unknown label "goto %s"'#13#10, [gotostr]);
        exit;
      end;
      result := sc.MatchString(state_tokens) = -1;

      exit;
    end;

    result := sc.MatchString(state_tokens) = -1;

    if not result then
      exit;

    if sc.BracketLevel = 0 then
    begin
      m_states[numstates - 1].nextstate := numstates - 1; // finished without stop keyword
      result := false;
      sc.UnGet;
      exit;
    end;

    result := true;
    sprite := sc._string;
    sc.GetString;
    frames := sc._string;
    sc.GetInteger;
    tics := sc._integer;

    bright := false;
    action := '';
    sc.GetString;
    if sc.NewLine then
      sc.UnGet
    else
    begin
      stmp := '';
      _end := false;
      while not sc.NewLine and not _end do
      begin
        if stmp <> '' then
          stmp := stmp + ' ';
        if sc.ParenthesisLevel = 1 then
          stmp := stmp + '"' + sc._string + '"'
        else
          stmp := stmp + sc._string;
        _end := not sc.GetString;
      end;
      if not _end then
        sc.UnGet;

      bright := false;
      stmp := strtrim(stmp);  // JVAL for safety, unneeded
      for i := 1 to length(stmp) do
        if stmp[i] in ['(', ')',','] then
          stmp[i] := ' ';
      if strupper(firstword(stmp)) = 'BRIGHT' then
      begin
        bright := true;
        action := secondword(stmp);
      end
      else if strupper(lastword(stmp)) = 'BRIGHT' then
      begin
        bright := true;
        action := Copy(stmp, 1, length(stmp) - 7);
      end
      else
        action := stmp;
    end;

    if stmp = '' then
      action := 'A_Null';

    for i := 1 to length(frames) do
    begin
      if numstates = MAXSTATES then
      begin
        I_Warning('SC_ActordefToDEH(): Object has more than %d states'#13#10, [MAXSTATES]);
      end
      else
      begin
        m_states[numstates].sprite := sprite;
        m_states[numstates].frame := Ord(frames[i]) - Ord('A');
        m_states[numstates].tics := tics;
        m_states[numstates].action := action;
        m_states[numstates].nextstate := numstates + 1;
        m_states[numstates].bright := bright;
        inc(numstates);
      end;
    end;

  end;

  procedure AddRes(const s: string);
  begin
    res := res + s + #13#10;
  end;

  procedure AddMobjStateRes(const st: integer; const prefix: string);
  begin
    if st = -1 then
      AddRes(prefix + ' Frame = OriginalFrame 0')
    else if st >= ORIGINALSTATEMARKER then
      AddRes(prefix + ' Frame = OriginalFrame ' + itoa(st - ORIGINALSTATEMARKER))
    else
      AddRes(prefix + ' Frame = NewFrame ' + itoa(st));
  end;

  procedure SubmitParsedData;
  var
    cnt: integer;
  begin
    res := '';
    if mobj.replacesid >= 0 then
      AddRes('Thing ' + itoa(mobj.replacesid + 1)) // JVAL DEH patches start Think numbers from 1
    else
      AddRes('NewThing "' + mobj.name + '"');
    if mobj.inheritsfrom <> '' then
      AddRes('Inheritsfrom = "' + mobj.inheritsfrom + '"')
    else
      AddRes('Inheritsfrom = -1');
    AddRes('Id # = ' + itoa(mobj.doomednum));
    AddMobjStateRes(mobj.spawnstate, 'Initial');
    AddRes('Hit Points = ' + itoa(mobj.spawnhealth));
    AddMobjStateRes(mobj.seestate, 'First Moving');
    AddRes('Alert Sound = ' + SC_SoundAlias(mobj.seesound));
    AddRes('Reaction Time = ' + itoa(mobj.reactiontime));
    AddRes('Attack Sound = ' + SC_SoundAlias(mobj.attacksound));
    AddMobjStateRes(mobj.painstate, 'Injury');
    AddRes('Pain Chance = ' + itoa(mobj.painchance));
    AddRes('Pain Sound = ' + SC_SoundAlias(mobj.painsound));
    AddMobjStateRes(mobj.meleestate, 'Close Attack');
    AddMobjStateRes(mobj.missilestate, 'Far Attack');
    AddMobjStateRes(mobj.deathstate, 'Death');
    AddMobjStateRes(mobj.xdeathstate, 'Exploding');
    AddMobjStateRes(mobj.healstate, 'Heal');
    AddRes('Death Sound = ' + SC_SoundAlias(mobj.deathsound));
    if ismissile then
      if mobj.speed < 2048 then // JVAL fix me
        mobj.speed := mobj.speed * FRACUNIT;
    AddRes('Speed = ' + itoa(mobj.speed));
    AddRes('Width = ' + itoa(mobj.radius * $10000));
    AddRes('Height = ' + itoa(mobj.height * $10000));
    AddRes('Mass = ' + itoa(mobj.mass));
    AddRes('Missile Damage = ' + itoa(mobj.damage));
    AddRes('Action Sound = ' + SC_SoundAlias(mobj.activesound));
    AddMobjStateRes(mobj.raisestate, 'Respawn');
    AddRes('Bits = ' + mobj.flags);
    AddRes('flags_ex = ' + mobj.flags_ex);
    AddRes('Custom Sound 1 = ' + SC_SoundAlias(mobj.customsound1));
    AddRes('Custom Sound 2 = ' + SC_SoundAlias(mobj.customsound2));
    AddRes('Custom Sound 3 = ' + SC_SoundAlias(mobj.customsound3));
    AddRes('Melee Damage = ' + itoa(mobj.meleedamage));
    AddRes('Melee Sound = ' + SC_SoundAlias(mobj.meleesound));
    AddRes('Explosion Damage = ' + itoa(mobj.explosiondamage));
    AddRes('Explosion Radius = ' + itoa(mobj.explosionradius));
    AddRes('Dropitem = ' + mobj.dropitem);
    AddRes('Missiletype = ' + mobj.missiletype);
    if mobj.renderstyle <> '' then
      AddRes('Renderstyle = ' + mobj.renderstyle)
    else
      AddRes('Renderstyle = NORMAL');
    AddRes('Alpha = ' + itoa(mobj.alpha));
    AddRes('flags2_ex = ' + mobj.flags2_ex);
    AddRes('Scale = ' + itoa(mobj.scale));
    AddRes('');

    if numstates > 0 then
    begin
      if m_states[numstates - 1].nextstate = numstates then
        m_states[numstates - 1].nextstate := numstates - 1;

      for cnt := 0 to numstates - 1 do
      begin
        AddRes('Frame NewFrame ' + itoa(cnt));
        AddRes('Sprite Number = ' + m_states[cnt].sprite);
        if m_states[cnt].bright then
          AddRes('Sprite Subnumber = Bright ' + itoa(m_states[cnt].frame))
        else
          AddRes('Sprite Subnumber = ' + itoa(m_states[cnt].frame));
        AddRes('Duration = ' + itoa(m_states[cnt].tics));
        if m_states[cnt].nextstate >= ORIGINALSTATEMARKER then
          AddRes('Next Frame = OriginalFrame ' + itoa(m_states[cnt].nextstate - ORIGINALSTATEMARKER))
        else if m_states[cnt].nextstate >= 0 then
          AddRes('Next Frame = NewFrame ' + itoa(m_states[cnt].nextstate))
        else
          AddRes('Next Frame = OriginalFrame 0');
        AddRes('Codep Frame = ' + m_states[cnt].action);
        AddRes('Unknown 1 = 0');
        AddRes('Unknown 2 = 0');
        AddRes('Flags_ex = 0');
        AddRes('');
      end;
      AddRes('');
      AddRes('');
      AddRes('SubmitNewFrames');
    end;

    AddRes('');
    AddRes('');
    if devparm then
    begin
      printf('SC_SubmitParsedData(): Submiting ACTORDEF lump to DEH subsystem:'#13#10);
      printf(res);
      printf('--------'#13#10);
    end;
    DEH_Parse(res);
  end;

var
  slist: TDStringList;
  isreplace: boolean;
begin

  state_tokens := TDStringList.Create;
  state_tokens.Add('spawn:');
  state_tokens.Add('see:');
  state_tokens.Add('melee:');
  state_tokens.Add('missile:');
  state_tokens.Add('pain:');
  state_tokens.Add('death:');
  state_tokens.Add('xdeath:');
  state_tokens.Add('raise:');
  state_tokens.Add('heal:');

  if devparm then
  begin
    printf('--------'#13#10);
    printf('SC_ParseActordefLump(): Parsing %s lump:'#13#10, [ACTORDEFLUMPNAME]);

    slist := TDStringList.Create;
    try
      slist.Text := in_text;
      for i := 0 to slist.Count - 1 do
        printf('%s: %s'#13#10, [IntToStrZFill(6, i + 1), slist[i]]);
    finally
      slist.Free;
    end;

    printf('--------'#13#10);
  end;

  sc := TActordefScriptEngine.Create(in_text);
  while sc.GetString do
  begin
    if sc.MatchString('ACTOR') then
    begin
      FillChar(mobj, SizeOf(mobj), 0);
      mobj.spawnstate := -1;
      mobj.seestate := -1;
      mobj.painstate := -1;
      mobj.meleestate := -1;
      mobj.missilestate := -1;
      mobj.deathstate := -1;
      mobj.xdeathstate := -1;
      mobj.raisestate := -1;
      mobj.healstate := -1;
      mobj.flags := '';
      mobj.flags_ex := '';
      mobj.flags2_ex := '';
      mobj.scale := FRACUNIT;
      mobj.replacesid := -1;
      ismissile := false;
      isreplace := false;
      FillChar(m_states, SizeOf(m_states), 0);
      sc.GetString;
      mobj.name := sc._String;
      if Pos(':', mobj.name) = Length(mobj.name) then
      begin
        SetLength(mobj.name, Length(mobj.name) - 1);
        sc.GetString;
        mobj.inheritsfrom := sc._string;
      end
      else
      begin
        if not sc.GetString then
          break;

        isreplace := sc.MatchString('replaces');
        if isreplace or sc.MatchString(':') or
           sc.MatchString('inherits') or sc.MatchString('inheritsfrom') then
        begin
          if not sc.GetString then
            break;
          mobj.inheritsfrom := sc._string;
        end;
      end;

      if mobj.inheritsfrom <> '' then
      begin
        idx := Info_GetMobjNumForName(mobj.inheritsfrom);
        if idx >= 0 then
        begin
          if isreplace then
          begin
            mobj.doomednum := mobjinfo[idx].doomednum;
            mobj.replacesid := idx;
          end;
          mobj.spawnhealth := mobjinfo[idx].spawnhealth;
          mobj.seesound := itoa(mobjinfo[idx].seesound);
          mobj.reactiontime := mobjinfo[idx].reactiontime;
          mobj.attacksound := itoa(mobjinfo[idx].attacksound);
          mobj.painchance := mobjinfo[idx].painchance;
          mobj.painsound := itoa(mobjinfo[idx].painsound);
          mobj.deathsound := itoa(mobjinfo[idx].deathsound);
          mobj.speed := mobjinfo[idx].speed;
          mobj.radius := mobjinfo[idx].radius div FRACUNIT;
          mobj.height := mobjinfo[idx].height div FRACUNIT;
          mobj.mass := mobjinfo[idx].mass;
          mobj.damage := mobjinfo[idx].damage;
          mobj.activesound := itoa(mobjinfo[idx].activesound);
          for i := 0 to 31 do
            if mobjinfo[idx].flags and _SHL(1, i) <> 0 then
              mobj.flags := mobj.flags + mobj_flags[i] + ' ';
          for i := 0 to 31 do
            if mobjinfo[idx].flags_ex and _SHL(1, i) <> 0 then
              mobj.flags_ex := mobj.flags_ex + mobj_flags_ex[i] + ' ';
          for i := 0 to 31 do
            if mobjinfo[idx].flags2_ex and _SHL(1, i) <> 0 then
              mobj.flags2_ex := mobj.flags2_ex + mobj_flags2_ex[i] + ' ';
          mobj.customsound1 := itoa(mobjinfo[idx].customsound1);
          mobj.customsound2 := itoa(mobjinfo[idx].customsound2);
          mobj.customsound3 := itoa(mobjinfo[idx].customsound3);
          mobj.dropitem := itoa(mobjinfo[idx].dropitem);
          mobj.missiletype := itoa(mobjinfo[idx].missiletype);
          mobj.explosiondamage := mobjinfo[idx].explosiondamage;
          mobj.explosionradius := mobjinfo[idx].explosionradius;
          mobj.meleedamage := mobjinfo[idx].meleedamage;
          mobj.meleesound := itoa(mobjinfo[idx].meleesound);

          mobj.spawnstate := ORIGINALSTATEMARKER + mobjinfo[idx].spawnstate;
          mobj.seestate := ORIGINALSTATEMARKER + mobjinfo[idx].seestate;
          mobj.painstate := ORIGINALSTATEMARKER + mobjinfo[idx].painstate;
          mobj.meleestate := ORIGINALSTATEMARKER + mobjinfo[idx].meleestate;
          mobj.missilestate := ORIGINALSTATEMARKER + mobjinfo[idx].missilestate;
          mobj.deathstate := ORIGINALSTATEMARKER + mobjinfo[idx].deathstate;
          mobj.xdeathstate := ORIGINALSTATEMARKER + mobjinfo[idx].xdeathstate;
          mobj.raisestate := ORIGINALSTATEMARKER + mobjinfo[idx].raisestate;
          mobj.healstate := ORIGINALSTATEMARKER + mobjinfo[idx].healstate;

          mobj.renderstyle := itoa(Ord(mobjinfo[idx].renderstyle));
          mobj.alpha := mobjinfo[idx].alpha;
          mobj.scale := mobjinfo[idx].scale;

        end;

        if not sc.GetString then
          break;
      end;

      if sc.NewLine then
      begin
        if not isreplace then
          mobj.doomednum := -1;
      end
      else
      begin
        mobj.doomednum := atoi(sc._string);
        if not sc.GetString then
          break;
      end;

      foundstates := false;
      repeat
        if sc.MatchString('health') then
        begin
          sc.GetInteger;
          mobj.spawnhealth := sc._integer;
          sc.GetString;
        end

        // When "inherits" is after the first line of actor we do not copy properties
        else if sc.MatchString('inherits') or sc.MatchString('inheritsfrom') then
        begin
          if not sc.GetString then
            break;
          mobj.inheritsfrom := sc._string;
        end

        else if sc.MatchString('replaces') then
        begin
          if not sc.GetString then
            break;
          idx := Info_GetMobjNumForName(sc._string);
          if idx >= 0 then
          begin
            if (mobj.doomednum > 0) and (mobjinfo[idx].doomednum <> mobj.doomednum) then
              I_Warning('SC_ActordefToDEH(): Replaces keyword found but points to a new doomednum %d, old doomednum=%d', [mobjinfo[idx].doomednum, mobj.doomednum])
            else
            begin
              mobj.doomednum := mobjinfo[idx].doomednum;
              mobj.replacesid := idx;
            end;
          end
          else
            I_Warning('SC_ActordefToDEH(): Replaces keyword points to an unknown mobj %s'#13#10, [sc._string]);
          sc.GetString;
        end

        else if sc.MatchString('monster') or sc.MatchString('+monster') then
        begin
           mobj.flags := mobj.flags + 'MF_SOLID MF_SHOOTABLE MF_COUNTKILL ';
           sc.GetString;
        end

        else if sc.MatchString('projectile') or sc.MatchString('+projectile') then
        begin
           mobj.flags := mobj.flags + 'MF_NOGRAVITY MF_DROPOFF  MF_MISSILE ';
           sc.GetString;
        end

        else if sc.MatchString('RENDERSTYLE') then
        begin
          sc.GetString;
          mobj.renderstyle := renderstyle_tokens[Ord(R_GetRenderstyleForName(sc._String))];
          sc.GetString;
        end

        else if sc.MatchString('ALPHA') then
        begin
          sc.GetFloat;
          mobj.alpha := Round(sc._float * FRACUNIT);
          sc.GetString;
        end

        else if sc.MatchString('SCALE') then
        begin
          sc.GetFloat;
          mobj.scale := Round(sc._float * FRACUNIT);
          sc.GetString;
        end

        else if MatchFlags then
          sc.GetString
        else if MatchFlagsEx then
          sc.GetString
        else if MatchFlags2Ex then
          sc.GetString

        else if MatchFlags_Delete then
          sc.GetString
        else if MatchFlagsEx_Delete then
          sc.GetString
        else if MatchFlags2Ex_Delete then
          sc.GetString

        else if sc.MatchString('DEFAULTMISSILE') or sc.MatchString('+DEFAULTMISSILE') then
        begin
          mobj.flags := mobj.flags + 'NOGRAVITY MISSILE NOBLOCKMAP DROPOFF ';
          sc.GetString;
        end

        else if sc.MatchString('DEFAULTTRANSPARENT') or sc.MatchString('+DEFAULTTRANSPARENT') then
        begin
          mobj.renderstyle := 'TRANSLUCENT';
          mobj.alpha := Round(0.67 * FRACUNIT);
          sc.GetString;
        end

        else if sc.MatchString('radius') or sc.MatchString('width') then
        begin
          sc.GetInteger;
          mobj.radius := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('height') then
        begin
          sc.GetInteger;
          mobj.height := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('speed') then
        begin
          sc.GetInteger;
          mobj.speed := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('damage') then
        begin
          sc.GetInteger;
          mobj.damage := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('painchance') then
        begin
          sc.GetInteger;
          mobj.painchance := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('mass') then
        begin
          sc.GetInteger;
          mobj.mass := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('reactiontime') then
        begin
          sc.GetInteger;
          mobj.reactiontime := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('dropitem') then
        begin
          sc.GetString;
          mobj.dropitem := sc._string;
          sc.GetString;
        end
        else if sc.MatchString('missiletype') then
        begin
          sc.GetString;
          mobj.missiletype := sc._string;
          sc.GetString;
        end
        else if sc.MatchString('explosiondamage') then
        begin
          sc.GetInteger;
          mobj.explosiondamage := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('explosionradius') then
        begin
          sc.GetInteger;
          mobj.explosionradius := sc._integer;
          sc.GetString;
        end
        else if sc.MatchString('meleedamage') then
        begin
          sc.GetInteger;
          mobj.meleedamage := sc._Integer;
          sc.GetString;
        end
        else if sc.MatchString('seesound') then
        begin
          sc.GetString;
          mobj.seesound := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('attacksound') then
        begin
          sc.GetString;
          mobj.attacksound := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('painsound') then
        begin
          sc.GetString;
          mobj.painsound := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('deathsound') then
        begin
          sc.GetString;
          mobj.deathsound := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('activesound') then
        begin
          sc.GetString;
          mobj.activesound := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('customsound1') then
        begin
          sc.GetString;
          mobj.customsound1 := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('customsound2') then
        begin
          sc.GetString;
          mobj.customsound2 := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('customsound3') then
        begin
          sc.GetString;
          mobj.customsound3 := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('meleesound') then
        begin
          sc.GetString;
          mobj.meleesound := sc._String;
          sc.GetString;
        end
        else if sc.MatchString('states') then
        begin
          foundstates := true;
        end
        else
          sc.GetString;
      until foundstates or sc._Finished;

      if mobj.flags = '' then
        mobj.flags := '0';
      if mobj.flags_ex = '' then
        mobj.flags_ex := '0';
      if mobj.flags2_ex = '' then
        mobj.flags2_ex := '0';

      numstates := 0;

      while sc.GetString do
      begin
        if sc.MatchString('ACTOR') then
        begin
          SubmitParsedData;
          sc.UnGet;
          break;
        end;
        if sc.MatchString('spawn:') then
        begin
          mobj.spawnstate := numstates;
          repeat until not ParseState(mobj.spawnstate);
        end
        else if sc.MatchString('see:') then
        begin
          mobj.seestate := numstates;
          repeat until not ParseState(mobj.seestate);
        end
        else if sc.MatchString('heal:') then
        begin
          mobj.healstate := numstates;
          repeat until not ParseState(mobj.healstate);
        end
        else if sc.MatchString('melee:') then
        begin
          mobj.meleestate := numstates;
          repeat until not ParseState(mobj.meleestate);
        end
        else if sc.MatchString('missile:') then
        begin
          mobj.missilestate := numstates;
          repeat until not ParseState(mobj.missilestate);
        end
        else if sc.MatchString('pain:') then
        begin
          mobj.painstate := numstates;
          repeat until not ParseState(mobj.painstate);
        end
        else if sc.MatchString('death:') then
        begin
          mobj.deathstate := numstates;
          repeat until not ParseState(mobj.deathstate);
        end
        else if sc.MatchString('xdeath:') then
        begin
          mobj.xdeathstate := numstates;
          repeat until not ParseState(mobj.xdeathstate);
        end
        else if sc.MatchString('raise:') then
        begin
          mobj.raisestate := numstates;
          repeat until not ParseState(mobj.raisestate);
        end
      end;

    end;
  end;

  SubmitParsedData;

  sc.Free;
  state_tokens.Free;

end;

//==============================================================================
//
// SC_ParseActordefLumps
//
//==============================================================================
procedure SC_ParseActordefLumps;
var
  i: integer;
  sound_tx: string;
  s: TDStringList;
  stmp: string;
  str1, str2: string;
  p: integer;
begin
// JVAL
// Retrive sndinfo lumps for sound alias list
  sound_tx := '';
  for i := 0 to W_NumLumps - 1 do
  begin
    if char8tostring(W_GetNameForNum(i)) = SNDINFOLUMPNAME then
      sound_tx := sound_tx + W_TextLumpNum(i);
  end;

  s := TDStringList.Create;
  try
    s.Text := fixsndaliasstr(sound_tx);
    for i := 0 to s.Count - 1 do
    begin
      stmp := strtrim(s[i]);
      p := Pos('//', stmp);
      if p > 0 then
        stmp := Copy(stmp, 1, p - 1);
      p := Pos(';', stmp);
      if p > 0 then
        stmp := Copy(stmp, 1, p - 1);
      if stmp <> '' then
      begin
        splitstring(stmp, str1, str2, [' ', '=', Chr($09)]);
        str2 := strtrim(str2);
        if str2 <> '' then
        begin
          str1 := strtrim(str1);
          soundaliases.Add('%s=%s', [str1, str2]);
        end;
      end;
    end;
  finally
    s.Free;
  end;

// Retrive ACTORDEF lumps
  for i := 0 to W_NumLumps - 1 do
    if char8tostring(W_GetNameForNum(i)) = ACTORDEFLUMPNAME then
      SC_ParseActordefLump(W_TextLumpNum(i));
end;

//==============================================================================
//
// SC_Init
//
//==============================================================================
procedure SC_Init;
begin
  soundaliases := TDStringList.Create;
end;

//==============================================================================
//
// SC_ShutDown
//
//==============================================================================
procedure SC_ShutDown;
begin
  soundaliases.Free;
end;

end.
