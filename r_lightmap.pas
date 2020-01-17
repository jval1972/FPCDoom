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

{$I FPCDoom.inc}

unit r_lightmap;

interface

uses
  d_fpc,
  m_fixed,
  p_mobj_h;

procedure R_InitDynamicLights;

procedure R_ShutDownDynamicLights;

procedure R_ClearDynamicLights;

procedure R_MarkDLights(const mo: Pmobj_t);

procedure R_AddAdditionalLights;

procedure R_CalcLights;

var
  lightdeflumppresent: boolean = false;
  uselightmap: boolean = true;
  lightmapaccuracymode: integer = 0;
  lightmapcolorintensity: integer = 64;
  lightwidthfactor: integer = 5;

const
  MINLIGHTWIDTHFACTOR = 0;
  DEFLIGHTWIDTHFACTOR = 5;
  MAXLIGHTWIDTHFACTOR = 10;
  MINLMCOLORSENSITIVITY = 32;
  DEFLMCOLORSENSITIVITY = 64;
  MAXLMCOLORSENSITIVITY = 160;

const
  NUMLIGHTMAPACCURACYMODES = 4;
  MAXLIGHTMAPACCURACYMODE = NUMLIGHTMAPACCURACYMODES - 1;

function R_CalcLigmapYAccuracy: integer;

function R_CastLightmapOnMasked: boolean;

implementation

uses
  d_main,
  doomdef,
  m_rnd,
  p_tick,
  w_wad,
  info,
  i_system,
  p_pspr,
  p_local,
  p_maputl,
  p_setup,
  tables,
  r_zbuffer,
  r_draw,
  r_draw_light,
  r_main,
  r_render,
  r_lights,
  sc_engine,
  sc_tokens;

const
  DLSTRLEN = 32;

type
  GLDlightType = (
    GLDL_POINT,   // Point light
    GLDL_FLICKER, // Flicker light
    GLDL_PULSE,   // pulse light
    GLDL_NUMDLIGHTTYPES,
    GLDL_UNKNOWN  // unknown light
  );

type
  GLDRenderLight = record
    r, g, b: float;     // Color
    radius: float;      // radius
    x, y, z: float;     // Offset
  end;
  PGLDRenderLight = ^GLDRenderLight;
  GLDRenderLightArray = array[0..$FFF] of GLDRenderLight;
  PGLDRenderLightArray = ^GLDRenderLightArray;

  GLDLight = record
    name: string[DLSTRLEN];             // Light name
    lighttype: GLDlightType;            // Light type
    r1, g1, b1: float;                  // Color
    r2, g2, b2: float;                  // Color
    colorinterval: integer;             // color interval in TICRATE * FRACUNIT
    colorchance: integer;
    size1: float;                       // Size
    size2: float;                       // Secondarysize for flicker and pulse lights
    interval: integer;                  // interval in TICRATE * FRACUNIT
    chance: integer;
    offsetx1, offsety1, offsetz1: float;   // Offset
    offsetx2, offsety2, offsetz2: float;   // Offset
    randomoffset: boolean;
    validcount: integer;
    randomseed: integer;
    renderinfo: GLDRenderLight;
  end;

  PGLDLight = ^GLDLight;
  GLDLightArray = array[0..$FFFF] of GLDLight;
  PGLDLightArray = ^GLDLightArray;

type
  Pvislight_t = ^vislight_t;
  vislight_t = record
    x1: integer;
    x2: integer;

    // for line side calculation
    gx: fixed_t;
    gy: fixed_t;

    // global bottom / top for silhouette clipping
    gz: fixed_t;

    // horizontal position of x1
    startfrac: fixed_t;

    scale: fixed_t;
    xiscale: fixed_t;

    dbmin: LongWord;
    dbmax: LongWord;
    dbdmin: LongWord;
    dbdmax: LongWord;

    texturemid: fixed_t;

    color32: LongWord;
  end;

const
  MAXVISLIGHTS = 1024;

var
  vislight_p: integer = 0;
  vislights: array[0..MAXVISLIGHTS - 1] of vislight_t;

type
  dlsortitem_t = record
    l: PGLDRenderLight;
    squaredist: single;
    x, y, z: fixed_t;
    radius: fixed_t;
    vis: Pvislight_t;
  end;
  Pdlsortitem_t = ^dlsortitem_t;
  dlsortitem_tArray = array[0..$FFFF] of dlsortitem_t;
  Pdlsortitem_tArray = ^dlsortitem_tArray;

var
  dlbuffer: Pdlsortitem_tArray = nil;
  numdlitems: integer = 0;
  realdlitems: integer = 0;

function R_NewVisLight: Pvislight_t;
begin
  if vislight_p = MAXVISLIGHTS then
    result := @vislights[MAXVISLIGHTS - 1]
  else
  begin
    result := @vislights[vislight_p];
    inc(vislight_p);
  end;
end;

function SpriteNumForName(const name: string): integer;
var
  spr_name: string;
  i: integer;
  check: integer;
begin
  result := atoi(name, -1);

  if (result >= 0) and (result < numsprites) and (itoa(result) = name) then
    exit;


  if Length(name) <> 4 then
  begin
    result := -1;
    exit;
  end;

  spr_name := strupper(name);

  check := Ord(spr_name[1]) +
           Ord(spr_name[2]) shl 8 +
           Ord(spr_name[3]) shl 16 +
           Ord(spr_name[4]) shl 24;

  for i := 0 to numsprites - 1 do
    if sprnames[i] = check then
    begin
      result := i;
      exit;
    end;

  result := -1;
end;

var
  numdlights: integer;
  realnumdlights: integer;
  dlightslist: PGLDLightArray;

var
// JVAL: Random index for light animation operations,
//       don't bother reseting it.... (?)
  lightrnd: integer = 0;

procedure R_GrowDynlightsArray;
begin
  if numdlights >= realnumdlights then
  begin
    if realnumdlights = 0 then
    begin
      realnumdlights := 32;
      dlightslist := malloc(realnumdlights * SizeOf(GLDLight));
    end
    else
    begin
      realloc(dlightslist, realnumdlights * SizeOf(GLDLight), (realnumdlights + 32) * SizeOf(GLDLight));
      realnumdlights := realnumdlights + 32;
    end;
  end;
end;

function R_AddDynamicLight(const l: GLDLight): integer;
var
  i: integer;
begin
  R_GrowDynlightsArray;
  result := numdlights;
  dlightslist[result] := l;
  for i := 1 to DLSTRLEN do
    dlightslist[result].name[i] := toupper(dlightslist[result].name[i]);
  inc(numdlights);
end;

function R_FindDynamicLight(const check: string): integer;
var
  i: integer;
  tmp: string;
begin
  tmp := strupper(check);
  for i := numdlights - 1 downto 0 do
    if tmp = dlightslist[i].name then
    begin
      result := i;
      exit;
    end;

  result := -1;
end;


const
  LIGHTSLUMPNAME = 'LIGHTDEF';

//
// SC_ParceDynamicLights
// JVAL: Parse LIGHTDEF
//
procedure SC_ParceDynamicLight(const in_text: string);
var
  sc: TScriptEngine;
  slist: TDStringList;
  i, j: integer;
  l: GLDLight;
  token: string;
  token1, token2, token3, token4: string;
  token_idx: integer;
  tokens: TTokenList;
  objectsfound: boolean;
  stmp: string;
  lidx: integer;
  frame: integer;
  sprite: integer;
  foundstate: boolean;
begin
  tokens := TTokenList.Create;
  tokens.Add('POINTLIGHT');
  tokens.Add('FLICKERLIGHT, FLICKERLIGHT2');
  tokens.Add('PULSELIGHT');
  tokens.Add('OBJECT');
  tokens.Add('COLOR, COLOR1, PRIMARYCOLOR');
  tokens.Add('COLOR2, SECONDARYCOLOR');
  tokens.Add('SIZE, SIZE1, PRIMARYSIZE');
  tokens.Add('SIZE2, SECONDARYSIZE');
  tokens.Add('INTERVAL');
  tokens.Add('COLORINTERVAL');
  tokens.Add('CHANCE');
  tokens.Add('COLORCHANCE');
  tokens.Add('OFFSET, OFFSET1, PRIMARYOFFSET');
  tokens.Add('OFFSET2, SECONDARYOFFSET');
  tokens.Add('RANDOMOFFSET');

  if devparm then
  begin
    printf('--------'#13#10);
    printf('SC_ParceDynamicLight(): Parsing %s lump:'#13#10, [LIGHTSLUMPNAME]);

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

  objectsfound := false;

  sc := TScriptEngine.Create(in_text);

  while sc.GetString do
  begin
    token := strupper(sc._String);
    token_idx := tokens.IndexOfToken(token);
    case token_idx of
      0, 1, 2:
        begin
          ZeroMemory(@l, SizeOf(GLDLight));
          l.lighttype := GLDlightType(token_idx);
          l.validcount := -1;
          l.randomseed := C_Random(lightrnd) * 256 + C_Random(lightrnd);
          if not sc.GetString then
          begin
            I_Warning('SC_ParceDynamicLight(): Token expected at line %d'#13#10, [sc._Line]);
            break;
          end;
          l.name := strupper(sc._String);

          while sc.GetString do
          begin
            token := strupper(sc._String);
            token_idx := tokens.IndexOfToken(token);
            case token_idx of
               4:  // Color
                begin
                  sc.MustGetFloat;
                  l.r1 := sc._Float;
                  l.r2 := l.r1;
                  sc.MustGetFloat;
                  l.g1 := sc._Float;
                  l.g2 := l.g1;
                  sc.MustGetFloat;
                  l.b1 := sc._Float;
                  l.b2 := l.b1;
                end;
               5:  // Secondary Color
                begin
                  sc.MustGetFloat;
                  l.r2 := sc._Float;
                  sc.MustGetFloat;
                  l.g2 := sc._Float;
                  sc.MustGetFloat;
                  l.b2 := sc._Float;
                end;
               6:  // Size
                begin
                  sc.MustGetInteger;
                  l.size1 := sc._Integer;
                  l.size2 := l.size1;
                end;
               7:  // Secondary Size
                begin
                  sc.MustGetInteger;
                  l.size2 := sc._Integer;
                end;
               8:  // Interval
                begin
                  sc.MustGetFloat;
                  if sc._float > 0.0 then
                    l.interval := Round(1 / sc._float * FRACUNIT * TICRATE);
                end;
               9:  // ColorInterval
                begin
                  sc.MustGetFloat;
                  if sc._float > 0.0 then
                    l.colorinterval := Round(1 / sc._float * FRACUNIT * TICRATE);
                end;
              10:  // Chance
                begin
                  sc.MustGetFloat;
                  l.chance := Round(sc._float * 255);
                  if l.chance < 0 then
                    l.chance := 0
                  else if l.chance > 255 then
                    l.chance := 255;
                end;
              11:  // ColorChance
                begin
                  sc.MustGetFloat;
                  l.colorchance := Round(sc._float * 255);
                  if l.colorchance < 0 then
                    l.colorchance := 0
                  else if l.colorchance > 255 then
                    l.colorchance := 255;
                end;
              12:  // Offset
                begin
                  sc.MustGetInteger;
                  l.offsetx1 := sc._Integer;
                  l.offsetx2 := l.offsetx1;
                  sc.MustGetInteger;
                  l.offsety1 := sc._Integer;
                  l.offsety2 := l.offsety1;
                  sc.MustGetInteger;
                  l.offsetz1 := sc._Integer;
                  l.offsetz2 := l.offsetz1;
                end;
              13:  // Offset2
                begin
                  sc.MustGetInteger;
                  l.offsetx2 := sc._Integer;
                  sc.MustGetInteger;
                  l.offsety2 := sc._Integer;
                  sc.MustGetInteger;
                  l.offsetz2 := sc._Integer;
                end;
              14:
                begin
                  l.randomoffset := true;
                end;
            else
              begin
                R_AddDynamicLight(l);
                sc.UnGet;
                break;
              end;
            end;
          end;

        end;

      3:
        begin
          objectsfound := true;
        end;
//    else
//      I_Warning('SC_ParceDynamicLight(): Unknown token %s at line %d'#13#10, [sc._String, sc._Line]);

    end;
  end;

  tokens.Free;

  // JVAL: Simplified parsing for frames keyword
  if objectsfound then
  begin
    slist := TDStringList.Create;
    slist.Text := in_text;

    for i := 0 to slist.Count - 1 do
    begin
      stmp := strupper(strtrim(slist.Strings[i]));
      if firstword(stmp) = 'FRAME' then
      begin
        sc.SetText(stmp);

        sc.MustGetString;
        token1 := sc._String;
        sc.MustGetString;
        token2 := sc._String;
        sc.MustGetString;
        token3 := sc._String;
        sc.MustGetString;
        token4 := sc._String;

        if token3 = 'LIGHT' then
        begin
          lidx := R_FindDynamicLight(token4);
          if lidx >= 0 then
          begin
            if Length(token2) >= 4 then
            begin
              token := '';
              for j := 1 to 4 do
                token := token + token2[j];
              sprite := SpriteNumForName(token);
              if sprite >= 0 then
              begin
                if Length(token2) > 4 then
                begin
                  frame := Ord(token2[5]) - Ord('A');
                  foundstate := false;
                  for j := 0 to numstates - 1 do
                    if (states[j].sprite = sprite) and
                       ((states[j].frame and FF_FRAMEMASK) = frame) then
                    begin
                      if states[j].dlights = nil then
                        states[j].dlights := TDNumberList.Create;
                      states[j].dlights.Add(lidx);
                      foundstate := true;
                    end;
                  if not foundstate then
                    I_Warning('SC_ParceDynamicLight(): Can not determine light owner, line %d: "%s",'#13#10, [i + 1, stmp]);

                end
                else
                begin
                  foundstate := false;
                  for j := 0 to numstates - 1 do
                    if states[j].sprite = sprite then
                    begin
                      if states[j].dlights = nil then
                        states[j].dlights := TDNumberList.Create;
                      states[j].dlights.Add(lidx);
                      foundstate := true;
                    end;
                  if not foundstate then
                    I_DevError('SC_ParceDynamicLight(): Can not determine light owner, line %d: "%s",'#13#10, [i + 1, stmp]);
                end;
              end
              else
                I_Warning('SC_ParceDynamicLight(): Unknown sprite %s at line %d'#13#10, [token, i + 1]);
            end
            else
              I_Warning('SC_ParceDynamicLight(): Unknown sprite %s at line %d'#13#10, [token2, i + 1]);
          end
          else
            I_Warning('SC_ParceDynamicLight(): Unknown light %s at line %d'#13#10, [token4, i + 1]);
        end
        else
          I_Warning('SC_ParceDynamicLight(): Unknown token %s at line %d'#13#10, [token3, i + 1]);
      end;
    end;
    slist.Free;

  end;

  sc.Free;
end;

//
// SC_ParceDynamicLights
// JVAL: Parse all LIGHTDEF lumps
//
procedure SC_ParceDynamicLights;
var
  i: integer;
begin
// Retrive lightdef lumps
  for i := 0 to W_NumLumps - 1 do
    if char8tostring(W_GetNameForNum(i)) = LIGHTSLUMPNAME then
    begin
      lightdeflumppresent := true;
      SC_ParceDynamicLight(W_TextLumpNum(i));
    end;
end;

procedure R_InitDynamicLights;
begin
  numdlights := 0;
  realnumdlights := 0;
  dlightslist := nil;
  printf(#13#10'SC_ParceDynamicLights: Parsing LIGHTDEF lumps.');
  SC_ParceDynamicLights;
end;

procedure R_ShutDownDynamicLights;
begin
  memfree(dlightslist, realnumdlights * SizeOf(GLDLight));
  numdlights := 0;
  realnumdlights := 0;

  memfree(dlbuffer, realdlitems * SizeOf(dlsortitem_t));
  numdlitems := 0;
  realdlitems := 0;
end;

procedure R_ClearDynamicLights;
begin
  numdlitems := 0;
  vislight_p := 0;
end;

//
// R_GetDynamicLight
// JVAL: Retrieving rendering information for lights
//       Dynamic lights animations
//
function R_GetDynamicLight(const index: integer): PGLDRenderLight;
var
  l: PGLDLight;
  frac: integer;
  frac1, frac2: single;

  procedure _CalcOffset(prl: PGLDRenderLight; const recalc: boolean);
  var
    rnd: integer;
  begin
    if l.randomoffset then
    begin
      rnd := C_Random(lightrnd);
      prl.x := (l.offsetx1 * rnd + l.offsetx2 * (255 - rnd)) / 255;
      rnd := C_Random(lightrnd);
      prl.y := (l.offsety1 * rnd + l.offsety2 * (255 - rnd)) / 255;
      rnd := C_Random(lightrnd);
      prl.z := (l.offsetz1 * rnd + l.offsetz2 * (255 - rnd)) / 255;
    end
    else if recalc then
    begin
      prl.x := l.offsetx1;
      prl.y := l.offsety1;
      prl.z := l.offsetz1;
    end;
  end;

begin
  l := @dlightslist[index];
  result := @l.renderinfo;

  // JVAL: Point lights, a bit static :)
  if l.lighttype = GLDL_POINT then
  begin
    if l.validcount < 0 then
    begin
      result.r := l.r1;
      result.g := l.g1;
      result.b := l.b1;
      result.radius := l.size1;
      _CalcOffset(result, true);
    end
    else if l.validcount <> leveltime then
      _CalcOffset(result, false);
    l.validcount := leveltime;
    exit;
  end;

  // JVAL: Flicker lights, use chance/colorchance to switch size/color
  if l.lighttype = GLDL_FLICKER then
  begin
    if l.validcount <> leveltime div TICRATE then
    begin

      // Determine color
      if l.colorchance > 0 then
      begin
        if C_Random(lightrnd) < l.colorchance then
        begin
          result.r := l.r1;
          result.g := l.g1;
          result.b := l.b1;
        end
        else
        begin
          result.r := l.r2;
          result.g := l.g2;
          result.b := l.b2;
        end;
      end
      else if l.colorinterval > 0 then
      begin
        if Odd(FixedDiv(l.randomseed + leveltime * FRACUNIT, l.colorinterval)) then
        begin
          result.r := l.r1;
          result.g := l.g1;
          result.b := l.b1;
        end
        else
        begin
          result.r := l.r2;
          result.g := l.g2;
          result.b := l.b2;
        end;
      end
      else
      begin
        result.r := l.r1;
        result.g := l.g1;
        result.b := l.b1;
      end;

      // Determine size
      if l.chance > 0 then
      begin
        if C_Random(lightrnd) < l.chance then
          result.radius := l.size1
        else
          result.radius := l.size2;
      end
      else if l.interval > 0 then
      begin
        if Odd(FixedDiv(l.randomseed + leveltime * FRACUNIT, l.interval)) then
          result.radius := l.size1
        else
          result.radius := l.size2;
      end
      else
        result.radius := l.size1;

      _CalcOffset(result, l.validcount < 0);
      l.validcount := leveltime div TICRATE;
    end;
    exit;
  end;

  // JVAL: Pulse lights, use leveltime to switch smoothly size/color
  if l.lighttype = GLDL_PULSE then
  begin
    if l.validcount <> leveltime then
    begin
      // Determine color,
      if l.colorinterval > 0 then
      begin
        frac := FixedDiv(l.randomseed + leveltime * FRACUNIT, l.colorinterval) mod l.colorinterval;
        frac1 := frac / l.colorinterval;
        frac2 := 1.0 - frac1;
        result.r := l.r1 * frac1 + l.r2 * frac2;
        result.g := l.g1 * frac1 + l.g2 * frac2;
        result.b := l.b1 * frac1 + l.b2 * frac2;
      end
      // colorchance should not be present in pulse light but just in case
      else if l.colorchance > 0 then
      begin
        if C_Random(lightrnd) < l.colorchance then
        begin
          result.r := l.r1;
          result.g := l.g1;
          result.b := l.b1;
        end
        else
        begin
          result.r := l.r2;
          result.g := l.g2;
          result.b := l.b2;
        end;
      end
      else
      begin
        result.r := l.r1;
        result.g := l.g1;
        result.b := l.b1;
      end;

      // Determine size
      if l.interval > 0 then
      begin
        frac := FixedDiv(l.randomseed + leveltime * FRACUNIT, l.interval) mod l.interval;
        frac1 := frac / l.interval;
        frac2 := 1.0 - frac1;
        result.radius := l.size1 * frac1 + l.size2 * frac2;
      end
      // chance should be present in pulse light but just in case
      else if l.chance > 0 then
      begin
        if C_Random(lightrnd) < l.chance then
          result.radius := l.size1
        else
          result.radius := l.size2;
      end
      else
        result.radius := l.size1;

      _CalcOffset(result, l.validcount < 0);
      l.validcount := leveltime;
    end;
    exit;
  end;

end;

procedure R_MarkDLights(const mo: Pmobj_t);
var
  l: PGLDRenderLight;
  i: integer;
  dx, dy, dz: single;
  xdist, ydist, zdist: single;
  psl: Pdlsortitem_t;
  dlights: TDNumberList;
begin
  if mo.lightvalidcount = rendervalidcount then
    exit;

  dlights := mo.state.dlights;
  if dlights = nil then
    exit;

  mo.lightvalidcount := rendervalidcount;

  xdist := (viewx - mo.x) / FRACUNIT;
  ydist := (viewy - mo.y) / FRACUNIT;
  zdist := (viewz - mo.z) / FRACUNIT;

  for i := 0 to dlights.Count - 1 do
  begin
    l := R_GetDynamicLight(dlights.Numbers[i]);
    if numdlitems >= realdlitems then
    begin
      realloc(dlbuffer, realdlitems * SizeOf(dlsortitem_t), (realdlitems + 32) * SizeOf(dlsortitem_t));
      realdlitems := realdlitems + 32;
    end;

    psl := @dlbuffer[numdlitems];
    psl.l := l;
    // Convert offset coordinates from LIGHTDEF lump
    dx := xdist - l.x;
    dy := ydist - l.z;
    dz := zdist - l.y;
    psl.squaredist := dx * dx + dy * dy + dz * dz;
    psl.x := mo.x + Trunc(FRACUNIT * l.x);
    psl.y := mo.y + Trunc(FRACUNIT * l.z);
    psl.z := mo.z + Trunc(FRACUNIT * l.y);
    psl.radius := Trunc(l.radius * FRACUNIT);
    inc(numdlitems);
  end;
end;

function RIT_AddAdditionalLights(mo: Pmobj_t): boolean;
begin
  R_MarkDLights(mo);
  // keep checking
  result := true;
end;

const
  MAXLIGHTRADIUS = 256 * FRACUNIT;

procedure R_AddAdditionalLights;
var
  x: integer;
  y: integer;
  xl: integer;
  xh: integer;
  yl: integer;
  yh: integer;
begin
  yh := MapBlockInt(viewy + MAXLIGHTRADIUS - bmaporgy);
  yl := MapBlockInt(viewy - MAXLIGHTRADIUS - bmaporgy);
  xh := MapBlockInt(viewx + MAXLIGHTRADIUS - bmaporgx);
  xl := MapBlockInt(viewx - MAXLIGHTRADIUS - bmaporgx);

  for y := yl to yh do
    for x := xl to xh do
      P_BlockThingsIterator(x, y, RIT_AddAdditionalLights);
end;

const
  DEPTHBUFFER_NEAR = $3FFF * FRACUNIT;
  DEPTHBUFFER_FAR = 256;

function R_GetVisLightProjection(const x, y, z: fixed_t; const radius: fixed_t; const color: LongWord): Pvislight_t;
var
  tr_x: fixed_t;
  tr_y: fixed_t;
  gxt: fixed_t;
  gyt: fixed_t;
  tx: fixed_t;
  tz: fixed_t;
  xscale: fixed_t;
  x1: integer;
  x2: integer;
  an: angle_t;
  dx, dy: fixed_t;
begin
  result := nil;

  // transform the origin point
  tr_x := x - viewx;
  tr_y := y - viewy;

  gxt := FixedMul(tr_x, viewcos);
  gyt := -FixedMul(tr_y, viewsin);

  tz := gxt - gyt;

  // thing is behind view plane?
  if tz <= 4 * FRACUNIT then
    exit;

  xscale := FixedDiv(projection, tz);
  if xscale > DEPTHBUFFER_NEAR then
    xscale := DEPTHBUFFER_NEAR;

  gxt := -FixedMul(tr_x, viewsin);
  gyt := FixedMul(tr_y, viewcos);
  tx := -(gyt + gxt);

  // too far off the side?
  if abs(tx) > 4 * tz then
    exit;

  // calculate edges of the shape
  tx := tx - radius;
  x1 := FixedInt(centerxfrac + FixedMul(tx, xscale));

  // off the right side?
  if x1 > viewwidth then
    exit;

  tx := tx + 2 * radius;
  x2 := FixedInt(centerxfrac + FixedMul(tx, xscale)) - 1;

  // off the left side
  if x2 < 0 then
    exit;

  // OK, we have a valid vislight
  result := R_NewVisLight;
  // store information in a vissprite
  result.scale := FixedDiv(projectiony, tz); // JVAL For correct aspect
  result.gx := x;
  result.gy := y;
  result.gz := z;
  result.texturemid := z + radius - viewz;
  result.xiscale := FixedDiv(FRACUNIT, xscale);

  if x1 <= 0 then
  begin
    result.x1 := 0;
    result.startfrac := result.xiscale * (result.x1 - x1);
  end
  else
  begin
    result.x1 := x1;
    result.startfrac := 0;
  end;
  if x2 >= viewwidth then
    result.x2 := viewwidth - 1
  else
    result.x2 := x2;


  // get depthbuffer range
  an := R_PointToAngle(x, y);
  an := an shr ANGLETOFINESHIFT;
  dx := FixedMul(radius, finecosine[an]);
  dy := FixedMul(radius, finesine[an]);

  tr_x := x - viewx + dx;
  tr_y := y - viewy + dy;

  gxt := FixedMul(tr_x, viewcos);
  gyt := -FixedMul(tr_y, viewsin);

  tz := gxt - gyt;

  if tz <= 4 * FRACUNIT then
    result.dbmin := DEPTHBUFFER_NEAR
  else
  begin
    result.dbmin := FixedDiv(projectiony, tz);
    if result.dbmin > DEPTHBUFFER_NEAR then
      result.dbmin := DEPTHBUFFER_NEAR
    else if result.dbmin < 256 then
      result.dbmin := 256;
  end;

  tr_x := x - viewx - dx;
  tr_y := y - viewy - dy;

  gxt := FixedMul(tr_x, viewcos);
  gyt := -FixedMul(tr_y, viewsin);

  tz := gxt - gyt;

  if tz <= 4 * FRACUNIT then
    result.dbmax := DEPTHBUFFER_NEAR
  else
  begin
    result.dbmax := FixedDiv(projectiony, tz);
    if result.dbmax > DEPTHBUFFER_NEAR then
      result.dbmax := DEPTHBUFFER_NEAR
    else if result.dbmax < DEPTHBUFFER_FAR then
      result.dbmax := DEPTHBUFFER_FAR;
  end;
  if result.dbmax = result.dbmin then
  begin
    result.dbmax := result.scale + DEPTHBUFFER_FAR;
    if result.scale < 2 * DEPTHBUFFER_FAR then
      result.dbmin := DEPTHBUFFER_FAR
    else
      result.dbmin := result.scale - DEPTHBUFFER_FAR;
    result.dbdmin := DEPTHBUFFER_FAR;
    result.dbdmax := DEPTHBUFFER_FAR;
  end
  else
  begin
    result.dbdmin := result.scale - result.dbmin;
    result.dbdmax := result.dbmax - result.scale;
  end;

  result.color32 := color;
end;

procedure R_DrawVisLight(const psl: Pdlsortitem_t);
var
  frac: fixed_t;
  fracstep: fixed_t;
  vis: Pvislight_t;
  w: float;
  spryscale: fixed_t;
  ltopscreen: fixed_t;
  texturecolumn: integer;
  ltopdelta: integer;
  llength: integer;
  topscreen: int64;
  bottomscreen: int64;
begin
  vis := psl.vis;
  w := 2 * psl.l.radius * lightwidthfactor / DEFLIGHTWIDTHFACTOR;
  frac := Trunc(vis.startfrac * LIGHTBOOSTSIZE / w);
  fracstep := Trunc(vis.xiscale * LIGHTBOOSTSIZE / w);
  spryscale := Trunc(vis.scale * w / LIGHTBOOSTSIZE);
  lcolumn.lightsourcex := psl.x;
  lcolumn.lightsourcey := psl.y;
  lcolumn.dl_iscale := FixedDivEx(FRACUNIT, spryscale);
  lcolumn.dl_fracstep := FixedDivEx(FRACUNIT, Trunc(vis.scale * w / LIGHTBOOSTSIZE));
  lcolumn.dl_scale := vis.scale;
  ltopscreen := centeryfrac - FixedMul(vis.texturemid, vis.scale);

  lcolumn.db_min := vis.dbmin;
  lcolumn.db_max := vis.dbmax;
  lcolumn.db_dmin := vis.dbdmin;
  lcolumn.db_dmax := vis.dbdmax;

  lcolumn.r := (vis.color32 shr 16) and $FF;
  lcolumn.g := (vis.color32 shr 8) and $FF;
  lcolumn.b := vis.color32 and $FF;

  lcolumn.dl_x := vis.x1;

  R_ZSetCriticalX(vis.x1 - 1, true);
  R_ZSetCriticalX(vis.x1, true);
  R_ZSetCriticalX(vis.x2, true);
  R_ZSetCriticalX(vis.x2 + 1, true);

  while lcolumn.dl_x <= vis.x2 do
  begin
    if R_ValidLightColumn(lcolumn.dl_x) then
    begin
      texturecolumn := (LongWord(frac) shr FRACBITS) and (LIGHTBOOSTSIZE - 1);
      ltopdelta := lightexturelookup[texturecolumn].topdelta;
      llength := lightexturelookup[texturecolumn].length;
      lcolumn.dl_source32 := @lighttexture[texturecolumn * LIGHTBOOSTSIZE + ltopdelta];
      topscreen := ltopscreen + int64(spryscale) * int64(ltopdelta);
      bottomscreen := topscreen + int64(spryscale) * int64(llength);

      lcolumn.dl_yl := FixedInt64(topscreen + (FRACUNIT - 1));
      lcolumn.dl_yh := FixedInt64(bottomscreen - 1);
      lcolumn.dl_texturemid := (centery - lcolumn.dl_yl) * lcolumn.dl_iscale;

      if lcolumn.dl_yh >= viewheight then
        lcolumn.dl_yh := viewheight - 1;
      if lcolumn.dl_yl < 0 then
        lcolumn.dl_yl := 0;

      if lcolumn.dl_yl <= lcolumn.dl_yh then
        R_AddRenderTask(lightcolfunc, RF_LIGHT, @lcolumn);
    end;
    frac := frac + fracstep;
    inc(lcolumn.dl_x);
  end;
end;

function f2b(const ff: float): byte;
var
  ii: integer;
begin
  ii := Trunc(ff * 256);
  if ii <= 0 then
    result := 0
  else if ii >= 255 then
    result := 255
  else
    result := ii;
end;

procedure R_CalcLight(const psl: Pdlsortitem_t);
var
  c: LongWord;
begin
  if fixedcolormapnum = INVERSECOLORMAP then
    c := $FFFFFF
  else
    c := f2b(psl.l.b) + f2b(psl.l.g) shl 8 + f2b(psl.l.r) shl 16;
  psl.vis := R_GetVisLightProjection(psl.x, psl.y, psl.z, psl.radius * lightwidthfactor div 5, c);
  if psl.vis = nil then
    exit;
  R_DrawVisLight(psl);
end;

//
//  R_SortDlights()
//  JVAL: Sort the dynamic lights according to square distance of view
//        (note: closer light is first!)
//
procedure R_SortDlights;

  procedure qsort(l, r: Integer);
  var
    i, j: Integer;
    tmp: dlsortitem_t;
    squaredist: float;
  begin
    repeat
      i := l;
      j := r;
      squaredist := dlbuffer[(l + r) shr 1].squaredist;
      repeat
        while dlbuffer[i].squaredist < squaredist do
          inc(i);
        while dlbuffer[j].squaredist > squaredist do
          dec(j);
        if i <= j then
        begin
          tmp := dlbuffer[i];
          dlbuffer[i] := dlbuffer[j];
          dlbuffer[j] := tmp;
          inc(i);
          dec(j);
        end;
      until i > j;
      if l < j then
        qsort(l, j);
      l := i;
    until i >= r;
  end;

begin
  if numdlitems > 0 then
    qsort(0, numdlitems - 1);
end;

procedure R_CalcLights;
var
  i: integer;
begin
  R_SortDlights;
  for i := 0 to numdlitems - 1 do
    R_CalcLight(@dlbuffer[i]);
end;

type
  dropoffitem_t = record
    maxwidth: integer;
    laccuraccy: array[0..NUMLIGHTMAPACCURACYMODES - 1] of integer;
  end;

const
  NUMDROPOFFARRAYITEMS = 7;

var
  dropoffarray: array[0..NUMDROPOFFARRAYITEMS - 1] of dropoffitem_t = (
    (maxwidth: 320;        laccuraccy: (3, 2, 1, 1)),
    (maxwidth: 640;        laccuraccy: (4, 3, 2, 1)),
    (maxwidth: 1024;       laccuraccy: (5, 4, 3, 1)),//2)),
    (maxwidth: 1280;       laccuraccy: (6, 5, 4, 1)),//3)),
    (maxwidth: 1366;       laccuraccy: (6, 5, 4, 1)),//3)),
    (maxwidth: 1600;       laccuraccy: (7, 6, 5, 1)),//4)),
    (maxwidth: 2147483647; laccuraccy: (8, 7, 6, 1)) //5))
  );

function R_CalcLigmapYAccuracy: integer;
var
  i, idx: integer;
begin
  lightmapaccuracymode := lightmapaccuracymode mod NUMLIGHTMAPACCURACYMODES;

  idx := 0;
  for i := 0 to NUMDROPOFFARRAYITEMS - 1 do
    if viewwidth <= dropoffarray[i].maxwidth then
    begin
      idx := i;
      break;
    end;

  result := dropoffarray[idx].laccuraccy[lightmapaccuracymode];
end;

function R_CastLightmapOnMasked: boolean;
begin
  result := uselightmap and (lightmapaccuracymode = MAXLIGHTMAPACCURACYMODE);
end;

end.

