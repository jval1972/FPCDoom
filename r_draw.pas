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

unit r_draw;

interface

uses
  d_fpc,
  doomdef,
  r_defs,
// Needs access to LFB (guess what).
  v_video;

//==============================================================================
//
// R_VideoErase
//
//==============================================================================
procedure R_VideoErase(const ofs: integer; const count: integer);

//==============================================================================
//
// R_VideoBlanc
//
//==============================================================================
procedure R_VideoBlanc(const scn: integer; const ofs: integer; const count: integer; const black: byte = 0);

//==============================================================================
//
// R_PlayerViewBlanc
//
//==============================================================================
procedure R_PlayerViewBlanc(const black: byte);

//==============================================================================
//
// R_InitBuffer
//
//==============================================================================
procedure R_InitBuffer(width, height: integer);

//==============================================================================
// R_InitTranslationTables
//
// Initialize color translation tables,
//  for player rendering etc.
//
//==============================================================================
procedure R_InitTranslationTables;

//==============================================================================
// R_FillBackScreen
//
// Rendering function.
//
//==============================================================================
procedure R_FillBackScreen;

//==============================================================================
//
// R_FillBackStatusbar
//
//==============================================================================
procedure R_FillBackStatusbar;

var
  needsstatusbarback: boolean = true;

//==============================================================================
// R_DrawViewBorder
//
// If the view size is not full screen, draws a border around it.
//
//==============================================================================
procedure R_DrawViewBorder;

//==============================================================================
// R_DrawDiskBusy
//
// Draw disk busy patch
//
//==============================================================================
procedure R_DrawDiskBusy;

var
  displaydiskbusyicon: boolean = true;

  translationtables: PByteArray;
  dc_translation: PByteArray;

  viewwidth: integer;
  viewheight: integer;
  scaledviewwidth: integer;

  viewwindowx: integer;
  viewwindowy: integer;

//
// All drawing to the view buffer is accomplished in this file.
// The other refresh files only know about ccordinates,
//  not the architecture of the frame buffer.
// Conveniently, the frame buffer is a linear one,
//  and we need only the base address,
//  and the total size == width*height*depth/8.,
//

var
  ylookup8: array[0..MAXHEIGHT - 1] of PByteArray;
  ylookup32: array[0..MAXHEIGHT - 1] of PLongWordArray;
  columnofs: array[0..MAXWIDTH - 1] of integer;

implementation

uses
  am_map,
  m_argv,
  r_hires,
  r_main,
  w_wad,
  z_memory,
  st_stuff,
// State.
  doomstat;

//==============================================================================
//
// R_InitTranslationTables
// Creates the translation tables to map
//  the green color ramp to gray, brown, red.
// Assumes a given structure of the PLAYPAL.
// Could be read from a lump instead.
//
//==============================================================================
procedure R_InitTranslationTables;
var
  i: integer;
begin
  translationtables := Z_Malloc(256 * 3 + 255, PU_STATIC, nil);
  translationtables := PByteArray((PCAST(translationtables) + 255) and not 255);

  // translate just the 16 green colors
  for i := 0 to 255 do
    if (i >= $70) and (i <= $7f) then
    begin
      // map green ramp to gray, brown, red
      translationtables[i] := $60 + (i and $f);
      translationtables[i + 256] := $40 + (i and $f);
      translationtables[i + 512] := $20 + (i and $f);
    end
    else
    begin
      // Keep all other colors as is.
      translationtables[i] := i;
      translationtables[i + 256] := i;
      translationtables[i + 512] := i;
    end;
end;

//==============================================================================
//
// R_InitBuffer
// Creats lookup tables that avoid
//  multiplies and other hazzles
//  for getting the framebuffer address
//  of a pixel to draw.
//
//==============================================================================
procedure R_InitBuffer(width, height: integer);
var
  i: integer;
begin
  // Handle resize,
  //  e.g. smaller view windows
  //  with border and/or status bar.
  viewwindowx := (SCREENWIDTH - width) div 2;

  // Column offset. For windows.
  for i := 0 to width - 1 do
    columnofs[i] := viewwindowx + i;

  // Same with base row offset.
  if width = SCREENWIDTH then
  begin
    viewwindowy := 0;
  end
  else
  begin
    viewwindowy := (V_PreserveY(ST_Y) - height) div 2;
  end;

  // Preclaculate all row offsets.
  for i := 0 to height - 1 do
  begin
    ylookup8[i] := @screens[SCN_FG][(i + viewwindowy) * SCREENWIDTH];
    ylookup32[i] := @screen32[(i + viewwindowy) * SCREENWIDTH];
  end;
end;

//==============================================================================
//
// R_ScreenBlanc
//
//==============================================================================
procedure R_ScreenBlanc(const scn: integer; const black: byte = 0);
var
  x, i: integer;
begin
  x := viewwindowy * SCREENWIDTH + viewwindowx;
  for i := 0 to viewheight - 1 do
  begin
    R_VideoBlanc(scn, x, scaledviewwidth, black);
    inc(x, SCREENWIDTH);
  end;
end;

//==============================================================================
//
// R_FillBackScreen
// Fills the back screen with a pattern
//  for variable screen sizes
// Also draws a beveled edge.
//
//==============================================================================
procedure R_FillBackScreen;
var
  src: PByteArray;
  dest: PByteArray;
  x: integer;
  y: integer;
  patch: Ppatch_t;
  name: string;
  tviewwindowx: integer;
  tviewwindowy: integer;
  tviewheight: integer;
  tscaledviewwidth: integer;
begin
  needsbackscreen := false;

  if scaledviewwidth = SCREENWIDTH then
    exit;

  if gamemode = commercial then
    name := 'GRNROCK'   // DOOM II border patch.
  else
    name := 'FLOOR7_2'; // DOOM border patch.

  src := W_CacheLumpName(name, PU_STATIC);

  dest := screens[SCN_TMP];

  for y := 0 to 200 - ST_HEIGHT do
  begin
    for x := 0 to 320 div 64 - 1 do
    begin
      memcpy(dest, pOp(src, _SHL(y and 63, 6)), 64);
      dest := @dest[64];
    end;
  end;

  Z_ChangeTag(src, PU_CACHE);

  tviewwindowx := viewwindowx * 320 div SCREENWIDTH + 1;
  tviewwindowy := viewwindowy * 200 div SCREENHEIGHT + 1;
  tviewheight := viewheight * 200 div SCREENHEIGHT - 2;
  tscaledviewwidth := scaledviewwidth * 320 div SCREENWIDTH - 2;

  patch := W_CacheLumpName('brdr_t', PU_STATIC);
  x := 0;
  while x < tscaledviewwidth do
  begin
    V_DrawPatch(tviewwindowx + x, tviewwindowy - 8, SCN_TMP, patch, false);
    x := x + 8;
  end;
  Z_ChangeTag(patch, PU_CACHE);

  patch := W_CacheLumpName('brdr_b', PU_STATIC);
  x := 0;
  while x < tscaledviewwidth do
  begin
    V_DrawPatch(tviewwindowx + x, tviewwindowy + tviewheight, SCN_TMP, patch, false);
    x := x + 8;
  end;
  Z_ChangeTag(patch, PU_CACHE);

  patch := W_CacheLumpName('brdr_l', PU_STATIC);
  y := 0;
  while y < tviewheight do
  begin
    V_DrawPatch(tviewwindowx - 8, tviewwindowy + y, SCN_TMP, patch, false);
    y := y + 8;
  end;
  Z_ChangeTag(patch, PU_CACHE);

  patch := W_CacheLumpName('brdr_r', PU_STATIC);
  y := 0;
  while y < tviewheight do
  begin
    V_DrawPatch(tviewwindowx + tscaledviewwidth, tviewwindowy + y, SCN_TMP, patch, false);
    y := y + 8;
  end;
  Z_ChangeTag(patch, PU_CACHE);

  // Draw beveled edge.
  V_DrawPatch(tviewwindowx - 8, tviewwindowy - 8, SCN_TMP,
    'brdr_tl', false);

  V_DrawPatch(tviewwindowx + tscaledviewwidth, tviewwindowy - 8, SCN_TMP,
    'brdr_tr', false);

  V_DrawPatch(tviewwindowx - 8, tviewwindowy + tviewheight, SCN_TMP,
    'brdr_bl', false);

  V_DrawPatch(tviewwindowx + tscaledviewwidth, tviewwindowy + tviewheight, SCN_TMP,
    'brdr_br', false);

  V_RemoveTransparency(SCN_TMP, 0, -1);
  V_CopyRect(0, 0, SCN_TMP, V_GetScreenWidth(SCN_TMP), V_GetScreenHeight(SCN_TMP), 0, 0, SCN_BG, true);

  R_ScreenBlanc(SCN_BG);
  x := V_PreserveY(ST_Y) * V_GetScreenWidth(SCN_BG);
  R_VideoBlanc(SCN_BG, x, (V_GetScreenHeight(SCN_BG) - V_PreserveY(ST_Y)) * V_GetScreenWidth(SCN_BG));
end;

var
  oldstatusbarfillblocks: integer = -1;

//==============================================================================
//
// R_FillBackStatusbar
//
//==============================================================================
procedure R_FillBackStatusbar;
var
  src: PByteArray;
  dest: PByteArray;
  x: integer;
  y: integer;
  patch: Ppatch_t;
  name: string;
begin
  if (oldstatusbarfillblocks <> 10) <> (screenblocks <> 10) then
  begin
    oldstatusbarfillblocks := screenblocks;
    needsstatusbarback := true;
  end;

  if not needsstatusbarback then
    exit;

  needsstatusbarback := false;

  if gamemode = commercial then
    name := 'GRNROCK'   // DOOM II border patch.
  else
    name := 'FLOOR7_2'; // DOOM border patch.

  src := W_CacheLumpName(name, PU_STATIC);

  dest := screens[SCN_ST2];

  for y := 200 - ST_HEIGHT + 1 to 200 do
  begin
    for x := 0 to 320 div 64 - 1 do
    begin
      memcpy(dest, pOp(src, _SHL(y and 63, 6)), 64);
      dest := @dest[64];
    end;
  end;

  Z_ChangeTag(src, PU_CACHE);

  if screenblocks = 10 then
  begin
    patch := W_CacheLumpName('brdr_b', PU_STATIC);
    x := 0;
    while x < 320 do
    begin
      V_DrawPatch(x, patch.topoffset, SCN_ST2, patch, false);
      x := x + 8;
    end;
    Z_ChangeTag(patch, PU_CACHE);
  end;
end;

//==============================================================================
// R_VideoErase
//
// Copy a screen buffer.
//
//==============================================================================
procedure R_VideoErase(const ofs: integer; const count: integer);
var
  i: integer;
  src: PByte;
  dest: PLongWord;
begin
  // LFB copy.
  // This might not be a good idea if memcpy
  //  is not optiomal, e.g. byte by byte on
  //  a 32bit CPU, as GNU GCC/Linux libc did
  //  at one point.
  if videomode = vm32bit then
  begin
    src := @screens[SCN_BG][ofs];
    dest := @screen32[ofs];
    for i := 1 to count do
    begin
      dest^ := videopal[src^];
      inc(dest);
      inc(src);
    end;
  end
  else
    memcpy(@screens[SCN_FG][ofs], @screens[SCN_BG][ofs], count);
end;

//==============================================================================
//
// R_VideoBlanc
//
//==============================================================================
procedure R_VideoBlanc(const scn: integer; const ofs: integer; const count: integer; const black: byte = 0);
var
  start: PByte;
  lstrart: PLongWord;
  i: integer;
  lblack: LongWord;
begin
  if (videomode = vm32bit) and (scn = SCN_FG) then
  begin
    lblack := curpal[black];
    lstrart := @screen32[ofs];
    for i := 0 to count -1 do
    begin
      lstrart^ := lblack;
      inc(lstrart);
    end;
  end
  else
  begin
    start := @screens[scn][ofs];
    memset(start, black, count);
  end;
end;

//==============================================================================
//
// R_PlayerViewBlanc
//
//==============================================================================
procedure R_PlayerViewBlanc(const black: byte);
begin
  R_ScreenBlanc(SCN_FG, black);
end;

//==============================================================================
//
// R_DrawViewBorder
// Draws the border around the view
//  for different size windows?
//
//==============================================================================
procedure R_DrawViewBorder;
begin
  if scaledviewwidth < SCREENWIDTH then
    if (gamestate = GS_LEVEL) and (amstate <> am_only) then
      V_CopyScreenTransparent(SCN_BG, SCN_FG);
end;

var
  disklump: integer = -2;
  diskpatch: Ppatch_t = nil;

//==============================================================================
//
// R_DrawDiskBusy
//
//==============================================================================
procedure R_DrawDiskBusy;
begin
  if not displaydiskbusyicon then
    exit;

// Draw disk busy patch
  if disklump = -2 then
  begin
    if M_CheckParmCDROM then
      disklump := W_CheckNumForName('STCDROM');
    if disklump < 0 then
      disklump := W_CheckNumForName('STDISK');
    if disklump >= 0 then
      diskpatch := W_CacheLumpNum(disklump, PU_STATIC);
  end;

  if diskpatch <> nil then
    V_DrawPatch(318 - diskpatch.width, 2, SCN_FG,
      diskpatch, true);
end;

end.
