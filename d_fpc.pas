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

unit d_fpc;

interface

uses
  Windows;

type
  {$IFDEF WIN32}
  PCAST = LongWord;
  {$ELSE}
  PCAST = QWORD;
  {$ENDIF}

  PPointer = ^Pointer;

  PString = ^string;

  PBoolean = ^Boolean;

  PInteger = ^Integer;

  PLongWord = ^LongWord;

  PShortInt = ^ShortInt;

  TWordArray = packed array[0..$FFFF] of word;
  PWordArray = ^TWordArray;

  TIntegerArray = packed array[0..$FFFF] of integer;
  PIntegerArray = ^TIntegerArray;

  TLongWordArray = packed array[0..$FFFF] of LongWord;
  PLongWordArray = ^TLongWordArray;

  TSmallintArray = packed array[0..$FFFF] of Smallint;
  PSmallintArray = ^TSmallintArray;

  TByteArray = packed array[0..$FFFF] of Byte;
  PByteArray = ^TByteArray;

  TBooleanArray = packed array[0..$FFFF] of boolean;
  PBooleanArray = ^TBooleanArray;

  PProcedure = procedure;
  PPointerParmProcedure = procedure(const p: pointer);

  TStringArray = array[0..$FFFF] of string;
  PStringArray = ^TStringArray;

  TPointerArray = packed array[0..$FFFF] of pointer;
  PPointerArray = ^TPointerArray;

  PSmallInt = ^SmallInt;
  TSmallIntPArray = packed array[0..$FFFF] of PSmallIntArray;
  PSmallIntPArray = ^TSmallIntPArray;

  PWord = ^Word;
  TWordPArray = packed array[0..$FFFF] of PWordArray;
  PWordPArray = ^TWordPArray;

  TLongWordPArray = packed array[0..$FFFF] of PLongWordArray;
  PLongWordPArray = ^TLongWordPArray;

  TIntegerPArray = packed array[0..$FFFF] of PIntegerArray;
  PIntegerPArray = ^TIntegerPArray;

  PByte = ^Byte;
  TBytePArray = packed array[0..$FFFF] of PByteArray;
  PBytePArray = ^TBytePArray;

  float = single;

type
  charset_t = set of char;

  TOutProc = procedure (const s: string);

var
  outproc: TOutProc = nil;

//==============================================================================
//
// sprintf
//
//==============================================================================
procedure sprintf(var s: string; const Fmt: string; const Args: array of const);

//==============================================================================
//
// printf
//
//==============================================================================
procedure printf(const str: string); overload;

//==============================================================================
//
// printf
//
//==============================================================================
procedure printf(const Fmt: string; const Args: array of const); overload;

//==============================================================================
//
// itoa
//
//==============================================================================
function itoa(i: integer): string;

//==============================================================================
//
// ftoa
//
//==============================================================================
function ftoa(f: single): string;

//==============================================================================
//
// atoi
//
//==============================================================================
function atoi(const s: string): integer; overload;

//==============================================================================
//
// atoi
//
//==============================================================================
function atoi(const s: string; const default: integer): integer; overload;

//==============================================================================
//
// atof
//
//==============================================================================
function atof(const s: string): single; overload;

//==============================================================================
//
// atof
//
//==============================================================================
function atof(const s: string; const default: single): single; overload;

//==============================================================================
// memcpy
//
// Memory functions
//
//==============================================================================
function memcpy(const dest0: pointer; const src0: pointer; count0: integer): pointer;

//==============================================================================
//
// memset
//
//==============================================================================
function memset(const dest0: pointer; const val: integer; const count0: integer): pointer;

//==============================================================================
//
// malloc
//
//==============================================================================
function malloc(const size: integer): Pointer;

//==============================================================================
//
// mallocA
//
//==============================================================================
function mallocA(var Size: integer; const Align: integer; var original: pointer): pointer;

//==============================================================================
//
// mallocz
//
//==============================================================================
function mallocz(const size: integer): Pointer;

{$IFDEF FPC}

//==============================================================================
//
// realloc
//
//==============================================================================
procedure realloc(var p: pointer; const oldsize, newsize: integer);
{$ELSE}

//==============================================================================
//
// realloc
//
//==============================================================================
function realloc(p: pointer; const oldsize, newsize: integer): pointer;
{$ENDIF}

//==============================================================================
//
// memfree
//
//==============================================================================
procedure memfree({$IFDEF FPC}var {$ENDIF}p: pointer; const size: integer);

var
  memoryusage: integer = 0;

//==============================================================================
//
// IntToStrZfill
//
//==============================================================================
function IntToStrZfill(const z: integer; const x: integer): string;

//==============================================================================
//
// intval
//
//==============================================================================
function intval(const b: boolean): integer;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: integer; const iffalse: integer): integer; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: boolean; const iffalse: boolean): boolean; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: string; const iffalse: string): string; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: pointer; const iffalse: pointer): pointer; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: integer; const iffalse: integer): integer; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: boolean; const iffalse: boolean): boolean; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: string; const iffalse: string): string; overload;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: pointer; const iffalse: pointer): pointer; overload;

//==============================================================================
//
// incp
//
//==============================================================================
function incp({$IFDEF FPC}var {$ENDIF}p: pointer; const size: integer = 1): pointer;

//==============================================================================
//
// pDiff
//
//==============================================================================
function pDiff(const p1, p2: pointer; const size: integer): integer;

//==============================================================================
//
// getenv
//
//==============================================================================
function getenv(const env: string): string;

//==============================================================================
//
// fexists
//
//==============================================================================
function fexists(const filename: string): boolean;

//==============================================================================
//
// fexpand
//
//==============================================================================
function fexpand(const filename: string): string;

//==============================================================================
//
// fpath
//
//==============================================================================
function fpath(const filename: string): string;

//==============================================================================
//
// fdelete
//
//==============================================================================
procedure fdelete(const filename: string);

//==============================================================================
//
// fext
//
//==============================================================================
function fext(const filename: string): string;

//==============================================================================
//
// fname
//
//==============================================================================
function fname(const filename: string): string;

const
  fCreate = 0;
  fOpenReadOnly = 1;
  fOpenReadWrite = 2;

  sFromBeginning = 0;
  sFromCurrent = 1;
  sFromEnd = 2;

type
  TStream = class
  protected
    FIOResult: integer;
  public
    OnBeginBusy: PProcedure;
    OnEndBusy: PProcedure;
    constructor Create;
    function Read(var Buffer; Count: Longint): Longint; virtual; abstract;
    function Write(const Buffer; Count: Longint): Longint; virtual; abstract;
    function Seek(Offset: Longint; Origin: Word): Longint; virtual; abstract;
    function Size: Longint; virtual; abstract;
    function Position: integer; virtual; abstract;
    function IOResult: integer;
  end;

  TFile = class(TStream)
  private
    f: file;
  public
    constructor Create(const FileName: string; const mode: integer);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    function Size: Longint; override;
    function Position: integer; override;
  end;

  TCachedFile = class(TFile)
  private
    fBufSize: integer;
    fBuffer: pointer;
    fPosition: integer;
    fBufferStart: integer;
    fBufferEnd: integer;
    fSize: integer;
    fInitialized: boolean;
  protected
    procedure SetSize(NewSize: Longint); virtual;
    procedure ResetBuffer; virtual;
  public
    constructor Create(const FileName: string; mode: word; ABufSize: integer = $FFFF); virtual;
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    function Position: integer; override;
  end;

type
  TDNumberList = class
  private
    fList: PIntegerArray;
    fNumItems: integer;
  protected
    function Get(Index: Integer): integer; virtual;
    procedure Put(Index: Integer; const value: integer); virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Add(const value: integer); overload; virtual;
    procedure Add(const nlist: TDNumberList); overload; virtual;
    function Delete(const Index: integer): boolean;
    function IndexOf(const value: integer): integer;
    procedure Clear;
    procedure Sort; virtual;
    property Count: integer read fNumItems;
    property Numbers[Index: Integer]: integer read Get write Put; default;
  end;

type
  TDPointerList = class(TObject)
  private
    fList: PPointerArray;
    fNumItems: integer;
    fRealSize: integer;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure AddItem(const value: pointer);
    function DeleteItem(const item: pointer): boolean;
    function IndexOf(const value: pointer): integer;
    procedure Clear;
    procedure FastClear;
    function HasSameContentWith(const pl: TDPointerList): boolean;
    property Pointers: PPointerArray read fList;
    property Count: integer read fNumItems;
  end;

type
  TTextArray = array[0..$FFFF] of string[255];
  PTextArray = ^TTextArray;

type
  TDTextList = class
  private
    fList: PTextArray;
    fNumItems: integer;
  protected
    function Get(Index: Integer): string; virtual;
    procedure Put(Index: Integer; const value: string); virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Add(const value: string); overload; virtual;
    procedure Add(const nlist: TDTextList); overload; virtual;
    function Delete(const Index: integer): boolean;
    function IndexOf(const value: string): integer;
    procedure Clear;
    property Count: integer read fNumItems;
    property Numbers[Index: Integer]: string read Get write Put; default;
  end;

const
  MaxListSize = MAXINT div 16;

type
{ TDStrings class }
  TDStrings = class
  private
    function GetCommaText: string;
    function GetName(Index: Integer): string;
    function GetValue(const Name: string): string;
    procedure SetCommaText(const Value: string);
    procedure SetValue(const Name, Value: string);
  protected
    function Get(Index: Integer): string; virtual; abstract;
    function GetCapacity: Integer; virtual;
    function GetCount: Integer; virtual; abstract;
    function GetObject(Index: Integer): TObject; virtual;
    function GetTextStr: string; virtual;
    procedure Put(Index: Integer; const S: string); virtual;
    procedure PutObject(Index: Integer; AObject: TObject); virtual;
    procedure SetCapacity(NewCapacity: Integer); virtual;
    procedure SetTextStr(const Value: string); virtual;
    procedure SetByteStr(const A: PByteArray; const Size: integer); virtual;
  public
    function Add(const S: string): Integer; overload; virtual;
    function Add(const Fmt: string; const Args: array of const): Integer; overload; virtual;
    function AddObject(const S: string; AObject: TObject): Integer; virtual;
    procedure Append(const S: string);
    procedure AddStrings(Strings: TDStrings); virtual;
    procedure Clear; virtual; abstract;
    procedure Delete(Index: Integer); virtual; abstract;
    function Equals(Strings: TDStrings): Boolean;
    procedure Exchange(Index1, Index2: Integer); virtual;
    function GetText: PChar; virtual;
    function IndexOf(const S: string): Integer; virtual;
    function IndexOfName(const Name: string): Integer;
    function IndexOfObject(AObject: TObject): Integer;
    procedure Insert(Index: Integer; const S: string); virtual; abstract;
    procedure InsertObject(Index: Integer; const S: string;
      AObject: TObject);
    function  LoadFromFile(const FileName: string): boolean; virtual;
    function  LoadFromStream(const strm: TStream): boolean; virtual;
    procedure Move(CurIndex, NewIndex: Integer); virtual;
    function SaveToFile(const FileName: string): boolean; virtual;
    procedure SetText(Text: PChar); virtual;
    property Capacity: Integer read GetCapacity write SetCapacity;
    property CommaText: string read GetCommaText write SetCommaText;
    property Count: Integer read GetCount;
    property Names[Index: Integer]: string read GetName;
    property Objects[Index: Integer]: TObject read GetObject write PutObject;
    property Values[const Name: string]: string read GetValue write SetValue;
    property Strings[Index: Integer]: string read Get write Put; default;
    property Text: string read GetTextStr write SetTextStr;
  end;

{ TDStringList class }

  TDStringList = class;

  PStringItem = ^TStringItem;
  TStringItem = record
    FString: string;
    FObject: TObject;
  end;

  PStringItemList = ^TStringItemList;
  TStringItemList = array[0..MaxListSize] of TStringItem;

  TDStringList = class(TDStrings)
  private
    FList: PStringItemList;
    FCount: Integer;
    FCapacity: Integer;
    procedure ExchangeItems(Index1, Index2: Integer);
    procedure Grow;
    procedure InsertItem(Index: Integer; const S: string);
  protected
    function Get(Index: Integer): string; override;
    function GetCapacity: Integer; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: string); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
    procedure SetCapacity(NewCapacity: Integer); override;
  public
    destructor Destroy; override;
    function Add(const S: string): Integer; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Exchange(Index1, Index2: Integer); override;
    procedure Insert(Index: Integer; const S: string); override;
  end;

//==============================================================================
//
// findfile
//
//==============================================================================
function findfile(const mask: string): string;

//==============================================================================
//
// findfiles
//
//==============================================================================
function findfiles(const mask: string): TDStringList;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(var f: file; const str: string); overload;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(var f: file; const Fmt: string; const Args: array of const); overload;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(const f: TFile; const str: string); overload;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(const f: TFile; const Fmt: string; const Args: array of const); overload;

//==============================================================================
//
// tan
//
//==============================================================================
function tan(const x: extended): extended;

//==============================================================================
//
// strupper
//
//==============================================================================
function strupper(const S: string): string;

//==============================================================================
//
// strlower
//
//==============================================================================
function strlower(const S: string): string;

//==============================================================================
//
// toupper
//
//==============================================================================
function toupper(ch: Char): Char;

//==============================================================================
//
// tolower
//
//==============================================================================
function tolower(ch: Char): Char;

//==============================================================================
//
// strremovespaces
//
//==============================================================================
function strremovespaces(const s: string): string;

//==============================================================================
//
// _SHL
//
//==============================================================================
function _SHL(const x: integer; const bits: integer): integer;

//==============================================================================
//
// _SHLW
//
//==============================================================================
function _SHLW(const x: LongWord; const bits: LongWord): LongWord; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// _SHR
//
//==============================================================================
function _SHR(const x: integer; const bits: integer): integer;

//==============================================================================
//
// _SHR1
//
//==============================================================================
function _SHR1(const x: integer): integer;

//==============================================================================
//
// _SHR2
//
//==============================================================================
function _SHR2(const x: integer): integer;

//==============================================================================
//
// _SHR8
//
//==============================================================================
function _SHR8(const x: integer): integer;

//==============================================================================
//
// _SHR14
//
//==============================================================================
function _SHR14(const x: integer): integer;

//==============================================================================
//
// _SHRW
//
//==============================================================================
function _SHRW(const x: LongWord; const bits: LongWord): LongWord; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// StringVal
//
//==============================================================================
function StringVal(const Str: PChar): string;

//==============================================================================
//
// ZeroMemory
//
//==============================================================================
procedure ZeroMemory(const dest0: pointer; const count0: integer);

//==============================================================================
//
// fopen
//
//==============================================================================
function fopen(var f: file; const FileName: string; const mode: integer): boolean;

//==============================================================================
//
// fsize
//
//==============================================================================
function fsize(const FileName: string): integer;

//==============================================================================
//
// fshortname
//
//==============================================================================
function fshortname(const FileName: string): string;

//==============================================================================
//
// strtrim
//
//==============================================================================
function strtrim(const S: string): string;

//==============================================================================
//
// capitalizedstring
//
//==============================================================================
function capitalizedstring(const S: string; const splitter: char = ' '): string;

//==============================================================================
//
// splitstring
//
//==============================================================================
procedure splitstring(const inp: string; var out1, out2: string; const splitter: string = ' '); overload;

//==============================================================================
//
// splitstring
//
//==============================================================================
procedure splitstring(const inp: string; var out1, out2: string; const splitters: charset_t); overload;

//==============================================================================
//
// firstword
//
//==============================================================================
function firstword(const inp: string; const splitter: string = ' '): string; overload;

//==============================================================================
//
// firstword
//
//==============================================================================
function firstword(const inp: string; const splitters: charset_t): string; overload;

//==============================================================================
//
// parsefirstword
//
//==============================================================================
function parsefirstword(const inp: string): string;

//==============================================================================
//
// secondword
//
//==============================================================================
function secondword(const inp: string; const splitter: string = ' '): string; overload;

//==============================================================================
//
// secondword
//
//==============================================================================
function secondword(const inp: string; const splitters: charset_t): string; overload;

//==============================================================================
//
// lastword
//
//==============================================================================
function lastword(const inp: string; const splitter: string = ' '): string; overload;

//==============================================================================
//
// lastword
//
//==============================================================================
function lastword(const inp: string; const splitters: charset_t): string; overload;

//==============================================================================
//
// FreeAndNil
//
//==============================================================================
procedure FreeAndNil(var Obj);

//==============================================================================
//
// StrLCopy
//
//==============================================================================
function StrLCopy(Dest: PChar; const Source: PChar; MaxLen: Cardinal): PChar;

//==============================================================================
//
// fabs
//
//==============================================================================
function fabs(const f: float): float;

//==============================================================================
//
// MakeDir
//
//==============================================================================
procedure MakeDir(const dir: string);

var
  mmxMachine: byte = 0;
  AMD3DNowMachine: byte = 0;

{$IFDEF FPC}

//==============================================================================
//
// GetEnvironmentVariable
//
//==============================================================================
function GetEnvironmentVariable(lpName: PChar; lpBuffer: PChar; nSize: DWORD): DWORD; stdcall;
{$ENDIF}

//==============================================================================
//
// AllocMemSize
//
//==============================================================================
function AllocMemSize: integer;

type
{$IFDEF FPC}
  PKeyboardState = ^TKeyboardState;
  TKeyboardState = array[0..255] of byte;
{$ENDIF}
  TImageFileHeader = packed record
    Machine: Word;
    NumberOfSections: Word;
    TimeDateStamp: DWORD;
    PointerToSymbolTable: DWORD;
    NumberOfSymbols: DWORD;
    SizeOfOptionalHeader: Word;
    Characteristics: Word;
  end;
  PImageFileHeader = ^TImageFileHeader;

  TImageDataDirectory = record
    VirtualAddress: DWORD;
    Size: DWORD;
  end;
  PImageDataDirectory = ^TImageDataDirectory;

const
  IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;

type
  TImageOptionalHeader = packed record
    { Standard fields. }
    Magic: Word;
    MajorLinkerVersion: Byte;
    MinorLinkerVersion: Byte;
    SizeOfCode: DWORD;
    SizeOfInitializedData: DWORD;
    SizeOfUninitializedData: DWORD;
    AddressOfEntryPoint: DWORD;
    BaseOfCode: DWORD;
    BaseOfData: DWORD;
    { NT additional fields. }
    ImageBase: DWORD;
    SectionAlignment: DWORD;
    FileAlignment: DWORD;
    MajorOperatingSystemVersion: Word;
    MinorOperatingSystemVersion: Word;
    MajorImageVersion: Word;
    MinorImageVersion: Word;
    MajorSubsystemVersion: Word;
    MinorSubsystemVersion: Word;
    Win32VersionValue: DWORD;
    SizeOfImage: DWORD;
    SizeOfHeaders: DWORD;
    CheckSum: DWORD;
    Subsystem: Word;
    DllCharacteristics: Word;
    SizeOfStackReserve: DWORD;
    SizeOfStackCommit: DWORD;
    SizeOfHeapReserve: DWORD;
    SizeOfHeapCommit: DWORD;
    LoaderFlags: DWORD;
    NumberOfRvaAndSizes: DWORD;
    DataDirectory: packed array[0..IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of TImageDataDirectory;
  end;
  PImageOptionalHeader = ^TImageOptionalHeader;

//==============================================================================
//
// NowTime
//
//==============================================================================
function NowTime: TDateTime;

//==============================================================================
//
// formatDateTimeAsString
//
//==============================================================================
function formatDateTimeAsString(const Format: string; DateTime: TDateTime): string;

//==============================================================================
//
// min3b
//
//==============================================================================
function min3b(const a, b, c: byte): byte; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// max3b
//
//==============================================================================
function max3b(const a, b, c: byte): byte; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// ibetween
//
//==============================================================================
function ibetween(const x: integer; const x1, x2: integer): integer; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// pOp
//
//==============================================================================
function pOp(const p: pointer; const offs: integer): pointer; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// imin
//
//==============================================================================
function imin(const x1, x2: integer): integer; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// imax
//
//==============================================================================
function imax(const x1, x2: integer): integer; {$IFDEF FPC}inline;{$ENDIF}

//==============================================================================
//
// logtofile
//
//==============================================================================
procedure logtofile(const fname: string; const str: string);

//==============================================================================
//
// RemoveQuotesFromString
//
//==============================================================================
function RemoveQuotesFromString(const s: string): string;

implementation

uses
  SysUtils;

//==============================================================================
//
// sprintf
//
//==============================================================================
procedure sprintf(var s: string; const Fmt: string; const Args: array of const);
begin
  FmtStr(s, Fmt, Args);
end;

//==============================================================================
//
// printf
//
//==============================================================================
procedure printf(const str: string);
begin
  if Assigned(outproc) then
    outproc(str)
  else if IsConsole then
    write(str);
end;

//==============================================================================
//
// printf
//
//==============================================================================
procedure printf(const Fmt: string; const Args: array of const);
var
  s: string;
begin
  sprintf(s, Fmt, Args);
  printf(s);
end;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(var f: file; const str: string);
begin
  BlockWrite(f, (@str[1])^, Length(str));
end;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(var f: file; const Fmt: string; const Args: array of const);
var
  s: string;
begin
  sprintf(s, Fmt, Args);
  fprintf(f, s);
end;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(const f: TFile; const str: string);
begin
  fprintf(f.f, str);
end;

//==============================================================================
//
// fprintf
//
//==============================================================================
procedure fprintf(const f: TFile; const Fmt: string; const Args: array of const);
begin
  fprintf(f.f, Fmt, Args);
end;

//==============================================================================
//
// itoa
//
//==============================================================================
function itoa(i: integer): string;
begin
  sprintf(result, '%d', [i]);
end;

//==============================================================================
//
// ftoa
//
//==============================================================================
function ftoa(f: single): string;
begin
  result := FloatToStr(f);
end;

//==============================================================================
//
// atoi
//
//==============================================================================
function atoi(const s: string): integer;
var
  code: integer;
  ret2: integer;
begin
  val(s, result, code);
  if code <> 0 then
  begin
    ret2 := 0;
    if Pos('0x', s) = 1 then
      val('$' + Copy(s, 3, Length(s) - 2), ret2, code)
    else if Pos('#', s) = 1 then
      val(Copy(s, 2, Length(s) - 1), ret2, code);
    if code = 0 then
      result := ret2
    else
      result := 0;
  end;
end;

//==============================================================================
//
// atoi
//
//==============================================================================
function atoi(const s: string; const default: integer): integer; overload;
var
  code: integer;
  ret2: integer;
begin
  val(s, result, code);
  if code <> 0 then
  begin
    ret2 := default;
    if Pos('0x', s) = 1 then
      val('$' + Copy(s, 3, Length(s) - 2), ret2, code)
    else if Pos('#', s) = 1 then
      val(Copy(s, 2, Length(s) - 1), ret2, code);
    if code = 0 then
      result := ret2
    else
      result := default;
  end;
end;

//==============================================================================
//
// atof
//
//==============================================================================
function atof(const s: string): single;
begin
  result := atof(s, 0.0);
end;

{$IFDEF FPC}

//==============================================================================
//
// atof
//
//==============================================================================
function atof(const s: string; const default: single): single;
var
  fmt: TFormatSettings;
begin
  fmt := DefaultFormatSettings;
  fmt.DecimalSeparator := '.';
  if TryStrToFloat(s, result, fmt) then
    exit;
  fmt.DecimalSeparator := ',';
  if TryStrToFloat(s, result, fmt) then
    exit;
  result := default;
end;
{$ELSE}

//==============================================================================
//
// atof
//
//==============================================================================
function atof(const s: string; const default: single): single;
var
  code: integer;
  i: integer;
  str: string;
begin
  ThousandSeparator := #0;
  DecimalSeparator := '.';

  val(s, result, code);
  if code <> 0 then
  begin
    str := s;
    for i := 1 to Length(str) do
      if str[i] in ['.', ','] then
        str[i] := DecimalSeparator;
    val(str, result, code);
    if code = 0 then
      exit;
    for i := 1 to Length(str) do
      if str[i] in ['.', ','] then
        str[i] := '.';
    val(str, result, code);
    if code = 0 then
      exit;
    for i := 1 to Length(str) do
      if str[i] in ['.', ','] then
        str[i] := ',';
    val(str, result, code);
    if code = 0 then
      exit;
    result := default;
  end;
end;
{$ENDIF}

//==============================================================================
//
// memcpy_MMX8
//
//==============================================================================
procedure memcpy_MMX8(const dst: pointer; const src: pointer; const len: integer); assembler;
asm
  push esi
  push edi

  mov esi, src
  mov edi, dst
  mov ecx, len
  shr ecx, 3  // 8 bytes per iteration

@@loop1:
// Read in source data
  movq  mm1, [esi]
// Non-temporal stores
  movntq [edi], mm1

  add esi, 8
  add edi, 8
  dec ecx
  jnz @@loop1

  emms

  pop edi
  pop esi
end;

//==============================================================================
//
// memcpy_MMX64
//
//==============================================================================
procedure memcpy_MMX64(const dst: pointer; const src: pointer; const len: integer); assembler;
asm
  push esi
  push edi

  mov esi, src
  mov edi, dst
  mov ecx, len
  shr ecx, 6    // 64 bytes per iteration

@@loop1:

// Read in source data
  movq mm1, [esi]
  movq mm2, [esi + 8]
  movq mm3, [esi + 16]
  movq mm4, [esi + 24]
  movq mm5, [esi + 32]
  movq mm6, [esi + 40]
  movq mm7, [esi + 48]
  movq mm0, [esi + 56]

// Non-temporal stores
  movntq [edi], mm1
  movntq [edi + 8], mm2
  movntq [edi + 16], mm3
  movntq [edi + 24], mm4
  movntq [edi + 32], mm5
  movntq [edi + 40], mm6
  movntq [edi + 48], mm7
  movntq [edi + 56], mm0

  add esi, 64
  add edi, 64
  dec ecx
  jnz @@loop1

  emms

  pop edi
  pop esi
end;

//==============================================================================
//
// memcpy_3DNow64
//
//==============================================================================
procedure memcpy_3DNow64(const dst: pointer; const src: pointer; const len: integer); assembler;
asm
  push esi
  push edi

  mov esi, src
  mov edi, dst
  mov ecx, len
  shr ecx, 6    // 64 bytes per iteration

@@loop1:
// Prefetch next loop, non-temporal
  prefetch [esi + 64]
  prefetch [esi + 96]

// Read in source data
  movq mm1, [esi]
  movq mm2, [esi + 8]
  movq mm3, [esi + 16]
  movq mm4, [esi + 24]
  movq mm5, [esi + 32]
  movq mm6, [esi + 40]
  movq mm7, [esi + 48]
  movq mm0, [esi + 56]

// Non-temporal stores
  movntq [edi], mm1
  movntq [edi + 8], mm2
  movntq [edi + 16], mm3
  movntq [edi + 24], mm4
  movntq [edi + 32], mm5
  movntq [edi + 40], mm6
  movntq [edi + 48], mm7
  movntq [edi + 56], mm0

  add esi, 64
  add edi, 64
  dec ecx
  jnz @@loop1

  emms

  pop edi
  pop esi
end;

//==============================================================================
//
// memcpy
//
//==============================================================================
function memcpy(const dest0: pointer; const src0: pointer; count0: integer): pointer;
var
  dest: PByte;
  src: PByte;
  count: integer;
begin
  if mmxMachine = 0 then
  begin
    Move(src0^, dest0^, count0);
    result := dest0;
    exit;
  end;

{  if abs(integer(dest0) - integer(src0)) < 8 then
  begin
    printf('FUCK!!');
    exit;
  end;}

  // if copying more than 16 bytes and we can copy 8 byte aligned
  if (count0 > 16) and (((PCAST(dest0) xor PCAST(src0)) and 7) = 0) then
  begin
    dest := PByte(dest0);
    src := PByte(src0);

    // copy up to the first 8 byte aligned boundary
    count := PCAST(dest) and 7;
    Move(src^, dest^, count);
    inc(dest, count);
    inc(src, count);
    count := count0 - count;

   // if there are blocks of 64 bytes
    if count and (not 63) <> 0 then
    begin
      if AMD3DNowMachine <> 0 then
        memcpy_3DNow64(dest, src, count and (not 63))
      else
        memcpy_MMX64(dest, src, count and (not 63));
      inc(src, count and (not 63));
      inc(dest, count and (not 63));
      count := count and 63;
    end;

    // if there are blocks of 8 bytes
    if count and (not 7) <> 0 then
    begin
      memcpy_MMX8(dest, src, count);
      inc(src, count and (not 7));
      inc(dest, count and (not 7));
      count := count and 7;
    end;

    // copy any remaining bytes
    Move(src^, dest^, count);
  end
  else
  begin
    // use the regular one if we cannot copy 8 byte aligned
    Move(src0^, dest0^, count0);
  end;
  result := dest0;
end;

type
  union_8b = record
    case integer of
      1: (bytes: array[0..7] of byte);
      2: (words: array[0..3] of word);
      3: (dwords: array[0..1] of LongWord);
  end;

//==============================================================================
//
// memset
//
//==============================================================================
function memset(const dest0: pointer; const val: integer; const count0: integer): pointer;
var
  data: union_8b;
  pdat: pointer;
  dest: PByte;
  count: integer;
begin
  if mmxMachine = 0 then
  begin
    FillChar(dest0^, count0, val);
    result := dest0;
    exit;
  end;

  dest := PByte(dest0);
  count := count0;

  while (count > 0) and (PCAST(dest) and 7 <> 0) do
  begin
    dest^ := val;
    inc(dest);
    dec(count);
  end;

  if count = 0 then
  begin
    result := dest0;
    exit;
  end;

  data.bytes[0] := val;
  data.bytes[1] := val;
  data.words[1] := data.words[0];
  data.dwords[1] := data.dwords[0];
  pdat := @data;

  if count >= 64 then
  begin
    asm
      push esi
      push edi

      mov edi, dest
      mov esi, pdat

      mov ecx, count
      // 64 bytes per iteration
      shr ecx, 6
      // Read in source data
      movq mm1, [esi]
      movq mm2, mm1
      movq mm3, mm1
      movq mm4, mm1
      movq mm5, mm1
      movq mm6, mm1
      movq mm7, mm1
      movq mm0, mm1
@@loop1:
      movntq [edi], mm1
      movntq [edi + 8], mm2
      movntq [edi + 16], mm3
      movntq [edi + 24], mm4
      movntq [edi + 32], mm5
      movntq [edi + 40], mm6
      movntq [edi + 48], mm7
      movntq [edi + 56], mm0

      add edi, 64
      dec ecx
      jnz @@loop1

      pop edi
      pop esi
    end;

    inc(dest, count and (not 63));
    count := count and 63;
  end;

  if count >= 8 then
  begin
    asm
      push esi
      push edi

      mov edi, dest
      mov esi, pdat

      mov ecx, count
      // 8 bytes per iteration
      shr ecx, 3
      // Read in source data
      movq mm1, [esi]
@@loop2:
      movntq  [edi], mm1

      add edi, 8
      dec ecx
      jnz @@loop2

      pop edi
      pop esi
    end;
    inc(dest, count and (not 7));
    count := count and 7;
  end;

  while count > 0 do
  begin
    dest^ := val;
    inc(dest);
    dec(count);
  end;

  asm
    emms
  end;

  result := dest0;
end;

//==============================================================================
//
// malloc
//
//==============================================================================
function malloc(const size: integer): Pointer;
begin
  if size = 0 then
    result := nil
  else
  begin
    GetMem(result, size);
    memoryusage := memoryusage + size;
  end;
end;

//==============================================================================
//
// mallocA
//
//==============================================================================
function mallocA(var Size: integer; const Align: integer; var original: pointer): pointer;
begin
  Size := Size + Align;
  result := malloc(Size);
  original := result;
  if result <> nil then
    result := pointer(PCAST(result) and (1 - Align) + Align);
end;

//==============================================================================
//
// mallocz
//
//==============================================================================
function mallocz(const size: integer): Pointer;
begin
  result := malloc(size);
  if result <> nil then
    ZeroMemory(result, size);
end;

{$IFDEF FPC}

//==============================================================================
//
// realloc
//
//==============================================================================
procedure realloc(var p: pointer; const oldsize, newsize: integer);
{$ELSE}

//==============================================================================
//
// realloc
//
//==============================================================================
function realloc(p: pointer; const oldsize, newsize: integer): pointer;
{$ENDIF}
begin
  if newsize = 0 then
  begin
    memfree(p, oldsize);
    {$IFNDEF FPC}
    result := nil;
    {$ENDIF}
  end
  else
  begin
    if newsize <> oldsize then
    begin
      reallocmem(p, newsize);
      memoryusage := memoryusage - oldsize + newsize;
    end;
    {$IFNDEF FPC}
    result := p;
    {$ENDIF}
  end;
end;

//==============================================================================
//
// memfree
//
//==============================================================================
procedure memfree({$IFDEF FPC}var {$ENDIF}p: pointer; const size: integer);
begin
  if p <> nil then
  begin
    FreeMem(p, size);
    {$IFDEF FPC}
    p := nil;
    {$ENDIF}
    memoryusage := memoryusage - size;
  end;
end;

//==============================================================================
//
// IntToStrZfill
//
//==============================================================================
function IntToStrZfill(const z: integer; const x: integer): string;
var
  i: integer;
  len: integer;
begin
  result := itoa(x);
  len := Length(result);
  for i := len + 1 to z do
    result := '0' + result;
end;

//==============================================================================
//
// intval
//
//==============================================================================
function intval(const b: boolean): integer;
begin
  if b then
    result := 1
  else
    result := 0;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: integer; const iffalse: integer): integer;
begin
  if condition then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: boolean; const iffalse: boolean): boolean;
begin
  if condition then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: string; const iffalse: string): string;
begin
  if condition then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: boolean;
  const iftrue: pointer; const iffalse: pointer): pointer;
begin
  if condition then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: integer; const iffalse: integer): integer;
begin
  if condition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: boolean; const iffalse: boolean): boolean;
begin
  if condition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: string; const iffalse: string): string;
begin
  if condition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// decide
//
//==============================================================================
function decide(const condition: integer;
  const iftrue: pointer; const iffalse: pointer): pointer;
begin
  if condition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

//==============================================================================
//
// incp
//
//==============================================================================
function incp({$IFDEF FPC}var {$ENDIF}p: pointer; const size: integer = 1): pointer;
begin
  result := pOp(p, size);
  {$IFDEF FPC}
  p := result;
  {$ENDIF}
end;

//==============================================================================
//
// pDiff
//
//==============================================================================
function pDiff(const p1, p2: pointer; const size: integer): integer;
begin
  result := (PCAST(p1) - PCAST(p2)) div size;
end;

//==============================================================================
// TStream.Create
//
////////////////////////////////////////////////////////////////////////////////
// TStream
//
//==============================================================================
constructor TStream.Create;
begin
  FIOResult := 0;
end;

//==============================================================================
//
// TStream.IOResult
//
//==============================================================================
function TStream.IOResult: integer;
begin
  result := FIOResult;
  FIOResult := 0;
end;

//==============================================================================
// TFile.Create
//
////////////////////////////////////////////////////////////////////////////////
// TFile
// File class
//
//==============================================================================
constructor TFile.Create(const FileName: string; const mode: integer);
begin
  Inherited Create;
  OnBeginBusy := nil;
  OnEndBusy := nil;

  fopen(f, FileName, mode);
end;

//==============================================================================
//
// TFile.Destroy
//
//==============================================================================
destructor TFile.Destroy;
begin
  close(f);
  Inherited;
end;

//==============================================================================
//
// TFile.Read
//
//==============================================================================
function TFile.Read(var Buffer; Count: Longint): Longint;
begin
  if Assigned(OnBeginBusy) then OnBeginBusy;

  {$I-}
  BlockRead(f, Buffer, Count, result);
  {$I+}
  FIOResult := IOResult;

  if Assigned(OnEndBusy) then OnEndBusy;
end;

//==============================================================================
//
// TFile.Write
//
//==============================================================================
function TFile.Write(const Buffer; Count: Longint): Longint;
begin
  if Assigned(OnBeginBusy) then OnBeginBusy;

  result := 0;
  {$I-}
  BlockWrite(f, Buffer, Count, result);
  {$I+}
  FIOResult := IOResult;

  if Assigned(OnEndBusy) then OnEndBusy;
end;

//==============================================================================
//
// TFile.Seek
//
//==============================================================================
function TFile.Seek(Offset: Longint; Origin: Word): Longint;
begin
  case Origin of
    sFromBeginning:
      result := Offset;
    sFromCurrent:
      result := FilePos(f) + Offset;
    sFromEnd:
      result := FileSize(f) - Offset;
  else
    result := 0;
  end;
  {$I-}
  system.Seek(f, result);
  {$I+}
  FIOResult := IOResult;
end;

//==============================================================================
//
// TFile.Size
//
//==============================================================================
function TFile.Size: Longint;
begin
  {$I-}
  result := FileSize(f);
  {$I+}
  FIOResult := IOResult;
end;

//==============================================================================
//
// TFile.Position
//
//==============================================================================
function TFile.Position: integer;
begin
  {$I-}
  result := FilePos(f);
  {$I+}
  FIOResult := IOResult;
end;

//==============================================================================
// TCachedFile.Create
//
////////////////////////////////////////////////////////////////////////////////
// TCachedFile
// Cache read file class
//
//==============================================================================
constructor TCachedFile.Create(const FileName: string; mode: word; ABufSize: integer = $FFFF);
begin
  fInitialized := false;
  Inherited Create(FileName, mode);
  if ABufSize > Size then
    fBufSize := Size
  else
    fBufSize := ABufSize;
  fBuffer := malloc(fBufSize);
  fPosition := 0;
  ResetBuffer;
  fSize := Inherited Size;
  fInitialized := true;
end;

//==============================================================================
//
// TCachedFile.ResetBuffer
//
//==============================================================================
procedure TCachedFile.ResetBuffer;
begin
  fBufferStart := -1;
  fBufferEnd := -1;
end;

//==============================================================================
//
// TCachedFile.Destroy
//
//==============================================================================
destructor TCachedFile.Destroy;
begin
  memfree(fBuffer, fBufSize);
  Inherited;
end;

//==============================================================================
//
// TCachedFile.Read
//
//==============================================================================
function TCachedFile.Read(var Buffer; Count: Longint): Longint;
var
  x: Longint;
  p: Pointer;
begin
// Buffer hit
  if (fPosition >= fBufferStart) and (fPosition + Count <= fBufferEnd) then
  begin
    p := pOp(fBuffer, fPosition - fBufferStart);
    Move(p^, Buffer, Count);
    fPosition := fPosition + Count;
    result := Count;
  end
// Non Buffer hit, cache buffer
  else if Count <= fBufSize then
  begin
    fPosition := Inherited Seek(fPosition, sFromBeginning);
    x := Inherited Read(fBuffer^, fBufSize);
    if x < Count then
      result := x
    else
      result := Count;
    Move(fBuffer^, Buffer, Count);
    fBufferStart := fPosition;
    fBufferEnd := fPosition + x;
    fPosition := fPosition + result;
  end
// Keep old buffer
  else
  begin
    fPosition := Inherited Seek(fPosition, sFromBeginning);
    result := Inherited Read(Buffer, Count);
    fPosition := fPosition + result;
  end;
end;

//==============================================================================
//
// TCachedFile.Write
//
//==============================================================================
function TCachedFile.Write(const Buffer; Count: Longint): Longint;
begin
  fPosition := Inherited Seek(fPosition, sFromBeginning);
  result := Inherited Write(Buffer, Count);
  fPosition := fPosition + result;
  if fSize < fPosition then
    fSize := fPosition;
end;

//==============================================================================
//
// TCachedFile.Seek
//
//==============================================================================
function TCachedFile.Seek(Offset: Longint; Origin: Word): Longint;
begin
  if fInitialized then
  begin
    case Origin of
      sFromBeginning: fPosition := Offset;
      sFromCurrent: Inc(fPosition, Offset);
      sFromEnd: fPosition := fSize + Offset;
    end;
    result := fPosition;
  end
  else
    result := Inherited Seek(Offset, Origin);
end;

//==============================================================================
//
// TCachedFile.SetSize
//
//==============================================================================
procedure TCachedFile.SetSize(NewSize: Longint);
begin
  Inherited;
  fSize := NewSize;
end;

//==============================================================================
//
// TCachedFile.Position
//
//==============================================================================
function TCachedFile.Position: integer;
begin
  result := FPosition;
end;

//==============================================================================
// TDNumberList.Create
//
////////////////////////////////////////////////////////////////////////////////
// TDNumberList
//
//==============================================================================
constructor TDNumberList.Create;
begin
  fList := nil;
  fNumItems := 0;
end;

//==============================================================================
//
// TDNumberList.Destroy
//
//==============================================================================
destructor TDNumberList.Destroy;
begin
  Clear;
end;

//==============================================================================
//
// TDNumberList.Get
//
//==============================================================================
function TDNumberList.Get(Index: Integer): integer;
begin
  if (Index < 0) or (Index >= fNumItems) then
    result := 0
  else
    result := fList[Index];
end;

//==============================================================================
//
// TDNumberList.Put
//
//==============================================================================
procedure TDNumberList.Put(Index: Integer; const value: integer);
begin
  fList[Index] := value;
end;

//==============================================================================
//
// TDNumberList.Add
//
//==============================================================================
procedure TDNumberList.Add(const value: integer);
begin
  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * SizeOf(integer), (fNumItems + 1) * SizeOf(integer));
  Put(fNumItems, value);
  inc(fNumItems);
end;

//==============================================================================
//
// TDNumberList.Add
//
//==============================================================================
procedure TDNumberList.Add(const nlist: TDNumberList);
var
  i: integer;
begin
  for i := 0 to nlist.Count - 1 do
    Add(nlist[i]);
end;

//==============================================================================
//
// TDNumberList.Delete
//
//==============================================================================
function TDNumberList.Delete(const Index: integer): boolean;
var
  i: integer;
begin
  if (Index < 0) or (Index >= fNumItems) then
  begin
    result := false;
    exit;
  end;

  for i := Index + 1 to fNumItems - 1 do
    fList[i - 1] := fList[i];

  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * SizeOf(integer), (fNumItems - 1) * SizeOf(integer));
  dec(fNumItems);

  result := true;
end;

//==============================================================================
//
// TDNumberList.IndexOf
//
//==============================================================================
function TDNumberList.IndexOf(const value: integer): integer;
var
  i: integer;
begin
  for i := 0 to fNumItems - 1 do
    if fList[i] = value then
    begin
      result := i;
      exit;
    end;
  result := -1;
end;

//==============================================================================
//
// TDNumberList.Clear
//
//==============================================================================
procedure TDNumberList.Clear;
begin
  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * SizeOf(integer), 0);
  fList := nil;
  fNumItems := 0;
end;

//==============================================================================
//
// TDNumberList.Sort
//
//==============================================================================
procedure TDNumberList.Sort;

  procedure qsortI(l, r: Integer);
  var
    i, j: integer;
    t: integer;
    d: integer;
  begin
    repeat
      i := l;
      j := r;
      d := fList[(l + r) shr 1];
      repeat
        while fList[i] < d do
          inc(i);
        while fList[j] > d do
          dec(j);
        if i <= j then
        begin
          t := fList[i];
          fList[i] := fList[j];
          fList[j] := t;
          inc(i);
          dec(j);
        end;
      until i > j;
      if l < j then
        qsortI(l, j);
      l := i;
    until i >= r;
  end;

begin
  if fNumItems > 1 then
    qsortI(0, fNumItems - 1);
end;

//==============================================================================
// TDPointerList.Create
//
////////////////////////////////////////////////////////////////////////////////
// TDPointerList
//
//==============================================================================
constructor TDPointerList.Create;
begin
  fList := nil;
  fNumItems := 0;
  fRealSize := 0;
  inherited;
end;

//==============================================================================
//
// TDPointerList.Destroy
//
//==============================================================================
destructor TDPointerList.Destroy;
begin
  Clear;
  inherited;
end;

//==============================================================================
//
// TDPointerList.AddItem
//
//==============================================================================
procedure TDPointerList.AddItem(const value: pointer);
var
  newsize: integer;
begin
  if fNumItems >= fRealSize then
  begin
    if fRealSize < 16 then
      newsize := fRealSize + 4
    else if fRealSize < 128 then
      newsize := fRealSize + 16
    else if fRealSize < 1024 then
      newsize := fRealSize + 128
    else
      newsize := fRealSize + 256;
    {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fRealSize * SizeOf(pointer), newsize * SizeOf(pointer));
    fRealSize := newsize;
  end;
  fList[fNumItems] := value;
  Inc(fNumItems);
end;

//==============================================================================
//
// TDPointerList.DeleteItem
//
//==============================================================================
function TDPointerList.DeleteItem(const item: pointer): boolean;
var
  i: integer;
begin
  for i := 0 to fNumItems - 1 do
    if fList[i] = item then
    begin
      fList[i] := fList[fNumItems - 1];
      dec(fNumItems);
      Result := True;
      Exit;
    end;

  Result := False;
end;

//==============================================================================
//
// TDPointerList.IndexOf
//
//==============================================================================
function TDPointerList.IndexOf(const value: pointer): integer;
var
  i: integer;
begin
  for i := 0 to fNumItems - 1 do
    if fList[i] = value then
    begin
      Result := i;
      Exit;
    end;
  Result := -1;
end;

//==============================================================================
//
// TDPointerList.Clear
//
//==============================================================================
procedure TDPointerList.Clear;
begin
  memfree(fList, fNumItems * SizeOf(pointer));
  fList := nil;
  fNumItems := 0;
  fRealSize := 0;
end;

//==============================================================================
//
// TDPointerList.FastClear
//
//==============================================================================
procedure TDPointerList.FastClear;
begin
  fNumItems := 0;
end;

//==============================================================================
//
// TDPointerList.HasSameContentWith
//
//==============================================================================
function TDPointerList.HasSameContentWith(const pl: TDPointerList): boolean;
var
  i: integer;
begin
  for i := 0 to fnumitems - 1 do
    if pl.IndexOf(fList[i]) < 0 then
    begin
      result := false;
      exit;
    end;
  for i := 0 to pl.fnumitems - 1 do
    if IndexOf(pl.fList[i]) < 0 then
    begin
      result := false;
      exit;
    end;
  result := true;
end;

//==============================================================================
// TDTextList.Create
//
////////////////////////////////////////////////////////////////////////////////
// TDTextList
//
//==============================================================================
constructor TDTextList.Create;
begin
  fList := nil;
  fNumItems := 0;
end;

//==============================================================================
//
// TDTextList.Destroy
//
//==============================================================================
destructor TDTextList.Destroy;
begin
  Clear;
end;

//==============================================================================
//
// TDTextList.Get
//
//==============================================================================
function TDTextList.Get(Index: Integer): string;
begin
  if (Index < 0) or (Index >= fNumItems) then
    result := ''
  else
    result := fList[Index];
end;

//==============================================================================
//
// TDTextList.Put
//
//==============================================================================
procedure TDTextList.Put(Index: Integer; const value: string);
begin
  fList[Index] := value;
end;

//==============================================================================
//
// TDTextList.Add
//
//==============================================================================
procedure TDTextList.Add(const value: string);
begin
  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * 256, (fNumItems + 1) * 256);
  Put(fNumItems, value);
  inc(fNumItems);
end;

//==============================================================================
//
// TDTextList.Add
//
//==============================================================================
procedure TDTextList.Add(const nlist: TDTextList);
var
  i: integer;
begin
  for i := 0 to nlist.Count - 1 do
    Add(nlist[i]);
end;

//==============================================================================
//
// TDTextList.Delete
//
//==============================================================================
function TDTextList.Delete(const Index: integer): boolean;
var
  i: integer;
begin
  if (Index < 0) or (Index >= fNumItems) then
  begin
    result := false;
    exit;
  end;

  for i := Index + 1 to fNumItems - 1 do
    fList[i - 1] := fList[i];

  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * 256, (fNumItems - 1) * 256);
  dec(fNumItems);

  result := true;
end;

//==============================================================================
//
// TDTextList.IndexOf
//
//==============================================================================
function TDTextList.IndexOf(const value: string): integer;
var
  i: integer;
begin
  for i := 0 to fNumItems - 1 do
    if fList[i] = value then
    begin
      result := i;
      exit;
    end;
  result := -1;
end;

//==============================================================================
//
// TDTextList.Clear
//
//==============================================================================
procedure TDTextList.Clear;
begin
  {$IFNDEF FPC}fList := {$ENDIF}realloc(fList, fNumItems * 256, 0);
  fList := nil;
  fNumItems := 0;
end;

//==============================================================================
// TDStrings.Add
//
////////////////////////////////////////////////////////////////////////////////
// TDStrings
//
//==============================================================================
function TDStrings.Add(const S: string): Integer;
begin
  result := GetCount;
  Insert(result, S);
end;

//==============================================================================
//
// TDStrings.Add
//
//==============================================================================
function TDStrings.Add(const Fmt: string; const Args: array of const): integer;
var
  str: string;
begin
  sprintf(str, Fmt, Args);
  result := Add(str);
end;

//==============================================================================
//
// TDStrings.AddObject
//
//==============================================================================
function TDStrings.AddObject(const S: string; AObject: TObject): Integer;
begin
  result := Add(S);
  PutObject(result, AObject);
end;

//==============================================================================
//
// TDStrings.Append
//
//==============================================================================
procedure TDStrings.Append(const S: string);
begin
  Add(S);
end;

//==============================================================================
//
// TDStrings.AddStrings
//
//==============================================================================
procedure TDStrings.AddStrings(Strings: TDStrings);
var
  I: Integer;
begin
  for I := 0 to Strings.Count - 1 do
    AddObject(Strings[I], Strings.Objects[I]);
end;

//==============================================================================
//
// TDStrings.Equals
//
//==============================================================================
function TDStrings.Equals(Strings: TDStrings): Boolean;
var
  I, iCount: Integer;
begin
  result := false;
  iCount := GetCount;
  if iCount <> Strings.GetCount then Exit;
  for I := 0 to iCount - 1 do if Get(I) <> Strings.Get(I) then Exit;
  result := true;
end;

//==============================================================================
//
// TDStrings.Exchange
//
//==============================================================================
procedure TDStrings.Exchange(Index1, Index2: Integer);
var
  TempObject: TObject;
  TempString: string;
begin
  TempString := Strings[Index1];
  TempObject := Objects[Index1];
  Strings[Index1] := Strings[Index2];
  Objects[Index1] := Objects[Index2];
  Strings[Index2] := TempString;
  Objects[Index2] := TempObject;
end;

//==============================================================================
//
// TDStrings.GetCapacity
//
//==============================================================================
function TDStrings.GetCapacity: Integer;
begin  // descendants may optionally override/replace this default implementation
  result := Count;
end;

//==============================================================================
//
// TDStrings.GetCommaText
//
//==============================================================================
function TDStrings.GetCommaText: string;
var
  S: string;
  P: PChar;
  I, iCount: Integer;
begin
  iCount := GetCount;
  if (iCount = 1) and (Get(0) = '') then
    result := '""'
  else
  begin
    result := '';
    for I := 0 to iCount - 1 do
    begin
      S := Get(I);
      P := PChar(S);
      while not (P^ in [#0..' ','"',',']) do P := CharNext(P);
      if (P^ <> #0) then S := AnsiQuotedStr(S, '"');
      result := result + S + ',';
    end;
    System.Delete(result, Length(result), 1);
  end;
end;

//==============================================================================
//
// TDStrings.GetName
//
//==============================================================================
function TDStrings.GetName(Index: Integer): string;
var
  P: Integer;
begin
  result := Get(Index);
  P := AnsiPos('=', result);
  if P <> 0 then
    SetLength(result, P-1)
  else
    SetLength(result, 0);
end;

//==============================================================================
//
// TDStrings.GetObject
//
//==============================================================================
function TDStrings.GetObject(Index: Integer): TObject;
begin
  result := nil;
end;

//==============================================================================
//
// TDStrings.GetText
//
//==============================================================================
function TDStrings.GetText: PChar;
begin
  result := StrNew(PChar(GetTextStr));
end;

//==============================================================================
//
// TDStrings.GetTextStr
//
//==============================================================================
function TDStrings.GetTextStr: string;
var
  I, L, Size, iCount: Integer;
  P: PChar;
  S: string;
begin
  iCount := GetCount;
  Size := 0;
  for I := 0 to iCount - 1 do Inc(Size, Length(Get(I)) + 2);
  SetString(result, nil, Size);
  P := Pointer(result);
  for I := 0 to iCount - 1 do
  begin
    S := Get(I);
    L := Length(S);
    if L <> 0 then
    begin
      System.Move(Pointer(S)^, P^, L);
      Inc(P, L);
    end;
    P^ := #13;
    Inc(P);
    P^ := #10;
    Inc(P);
  end;
end;

//==============================================================================
//
// TDStrings.GetValue
//
//==============================================================================
function TDStrings.GetValue(const Name: string): string;
var
  I: Integer;
begin
  I := IndexOfName(Name);
  if I >= 0 then
    result := Copy(Get(I), Length(Name) + 2, MaxInt) else
    result := '';
end;

//==============================================================================
//
// TDStrings.IndexOf
//
//==============================================================================
function TDStrings.IndexOf(const S: string): Integer;
begin
  for result := 0 to GetCount - 1 do
    if AnsiCompareText(Get(result), S) = 0 then Exit;
  result := -1;
end;

//==============================================================================
//
// TDStrings.IndexOfName
//
//==============================================================================
function TDStrings.IndexOfName(const Name: string): Integer;
var
  P: Integer;
  S: string;
begin
  for result := 0 to GetCount - 1 do
  begin
    S := Get(result);
    P := AnsiPos('=', S);
    if (P <> 0) and (AnsiCompareText(Copy(S, 1, P - 1), Name) = 0) then Exit;
  end;
  result := -1;
end;

//==============================================================================
//
// TDStrings.IndexOfObject
//
//==============================================================================
function TDStrings.IndexOfObject(AObject: TObject): Integer;
begin
  for result := 0 to GetCount - 1 do
    if GetObject(result) = AObject then Exit;
  result := -1;
end;

//==============================================================================
//
// TDStrings.InsertObject
//
//==============================================================================
procedure TDStrings.InsertObject(Index: Integer; const S: string;
  AObject: TObject);
begin
  Insert(Index, S);
  PutObject(Index, AObject);
end;

//==============================================================================
//
// TDStrings.LoadFromFile
//
//==============================================================================
function TDStrings.LoadFromFile(const FileName: string): boolean;
var
  f: file;
  Size: Integer;
  S: string;
begin
  if fopen(f, FileName, fOpenReadOnly) then
  begin
    {$I-}
    Size := FileSize(f);
    SetString(S, nil, Size);
    BlockRead(f, Pointer(S)^, Size);
    SetTextStr(S);
    close(f);
    {$I+}
    result := IOresult = 0;
  end
  else
    result := false;
end;

//==============================================================================
//
// TDStrings.LoadFromStream
//
//==============================================================================
function TDStrings.LoadFromStream(const strm: TStream): boolean;
var
  Size: Integer;
  A: PByteArray;
begin
  {$I-}
  strm.Seek(0, sFromBeginning);
  Size := strm.Size;
  A := malloc(Size);
  strm.Read(A^, Size);
  SetByteStr(A, Size);
  memfree(A, Size);
  {$I+}
  result := IOresult = 0;
end;

//==============================================================================
//
// TDStrings.Move
//
//==============================================================================
procedure TDStrings.Move(CurIndex, NewIndex: Integer);
var
  TempObject: TObject;
  TempString: string;
begin
  if CurIndex <> NewIndex then
  begin
    TempString := Get(CurIndex);
    TempObject := GetObject(CurIndex);
    Delete(CurIndex);
    InsertObject(NewIndex, TempString, TempObject);
  end;
end;

//==============================================================================
//
// TDStrings.Put
//
//==============================================================================
procedure TDStrings.Put(Index: Integer; const S: string);
var
  TempObject: TObject;
begin
  TempObject := GetObject(Index);
  Delete(Index);
  InsertObject(Index, S, TempObject);
end;

//==============================================================================
//
// TDStrings.PutObject
//
//==============================================================================
procedure TDStrings.PutObject(Index: Integer; AObject: TObject);
begin
end;

//==============================================================================
//
// TDStrings.SaveToFile
//
//==============================================================================
function TDStrings.SaveToFile(const FileName: string): boolean;
var
  f: file;
  S: string;
begin
  if fopen(f, FileName, fCreate) then
  begin
    {$I-}
    S := GetTextStr;
    BlockWrite(f, Pointer(S)^, Length(S));
    close(f);
    {$I+}
    result := IOresult = 0;
  end
  else
    result := false;
end;

//==============================================================================
//
// TDStrings.SetCapacity
//
//==============================================================================
procedure TDStrings.SetCapacity(NewCapacity: Integer);
begin
  // do nothing - descendants may optionally implement this method
end;

//==============================================================================
//
// TDStrings.SetCommaText
//
//==============================================================================
procedure TDStrings.SetCommaText(const Value: string);
var
  P, P1: PChar;
  S: string;
begin
  Clear;
  P := PChar(Value);
  while P^ in [#1..' '] do P := CharNext(P);
  while P^ <> #0 do
  begin
    if P^ = '"' then
      S := AnsiExtractQuotedStr(P, '"')
    else
    begin
      P1 := P;
      while (P^ > ' ') and (P^ <> ',') do P := CharNext(P);
      SetString(S, P1, P - P1);
    end;
    Add(S);
    while P^ in [#1..' '] do P := CharNext(P);
    if P^ = ',' then
      repeat
        P := CharNext(P);
      until not (P^ in [#1..' ']);
  end;
end;

//==============================================================================
//
// TDStrings.SetText
//
//==============================================================================
procedure TDStrings.SetText(Text: PChar);
begin
  SetTextStr(Text);
end;

//==============================================================================
//
// TDStrings.SetTextStr
//
//==============================================================================
procedure TDStrings.SetTextStr(const Value: string);
var
  P, Start: PChar;
  S: string;
begin
  Clear;
  P := Pointer(Value);
  if P <> nil then
    while P^ <> #0 do
    begin
      Start := P;
      while not (P^ in [#0, #10, #13]) do Inc(P);
      SetString(S, Start, P - Start);
      Add(S);
      if P^ = #13 then Inc(P);
      if P^ = #10 then Inc(P);
    end;
end;

//==============================================================================
//
// TDStrings.SetByteStr
//
//==============================================================================
procedure TDStrings.SetByteStr(const A: PByteArray; const Size: integer);
var
  P, Start: PChar;
  S: string;
begin
  Clear;
  P := PChar(@A[0]);
  if P <> nil then
    while (P^ <> #0) and (P <> @A[Size]) do
    begin
      Start := P;
      while (not (P^ in [#0, #10, #13])) and (P <> @A[Size]) do Inc(P);
      SetString(S, Start, P - Start);
      Add(S);
      if P^ = #13 then Inc(P);
      if P^ = #10 then Inc(P);
    end;
end;

//==============================================================================
//
// TDStrings.SetValue
//
//==============================================================================
procedure TDStrings.SetValue(const Name, Value: string);
var
  I: Integer;
begin
  I := IndexOfName(Name);
  if Value <> '' then
  begin
    if I < 0 then I := Add('');
    Put(I, Name + '=' + Value);
  end else
  begin
    if I >= 0 then Delete(I);
  end;
end;

//==============================================================================
// TDStringList.Destroy
//
////////////////////////////////////////////////////////////////////////////////
// TStringList
//
//==============================================================================
destructor TDStringList.Destroy;
begin
  inherited Destroy;
  if FCount <> 0 then Finalize(FList[0], FCount);
  FCount := 0;
  SetCapacity(0);
end;

//==============================================================================
//
// TDStringList.Add
//
//==============================================================================
function TDStringList.Add(const S: string): Integer;
begin
  result := FCount;
  InsertItem(result, S);
end;

//==============================================================================
//
// TDStringList.Clear
//
//==============================================================================
procedure TDStringList.Clear;
begin
  if FCount <> 0 then
  begin
    Finalize(FList[0], FCount);
    FCount := 0;
    SetCapacity(0);
  end;
end;

//==============================================================================
//
// TDStringList.Delete
//
//==============================================================================
procedure TDStringList.Delete(Index: Integer);
begin
  if (Index >= 0) and (Index < FCount) then
  begin
    Finalize(FList[Index]);
    Dec(FCount);
    if Index < FCount then
      System.Move(FList[Index + 1], FList[Index],
        (FCount - Index) * SizeOf(TStringItem));
  end;
end;

//==============================================================================
//
// TDStringList.Exchange
//
//==============================================================================
procedure TDStringList.Exchange(Index1, Index2: Integer);
begin
  if (Index1 < 0) or (Index1 >= FCount) then exit;
  if (Index2 < 0) or (Index2 >= FCount) then exit;
  ExchangeItems(Index1, Index2);
end;

//==============================================================================
//
// TDStringList.ExchangeItems
//
//==============================================================================
procedure TDStringList.ExchangeItems(Index1, Index2: Integer);
var
  Temp: Integer;
  Item1, Item2: PStringItem;
begin
  Item1 := @FList[Index1];
  Item2 := @FList[Index2];
  Temp := Integer(Item1.FString);
  Integer(Item1.FString) := Integer(Item2.FString);
  Integer(Item2.FString) := Temp;
  Temp := Integer(Item1.FObject);
  Integer(Item1.FObject) := Integer(Item2.FObject);
  Integer(Item2.FObject) := Temp;
end;

//==============================================================================
//
// TDStringList.Get
//
//==============================================================================
function TDStringList.Get(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FCount) then
    result := FList[Index].FString
  else
    result := '';
end;

//==============================================================================
//
// TDStringList.GetCapacity
//
//==============================================================================
function TDStringList.GetCapacity: Integer;
begin
  result := FCapacity;
end;

//==============================================================================
//
// TDStringList.GetCount
//
//==============================================================================
function TDStringList.GetCount: Integer;
begin
  result := FCount;
end;

//==============================================================================
//
// TDStringList.GetObject
//
//==============================================================================
function TDStringList.GetObject(Index: Integer): TObject;
begin
  if (Index >= 0) and (Index < FCount) then
    result := FList[Index].FObject
  else
    result := nil;
end;

//==============================================================================
//
// TDStringList.Grow
//
//==============================================================================
procedure TDStringList.Grow;
var
  Delta: Integer;
begin
  if FCapacity > 64 then Delta := FCapacity div 4 else
    if FCapacity > 8 then Delta := 16 else
      Delta := 4;
  SetCapacity(FCapacity + Delta);
end;

//==============================================================================
//
// TDStringList.Insert
//
//==============================================================================
procedure TDStringList.Insert(Index: Integer; const S: string);
begin
  if (Index >= 0) and (Index <= FCount) then
    InsertItem(Index, S);
end;

//==============================================================================
//
// TDStringList.InsertItem
//
//==============================================================================
procedure TDStringList.InsertItem(Index: Integer; const S: string);
begin
  if FCount = FCapacity then Grow;
  if Index < FCount then
    System.Move(FList[Index], FList[Index + 1],
      (FCount - Index) * SizeOf(TStringItem));
  with FList[Index] do
  begin
    Pointer(FString) := nil;
    FObject := nil;
    FString := S;
  end;
  Inc(FCount);
end;

//==============================================================================
//
// TDStringList.Put
//
//==============================================================================
procedure TDStringList.Put(Index: Integer; const S: string);
begin
  if (Index > 0) and (Index < FCount) then
    FList[Index].FString := S;
end;

//==============================================================================
//
// TDStringList.PutObject
//
//==============================================================================
procedure TDStringList.PutObject(Index: Integer; AObject: TObject);
begin
  if (Index >= 0) and (Index < FCount) then
    FList[Index].FObject := AObject;
end;

//==============================================================================
//
// TDStringList.SetCapacity
//
//==============================================================================
procedure TDStringList.SetCapacity(NewCapacity: Integer);
begin
  {$IFNDEF FPC}FList := {$ENDIF}realloc(FList, FCapacity * SizeOf(TStringItem), NewCapacity * SizeOf(TStringItem));
  FCapacity := NewCapacity;
end;

//==============================================================================
// getenv
//
////////////////////////////////////////////////////////////////////////////////
//
//==============================================================================
function getenv(const env: string): string;
var
  buf: array[0..255] of char;
begin
  ZeroMemory(@buf, SizeOf(buf));
  GetEnvironmentVariable(PChar(env), buf, 255);
  result := Trim(StringVal(buf));
end;

//==============================================================================
//
// fexists
//
//==============================================================================
function fexists(const filename: string): boolean;
begin
  result := FileExists(filename);
end;

//==============================================================================
//
// fexpand
//
//==============================================================================
function fexpand(const filename: string): string;
begin
  result := ExpandFileName(filename);
end;

//==============================================================================
//
// fpath
//
//==============================================================================
function fpath(const filename: string): string;
begin
  result := ExtractFilePath(filename);
end;

//==============================================================================
//
// fdelete
//
//==============================================================================
procedure fdelete(const filename: string);
begin
  if fexists(filename) then
    DeleteFile(filename);
end;

//==============================================================================
//
// fext
//
//==============================================================================
function fext(const filename: string): string;
begin
  result := ExtractFileExt(filename);
end;

//==============================================================================
//
// fname
//
//==============================================================================
function fname(const filename: string): string;
begin
  result := ExtractFileName(filename);
end;

//==============================================================================
//
// fmask
//
//==============================================================================
function fmask(const mask: string): string;
begin
  result := mask;
  if result = '' then
    result := '*.*';
end;

//==============================================================================
//
// findfile
//
//==============================================================================
function findfile(const mask: string): string;
var
  sr: TSearchRec;
  mask1: string;
begin
  mask1 := fmask(mask);
  if FindFirst(mask1, faAnyFile, sr) = 0 then
  begin
    result := sr.Name;
    FindClose(sr);
  end
  else
    result := '';
end;

//==============================================================================
//
// findfiles
//
//==============================================================================
function findfiles(const mask: string): TDStringList;
var
  sr: TSearchRec;
  mask1: string;
begin
  result := TDStringList.Create;
  mask1 := fmask(mask);
  if FindFirst(mask1, faAnyFile, sr) = 0 then
  begin
    result.Add(sr.Name);
    while FindNext(sr) = 0 do
      result.Add(sr.Name);
    FindClose(sr);
  end;
end;

//==============================================================================
//
// tan
//
//==============================================================================
function tan(const x: extended): extended;
var
  a: single;
  b: single;
begin
  b := cos(x);
  if b <> 0 then
  begin
    a := sin(x);
    result := a / b;
  end
  else
    result := 0.0;
end;

//==============================================================================
//
// strupper
//
//==============================================================================
function strupper(const S: string): string;
var
  Ch: Char;
  L: Integer;
  Source, Dest: PChar;
begin
  L := Length(S);
  SetLength(result, L);
  Source := Pointer(S);
  Dest := Pointer(result);
  while L <> 0 do
  begin
    Ch := Source^;
    if (Ch >= 'a') and (Ch <= 'z') then Dec(Ch, 32);
    Dest^ := Ch;
    Inc(Source);
    Inc(Dest);
    Dec(L);
  end;
end;

//==============================================================================
//
// strlower
//
//==============================================================================
function strlower(const S: string): string;
var
  Ch: Char;
  L: Integer;
  Source, Dest: PChar;
begin
  L := Length(S);
  SetLength(result, L);
  Source := Pointer(S);
  Dest := Pointer(result);
  while L <> 0 do
  begin
    Ch := Source^;
    if (Ch >= 'A') and (Ch <= 'Z') then Inc(Ch, 32);
    Dest^ := Ch;
    Inc(Source);
    Inc(Dest);
    Dec(L);
  end;
end;

//==============================================================================
//
// toupper
//
//==============================================================================
function toupper(ch: Char): Char;
asm
{ ->    AL      Character       }
{ <-    AL      result          }

  cmp al, 'a'
  jb  @@exit
  cmp al, 'z'
  ja  @@exit
  sub al, 'a' - 'A'
@@exit:
end;

//==============================================================================
//
// tolower
//
//==============================================================================
function tolower(ch: Char): Char;
asm
{ ->    AL      Character       }
{ <-    AL      result          }

  cmp al, 'A'
  jb  @@exit
  cmp al, 'Z'
  ja  @@exit
  sub al, 'A' - 'a'
@@exit:
end;

//==============================================================================
//
// strremovespaces
//
//==============================================================================
function strremovespaces(const s: string): string;
var
  i: integer;
begin
  result := '';
  for i := 1 to Length(s) do
    if s[i] <> ' ' then
      result := result + s[i];
end;

//==============================================================================
//
// _SHL
//
//==============================================================================
function _SHL(const x: integer; const bits: integer): integer; assembler;
asm
  mov ecx, edx
  sal eax, cl
end;

//==============================================================================
//
// _SHLW
//
//==============================================================================
function _SHLW(const x: LongWord; const bits: LongWord): LongWord; {$IFDEF FPC}inline;{$ENDIF}
begin
  result := x shl bits;
end;

//==============================================================================
//
// _SHR
//
//==============================================================================
function _SHR(const x: integer; const bits: integer): integer; assembler;
asm
  mov ecx, edx
  sar eax, cl
end;

//==============================================================================
//
// _SHR1
//
//==============================================================================
function _SHR1(const x: integer): integer; assembler;
asm
  sar eax, 1
end;

//==============================================================================
//
// _SHR2
//
//==============================================================================
function _SHR2(const x: integer): integer; assembler;
asm
  sar eax, 2
end;

//==============================================================================
//
// _SHR8
//
//==============================================================================
function _SHR8(const x: integer): integer; assembler;
asm
  sar eax, 8
end;

//==============================================================================
//
// _SHR14
//
//==============================================================================
function _SHR14(const x: integer): integer; assembler;
asm
  sar eax, 14
end;

//==============================================================================
//
// _SHRW
//
//==============================================================================
function _SHRW(const x: LongWord; const bits: LongWord): LongWord; {$IFDEF FPC}inline;{$ENDIF}
begin
  result := x shr bits;
end;

//==============================================================================
//
// StringVal
//
//==============================================================================
function StringVal(const Str: PChar): string;
begin
  result := Str;
end;

//==============================================================================
//
// ZeroMemory
//
//==============================================================================
procedure ZeroMemory(const dest0: pointer; const count0: integer);
var
  data: union_8b;
  pdat: pointer;
  dest: PByte;
  count: integer;
begin
  if mmxMachine = 0 then
  begin
    FillChar(dest0^, count0, 0);
    exit;
  end;

  dest := PByte(dest0);
  count := count0;

  while (count > 0) and (PCAST(dest) and 7 <> 0) do
  begin
    dest^ := 0;
    inc(dest);
    dec(count);
  end;

  if count = 0 then
  begin
    exit;
  end;

  data.dwords[0] := 0;
  data.dwords[1] := 0;
  pdat := @data;

  if count >= 64 then
  begin
    asm
      push esi
      push edi

      mov edi, dest
      mov esi, pdat

      mov ecx, count
      // 64 bytes per iteration
      shr ecx, 6
      // Read in source data
      movq mm1, [esi]
      movq mm2, mm1
      movq mm3, mm1
      movq mm4, mm1
      movq mm5, mm1
      movq mm6, mm1
      movq mm7, mm1
      movq mm0, mm1
@@loop1:
      // Non-temporal stores
      movntq [edi], mm1
      movntq [edi + 8], mm2
      movntq [edi + 16], mm3
      movntq [edi + 24], mm4
      movntq [edi + 32], mm5
      movntq [edi + 40], mm6
      movntq [edi + 48], mm7
      movntq [edi + 56], mm0

      add edi, 64
      dec ecx
      jnz @@loop1

      pop edi
      pop esi
    end;

    inc(dest, count and (not 63));
    count := count and 63;
  end;

  if count >= 8 then
  begin
    asm
      push esi
      push edi

      mov edi, dest
      mov esi, pdat

      mov ecx, count
      // 8 bytes per iteration
      shr ecx, 3
      // Read in source data
      movq mm1, [esi]
@@loop2:
      // Non-temporal stores
      movntq  [edi], mm1

      add edi, 8
      dec ecx
      jnz @@loop2

      pop edi
      pop esi
    end;
    inc(dest, count and (not 7));
    count := count and 7;
  end;

  while count > 0 do
  begin
    dest^ := 0;
    inc(dest);
    dec(count);
  end;

  asm
    emms
  end;

end;

//==============================================================================
//
// fopen
//
//==============================================================================
function fopen(var f: file; const FileName: string; const mode: integer): boolean;
begin
  assign(f, FileName);
  {$I-}
  if mode = fCreate then
  begin
    FileMode := 2;
    rewrite(f, 1);
  end
  else if mode = fOpenReadOnly then
  begin
    FileMode := 0;
    reset(f, 1);
  end
  else if mode = fOpenReadWrite then
  begin
    FileMode := 2;
    reset(f, 1);
  end
  else
  begin
    result := false;
    exit;
  end;
  {$I+}
  result := IOresult = 0;
end;

//==============================================================================
//
// fsize
//
//==============================================================================
function fsize(const FileName: string): integer;
var
  f: file;
begin
  if fopen(f, FileName, fOpenReadOnly) then
  begin
  {$I-}
    result := FileSize(f);
    close(f);
  {$I+}
  end
  else
    result := 0;
end;

//==============================================================================
//
// fshortname
//
//==============================================================================
function fshortname(const FileName: string): string;
var
  i: integer;
begin
  result := '';
  for i := Length(FileName) downto 1 do
  begin
    if FileName[i] in ['\', '/'] then
      break;
    result := FileName[i] + result;
  end;
end;

//==============================================================================
//
// strtrim
//
//==============================================================================
function strtrim(const S: string): string;
var
  I, L: Integer;
begin
  L := Length(S);
  I := 1;
  while (I <= L) and (S[I] <= ' ') do Inc(I);
  if I > L then result := '' else
  begin
    while S[L] <= ' ' do Dec(L);
    result := Copy(S, I, L - I + 1);
  end;
end;

//==============================================================================
//
// capitalizedstring
//
//==============================================================================
function capitalizedstring(const S: string; const splitter: char = ' '): string;
var
  i: integer;
  c: string;
begin
  if S = '' then
  begin
    result := '';
    exit;
  end;

  result := strlower(S);
  result[1] := toupper(result[1]);
  c := tolower(splitter);
  for i := 2 to Length(result) do
  begin
    if result[i - 1] = c then
      result[i] := toupper(result[i])
  end;
end;

//==============================================================================
//
// splitstring
//
//==============================================================================
procedure splitstring(const inp: string; var out1, out2: string; const splitter: string = ' ');
var
  p: integer;
begin
  p := Pos(splitter, inp);
  if p = 0 then
  begin
    out1 := inp;
    out2 := '';
  end
  else
  begin
    out1 := strtrim(Copy(inp, 1, p - 1));
    out2 := strtrim(Copy(inp, p + 1, Length(inp) - p));
  end;
end;

//==============================================================================
//
// splitstring
//
//==============================================================================
procedure splitstring(const inp: string; var out1, out2: string; const splitters: charset_t);
var
  i: integer;
  p: integer;
  inp1: string;
begin
  inp1 := inp;
  for i := 1 to Length(inp1) do
    if inp1[i] in splitters then
      inp1[i] := ' ';
  p := Pos(' ', inp1);
  if p = 0 then
  begin
    out1 := inp1;
    out2 := '';
  end
  else
  begin
    out1 := strtrim(Copy(inp1, 1, p - 1));
    out2 := strtrim(Copy(inp1, p + 1, Length(inp) - p));
  end;
end;

//==============================================================================
//
// firstword
//
//==============================================================================
function firstword(const inp: string; const splitter: string = ' '): string;
var
  tmp: string;
begin
  splitstring(inp, result, tmp, splitter);
end;

//==============================================================================
//
// firstword
//
//==============================================================================
function firstword(const inp: string; const splitters: charset_t): string;
var
  tmp: string;
begin
  splitstring(inp, result, tmp, splitters);
end;

//==============================================================================
//
// parsefirstword
//
//==============================================================================
function parsefirstword(const inp: string): string;
var
  st: string;
  tmp: string;
  i: integer;
begin
  st := strtrim(inp);
  if st = '' then
  begin
    result := '';
    exit;
  end;

  if st[1] = '"' then
  begin
    result := '';
    for i := 2 to Length(st) do
    begin
      if st[i] = '"' then
        break;
      result := result + st[i];
    end;
    exit;
  end;

  splitstring(st, result, tmp, ' ');
end;

//==============================================================================
//
// secondword
//
//==============================================================================
function secondword(const inp: string; const splitter: string = ' '): string;
var
  tmp: string;
begin
  splitstring(inp, tmp, result, splitter);
end;

//==============================================================================
//
// secondword
//
//==============================================================================
function secondword(const inp: string; const splitters: charset_t): string; overload;
var
  tmp: string;
begin
  splitstring(inp, tmp, result, splitters);
end;

//==============================================================================
//
// lastword
//
//==============================================================================
function lastword(const inp: string; const splitter: string = ' '): string;
var
  i: integer;
begin
  result := '';
  i := length(inp);
  while i > 0 do
  begin
    if inp[i] = splitter then
      exit
    else
    begin
      result := inp[i] + result;
      dec(i);
    end;
  end;
end;

//==============================================================================
//
// lastword
//
//==============================================================================
function lastword(const inp: string; const splitters: charset_t): string; overload;
var
  i: integer;
begin
  result := '';
  i := length(inp);
  while i > 0 do
  begin
    if inp[i] in splitters then
      exit
    else
    begin
      result := inp[i] + result;
      dec(i);
    end;
  end;
end;

//==============================================================================
//
// FreeAndNil
//
//==============================================================================
procedure FreeAndNil(var Obj);
var
  Temp: TObject;
begin
  Temp := TObject(Obj);
  Pointer(Obj) := nil;
  Temp.Free;
end;

//==============================================================================
//
// StrLCopy
//
//==============================================================================
function StrLCopy(Dest: PChar; const Source: PChar; MaxLen: Cardinal): PChar; assembler;
asm
        PUSH    EDI
        PUSH    ESI
        PUSH    EBX
        MOV     ESI,EAX
        MOV     EDI,EDX
        MOV     EBX,ECX
        XOR     AL,AL
        TEST    ECX,ECX
        JZ      @@1
        REPNE   SCASB
        JNE     @@1
        INC     ECX
@@1:    SUB     EBX,ECX
        MOV     EDI,ESI
        MOV     ESI,EDX
        MOV     EDX,EDI
        MOV     ECX,EBX
        SHR     ECX,2
        REP     MOVSD
        MOV     ECX,EBX
        AND     ECX,3
        REP     MOVSB
        STOSB
        MOV     EAX,EDX
        POP     EBX
        POP     ESI
        POP     EDI
end;

//==============================================================================
//
// fabs
//
//==============================================================================
function fabs(const f: float): float;
begin
  if f >= 0 then
    result := f
  else
    result := -f;
end;

//==============================================================================
//
// MakeDir
//
//==============================================================================
procedure MakeDir(const dir: string);
begin
  CreateDir(dir);
end;

{$IFDEF FPC}

//==============================================================================
//
// GetEnvironmentVariable
//
//==============================================================================
function GetEnvironmentVariable(lpName: PChar; lpBuffer: PChar; nSize: DWORD): DWORD; stdcall; external 'kernel32.dll' name 'GetEnvironmentVariableA';
{$ENDIF}

//==============================================================================
//
// AllocMemSize
//
//==============================================================================
function AllocMemSize: integer;
begin
  result := memoryusage;
end;

//==============================================================================
//
// NowTime
//
//==============================================================================
function NowTime: TDateTime;
begin
  result := Now;
end;

//==============================================================================
//
// formatDateTimeAsString
//
//==============================================================================
function formatDateTimeAsString(const Format: string; DateTime: TDateTime): string;
begin
  DateTimeToString(Result, Format, DateTime);
end;

//==============================================================================
//
// min3b
//
//==============================================================================
function min3b(const a, b, c: byte): byte; {$IFDEF FPC}inline;{$ENDIF}
begin
  result := a;
  if b < result then
    result := b;
  if c < result then
    result := c;
end;

//==============================================================================
//
// max3b
//
//==============================================================================
function max3b(const a, b, c: byte): byte; {$IFDEF FPC}inline;{$ENDIF}
begin
  result := a;
  if b > result then
    result := b;
  if c > result then
    result := c;
end;

//==============================================================================
//
// ibetween
//
//==============================================================================
function ibetween(const x: integer; const x1, x2: integer): integer; {$IFDEF FPC}inline;{$ENDIF}
begin
  if x <= x1 then
    result := x1
  else if x >= x2 then
    result := x2
  else
    result := x;
end;

//==============================================================================
//
// pOp
//
//==============================================================================
function pOp(const p: pointer; const offs: integer): pointer; {$IFDEF FPC}inline;{$ENDIF}
begin
  result := pointer(PCAST(p) + offs);
end;

//==============================================================================
//
// imin
//
//==============================================================================
function imin(const x1, x2: integer): integer; {$IFDEF FPC}inline;{$ENDIF}
begin
  if x1 > x2 then
    result := x2
  else
    result := x1;
end;

//==============================================================================
//
// imax
//
//==============================================================================
function imax(const x1, x2: integer): integer; {$IFDEF FPC}inline;{$ENDIF}
begin
  if x1 > x2 then
    result := x1
  else
    result := x2;
end;

//==============================================================================
//
// logtofile
//
//==============================================================================
procedure logtofile(const fname: string; const str: string);
var
  f: file;
begin
  if not fexists(fname) then
    fopen(f, fname, fCreate)
  else
  begin
    fopen(f, fname, fOpenReadWrite);
    system.Seek(f, FileSize(f));
  end;
  {$I-}
  BlockWrite(f, Pointer(str)^, Length(str));
  close(f);
end;

//==============================================================================
//
// RemoveQuotesFromString
//
//==============================================================================
function RemoveQuotesFromString(const s: string): string;
begin
  Result := s;
  if Result = '' then
    Exit;
  if Result[1] = '"' then
    Delete(Result, 1, 1);
  if (Result <> '') and (Result[Length(Result)] = '"') then
    Delete(Result, Length(Result), 1);
end;

end.

