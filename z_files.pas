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

unit z_files;

interface

uses
  d_fpc;

const
  ZIPFILESIGNATURE = $04034b50;
  ZIPARCIEVESIGNATURE = $08064b50;

type
  TZipFileHeader = packed record
    Signature: integer; // $04034b50
    Version: word;
    BitFlag: word;
    CompressionMethod: word;
    DosDate: integer;
    crc32: integer;
    CompressedSize: integer;
    UnCompressedSize: integer;
    FileNameLen: word;
    ExtraFieldLen: word;
  end;

// This descriptor exists only if bit 3 of the general
// purpose bit flag is set (see below).
  TZipFileDescriptor = record
    crc32: integer;
    CompressedSize: integer;
    UnCompressedSize: integer;
  end;

  TZipArchieveExtraDataRecord = record
    Signature: integer; // $08064b50
    ExtraFieldLen: integer;
  end;

  TZipFile = class
  private
    fFileName: string;
    fFiles: TDStringList;
    f: TCachedFile;
  protected
    function GetFile(Index: Integer): string; virtual;
    procedure Load; virtual;
    procedure Clear; virtual;
    procedure SetFileName(const Value: string); virtual;
    function GetFileCount: integer;
  public
    constructor Create(const aFileName: string); virtual;
    destructor Destroy; override;
    function GetZipFileData(const Index: integer; var p: pointer;
      var size: integer): boolean; overload; virtual;
    function GetZipFileData(const Name: string; var p: pointer;
      var size: integer): boolean; overload; virtual;
    property FileName: string read fFileName write SetFileName;
    property Files[Index: Integer]: string read GetFile;
    property FileCount: integer read GetFileCount;
  end;

implementation

uses
  i_system,
  {$IFDEF FPC}paszlib{$ELSE}ZLib{$ENDIF};

procedure ZDecompress2(const inBuffer: Pointer; const inSize: Integer;
  const outSize: Integer; out outBuffer: Pointer);
{$IFDEF FPC}
var
  zstream: TZStream;

  procedure CheckErr(err: integer);
  begin
    if err < 0 then
      I_Error('ZDecompress2(): Zip file error(%d)', [err]);
  end;

begin
  FillChar(zstream, SizeOf(TZStream), 0);

  outBuffer := malloc(outSize);

  CheckErr(InflateInit2(zstream, -15));


  zstream.next_in := inBuffer;
  zstream.avail_in := inSize;
  zstream.next_out := outBuffer;
  zstream.avail_out := outSize;

  CheckErr(inflate(zstream, Z_SYNC_FLUSH));

  inflateEnd(zstream);
end;
{$ELSE}
begin
  DecompressToUserBuf(inBuffer, inSize, outBuffer, outSize);
end;
{$ENDIF}

//------------------------------------------------------------------------------
type
  TZipFileEntryInfo = class
  private
    fSize: integer;
    fCompressedSize: integer;
    fPosition: integer;
    fCompressed: boolean;
  public
    constructor Create(const aSize, aCompressedSize, aPosition: integer;
      aCompressed: boolean); virtual;
    property Size: integer read fSize;
    property CompressedSize: integer read fCompressedSize;
    property Position: integer read fPosition;
    property Compressed: boolean read fCompressed;
  end;

constructor TZipFileEntryInfo.Create(const aSize, aCompressedSize, aPosition: integer;
      aCompressed: boolean);
begin
  fSize := aSize;
  fCompressedSize := aCompressedSize;
  fPosition := aPosition;
  fCompressed := aCompressed;
end;

//------------------------------------------------------------------------------
constructor TZipFile.Create(const aFileName: string);
begin
  Inherited Create;
  fFiles := TDStringList.Create;
  fFileName := aFileName;
  Load;
end;

destructor TZipFile.Destroy;
begin
  Clear;
  fFiles.Free;
  Inherited Destroy;
end;

function TZipFile.GetZipFileData(const Index: integer; var p: pointer;
  var size: integer): boolean;
var
  tmp: pointer;
  zinf: TZipFileEntryInfo;
  csize: integer;
begin
  if (Index >= 0) and (Index < fFiles.Count) then
  begin
    zinf := (fFiles.Objects[Index] as TZipFileEntryInfo);
    if zinf.Compressed then
    begin
      size := zinf.Size;
      csize := zinf.CompressedSize;
      tmp := malloc(csize);
      try
        f.Seek(zinf.Position, sFromBeginning);
        f.Read(tmp^, csize);
        ZDecompress2(tmp, csize, size, p);
      finally
        memfree(tmp, csize);
      end;
      result := true;
    end
    else
    begin
      size := zinf.Size;
      p := malloc(size);
      f.Seek(zinf.Position, sFromBeginning);
      f.Read(p^, size);
      result := true;
    end;
  end
  else
    result := false;
end;

function TZipFile.GetZipFileData(const Name: string; var p: pointer;
  var size: integer): boolean;
var
  Name2: string;
  i: integer;
begin
  Name2 := strupper(Name);
  for i := 1 to Length(Name) do
    if Name2[i] = '/' then
      Name2[i] := '\';
  result := GetZipFileData(fFiles.IndexOf(Name2), p, size);
end;

function TZipFile.GetFile(Index: Integer): string;
begin
  result := fFiles[Index];
end;

procedure TZipFile.Load;
var
  h: TZipFileHeader;
  str: string;
  i: integer;
begin
  Clear;
  if fFileName <> '' then
  begin
    f := TCachedFile.Create(fFileName, fOpenReadOnly, 256);
    while true do
    begin
      f.Read(h, SizeOf(h));
      if h.Signature = ZIPFILESIGNATURE then
      begin
        SetLength(str, h.FileNameLen);
        if h.FileNameLen > 0 then
        begin
          f.Read((@str[1])^, h.FileNameLen);
          str := strupper(str);
          for i := 1 to h.FileNameLen do
            if str[i] = '/' then
              str[i] := '\';
          fFiles.Objects[fFiles.Add(str)] :=
            TZipFileEntryInfo.Create(h.UnCompressedSize, h.CompressedSize,
              f.Position + h.ExtraFieldLen, h.CompressionMethod > 0);
          if (h.BitFlag and $4) <> 0 then
            f.Seek(h.ExtraFieldLen + h.CompressedSize + SizeOf(TZipFileDescriptor), sFromCurrent)
          else
            f.Seek(h.ExtraFieldLen + h.CompressedSize, sFromCurrent);
        end;
      end
      else
        break;
    end;
  end;
end;

procedure TZipFile.Clear;
var
  i: integer;
begin
  for i := 0 to fFiles.Count - 1 do
    fFiles.Objects[i].Free;
  fFiles.Clear;
  f.Free;
end;

procedure TZipFile.SetFileName(const Value: string);
begin
  if fFileName <> Value then
  begin
    fFileName := Value;
    Load;
  end;
end;

function TZipFile.GetFileCount: integer;
begin
  result := fFiles.Count;
end;

end.


