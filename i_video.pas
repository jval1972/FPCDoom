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

unit i_video;

interface

uses
  SysUtils,
  Windows,
  d_fpc;

//==============================================================================
//
// I_DetectNativeScreenResolution
//
//==============================================================================
procedure I_DetectNativeScreenResolution;

//==============================================================================
// I_InitGraphics
//
// Called by D_DoomMain,
// determines the hardware configuration
// and sets up the video mode
//
//==============================================================================
procedure I_InitGraphics;

//==============================================================================
//
// I_ChangeFullScreen
//
//==============================================================================
procedure I_ChangeFullScreen(const dofull, doexclusive: boolean);

//==============================================================================
//
// I_ShutDownGraphics
//
//==============================================================================
procedure I_ShutDownGraphics;

//==============================================================================
// I_SetPalette
//
// Takes full 8 bit values.
//
//==============================================================================
procedure I_SetPalette(const palette: PByteArray);

//==============================================================================
//
// I_FinishUpdate
//
//==============================================================================
procedure I_FinishUpdate;

//==============================================================================
//
// I_ReadScreen32
//
//==============================================================================
procedure I_ReadScreen32(dest: pointer);

//==============================================================================
//
// I_RestoreWindowPos
//
//==============================================================================
procedure I_RestoreWindowPos(const fs: Boolean);

var
  fixstallhack: boolean = true;

type
  displaymode_t = record
    width, height: integer;
    bpp: integer;
  end;
  displaymode_tArray = array[0..$FF] of displaymode_t;
  Pdisplaymode_tArray = ^displaymode_tArray;

var
  displaymodes: Pdisplaymode_tArray = nil;
  numdisplaymodes: integer = 0;

//==============================================================================
//
// I_DisplayModeIndex
//
//==============================================================================
function I_DisplayModeIndex(const w, h: integer): integer;

//==============================================================================
//
// I_NearestDisplayModeIndex
//
//==============================================================================
function I_NearestDisplayModeIndex(const w, h: integer): integer;

var
  vid_pillarbox_pct: integer;
  vid_letterbox_pct: integer;

const
  PILLARLETTER_MIN = 0;
  PILLARLETTER_MAX = 50;

implementation

uses
  doomdef,
  DirectX,
  i_system,
  i_main,
  i_input,
  r_hires,
  v_video;

var
  g_pDD: IDirectDraw7 = nil;                // DirectDraw object
  g_pDDSPrimary: IDirectDrawSurface7 = nil; // DirectDraw primary surface
  g_pDDScreen: IDirectDrawSurface7 = nil;   // DirectDraw surface
  g_pDDClipper: IDirectDrawClipper = nil;   // Clipper

var
  bpp: integer;

var
  s_alttab_disabled: boolean = false;

var
  screen16: PWordArray;
  screen: PLongWordArray;
  oscreen: pointer;

//==============================================================================
//
// I_GetWindowClientOffset
//
//==============================================================================
procedure I_GetWindowClientOffset(var dw, dh: integer);
var
  rw, rc: TRect;
begin
  GetClientRect(hMainWnd, rc);
  GetWindowRect(hMainWnd, rw);
  dw := (rw.Right - rw.Left) - (rc.Right - rc.Left);
  dh := (rw.Bottom - rw.Top) - (rc.Bottom - rc.Top);
end;

//==============================================================================
//
// I_GetWindowOffset
//
//==============================================================================
procedure I_GetWindowOffset(var dw, dh: integer);
var
  rw, rc: TRect;
  border: integer;
begin
  GetClientRect(hMainWnd, rc);
  GetWindowRect(hMainWnd, rw);
  border := ((rw.Right - rw.Left) - (rc.Right - rc.Left)) div 2;
  dw := rw.Right - rc.Right - border;
  dh := rw.Bottom - rc.Bottom - border;
end;

//==============================================================================
//
// I_GetWindowPosition
//
//==============================================================================
procedure I_GetWindowPosition(var dw, dh: integer);
var
  rw: TRect;
begin
  GetWindowRect(hMainWnd, rw);
  dw := rw.Left;
  dh := rw.Top;
end;

//==============================================================================
//
// I_RestoreWindowPos
//
//==============================================================================
procedure I_RestoreWindowPos(const fs: Boolean);
var
  dw, dh: integer;
begin
  if fs then
  begin
    SetWindowLong(hMainWnd, GWL_STYLE, WINDOW_STYLE_FS);
    SetWindowPos(hMainWnd, HWND_NOTOPMOST, 0, 0, WINDOWWIDTH, WINDOWHEIGHT, SWP_SHOWWINDOW);
  end
  else
  begin
    SetWindowLong(hMainWnd, GWL_STYLE, WINDOW_STYLE_W);
    SetWindowPos(hMainWnd, HWND_NOTOPMOST, windowxpos, windowypos, WINDOWWIDTH, WINDOWHEIGHT, SWP_SHOWWINDOW);
    I_GetWindowClientOffset(dw, dh);
    SetWindowPos(hMainWnd, HWND_NOTOPMOST, windowxpos, windowypos, WINDOWWIDTH + dw, WINDOWHEIGHT + dh, SWP_SHOWWINDOW);
  end;
end;

//==============================================================================
//
// I_SetClipper
//
//==============================================================================
procedure I_SetClipper(const fs: boolean);
begin
  if fs then
    g_pDDSPrimary.SetClipper(nil)
  else
    g_pDDSPrimary.SetClipper(g_pDDClipper);
end;

//==============================================================================
//
// I_DisableAltTab
//
//==============================================================================
procedure I_DisableAltTab;
var
  old: Boolean;
begin
  if s_alttab_disabled then
    Exit;

  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
    if isLibrary then
      RegisterHotKey(0, $C000, MOD_ALT, VK_TAB)
    else
      RegisterHotKey(0, 0, MOD_ALT, VK_TAB)
  end
  else
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, 1, @old, 0);

  s_alttab_disabled := true;
end;

//==============================================================================
//
// I_EnableAltTab
//
//==============================================================================
procedure I_EnableAltTab;
var
  old: Boolean;
begin
  if s_alttab_disabled then
  begin
    if Win32Platform = VER_PLATFORM_WIN32_NT then
    begin
      if isLibrary then
        UnregisterHotKey(0, $C000)
      else
        UnregisterHotKey(0, 0)
    end
    else
      SystemParametersInfo(SPI_SCREENSAVERRUNNING, 0, @old, 0);

    s_alttab_disabled := false;
  end;
end;

var
  allocscreensize: integer;

//==============================================================================
//
// I_ShutDownGraphics
//
//==============================================================================
procedure I_ShutDownGraphics;
begin
  I_ClearInterface(IInterface(g_pDDScreen));
  I_ClearInterface(IInterface(g_pDDSPrimary));
  I_ClearInterface(IInterface(g_pDD));
  I_ClearInterface(IInterface(g_pDDClipper));

  I_EnableAltTab;
  {$IFNDEF FPC}displaymodes := {$ENDIF}realloc(displaymodes, numdisplaymodes * SizeOf(displaymode_t), 0);
  numdisplaymodes := 0;
  memfree(oscreen, allocscreensize);
  if screen16 <> nil then
    memfree(screen16, SCREENWIDTH * SCREENHEIGHT * 2);
end;

var
  stallhack: boolean;

type
  finishupdateparms_t = record
    start, stop: integer;
  end;
  Pfinishupdateparms_t = ^finishupdateparms_t;

//==============================================================================
// I_FinishUpdate8
//
// I_FinishUpdate
//
//==============================================================================
procedure I_FinishUpdate8(parms: Pfinishupdateparms_t);
var
  destl: PLongWord;
  destw: PWord;
  pixel: LongWord;
  r, g, b: LongWord;
  src: PByte;
  srcstop: PByte;
begin
  src := @(screens[SCN_FG][parms.start]);
  srcstop := @(screens[SCN_FG][parms.stop]);
  if bpp = 32 then
  begin
    destl := @screen[parms.start];
    while PCAST(src) < PCAST(srcstop) do
    begin
      destl^ := curpal[src^];
      inc(destl);
      inc(src);
    end;
  end
  else if bpp = 16 then
  begin
    destw := @screen16[parms.start];
    while PCAST(src) < PCAST(srcstop) do
    begin
      pixel := curpal[src^];
      r := (pixel shr 19) and 31;
      g := (pixel shr 11) and 31;
      b := (pixel shr 3) and 31;
      destw^ := (r shl 11) or (g shl 6) or b;
      inc(destw);
      inc(src);
    end;
  end;
end;

//==============================================================================
//
// I_FinishUpdate16
//
//==============================================================================
procedure I_FinishUpdate16;
var
  i: integer;
  destw: PWord;
  pixel: LongWord;
  r, g, b: LongWord;
  srcl: PLongWord;
begin
  destw := @screen16[0];
  srcl := @screen[0];
  for i := 0 to SCREENWIDTH * SCREENHEIGHT - 1 do
  begin
    pixel := srcl^;
    r := (pixel shr 19) and 31;
    g := (pixel shr 11) and 31;
    b := (pixel shr 3) and 31;
    destw^ := (r shl 11) or (g shl 6) or b;
    inc(destw);
    inc(srcl);
  end;
end;

var
  oldstretch: boolean = false;
  old_pillarbox_pct: integer = -1;
  old_letterbox_pct: integer = -1;
  old_windowwidth: integer = -1;
  old_windowheight: integer = -1;
  old_fullscreen: boolean = false;
  old_fullscreenexclusive: boolean = false;

//==============================================================================
//
// I_FinishUpdate
//
//==============================================================================
procedure I_FinishUpdate;
var
  srcrect: TRect;
  destrect: TRect;
  blackrect: TRect;
  oldcolor: LongWord;
  parms1: finishupdateparms_t;
  stretch: boolean;
  hpan, vpan: integer;
  dw, dh: integer;
begin
  if (hMainWnd = 0) or (screens[SCN_FG] = nil) or (screen32 = nil) then
    exit;

  if videomode = vm32bit then
  begin
    if bpp = 16 then
    begin
    // JVAL
    // Internal hi-color rendering engine works in 32 bits
    // If we have a 16 bit depth desktop we get a bit slower performance ....
      I_FinishUpdate16;
    end;
    // if bpp = 32 <- we don't do nothing, directly drawing was performed
  end
  else
  begin
    parms1.start := 0;
    parms1.stop := SCREENWIDTH * SCREENHEIGHT - 1;
    I_FinishUpdate8(@parms1);
  end;

  vid_pillarbox_pct := ibetween(vid_pillarbox_pct, PILLARLETTER_MIN, PILLARLETTER_MAX);
  vid_letterbox_pct := ibetween(vid_letterbox_pct, PILLARLETTER_MIN, PILLARLETTER_MAX);

  srcrect.Left := 0;
  srcrect.Top := 0;
  srcrect.Right := SCREENWIDTH;
  srcrect.Bottom := SCREENHEIGHT;

  stretch := stallhack and fixstallhack and (WINDOWHEIGHT = SCREENHEIGHT);
  if not stretch then
    stretch := (WINDOWWIDTH <> SCREENWIDTH) or (WINDOWHEIGHT <> SCREENHEIGHT) or
               (vid_pillarbox_pct <> 0) or (vid_letterbox_pct <> 0) or
               (fullscreen <> old_fullscreen) or (fullscreenexclusive <> old_fullscreenexclusive);

  if stretch or not fullscreen then
  begin
    hpan := Trunc(vid_pillarbox_pct * WINDOWWIDTH / 100 / 2);
    vpan := Trunc(vid_letterbox_pct * WINDOWHEIGHT / 100 / 2);

    if not oldstretch or
      (vid_pillarbox_pct <> old_pillarbox_pct) or
      (vid_letterbox_pct <> old_letterbox_pct) or
      (old_windowwidth <> WINDOWWIDTH) or
      (old_windowheight <> WINDOWHEIGHT) or
      (fullscreen <> old_fullscreen) or (fullscreenexclusive <> old_fullscreenexclusive) then
    begin
      if bpp = 16 then
      begin
        oldcolor := screen16[0];
        screen16[0] := 0;
      end
      else
      begin
        oldcolor := screen32[0];
        screen32[0] := 0;
      end;

      blackrect.Left := 0;
      blackrect.Top := 0;
      blackrect.Right := 1;
      blackrect.Bottom := 1;

      if hpan <> 0 then
      begin
        destrect.Left := 0;
        destrect.Top := 0;
        destrect.Right := hpan;
        destrect.Bottom := WINDOWHEIGHT;

        if g_pDDSPrimary.Blt(destrect, g_pDDScreen, blackrect, DDBLTFAST_DONOTWAIT or DDBLTFAST_NOCOLORKEY, PDDBltFX(0)^) = DDERR_SURFACELOST then
          g_pDDSPrimary.Restore;

        destrect.Left := WINDOWWIDTH - hpan;
        destrect.Top := 0;
        destrect.Right := WINDOWWIDTH;
        destrect.Bottom := WINDOWHEIGHT;

        if g_pDDSPrimary.Blt(destrect, g_pDDScreen, blackrect, DDBLTFAST_DONOTWAIT or DDBLTFAST_NOCOLORKEY, PDDBltFX(0)^) = DDERR_SURFACELOST then
          g_pDDSPrimary.Restore;
      end;

      if vpan <> 0 then
      begin
        destrect.Left := hpan;
        destrect.Top := 0;
        destrect.Right := WINDOWWIDTH - hpan;
        destrect.Bottom := vpan;

        if g_pDDSPrimary.Blt(destrect, g_pDDScreen, blackrect, DDBLTFAST_DONOTWAIT or DDBLTFAST_NOCOLORKEY, PDDBltFX(0)^) = DDERR_SURFACELOST then
          g_pDDSPrimary.Restore;

        destrect.Left := hpan;
        destrect.Top := WINDOWHEIGHT - vpan;
        destrect.Right := WINDOWWIDTH - hpan;
        destrect.Bottom := WINDOWHEIGHT;

        if g_pDDSPrimary.Blt(destrect, g_pDDScreen, blackrect, DDBLTFAST_DONOTWAIT or DDBLTFAST_NOCOLORKEY, PDDBltFX(0)^) = DDERR_SURFACELOST then
          g_pDDSPrimary.Restore;
      end;

      if bpp = 16 then
        screen16[0] := oldcolor
      else
        screen32[0] := oldcolor;

      oldstretch := true;
      old_pillarbox_pct := vid_pillarbox_pct;
      old_letterbox_pct := vid_letterbox_pct;
      old_windowwidth := WINDOWWIDTH;
      old_windowheight := WINDOWHEIGHT;
      old_fullscreen := fullscreen;
      old_fullscreenexclusive := fullscreenexclusive;
    end;

    destrect.Left := hpan;
    destrect.Top := vpan;
    destrect.Right := WINDOWWIDTH - hpan;
    destrect.Bottom := WINDOWHEIGHT - vpan;

    if not fullscreen then
    begin
      I_GetWindowPosition(windowxpos, windowypos);
      I_GetWindowOffset(dw, dh);
      Inc(destrect.Left, dw);
      Inc(destrect.Right, dw);
      Inc(destrect.Top, dh);
      Inc(destrect.Bottom, dh);
    end;

    if g_pDDSPrimary.Blt(destrect, g_pDDScreen, srcrect, DDBLTFAST_DONOTWAIT or DDBLTFAST_NOCOLORKEY, PDDBltFX(0)^) = DDERR_SURFACELOST then
      g_pDDSPrimary.Restore;

  end
  else
  begin
    if g_pDDSPrimary.BltFast(0, 0, g_pDDScreen, srcrect, DDBLTFAST_DONOTWAIT or DDBLTFAST_NOCOLORKEY) = DDERR_SURFACELOST then
      g_pDDSPrimary.Restore;
    oldstretch := false;
  end;
end;

//==============================================================================
//
// Palette stuff.
//
// I_SetPalette
//
//==============================================================================
procedure I_SetPalette(const palette: PByteArray);
var
  dest: PLongWord;
  src: PByteArray;
  curgamma: PByteArray;
begin
  dest := @curpal[0];
  src := palette;
  curgamma := @gammatable[usegamma];
  while PCAST(src) < PCAST(@palette[256 * 3]) do
  begin
    dest^ := (LongWord(curgamma[src[0]]) shl 16) or
             (LongWord(curgamma[src[1]]) shl 8) or
             (LongWord(curgamma[src[2]]));
    inc(dest);
    src := pOp(src, 3);
  end;
end;

//==============================================================================
//
// I_AdjustWindowMode
//
//==============================================================================
function I_AdjustWindowMode: boolean;
begin
  result := false;
  if WINDOWWIDTH > NATIVEWIDTH then
  begin
    WINDOWWIDTH := NATIVEWIDTH;
    result := true;
  end;
  if WINDOWHEIGHT > NATIVEHEIGHT then
  begin
    WINDOWHEIGHT := NATIVEHEIGHT;
    result := true;
  end;
end;

//==============================================================================
//
// I_MemoryStallHack
//
//==============================================================================
function I_MemoryStallHack: boolean;
// JVAL: Memory stall can dramatically reduce performance in inc operation of
// esi register of value 4096 etc
// e.g.
//  mov [esp], 4096 (=SCREENWIDTH(=1024) * SizeOf(LongWord)(=4)
//  add esi, [esp]
// The above code is dramatically slower than:
//  mov [esp], 4088 (=SCREENWIDTH(=1022) * SizeOf(LongWord)(=4)
//  add esi, [esp]
// It's crazy!
begin
  if (SCREENWIDTH = 1024) or (SCREENWIDTH = 1152) or (SCREENWIDTH = 1280) then
  begin
    dec(SCREENWIDTH, 2);
    stallhack := true;
  end
  else
    stallhack := false;
  result := stallhack;
end;

//==============================================================================
//
// SortDisplayModes
//
//==============================================================================
procedure SortDisplayModes;

  function sortvalue(const idx: integer): double;
  begin
    result := displaymodes[idx].width + displaymodes[idx].height / 1000000
  end;

  procedure qsort(l, r: Integer);
  var
    i, j: Integer;
    tmp: displaymode_t;
    rover: double;
  begin
    repeat
      i := l;
      j := r;
      rover := sortvalue((l + r) shr 1);
      repeat
        while sortvalue(i) < rover do
          inc(i);
        while sortvalue(j) > rover do
          dec(j);
        if i <= j then
        begin
          tmp := displaymodes[i];
          displaymodes[i] := displaymodes[j];
          displaymodes[j] := tmp;
          inc(i);
          dec(j);
        end;
      until i > j;
      if l < j then
        qsort(l, j);
      l := i;
    until i >= r;
  end;

begin
  if numdisplaymodes > 0 then
    qsort(0, numdisplaymodes - 1);
end;

//==============================================================================
//
// I_DisplayModeIndex
//
//==============================================================================
function I_DisplayModeIndex(const w, h: integer): integer;
var
  i: integer;
begin
  result := -1;

  if displaymodes = nil then
    exit;

  for i := 0 to numdisplaymodes - 1 do
    if (displaymodes[i].width = w) and (displaymodes[i].height = h) then
    begin
      result := i;
      exit;
    end;
end;

//==============================================================================
//
// I_NearestDisplayModeIndex
//
//==============================================================================
function I_NearestDisplayModeIndex(const w, h: integer): integer;
var
  i: integer;
  dist: double;
  mindist: double;
begin
  result := I_DisplayModeIndex(w, h);
  if result >= 0 then
    exit;

  mindist := 1000000000000.0;
  for i := 0 to numdisplaymodes - 1 do
  begin
    dist := sqrt(sqr(displaymodes[i].width - SCREENWIDTH) + sqr(displaymodes[i].height - SCREENHEIGHT));
    if SCREENWIDTH < displaymodes[i].width then
      dist := dist + 50.0;
    if SCREENHEIGHT < displaymodes[i].height then
      dist := dist + 50.0;
    if dist < mindist then
    begin
      mindist := dist;
      result := i;
    end;
  end;
end;

//==============================================================================
//
// IsAvailableScreenResolution
//
//==============================================================================
function IsAvailableScreenResolution(const w, h: integer): boolean;
begin
  result := I_DisplayModeIndex(w, h) >= 0;
end;

//==============================================================================
//
// I_EnumDisplayModes
//
//==============================================================================
procedure I_EnumDisplayModes;
var
  dm: TDevMode;
  i: integer;
begin
  if displaymodes <> nil then
    memfree(displaymodes, numdisplaymodes * SizeOf(displaymode_t));

  numdisplaymodes := 0;
  i := 0;
  while EnumDisplaySettings(nil, i, dm) do
  begin
    if (dm.dmPelsWidth >= 320) and (dm.dmPelsHeight >= 200) and (dm.dmBitsPerPel = 32) and not IsAvailableScreenResolution(dm.dmPelsWidth, dm.dmPelsHeight) then
    begin
      {$IFNDEF FPC}displaymodes := {$ENDIF}realloc(displaymodes, numdisplaymodes * SizeOf(displaymode_t), (numdisplaymodes + 1) * SizeOf(displaymode_t));
      displaymodes[numdisplaymodes].width := dm.dmPelsWidth;
      displaymodes[numdisplaymodes].height := dm.dmPelsHeight;
      displaymodes[numdisplaymodes].bpp := dm.dmBitsPerPel;
      inc(numdisplaymodes);
    end;
    Inc(i);
  end;
  if numdisplaymodes = 0 then
  begin
    while EnumDisplaySettings(nil, i, dm) do
    begin
      if (dm.dmPelsWidth >= 640) and (dm.dmPelsHeight >= 400) and (dm.dmBitsPerPel >= 16) and not IsAvailableScreenResolution(dm.dmPelsWidth, dm.dmPelsHeight) then
      begin
        {$IFNDEF FPC}displaymodes := {$ENDIF}realloc(displaymodes, numdisplaymodes * SizeOf(displaymode_t), (numdisplaymodes + 1) * SizeOf(displaymode_t));
        displaymodes[numdisplaymodes].width := dm.dmPelsWidth;
        displaymodes[numdisplaymodes].height := dm.dmPelsHeight;
        displaymodes[numdisplaymodes].bpp := dm.dmBitsPerPel;
        inc(numdisplaymodes);
      end;
      Inc(i);
    end;
  end;
  if numdisplaymodes = 0 then
  begin
    displaymodes := malloc(SizeOf(displaymode_t));
    displaymodes[0].width := 320;
    displaymodes[0].height := 200;
    displaymodes[0].bpp := 32;
    displaymodes[1].width := 640;
    displaymodes[1].height := 400;
    displaymodes[1].bpp := 32;
    numdisplaymodes := 2;
  end;

  SortDisplayModes;
end;

//==============================================================================
//
// I_DoFindWindowSize
//
//==============================================================================
procedure I_DoFindWindowSize(const dofull, doexclusive: boolean);
var
  i: integer;
  dist: double;
  mindist: double;
  idx: integer;
begin
  if dofull and not doexclusive then
  begin
    WINDOWWIDTH := NATIVEWIDTH;
    WINDOWHEIGHT := NATIVEHEIGHT;
    exit;
  end;

  if not dofull then
  begin
    WINDOWWIDTH := SCREENWIDTH;
    WINDOWHEIGHT := SCREENHEIGHT;
    exit;
  end;

  for i := 0 to numdisplaymodes - 1 do
    if displaymodes[i].width = SCREENWIDTH then
      if displaymodes[i].height = SCREENHEIGHT then
      begin
        WINDOWWIDTH := SCREENWIDTH;
        WINDOWHEIGHT := SCREENHEIGHT;
        exit;
      end;

  mindist := 1000000000000.0;
  idx := -1;
  for i := 0 to numdisplaymodes - 1 do
  begin
    dist := sqrt(sqr(displaymodes[i].width - SCREENWIDTH) + sqr(displaymodes[i].height - SCREENHEIGHT));
    if SCREENWIDTH < displaymodes[i].width then
      dist := dist + 50.0;
    if SCREENHEIGHT < displaymodes[i].height then
      dist := dist + 50.0;
    if dist < mindist then
    begin
      mindist := dist;
      idx := i;
    end;
  end;

  if idx >= 0 then
  begin
    WINDOWWIDTH := displaymodes[idx].width;
    WINDOWHEIGHT := displaymodes[idx].height;
    exit;
  end;

  WINDOWWIDTH := NATIVEWIDTH;
  WINDOWHEIGHT := NATIVEHEIGHT;
end;

//==============================================================================
//
// I_FindWindowSize
//
//==============================================================================
procedure I_FindWindowSize(const dofull, doexclusive: boolean);
begin
  I_DoFindWindowSize(dofull, doexclusive);
  printf('I_FindWindowSize: Set window size at (%d, %d)'#13#10, [WINDOWWIDTH, WINDOWHEIGHT]);
end;

//==============================================================================
//
// I_DetectNativeScreenResolution
//
//==============================================================================
procedure I_DetectNativeScreenResolution;
begin
  NATIVEWIDTH := GetSystemMetrics(SM_CXSCREEN);
  NATIVEHEIGHT := GetSystemMetrics(SM_CYSCREEN);
end;

var
  isexclusive: boolean = false;

//==============================================================================
//
// I_SetCooperativeLevel
//
//==============================================================================
function I_SetCooperativeLevel(const exclusive: boolean): HResult;
begin
  if exclusive then
    result := g_pDD.SetCooperativeLevel(hMainWnd, DDSCL_ALLOWMODEX or DDSCL_EXCLUSIVE or DDSCL_FULLSCREEN)
  else
    result := g_pDD.SetCooperativeLevel(hMainWnd, DDSCL_NORMAL);
  isexclusive := exclusive;
end;

const
  ERROR_OFFSET = 20;

//==============================================================================
// I_InitGraphics
//
// Called by D_DoomMain,
// determines the hardware configuration
// and sets up the video mode
//
//==============================================================================
procedure I_InitGraphics;
var
  hres: HRESULT;
  ddsd: DDSURFACEDESC2;

  procedure I_ErrorInitGraphics(const procname: string);
  begin
    I_Error('I_InitGraphics(): %s failed, result = %d', [procname, hres]);
  end;

begin
  if g_pDD <> nil then
    exit;

  printf('I_InitGraphics: Initialize directdraw.' + #13#10);

  I_EnumDisplayModes;

///////////////////////////////////////////////////////////////////////////
// Create the main DirectDraw object
///////////////////////////////////////////////////////////////////////////
  hres := DirectDrawCreateEx(nil, g_pDD, IID_IDirectDraw7, nil);
  if hres <> DD_OK then
    I_ErrorInitGraphics('DirectDrawCreateEx');

///////////////////////////////////////////////////////////////////////////
// Create the clipper using the DirectDraw object
///////////////////////////////////////////////////////////////////////////
  hres := g_pDD.CreateClipper(0, g_pDDClipper, nil);
  if hres <> DD_OK then
    I_ErrorInitGraphics('CreateClipper');
///////////////////////////////////////////////////////////////////////////
// Assign your window's HWND to the clipper
///////////////////////////////////////////////////////////////////////////
  hres := g_pDDClipper.SetHWnd(0, hMainWnd);
  if hres <> DD_OK then
    I_ErrorInitGraphics('g_pDDClipper.SetHWnd');

  if fullscreen then
  begin
    I_FindWindowSize(true, fullscreenexclusive);

    // Get exclusive mode
    hres := I_SetCooperativeLevel(fullscreenexclusive);

    if hres <> DD_OK then
      I_ErrorInitGraphics('SetCooperativeLevel');

    if fullscreenexclusive then
    begin
      // Set the video mode to WINDOWWIDTH x WINDOWHEIGHT x 32
      hres := g_pDD.SetDisplayMode(WINDOWWIDTH, WINDOWHEIGHT, 32, 0, 0);
      if hres <> DD_OK then
      begin
      // Fullscreen mode failed, trying window mode
        fullscreen := false;

        I_AdjustWindowMode;
        I_RestoreWindowPos(fullscreen);

        I_Warning('SetDisplayMode(): Failed to fullscreen %dx%dx%d, trying window mode...'#13#10,
          [WINDOWWIDTH, WINDOWHEIGHT, 32]);
        printf('Window Mode %dx%d' + #13#10, [WINDOWWIDTH, WINDOWHEIGHT]);

        hres := I_SetCooperativeLevel(false);
        if hres <> DD_OK then
        begin
          I_Warning('SetDisplayMode(): Failed to window mode %dx%d...' + #13#10, [WINDOWWIDTH, WINDOWHEIGHT]);
          WINDOWWIDTH := 640;
          WINDOWHEIGHT := 480;
          V_ReInit;
          hres := g_pDD.SetDisplayMode(WINDOWWIDTH, WINDOWHEIGHT, 32, 0, 0);
          if hres <> DD_OK then
            I_ErrorInitGraphics('SetDisplayMode');
          printf('SetDisplayMode(): %dx%d...'#13#10, [WINDOWWIDTH, WINDOWHEIGHT]);
        end;
      end
      else
        I_DisableAltTab;
    end;
  end
  else
  begin
    I_FindWindowSize(false, false);
    I_AdjustWindowMode;
    I_RestoreWindowPos(fullscreen);
    hres := I_SetCooperativeLevel(false);
    if hres <> DD_OK then
      I_ErrorInitGraphics('SetCooperativeLevel');
  end;

  if I_MemoryStallHack then
    V_ReInit;

  ZeroMemory(@ddsd, SizeOf(ddsd));
  ddsd.dwSize := SizeOf(ddsd);
  ddsd.dwFlags := DDSD_CAPS;
  ddsd.ddsCaps.dwCaps := DDSCAPS_PRIMARYSURFACE or DDSCAPS_VIDEOMEMORY;
  hres := g_pDD.CreateSurface(ddsd, g_pDDSPrimary, nil);
  if hres <> DD_OK then
  begin
    I_Warning('I_InitGraphics(): Usage of video memory failed, trying system memory.'#13#10);
    ddsd.ddsCaps.dwCaps := DDSCAPS_PRIMARYSURFACE;
    hres := g_pDD.CreateSurface(ddsd, g_pDDSPrimary, nil);
    if hres <> DD_OK then
      I_ErrorInitGraphics('CreateSurface');
  end;

  ZeroMemory(@ddsd, SizeOf(ddsd));
  ZeroMemory(@ddsd.ddpfPixelFormat, SizeOf(ddsd.ddpfPixelFormat));

  ddsd.ddpfPixelFormat.dwSize := SizeOf(ddsd.ddpfPixelFormat);
  g_pDDSPrimary.GetPixelFormat(ddsd.ddpfPixelFormat);

  ddsd.dwSize := SizeOf(ddsd);
  ddsd.dwFlags := DDSD_WIDTH or DDSD_HEIGHT or DDSD_LPSURFACE or
                  DDSD_PITCH or DDSD_PIXELFORMAT or DDSD_CAPS;
  ddsd.ddsCaps.dwCaps := DDSCAPS_OFFSCREENPLAIN or DDSCAPS_SYSTEMMEMORY;

  bpp := ddsd.ddpfPixelFormat.dwRGBBitCount;

  ddsd.dwWidth := SCREENWIDTH;
  ddsd.dwHeight := SCREENHEIGHT;

  if bpp = 32 then
  begin
    ddsd.lPitch := 4 * SCREENWIDTH; // Display is true color
    screen16 := nil;
  end
  else if bpp = 16 then
  begin
    ddsd.lPitch := 2 * SCREENWIDTH;
    screen16 := malloc(SCREENWIDTH * SCREENHEIGHT * 2);
    I_Warning('I_InitGraphics(): using 16 bit color depth desktop in non fullscreen mode reduces performance'#13#10);
  end
  else
    I_Error('I_InitGraphics(): invalid colordepth = %d, only 16 and 32 bit color depth allowed', [bpp]);

  allocscreensize := SCREENWIDTH * (SCREENHEIGHT + ERROR_OFFSET) * SizeOf(LongWord) and not (4095);
  screen := mallocA(allocscreensize, $10000, oscreen); // JVAL: Memory padding may increase performance until 4%
  screen32 := screen;

  if bpp = 16 then
    ddsd.lpSurface := screen16
  else
    ddsd.lpSurface := screen32;

  hres := g_pDD.CreateSurface(ddsd, g_pDDScreen, nil);
  if hres <> DD_OK then
    I_ErrorInitGraphics('CreateSurface');

  I_SetClipper(fullscreen);
end;

//==============================================================================
//
// I_RecreateSurfaces
//
//==============================================================================
procedure I_RecreateSurfaces;
var
  hres: HRESULT;
  ddsd: DDSURFACEDESC2;
begin
  I_ClearInterface(IInterface(g_pDDScreen));
  I_ClearInterface(IInterface(g_pDDSPrimary));

  ZeroMemory(@ddsd, SizeOf(ddsd));
  ddsd.dwSize := SizeOf(ddsd);
  ddsd.dwFlags := DDSD_CAPS;
  ddsd.ddsCaps.dwCaps := DDSCAPS_PRIMARYSURFACE or DDSCAPS_VIDEOMEMORY;
  hres := g_pDD.CreateSurface(ddsd, g_pDDSPrimary, nil);
  if hres <> DD_OK then
  begin
    ddsd.ddsCaps.dwCaps := DDSCAPS_PRIMARYSURFACE;
    hres := g_pDD.CreateSurface(ddsd, g_pDDSPrimary, nil);
    if hres <> DD_OK then
      I_Error('I_RecreateSurfaces(): CreateSurface failed');
  end;

  ZeroMemory(@ddsd, SizeOf(ddsd));
  ZeroMemory(@ddsd.ddpfPixelFormat, SizeOf(ddsd.ddpfPixelFormat));

  ddsd.ddpfPixelFormat.dwSize := SizeOf(ddsd.ddpfPixelFormat);
  g_pDDSPrimary.GetPixelFormat(ddsd.ddpfPixelFormat);

  ddsd.dwSize := SizeOf(ddsd);
  ddsd.dwFlags := DDSD_WIDTH or DDSD_HEIGHT or DDSD_LPSURFACE or
                  DDSD_PITCH or DDSD_PIXELFORMAT or DDSD_CAPS;
  ddsd.ddsCaps.dwCaps := DDSCAPS_OFFSCREENPLAIN or DDSCAPS_SYSTEMMEMORY;

  bpp := ddsd.ddpfPixelFormat.dwRGBBitCount;

  ddsd.dwWidth := SCREENWIDTH;
  ddsd.dwHeight := SCREENHEIGHT;

  if bpp = 32 then
  begin
    ddsd.lPitch := 4 * SCREENWIDTH; // Display is true color
    if screen16 <> nil then
      memfree(screen16, SCREENWIDTH * SCREENHEIGHT * 2);
  end
  else if bpp = 16 then
  begin
    ddsd.lPitch := 2 * SCREENWIDTH;
    if screen16 = nil then
      screen16 := malloc(SCREENWIDTH * SCREENHEIGHT * 2);
    I_Warning('I_RecreateSurfaces(): using 16 bit color depth desktop in non fullscreen mode reduces performance'#13#10);
  end
  else
    I_Error('I_RecreateSurfaces(): invalid colordepth = %d, only 16 and 32 bit color depth allowed', [bpp]);

  if bpp = 16 then
    ddsd.lpSurface := screen16
  else
    ddsd.lpSurface := screen32;

  hres := g_pDD.CreateSurface(ddsd, g_pDDScreen, nil);
  if hres <> DD_OK then
    I_Error('I_RecreateSurfaces(): CreateSurface failed');
end;

const
  NUMSTDRESOLUTIONS = 11;
  STANDARDSCREENRESOLUTIONS: array[0..NUMSTDRESOLUTIONS - 1, 0..1] of integer = (
    (1920, 1080), (1366, 768), (1280, 1024), (1280, 800), (1024, 768), (800, 600), (640, 480), (600, 400), (512, 384), (400, 300), (320, 200)
  );

const
  s_cfs_descs: array[boolean] of string = ('window', 'fullscreen');

//==============================================================================
//
// I_DoChangeFullScreen
//
//==============================================================================
procedure I_DoChangeFullScreen(const dofull, doexclusive: boolean);
var
  hres: HRESULT;
  i: integer;
  wasexclusive: boolean;
begin
  if dofull = fullscreen then
    if doexclusive = fullscreenexclusive then
      exit;

  if not dofull and not fullscreen then
  begin
    fullscreenexclusive := doexclusive;
    exit;
  end;

  wasexclusive := isexclusive;

  hres := I_SetCooperativeLevel(dofull and doexclusive);

  if hres <> DD_OK then
  begin
    I_Warning('I_ChangeFullScreen(): Can not change to %s mode'#13#10, [s_cfs_descs[dofull and doexclusive]]);
    exit;
  end;

  I_FindWindowSize(dofull, doexclusive);
  I_AdjustWindowMode;
  I_RestoreWindowPos(dofull);

  if dofull and doexclusive then
  begin
    hres := g_pDD.SetDisplayMode(WINDOWWIDTH, WINDOWHEIGHT, 32, 0, 0);
    if hres <> DD_OK then
    begin
      I_Warning('I_ChangeFullScreen(): Can not change to (%d, %d)'#13#10, [WINDOWWIDTH, WINDOWHEIGHT]);

      i := 0;

      // Determine a standard screen resolution
      WINDOWWIDTH := STANDARDSCREENRESOLUTIONS[NUMSTDRESOLUTIONS - 1, 0];
      WINDOWHEIGHT := STANDARDSCREENRESOLUTIONS[NUMSTDRESOLUTIONS - 1, 1];
      while i < NUMSTDRESOLUTIONS - 1 do
      begin
        if (WINDOWWIDTH <= STANDARDSCREENRESOLUTIONS[i, 0]) and
           (WINDOWHEIGHT <= STANDARDSCREENRESOLUTIONS[i, 1]) and
           (WINDOWWIDTH >= STANDARDSCREENRESOLUTIONS[i + 1, 0]) then
        begin
          WINDOWWIDTH := STANDARDSCREENRESOLUTIONS[i, 0];
          WINDOWHEIGHT := STANDARDSCREENRESOLUTIONS[i, 1];
          break;
        end;
        inc(i);
      end;

      hres := g_pDD.SetDisplayMode(WINDOWWIDTH, WINDOWHEIGHT, 32, 0, 0);
      if hres <> DD_OK then
      begin
        I_Warning('I_ChangeFullScreen(): Can not change to %s mode'#13#10, [s_cfs_descs[fullscreen]]);
        // Restore original window state
        I_SetCooperativeLevel(false);
        exit;
      end;
    end;
  end;

  if wasexclusive then
    if not isexclusive then
      g_pDD.RestoreDisplayMode;

  fullscreen := dofull;
  fullscreenexclusive := doexclusive;

  I_RecreateSurfaces;
end;

//==============================================================================
//
// I_ChangeFullScreen
//
//==============================================================================
procedure I_ChangeFullScreen(const dofull, doexclusive: boolean);
begin
  I_IgnoreInput(MAXINT);
  I_DoChangeFullScreen(dofull, doexclusive);
  I_SetClipper(fullscreen);
  I_IgnoreInput(15);
end;

//==============================================================================
//
// I_ReadScreen32
//
//==============================================================================
procedure I_ReadScreen32(dest: pointer);
var
  i: integer;
  destl: PLongWord;
  src: PByte;
begin
  if videomode = vm8bit then
  begin
    src := @(screens[SCN_FG]^);
    destl := dest;
    for i := 0 to SCREENWIDTH * SCREENHEIGHT - 1 do
    begin
      destl^ := curpal[src^];
      inc(destl);
      inc(src);
    end;
  end
  else
    memcpy(dest, screen32, SCREENWIDTH * SCREENHEIGHT * SizeOf(LongWord));
end;

end.

