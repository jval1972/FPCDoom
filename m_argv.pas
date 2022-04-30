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

unit m_argv;

interface

//
// MISC
//

const
  MAXARGS = 1024;

var
  myargc: integer;
  myargv: array[0..MAXARGS] of string;

{ Returns the position of the given parameter }
{ in the arg list (0 if not found). }

//==============================================================================
//
// M_CheckParm
//
//==============================================================================
function M_CheckParm(const check: string): integer;

//==============================================================================
//
// M_CheckParmCDROM
//
//==============================================================================
function M_CheckParmCDROM: boolean;

//==============================================================================
//
// M_InitArgv
//
//==============================================================================
procedure M_InitArgv;

//==============================================================================
//
// M_CmdShowCommandLineParams
//
//==============================================================================
procedure M_CmdShowCommandLineParams(const parm: string);

//==============================================================================
//
// M_CmdShowCmdline
//
//==============================================================================
procedure M_CmdShowCmdline(const parm: string);

//==============================================================================
//
// M_SaveFileName
//
//==============================================================================
function M_SaveFileName(const filename: string): string;

const
  CD_WORKDIR = 'c:\doomdata\';
  APP_WORKDIR = '.\data\';

implementation

uses
  d_fpc,
  c_cmds,
  i_system;

var
  cdchecked: integer = -1;

var
  cmdparams: TDStringList;

//==============================================================================
//
// M_CheckParm
//
//==============================================================================
function M_CheckParm(const check: string): integer;
var
  i: integer;
begin
  if cmdparams.IndexOf(check) < 0 then
    cmdparams.Add(check);

  for i := 1 to myargc - 1 do
    if strupper(check) = myargv[i] then
    begin
      result := i;
      exit;
    end;
  result := 0;
end;

//==============================================================================
//
// M_CheckParmCDROM
//
//==============================================================================
function M_CheckParmCDROM: boolean;
begin
  if cdchecked = -1 then
  begin
    if I_IsCDRomDrive then
      cdchecked := 1
    else
      cdchecked := M_CheckParm('-cdrom');
    if cdchecked > 0 then
      MakeDir(CD_WORKDIR);
  end;
  result := cdchecked > 0;
end;

//==============================================================================
//
// M_InitArgv
//
//==============================================================================
procedure M_InitArgv;
var
  i: integer;
  cmdln: string;
begin
  myargc := ParamCount + 1;
  for i := 0 to myargc - 1 do
  begin
    myargv[i] := strupper(ParamStr(i));
    if i = MAXARGS then
    begin
      myargc := i + 1;
      exit;
    end;
    if myargv[i] <> '' then
      if myargv[i][1] <> '-' then
        if fexists(myargv[i]) then
          myargv[i] := fexpand(myargv[i]);
  end;

  for i := myargc to MAXARGS do
    myargv[i] := '';

  cmdln := fname(myargv[0]);
  for i := 1 to myargc - 1 do
    cmdln := cmdln + ' ' + myargv[i];
  printf('%s'#13#10, [cmdln]);

  ChDir(fpath(myargv[0]));
end;

//==============================================================================
//
// M_CmdShowCommandLineParams
//
//==============================================================================
procedure M_CmdShowCommandLineParams(const parm: string);
var
  i: integer;
  mlist: TDStringList;
  mask: string;
begin
  if parm = '' then
    mask := '*'
  else
    mask := parm;
  mlist := C_GetMachingList(cmdparams, mask);
  printf('Command line parameters: '#13#10);
  for i := 0 to mlist.Count - 1 do
    printf(' %s'#13#10, [mlist[i]]);
  mlist.Free;
end;

//==============================================================================
//
// M_CmdShowCmdline
//
//==============================================================================
procedure M_CmdShowCmdline(const parm: string);
var
  i: integer;
begin
  for i := 1 to myargc - 1 do
    printf('%s ', [myargv[i]]);
  printf(#13#10);
end;

//==============================================================================
//
// M_SaveFileName
//
//==============================================================================
function M_SaveFileName(const filename: string): string;
begin
  if M_CheckParmCDROM then
    result := CD_WORKDIR + filename
  else
  begin
    MakeDir(APP_WORKDIR);
    result := APP_WORKDIR + filename;
  end;
end;

initialization
  cmdparams := TDStringList.Create;

finalization
  cmdparams.Free;

end.

