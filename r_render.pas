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

unit r_render;

interface

uses
  d_fpc;

const
  RF_WALL = 1;
  RF_SPAN = 2;
  RF_MASKED = 4;
  RF_DEPTHBUFFERWRITE = 8;
  RF_CALCDEPTHBUFFERCOLUMNS = 16;
  RF_LIGHT = 32;
  RF_LIGHTMAP = 64;
  RF_MIRRORBUFFER = 128;
  RF_GRAYSCALE = 256;
  RF_COLORSUBSAMPLING = 512;

const
  RI_WALL = 0;
  RI_DEPTHBUFFERWALL = 1;
  RI_SPAN = 2;
  RI_DEPTHBUFFERSPAN = 3;
  RI_MASKED = 4;
  RI_DEPTHBUFFERMASKED = 5;
  RI_CALCDEPTHBUFFERCOLUMNS = 6;
  RI_LIGHT = 7;
  RI_LIGHTMAP = 8;
  RI_MIRRORBUFFER = 9;
  RI_GRAYSCALE = 10;
  RI_COLORSUBSAMPLING = 11;
  RI_MAX = 12;

const
  RIF_WAIT = 0;
  RIF_NOWAIT = 1;

procedure R_InitRender;

procedure R_ShutDownRender;

procedure R_AddRenderTask(const proc: PPointerParmProcedure; const flags: LongWord; const parms: pointer);

// Wait all threads to stop
procedure R_RenderWaitMT;

// Render Tasks in Single Thread
procedure R_RenderItemsST(const rid: integer);

// Render Tasks in Multiple Threads
procedure R_RenderItemsMT(const rid: integer; const wait: integer);

procedure R_ClearRender(const id: integer = -1);

function R_ScheduleTask(const proc: PProcedure): integer;

procedure R_ExecutePendingTask(const id: integer);

procedure R_ExecutePendingTasks;

procedure R_WaitTask(const id: integer);

procedure R_WaitTasks;

implementation

uses
  i_threads,
  i_system,
  r_depthbuffer,
  r_draw,
  r_draw_column,
  r_draw_span,
  r_draw_light;

type
  renderitem_t = record
    proc: PPointerParmProcedure;
    flags: LongWord;
    id: integer;
    case integer of
      0: (params: pointer);
      1: (columnparams: columnparams_t);
      2: (spanparams: spanparams_t);
      3: (lightparams: lightparams_t);
      4: (iparam: integer);
  end;
  Prenderitem_t = ^renderitem_t;

  renderitem_tArray = array[0..$FFFF] of renderitem_t;
  Prenderitem_tArray = ^renderitem_tArray;

  renderitempool_t = record
    data: Prenderitem_tArray;
    numitems: integer;
    realnumitems: integer;
    intoffset: integer;
    pint: PInteger;
  end;
  Prenderitempool_t = ^renderitempool_t;

var
  ritems: array[RI_WALL..RI_MAX - 1] of renderitempool_t;

// JVAL: Max Rendering threads
const
  MAXRTHREADS = 256;
  MAXGPTHREADS = 8; // General purpose threads

var
  numrthreads: integer;
  r_threads: array[0..MAXRTHREADS - 1] of TDThread;
  r_gpthreads: array[0..MAXGPTHREADS - 1] of TDThread;

procedure R_InitRender;
var
  i: integer;
  r0: Prenderitem_t;
begin
  for i := RI_WALL to RI_MAX - 1 do
  begin
    ritems[i].data := nil;
    ritems[i].numitems := 0;
    ritems[i].realnumitems := 0;
  end;
  r0 := Prenderitem_t(0);
  ritems[RI_WALL].intoffset := -1;
  ritems[RI_WALL].pint := nil;
  ritems[RI_DEPTHBUFFERWALL].intoffset := -1;
  ritems[RI_DEPTHBUFFERWALL].pint := nil;
  ritems[RI_SPAN].intoffset := -1;
  ritems[RI_SPAN].pint := nil;
  ritems[RI_DEPTHBUFFERSPAN].intoffset := -1;
  ritems[RI_DEPTHBUFFERSPAN].pint := nil;
  ritems[RI_MASKED].intoffset := integer(@(r0^.columnparams.dc_x));
  ritems[RI_MASKED].pint := @viewwidth;
  ritems[RI_DEPTHBUFFERMASKED].intoffset := integer(@(r0^.columnparams.dc_x));
  ritems[RI_DEPTHBUFFERMASKED].pint := @viewwidth;
  ritems[RI_CALCDEPTHBUFFERCOLUMNS].intoffset := -1;
  ritems[RI_CALCDEPTHBUFFERCOLUMNS].pint := nil;
  ritems[RI_LIGHT].intoffset := integer(@(r0^.lightparams.dl_x));
  ritems[RI_LIGHT].pint := @viewwidth;
  ritems[RI_LIGHTMAP].intoffset := -1;
  ritems[RI_LIGHTMAP].pint := nil;
  ritems[RI_MIRRORBUFFER].intoffset := -1;
  ritems[RI_MIRRORBUFFER].pint := nil;
  ritems[RI_GRAYSCALE].intoffset := -1;
  ritems[RI_GRAYSCALE].pint := nil;
  ritems[RI_COLORSUBSAMPLING].intoffset := -1;
  ritems[RI_COLORSUBSAMPLING].pint := nil;

  numrthreads := I_GetNumCPUs;

  if numrthreads < 2 then
    numrthreads := 2;
  if numrthreads > MAXRTHREADS then
    numrthreads := MAXRTHREADS;
  for i := 0 to numrthreads - 1 do
    r_threads[i] := TDThread.Create;
  for i := 0 to MAXGPTHREADS - 1 do
    r_gpthreads[i] := TDThread.Create;
end;

procedure R_ShutDownRender;
var
  i: integer;
begin
  for i := RI_WALL to RI_MAX - 1 do
    memfree(ritems[i].data, ritems[i].realnumitems * SizeOf(renderitem_t));
  for i := 0 to numrthreads - 1 do
    r_threads[i].Free;
  for i := 0 to MAXGPTHREADS - 1 do
    r_gpthreads[i].Free;
end;

procedure R_AddRenderTaskId(const proc: PPointerParmProcedure; const flags: LongWord; id: integer; const parms: pointer);
const
  GROWSTEP = 256;
var
  item: Prenderitem_t;
  rip: Prenderitempool_t;
begin
  rip := @ritems[id];
  if rip.numitems >= rip.realnumitems then
  begin
    realloc(rip.data, rip.realnumitems * SizeOf(renderitem_t), (GROWSTEP + rip.realnumitems) * SizeOf(renderitem_t));
    rip.realnumitems := rip.realnumitems + GROWSTEP;
  end;
  item := @rip.data[rip.numitems];
  inc(rip.numitems);

  item.proc := proc;
  item.flags := flags;
  item.id := id;
  if flags and (RF_WALL or RF_MASKED) <> 0 then
    item.columnparams := Pcolumnparams_t(parms)^
  else if flags and RF_SPAN <> 0 then
    item.spanparams := Pspanparams_t(parms)^
  else if flags and RF_LIGHT <> 0 then
    item.lightparams := Plightparams_t(parms)^
  else if flags and (RF_LIGHTMAP or RF_MIRRORBUFFER or RF_CALCDEPTHBUFFERCOLUMNS or RF_GRAYSCALE or RF_COLORSUBSAMPLING) <> 0 then
    item.iparam := PInteger(parms)^
end;

procedure R_AddRenderTask(const proc: PPointerParmProcedure; const flags: LongWord; const parms: pointer);
begin
  if flags and RF_WALL <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_WALL, parms);
    if flags and RF_DEPTHBUFFERWRITE <> 0 then
      R_AddRenderTaskId(@R_DrawColumnToDepthBuffer, flags, RI_DEPTHBUFFERWALL, parms);
  end
  else if flags and RF_SPAN <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_SPAN, parms);
    if flags and RF_DEPTHBUFFERWRITE <> 0 then
      R_AddRenderTaskId(@R_DrawSpanToDepthBuffer, flags, RI_DEPTHBUFFERSPAN, parms);
  end
  else if flags and RF_MASKED <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_MASKED, parms);
    if flags and RF_DEPTHBUFFERWRITE <> 0 then
      R_AddRenderTaskId(@R_DrawColumnToDepthBuffer, flags, RI_DEPTHBUFFERMASKED, parms);
  end
  else if flags and RF_LIGHT <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_LIGHT, parms)
    // No depthbuffer write for light columns
  end
  else if flags and RF_LIGHTMAP <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_LIGHTMAP, parms)
    // No depthbuffer write for lightmap flash
  end
  else if flags and RF_MIRRORBUFFER <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_MIRRORBUFFER, parms)
    // No depthbuffer write for mirror effects
  end
  else if flags and RF_GRAYSCALE <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_GRAYSCALE, parms)
    // No depthbuffer write for grayscale effect
  end
  else if flags and RF_COLORSUBSAMPLING <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_COLORSUBSAMPLING, parms)
    // No depthbuffer write for color subsubling effect
  end
  else if flags and RF_CALCDEPTHBUFFERCOLUMNS <> 0 then
  begin
    R_AddRenderTaskId(proc, flags, RI_CALCDEPTHBUFFERCOLUMNS, parms)
  end;
end;

procedure R_RenderTask(const r: Prenderitem_t);
begin
  r.proc(@r.params);
end;

type
  range_t = record
    start, stop: integer;
    id: integer;
  end;
  Prange_t = ^range_t;

var
  ranges: array[0..MAXRTHREADS - 1] of range_t;

// For solid walls, floors & ceilings
function _render_task_range(p: pointer): integer; stdcall;
var
  i: integer;
  start, stop: integer;
  ria: Prenderitem_tArray;
begin
  ria := ritems[Prange_t(p).id].data;
  start := Prange_t(p).start;
  stop := Prange_t(p).stop;
  for i := start to stop do
    R_RenderTask(@ria[i]);
  result := 0;
end;

// For things, light and lighmap
function _render_task_index(p: pointer): integer; stdcall;
var
  i: integer;
  ri: Prenderitem_t;
  start, stop: integer;
  ofs, check: integer;
  rip: Prenderitempool_t;
  ria: Prenderitem_tArray;
begin
  rip := @ritems[Prange_t(p).id];
  ofs := rip.intoffset;
  ria := rip.data;
  start := Prange_t(p).start;
  stop := Prange_t(p).stop;
  for i := 0 to rip.numitems - 1 do
  begin
    ri := @ria[i];
    check := PInteger(@PByteArray(ri)[ofs])^;
    if check >= start then
      if check <= stop then
        R_RenderTask(ri);
  end;
  result := 0;
end;

// Wait all threads to stop
procedure R_RenderWaitMT;
var
  i: integer;
begin
  for i := 0 to numrthreads - 1 do
    r_threads[i].Wait;
end;

// Render Tasks in Single Thread
procedure R_RenderItemsST(const rid: integer);
var
  i: integer;
begin
  for i := 0 to ritems[rid].numitems - 1 do
    R_RenderTask(@ritems[rid].data[i]);
end;

// Render Tasks in Multiple Threads
procedure R_RenderItemsMT(const rid: integer; const wait: integer);
var
  i: integer;
  nt: integer;
  tfunc: threadfunc_t;
  rip: Prenderitempool_t;
begin
  R_RenderWaitMT;

  rip := @ritems[rid];
  if wait = RIF_WAIT then
    nt := numrthreads
  else
    nt := numrthreads - 1;
  if nt > rip.numitems then
    nt := rip.numitems;
  if nt = 0 then
    Exit;

  if rip.intoffset < 0 then
  begin
    ranges[0].start := 0;
    for i := 1 to nt - 1 do
      ranges[i].start := round(i * rip.numitems / nt);
    for i := 0 to nt - 2 do
      ranges[i].stop := ranges[i + 1].start - 1;
    ranges[nt - 1].stop := rip.numitems - 1;

    tfunc := @_render_task_range;
  end
  else
  begin
    ranges[0].start := 0;
    for i := 1 to nt - 1 do
      ranges[i].start := round(i * rip.pint^ / nt);
    for i := 0 to nt - 2 do
      ranges[i].stop := ranges[i + 1].start - 1;
    ranges[nt - 1].stop := rip.pint^ - 1;

    tfunc := @_render_task_index;
  end;

  for i := 0 to nt - 1 do
    ranges[i].id := rid;

  if wait = RIF_WAIT then
  begin
    for i := 0 to nt - 2 do
      r_threads[i].Activate(tfunc, @ranges[i]);

    tfunc(@ranges[nt - 1]);

    R_RenderWaitMT;
  end
  else
  begin
    for i := 0 to nt - 1 do
      r_threads[i].Activate(tfunc, @ranges[i]);
  end;
end;

procedure R_ClearRender(const id: integer = -1);
var
  i: integer;
begin
  if id = -1 then
  begin
    for i := RI_WALL to RI_MAX - 1 do
      ritems[i].numitems := 0;
  end
  else
    ritems[id].numitems := 0;
end;

type
  taskinfo_t = record
    id: integer;
    proc: PProcedure;
  end;
  Ptaskinfo_t = ^taskinfo_t;

var
  tasks: array[0..MAXGPTHREADS - 1] of taskinfo_t;

function _render_task(p: pointer): integer; stdcall;
var
  pt: Ptaskinfo_t;
begin
  pt := p;
  pt.proc;
  result := pt.id;
  pt.id := -1;
  pt.proc := nil;
end;

function R_ScheduleTask(const proc: PProcedure): integer;
var
  i: integer;
begin
  for i := 0 to MAXGPTHREADS - 1 do
    if not Assigned(tasks[i].proc) then
    begin
      tasks[i].id := i;
      tasks[i].proc := proc;
      result := i;
      exit;
    end;
  proc;
  result := -1;
end;

procedure R_ExecutePendingTask(const id: integer);
begin
  if Assigned(tasks[id].proc) then
    r_gpthreads[id].Activate(_render_task, @tasks[id]);
end;

procedure R_ExecutePendingTasks;
var
  i: integer;
begin
  for i := 0 to MAXGPTHREADS - 1 do
    if Assigned(tasks[i].proc) then
      r_gpthreads[i].Activate(_render_task, @tasks[i]);
end;


procedure R_WaitTask(const id: integer);
begin
  if (id < 0) or (id >= MAXGPTHREADS) then
    exit;
  if Assigned(tasks[id].proc) then
    r_gpthreads[id].Wait;
end;

procedure R_WaitTasks;
var
  i: integer;
begin
  for i := 0 to MAXGPTHREADS - 1 do
    if Assigned(tasks[i].proc) then
      r_gpthreads[i].Wait;
end;

end.

