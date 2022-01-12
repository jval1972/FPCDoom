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

unit d_main;

interface

uses
  d_event,
  doomdef;

//
// DESCRIPTION:
// DOOM main program (D_DoomMain) and game loop (D_DoomLoop),
// plus functions to determine game mode (shareware, registered),
// parse command line parameters, configure game parameters (turbo),
// and call the startup functions.
//
//-----------------------------------------------------------------------------

const
  AppTitle = 'FPCDoom';

procedure D_ProcessEvents;
procedure D_DoAdvanceDemo;


procedure D_AddFile(const fname: string);

//
// D_DoomMain()
// Not a globally visible function, just included for source reference,
// calls all startup code, parses command line options.
// If not overrided by user input, calls N_AdvanceDemo.
//
procedure D_DoomMain;

// Called by IO functions when input is detected.
procedure D_PostEvent(ev: Pevent_t);

//
// BASE LEVEL
//
procedure D_PageTicker;

procedure D_PageDrawer;

procedure D_AdvanceDemo;

procedure D_StartTitle;

function D_IsPaused: boolean;

procedure D_Display;

// wipegamestate can be set to -1 to force a wipe on the next draw
var
  wipegamestate: integer = -1;   // JVAL was gamestate_t = GS_DEMOSCREEN;
  wipedisplay: boolean = false;

  nomonsters: boolean;          // checkparm of -nomonsters
  fastparm: boolean;            // checkparm of -fast
  devparm: boolean;             // started game with -devparm
  singletics: boolean;          // debug flag to cancel adaptiveness
  autostart: boolean;
  startskill: skill_t;
  respawnparm: boolean;         // checkparm of -respawn

  startepisode: integer;
  startmap: integer;
  advancedemo: boolean;

  basedefault: string;          // default file

function D_Version: string;
function D_VersionBuilt: string;

procedure D_ShutDown;

var
  set_videomodeneeded: boolean = false;
  set_screenwidth: integer;
  set_screenheight: integer;

implementation

uses
  d_fpc,
  deh_main,
  doomstat,
  d_english,
  d_player,
  d_net,
  c_con,
  c_cmds,
  e_endoom,
  f_finale,
  f_wipe,
  m_argv,
  m_misc,
  m_menu,
  info,
  info_rnd,
  i_system,
  i_sound,
  i_video,
  i_io,
  g_game,
  hu_stuff,
  wi_stuff,
  st_stuff,
  am_map,
  p_setup,
  p_mobj_h,
  r_draw,
  r_main,
  r_hires,
  r_defs,
  r_intrpl,
  r_data,
  r_lightmap,
  registry,
  sounds,
  s_sound,
  sc_actordef,
  t_main,
  v_video,
  v_screenresolution,
  w_wad,
  w_pak,
  z_memory;

//
// D_DoomLoop()
// Not a globally visible function,
//  just included for source reference,
//  called by D_DoomMain, never exits.
// Manages timing and IO,
//  calls all ?_Responder, ?_Ticker, and ?_Drawer,
//  calls I_GetTime, I_StartFrame, and I_StartTic
//

//
// D_PostEvent
// Called by the I/O functions when input is detected
//
procedure D_PostEvent(ev: Pevent_t);
begin
  events[eventhead] := ev^;
  inc(eventhead);
  eventhead := eventhead and (MAXEVENTS - 1);
end;

//
// D_ProcessEvents
// Send all the events of the given timestamp down the responder chain
//
procedure D_ProcessEvents;
var
  ev: Pevent_t;
begin
// IF STORE DEMO, DO NOT ACCEPT INPUT
  if (gamemode = commercial) and (W_CheckNumForName('MAP01') < 0) then
    exit;

  if I_GameFinished then
    exit;

  while eventtail <> eventhead do
  begin
    ev := @events[eventtail];
    if C_Responder(ev) then
      // console ate the event
    else if M_Responder(ev) then
      // menu ate the event
    else
      G_Responder(ev);
    if I_GameFinished then
    begin
      eventtail := eventhead;
      exit;
    end;
    inc(eventtail);
    eventtail := eventtail and (MAXEVENTS - 1);
  end;
end;

//
// D_Display
//  draw current display, possibly wiping it from the previous
//

var
  viewactivestate: boolean = false;
  menuactivestate: boolean = false;
  viewfullscreen: boolean = false;
  inhelpscreensstate: boolean = false;
  borderdrawcount: integer;
  nodrawers: boolean = false; // for comparative timing purposes
  noblit: boolean = false;    // for comparative timing purposes
  norender: boolean = false;  // for comparative timing purposes


procedure D_FinishUpdate;
begin
  if not noblit then
    I_FinishUpdate; // page flip or blit buffer
end;

procedure D_RenderPlayerView(player: Pplayer_t);
begin
  if norender then
  begin
    R_PlayerViewBlanc(aprox_black);
    exit;
  end;

  if player <> nil then
    R_RenderPlayerView(player)
end;

var
  diskbusy: integer = -1;

procedure D_Display;
var
  nowtime: integer;
  tics: integer;
  wipestart: integer;
  y: integer;
  done: boolean;
  wipe: boolean;
  redrawsbar: boolean;
  redrawbkscn: boolean;
  palette: PByteArray;
  oldvideomode: videomode_t;
  drawhu: boolean;
begin
  if gamestate = GS_ENDOOM then
  begin
    E_Drawer;
    D_FinishUpdate; // page flip or blit buffer
    exit;
  end;

  HU_DoFPSStuff;

  if nodrawers then
    exit; // for comparative timing / profiling

  redrawsbar := false;
  redrawbkscn := false;
  drawhu := false;

  // change the view size if needed
  if setsizeneeded then
  begin
    R_ExecuteSetViewSize;
    oldgamestate := -1; // force background redraw
    borderdrawcount := 3;
  end;

  // save the current screen if about to wipe
  if Ord(gamestate) <> wipegamestate then
  begin
    wipe := true;
    wipe_StartScreen;
  end
  else
    wipe := false;

  if (gamestate = GS_LEVEL) and (gametic <> 0) then
    HU_Erase;

  // do buffered drawing
  case gamestate of
    GS_LEVEL:
      begin
        if gametic <> 0 then
        begin
          if amstate = am_only then
            AM_Drawer;
          if wipe or ((viewheight <> SCREENHEIGHT) and viewfullscreen) then
            redrawsbar := true;
          if inhelpscreensstate and (not inhelpscreens) then
            redrawsbar := true; // just put away the help screen
          viewfullscreen := viewheight = SCREENHEIGHT;
          if viewfullscreen then
            ST_Drawer(stdo_no, redrawsbar)
          else
            ST_Drawer(stdo_full, redrawsbar);
        end;
      end;
    GS_INTERMISSION:
      WI_Drawer;
    GS_FINALE:
      F_Drawer;
    GS_DEMOSCREEN:
      D_PageDrawer;
  end;

  // draw the view directly
  if gamestate = GS_LEVEL then
  begin
    if (amstate <> am_only) and (gametic <> 0) then
    begin
      D_RenderPlayerView(@players[displayplayer]);
      if amstate = am_overlay then
        AM_Drawer;
    end;

    if gametic <> 0 then
      drawhu := true;
  end
  else if Ord(gamestate) <> oldgamestate then
  begin
  // clean up border stuff
    palette := V_ReadPalette(PU_STATIC);
    I_SetPalette(palette);
    V_SetPalette(palette);
    Z_ChangeTag(palette, PU_CACHE);
  end;

  // see if the border needs to be initially drawn
  if gamestate = GS_LEVEL then
  begin
    if needsbackscreen or (oldgamestate <> Ord(GS_LEVEL)) then
    begin
      viewactivestate := false; // view was not active
      R_FillBackScreen;         // draw the pattern into the back screen
    end;

  // see if the border needs to be updated to the screen
    if amstate <> am_only then
    begin
      if scaledviewwidth <> SCREENWIDTH then
      begin
        if menuactive or menuactivestate or (not viewactivestate) or C_IsConsoleActive then
          borderdrawcount := 3;
        if borderdrawcount > 0 then
        begin
          R_DrawViewBorder; // erase old menu stuff
          redrawbkscn := true;
          dec(borderdrawcount);
        end;
      end
      else if R_FullStOn and (gametic <> 0) then
        ST_Drawer(stdo_small, redrawsbar);
    end;
  end;

  menuactivestate := menuactive;
  viewactivestate := viewactive;
  inhelpscreensstate := inhelpscreens;
  oldgamestate := Ord(gamestate);
  wipegamestate := Ord(gamestate);

  // draw pause pic
  if paused then
  begin
    if amstate = am_only then
      y := 4
    else
      y := (viewwindowy * 200) div SCREENHEIGHT + 4;
    V_DrawPatch((320 - 68) div 2, y, SCN_FG,
      'M_PAUSE', true);
  end;

  if drawhu then
    HU_Drawer;

  if isdiskbusy then
  begin
    diskbusy := 4; // Display busy disk for a little...
    isdiskbusy := false;
  end;

  if diskbusy > 0 then
  begin
    // Menus go directly to the screen
    M_Drawer; // Menu is drawn even on top of everything

    // Console goes directly to the screen
    C_Drawer;   // Console is drawn even on top of menus

    // Draw disk busy patch
    R_DrawDiskBusy; // Draw disk busy is draw on top of console
    dec(diskbusy);
  end
  else if diskbusy = 0 then
  begin
    if not redrawbkscn then
    begin
      R_DrawViewBorder;
      if drawhu then
        HU_Drawer;
    end;

    M_Drawer;
    C_Drawer;
    dec(diskbusy);
  end
  else
  begin
    M_Drawer;
    C_Drawer;
  end;

  NetUpdate; // send out any new accumulation

  // normal update
  if not wipe then
  begin
    D_FinishUpdate; // page flip or blit buffer
    exit;
  end;

  // wipe update
  wipe_EndScreen;

  wipedisplay := true;
  wipestart := I_GetTime - 1;

  oldvideomode := videomode;
  videomode := vm32bit;
  repeat
    repeat
      I_Sleep(0);
      nowtime := I_GetTime;
      tics := nowtime - wipestart;
    until tics <> 0;
    wipestart := nowtime;
    done := wipe_Ticker(tics);
    M_Drawer;         // Menu is drawn even on top of wipes
    C_Drawer;         // Console draw on top of wipes and menus
    D_FinishUpdate;   // page flip or blit buffer
    HU_DoFPSStuff;
  until done;
  videomode := oldvideomode;
  wipedisplay := false;
end;

//
//  D_DoomLoop
//

procedure D_DoomLoop;
begin
  if demorecording then
    G_BeginRecording;

  I_InitGraphics;

  while true do
  begin
    // frame syncronous IO operations
    I_StartFrame;

    // process one or more tics
    if singletics then
      D_RunSingleTick // will run only one tick
    else
      D_RunMultipleTicks; // will run at least one tick

    S_UpdateSounds(players[consoleplayer].mo);// move positional sounds

    if set_videomodeneeded then
    begin
      set_videomodeneeded := false;
      V_SetScreenResolution(set_screenwidth, set_screenheight);
    end;

  end;
end;

//
//  DEMO LOOP
//
var
  demosequence: integer;
  pagetic: integer;
  pagename: string;

//
// D_PageTicker
// Handles timing for warped projection
//
procedure D_PageTicker;
begin
  dec(pagetic);
  if pagetic < 0 then
    D_AdvanceDemo;
end;

//
// D_PageDrawer
//
procedure D_PageDrawer;
begin
   V_PageDrawer(pagename);
end;

//
// D_AdvanceDemo
// Called after each demo or intro demosequence finishes
//
procedure D_AdvanceDemo;
begin
  if gamestate <> GS_ENDOOM then
    advancedemo := true;
end;

//
// This cycles through the demo sequences.
// FIXME - version dependend demo numbers?
//
procedure D_DoAdvanceDemo;
begin
  players[consoleplayer].playerstate := PST_LIVE;  // not reborn
  advancedemo := false;
  usergame := false;               // no save / end game here
  paused := false;
  gameaction := ga_nothing;

  if gamemode = retail then
    demosequence := (demosequence + 1) mod 7
  else
    demosequence := (demosequence + 1) mod 6;

  case demosequence of
    0:
      begin
        if gamemode = commercial then
          pagetic := TICRATE * 11
        else
          pagetic := 170;
        gamestate := GS_DEMOSCREEN;
        pagename := 'TITLEPIC';
        if gamemode = commercial then
          S_StartMusic(Ord(mus_dm2ttl))
        else
          S_StartMusic(Ord(mus_intro));
      end;
    1:
      begin
        G_DeferedPlayDemo('1');
      end;
    2:
      begin
        pagetic := 200;
        gamestate := GS_DEMOSCREEN;
        pagename := 'CREDIT';
      end;
    3:
      begin
        G_DeferedPlayDemo('2');
      end;
    4:
      begin
        gamestate := GS_DEMOSCREEN;
        if gamemode = commercial then
        begin
          pagetic := TICRATE * 11;
          pagename := 'TITLEPIC';
          S_StartMusic(Ord(mus_dm2ttl));
        end
        else
        begin
          pagetic := 200;
          if gamemode = retail then
            pagename := 'CREDIT'
          else
            pagename := 'HELP2';
        end;
      end;
    5:
      begin
        G_DeferedPlayDemo('3');
      end;
    // THE DEFINITIVE DOOM Special Edition demo
    6:
      begin
        G_DeferedPlayDemo('4');
      end;
  end;
end;

//
// D_StartTitle
//
procedure D_StartTitle;
begin
  gameaction := ga_nothing;
  demosequence := -1;
  D_AdvanceDemo;
end;

var
  wadfiles: TDStringList;

//
// D_AddFile
//
procedure D_AddFile(const fname: string);
begin
  if fname <> '' then
    if wadfiles.IndexOf(strupper(fname)) < 0 then
      wadfiles.Add(strupper(fname));
end;

//
// IdentifyVersion
// Checks availability of IWAD files by name,
// to determine whether registered/commercial features
// should be executed (notably loading PWAD's).
//
const
  PATH_SEPARATOR = ';';

const
  NUMSTEAMAPPS = 3;
  steamapps: array[0..NUMSTEAMAPPS - 1] of integer = (2280, 2290, 2300);

{$IFNDEF FPC}
const
  HKEY_LOCAL_MACHINE = LongWord($80000002);
  KEY_WOW64_64KEY = $100;
  KEY_WOW64_32KEY = $200;
  KEY_READ = 983065;
{$ENDIF}

function QuerySteamDirectory(const flags, dirid: integer): string;
var
  reg: TRegistry;
begin
  reg := TRegistry.Create(flags);
  reg.RootKey := HKEY_LOCAL_MACHINE;
  if reg.OpenKeyReadOnly('\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App ' + itoa(dirid)) then
    result := reg.ReadString('InstallLocation')
  else if reg.OpenKeyReadOnly('\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App ' + itoa(dirid)) then
    result := reg.ReadString('InstallLocation')
  else
    result := '';
  reg.free;
end;

function FileInDoomPath(const fn: string): string;
var
  doomwaddir: string;
  doomwadpath: string;
  paths: TDStringList;
  i: integer;
  tmp: string;
begin
  if fexists(fn) then
  begin
    result := fn;
    exit;
  end;

  doomwaddir := getenv('DOOMWADDIR');
  doomwadpath := getenv('DOOMWADPATH');

  paths := TDStringList.Create;
  if doomwaddir <> '' then
    paths.Add(doomwaddir);
  if doomwadpath <> '' then
  begin
    tmp := '';
    for i := 1 to length(doomwadpath) do
    begin
      if doomwadpath[i] = PATH_SEPARATOR then
      begin
        if tmp <> '' then
        begin
          paths.Add(tmp);
          tmp := '';
        end;
      end
      else
        tmp := tmp + doomwadpath[i];
    end;
    if tmp <> '' then
      paths.Add(tmp);
  end;

  for i := 0 to NUMSTEAMAPPS - 1 do
  begin
    tmp := QuerySteamDirectory(KEY_READ or KEY_WOW64_64KEY, steamapps[i]);
    if tmp = '' then
      tmp := QuerySteamDirectory(KEY_READ, steamapps[i]);
    if tmp <> '' then
    begin
      if tmp[length(tmp)] <> '\' then
        tmp := tmp + '\';
      paths.Add(tmp);
      paths.Add(tmp + 'base\');
      paths.Add(tmp + 'base\wads');
    end;
  end;

  result := fname(fn);
  for i := 0 to paths.Count - 1 do
  begin
    tmp := paths.Strings[i];
    if tmp[length(tmp)] <> '\' then
      tmp := tmp + '\';
    if fexists(tmp + result) then
    begin
      result := tmp + result;
      paths.free;
      exit;
    end;
  end;
  result := fn;
  paths.free;
end;

const
  SYSWAD = 'FPCDoom.wad';

procedure D_AddSystemWAD;
var
  fsyswad: string;
begin
  fsyswad := FileInDoomPath(SYSWAD);
  if fexists(fsyswad) then
    D_AddFile(fsyswad)
  else
    I_Error('D_AddSystemWAD(): System WAD %s not found.'#13#10, [fsyswad]);
end;

var
  doomcwad: string = ''; // Custom main WAD

procedure IdentifyVersion;
var
  doom1wad: string;
  doomwad: string;
  doomuwad: string;
  doom2wad: string;

  doom2fwad: string;
  plutoniawad: string;
  tntwad: string;
  doomwaddir: string;
  p: integer;
begin
  doomwaddir := getenv('DOOMWADDIR');
  if doomwaddir = '' then
    doomwaddir := '.';

  // Commercial.
  sprintf(doom2wad, '%s\doom2.wad', [doomwaddir]);

  // Retail.
  sprintf(doomuwad, '%s\doomu.wad', [doomwaddir]);

  // Registered.
  sprintf(doomwad, '%s\doom.wad', [doomwaddir]);

  // Shareware.
  sprintf(doom1wad, '%s\doom1.wad', [doomwaddir]);

  // plutonia pack
  sprintf(plutoniawad, '%s\plutonia.wad', [doomwaddir]);

  // tnt pack
  sprintf(tntwad, '%s\tnt.wad', [doomwaddir]);


  // French stuff.
  sprintf(doom2fwad, '%s\doom2f.wad', [doomwaddir]);

  basedefault := 'FPCDoom.ini';

  p := M_CheckParm('-mainwad');
  if p = 0 then
    p := M_CheckParm('-iwad');
  if (p > 0) and (p < myargc - 1) then
  begin
    inc(p);
    doomcwad := FileInDoomPath(myargv[p]);
    if fexists(doomcwad) then
    begin
      printf(' External main wad in use: %s'#13#10, [doomcwad]);
      gamemode := indetermined;
      D_AddFile(doomcwad);
      exit;
    end
    else
      doomcwad := '';
  end;

  if M_CheckParm('-shdev') > 0 then
  begin
    gamemode := shareware;
    devparm := true;
    D_AddFile(DEVDATA + 'doom1.wad');
    D_AddFile(DEVMAPS + 'data_se/texture1.lmp');
    D_AddFile(DEVMAPS + 'data_se/pnames.lmp');
    basedefault := DEVDATA + 'FPCDoom.ini';
    exit;
  end;

  if M_CheckParm('-regdev') > 0 then
  begin
    gamemode := registered;
    devparm := true;
    D_AddFile(DEVDATA + 'doom.wad');
    D_AddFile(DEVMAPS + 'data_se/texture1.lmp');
    D_AddFile(DEVMAPS + 'data_se/texture2.lmp');
    D_AddFile(DEVMAPS + 'data_se/pnames.lmp');
    basedefault := DEVDATA + 'FPCDoom.ini';
    exit;
  end;

  if M_CheckParm('-comdev') > 0 then
  begin
    gamemode := commercial;
    devparm := true;
    D_AddFile(DEVDATA + 'doom2.wad');

    D_AddFile(DEVMAPS + 'cdata/texture1.lmp');
    D_AddFile(DEVMAPS + 'cdata/pnames.lmp');
    basedefault := DEVDATA + 'FPCDoom.ini';
    exit;
  end;

  for p := 1 to 2 do
  begin
    if fexists(doom2fwad) then
    begin
      gamemode := commercial;
      gamemission := doom2;
      // C'est ridicule!
      // Let's handle languages in config files, okay?
      language := french;
      printf('French version'#13#10);
      D_AddFile(doom2fwad);
      exit;
    end;

    if fexists(doom2wad) then
    begin
      gamemode := commercial;
      gamemission := doom2;
      D_AddFile(doom2wad);
      exit;
    end;

    if fexists(plutoniawad) then
    begin
      gamemode := commercial;
      gamemission := pack_plutonia;
      D_AddFile(plutoniawad);
      exit;
    end;

    if fexists(tntwad) then
    begin
      gamemode := commercial;
      gamemission := pack_tnt;
      D_AddFile(tntwad);
      exit;
    end;

    if fexists(doomuwad) then
    begin
      gamemode := indetermined; // Will check if retail or register mode later
      gamemission := doom;
      D_AddFile(doomuwad);
      exit;
    end;

    if fexists(doomwad) then
    begin
      gamemode := indetermined; // Will check if retail or register mode later
      gamemission := doom;
      D_AddFile(doomwad);
      exit;
    end;

    if fexists(doom1wad) then
    begin
      gamemode := shareware;
      gamemission := doom;
      D_AddFile(doom1wad);
      exit;
    end;

    if p = 1 then
    begin
      doom2wad := FileInDoomPath(doom2wad);
      doomuwad := FileInDoomPath(doomuwad);
      doomwad := FileInDoomPath(doomwad);
      doom1wad := FileInDoomPath(doom1wad);
      plutoniawad := FileInDoomPath(plutoniawad);
      tntwad := FileInDoomPath(tntwad);
      doom2fwad := FileInDoomPath(doom2fwad);
    end;
  end;

  printf('Game mode indeterminate.'#13#10);
  gamemode := indetermined;
end;

//
// Find a Response File
//
// JVAL: Changed to handle more than 1 response files
procedure FindResponseFile;
var
  i: integer;
  handle: file;
  size: integer;
  index: integer;
  myargv1: string;
  infile: string;
  filename: string;
  s: TDStringList;
begin
  s := TDStringList.Create;
  try
    s.Add(myargv[0]);

    for i := 1 to myargc - 1 do
    begin
      if myargv[i][1] = '@' then
      begin
        // READ THE RESPONSE FILE INTO MEMORY
        myargv1 := Copy(myargv[i], 2, length(myargv[i]) - 1);
        if fopen(handle, myargv1, fOpenReadOnly) then
        begin
          printf('Found response file %s!'#13#10, [myargv1]);

          size := FileSize(handle);
          seek(handle, 0);
          SetLength(filename, size);
          BlockRead(handle, (@filename[1])^, size);
          close(handle);

          infile := '';
          for index := 1 to Length(filename) do
            if filename[index] = ' ' then
              infile := infile + #13#10
            else
              infile := infile + filename[i];

          s.Text := s.Text + infile;
        end
        else
          printf(#13#10'No such response file: %s!'#13#10, [myargv1]);
      end
      else
        s.Add(myargv[i])
    end;

    index := 0;
    for i := 0 to s.Count - 1 do
      if s[i] <> '' then
      begin
        myargv[index] := s[i];
        inc(index);
        if index = MAXARGS then
          break;
      end;
    myargc := index;
  finally
    s.Free;
  end;
end;

function D_Version: string;
begin
  sprintf(result, Apptitle + ' version %d.%d', [VERSION div 100, VERSION mod 100]);
end;

function D_VersionBuilt: string;
begin
  sprintf(result, ' built %s', [I_VersionBuilt]);
end;

procedure D_CmdVersion;
begin
  printf('%s,%s'#13#10, [D_Version, D_VersionBuilt]);
end;

procedure D_CmdAddPakFile(const parm: string);
var
  files: TDStringList;
  i: integer;
begin
  if parm = '' then
  begin
    printf('Please specify the pak file or directory to load'#13#10);
    exit;
  end;

  // JVAL
  // If a shareware game do not allow external files
  if gamemode = shareware then
  begin
    I_Warning('You cannot use external files with the shareware version. Register!'#13#10);
    exit;
  end;

  if (Pos('*', parm) > 0) or (Pos('?', parm) > 0) then // It's a mask
    files := findfiles(parm)
  else
  begin
    files := TDStringList.Create;
    files.Add(parm)
  end;

  try

    for i := 0 to files.Count - 1 do
      if not PAK_AddFile(files[i]) then
        I_Warning('PAK_AddFile(): %s could not be added to PAK file system.'#13#10, [files[i]]);

  finally
    files.Free;
  end;

end;

procedure D_StartThinkers;
begin
  Info_Init(true);
  printf('Thinkers initialized'#13#10);
end;

procedure D_StopThinkers;
begin
  if demoplayback then
  begin
    I_Warning('Thinkers can not be disabled during demo playback.'#13#10);
    exit;
  end;

  if demorecording then
  begin
    I_Warning('Thinkers can not be disabled during demo recording.'#13#10);
    exit;
  end;

  Info_Init(false);
  printf('Thinkers disabled'#13#10);
end;

procedure D_AddWADFiles(const parm: string);
var
  p: integer;
begin
  p := M_CheckParm(parm);
  if p <> 0 then
  begin
  // the parms after p are wadfile/lump names,
  // until end of parms or another - preceded parm
    modifiedgame := true; // homebrew levels
    inc(p);
    while (p < myargc) and (myargv[p][1] <> '-') do
    begin
      D_AddFile(FileInDoomPath(myargv[p]));
      inc(p);
    end;
  end;
end;

procedure D_AddPAKFiles(const parm: string);
var
  p: integer;
begin
  p := M_CheckParm(parm);
  if p <> 0 then
  begin
  // the parms after p are wadfile/lump names,
  // until end of parms or another - preceded parm
    modifiedgame := true; // homebrew levels
    externalpakspresent := true;
    inc(p);
    while (p < myargc) and (myargv[p][1] <> '-') do
    begin
      PAK_AddFile(myargv[p]);
      inc(p);
    end;
  end;
end;

procedure D_AddDEHFiles(const parm: string);
var
  p: integer;
begin
  p := M_CheckParm(parm);
  if p <> 0 then
  begin
  // the parms after p are wadfile/lump names,
  // until end of parms or another - preceded parm
    modifiedgame := true; // homebrew levels
    externaldehspresent := true;
    inc(p);
    while (p < myargc) and (myargv[p][1] <> '-') do
    begin
      DEH_ParseFile(myargv[p]);
      inc(p);
    end;
  end;
end;

procedure D_IdentifyGameDirectories;
var
  gamedirectorystring: string;
  i: integer;
  wad: string;
begin
  MakeDir(M_SaveFileName(SAVEGAMEPATH));
  SAVEGAMEIWAD := '';
  case gamemission of
    doom2:
      begin
        gamedirectorystring := 'DOOM2,DOOM1,DOOM';
        SAVEGAMEIWAD := 'DOOM2';
      end;
    pack_tnt:
      begin
        gamedirectorystring := 'TNT,DOOM2,DOOM1,DOOM';
        SAVEGAMEIWAD := 'TNT';
      end;
    pack_plutonia:
      begin
        gamedirectorystring := 'PLUTONIA,DOOM2,DOOM1,DOOM';
        SAVEGAMEIWAD := 'PLUTONIA';
      end
  else
    begin
      gamedirectorystring := 'DOOM1,DOOM';
      if gamemode = shareware then
        SAVEGAMEIWAD := 'DOOM1'
      else
        SAVEGAMEIWAD := 'DOOM';
    end;
  end;
  MakeDir(M_SaveFileName(SAVEGAMEPATH + '\' + SAVEGAMEIWAD));
  for i := wadfiles.Count - 1 downto 0 do
  begin
    wad := strupper(fname(wadfiles[i]));
    if Pos('.', wad) > 0 then
      wad := Copy(wad, 1, Pos('.', wad) - 1);
    if Pos(wad + ',', gamedirectorystring + ',') = 0 then
      gamedirectorystring := wad + ',' + gamedirectorystring;
  end;

  gamedirectories := PAK_GetDirectoryListFromString(gamedirectorystring);
  for i := 0 to gamedirectories.Count - 1 do
  begin
    wad := gamedirectories[i];
    if wad <> '' then
      if wad[length(wad)] = '\' then
        printf(' %s'#13#10, [gamedirectories[i]]);
  end;
end;

//
// D_DoomMain
//
procedure D_DoomMain;
var
  p: integer;
  filename: string;
  scale: integer;
  _time: integer;
  s_error: string;
  i: integer;
  j: integer;
  episodes: integer;
  err_shown: boolean;
  s1, s2: string;
begin
  outproc := @I_IOprintf;
  wadfiles := TDSTringList.Create;

  printf('Starting %s, %s'#13#10, [D_Version, D_VersionBuilt]);
  C_AddCmd('ver, version', @D_CmdVersion);
  C_AddCmd('addpakfile, loadpakfile, addpak, loadpak', @D_CmdAddPakFile);
  C_AddCmd('startthinkers', @D_StartThinkers);
  C_AddCmd('stopthinkers', @D_StopThinkers);

  printf('M_InitArgv: Initializing command line parameters.'#13#10);
  M_InitArgv;

  FindResponseFile;

  printf('I_InitializeIO: Initializing input/output streams.'#13#10);
  I_InitializeIO;

  D_AddSystemWAD; // Add system wad first

  IdentifyVersion;

  modifiedgame := false;

  nomonsters := M_CheckParm('-nomonsters') > 0;
  respawnparm := M_CheckParm('-respawn') > 0;
  fastparm := M_CheckParm('-fast') > 0;
  devparm := M_CheckParm('-devparm') > 0;

  if M_CheckParm('-altdeath') > 0 then
    deathmatch := 2
  else if M_CheckParm('-deathmatch') > 0 then
    deathmatch := 1;

  case gamemode of
    retail:
      begin
        printf(
           '                         ' +
           'The Ultimate DOOM Startup v%d.%d' +
           '                           '#13#10,
            [VERSION div 100, VERSION mod 100]);
      end;
    shareware:
      begin
        printf(
           '                            ' +
           'DOOM Shareware Startup v%d.%d' +
           '                           '#13#10,
            [VERSION div 100, VERSION mod 100]);
      end;
    registered:
      begin
        printf(
           '                            ' +
           'DOOM Registered Startup v%d.%d' +
           '                           '#13#10,
            [VERSION div 100, VERSION mod 100]);
      end;
    commercial:
      begin
        printf(
           '                         ' +
           'DOOM 2: Hell on Earth v%d.%d' +
           '                           '#13#10,
            [VERSION div 100, VERSION mod 100]);
      end;
  else
    begin
      printf(
         '                         ' +
         'Public DOOM - v%d.%d' +
         '                           '#13#10,
          [VERSION div 100, VERSION mod 100]);
    end;
  end;

  if devparm then
    printf(D_DEVSTR);

  if M_CheckParmCDROM then
    printf(D_CDROM);

  basedefault := M_SaveFileName('FPCDoom.ini');

  // turbo option
  p := M_CheckParm('-turbo');
  if p <> 0 then
  begin
    if p < myargc - 1 then
    begin
      scale := atoi(myargv[p + 1]);
      if scale < 10 then
        scale := 10
      else if scale > 200 then // 22/3/2012 (was 400)
        scale := 200;          // 22/3/2012 (was 400)
    end
    else
      scale := 200;
    printf(' turbo scale: %d'#13#10, [scale]);
    forwardmove[0] := forwardmove[0] * scale div 100;
    forwardmove[1] := forwardmove[1] * scale div 100;
    sidemove[0] := sidemove[0] * scale div 100;
    sidemove[1] := sidemove[1] * scale div 100;
  end;

  // add any files specified on the command line with -file wadfile
  // to the wad list
  //
  // convenience hack to allow -wart e m to add a wad file
  // prepend a tilde to the filename so wadfile will be reloadable
  p := M_CheckParm('-wart');
  if (p <> 0) and (p < myargc - 1) then
  begin
    myargv[p][5] := 'p';     // big hack, change to -warp

  // Map name handling.
    case gamemode of
      shareware,
      retail,
      registered:
        begin
          if p < myargc - 2 then
          begin
            sprintf(filename, '~' + DEVMAPS + 'E%sM%s.wad',
              [myargv[p + 1][1], myargv[p + 2][1]]);
            printf('Warping to Episode %s, Map %s.'#13#10,
              [myargv[p + 1], myargv[p + 2]]);
          end;
        end;
    else
      begin
        p := atoi(myargv[p + 1]);
        if p < 10 then
          sprintf(filename, '~' + DEVMAPS + 'cdata/map0%d.wad', [p])
        else
          sprintf (filename,'~' + DEVMAPS + 'cdata/map%d.wad', [p]);
      end;
    end;

    D_AddFile(filename);
  end;

  D_AddWADFiles('-file');
  for p := 1 to 9 do
    D_AddWADFiles('-file' + itoa(p));

  printf('PAK_InitFileSystem: Init PAK/ZIP/PK3/PK4 files.'#13#10);
  PAK_InitFileSystem;

  D_AddPAKFiles('-pakfile');
  for p := 1 to 9 do
    D_AddPAKFiles('-pakfile' + itoa(p));

  p := M_CheckParm('-playdemo');

  if p = 0 then
    p := M_CheckParm('-timedemo');

  if (p <> 0) and (p < myargc - 1) then
  begin
    inc(p);
    if Pos('.', myargv[p]) > 0 then
      filename := myargv[p]
    else
      sprintf(filename,'%s.lmp', [myargv[p]]);
    D_AddFile(filename);
    printf('Playing demo %s.'#13#10, [filename]);
  end;

  // get skill / episode / map from parms
  startskill := sk_medium;
  startepisode := 1;
  startmap := 1;
  autostart := false;

  p := M_CheckParm('-skill');
  if (p <> 0) and (p < myargc - 1) then
  begin
    startskill := skill_t(Ord(myargv[p + 1][1]) - Ord('1'));
    autostart := true;
  end;

  p := M_CheckParm('-episode');
  if (p <> 0) and (p < myargc - 1) then
  begin
    startepisode := atoi(myargv[p + 1]);
    startmap := 1;
    autostart := true;
  end;

  p := M_CheckParm('-timer');
  if (p <> 0) and (p < myargc - 1) and (deathmatch <> 0) then
  begin
    _time := atoi(myargv[p + 1]);
    printf('Levels will end after %d minute' + decide(_time > 1, 's', '') + #13#10, [_time]);
  end;

  p := M_CheckParm('-avg');
  if (p <> 0) and (p <= myargc - 1) and (deathmatch <> 0) then
    printf('Austin Virtual Gaming: Levels will end after 20 minutes'#13#10);

  printf('M_LoadDefaults: Load system defaults.'#13#10);
  M_LoadDefaults;              // load before initing other systems

  p := M_CheckParm('-fullscreen');
  if (p <> 0) and (p <= myargc - 1) then
    fullscreen := true;

  p := M_CheckParm('-nofullscreen');
  if p = 0 then
    p := M_CheckParm('-windowed');
  if (p <> 0) and (p <= myargc - 1) then
    fullscreen := false;

  p := M_CheckParm('-zaxisshift');
  if (p <> 0) and (p <= myargc - 1) then
    zaxisshift := true;

  p := M_CheckParm('-nozaxisshift');
  if (p <> 0) and (p <= myargc - 1) then
    zaxisshift := false;

  if M_Checkparm('-normalres') <> 0 then
    detailLevel := DL_NORMAL;

  if M_Checkparm('-mediumres') <> 0 then
    detailLevel := DL_MEDIUM;

  if M_Checkparm('-interpolate') <> 0 then
    interpolate := true;

  if M_Checkparm('-nointerpolate') <> 0 then
    interpolate := false;

  p := M_CheckParm('-compatibilitymode');
  if (p <> 0) and (p <= myargc - 1) then
    compatibilitymode := true;

  p := M_CheckParm('-nocompatibilitymode');
  if (p <> 0) and (p <= myargc - 1) then
    compatibilitymode := false;

  oldcompatibilitymode := compatibilitymode;

  p := M_CheckParm('-spawnrandommonsters');
  if (p <> 0) and (p <= myargc - 1) then
    spawnrandommonsters := true;

  p := M_CheckParm('-nospawnrandommonsters');
  if (p <> 0) and (p <= myargc - 1) then
    spawnrandommonsters := false;

  p := M_CheckParm('-mouse');
  if (p <> 0) and (p <= myargc - 1) then
    usemouse := true;

  p := M_CheckParm('-nomouse');
  if (p <> 0) and (p <= myargc - 1) then
    usemouse := false;

  p := M_CheckParm('-invertmouselook');
  if (p <> 0) and (p <= myargc - 1) then
    invertmouselook := true;

  p := M_CheckParm('-noinvertmouselook');
  if (p <> 0) and (p <= myargc - 1) then
    invertmouselook := false;

  p := M_CheckParm('-invertmouseturn');
  if (p <> 0) and (p <= myargc - 1) then
    invertmouseturn := true;

  p := M_CheckParm('-noinvertmouseturn');
  if (p <> 0) and (p <= myargc - 1) then
    invertmouseturn := false;

  p := M_CheckParm('-nojoystick');
  if (p <> 0) and (p <= myargc - 1) then
    usejoystick := false;

  p := M_CheckParm('-joystick');
  if (p <> 0) and (p <= myargc - 1) then
    usejoystick := true;

  p := M_CheckParm('-windowwidth');
  if (p <> 0) and (p < myargc - 1) then
    WINDOWWIDTH := atoi(myargv[p + 1]);
  if WINDOWWIDTH > MAXWIDTH then
    WINDOWWIDTH := MAXWIDTH;

  p := M_CheckParm('-windowheight');
  if (p <> 0) and (p < myargc - 1) then
    WINDOWHEIGHT := atoi(myargv[p + 1]);
  if WINDOWHEIGHT > MAXHEIGHT then
    WINDOWHEIGHT := MAXHEIGHT;

  p := M_CheckParm('-screenwidth');
  if (p <> 0) and (p < myargc - 1) then
    SCREENWIDTH := atoi(myargv[p + 1]);
  if SCREENWIDTH > MAXWIDTH then
    SCREENWIDTH := MAXWIDTH;

  p := M_CheckParm('-screenheight');
  if (p <> 0) and (p < myargc - 1) then
    SCREENHEIGHT := atoi(myargv[p + 1]);
  if SCREENHEIGHT > MAXHEIGHT then
    SCREENHEIGHT := MAXHEIGHT;

  p := M_CheckParm('-geom');
  if (p <> 0) and (p < myargc - 1) then
  begin
    splitstring(myargv[p + 1], s1, s2, ['X', 'x']);
    SCREENWIDTH := atoi(s1);
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := atoi(s2);
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  p := M_CheckParm('-fullhd');
  if (p <> 0) and (p < myargc) then
  begin
    SCREENWIDTH := 1920;
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := 1080;
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  p := M_CheckParm('-vga');
  if (p <> 0) and (p < myargc) then
  begin
    SCREENWIDTH := 640;
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := 480;
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  p := M_CheckParm('-svga');
  if (p <> 0) and (p < myargc) then
  begin
    SCREENWIDTH := 800;
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := 600;
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  p := M_CheckParm('-cga');
  if (p <> 0) and (p < myargc) then
  begin
    SCREENWIDTH := 320;
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := 200;
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  p := M_CheckParm('-cgaX2');
  if (p <> 0) and (p < myargc) then
  begin
    SCREENWIDTH := 640;
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := 400;
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  p := M_CheckParm('-cgaX3');
  if (p <> 0) and (p < myargc) then
  begin
    SCREENWIDTH := 960;
    if SCREENWIDTH > MAXWIDTH then
      SCREENWIDTH := MAXWIDTH;
    SCREENHEIGHT := 600;
    if SCREENHEIGHT > MAXHEIGHT then
      SCREENHEIGHT := MAXHEIGHT;
  end;

  if SCREENHEIGHT <= 0 then
    SCREENHEIGHT := I_ScreenHeight;
  if SCREENHEIGHT > MAXHEIGHT then
    SCREENHEIGHT := MAXHEIGHT
  else if SCREENHEIGHT < MINHEIGHT then
    SCREENHEIGHT := MINHEIGHT;

  if SCREENWIDTH <= 0 then
    SCREENWIDTH := I_ScreenWidth;
  if SCREENWIDTH > MAXWIDTH then
    SCREENWIDTH := MAXWIDTH
  else if SCREENHEIGHT < MINHEIGHT then
    SCREENWIDTH := MINWIDTH;

  SCREENWIDTH := SCREENWIDTH and not 1;
  SCREENHEIGHT := SCREENHEIGHT and not 1;

  if SCREENWIDTH < SCREENHEIGHT then
    SCREENWIDTH := SCREENHEIGHT;

  I_RestoreWindowPos;

  singletics := M_CheckParm('-singletics') > 0;


  nodrawers := M_CheckParm('-nodraw') <> 0;
  noblit := M_CheckParm('-noblit') <> 0;
  norender := M_CheckParm('-norender') <> 0;

  if M_CheckParm('-usetransparentsprites') <> 0 then
    usetransparentsprites := true;
  if M_CheckParm('-dontusetransparentsprites') <> 0 then
    usetransparentsprites := false;
  if M_CheckParm('-uselightmap') <> 0 then
    uselightmap := true;
  if M_CheckParm('-dontuselightmap') <> 0 then
    uselightmap := false;
  if M_CheckParm('-chasecamera') <> 0 then
    chasecamera := true;
  if M_CheckParm('-nochasecamera') <> 0 then
    chasecamera := false;

  // init subsystems
  printf('Z_Init: Init memory allocation daemon.'#13#10);
  Z_Init;

  p := M_CheckParm('-nothinkers');
  if p = 0 then
  begin
    printf('I_InitInfo: Initialize information tables.'#13#10);
    Info_Init(true);
  end
  else
  begin
    I_Warning('Thinkers not initialized.'#13#10);
    Info_Init(false);
  end;

  for p := 1 to myargc do
    if (strupper(fext(myargv[p])) = '.WAD') or (strupper(fext(myargv[p])) = '.OUT') then
      D_AddFile(myargv[p]);

  for p := 1 to myargc do
    if (strupper(fext(myargv[p])) = '.PK3') or
       (strupper(fext(myargv[p])) = '.PK4') or
       (strupper(fext(myargv[p])) = '.ZIP') or
       (strupper(fext(myargv[p])) = '.PAK') then
    begin
      modifiedgame := true;
      externalpakspresent := true;
      PAK_AddFile(myargv[p]);
    end;

  printf('W_Init: Init WADfiles.'#13#10);
  if (W_InitMultipleFiles(wadfiles) = 0) or (W_CheckNumForName('playpal') = -1) then
  begin
  // JVAL
  //  If none wadfile has found as far,
  //  we search the current directory
  //  and we use the first WAD we find
    filename := findfile('*.wad');
    if filename <> '' then
      I_Warning('Loading unspecified wad file: %s'#13#10, [filename]);
    D_AddFile(filename);
    if W_InitMultipleFiles(wadfiles) = 0 then
      I_Error('W_InitMultipleFiles(): no files found');
  end;

  printf('S_InitDEHExtraSounds: Initializing dehacked sounds.'#13#10);
  S_InitDEHExtraSounds;

  printf('DEH_Init: Initializing dehacked subsystem.'#13#10);
  DEH_Init;

  if M_CheckParm('-internalgamedef') = 0 then
    if not DEH_ParseLumpName('GAMEDEF') then
      I_Warning('DEH_ParseLumpName(): GAMEDEF lump not found, using defaults.'#13#10);

  if M_CheckParm('-nowaddehacked') = 0 then
    if not DEH_ParseLumpNames('DEHACKED') then
      printf('DEH_ParseLumpName(): DEHACKED lump not found.'#13#10);

  // JVAL Adding dehached files
  D_AddDEHFiles('-deh');
  D_AddDEHFiles('-bex');

  printf('SC_Init: Initializing script engine.'#13#10);
  SC_Init;
  if M_CheckParm('-noactordef') = 0 then
  begin
    printf('SC_ParseActordefLumps(): Parsing ACTORDEF lumps.'#13#10);
    SC_ParseActordefLumps;
  end;

  printf('Info_SaveActions: Saving state actions'#13#10);
  Info_SaveActions;

  for i := 0 to NUM_STARTUPMESSAGES - 1 do
    if startmsg[i] <> '' then
      printf('%s'#13#10, [startmsg[i]]);

  printf('T_Init: Initializing texture manager.'#13#10);
  T_Init;

  printf('V_Init: allocate screens.'#13#10);
  V_Init;

  printf('AM_Init: initializing automap.'#13#10);
  AM_Init;

  printf('C_Init: Initializing console.'#13#10);
  C_Init;

  p := M_CheckParm('-autoexec');
  if (p <> 0) and (p < myargc - 1) then
    autoexecfile := myargv[p + 1]
  else
    autoexecfile := M_SaveFileName(DEFAUTOEXEC);

  printf('M_InitMenus: Initializing menus.'#13#10);
  M_InitMenus;

  if gamemode = indetermined then
  begin
    if W_CheckNumForName('e4m1') <> -1 then
    begin
      gamemission := doom;
      gamemode := retail;
    end
    else if W_CheckNumForName('e3m1') <> -1 then
    begin
      gamemission := doom;
      gamemode := registered;
    end
    else if W_CheckNumForName('e1m1') <> -1 then
    begin
      gamemission := doom;
      gamemode := shareware
    end
    else if W_CheckNumForName('map01') <> -1 then
    begin
      gamemode := commercial;
      if Pos('TNT.WAD', strupper(doomcwad)) > 0 then
        gamemission := pack_tnt
      else if Pos('PLUTONIA.WAD', strupper(doomcwad)) > 0 then
        gamemission := pack_plutonia
      else
        gamemission := doom2;
    end
    else
      I_Error('Game mode indetermined'#13#10);
  end;

  printf('D_IdentifyGameDirectories: Identify game directories.'#13#10);
  D_IdentifyGameDirectories;

  p := M_CheckParm('-warp');
  if (p <> 0) and (p < myargc - 1) then
  begin
    if gamemode = commercial then
    begin
      startmap := atoi(myargv[p + 1]);
      autostart := true;
    end
    else
    begin
      if p < myargc - 2 then
      begin
        startepisode := atoi(myargv[p + 1]);
        startmap := atoi(myargv[p + 2]);
        autostart := true;
      end;
    end;
  end;

  // Check for -file in shareware
  // JVAL
  // Allow modified games if -devparm is specified, for debuging reasons
  if modifiedgame and (not devparm) then
  begin
    err_shown := false;
    if gamemode = shareware then
    begin
      I_DevError(#13#10 + 'D_DoomMain(): You cannot use external files with the shareware version. Register!');
      err_shown := true;
    end;
  // Check for fake IWAD with right name,
  // but w/o all the lumps of the registered version.
    if not err_shown and (gamemode in [registered, retail]) then
    begin
  // These are the lumps that will be checked in IWAD,
  // if any one is not present, execution will be aborted.
      s_error := #13#10 + 'D_DoomMain(): This is not the registered version.';
      episodes := 3;
      if gamemode = retail then
        inc(episodes);
      for i := 2 to episodes do
        for j := 1 to 9 do
          if W_CheckNumForName('e' + itoa(i) + 'm' + itoa(j)) < 0 then
          begin
            if not err_shown then
              I_DevError(s_error);
            err_shown := true;
          end;
      if not err_shown then
      begin
        if W_CheckNumForName('dphoof') < 0 then
          I_DevError(s_error)
        else if W_CheckNumForName('bfgga0') < 0 then
          I_DevError(s_error)
        else if W_CheckNumForName('heada1') < 0 then
          I_DevError(s_error)
        else if W_CheckNumForName('cybra1') < 0 then
          I_DevError(s_error)
        else if W_CheckNumForName('spida1d1') < 0 then
          I_DevError(s_error);
      end;
    end;

  // If additonal PWAD files are used, print modified message
    printf(MSG_MODIFIEDGAME);
  end;

  case gamemode of
    shareware,
    indetermined:
      printf(MSG_SHAREWARE);
    registered,
    retail,
    commercial:
      printf(MSG_COMMERCIAL);
  else
    begin
      printf(MSG_UNDETERMINED);
    end;
  end;

  printf('Info_InitRandom: Initializing randomizers.'#13#10);
  Info_InitRandom;

  printf('M_Init: Init miscellaneous info.'#13#10);
  M_Init;

  p := M_CheckParm('-mmx');
  if p > 0 then
    usemmx := true;

  p := M_CheckParm('-nommx');
  if p > 0 then
    usemmx := false;

  printf('I_DetectCPU: Detecting CPU extensions.'#13#10);
  I_DetectCPU;

  printf('R_Init: Init DOOM refresh daemon.');
  R_Init;

  printf(#13#10 + 'P_Init: Init Playloop state.'#13#10);
  P_Init;


  printf('I_Init: Setting up machine state.'#13#10);
  I_Init;

  printf('D_CheckNetGame: Checking network game status.'#13#10);
  D_CheckNetGame;

  printf('S_Init: Setting up sound.'#13#10);
  S_Init(snd_SfxVolume, snd_MusicVolume);

  printf('HU_Init: Setting up heads up display.'#13#10);
  HU_Init;

  printf('ST_Init: Init status bar.'#13#10);
  ST_Init;

  printf('I_DetectNativeScreenResolution: Detect native screen resolution.'#13#10);
  I_DetectNativeScreenResolution;

// check for a driver that wants intermission stats
  p := M_CheckParm('-statcopy');
  if (p > 0) and (p < myargc - 1) then
  begin
  // for statistics driver
    statcopy := pointer(atoi(myargv[p + 1]));
    printf('External statistics registered.'#13#10);
  end;

  // start the apropriate game based on parms
  p := M_CheckParm('-record');

  if (p <> 0) and (p < myargc - 1) then
  begin
    G_RecordDemo(myargv[p + 1]);
    autostart := true;
  end;

  p := M_CheckParm('-playdemo');
  if (p <> 0) and (p < myargc - 1) then
  begin
  // JVAL
  /// if -nosingledemo param exists does not
  // quit after one demo
    singledemo := M_CheckParm('-nosingledemo') = 0;
    G_DeferedPlayDemo(myargv[p + 1]);
    D_DoomLoop;  // never returns
  end;

  p := M_CheckParm('-timedemo');
  if (p <> 0) and (p < myargc - 1) then
  begin
    G_TimeDemo(myargv[p + 1]);
    D_DoomLoop;  // never returns
  end;

  p := M_CheckParm('-loadgame');
  if (p <> 0) and (p < myargc - 1) then
  begin
    sprintf(filename, M_SaveFileName(SAVEGAMEPATH + '\' + SAVEGAMEIWAD + '\' + SAVEGAMENAME) + '%s.dsg', [myargv[p + 1][1]]);
    G_LoadGame(filename);
  end;

  if gameaction <> ga_loadgame then
  begin
    if autostart or netgame then
    begin
      G_InitNew(startskill, startepisode, startmap);
    end
    else
      D_StartTitle; // start up intro loop
  end;

  D_DoomLoop;  // never returns
end;

function D_IsPaused: boolean;
begin
  result := paused;
end;

procedure D_ShutDown;
var
  i: integer;
begin
  printf('C_ShutDown: Shut down console.'#13#10);
  C_ShutDown;
  printf('R_ShutDown: Shut down DOOM refresh daemon.');
  R_ShutDown;
  printf('Info_ShutDownRandom: Shut down randomizers.'#13#10);
  Info_ShutDownRandom;
  printf('T_ShutDown: Shut down texture manager.'#13#10);
  T_ShutDown;
  printf('M_ShutDown: Shut down menus.'#13#10);
  M_ShutDown;
  printf('SC_ShutDown: Shut down script engine.'#13#10);
  SC_ShutDown;
  printf('DEH_ShutDown: Shut down dehacked subsystem.'#13#10);
  DEH_ShutDown;
  printf('Info_ShutDown: Shut down game definition.'#13#10);
  Info_ShutDown;
  printf('PAK_ShutDown: Shut down PAK/ZIP/PK3/PK4 file system.'#13#10);
  PAK_ShutDown;
  printf('E_ShutDown: Shut down ENDOOM screen.'#13#10);
  E_ShutDown;
  printf('Z_ShutDown: Shut down zone memory allocation daemon.'#13#10);
  Z_ShutDown;
  printf('W_ShutDown: Shut down WAD file system.'#13#10);
  W_ShutDown;
  printf('V_ShutDown: Shut down screens.'#13#10);
  V_ShutDown;

  gamedirectories.Free;

  if wadfiles <> nil then
  begin
    for i := 0 to wadfiles.Count - 1 do
      if wadfiles.Objects[i] <> nil then
        wadfiles.Objects[i].Free;

    wadfiles.Free;
  end;

end;

end.

