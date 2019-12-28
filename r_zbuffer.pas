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

unit r_zbuffer;

interface

uses
  doomdef,
  r_defs,
  r_draw_column,
  r_draw_span;

type
  zbufferitem_t = record
    start, stop: integer;
    depth: LongWord;
    seg: Pseg_t;
    rendertype: LongWord;
  end;
  Pzbufferitem_t = ^zbufferitem_t;
  zbufferitem_tArray = array[0..$FFFF] of zbufferitem_t;
  Pzbufferitem_tArray = ^zbufferitem_tArray;

  zbuffer_t = record
    items: Pzbufferitem_tArray;
    numitems: integer;
    numrealitems: integer;
  end;
  Pzbuffer_t = ^zbuffer_t;

var
  Zspans: array[0..MAXHEIGHT] of zbuffer_t;
  Zcolumns: array[0..MAXWIDTH] of zbuffer_t;

procedure R_DrawSpanToZBuffer(const parms: Pspanparams_t);

procedure R_DrawColumnToZBuffer(const parms: Pcolumnparams_t);

// Returns the z buffer value at (x, y) or screen
// Lower value means far away
// no z-buffer is sky (or render glitch) - we do not write o zbuffer in skycolfunc
function R_ZBufferAt(const x, y: integer): Pzbufferitem_t;

procedure R_InitZBuffer;

procedure R_ShutDownZBuffer;

procedure R_StartZBuffer;

procedure R_CalcZBuffer;

function R_ZGetCriticalX(const x: integer): boolean;

procedure R_ZSetCriticalX(const x: integer; const value: boolean);

procedure R_StopZBuffer;

implementation

uses
  d_fpc,
  m_fixed,
  r_draw,
  r_render,
  r_main;

var
  zcriticalx: array[0..MAXWIDTH] of boolean;

function R_NewZBufferItem(const Z: Pzbuffer_t): Pzbufferitem_t;
const
  GROWSTEP = 4;
begin
  if Z.numitems >= Z.numrealitems then
  begin
    realloc(Z.items, Z.numrealitems * SizeOf(zbufferitem_t), (Z.numrealitems + GROWSTEP) * SizeOf(zbufferitem_t));
    Z.numrealitems := Z.numrealitems + GROWSTEP;
  end;
  result := @Z.items[Z.numitems];
  inc(Z.numitems);
end;

procedure R_DrawSpanToZBuffer(const parms: Pspanparams_t);
var
  item: Pzbufferitem_t;
begin
  item := R_NewZBufferItem(@Zspans[parms.ds_y]);

  if parms.ds_y = centery then
    item.depth := 0
  else
    item.depth := Round(FRACUNIT / (parms.ds_planeheight / abs(centery - parms.ds_y)) * FRACUNIT);

  item.seg := nil;
  item.rendertype := RIT_FLAT;

  item.start := parms.ds_x1;
  item.stop := parms.ds_x2;
end;

procedure R_DrawColumnToZBuffer(const parms: Pcolumnparams_t);
var
  item: Pzbufferitem_t;
begin
  item := R_NewZBufferItem(@Zcolumns[parms.dc_x]);

  item.depth := trunc((FRACUNIT / parms.dc_iscale) * FRACUNIT);
  item.seg := parms.seg;
  item.rendertype := parms.rendertype;

  item.start := parms.dc_yl;
  item.stop := parms.dc_yh;
end;

var
  stubzitem: zbufferitem_t = (
    start: 0;
    stop: 0;
    depth: 0;
    seg: nil;
    rendertype: RIT_NONE;
  );

function R_ZBufferAt(const x, y: integer): Pzbufferitem_t;
var
  Z: Pzbuffer_t;
  pi, pistop: Pzbufferitem_t;
  maxdepth, depth: LongWord;
begin
  result := @stubzitem;
  maxdepth := 0;

  Z := @Zcolumns[x];
  pi := @Z.items[0];
  pistop := @Z.items[Z.numitems];
  while pi <> pistop do
  begin
    if (y >= pi.start) and (y <= pi.stop) then
    begin
      depth := pi.depth;
      if depth > maxdepth then
      begin
        result := pi;
        maxdepth := depth;
      end;
    end;
    inc(pi);
  end;

  if result.seg <> nil then
    exit;

  Z := @Zspans[y];
  pi := @Z.items[0];
  pistop := @Z.items[Z.numitems];
  while pi <> pistop do
  begin
    if (x >= pi.start) and (x <= pi.stop) then
    begin
      depth := pi.depth;
      if depth > maxdepth then
      begin
        result := pi;
        maxdepth := depth;
      end;
    end;
    inc(pi);
  end;
end;

procedure R_InitZBuffer;
begin
  ZeroMemory(@Zspans, SizeOf(Zspans));
  ZeroMemory(@Zcolumns, SizeOf(Zcolumns));
  ZeroMemory(@zcriticalx, SizeOf(zcriticalx));
end;

procedure R_ShutDownZBuffer;
var
  i: integer;
begin
  for i := 0 to MAXWIDTH do
    if Zcolumns[i].numrealitems > 0 then
    begin
      memfree(Zcolumns[i].items, Zcolumns[i].numrealitems * SizeOf(zbufferitem_t));
      Zcolumns[i].numrealitems := 0;
      Zcolumns[i].numitems := 0;
    end;

  for i := 0 to MAXHEIGHT do
    if Zspans[i].numrealitems > 0 then
    begin
      memfree(Zspans[i].items, Zspans[i].numrealitems * SizeOf(zbufferitem_t));
      Zspans[i].numrealitems := 0;
      Zspans[i].numitems := 0;
    end;
end;

procedure R_StartZBuffer;
begin
end;

function R_ZGetCriticalX(const x: integer): boolean;
begin
  result := zcriticalx[x];
end;

procedure R_ZSetCriticalX(const x: integer; const value: boolean);
begin
  zcriticalx[x] := value;
end;

//
// R_CalcZBuffer
// Find critical columns
//
procedure R_CalcZBufferColumn(const px: PInteger);
var
  i, j: integer;
  x: integer;
  A, B: Pzbufferitem_tArray;
  rt: LongWord;
begin
  x := px^;
  if zcriticalx[x] then
    exit;

  A := Zcolumns[x].items;
  B := Zcolumns[x + 1].items;
  for i := 0 to Zcolumns[x].numitems - 1 do
  begin
    rt := A[i].rendertype;

    // Check sprite outline & seg change
    for j := 0 to Zcolumns[x + 1].numitems - 1 do
    begin
      if (B[j].start <= A[i].stop) and (A[i].start <= B[j].stop) then // interval intersection check
      begin
        if (B[j].rendertype = RIT_SPRITE) <> (rt = RIT_SPRITE) then
        begin
          zcriticalx[x] := true;
          zcriticalx[x + 1] := true;
          exit; // done search
        end;
        if B[j].seg <> A[i].seg then
        begin
          zcriticalx[x] := true;
          zcriticalx[x + 1] := true;
          exit; // done search
        end;
      end;
    end;

    if rt = RIT_MASKEDWALL then
    begin
      zcriticalx[x] := true;
      continue; // continue search
    end;

  end;
end;

procedure R_CalcZBuffer;
var
  i: integer;
begin
  // first and last are critical
  zcriticalx[0] := true;
  zcriticalx[viewwidth - 1] := true;

  for i := 1 to viewwidth - 2 do
    R_AddRenderTask(@R_CalcZBufferColumn, RF_CALCDEPTHBUFFERCOLUMNS, @i);

  R_RenderItemsMT(RI_CALCDEPTHBUFFERCOLUMNS, RIF_WAIT);
end;

procedure R_StopZBuffer;
var
  i: integer;
begin
  for i := 0 to viewwidth do
    Zcolumns[i].numitems := 0;
  for i := 0 to viewheight do
    Zspans[i].numitems := 0;
  ZeroMemory(@zcriticalx, viewwidth * SizeOf(boolean));
end;

end.

