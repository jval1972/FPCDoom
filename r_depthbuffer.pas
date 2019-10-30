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

unit r_depthbuffer;

interface

uses
  d_fpc,
  r_defs,
  r_draw_column,
  r_draw_span;

type
  depthbufferitem_t = record
    depth: LongWord;
    seg: Pseg_t;
    rendertype: LongWord;
  end;
  Pdepthbufferitem_t = ^depthbufferitem_t;

procedure R_DrawSpanToDepthBuffer(const parms: Pspanparams_t);

procedure R_DrawColumnToDepthBuffer(const parms: Pcolumnparams_t);

// Returns the depth buffer value at (x, y) or screen
// Lower value means far away
// Depth buffer initialization -> Set buffer to 0
// Sky depth is 0 - so we do not write depthbuffer in skycolfunc
function R_DepthBufferDepthAt(const x, y: integer): LongWord;

function R_DepthBufferAt(const x, y: integer): Pdepthbufferitem_t;

procedure R_InitDepthBuffer;

procedure R_ShutDownDepthBuffer;

procedure R_StartDepthBuffer;

procedure R_CalcDepthBuffer;

function R_DBCriticalX(const x: integer): boolean;

procedure R_StopDepthBuffer;

implementation

uses
  doomdef,
  r_render,
  r_lightmap,
  m_fixed,
  r_draw,
  r_main;

const
  DB_XACCURACY = 1;
  DB_XMOD = DB_XACCURACY div 2;

var
  DB_YACCURACY: integer = 5;
  DB_YMOD: integer = 2;

type
  depthbufferitem_tArray = array[0..$FFFF] of depthbufferitem_t;
  Pdepthbufferitem_tArray = ^depthbufferitem_tArray;

var
  depthbuffer: Pdepthbufferitem_tArray;
  dbsegs: array[0..(MAXWIDTH + DB_XMOD) div DB_XACCURACY] of TDPointerList;
  criticalx: array[0..(MAXWIDTH + DB_XMOD) div DB_XACCURACY] of boolean;
  ylookupdb: array[0..MAXHEIGHT] of Pdepthbufferitem_tArray;
  depthbufferactive: boolean;
  DBWIDTH, DBHEIGHT: integer;

function DB_Screen2DBx(const screenx: integer): integer; inline;
begin
  result := (screenx + DB_XMOD) div DB_XACCURACY;
  if result < 0 then
    result := 0
  else if result >= DBWIDTH then
    result := DBWIDTH - 1;
end;

function DB_Screen2DBy(const screeny: integer): integer; inline;
begin
  result := (screeny + DB_YMOD) div DB_YACCURACY;
  if result < 0 then
    result := 0
  else if result >= DBHEIGHT then
    result := DBHEIGHT - 1;
end;

procedure R_DrawSpanToDepthBuffer(const parms: Pspanparams_t);
var
  db: depthbufferitem_t;
  destl: Pdepthbufferitem_t;
  i: integer;
  dsx1, dsx2, dsy: integer;
begin
  if parms.ds_y mod DB_YACCURACY <> DB_YMOD then
    Exit;

  if parms.ds_y = centery then
    db.depth := 0
  else
    db.depth := Round(FRACUNIT / (parms.ds_planeheight / abs(centery - parms.ds_y)) * FRACUNIT);
  db.seg := nil;
  db.rendertype := RIT_FLAT;

  dsx1 := DB_Screen2DBx(parms.ds_x1);
  dsx2 := DB_Screen2DBx(parms.ds_x2);
  dsy := DB_Screen2DBy(parms.ds_y);
  destl := @((ylookupdb[dsy]^)[columnofs[dsx1]]);
  for i := dsx1 to dsx2 do
  begin
    destl^ := db;
    inc(destl);
  end;
end;

procedure R_DrawColumnToDepthBuffer(const parms: Pcolumnparams_t);
var
  db: depthbufferitem_t;
  destl: Pdepthbufferitem_t;
  i: integer;
  dcx, dcyl, dcyh: integer;
begin
  if parms.dc_x mod DB_XACCURACY <> DB_XMOD then
    Exit;

  db.depth := trunc((FRACUNIT / parms.dc_iscale) * FRACUNIT);
  db.seg := parms.seg;
  db.rendertype := parms.rendertype;

  dcx := DB_Screen2DBx(parms.dc_x);
  dcyl := DB_Screen2DBy(parms.dc_yl);
  dcyh := DB_Screen2DBy(parms.dc_yh);
  destl := @((ylookupdb[dcyl]^)[columnofs[dcx]]);
  for i := dcyl to dcyh do
  begin
    destl^ := db;
    inc(destl, DBWIDTH);
  end;
end;

function R_DepthBufferDepthAt(const x, y: integer): LongWord;
begin
  result := Pdepthbufferitem_t(@((ylookupdb[DB_Screen2DBy(y)]^)[columnofs[DB_Screen2DBx(x)]]))^.depth;
end;

function R_DepthBufferAt(const x, y: integer): Pdepthbufferitem_t;
begin
  result := Pdepthbufferitem_t(@((ylookupdb[DB_Screen2DBy(y)]^)[columnofs[DB_Screen2DBx(x)]]));
end;

procedure R_InitDepthBuffer;
var
  i: integer;
begin
  DBWIDTH := SCREENWIDTH div DB_XACCURACY;
  DBHEIGHT := SCREENHEIGHT div DB_YACCURACY;
  depthbuffer := mallocz((DBWIDTH + 1) * (DBHEIGHT + 1) * SizeOf(depthbufferitem_t));
  depthbufferactive := false;
  for i := 0 to DBWIDTH - 1 do
    dbsegs[i] := TDPointerList.Create;
end;

procedure R_ShutDownDepthBuffer;
var
  i: integer;
begin
  memfree(depthbuffer, (DBWIDTH + 1) * (DBHEIGHT + 1) * SizeOf(depthbufferitem_t));
  for i := 0 to DBWIDTH - 1 do
    dbsegs[i].Free;
end;

// Called in each render tic before we start depth buffer
var
  dlastviewwindowy: Integer = -1;
  dlastviewheight: Integer = -1;
  olddbaccuracymode: integer = 0;

procedure R_StartDepthBuffer;
var
  i: integer;
begin
  if depthbufferactive then
    exit;

  if (dlastviewwindowy <> viewwindowy) or (dlastviewheight <> viewheight) or (olddbaccuracymode <> lightmapaccuracymode) then
  begin
    if olddbaccuracymode <> lightmapaccuracymode then
    begin
      lightmapaccuracymode := lightmapaccuracymode mod NUMLIGHTMAPACCURACYMODES;
      olddbaccuracymode := lightmapaccuracymode;
      case lightmapaccuracymode of
        0: DB_YACCURACY := 5;
        1: DB_YACCURACY := 3;
        2: DB_YACCURACY := 2;
      else DB_YACCURACY := 1;
      end;
      DB_YMOD := DB_YACCURACY div 2;
    end;
    memfree(depthbuffer, (DBWIDTH + 1) * (DBHEIGHT + 1) * SizeOf(depthbufferitem_t));
    DBWIDTH := viewwidth div DB_XACCURACY;
    DBHEIGHT := viewheight div DB_YACCURACY;
    depthbuffer := mallocz((DBWIDTH + 1) * (DBHEIGHT + 1) * SizeOf(depthbufferitem_t));
    dlastviewwindowy := viewwindowy;
    dlastviewheight := viewheight;
    for i := 0 to DBHEIGHT do
      ylookupdb[i] := Pdepthbufferitem_tArray(@depthbuffer[i * DBWIDTH]);
  end;
  depthbufferactive := true;
end;

//
// R_CalcDepthBuffer
// Find critical columns (change of seg)
//
procedure R_CalcDepthBufferColumn(const px: PInteger);
var
  i: integer;
  pdb: Pdepthbufferitem_t;
  dcx, dcyl, dcyh: integer;
  seg: Pseg_t;
begin
  if px^ mod DB_XACCURACY <> DB_XMOD then
    Exit;

  dcx := DB_Screen2DBx(px^);
  if criticalx[dcx] then
    exit;

  dcyl := DB_Screen2DBy(0);
  dcyh := DB_Screen2DBy(viewheight);

  pdb := @((ylookupdb[dcyl]^)[columnofs[dcx]]);
  for i := dcyl to dcyh do
  begin
    if pdb.rendertype = RIT_SPRITE then
    begin
      criticalx[dcx - 1] := true;
      criticalx[dcx] := true;
      criticalx[dcx + 1] := true;
      exit;
    end;
    inc(pdb, DBWIDTH);
  end;

  pdb := @((ylookupdb[dcyl]^)[columnofs[dcx]]);
  seg := nil;
  for i := dcyl to dcyh do
  begin
    if pdb^.seg <> seg then
    begin
      seg := pdb^.seg;
      if dbsegs[dcx].IndexOf(seg) < 0 then
        dbsegs[dcx].AddItem(seg);
    end;
    inc(pdb, DBWIDTH);
  end;

end;

procedure R_CalcDepthBuffer;
var
  i: integer;
begin
  for i := 1 to DBWIDTH - 2 do
    criticalx[i] := false;
  // first and last are critical
  criticalx[0] := true;
  criticalx[DBWIDTH - 1] := true;

  // if we have more than 1 segs column is critical
  for i := 1 to DBWIDTH - 2 do
    if dbsegs[i].Count > 1 then
    begin
      criticalx[i - 1] := true;
      criticalx[i] := true;
      criticalx[i + 1] := true;
    end;

  for i := 1 to DBWIDTH - 1 do
    R_AddRenderTask(@R_CalcDepthBufferColumn, RF_CALCDEPTHBUFFERCOLUMNS, @i);

  R_RenderItemsMT(RF_CALCDEPTHBUFFERCOLUMNS, RIF_WAIT);

  // if we have different segs column is critical
  for i := 0 to DBWIDTH - 2 do
    if not criticalx[i] then
      if not dbsegs[i].HasSameContentWith(dbsegs[i + 1]) then
      begin
        criticalx[i] := true;
        criticalx[i + 1] := true;
      end;
end;

function R_DBCriticalX(const x: integer): boolean;
begin
  result := criticalx[DB_Screen2DBx(x)];
end;

procedure R_StopDepthBuffer;
var
  i: integer;
begin
  depthbufferactive := false;
  ZeroMemory(depthbuffer, (DBWIDTH + 1) * (DBHEIGHT + 1) * SizeOf(depthbufferitem_t));
  for i := 0 to DBWIDTH - 1 do
    dbsegs[i].FastClear;
end;

end.

