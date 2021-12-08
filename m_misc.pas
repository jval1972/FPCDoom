//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2021 by Jim Valavanis
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

unit m_misc;

interface

//
// MISC
//

function M_WriteFile(const name: string; source: pointer; length: integer): boolean;

function M_ReadFile(const name: string; var buffer: Pointer): integer;

procedure M_ScreenShot(const filename: string = ''; const silent: boolean = false);

function M_DoScreenShot(const filename: string): boolean;

procedure M_SetDefaults;

procedure M_SetDefault(const parm: string);

procedure M_LoadDefaults;

procedure M_SaveDefaults;

procedure Cmd_Set(const name: string; const value: string);

procedure Cmd_Get(const name: string);

procedure Cmd_TypeOf(const name: string);

var
  yesnoStrings: array[boolean] of string = ('NO', 'YES');
  truefalseStrings: array[boolean] of string = ('FALSE', 'TRUE');
  confignotfound: Boolean = true;
  screenshottype: string = 'png';

implementation

uses
  d_fpc,
  c_cmds,
  doomdef,
  d_main,
  d_player,
  g_game,
  m_argv,
  m_defs,
  m_menu,
  t_png,
  i_system,
  i_video,
  z_memory;

function M_WriteFile(const name: string; source: pointer; length: integer): boolean;
var
  handle: file;
  count: integer;
begin
  if not fopen(handle, name, fCreate) then
  begin
    result := false;
    exit;
  end;

  BlockWrite(handle, source^, length, count);
  close(handle);

  result := count > 0;
end;

function M_ReadFile(const name: string; var buffer: Pointer): integer;
var
  handle: file;
  count: integer;
begin
  if not fopen(handle, name, fOpenReadOnly) then
    I_Error('M_ReadFile(): Could not read file %s', [name]);

  result := FileSize(handle);
  // JVAL
  // If Z_Malloc changed to malloc() a lot of changes must be made....
  buffer := Z_Malloc(result, PU_STATIC, nil);
  BlockRead(handle, buffer^, result, count);
  close(handle);

  if count < result then
    I_Error('M_ReadFile(): Could not read file %s', [name]);
end;

const
  MSG_ERR_SCREENSHOT = 'Couldn''t create a screenshot';

//
// M_ScreenShot
//
type
  BMP_Header = packed record
    bfType1         : Char    ; (* "B"                                *)
    bfType2         : Char    ; (* "M"                                *)
    bfSize          : LongInt ; (* Size of File                       *)
    bfReserved1     : Word    ; (* Zero                               *)
    bfReserved2     : Word    ; (* Zero                               *)
    bfOffBits       : LongInt ; (* Offset to beginning of BitMap      *)
    biSize          : LongInt ; (* Number of Bytes in Structure       *)
    biWidth         : LongInt ; (* Width  of BitMap in Pixels         *)
    biHeight        : LongInt ; (* Height of BitMap in Pixels         *)
    biPlanes        : Word    ; (* Planes in target device = 1        *)
    biBitCount      : Word    ; (* Bits per Pixel 1, 4, 8, or 24      *)
    biCompression   : LongInt ; (* BI_RGB = 0, BI_RLE8, BI_RLE4       *)
    biSizeImage     : LongInt ; (* Size of Image Part (often ignored) *)
    biXPelsPerMeter : LongInt ; (* Always Zero                        *)
    biYPelsPerMeter : LongInt ; (* Always Zero                        *)
    biClrUsed       : LongInt ; (* # of Colors used in Palette        *)
    biClrImportant  : LongInt ; (* # of Colors that are Important     *)
 end;

function Save_24_Bit_BMP(const filename: string; const buf: PByteArray; const W, H: integer): boolean;
const Zero_Array: array [1..4] of Byte = (0, 0, 0, 0);
var
  Outfile: file;
  File_OK: boolean;
  Header: BMP_Header;
  Bytes_Per_Raster: LongInt ;
  Raster_Pad: SmallInt;
  X, Y: LongInt;
  X1, Y1, X2, Y2: LongInt;
  buf2: PByteArray;
  XY, XX: integer;
begin
  result := false;

  X1 := 0;
  Y1 := 0;
  X2 := W;
  Y2 := H;

  (*----------------------------------------------------------*)
  (* Compute the number of bytes per raster.  24 bit .BMP     *)
  (* files require that each raster be a multiple of 32 bits  *)
  (* (4 bytes) in length, so depending on the number of pixels*)
  (* in each raster line, we may have to write out between 0  *)
  (* and 3 zero bytes to pad the line properly.               *)
  (*----------------------------------------------------------*)

  Bytes_Per_Raster := (X2 - X1) * 3 ;

  if Bytes_Per_Raster mod 4 = 0 then
    Raster_Pad := 0
  else
    Raster_Pad := 4 - (Bytes_Per_Raster mod 4) ;

  Bytes_Per_Raster := Bytes_Per_Raster + Raster_Pad ;

  (*----------------------------------------------------------*)
  (* Set up the header of the file using current image values *)
  (*----------------------------------------------------------*)

  with Header Do
  begin
    bfType1         := 'B' ;                        (* Always 'B'                   *)
    bfType2         := 'M' ;                        (* Always 'M'                   *)
    bfSize          := 0 ;                          (* Size of File, Computed below *)
    bfReserved1     := 0 ;                          (* Always Zero                  *)
    bfReserved2     := 0 ;                          (* Always Zero                  *)
    bfOffbits       := SizeOf(Header) ;             (* Pointer to Image Start       *)
    biSize          := 40 ;                         (* Bytes in bi Section          *)
    biWidth         := X2 - X1;                     (* Width  of Image              *)
    biHeight        := Y2 - Y1;                     (* Height of Image              *)
    biPlanes        := 1 ;                          (* One Plane (all colors packed)*)
    biBitCount      := 24 ;                         (* Bits per Pixel               *)
    biCompression   := 0 ;                          (* No Compression               *)
    biSizeImage     := Bytes_Per_Raster * biHeight; (* Size of Image                *)
    biXPelsPerMeter := 0 ;                          (* Always Zero                  *)
    biYPelsPerMeter := 0 ;                          (* Always Zero                  *)
    biClrUsed       := 0 ;                          (* No Palette in 24 bit mode    *)
    biClrImportant  := 0 ;                          (* No Palette in 24 bit mode    *)

    bfSize          := SizeOf(Header) + biSizeImage ;
  end;

  (*----------------------------------------------------------*)
  (* Open the file for writing.  The $I- and $I+ directives   *)
  (* disable file I/O checks around the area that the file is *)
  (* opened in order to explicitly trap errors (such as errors*)
  (* in the filename).  Any errors cause the procedure to exit*)
  (* immediately without writing anything.                    *)
  (*----------------------------------------------------------*)

  {$I-}
  Assign(Outfile, Filename) ;
  Rewrite(Outfile, 1) ;
  File_OK := (IOresult = 0) ;
  if not File_OK then Exit ;
  {$I+}

  (*----------------------------------------------------------*)
  (* Write out the header record of the bitmap to the file.   *)
  (*----------------------------------------------------------*)

  BlockWrite (Outfile, Header, SizeOf(Header)) ;

  (*----------------------------------------------------------*)
  (* Write out the main image to the file.  .BMP files are    *)
  (* stored greatest scan-line first, and in Blue-Green-Red   *)
  (* order.  If Raster_Pad > 0, then that many zeroes are     *)
  (* tacked onto the end of each raster line.                 *)
  (*----------------------------------------------------------*)

  buf2 := malloc((X2 - X1) * 3);
  for Y := Y2 - 1 downto Y1 do
  begin
    for X := X1 to X2 - 1 do
    begin
      XY := (Y * W + X) * 4;
      XX := (X - X1) * 3;
      buf2[XX] := buf[XY];
      buf2[XX + 1] := buf[XY + 1];
      buf2[XX + 2] := buf[XY + 2];
    end;
    BlockWrite(Outfile, buf2^, (X2 - X1) * 3);

    if Raster_Pad > 0 then
      BlockWrite (Outfile, Zero_Array, Raster_Pad);
  end;
  memfree(buf2, (X2 - X1) * 3);

  (*----------------------------------------------------------*)
  (* Close the file, ignoring any I/O errors.                 *)
  (*----------------------------------------------------------*)

  {$I-}
  Close(Outfile);
  File_OK := (IOresult = 0);
  {$I+}
  result := File_OK;
end;

function Save_24_Bit_PNG(const filename: string; const buf: PByteArray; const W, H: integer): boolean;
var
  png: TPngObject;
  r, c: integer;
  lpng, lsrc: PByteArray;
begin
  png := TPngObject.CreateBlank(COLOR_RGB, 8, W, H);
  try
    for r := 0 to H - 1 do
    begin
      lpng := png.Scanline[r];
      lsrc := @buf[r * W * 4];
      for c := 0 to W - 1 do
      begin
        lpng[c * 3] := lsrc[c * 4];
        lpng[c * 3 + 1] := lsrc[c * 4 + 1];
        lpng[c * 3 + 2] := lsrc[c * 4 + 2];
      end;
    end;
    png.SaveToFile(filename);
    result := png.IOresult = '';
  finally
    png.Free;
  end;
end;

procedure M_ScreenShot(const filename: string = ''; const silent: boolean = false);
var
  imgname: string;
  ret: boolean;
  dir: string;
  date: TDateTime;
begin
  if strupper(screenshottype) = 'PNG' then
    screenshottype := 'png'
  else
    screenshottype := 'bmp';
  if filename = '' then
  begin
    dir := M_SaveFileName('') + 'SCREENSHOTS';
    MakeDir(dir);
    date := NowTime;
    imgname := dir + '\Doom_' + formatDateTimeAsString('yyyymmdd_hhnnsszzz', date) + '.' + screenshottype;
  end
  else
  begin
    if Pos('.', filename) = 0 then
      imgname := filename + '.' + screenshottype
    else
      imgname := filename;
  end;

  ret := M_DoScreenShot(imgname);
  if not silent then
  begin
    if ret then
      players[consoleplayer]._message := 'screen shot'
    else
      players[consoleplayer]._message := MSG_ERR_SCREENSHOT;
  end;
end;

function M_DoScreenShot(const filename: string): boolean;
var
  bufsize: integer;
  src: PByteArray;
begin
  bufsize := SCREENWIDTH * SCREENHEIGHT * 4;
  src := malloc(bufsize);
  I_ReadScreen32(src);
  if strupper(screenshottype) = 'PNG' then
    result := Save_24_Bit_PNG(filename, src, SCREENWIDTH, SCREENHEIGHT)
  else
    result := Save_24_Bit_BMP(filename, src, SCREENWIDTH, SCREENHEIGHT);

  memfree(src, bufsize);
end;

procedure Cmd_Set(const name: string; const value: string);
var
  i: integer;
  pd: Pdefault_t;
  cname: string;
  cmd: cmd_t;
  clist: TDStringList;
  rlist: TDStringList;
  setflags: byte;
begin
  if netgame then
    setflags := DFS_NETWORK
  else
    setflags := DFS_SINGLEPLAYER;

  if name = '' then
  begin
    printf('Usage is:'#13#10'set [name] [value]'#13#10);
    printf(' Configures the following settings:'#13#10);
    pd := @defaults[0];
    for i := 0 to NUMDEFAULTS - 1 do
    begin
      if pd._type <> tGroup then
        if pd.setable and setflags <> 0 then
          printf('  %s'#13#10, [pd.name]);
      inc(pd);
    end;
    exit;
  end;

  if pos('*', name) > 0 then // Is a mask
  begin
    clist := TDStringList.Create;
    try
      pd := @defaults[0];
      for i := 0 to NUMDEFAULTS - 1 do
      begin
        if pd._type <> tGroup then
          if pd.setable and setflags <> 0 then
            clist.Add(pd.name);
        inc(pd);
      end;

      rlist := C_GetMachingList(clist, name);
      try
        for i := 0 to rlist.Count - 1 do
          printf('%s'#13#10, [rlist[i]]);
      finally
        rlist.Free;
      end;
    finally
      clist.Free;
    end;
    exit;
  end;

  if value = '' then
  begin
    printf('Please give the value to set %s'#13#10, [name]);
    exit;
  end;

  cname := strlower(name);

  pd := @defaults[0];
  for i := 0 to NUMDEFAULTS - 1 do
  begin
    if pd._type <> tGroup then
    begin
      if pd.name = cname then
      begin
        if pd.setable and setflags <> 0 then
        begin
          if pd._type = tInteger then
            PInteger(pd.location)^ := atoi(value)
          else if pd._type = tBoolean then
            PBoolean(pd.location)^ := C_BoolEval(value, PBoolean(pd.location)^)
          else if pd._type = tString then
            PString(pd.location)^ := value;
        end
        else
        begin
          if pd.setable = DFS_NEVER then
            I_Warning('Can not set readonly variable: %s'#13#10, [name])
          else if pd.setable = DFS_SINGLEPLAYER then
            I_Warning('Can not set variable: %s during network game'#13#10, [name]);
        end;
        exit;
      end;
    end;
    inc(pd);
  end;

  if C_GetCmd(name, cmd) then
    if C_ExecuteCmd(@cmd, value) then
      exit;

  C_UnknowCommandMsg;
end;

procedure Cmd_Get(const name: string);
var
  i: integer;
  pd: Pdefault_t;
  cname: string;
  cmd: cmd_t;
  clist: TDStringList;
  rlist: TDStringList;
begin
  if name = '' then
  begin
    printf('Usage is:'#13#10'get [name]'#13#10);
    printf(' Display the current settings of:'#13#10);
    pd := @defaults[0];
    for i := 0 to NUMDEFAULTS - 1 do
    begin
      if pd._type <> tGroup then
        printf('  %s'#13#10, [pd.name]);
      inc(pd);
    end;
    exit;
  end;

  if pos('*', name) > 0 then // Is a mask
  begin
    clist := TDStringList.Create;
    try
      pd := @defaults[0];
      for i := 0 to NUMDEFAULTS - 1 do
      begin
        if pd._type <> tGroup then
          clist.Add(pd.name);
        inc(pd);
      end;

      rlist := C_GetMachingList(clist, name);
      try
        for i := 0 to rlist.Count - 1 do
          Cmd_Get(rlist[i]);
      finally
        rlist.Free;
      end;
    finally
      clist.Free;
    end;
    exit;
  end;

  cname := strlower(name);

  pd := @defaults[0];
  for i := 0 to NUMDEFAULTS - 1 do
  begin
    if pd._type <> tGroup then
    begin
      if pd.name = cname then
      begin
        if pd._type = tInteger then
          printf('%s=%d'#13#10, [name, PInteger(pd.location)^])
        else if pd._type = tBoolean then
        begin
          if PBoolean(pd.location)^ then
            printf('%s=ON'#13#10, [name])
          else
            printf('%s=OFF'#13#10, [name])
        end
        else if pd._type = tString then
          printf('%s=%s'#13#10, [name, PString(pd.location)^]);
        exit;
      end;
    end;
    inc(pd);
  end;

  if C_GetCmd(name, cmd) then
    if C_ExecuteCmd(@cmd) then
      exit;

  C_UnknowCommandMsg;
end;

procedure Cmd_TypeOf(const name: string);
var
  i: integer;
  pd: Pdefault_t;
  cname: string;
  clist: TDStringList;
  rlist: TDStringList;
begin
  if name = '' then
  begin
    printf('Usage is:'#13#10'typeof [name]'#13#10);
    printf(' Display the type of variable.'#13#10);
  end;

  if pos('*', name) > 0 then // Is a mask
  begin
    clist := TDStringList.Create;
    try
      pd := @defaults[0];
      for i := 0 to NUMDEFAULTS - 1 do
      begin
        if pd._type <> tGroup then
          clist.Add(pd.name);
        inc(pd);
      end;

      rlist := C_GetMachingList(clist, name);
      try
        for i := 0 to rlist.Count - 1 do
          Cmd_TypeOf(rlist[i]);
      finally
        rlist.Free;
      end;
    finally
      clist.Free;
    end;
    exit;
  end;

  cname := strlower(name);

  pd := @defaults[0];
  for i := 0 to NUMDEFAULTS - 1 do
  begin
    if pd._type <> tGroup then
    begin
      if pd.name = cname then
      begin
        if pd._type = tInteger then
          printf('%s is integer'#13#10, [name])
        else if pd._type = tBoolean then
          printf('%s is boolean'#13#10, [name])
        else if pd._type = tString then
          printf('%s is string'#13#10, [name]);
        exit;
      end;
    end;
    inc(pd);
  end;

  printf('Unknown variable: %s'#13#10, [name]);
end;

const
  VERFMT = 'ver %d.%d';

var
  defaultfile: string;


procedure M_SaveDefaults;
var
  i: integer;
  pd: Pdefault_t;
  s: TDStringList;
  verstr: string;
begin
  s := TDStringList.Create;
  try
    sprintf(verstr, '[' + AppTitle + ' ' + VERFMT + ']', [VERSION div 100, VERSION mod 100]);
    s.Add(verstr);
    pd := @defaults[0];
    for i := 0 to NUMDEFAULTS - 1 do
    begin
      if pd._type = tInteger then
        s.Add(pd.name + '=' + itoa(PInteger(pd.location)^))
      else if pd._type = tString then
        s.Add(pd.name + '=' + PString(pd.location)^)
      else if pd._type = tBoolean then
        s.Add(pd.name + '=' + itoa(intval(PBoolean(pd.location)^)))
      else if pd._type = tGroup then
      begin
        s.Add('');
        s.Add('[' + pd.name + ']');
      end;
      inc(pd);
    end;

    s.SaveToFile(defaultfile);

  finally
    s.Free;
  end;
end;

procedure M_SetDefaults;
begin
  M_SetDefault('*');
end;

procedure M_SetDefault(const parm: string);
var
  i: integer;
  def: string;
  parm1: string;
  pd: Pdefault_t;
  clist: TDStringList;
  rlist: TDStringList;
  setflags: byte;
begin
  // set parm1 to base value
  if parm = '' then
  begin
    printf('Please specify the variable to reset to default value'#13#10);
    exit;
  end;

  if netgame then
    setflags := DFS_NETWORK
  else
    setflags := DFS_SINGLEPLAYER;

  if pos('*', parm) > 0 then // Is a mask
  begin
    clist := TDStringList.Create;
    try
      pd := @defaults[0];
      for i := 0 to NUMDEFAULTS - 1 do
      begin
        if pd._type <> tGroup then
          clist.Add(pd.name);
        inc(pd);
      end;

      rlist := C_GetMachingList(clist, parm);
      try
        for i := 0 to rlist.Count - 1 do
          M_SetDefault(rlist[i]);
      finally
        rlist.Free;
      end;
    finally
      clist.Free;
    end;
    exit;
  end;

  def := strlower(parm);
  for i := 0 to NUMDEFAULTS - 1 do
    if defaults[i].name = def then
    begin
      if defaults[i].setable and setflags <> 0 then
      begin
        if defaults[i]._type = tInteger then
          PInteger(defaults[i].location)^ := defaults[i].defaultivalue
        else if defaults[i]._type = tBoolean then
          PBoolean(defaults[i].location)^ := defaults[i].defaultbvalue
        else if defaults[i]._type = tString then
          PString(defaults[i].location)^ := defaults[i].defaultsvalue
        else
          exit; // Ouch!
        printf('Setting default value for %s'#13#10, [parm]);
        Cmd_Get(def); // Display the default value
      end
      else if C_CmdExists(def) then
      begin
        if defaults[i]._type = tInteger then
          parm1 := itoa(defaults[i].defaultivalue)
        else if defaults[i]._type = tBoolean then
          parm1 := yesnostrings[defaults[i].defaultbvalue]
        else if defaults[i]._type = tString then
          parm1 := defaults[i].defaultsvalue
        else
          exit; // Ouch!
        printf('Setting default value for %s'#13#10, [parm]);
        C_ExecuteCmd(def, parm1);
      end;
    end;
end;

procedure M_LoadDefaults;
var
  i: integer;
  j: integer;
  idx: integer;
  pd: Pdefault_t;
  s: TDStringList;
  n: string;
begin
  // set everything to base values
  for i := 0 to NUMDEFAULTS - 1 do
    if defaults[i]._type = tInteger then
      PInteger(defaults[i].location)^ := defaults[i].defaultivalue
    else if defaults[i]._type = tBoolean then
      PBoolean(defaults[i].location)^ := defaults[i].defaultbvalue
    else if defaults[i]._type = tString then
      PString(defaults[i].location)^ := defaults[i].defaultsvalue;
  M_SetKeyboardMode(1);

  if M_CheckParm('-defaultvalues') > 0 then
    exit;

  // check for a custom default file
  i := M_CheckParm('-config');
  if (i > 0) and (i < myargc - 1) then
  begin
    defaultfile := myargv[i + 1];
    printf(' default file: %s'#13#10, [defaultfile]);
  end
  else
    defaultfile := basedefault;

  s := TDStringList.Create;
  try
    // read the file in, overriding any set defaults
    if fexists(defaultfile) then
      s.LoadFromFile(defaultfile);

    if s.Count > 1 then
    begin
      if Pos(AppTitle, s[0]) > 0 then // Ignore old version config
      begin
        confignotfound := False;

        s.Delete(0);

        for i := 0 to s.Count - 1 do
        begin
          idx := -1;
          n := strlower(s.Names[i]);
          for j := 0 to NUMDEFAULTS - 1 do
            if defaults[j].name = n then
            begin
              idx := j;
              break;
            end;

          if idx > -1 then
          begin
            pd := @defaults[idx];
            if pd._type = tInteger then
              PInteger(pd.location)^ := atoi(s.Values[n])
            else if pd._type = tBoolean then
              PBoolean(pd.location)^ := atoi(s.Values[n]) <> 0
            else if pd._type = tString then
              PString(pd.location)^ := s.Values[n];
          end;
        end;
      end;
    end;

  finally
    s.Free;
  end;
end;

end.

