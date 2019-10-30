//------------------------------------------------------------------------------
//
//  FPCDoom - Port of Doom to Free Pascal Compiler
//  Copyright (C) 2004-2007 by Jim Valavanis
//  Copyright (C) 2017-2018 by Jim Valavanis
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

const
// Columns cache
  COL32CACHESIZE = $4000;
  CACHECOLSHIFT = 15;
  CACHETEXTMASK = 1 shl CACHECOLSHIFT - 1;
  CACHECOLBITS = 10;
  CACHECOLMASK = 1 shl CACHECOLBITS - 1;

procedure R_ReadDC32Cache(const rtex, rcol: integer);

procedure R_Precache32bittexture(const rtex: integer);

const
  MAXTEXTUREHEIGHT = 1024;
  MAXTEXTUREWIDTH = 1 shl CACHECOLBITS;
  MAXEQUALHASH = 2; // Allow 2 same hash values to increase performance.

type
  dc32_t = array[0..MAXTEXTUREHEIGHT] of LongWord;
  Pdc32_t = ^dc32_t;

  dc32cacheitem_t = record
    dc32: Pdc32_t;
    columnsize: integer;
    texture: integer;
    column: integer;
    texturemod: integer;
  end;
  Pdc32cacheitem_t = ^dc32cacheitem_t;

  dc32cacheinfo_t = array[0..MAXEQUALHASH - 1] of Pdc32cacheitem_t;
  Pdc32cacheinfo_t = ^dc32cacheinfo_t;

  dc32cacheinfo_tArray = array[0..COL32CACHESIZE - 1] of dc32cacheinfo_t;
  dc32cacheinfo_tPArray = array[0..COL32CACHESIZE - 1] of Pdc32cacheinfo_t;

procedure R_ClearDC32Cache;
procedure R_ResetDC32Cache;
procedure R_InitDC32Cache;
procedure R_ShutDownDC32Cache;

const
// Flat cache
  FLAT32CACHESIZE = 256;
  CACHEFLATMASK = FLAT32CACHESIZE - 1;

procedure R_ReadDS32Cache(const flat: integer);

type
  ds32_t = array[0..512 * 512 - 1] of LongWord;
  Pds32_t = ^ds32_t;

  ds32cacheinfo_t = record
    ds32: array[0..Ord(NUMDSSCALES) - 1] of Pds32_t;
    lump: integer;
    scale: dsscale_t;
  end;
  Pds32cacheinfo_t = ^ds32cacheinfo_t;
  ds32cacheinfo_tArray = array[0..FLAT32CACHESIZE - 1] of ds32cacheinfo_t;
  ds32cacheinfo_tPArray = array[0..FLAT32CACHESIZE - 1] of Pds32cacheinfo_t;

function R_Get_ds32(p: Pds32cacheinfo_t): Pds32_t;

function R_FlatScaleFromSize(const size: integer): dsscale_t;

procedure R_ClearDS32Cache;
procedure R_ResetDS32Cache;
procedure R_InitDS32Cache;
procedure R_ShutDownDS32Cache;

procedure R_InitSpanTables;

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
  dc32cache: dc32cacheinfo_tPArray;

function R_Get_dc32(p: Pdc32cacheitem_t; columnsize: integer): Pdc32_t;
begin
  if p.dc32 = nil then
  begin
    p.dc32 := malloc((columnsize + 1) * SizeOf(LongWord));
    p.columnsize := columnsize;
  end
  else if p.columnsize <> columnsize then
  begin
    realloc(pointer(p.dc32), (p.columnsize + 1) * SizeOf(LongWord), (columnsize + 1) * SizeOf(LongWord));
    p.columnsize := columnsize;
  end;
  result := p.dc32;
end;

//
// R_ReadDC32ExternalCache
//
// JVAL
//  Create dc_source32 from an external texture
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
  index: integer;
  ptex: Ptexture_t;
begin
  if not useexternaltextures then
  begin
    result := false;
    exit;
  end;

  // Cache read of the caclulated dc_source32, 98-99% propability not to recalc...
  hash := R_GetHash(rtex, rcol, dc_texturemod);
  index := 0;
  cachemiss := true;
  if dc32cache[hash] <> nil then
  begin
    while dc32cache[hash][index] <> nil do
    begin
      if dc32cache[hash][index].texture = -1 then
        break;
      cachemiss := (dc32cache[hash][index].texture <> rtex) or
                   (dc32cache[hash][index].column <> rcol) or
                   (dc32cache[hash][index].texturemod <> dc_texturemod);
      if not cachemiss then
        break;
      if index = MAXEQUALHASH - 1 then
        break;
      inc(index);
    end;
  end
  else
    dc32cache[hash] := mallocz(SizeOf(dc32cacheinfo_t));

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
        while (twidth > MAXTEXTUREHEIGHT) or (theight > MAXTEXTUREHEIGHT) do
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
      if dc32cache[hash][index] = nil then
        dc32cache[hash][index] := mallocz(SizeOf(dc32cacheitem_t));

      dc32cache[hash][index].texture := rtex;
      dc32cache[hash][index].column := rcol;
      dc32cache[hash][index].texturemod := dc_texturemod;

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
        mod_c := (dc_texturemod  * tfactor) shr DC_HIRESBITS;
        mod_d := dc_texturemod - mod_c * (1 shl (DC_HIRESBITS - ptex.factorbits));
        col := col * tfactor + mod_c;
        dc_texturemod := mod_d;
      end
      else
      begin
        dc_texturemod := dc_mod;
        columnsize := 128;
      end;

      pdc32 := R_Get_dc32(dc32cache[hash][index], columnsize);
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
      if dc_texturemod <> 0 then
      begin
        if t.GetBytesPerPixel = 1 then
          t.GetPalettedColumn32(col + 1, columnsize, @dc32_a, c)
        else
          t.GetColumn32(col + 1, columnsize, @dc32_a);
        plw2 := @dc32_a;
        cfrac2 := dc_texturemod shl (FRACBITS - DC_HIRESBITS);
        for i := 0 to columnsize - 1 do
        begin
          plw^ := R_ColorAverage(plw^, plw2^, cfrac2);
          inc(plw);
          inc(plw2);
        end;
      end;

      if t.GetBytesPerPixel <> 1 then
      begin
        pdc32 := R_Get_dc32(dc32cache[hash][index], columnsize);
        plw := @pdc32[0];
        // Simutate palette changes
        if dc_32bittexturepaletteeffects and (pal_color <> 0) then
        begin
          dc_palcolor := pal_color; // JVAL: needed for transparent textures.
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
          dc_palcolor := 0;
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
      dc32cache[hash][index].dc32[columnsize] := dc32cache[hash][index].dc32[columnsize - 1]
    else
      dc32cache[hash][index].dc32[columnsize] := dc32cache[hash][index].dc32[0];
  end;
  dc_mod := dc_texturemod;
  dc_texturefactorbits := ptex.factorbits;
  dc_source32 := PLongWordArray(dc32cache[hash][index].dc32);
  result := true;
end;

//
// R_ReadDC32InternalCache
//
// JVAL
//  Create dc_source32 from internal (IWAD) texture
//
procedure R_ReadDC32InternalCache(const rtex, rcol: integer);
var
  plw: PLongWord;
  pdc32: Pdc32_t;
  src1, src2: PByte;
  tbl: Phiresmodtable_t;
  cachemiss: boolean;
  hash: integer;
  i, index: integer;
  dc_source2: PByteArray;
begin
  // Cache read of the caclulated dc_source32, 98-99% propability not to recalc...
  hash := R_GetHash(rtex, rcol, dc_mod);
  index := 0;
  cachemiss := true;
  if dc32cache[hash] <> nil then
  begin
    while dc32cache[hash][index] <> nil do
    begin
      if dc32cache[hash][index].texture = -1 then
        break;
      cachemiss := (dc32cache[hash][index].texture <> rtex) or
                   (dc32cache[hash][index].column <> rcol) or
                   (dc32cache[hash][index].texturemod <> dc_mod);
      if not cachemiss then
        break;
      if index = MAXEQUALHASH - 1 then
        break;
      inc(index);
    end;
  end
  else
    dc32cache[hash] := mallocz(SizeOf(dc32cacheinfo_t));

  if cachemiss then
  begin
    if dc32cache[hash][index] = nil then
      dc32cache[hash][index] := mallocz(SizeOf(dc32cacheitem_t));
    dc32cache[hash][index].texture := rtex;
    dc32cache[hash][index].column := rcol;
    dc32cache[hash][index].texturemod := dc_mod;

    pdc32 := R_Get_dc32(dc32cache[hash][index], 128);
    plw := @pdc32[0];
    textures[rtex].factorbits := 0;
    if dc_mod = 0 then
    begin
      dc_source := R_GetColumn(rtex, rcol);
      src1 := @dc_source[0];
      for i := 0 to 127 do
      begin
        plw^ := videopal[src1^];
        inc(plw);
        inc(src1);
      end;
    end
    else
    begin
      tbl := @hirestable[dc_mod];
      dc_source := R_GetColumn(rtex, rcol);
      src1 := @dc_source[0];
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
      plw^ := dc32cache[hash][index].dc32[127]
    else
      plw^ := dc32cache[hash][index].dc32[0];
  end;
  dc_texturefactorbits := 0;
  dc_source32 := PLongWordArray(dc32cache[hash][index].dc32);
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
  i, j: integer;
begin
  for i := 0 to COL32CACHESIZE - 1 do
    if dc32cache[i] <> nil then
      for j := 0 to MAXEQUALHASH - 1 do
        if dc32cache[i][j] <> nil then
          dc32cache[i][j].texture := -1;
end;

procedure R_ClearDC32Cache;
var
  i, j: integer;
begin
  for i := 0 to numtextures - 1 do
  begin
    if LongWord(textures[i].texture32) > 1 then
      dispose(textures[i].texture32, destroy);
    textures[i].texture32 := nil;
  end;

  for i := 0 to COL32CACHESIZE - 1 do
    if dc32cache[i] <> nil then
    begin
      for j := 0 to MAXEQUALHASH - 1 do
        if dc32cache[i][j] <> nil then
        begin
          if dc32cache[i][j].dc32 <> nil then
            memfree(pointer(dc32cache[i][j].dc32), (dc32cache[i][j].columnsize + 1) * SizeOf(LongWord));
          memfree(pointer(dc32cache[i][j]), SizeOf(dc32cacheitem_t));
        end;
      memfree(pointer(dc32cache[i]), SizeOf(dc32cacheinfo_t));
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
var
  i: integer;
begin
  R_ClearDC32Cache;
  for i := 0 to COL32CACHESIZE - 1 do
    if dc32cache[i] <> nil then
      memfree(pointer(dc32cache[i]), SizeOf(dc32cacheinfo_t));
end;

var
  spanpixels_left: array[0..4095] of integer;
  spanpixels_down: array[0..4095] of integer;
  spanpixels_leftdown: array[0..4095] of integer;

//
// R_InitSpanTables
//
procedure R_InitSpanTables;
var
  i: integer;
begin
  for i := 0 to 4095 do
    if (i + 1) mod 64 = 0 then
      spanpixels_left[i] := (i - 63) and 4095
    else
      spanpixels_left[i] := (i + 1) and 4095;

  for i := 0 to 4095 do
    spanpixels_down[i] := (i + 64) and 4095;

  for i := 0 to 4095 do
    if (i + 65) mod 64 = 0 then
      spanpixels_leftdown[i] := (i + 1) and 4095
    else
      spanpixels_leftdown[i] := (i + 65) and 4095;
end;

procedure R_GrowSpan64to128(const p: Pds32cacheinfo_t);
var
  i: integer;
  dest: PLongWord;
  cA, cB, cC, cD: LongWord;
  p1, p2: Pds32_t;
begin
  if p.scale <> ds64x64 then
    exit;
  p1 := R_Get_ds32(p);
  p.scale := ds128x128;
  p2 := R_Get_ds32(p);
  dest := @p2[0];
  for i := 0 to 4095 do
  begin
    cA := p1[i];
    cB := p1[spanpixels_left[i]];
    cC := p1[spanpixels_down[i]];
    cD := p1[spanpixels_leftdown[i]];
    dest^ := cA;
    inc(dest);
    dest^ := R_ColorMidAverage(cA, cB);
    inc(dest, 127);
    dest^ := R_ColorMidAverage(cA, cC);
    cA := dest^;
    inc(dest);
    dest^ := R_ColorMidAverage(cA, R_ColorMidAverage(cB, cD));
    if i and 63 = 63 then
      inc(dest)
    else
      dec(dest, 127);
  end;
end;

var
  ds32cache: ds32cacheinfo_tPArray;

procedure R_ReadDS32Cache(const flat: integer);
var
  cachemiss: boolean;
  hash: integer;
  t: PTexture;
  pds: Pds32cacheinfo_t;
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
begin
  ds_source := nil;
  cachemiss := false;
  hash := flat and CACHEFLATMASK;
  if ds32cache[hash] = nil then
  begin
    ds32cache[hash] := mallocz(SizeOf(ds32cacheinfo_t));
    cachemiss := true;
  end;
  pds := ds32cache[hash];
  lump := R_GetLumpForFlat(flat);
  if cachemiss or (pds.lump <> lump) then
  begin
    pds.lump := lump;
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

    if useexternaltextures and (integer(t) > $1) then // if we have a hi resolution flat
    begin
      fsize := t.GetWidth;
      if fsize = 512 then
        pds.scale := ds512x512
      else if fsize = 256 then
        pds.scale := ds256x256
      else if fsize = 128 then
        pds.scale := ds128x128
      else
        pds.scale := ds64x64;
      pds32 := R_Get_ds32(pds);
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
        pbstop := PByte(integer(pb) + numpixels);
        while integer(pb) < integer(pbstop) do
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
      ds_source := W_CacheLumpNum(lump, PU_STATIC);
      lumplen := W_LumpLength(lump);
      pds.scale := R_FlatScaleFromSize(lumplen);

      src1 := @ds_source[0];
      pds32 := R_Get_ds32(pds);
      plw := @pds32[0];
      if lumplen < $1000 then
        loops := 0
      else
        loops := dsscalesize[Ord(pds.scale)];
      for i := 0 to loops - 1 do
      begin
        plw^ := videopal[src1^];
        inc(plw);
        inc(src1);
      end;
      Z_ChangeTag(ds_source, PU_CACHE);
    end;
    if (detailLevel >= DL_NORMAL) and (pds.scale = ds64x64) then
    begin
      if extremeflatfiltering then
        R_GrowSpan64to128(pds);
      pds32 := R_Get_ds32(pds);
    end;
  end
  else
    pds32 := R_Get_ds32(pds);
  ds_source32 := PLongWordArray(pds32);
  ds_scale := pds.scale;
end;

function R_Get_ds32(p: Pds32cacheinfo_t): Pds32_t;
begin
  result := p.ds32[Ord(p.scale)];
  if result = nil then
  begin
    result := malloc(dsscalesize[Ord(p.scale)] * SizeOf(LongWord));
    p.ds32[Ord(p.scale)] := result;
  end;
end;

procedure R_ResetDS32Cache;
var
  i: integer;
begin
  for i := 0 to FLAT32CACHESIZE - 1 do
    if ds32cache[i] <> nil then
      ds32cache[i].lump := -1;
end;

procedure R_ClearDS32Cache;
var
  i, j: integer;
begin
  for i := 0 to numflats - 1 do
  begin
    if LongWord(flats[i].flat32) > 1 then
      dispose(flats[i].flat32, destroy);
    flats[i].flat32 := nil;
  end;

  for i := 0 to FLAT32CACHESIZE - 1 do
    if ds32cache[i] <> nil then
    begin
      for j := 0 to Ord(NUMDSSCALES) - 1 do
        if ds32cache[i].ds32[j] <> nil then
          memfree(pointer(ds32cache[i].ds32[j]), dsscalesize[j] * SizeOf(LongWord));
      memfree(pointer(ds32cache[i]), SizeOf(ds32cacheinfo_t));
    end
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
var
  i: integer;
begin
  R_ClearDS32Cache;
  for i := 0 to FLAT32CACHESIZE - 1 do
    if ds32cache[i] <> nil then
      memfree(pointer(ds32cache[i]), SizeOf(ds32cacheinfo_t));
end;

end.

