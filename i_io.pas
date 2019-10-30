//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2018 by Jim Valavanis
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

unit i_io;

interface

uses
  d_fpc;

var
  debugfile: TFile;
  stderr: TFile;
  stdout: TFile;
  stdoutbuffer: TDStringList;

procedure I_InitializeIO;

procedure I_ShutDownIO;

procedure I_IOErrorMessageBox(const s: string);

procedure I_IOprintf(const s: string);

implementation

uses
  Windows,
  d_main,
  g_game,
  i_main,
  m_argv;

procedure I_IOErrorMessageBox(const s: string);
begin
  MessageBox(hMainWnd, PChar(s), AppTitle, MB_OK or MB_ICONERROR or MB_APPLMODAL);
end;

var
  io_lastNL: boolean = true;

procedure I_IOprintf(const s: string);
var
  p: integer;
  do_add: boolean;
  len: integer;
begin
  len := Length(s);
  if len = 0 then
    exit;

  do_add := false;
  if io_lastNL then
  begin
    p := Pos(#10, s);
    if (p = 0) or (p = len) then
      do_add := true
  end;

  io_lastNL := s[len] = #10;

  if do_add then
  begin
    if len >= 2 then
    begin
      if s[len - 1] = #13 then
        stdoutbuffer.Add(Copy(s, 1, len - 2))
      else
        stdoutbuffer.Add(Copy(s, 1, len - 1))
    end
    else
      stdoutbuffer.Add('')
  end
  else
    stdoutbuffer.Text := stdoutbuffer.Text + s;

  if IsConsole then
    write(s);
end;

procedure I_InitializeIO;
var
  dfilename: string;
  efilename: string;
  sfilename: string;
begin
  if M_CheckParm('-debugfile') <> 0 then
    sprintf(dfilename, 'FPCDoom_debug%d.txt', [consoleplayer])
  else
    dfilename := 'FPCDoom_debug.txt';
  efilename := 'FPCDoom_stderr.txt';
  sfilename := 'FPCDoom_stdout.txt';

  dfilename := M_SaveFileName(dfilename);
  efilename := M_SaveFileName(efilename);
  sfilename := M_SaveFileName(sfilename);

  printf(' error output to: %s' + #13#10, [efilename]);
  stderr := TFile.Create(efilename, fCreate);
  printf(' debug output to: %s' + #13#10, [dfilename]);
  debugfile := TFile.Create(dfilename, fCreate);
  printf(' standard output to: %s' + #13#10, [sfilename]);
  stdout := TFile.Create(sfilename, fCreate);
end;


procedure I_ShutDownIO;
begin
  stderr.Free;
  debugfile.Free;
  stdout.Free;
end;

initialization

  stdoutbuffer := TDStringList.Create;

finalization

  stdoutbuffer.Free;

end.
