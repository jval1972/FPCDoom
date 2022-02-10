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

unit r_data;

interface

uses
  d_fpc,
  m_fixed,
  r_defs;

//==============================================================================
// R_GetColumn
//
// Retrieve column data for span blitting.
//
//==============================================================================
function R_GetColumn(const tex: integer; col: integer): PByteArray;

//==============================================================================
// R_GetDSs
//
// Retrieve ds_sources
//
//==============================================================================
procedure R_GetDSs(const flat: integer);

//==============================================================================
//
// R_GetLumpForFlat
//
//==============================================================================
function R_GetLumpForFlat(const flat: integer): integer;

//==============================================================================
// R_GetDCs
//
// Retrieve dc_sources
//
//==============================================================================
procedure R_GetDCs(const tex: integer; const col: integer);

//==============================================================================
// R_InitData
//
// I/O, setting up the stuff.
//
//==============================================================================
procedure R_InitData;

//==============================================================================
//
// R_PrecacheLevel
//
//==============================================================================
procedure R_PrecacheLevel;

//==============================================================================
// R_FlatNumForName
//
// Retrieval.
// Floor/ceiling opaque texture tiles,
// lookup by name. For animation?
//
//==============================================================================
function R_FlatNumForName(const name: string): integer;

//==============================================================================
//
// R_CacheFlat
//
//==============================================================================
function R_CacheFlat(const lump: integer; const tag: integer): pointer;

//==============================================================================
// R_TextureNumForName
//
// Called by P_Ticker for switches and animations,
// returns the texture number for the texture name.
//
//==============================================================================
function R_TextureNumForName(const name: string): integer;

//==============================================================================
//
// R_CheckTextureNumForName
//
//==============================================================================
function R_CheckTextureNumForName(const name: string): integer;

var
// for global animation
  texturetranslation: PIntegerArray;

// needed for texture pegging
  textureheight: Pfixed_tArray;
  texturecompositesize: PIntegerArray;

  firstspritelump: integer;
  lastspritelump: integer;

// needed for pre rendering
  spritewidth: Pfixed_tArray;
  spriteoffset: Pfixed_tArray;
  spritetopoffset: Pfixed_tArray;
  spritepresent: PBooleanArray;

  colormaps: PByteArray;
  colormaps32: PLongWordArray;

var
  firstflat: integer;
  lastflat: integer;
  numflats: integer;
  maxvisplane: integer = -1;

//==============================================================================
//
// R_SetupLevel
//
//==============================================================================
procedure R_SetupLevel;

var
  numtextures: integer;
  textures: Ptexture_tPArray;
  flats: PflatPArray;
  aprox_black: byte = 247;

implementation

uses
  doomstat,
  d_think,
  i_system,
  p_setup,
  p_tick,
  p_mobj_h,
  p_mobj,
  p_terrain,
  r_sky,
  r_things,
  r_bsp,
  r_hires,
  r_draw_column,
  r_draw_span,
  r_externaltextures,
  v_video,
  w_wad,
  z_memory;

//==============================================================================
//
// Graphics.
// DOOM graphics for walls and sprites
// is stored in vertical runs of opaque pixels (posts).
// A column is composed of zero or more posts,
// a patch or sprite is composed of zero or more columns.
//
// R_DrawColumnInCache
// Clip and draw a column
//  from a patch into a cached post.
//
//==============================================================================
procedure R_DrawColumnInCache(patch: Pcolumn_t; cache: PByteArray;
  originy: integer; cacheheight: integer);
var
  count: integer;
  position: integer;
  source: PByteArray;
begin
  while patch.topdelta <> $ff do
  begin
    source := pOp(patch, 3);

    count := patch.length;
    position := originy + patch.topdelta;

    if position < 0 then
    begin
      count := count + position;
      position := 0;
    end;

    if position + count > cacheheight then
      count := cacheheight - position;

    if count > 0 then
      memcpy(@cache[position], source, count);

    patch := pOp(patch, patch.length + 4);
  end;
end;

//==============================================================================
//
// R_GenerateComposite
// Using the texture definition,
//  the composite texture is created from the patches,
//  and each column is cached.
//
//==============================================================================
procedure R_GenerateComposite(const texnum: integer);
var
  block: PByteArray;
  texture: Ptexture_t;
  patch: Ptexpatch_t;
  realpatch: Ppatch_t;
  x: integer;
  x1: integer;
  x2: integer;
  i: integer;
  patchcol: Pcolumn_t;
  collump: PSmallIntArray;
  colofs: PIntegerArray; //PWordArray; // 64k
  twidth: integer;
  theight: integer;
begin
  texture := textures[texnum];
  twidth := texture.width;
  theight := texture.height;

  block := Z_Malloc(texturecompositesize[texnum], PU_STATIC, @texturecomposite[texnum]);

  collump := texturecolumnlump[texnum];
  colofs := texturecolumnofs[texnum];

  // Composite the columns together.
  patch := @texture.patches[0];
  for i := 0 to texture.patchcount - 1 do
  begin
    realpatch := W_CacheLumpNum(patch.patch, PU_STATIC);
    x1 := patch.originx;
    x2 := x1 + realpatch.width;

    if x1 < 0 then
      x := 0
    else
      x := x1;

    if x2 > twidth then
      x2 := twidth;

    while x < x2 do
    begin
      // Column does not have multiple patches?
      if collump[x] < 0 then
      begin
        patchcol := pOp(realpatch, realpatch.columnofs[x - x1]);
        R_DrawColumnInCache(
          patchcol, @block[colofs[x]], patch.originy, theight);
      end;
      inc(x);
    end;
    inc(patch);
    Z_ChangeTag(realpatch, PU_CACHE);
  end;

  // Now that the texture has been built in column cache,
  //  it is purgable from zone memory.
  Z_ChangeTag(block, PU_CACHE);
end;

//==============================================================================
//
// R_GenerateLookup
//
//==============================================================================
procedure R_GenerateLookup(const texnum: integer);
var
  texture: Ptexture_t;
  patchcount: PByteArray; // patchcount[texture->width]
  patch: Ptexpatch_t;
  realpatch: Ppatch_t;
  x: integer;
  x1: integer;
  x2: integer;
  i: integer;
  collump: PSmallIntArray;
  colofs: PIntegerArray;  //PWordArray; // 64k
begin
  texture := textures[texnum];

  // Composited texture not created yet.
  texturecomposite[texnum] := nil;

  texturecompositesize[texnum] := 0;
  collump := texturecolumnlump[texnum];
  colofs := texturecolumnofs[texnum];

  // Now count the number of columns
  //  that are covered by more than one patch.
  // Fill in the lump / offset, so columns
  //  with only a single patch are all done.
  patchcount := mallocz(texture.width);
  patch := @texture.patches[0];

  for i := 0 to texture.patchcount - 1 do
  begin
    realpatch := W_CacheLumpNum(patch.patch, PU_STATIC);
    x1 := patch.originx;
    x2 := x1 + realpatch.width;

    if x1 < 0 then
      x := 0
    else
      x := x1;

    if x2 > texture.width then
      x2 := texture.width;
    while x < x2 do
    begin
      patchcount[x] := patchcount[x] + 1;
      collump[x] := patch.patch;
      colofs[x] := realpatch.columnofs[x - x1] + 3;
      inc(x);
    end;
    inc(patch);
    Z_ChangeTag(realpatch, PU_CACHE);
  end;

  for x := 0 to texture.width - 1 do
  begin
    if patchcount[x] = 0 then
    begin
      I_DevWarning('R_GenerateLookup(): column without a patch (%s)'#13#10, [char8tostring(texture.name)]);
      exit;
    end;

    if patchcount[x] > 1 then
    begin
      // Use the cached block.
      collump[x] := -1;
      colofs[x] := texturecompositesize[texnum];

      if texturecompositesize[texnum] > $10000 - texture.height then
        I_DevWarning('R_GenerateLookup(): texture %d is > 64k', [texnum]);

      texturecompositesize[texnum] := texturecompositesize[texnum] + texture.height;
    end;
  end;
  memfree(patchcount, texture.width);
end;

//==============================================================================
//
// R_GetColumn
//
//==============================================================================
function R_GetColumn(const tex: integer; col: integer): PByteArray;
var
  lump: integer;
  ofs: integer;
begin
  col := col and texturewidthmask[tex];
  lump := texturecolumnlump[tex][col];
  ofs := texturecolumnofs[tex][col];

  if lump > 0 then
  begin
    result := pOp(W_CacheLumpNum(lump, PU_LEVEL), ofs);
    exit;
  end;

  if texturecomposite[tex] = nil then
    R_GenerateComposite(tex);

  result := pOp(texturecomposite[tex], ofs);
end;

//==============================================================================
//
// R_GetDSs
//
//==============================================================================
procedure R_GetDSs(const flat: integer);
var
  lump: integer;
begin
  if videomode = vm8bit then
  begin
    lump := R_GetLumpForFlat(flat);
    rspan.ds_source := W_CacheLumpNum(lump, PU_STATIC);
    rspan.ds_scale := R_FlatScaleFromSize(W_LumpLength(lump));
  end
  else
    R_ReadDS32Cache(flat);
end;

//==============================================================================
//
// R_GetLumpForFlat
//
//==============================================================================
function R_GetLumpForFlat(const flat: integer): integer;
begin
  result := flats[flats[flat].translation].lump;
end;

//==============================================================================
//
// R_GetDCs
//
//==============================================================================
procedure R_GetDCs(const tex: integer; const col: integer);
begin
  if videomode = vm8bit then
  begin
    rcolumn.dc_source := R_GetColumn(tex, col);
    rcolumn.dc_texturefactorbits := 0;
  end
  else
    R_ReadDC32Cache(tex, col);
end;

//==============================================================================
//
// R_InitTextures
// Initializes the texture list
//  with the textures from the world map.
//
//==============================================================================
procedure R_InitTextures;
var
  mtexture: Pmaptexture_t;
  texture: Ptexture_t;
  mpatch: Pmappatch_t;
  patch: Ptexpatch_t;
  i: integer;
  j: integer;
  maptex: PIntegerArray;
  maptex2: PIntegerArray;
  maptex1: PIntegerArray;
  name: char8_t;
  names: PByteArray;
  name_p: PByteArray;
  patchlookup: PIntegerArray;
  nummappatches: integer;
  offset: integer;
  maxoff: integer;
  maxoff2: integer;
  numtextures1: integer;
  numtextures2: integer;
  directory: PIntegerArray;
begin
  // Load the patch names from pnames.lmp.
  ZeroMemory(@name, SizeOf(char8_t));
  names := W_CacheLumpName('PNAMES', PU_STATIC);
  nummappatches := PInteger(names)^;
  name_p := pOp(names, 4);

//  patchlookup := malloc(nummappatches * SizeOf(integer));
  patchlookup := Z_Malloc(nummappatches * SizeOf(integer), PU_STATIC, nil);

  for i := 0 to nummappatches - 1 do
  begin
    j := 0;
    while (j < 8) do
    begin
      name[j] := Chr(name_p[i * 8 + j]);
      if name[j] = #0 then
      begin
        inc(j);
        break;
      end;
      inc(j);
    end;
    while (j < 8) do
    begin
      name[j] := #0;
      inc(j);
    end;
    patchlookup[i] := W_CheckNumForName(char8tostring(name));
  end;
  Z_Free(names);

  // Load the map texture definitions from textures.lmp.
  // The data is contained in one or two lumps,
  //  TEXTURE1 for shareware, plus TEXTURE2 for commercial.
  maptex1 := W_CacheLumpName('TEXTURE1', PU_STATIC);
  maptex := maptex1;
  numtextures1 := maptex[0];
  maxoff := W_LumpLength(W_GetNumForName('TEXTURE1'));
  directory := pOp(maptex, SizeOf(integer));

  if W_CheckNumForName('TEXTURE2') <> -1 then
  begin
    maptex2 := W_CacheLumpName('TEXTURE2', PU_STATIC);
    numtextures2 := maptex2[0];
    maxoff2 := W_LumpLength(W_GetNumForName('TEXTURE2'));
  end
  else
  begin
    maptex2 := nil;
    numtextures2 := 0;
    maxoff2 := 0;
  end;
  numtextures := numtextures1 + numtextures2;

  textures := Z_Malloc(numtextures * SizeOf(Ptexture_t), PU_STATIC, nil);
  texturecolumnlump := Z_Malloc(numtextures * SizeOf(PSmallIntArray), PU_STATIC, nil);
  texturecolumnofs := Z_Malloc(numtextures * SizeOf(PIntegerArray), PU_STATIC, nil);
  texturecomposite := Z_Malloc(numtextures * SizeOf(PByteArray), PU_STATIC, nil);
  texturecompositesize := Z_Malloc(numtextures * SizeOf(integer), PU_STATIC, nil);
  texturewidthmask := Z_Malloc(numtextures * SizeOf(integer), PU_STATIC, nil);
  textureheight := Z_Malloc(numtextures * SizeOf(fixed_t), PU_STATIC, nil);

  for i := 0 to numtextures - 1 do
  begin
    if i = numtextures1 then
    begin
      // Start looking in second texture file.
      maptex := maptex2;
      maxoff := maxoff2;
      directory := pOp(maptex, SizeOf(integer));
    end;

    offset := directory[0];

    if offset > maxoff then
      I_Error('R_InitTextures(): bad texture directory');

    mtexture := pOp(maptex, offset);

    textures[i] :=
      Z_Malloc(
        SizeOf(texture_t) + SizeOf(texpatch_t) * (mtexture.patchcount - 1),
          PU_STATIC, nil);
    texture := textures[i];

    texture.width := mtexture.width;
    texture.height := mtexture.height;
    texture.patchcount := mtexture.patchcount;
    texture.texture32 := nil;

    memcpy(@texture.name, @mtexture.name, SizeOf(texture.name));
    mpatch := @mtexture.patches[0];
    patch := @texture.patches[0];

    for j := 0 to texture.patchcount - 1 do
    begin
      patch.originx := mpatch.originx;
      patch.originy := mpatch.originy;
      patch.patch := patchlookup[mpatch.patch];
      if patch.patch = -1 then
        I_Error('R_InitTextures(): Missing patch in texture %s', [char8tostring(texture.name)]);
      inc(mpatch);
      inc(patch);
    end;
    texturecolumnlump[i] := Z_Malloc(texture.width * SizeOf(texturecolumnlump[0][0]), PU_STATIC, nil);
    texturecolumnofs[i] := Z_Malloc(texture.width * SizeOf(texturecolumnofs[0][0]), PU_STATIC, nil);

    j := 1;
    while j * 2 <= texture.width do
      j := j * 2;

    texturewidthmask[i] := j - 1;
    textureheight[i] := texture.height * FRACUNIT;

    {$IFNDEF FPC}directory := {$ENDIF}incp(directory, SizeOf(integer));
  end;

  Z_Free(maptex1);
  if maptex2 <> nil then
    Z_Free(maptex2);

  // Precalculate whatever possible.
  for i := 0 to numtextures - 1 do
    R_GenerateLookup(i);

  // Create translation table for global animation.
  texturetranslation := Z_Malloc((numtextures + 1) * SizeOf(integer), PU_STATIC, nil);

  for i := 0 to numtextures - 1 do
    texturetranslation[i] := i;
end;

//==============================================================================
//
// R_InitFlats
//
//==============================================================================
procedure R_InitFlats;
var
  i: integer;
begin
  firstflat := W_GetNumForName('F_START') + 1;
  lastflat := W_GetNumForName('F_END') - 1;
  numflats := lastflat - firstflat + 1;

  // Create translation table for global animation.
  flats := PflatPArray(Z_Malloc(numflats * SizeOf(pointer), PU_STATIC, nil));

  for i := 0 to numflats - 1 do
  begin
    flats[i] := Pflat_t(Z_Malloc(SizeOf(flat_t), PU_STATIC, nil));
    flats[i].name := W_GetNameForNum(firstflat + i);
    flats[i].translation := i;
    flats[i].lump := W_GetNumForName(flats[i].name);
    flats[i].flat32 := nil;
    // JVAL: 9 December 2007, Added terrain types
    flats[i].terraintype := P_TerrainTypeForName(flats[i].name);;
  end;
end;

//==============================================================================
//
// R_InitSpriteLumps
// Finds the width and hoffset of all sprites in the wad,
//  so the sprite does not need to be cached completely
//  just for having the header info ready during rendering.
//
//==============================================================================
procedure R_InitSpriteLumps;
var
  i: integer;
  in_loop: boolean;
  patch: Ppatch_t;
  tmp: integer;
  lumpname: string;
begin

  firstspritelump := 0;
  for i := 0 to W_NumLumps - 1 do
  begin
    lumpname := char8tostring(W_GetNameForNum(i));
    if (lumpname = 'S_START') or (lumpname = 'SS_START') then
    begin
      firstspritelump := i + 1;
      break;
    end;
  end;

  lastspritelump := W_GetNumForName('S_END') - 1;
  tmp := W_CheckNumForName('SS_END');
  if tmp > 0 then
  begin
    dec(tmp);
    if lastspritelump < tmp then
      lastspritelump := tmp;
  end;

  if lastspritelump < firstspritelump then
  begin
    I_Warning('R_InitSpriteLumps(): WAD files have missplaced sprite markers (start=%d, end=%d)'#13#10, [firstspritelump, lastspritelump]);
    lastspritelump := W_NumLumps;
  end;
  numspritelumps := lastspritelump - firstspritelump + 1;
  spritewidth := Z_Malloc(numspritelumps * SizeOf(fixed_t), PU_STATIC, nil);
  spriteoffset := Z_Malloc(numspritelumps * SizeOf(fixed_t), PU_STATIC, nil);
  spritetopoffset := Z_Malloc(numspritelumps * SizeOf(fixed_t), PU_STATIC, nil);
  spritepresent := Z_Malloc(numspritelumps * SizeOf(boolean), PU_STATIC, nil);

  in_loop := true;

  for i := 0 to numspritelumps - 1 do
  begin
    spritewidth[i] := 0;
    spriteoffset[i] := 0;
    spritetopoffset[i] := 0;
    spritepresent[i] := false;
    lumpname := char8tostring(W_GetNameForNum(firstspritelump + i));
    if (lumpname = 'SS_START') or (lumpname = 'S_START') then
      in_loop := true
    else if (lumpname = 'SS_END') or (lumpname = 'S_END') then
      in_loop := false
    else if in_loop then
    begin
      patch := W_CacheLumpNum(firstspritelump + i, PU_CACHE);
      spritewidth[i] := patch.width * FRACUNIT;
      spriteoffset[i] := patch.leftoffset * FRACUNIT;
      spritetopoffset[i] := patch.topoffset * FRACUNIT;
      spritepresent[i] := true;
    end;
  end;
end;

//==============================================================================
//
// R_InitColormaps
//
//==============================================================================
procedure R_InitColormaps;
var
  lump: integer;
  length: integer;
  i: integer;
  palette: PByteArray;
  cpal: array[0..255] of LongWord;
  src: PByteArray;
  dest: PLongWord;
begin
  palette := V_ReadPalette(PU_STATIC);

  dest := @cpal[0];
  src := palette;
  while PCAST(src) < PCAST(@palette[256 * 3]) do
  begin
    dest^ := (LongWord(src[0]) shl 16) or
             (LongWord(src[1]) shl 8) or
             (LongWord(src[2]));
    inc(dest);
    src := pOp(src, 3);
  end;
  aprox_black := V_FindAproxColorIndex(@cpal, $0, 1, 255);
  Z_ChangeTag(palette, PU_CACHE);

  // Load in the light tables,
  //  256 byte align tables.
  lump := W_GetNumForName('COLORMAP');
  length := W_LumpLength(lump);
  colormaps := Z_Malloc(length, PU_STATIC, nil);
  colormaps32 := Z_Malloc(length * SizeOf(LongWord), PU_STATIC, nil);
  W_ReadLump(lump, colormaps);
  for i := 0 to length - 1 do
    if colormaps[i] = 0 then
      colormaps[i] := aprox_black;
  v_translation := colormaps;
end;

//==============================================================================
//
// R_InitData
// Locates all the lumps
//  that will be used by all views
// Must be called after W_Init.
//
//==============================================================================
procedure R_InitData;
begin
  R_InitTextures;
  R_InitFlats;
  R_InitSpriteLumps;
  R_InitColormaps;
  R_InitFuzzTable;
end;

//==============================================================================
//
// R_FlatNumForName
// Retrieval, get a flat number for a flat name.
//
//==============================================================================
function R_FlatNumForName(const name: string): integer;
var
  i: integer;
begin
  i := W_CheckNumForName(name, firstflat, lastflat);
  if i > -1 then
    result := i - firstflat
  else
  begin
    i := W_CheckNumForName(name);
    if i = -1 then
      I_Error('R_FlatNumForName(): %s not found', [name]);

    // JVAL: Found a flat outside F_START, F_END
    result := numflats;
    inc(numflats);
    flats := Z_ReAlloc(flats, numflats * SizeOf(pointer), PU_STATIC, nil);

    flats[result] := Pflat_t(Z_Malloc(SizeOf(flat_t), PU_STATIC, nil));
    flats[result].name := W_GetNameForNum(i);
    flats[result].translation := result;
    flats[result].lump := i;
    flats[result].flat32 := nil;
    // JVAL: 9 December 2007, Added terrain types
    flats[result].terraintype := P_TerrainTypeForName(flats[result].name);
  end
end;

//==============================================================================
//
// R_CheckTextureNumForName
// Check whether texture is available.
// Filter out NoTexture indicator.
//
//==============================================================================
function R_CheckTextureNumForName(const name: string): integer;
var
  i: integer;
  check: string;
begin
  // "NoTexture" marker.
  if name[1] = '-' then
  begin
    result := 0;
    exit;
  end;

  check := strupper(name);
  for i := 0 to numtextures - 1 do
    if strupper(char8tostring(textures[i].name)) = check then
    begin
      result := i;
      exit;
    end;

  result := -1;
end;

//==============================================================================
//
// R_TextureNumForName
// Calls R_CheckTextureNumForName,
//  aborts with error message.
//
//==============================================================================
function R_TextureNumForName(const name: string): integer;
begin
  result := R_CheckTextureNumForName(name);

  if result = -1 then
    I_Error('R_TextureNumForName(): %s not found', [name]);
end;

//==============================================================================
//
// R_CacheFlat
//
//==============================================================================
function R_CacheFlat(const lump: integer; const tag: integer): pointer;
begin
  result := W_CacheLumpNum(lump, tag);
end;

//==============================================================================
//
// R_PrecacheLevel
// Preloads all relevant graphics for the level.
//
//==============================================================================
procedure R_PrecacheLevel;
var
  flatpresent: PByteArray;
  texturepresent: PByteArray;
  sprpresent: PByteArray;
  i: integer;
  j: integer;
  k: integer;
  lump: integer;
  texture: Ptexture_t;
  th: Pthinker_t;
  sf: Pspriteframe_t;
  flatmemory: integer;
  texturememory: integer;
  spritememory: integer;
  allocmemory: integer;
  flat: pointer;
  sd: Pside_t;
begin
  printf('R_PrecacheLevel()'#13#10);

  // Precache flats.
  flatpresent := mallocz(numflats);

  for i := 0 to numsectors - 1 do
  begin
    flatpresent[sectors[i].floorpic] := 1;
    flatpresent[sectors[i].ceilingpic] := 1;
  end;

  flatmemory := 0;
  allocmemory := AllocMemSize;

  printf(' Precaching flats'#13#10);
  for i := 0 to numflats - 1 do
  begin
    if flatpresent[i] <> 0 then
    begin
      flat := W_CacheLumpNum(R_GetLumpForFlat(i), PU_STATIC);
      R_ReadDS32Cache(i);
      Z_ChangeTag(flat, PU_CACHE);
      flatmemory := flatmemory + 64 * 64;
    end;
  end;
  allocmemory := AllocMemSize - allocmemory;
  printf('%6d KB memory usage for flats'#13#10, [(flatmemory + allocmemory) div 1024]);

  // Precache textures.
  texturepresent := mallocz(numtextures);

  sd := @sides[numsides];
  while sd <> @sides[0] do
  begin
    dec(sd);
    texturepresent[sd.toptexture] := 1;
    texturepresent[sd.midtexture] := 1;
    texturepresent[sd.bottomtexture] := 1;
  end;

  // Sky texture is always present.
  // Note that F_SKY1 is the name used to
  //  indicate a sky floor/ceiling as a flat,
  //  while the sky texture is stored like
  //  a wall texture, with an episode dependend
  //  name.
  texturepresent[skytexture] := 1;

  texturememory := 0;
  allocmemory := AllocMemSize;

  printf(' Precaching textures'#13#10);
  rcolumn.dc_mod := 0;
  rcolumn.dc_texturemod := 0;
  for i := 0 to numtextures - 1 do
  begin
    if texturepresent[i] = 0 then
      continue;

    texture := textures[i];

    for j := 0 to texture.patchcount - 1 do
    begin
      lump := texture.patches[j].patch;
      texturememory := texturememory + lumpinfo[lump].size;
      W_CacheLumpNum(lump, PU_CACHE);
    end;
    R_Precache32bittexture(i);
  end;
  allocmemory := AllocMemSize - allocmemory;
  printf('%6d KB memory usage for textures'#13#10, [(texturememory + allocmemory) div 1024]);

  // Precache sprites.
  sprpresent := mallocz(numspritespresent);

  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th._function.acp1 = @P_MobjThinker then
      sprpresent[Pmobj_t(th).sprite] := 1;
    th := th.next;
  end;

  spritememory := 0;
  allocmemory := AllocMemSize;

  printf(' Precaching sprites'#13#10);
  for i := 0 to numspritespresent - 1 do
  begin
    if sprpresent[i] <> 0 then
    begin
      for j := 0 to sprites[i].numframes - 1 do
      begin
        sf := @sprites[i].spriteframes[j];
        for k := 0 to 7 do
        begin
          lump := firstspritelump + sf.lump[k];
          spritememory := spritememory + lumpinfo[lump].size;
          W_CacheLumpNum(lump, PU_CACHE);
        end;
      end;
    end;
  end;
  allocmemory := AllocMemSize - allocmemory;
  printf('%6d KB memory usage for sprites'#13#10, [(spritememory + allocmemory) div 1024]);

  memfree(flatpresent, numflats);
  memfree(texturepresent, numtextures);
  memfree(sprpresent, numspritespresent);
end;

//==============================================================================
//
// R_SetupLevel
//
//==============================================================================
procedure R_SetupLevel;
begin
  maxvisplane := -1;
  max_ds_p := -1;
  maxvissprite := -1;
end;

end.
