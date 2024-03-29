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

unit w_wad;

interface

uses
  d_fpc;

//
// TYPES
//
type
  char8_t = array[0..7] of char;

  wadinfo_t = packed record
    // Should be "IWAD" or "PWAD".
    identification: integer;
    numlumps: integer;
    infotableofs: integer;
  end;
  Pwadinfo_t = ^wadinfo_t;

  filelump_t = packed record
    filepos: integer;
    size: integer;
    name: char8_t;
  end;
  Pfilelump_t = ^filelump_t;
  Tfilelump_tArray = packed array[0..$FFFF] of filelump_t;
  Pfilelump_tArray = ^Tfilelump_tArray;

//
// WADFILE I/O related stuff.
//
  lumpinfo_t = record
    handle: TCachedFile;
    position: integer;
    size: integer;
    case integer of
      0: (name: char8_t);
      1: (v1, v2: integer);
    end;

  Plumpinfo_t = ^lumpinfo_t;
  lumpinfo_tArray = array[0..$FFFF] of lumpinfo_t;
  Plumpinfo_tArray = ^lumpinfo_tArray;

//==============================================================================
//
// char8tostring
//
//==============================================================================
function char8tostring(src: char8_t): string;

//==============================================================================
//
// stringtochar8
//
//==============================================================================
function stringtochar8(src: string): char8_t;

//==============================================================================
//
// W_InitMultipleFiles
//
//==============================================================================
function W_InitMultipleFiles(const filenames: TDStringList): integer;

//==============================================================================
//
// W_ShutDown
//
//==============================================================================
procedure W_ShutDown;

//==============================================================================
//
// W_Reload
//
//==============================================================================
procedure W_Reload;

//==============================================================================
//
// W_NumLumps
//
//==============================================================================
function W_NumLumps: integer;

//==============================================================================
//
// W_CheckNumForName
//
//==============================================================================
function W_CheckNumForName(const name: string; first: integer = -1; last: integer = -1): integer;

//==============================================================================
//
// W_GetNumForName
//
//==============================================================================
function W_GetNumForName(const name: string): integer;

//==============================================================================
//
// W_GetNameForNum
//
//==============================================================================
function W_GetNameForNum(const lump: integer): char8_t;

//==============================================================================
//
// W_LumpLength
//
//==============================================================================
function W_LumpLength(const lump: integer): integer;

//==============================================================================
//
// W_ReadLump
//
//==============================================================================
procedure W_ReadLump(const lump: integer; dest: pointer);

//==============================================================================
//
// W_CacheLumpNum
//
//==============================================================================
function W_CacheLumpNum(const lump: integer; const tag: integer): pointer;

//==============================================================================
//
// W_CacheLumpName
//
//==============================================================================
function W_CacheLumpName(const name: string; const tag: integer): pointer;

//==============================================================================
//
// W_TextLumpNum
//
//==============================================================================
function W_TextLumpNum(const lump: integer): string;

//==============================================================================
//
// W_TextLumpName
//
//==============================================================================
function W_TextLumpName(const name: string): string;

//==============================================================================
//
// ExtractFileBase8
//
//==============================================================================
procedure ExtractFileBase8(const path: string; var dest: char8_t);

var
  lumpinfo: Plumpinfo_tArray = nil;

implementation

uses
  i_system,
  z_memory;

var
  numlumps: integer;

const
  IWAD = integer(Ord('I') or
                (Ord('W') shl 8) or
                (Ord('A') shl 16) or
                (Ord('D') shl 24));

  PWAD = integer(Ord('P') or
                (Ord('W') shl 8) or
                (Ord('A') shl 16) or
                (Ord('D') shl 24));

//
// GLOBALS
//

// Location of each lump on disk.
var
  lumpcache: PPointerArray;

//==============================================================================
//
// char8tostring
//
//==============================================================================
function char8tostring(src: char8_t): string;
var
  i: integer;
begin
  result := '';
  i := 0;
  while (i < 8) and (src[i] <> #0) do
  begin
    result := result + src[i];
    inc(i);
  end;
end;

//==============================================================================
//
// stringtochar8
//
//==============================================================================
function stringtochar8(src: string): char8_t;
var
  i: integer;
  len: integer;
begin
  len := length(src);
  if len > 8 then
    I_Error('stringtochar8(): length of %s is > 8', [src]);

  i := 1;
  while (i <= len) do
  begin
    result[i - 1] := src[i];
    inc(i);
  end;

  for i := len to 7 do
    result[i] := #0;
end;

//==============================================================================
//
// filelength
//
//==============================================================================
function filelength(handle: TCachedFile): integer;
begin
  try
    result := handle.Size;
  except
    result := 0;
    I_Error('filelength(): Error fstating');
  end;
end;

//==============================================================================
//
// ExtractFileBase
//
//==============================================================================
procedure ExtractFileBase(const path: string; var dest: string);
var
  i: integer;
  len: integer;
begin
  len := Length(path);
  i := len;
  while i > 0 do
  begin
    if path[i] in ['/', '\'] then
      break;
    dec(i);
  end;
  dest := '';
  while (i < len) do
  begin
    inc(i);
    if path[i] = '.' then
      break
    else
      dest := dest + toupper(path[i]);
  end;
  if Length(dest) > 8 then
    I_Error('ExtractFileBase(): Filename base of %s >8 chars', [path]);
end;

//==============================================================================
//
// ExtractFileBase8
//
//==============================================================================
procedure ExtractFileBase8(const path: string; var dest: char8_t);
var
  dst: string;
begin
  dst := char8tostring(dest);
  ExtractFileBase(path, dst);
  dest := stringtochar8(dst);
end;

//
// LUMP BASED ROUTINES.
//

//
// W_AddFile
// All files are optional, but at least one file must be
//  found (PWAD, if all required lumps are present).
// Files with a .wad extension are wadlink files
//  with multiple lumps.
// Other files are single lumps with the base filename
//  for the lump name.
//
// If filename starts with a tilde, the file is handled
//  specially to allow map reloads.
// But: the reload feature is a fragile hack...
var
  reloadlump: integer;
  reloadname: string;

//==============================================================================
//
// W_AddFile
//
//==============================================================================
function W_AddFile(var filename: string): TStream;
var
  header: wadinfo_t;
  lump_p: Plumpinfo_t;
  i: integer;
  j: integer;
  handle: TCachedFile;
  len: integer;
  startlump: integer;
  fileinfo: Pfilelump_tArray;
  singleinfo: filelump_t;
  storehandle: TCachedFile;
  ext: string;
  c: char;
begin
  // open the file and add to directory
  // handle reload indicator.
  result := nil;

  if filename[1] = '~' then
  begin
    reloadname := Copy(filename, 2, Length(filename) - 1);
    Delete(filename, 1, 1);
    reloadlump := numlumps;
  end
  else
    reloadname := '';

  if not fexists(filename) then
  begin
    I_Warning('W_AddFile(): File %s does not exist' + #13#10, [filename]);
    exit;
  end;

  try
    handle := TCachedFile.Create(filename, fOpenReadOnly);
  except
    I_Warning('W_AddFile(): couldn''t open %s' + #13#10, [filename]);
    exit;
  end;

  result := handle;

  handle.OnBeginBusy := I_BeginDiskBusy;

  printf(' adding %s' + #13#10, [filename]);
  startlump := numlumps;

  ext := strupper(fext(filename));
  if ext <> '.WAD' then
  begin
    // single lump file
    len := 0;
    fileinfo := @singleinfo;
    singleinfo.filepos := 0;
    singleinfo.size := filelength(handle);
    ExtractFileBase8(filename, singleinfo.name);
    inc(numlumps);
  end
  else
  begin
    // WAD file
    handle.Read(header, SizeOf(header));
    if header.identification <> IWAD then
      // Homebrew levels?
      if header.identification <> PWAD then
        I_Error('W_AddFile(): Wad file %s doesn''t have IWAD or PWAD id' + #13#10, [filename]);

    len := header.numlumps * SizeOf(filelump_t);
    fileinfo := malloc(len);
    handle.Seek(header.infotableofs, sFromBeginning);
    handle.Read(fileinfo^, len);
    numlumps := numlumps + header.numlumps;
  end;

  // Fill in lumpinfo
  {$IFNDEF FPC}lumpinfo := {$ENDIF}realloc(lumpinfo, startlump * SizeOf(lumpinfo_t), numlumps * SizeOf(lumpinfo_t));

  if lumpinfo = nil then
    I_Error('W_AddFile(): Couldn''t realloc lumpinfo');

  if reloadname <> '' then
    storehandle := nil
  else
    storehandle := handle;

  for i := startlump to numlumps - 1 do
  begin
    lump_p := @lumpinfo[i];
    lump_p.handle := storehandle;
    lump_p.position := fileinfo[i - startlump].filepos;
    lump_p.size := fileinfo[i - startlump].size;
    c := #255;
    for j := 0 to 7 do
    begin
      // Prevent non null charactes after ending #0
      if c <> #0 then
        c := toupper(fileinfo[i - startlump].name[j]);
      lump_p.name[j] := c;
    end;
  end;

  if reloadname <> '' then
    handle.Free;

  if len > 0 then
    memfree(fileinfo, len);

end;

//==============================================================================
//
// W_Reload
// Flushes any of the reloadable lumps in memory
//  and reloads the directory.
//
//==============================================================================
procedure W_Reload;
var
  header: wadinfo_t;
  lumpcount: integer;
  lump_p: Plumpinfo_t;
  i: integer;
  handle: TCachedFile;
  length: integer;
  fileinfo: Pfilelump_tArray;
begin
  if reloadname = '' then
    exit;

  if not fexists(reloadname) then
    I_Error('W_Reload(): File %s does not exist' + #13#10, [reloadname]);

  try
    handle := TCachedFile.Create(reloadname, fOpenReadOnly);
  except
    handle := nil;
    I_Error('W_Reload(): couldn''t open %s', [reloadname]);
  end;

  handle.OnBeginBusy := I_BeginDiskBusy;

  handle.Read(header, SizeOf(header));
  lumpcount := header.numlumps;
  length := lumpcount * SizeOf(filelump_t);
  fileinfo := malloc(length);
  handle.Seek(header.infotableofs, sFromBeginning);
  handle.Read(fileinfo^, length);

  // Fill in lumpinfo

  for i := reloadlump to reloadlump + lumpcount - 1 do
  begin
    lump_p := @lumpinfo[reloadlump];
    if lumpcache[i] <> nil then
      Z_Free(lumpcache[i]);

    lump_p.position := fileinfo[i - reloadlump].filepos;
    lump_p.size := fileinfo[i - reloadlump].size;
  end;

  handle.Free;
end;

//==============================================================================
//
// W_InitMultipleFiles
// Pass a null terminated list of files to use.
// All files are optional, but at least one file
//  must be found.
// Files with a .wad extension are idlink files
//  with multiple lumps.
// Other files are single lumps with the base filename
//  for the lump name.
// Lump names can appear multiple times.
// The name searcher looks backwards, so a later file
//  does override all earlier ones.
//
//==============================================================================
function W_InitMultipleFiles(const filenames: TDStringList): integer;
var
  size: integer;
  filename: string;
  i: integer;
begin
  // open all the files, load headers, and count lumps
  numlumps := 0;

  for i := 0 to filenames.Count - 1 do
  begin
    filename := filenames[i];
    filenames.Objects[i] := W_AddFile(filename);
    filenames[i] := filename;
  end;

  result := numlumps;

  if result > 0 then
  begin
    // set up caching
    size := numlumps * SizeOf(pointer);
    lumpcache := mallocz(size);

    if lumpcache = nil then
      I_Error('W_InitMultipleFiles(): Couldn''t allocate lumpcache');

  end;
end;

//==============================================================================
//
// W_ShutDown
//
//==============================================================================
procedure W_ShutDown;
begin
  memfree(lumpcache, numlumps * SizeOf(pointer));
  memfree(lumpinfo, numlumps * SizeOf(lumpinfo_t));
end;

//==============================================================================
//
// W_InitFile
// Just initialize from a single file.
//
//==============================================================================
procedure W_InitFile(const filename: string);
var
  names: TDStringList;
begin
  names := TDSTringList.Create;
  try
    names.Add(filename);
    W_InitMultipleFiles(names);
  finally
    if names.Objects[0] <> nil then
      names.Objects[0].Free;
    names.Free;
  end;
end;

//==============================================================================
//
// W_NumLumps
//
//==============================================================================
function W_NumLumps: integer;
begin
  result := numlumps;
end;

//
// W_CheckNumForName
// Returns -1 if name not found.
//
type
  name8_t = record
    case integer of
      0: (s: char8_t);
      1: (x: array[0..1] of integer);
    end;

//==============================================================================
//
// W_CheckNumForName
//
//==============================================================================
function W_CheckNumForName(const name: string; first: integer = -1; last: integer = -1): integer;
var
  name8: name8_t;
  v1: integer;
  v2: integer;
  lump_p: Plumpinfo_t;
  len: integer;
  i: integer;
  lfirst, llast: Plumpinfo_t;
begin
  len := Length(name);
  if len > 8 then // JVAL: Original an I_Error ocurred. Now we call I_DevError
  begin
    I_DevError('W_CheckNumForName(): name string has more than 8 characters: %s'#13#10, [name]);
    len := 8;
  end;

  // make the name into two integers for easy compares
  for i := 1 to len do
    name8.s[i - 1] := toupper(name[i]); // case insensitive
  for i := len to 7 do
    name8.s[i] := #0;

  v1 := name8.x[0];
  v2 := name8.x[1];

  // scan backwards so patch lump files take precedence
  if first = -1 then
    lfirst := @lumpinfo[0]
  else
    lfirst := @lumpinfo[first];
  if last = -1 then
    llast := @lumpinfo[numlumps]
  else
    llast := @lumpinfo[last + 1];

  lump_p := llast;
  while lump_p <> lfirst do
  begin
    dec(lump_p);
    if (lump_p.v1 = v1) and (lump_p.v2 = v2) then
    begin
      result := pDiff(lump_p, lumpinfo, SizeOf(lumpinfo_t));
      exit;
    end;
  end;

  // TFB. Not found.
  result := -1;
end;

//==============================================================================
//
// W_GetNumForName
// Calls W_CheckNumForName, but bombs out if not found.
//
//==============================================================================
function W_GetNumForName(const name: string): integer;
begin
  result := W_CheckNumForName(name);
  if result = -1 then
    I_Error('W_GetNumForName(): %s not found!', [name]);
end;

//==============================================================================
//
// W_GetNameForNum
//
//==============================================================================
function W_GetNameForNum(const lump: integer): char8_t;
begin
  result := lumpinfo[lump].name;
end;

//==============================================================================
//
// W_LumpLength
// Returns the buffer size needed to load the given lump.
//
//==============================================================================
function W_LumpLength(const lump: integer): integer;
begin
  if lump >= numlumps then
    I_Error('W_LumpLength(): %d >= numlumps', [lump]);

  result := lumpinfo[lump].size;
end;

//==============================================================================
//
// W_ReadLump
// Loads the lump into the given buffer,
//  which must be >= W_LumpLength().
//
//==============================================================================
procedure W_ReadLump(const lump: integer; dest: pointer);
var
  c: integer;
  l: Plumpinfo_t;
  handle: TCachedFile;
begin
  if lump >= numlumps then
    I_Error('W_ReadLump(): %d >= numlumps', [lump]);

  l := @lumpinfo[lump];

  if l.handle = nil then
  begin
    // reloadable file, so use open / read / close
    if not fexists(reloadname) then
      I_Error('W_ReadLump(): couldn''t open %s', [reloadname]);

    try
      handle := TCachedFile.Create(reloadname, fOpenReadOnly);
    except
      handle := nil;
      I_Error('W_ReadLump(): couldn''t open %s', [reloadname]);
    end
  end
  else
    handle := l.handle;

  handle.OnBeginBusy := I_BeginDiskBusy;

  handle.Seek(l.position, sFromBeginning);
  c := handle.Read(dest^, l.size);

  if c < l.size then
    I_Error('W_ReadLump(): only read %d of %d on lump %d', [c, l.size, lump]);

  if l.handle = nil then
    handle.Free;
end;

//==============================================================================
//
// W_CacheLumpNum
//
//==============================================================================
function W_CacheLumpNum(const lump: integer; const tag: integer): pointer;
begin
  if lump >= numlumps then
    I_Error('W_CacheLumpNum(): lump = %d, >= numlumps', [lump]);

  if lump < 0 then
    I_Error('W_CacheLumpNum(): lump = %d, < 0', [lump]);

  if lumpcache[lump] = nil then
  begin
    // read the lump in
    //printf ("cache miss on lump %i\n",lump);
    Z_Malloc(W_LumpLength(lump), tag, @lumpcache[lump]);
    W_ReadLump(lump, lumpcache[lump]);
  end
  else
  begin
    //printf ("cache hit on lump %i\n",lump);
    Z_ChangeTag(lumpcache[lump], tag);
  end;

  result := lumpcache[lump];
end;

//==============================================================================
//
// W_CacheLumpName
//
//==============================================================================
function W_CacheLumpName(const name: string; const tag: integer): pointer;
begin
  result := W_CacheLumpNum(W_GetNumForName(name), tag);
end;

//==============================================================================
//
// W_TextLumpNum
//
//==============================================================================
function W_TextLumpNum(const lump: integer): string;
var
  p: PByteArray;
  i: integer;
  len: integer;
begin
  if lump < 0 then
  begin
    result := '';
    exit;
  end;

  p := W_CacheLumpNum(lump, PU_STATIC);
  len := W_LumpLength(lump);

  result := '';
  SetLength(result, len);
  for i := 0 to len - 1 do
    if p[i] <> 0 then
      result[i + 1] := Chr(p[i])
    else
      result[i + 1] := ' ';

  Z_Free(p);
end;

//==============================================================================
//
// W_TextLumpName
//
//==============================================================================
function W_TextLumpName(const name: string): string;
begin
  result := W_TextLumpNum(W_GetNumForName(name));
end;

end.
