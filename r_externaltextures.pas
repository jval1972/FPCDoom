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

unit r_externaltextures;

interface
uses
  r_draw_span;

procedure R_Reset32Cache;

procedure R_Clear32Cache;

procedure R_Init32Cache;

procedure R_ShutDown32Cache;

procedure R_ReadDC32Cache(const rtex, rcol: integer);

procedure R_Precache32bittexture(const rtex: integer);

procedure R_ClearDC32Cache;
procedure R_ResetDC32Cache;
procedure R_InitDC32Cache;
procedure R_ShutDownDC32Cache;

procedure R_ReadDS32Cache(const flat: integer);

function R_FlatScaleFromSize(const size: integer): dsscale_t;

procedure R_ClearDS32Cache;
procedure R_ResetDS32Cache;
procedure R_InitDS32Cache;
procedure R_ShutDownDS32Cache;

implementation

uses
  d_fpc,
  m_fixed,
  r_defs,
  r_hires,
  r_draw_column,
  r_sky,
  r_data,
  r_mmx,
  t_main,
  v_video,
  w_wad,
  z_memory;

const
// Columns cache
  COL32CACHESIZE = $4000;

const
  MAXTEXTURESIZE32 = 128 * (1 shl MAXTEXTUREFACTORBITS);

type
  dc32_t = array[0..MAXTEXTURESIZE32] of LongWord;
  Pdc32_t = ^dc32_t;

  Pdc32cacheitem_t = ^dc32cacheitem_t;
  dc32cacheitem_t = record
    dc32: Pdc32_t;
    columnsize32: integer;
    texture: integer;
    column: integer;
    texturemod: integer;
    next: Pdc32cacheitem_t;
  end;

  dc32cacheitem_tArray = array[0..COL32CACHESIZE - 1] of dc32cacheitem_t;
  dc32cacheitem_tPArray = array[0..COL32CACHESIZE - 1] of Pdc32cacheitem_t;

procedure R_Reset32Cache;
begin
  R_ResetDC32Cache;
  R_ResetDS32Cache;
end;

procedure R_Clear32Cache;
begin
  R_ClearDC32Cache;
  R_ClearDS32Cache;
end;

procedure R_ShutDown32Cache;
begin
  R_ShutDownDC32Cache;
  R_ShutDownDS32Cache;
end;

procedure R_Init32Cache;
begin
  R_InitDC32Cache;
  R_InitDS32Cache;
end;

function R_GetHash(const tex, col, dmod: integer): integer;
// JVAL
// Get a hash value depending on tex, col and dc_mod.
// Although the followng hash is elementary, simple
// and it 's not the best gives good results,
// (about 98-99.9% hits correctly to cache (for standard resolution textures))
begin
  result := (97 * tex + col * 3833 + dmod * 7867) and (COL32CACHESIZE - 1);
end;

var
  dc32cache: dc32cacheitem_tPArray;

function R_Get_dc32(p: Pdc32cacheitem_t; columnsize: integer): Pdc32_t;
begin
  if p.dc32 = nil then
  begin
    p.dc32 := malloc((columnsize + 1) * SizeOf(LongWord));
    p.columnsize32 := columnsize;
  end
  else if p.columnsize32 <> columnsize then
  begin
    {$IFNDEF FPC}p.dc32 := {$ENDIF}realloc(p.dc32, (p.columnsize32 + 1) * SizeOf(LongWord), (columnsize + 1) * SizeOf(LongWord));
    p.columnsize32 := columnsize;
  end;
  result := p.dc32;
end;

function R_FindDC32Rover(const hash, rtex, rcol, rtexturemod: integer): Pdc32cacheitem_t;
begin
  result := dc32cache[hash];
  while result <> nil do
  begin
    if (result.texture = rtex) and (result.column = rcol) and (result.texturemod = rtexturemod) then
       exit;
    result := result.next;
  end;
end;

function R_NewDC32Rover(const hash: integer): Pdc32cacheitem_t;
begin
  result := mallocz(SizeOf(dc32cacheitem_t));
  result.next := dc32cache[hash];
  dc32cache[hash] := result;
end;

//
// R_ReadDC32ExternalCache
//
// JVAL
//  Create dc_source (32 bit) from an external texture
//
function R_ReadDC32ExternalCache(const rtex, rcol: integer): boolean;
var
  plw: PLongWord;
  plw2: PLongWord;
  pdc32: Pdc32_t;
  cachemiss: boolean;
  t: PTexture;
  col: integer;
  i: integer;
  dc32_a: dc32_t;
  cfrac2: fixed_t;
  r1, b1, g1: byte;
  r2, g2, b2: byte;
  r, g, b: LongWord;
  c: LongWord;
  twidth: integer;
  theight: integer;
  tfactor: integer;
  columnsize: integer;
  mod_c, mod_d: integer;
  loops: integer;
  hash: integer;
  curgamma: PByteArray;
  pb: PByte;
  ptex: Ptexture_t;
  rover: Pdc32cacheitem_t;
begin
  if not useexternaltextures then
  begin
    result := false;
    exit;
  end;

  // Cache read of the caclulated dc_source (32 bit), 98-99% propability not to recalc...
  hash := R_GetHash(rtex, rcol, rcolumn.dc_texturemod);
  rover := R_FindDC32Rover(hash, rtex, rcol, rcolumn.dc_texturemod);
  cachemiss := rover = nil;
  if cachemiss then
    rover := R_NewDC32Rover(hash);

  ptex := textures[rtex];
  if cachemiss then
  begin
    t := ptex.texture32;

    if t = nil then
    begin
      t := T_LoadHiResTexture(ptex.name);
      if t = nil then
        ptex.texture32 := pointer($1) // Mark as missing
      else
      begin
        ptex.texture32 := t;
        // JVAL Adjust very big textures
        theight := t.GetHeight;
        tfactor := theight div ptex.height; // Scaling
        i := 0;
        while i < MAXTEXTUREFACTORBITS do
        begin
          if tfactor <= 1 shl i then
            break;
          inc(i);
        end;
        // JVAL Final adjustment of hi resolution textures
        twidth := (1 shl i) * ptex.width;
        theight := (1 shl i) * ptex.height;
        while (twidth > MAXTEXTURESIZE32) or (theight > MAXTEXTURESIZE32) do
        begin
          dec(i);
          twidth := (1 shl i) * ptex.width;
          theight := (1 shl i) * ptex.height;
        end;
        t.ScaleTo(twidth, theight); // JVAL Scale the texture if needed
        ptex.factorbits := i;
      end;
    end;

    if LongWord(t) > $1 then // if we have a hi resolution texture
    begin
      rover.texture := rtex;
      rover.column := rcol;
      rover.texturemod := rcolumn.dc_texturemod;

      // JVAL
      // Does not use [and (t.GetWidth - 1)] but [mod (t.GetWidth - 1)] because
      // we don't require textures to have width as power of 2.
      if rcol < 0 then
        col := abs(rcol - ptex.width) mod ptex.width
      else
        col := rcol mod ptex.width;
      if ptex.factorbits > 0 then
      begin
      // JVAL: Handle hi resolution texture
        tfactor := 1 shl ptex.factorbits;
        columnsize := 128 * tfactor;
        mod_c := (rcolumn.dc_texturemod  * tfactor) shr DC_HIRESBITS;
        mod_d := rcolumn.dc_texturemod - mod_c * (1 shl (DC_HIRESBITS - ptex.factorbits));
        col := col * tfactor + mod_c;
        rcolumn.dc_texturemod := mod_d;
      end
      else
      begin
        tfactor := 1;
        rcolumn.dc_texturemod := rcolumn.dc_mod;
        columnsize := 128;
      end;

      pdc32 := R_Get_dc32(rover, columnsize);
      plw := @pdc32[0];

      curgamma := @gammatable[usegamma]; // To Adjust gamma

      c := 0;
      if t.GetBytesPerPixel = 1 then
      begin
        r1 := pal_color;
        g1 := pal_color shr 8;
        b1 := pal_color shr 16;
        c := curgamma[r1] + curgamma[g1] shl 8 + curgamma[b1] shl 16;
        t.GetPalettedColumn32(col, columnsize, plw, c);
      end
      else
        t.GetColumn32(col, columnsize, plw);

      // Texture filtering if dc_texturemod <> 0
      if rcolumn.dc_texturemod <> 0 then
      begin
        if t.GetBytesPerPixel = 1 then
          t.GetPalettedColumn32(col + 1, columnsize, @dc32_a, c)
        else
          t.GetColumn32(col + 1, columnsize, @dc32_a);
        plw2 := @dc32_a;
        cfrac2 := rcolumn.dc_texturemod shl (FRACBITS - DC_HIRESBITS);
        for i := 0 to columnsize - 1 do
        begin
          plw^ := R_ColorAverageAlpha(plw^, plw2^, cfrac2);
          inc(plw);
          inc(plw2);
        end;
      end;

      if t.GetBytesPerPixel <> 1 then
      begin
        pdc32 := R_Get_dc32(rover, columnsize);
        plw := @pdc32[0];
        // Simutate palette changes
        if dc_32bittexturepaletteeffects and (pal_color <> 0) then
        begin
          r1 := pal_color;
          g1 := pal_color shr 8;
          b1 := pal_color shr 16;
          loops := columnsize;
          if usegamma > 0 then
          begin
            while loops >= 0 do
            begin
              c := plw^;
              if c <> 0 then // JVAL: color $000000 is transparent index
              begin
                r2 := c;
                g2 := c shr 8;
                b2 := c shr 16;
                r := r1 + r2;
                if r > 255 then
                  r := 255
                else
                  r := curgamma[r];
                g := g1 + g2;
                if g > 255 then
                  g := 255
                else
                  g := curgamma[g];
                b := b1 + b2;
                if b > 255 then
                  plw^ := r + g shl 8 + $FF0000
                else
                  plw^ := r + g shl 8 + curgamma[b] shl 16;
              end;
              inc(plw);
              dec(loops);
            end;
          end
          else
          begin
            if not R_BatchColorAdd32_MMX(plw, pal_color, columnsize) then
            begin
              while loops >= 0 do
              begin
                c := plw^;
                if c <> 0 then // JVAL: color $000000 is transparent index
                begin
                  r2 := c;
                  g2 := c shr 8;
                  b2 := c shr 16;
                  r := r1 + r2;
                  if r > 255 then
                    r := 255;
                  g := g1 + g2;
                  if g > 255 then
                    g := 255;
                  b := b1 + b2;
                  if b > 255 then
                    plw^ := r + g shl 8 + $FF0000
                  else
                    plw^ := r + g shl 8 + b shl 16;
                end;
                inc(plw);
                dec(loops);
              end;
            end;
          end;
        end
        else
        begin
          if usegamma > 0 then
          begin
            pb := PByte(plw);
            loops := columnsize;
            while loops > 0 do
            begin
              if PLongWord(pb)^ <> 0 then
              begin
                pb^ := curgamma[pb^];
                inc(pb);
                pb^ := curgamma[pb^];
                inc(pb);
                pb^ := curgamma[pb^];
                inc(pb, 2);
              end
              else
                inc(pb, 4);
              dec(loops);
            end;
          end;
        end;
      end;
    end
    else // We don't have hi resolution texture
    begin
      result := false;
      exit;
    end;

    if rtex = skytexture then
      rover.dc32[columnsize] := rover.dc32[columnsize - 1]
    else
      rover.dc32[columnsize] := rover.dc32[0];
  end;
  rcolumn.dc_mod := rcolumn.dc_texturemod;
  rcolumn.dc_texturefactorbits := ptex.factorbits;
  rcolumn.dc_source := rover.dc32;
  result := true;
end;

type
  resize_t = function (const x1, x2, x3: LongWord; const offs: integer): LongWord;

function hqresize(const x1, x2, x3: LongWord; const offs: integer): LongWord;
  function _color_sqdiff(const c1, c2: LongWord): LongWord;
  var
    dr, dg, db: LongWord;
  begin
    dr := ((c1 shr 16) and $FF) - ((c2 shr 16) and $FF);
    dg := ((c1 shr 8) and $FF) - ((c1 shr 8) and $FF);
    db := (c1 and $FF) - (c2 and $FF);
    result := dr * dr + dg * dg + db * db;
  end;
var
  sqoffs: LongWord;
  sqoffs1, sqoffs3: LongWord;
  t1, t3: LongWord;
begin
  sqoffs := offs * offs;

  sqoffs1 := _color_sqdiff(x1, x2);
  if sqoffs1 < sqoffs then
    t1 := x1
  else
    t1 := x2;

  sqoffs3 := _color_sqdiff(x3, x2);
  if sqoffs3 < sqoffs then
    t3 := x3
  else
    t3 := x2;

  result := R_ColorArrayAverage([t1, x2, x2, t3]);
end;

function noresize(const x1, x2, x3: LongWord; const offs: integer): LongWord;
begin
  result := x2;
end;

function R_Grow_dc32(p: Pdc32cacheitem_t; oldcolumnsize: integer; factor: integer; lastid: integer; proc: resize_t): Pdc32_t;
var
  l: PLongWordArray;
  i: integer;
begin
  if p.dc32 = nil then
  begin
    p.dc32 := mallocz(factor * (oldcolumnsize + 1) * SizeOf(LongWord));
    p.columnsize32 := factor * oldcolumnsize;
  end
  else if p.columnsize32 = oldcolumnsize then
  begin
    l := malloc((factor * oldcolumnsize + 1) * SizeOf(LongWord));
    for i := 0 to factor * oldcolumnsize - 1 do
      l[i] := p.dc32[i div factor];
    l[factor * p.columnsize32] := p.dc32[lastid];

    {$IFNDEF FPC}p.dc32 := {$ENDIF}realloc(p.dc32, (p.columnsize32 + 1) * SizeOf(LongWord), (factor * oldcolumnsize + 1) * SizeOf(LongWord));
    p.columnsize32 := factor * oldcolumnsize;
    p.dc32[0] := proc(l[p.columnsize32], l[0], l[1], 64);
    for i := 1 to p.columnsize32 - 1 do
      p.dc32[i] := proc(l[i - 1], l[i], l[i + 1], 64);
    p.dc32[p.columnsize32] := proc(l[p.columnsize32 - 1], l[p.columnsize32], l[1], 64);
    memfree(l, (factor * oldcolumnsize + 1) * SizeOf(LongWord));
  end;
  result := p.dc32;
end;

//
// R_ReadDC32InternalCache
//
// JVAL
//  Create dc_source (32 bit) from internal (IWAD) texture
//
procedure R_ReadDC32InternalCache(const rtex, rcol: integer);
var
  plw: PLongWord;
  pdc32: Pdc32_t;
  src1, src2: PByte;
  tbl: Phiresmodtable_t;
  cachemiss: boolean;
  hash: integer;
  i: integer;
  dc_source1, dc_source2: PByteArray;
  rover: Pdc32cacheitem_t;
begin
  // Cache read of the caclulated dc_source (32 bit), 98-99% propability not to recalc...
  hash := R_GetHash(rtex, rcol, rcolumn.dc_mod);
  rover := R_FindDC32Rover(hash, rtex, rcol, rcolumn.dc_texturemod);
  cachemiss := rover = nil;
  if cachemiss then
    rover := R_NewDC32Rover(hash);

  if cachemiss then
  begin
    rover.texture := rtex;
    rover.column := rcol;
    rover.texturemod := rcolumn.dc_mod;

    pdc32 := R_Get_dc32(rover, 128);
    plw := @pdc32[0];
    textures[rtex].factorbits := 0;
    if rcolumn.dc_mod = 0 then
    begin
      dc_source1 := R_GetColumn(rtex, rcol);
      src1 := @dc_source1[0];
      for i := 0 to 127 do
      begin
        plw^ := videopal[src1^];
        inc(plw);
        inc(src1);
      end;
    end
    else
    begin
      tbl := @hirestable[rcolumn.dc_mod];
      dc_source1 := R_GetColumn(rtex, rcol);
      src1 := @dc_source1[0];
      dc_source2 := R_GetColumn(rtex, rcol + 1);
      src2 := @dc_source2[0];
      for i := 0 to 127 do
      begin
        plw^ := tbl[src1^, src2^];
        inc(plw);
        inc(src1);
        inc(src2);
      end;
    end;

    if rtex = skytexture then
    begin
      if smoothskies then
      begin
        R_Grow_dc32(rover, 128, 2, 127, @hqresize)
      end
      else
        R_Grow_dc32(rover, 128, 2, 127, @noresize);
      textures[rtex].factorbits := 1;
    end
    else
      plw^ := rover.dc32[0];
  end;
  rcolumn.dc_texturefactorbits := textures[rtex].factorbits;
  rcolumn.dc_source := rover.dc32;
end;

procedure R_ReadDC32Cache(const rtex, rcol: integer);
begin
  if not R_ReadDC32ExternalCache(rtex, rcol) then
    R_ReadDC32InternalCache(rtex, rcol);
end;

procedure R_Precache32bittexture(const rtex: integer);
begin
  R_ReadDC32Cache(rtex, 0);
end;

procedure R_ResetDC32Cache;
var
  i: integer;
  rover: Pdc32cacheitem_t;
begin
  for i := 0 to COL32CACHESIZE - 1 do
  begin
    rover := dc32cache[i];
    while rover <> nil do
    begin
      rover.texture := -1;
      rover := rover.next;
    end;
  end;
end;

procedure R_ClearDC32Cache;
var
  i: integer;
  rover, next: Pdc32cacheitem_t;
begin
  for i := 0 to numtextures - 1 do
  begin
    if LongWord(textures[i].texture32) > 1 then
      dispose(textures[i].texture32, destroy);
    textures[i].texture32 := nil;
  end;

  for i := 0 to COL32CACHESIZE - 1 do
  begin
    rover := dc32cache[i];
    while rover <> nil do
    begin
      next := rover.next;
      if rover.dc32 <> nil then
        memfree(rover.dc32, (rover.columnsize32 + 1) * SizeOf(LongWord));
      memfree(rover, SizeOf(dc32cacheitem_t));
      rover := next;
    end;
    dc32cache[i] := nil;
  end;
end;

procedure R_InitDC32Cache;
var
  i: integer;
begin
  for i := 0 to COL32CACHESIZE - 1 do
    dc32cache[i] := nil;
end;

procedure R_ShutDownDC32Cache;
begin
  R_ClearDC32Cache;
end;

const
// Flat cache
  FLAT32CACHESIZE = 256;
  CACHEFLATMASK = FLAT32CACHESIZE - 1;


type
  ds32_t = array[0..512 * 512 - 1] of LongWord;
  Pds32_t = ^ds32_t;

  Pds32cacheitem_t = ^ds32cacheitem_t;
  ds32cacheitem_t = record
    ds32: array[0..Ord(NUMDSSCALES) - 1] of Pds32_t;
    lump: integer;
    scale: dsscale_t;
    next: Pds32cacheitem_t;
  end;
  ds32cacheitem_tArray = array[0..FLAT32CACHESIZE - 1] of ds32cacheitem_t;
  ds32cacheitem_tPArray = array[0..FLAT32CACHESIZE - 1] of Pds32cacheitem_t;

function R_Get_ds32(p: Pds32cacheitem_t): Pds32_t;
begin
  result := p.ds32[Ord(p.scale)];
  if result = nil then
  begin
    result := malloc(dsscalesize[Ord(p.scale)] * SizeOf(LongWord));
    p.ds32[Ord(p.scale)] := result;
  end;
end;

type
  span64x64_t = packed array[0..63, 0..63] of LongWord;
  Pspan64x64_t = ^span64x64_t;

  span128x128_t = packed array[0..127, 0..127] of LongWord;
  Pspan128x128_t = ^span128x128_t;

procedure R_GrowSpan64to128(const p: Pds32cacheitem_t);
var
  i, j: integer;
  p1, p2: Pds32_t;
  pspan64: Pspan64x64_t;
  pspan128: Pspan128x128_t;
  outspan128: Pspan128x128_t;
  c: LongWord;
begin
  if p.scale <> ds64x64 then
    exit;
  p1 := R_Get_ds32(p);
  p.scale := ds128x128;
  p2 := R_Get_ds32(p);

  pspan64 := @p1[0];
  pspan128 := malloc(SizeOf(span128x128_t));
  for i := 0 to 127 do
    for j := 0 to 127 do
      pspan128[i, j] := pspan64[i div 2, j div 2];

  outspan128 := @p2[0];
  for i := 0 to 127 do
    for j := 0 to 127 do
    begin
      c := pspan128[i, j];
      outspan128[i, j] := R_ColorArrayAverage(
        [pspan128[(i - 1) and 127, j], c, pspan128[(i + 1) and 127, j],
         pspan128[i, (j - 1) and 127], c, pspan128[i, (j + 1) and 127]]);
    end;

  memfree(pspan128, SizeOf(span128x128_t));
end;

var
  ds32cache: ds32cacheitem_tPArray;

function R_FindDS32Rover(const hash, lump: integer): Pds32cacheitem_t;
begin
  result := ds32cache[hash];
  while result <> nil do
  begin
    if result.lump = lump then
      exit;
    result := result.next;
  end;
end;

function R_NewDS32Rover(const hash: integer): Pds32cacheitem_t;
begin
  result := mallocz(SizeOf(ds32cacheitem_t));
  result.lump := -1;
  result.next := ds32cache[hash];
  ds32cache[hash] := result;
end;


procedure R_ReadDS32Cache(const flat: integer);
var
  cachemiss: boolean;
  hash: integer;
  t: PTexture;
  rover: Pds32cacheitem_t;
  pds32: Pds32_t;
  plw: PLongWord;
  src1: PByte;
  i: integer;
  fsize: integer;
  r1, b1, g1: byte;
  r2, g2, b2: byte;
  r, g, b: LongWord;
  c: LongWord;
  lump: integer;
  lumplen: integer;
  loops: integer;
  curgamma: PByteArray;
  pb: PByte;
  pbstop: PByte;
  tpal: PLongWordArray;
  numpixels: integer;
  flatname: string;
  ds_source8: PByteArray;
begin
  hash := flat and CACHEFLATMASK;
  lump := R_GetLumpForFlat(flat);
  rover := R_FindDS32Rover(hash, lump);
  cachemiss := rover = nil;
  if cachemiss then
    rover := R_NewDS32Rover(hash);

  if cachemiss or (rover.lump <> lump) then
  begin
    rover.lump := lump;
    t := flats[flats[flat].translation].flat32;
    if useexternaltextures and (t = nil) then
    begin
      flatname := W_GetNameForNum(lump);
      t := T_LoadHiResTexture(flatname);
      if t = nil then // JVAL: This allow to use Doomsday resource pack
        t := T_LoadHiResTexture('flat-' + flatname);
      if t = nil then
        flats[flats[flat].translation].flat32 := pointer($1) // Mark as missing
      else
      begin
        if t.GetWidth <= 64 then
          fsize := 64
        else if t.GetWidth <= 128 then
          fsize := 128
        else if t.GetWidth <= 256 then
          fsize := 256
        else
          fsize := 512;
        t.ScaleTo(fsize, fsize);
        flats[flats[flat].translation].flat32 := t;
      end;
    end;

    if useexternaltextures and (PCAST(t) > $1) then // if we have a hi resolution flat
    begin
      fsize := t.GetWidth;
      if fsize = 512 then
        rover.scale := ds512x512
      else if fsize = 256 then
        rover.scale := ds256x256
      else if fsize = 128 then
        rover.scale := ds128x128
      else
        rover.scale := ds64x64;
      pds32 := R_Get_ds32(rover);
      numpixels := fsize * fsize;
      curgamma := @gammatable[usegamma]; // To Adjust gamma

      if t.GetBytesPerPixel = 1 then
      begin
        r1 := pal_color;
        g1 := pal_color shr 8;
        b1 := pal_color shr 16;
        c := curgamma[r1] + curgamma[g1] shl 8 + curgamma[b1] shl 16;
        t.SetPalColor(c);
        plw := @pds32[0];
        tpal := PLongWordArray(t.GetTransformedPalette);
        pb := PByte(t.GetImage);
        pbstop := pOp(pb, numpixels);
        while PCAST(pb) < PCAST(pbstop) do
        begin
          plw^ := tpal[pb^];
          inc(plw);
          inc(pb);
        end;
      end
      else
      begin
        memcpy(pds32, t.GetImage, numpixels * SizeOf(LongWord));

        // Simutate palette changes
        plw := @pds32[0];

        if dc_32bittexturepaletteeffects and (pal_color <> 0) then
        begin
          r1 := pal_color;
          g1 := pal_color shr 8;
          b1 := pal_color shr 16;
          loops := numpixels;
          if usegamma > 0 then
          begin
            for i := 0 to loops - 1 do
            begin
              c := plw^;
              r2 := c;
              g2 := c shr 8;
              b2 := c shr 16;
              r := r1 + r2;
              if r > 255 then
                r := 255
              else
                r := curgamma[r];
              g := g1 + g2;
              if g > 255 then
                g := 255
              else
                g := curgamma[g];
              b := b1 + b2;
              if b > 255 then
                plw^ := r + g shl 8 + $FF0000
              else
                plw^ := r + g shl 8 + curgamma[b] shl 16;
              inc(plw);
            end;
          end
          else
          begin
            if not R_BatchColorAdd32_MMX(plw, pal_color, numpixels) then
            begin
              for i := 0 to loops - 1 do
              begin
                c := plw^;
                r2 := c;
                g2 := c shr 8;
                b2 := c shr 16;
                r := r1 + r2;
                if r > 255 then
                  r := 255;
                g := g1 + g2;
                if g > 255 then
                  g := 255;
                b := b1 + b2;
                if b > 255 then
                  plw^ := r + g shl 8 + $FF0000
                else
                  plw^ := r + g shl 8 + b shl 16;
                inc(plw);
              end;
            end;
          end
        end
        else
        begin
          if usegamma > 0 then
          begin
            pb := PByte(plw);
            loops := numpixels;
            while loops > 0 do
            begin
              pb^ := curgamma[pb^];
              inc(pb);
              pb^ := curgamma[pb^];
              inc(pb);
              pb^ := curgamma[pb^];
              inc(pb, 2);
              dec(loops);
            end;
          end;
        end;
      end;

    end
    else
    begin
      ds_source8 := W_CacheLumpNum(lump, PU_STATIC);
      lumplen := W_LumpLength(lump);
      rover.scale := R_FlatScaleFromSize(lumplen);

      src1 := @ds_source8[0];
      pds32 := R_Get_ds32(rover);
      plw := @pds32[0];
      if lumplen < $1000 then
        loops := 0
      else
        loops := dsscalesize[Ord(rover.scale)];
      for i := 0 to loops - 1 do
      begin
        plw^ := videopal[src1^];
        inc(plw);
        inc(src1);
      end;
      Z_ChangeTag(ds_source8, PU_CACHE);
    end;
    if (detailLevel >= DL_NORMAL) and (rover.scale = ds64x64) then
    begin
      if extremeflatfiltering then
        R_GrowSpan64to128(rover);
      pds32 := R_Get_ds32(rover);
    end;
  end
  else
    pds32 := R_Get_ds32(rover);
  rspan.ds_source := PLongWordArray(pds32);
  rspan.ds_scale := rover.scale;
end;

procedure R_ResetDS32Cache;
var
  i: integer;
  rover: Pds32cacheitem_t;
begin
  for i := 0 to FLAT32CACHESIZE - 1 do
  begin
    rover := ds32cache[i];
    while rover <> nil do
    begin
      rover.lump := -1;
      rover := rover.next;
    end;
  end;
end;

procedure R_ClearDS32Cache;
var
  i, j: integer;
  rover, next: Pds32cacheitem_t;
begin
  for i := 0 to numflats - 1 do
  begin
    if LongWord(flats[i].flat32) > 1 then
      dispose(flats[i].flat32, destroy);
    flats[i].flat32 := nil;
  end;

  for i := 0 to FLAT32CACHESIZE - 1 do
  begin
    rover := ds32cache[i];
    while rover <> nil do
    begin
      next := rover.next;
      for j := 0 to Ord(NUMDSSCALES) - 1 do
        if rover.ds32[j] <> nil then
          memfree(rover.ds32[j], dsscalesize[j] * SizeOf(LongWord));
      memfree(rover, SizeOf(ds32cacheitem_t));
      rover := next;
    end;
    ds32cache[i] := nil;
  end;
end;

function R_FlatScaleFromSize(const size: integer): dsscale_t;
var
  i: integer;
begin
  result := ds64x64;
  // JVAL
  // Determine hi-resolution flats inside wad
  // The lump size of a hi resolution flat must fit dsscalesize
  for i := 1 to Ord(NUMDSSCALES) - 1 do
    if size = dsscalesize[i] then
    begin
      result := dsscale_t(i);
      exit;
    end;
end;

procedure R_InitDS32Cache;
var
  i: integer;
begin
  for i := 0 to FLAT32CACHESIZE - 1 do
    ds32cache[i] := nil;
end;

procedure R_ShutDownDS32Cache;
begin
  R_ClearDS32Cache;
end;

end.

