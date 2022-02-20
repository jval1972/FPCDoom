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

unit sc_params;

//
// JVAL
// Dynamic Custom Parameter List for ACTORDEF LUMPS

interface

type
  customparam_t = record
    s_param: string[64];
    i_param: integer;
    f_param: single;
    i_rand1, i_rand2: integer;
    israndom: boolean;
    computed: boolean;
  end;
  Pcustomparam_t = ^customparam_t;
  customparam_tArray = array[0..$FFF] of customparam_t;
  Pcustomparam_tArray = ^customparam_tArray;

  TCustomParamList = class
  private
    fList: Pcustomparam_tArray;
    fNumItems: integer;
  protected
    function GetIsComputed(index: integer): boolean; virtual;
    function GetInteger(index: integer): integer; virtual;
    procedure PutInteger(index: Integer; const value: integer); virtual;
    function GetFloat(index: integer): single; virtual;
    procedure PutFloat(index: Integer; const value: single); virtual;
    function GetString(index: integer): string; virtual;
  public
    constructor Create(const tx: string); virtual;
    destructor Destroy; override;
    procedure Add(const value: string); virtual;
    property Count: integer read fNumItems;
    property IsComputed[index: Integer]: boolean read GetIsComputed;
    property IntVal[index: Integer]: integer read GetInteger write PutInteger;
    property FloatVal[index: Integer]: single read GetFloat write PutFloat;
    property StrVal[index: Integer]: string read GetString;
  end;

implementation

uses
  d_fpc,
  m_rnd,
  m_fixed,
  sc_engine;

//==============================================================================
//
// TCustomParamList.Create
//
//==============================================================================
constructor TCustomParamList.Create(const tx: string);
var
  i: integer;
  sc: TScriptEngine;
  token1: string;
begin
  fList := nil;
  fNumItems := 0;

  token1 := tx;
  for i := 1 to length(token1) do
    if token1[i] in ['{', ',', '}', '(', ')'] then
      token1[i] := ' ';

  sc := TScriptEngine.Create(token1);
  try
    while sc.GetString do
      Add(sc._String);
  finally
    sc.Free;
  end;
end;

//==============================================================================
//
// TCustomParamList.Destroy
//
//==============================================================================
destructor TCustomParamList.Destroy;
begin
  if fNumItems > 0 then
    {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * SizeOf(customparam_t), 0);
end;

//==============================================================================
//
// TCustomParamList.Add
//
//==============================================================================
procedure TCustomParamList.Add(const value: string);
var
  ival: integer;
  fval: single;
  token, token1, token2: string;
begin
  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * SizeOf(customparam_t), (fNumItems + 1) * SizeOf(customparam_t));
  splitstring(value, token1, token);
  if strupper(token1) = 'RANDOM' then
  begin
    fList[fNumItems].israndom := true;
    fList[fNumItems].computed := false;
    if token = '' then
    begin
      fList[fNumItems].i_rand1 := 0;
      fList[fNumItems].i_rand2 := 255;
    end
    else
    begin
      splitstring(token, token1, token2);
      if token2 = '' then
      begin
        fList[fNumItems].i_rand1 := 0;
        fList[fNumItems].i_rand2 := atoi(token1, 255);
      end
      else
      begin
        fList[fNumItems].i_rand1 := atoi(token1, 0);
        fList[fNumItems].i_rand2 := atoi(token2, 255);
      end;
    end;
  end
  else
  begin
    fList[fNumItems].israndom := false;
    fList[fNumItems].s_param := value;
    ival := atoi(value);
    fList[fNumItems].i_param := ival;
    fList[fNumItems].computed := itoa(ival) = value;
    if fList[fNumItems].computed then
      fList[fNumItems].f_param := ival
    else
    begin
      fval := atof(value);
      fList[fNumItems].f_param := fval;
      fList[fNumItems].computed := ftoa(ival) = value;
    end;
  end;

  inc(fNumItems);
end;

//==============================================================================
//
// TCustomParamList.GetIsComputed
//
//==============================================================================
function TCustomParamList.GetIsComputed(index: integer): boolean;
begin
  result := fList[index].computed;
end;

//==============================================================================
//
// TCustomParamList.GetInteger
//
//==============================================================================
function TCustomParamList.GetInteger(index: integer): integer;
begin
  if (index >= 0) and (index < fNumItems) then
  begin
    if fList[index].israndom then
      result := fList[index].i_rand1 + N_Random * (fList[index].i_rand2 - fList[index].i_rand1) div 256
    else
      result := fList[index].i_param
  end
  else
    result := 0;
end;

//==============================================================================
//
// TCustomParamList.PutInteger
//
//==============================================================================
procedure TCustomParamList.PutInteger(index: Integer; const value: integer);
begin
  if (index >= 0) and (index < fNumItems) then
  begin
    fList[index].i_param := value;
    fList[index].computed := true;
    fList[index].israndom := false;
  end;
end;

//==============================================================================
//
// TCustomParamList.GetFloat
//
//==============================================================================
function TCustomParamList.GetFloat(index: integer): single;
begin
  if (index >= 0) and (index < fNumItems) then
  begin
    if fList[index].israndom then
      result := (fList[index].i_rand1 * FRACUNIT + N_Random * (fList[index].i_rand2 - fList[index].i_rand1) * 256) / FRACUNIT
    else
      result := fList[index].f_param
  end
  else
    result := 0;
end;

//==============================================================================
//
// TCustomParamList.PutFloat
//
//==============================================================================
procedure TCustomParamList.PutFloat(index: Integer; const value: float);
begin
  if (index >= 0) and (index < fNumItems) then
  begin
    fList[index].f_param := value;
    fList[index].computed := true;
    fList[index].israndom := false;
  end;
end;

//==============================================================================
//
// TCustomParamList.GetString
//
//==============================================================================
function TCustomParamList.GetString(index: integer): string;
begin
  if (index >= 0) and (index < fNumItems) then
    result := fList[index].s_param
  else
    result := '';
end;

end.
