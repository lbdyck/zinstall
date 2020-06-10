/* REXX */
  /* ---------------------------------------------------------- *
  | Name:      zinstall                                        |
  |                                                            |
  | Function:  ZIGI Package Installation Script                |
  |                                                            |
  | Syntax:    %zinstall                                       |
  |                                                            |
  | Usage Notes:                                               |
  |            1. Prompt for                                   |
  |               - default HLQ to be used                     |
  |            2. Sequential files that have no lowercase      |
  |               will be processed.                           |
  |            3. Directories that are all uppercase will      |
  |               be assumed to be PDS directories             |
  |                                                            |
  | Post Install Notes:                                        |
  |            Consider using the ZGSTAT exec with this        |
  |            tool to provide a complete package.             |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            06/10/20 LBD - Tweak for zgstat.exec dsn        |
  |            06/09/20 LBD - Creation from zigickot           |
  | ---------------------------------------------------------- |
  |    zigi - the z/OS ISPF Git Interface                      |
  |    Copyright (C) 2020 - Henri Kuiper and Lionel Dyck       |
  |                                                            |
  |    This program is free software: you can redistribute it  |
  |    and/or modify it under the terms of the GNU General     |
  |    Public License as published by the Free Software        |
  |    Foundation, either version 3 of the License, or (at     |
  |    your option) any later version.                         |
  |                                                            |
  |    This program is distributed in the hope that it will be |
  |    useful, but WITHOUT ANY WARRANTY; without even the      |
  |    implied warranty of MERCHANTABILITY or FITNESS FOR A    |
  |    PARTICULAR PURPOSE.  See the GNU General Public License |
  |    for more details.                                       |
  |                                                            |
  |    You should have received a copy of the GNU General      |
  |    Public License along with this program.  If not, see    |
  |    <https://www.gnu.org/licenses/>.                        |
  * ---------------------------------------------------------- */

/* ------------------- *
 | Prompt for z/OS HLQ |
 * ------------------- */
  say 'Enter the z/OS High Level Qualifier to use:'
  pull ckothlq
  if ckothlq = '' then do
    say 'no qualifier entered - exiting for now.'
    exit 8
  end
  ckothlq = translate(ckothlq)

/* --------------------- *
 | Get current directory |
 * --------------------- */
  cmd = 'pwd'
  x = bpxwunix(cmd,,so.,se.)
  ckotdir = strip(so.1)

  /* -------------------------------------------------------- *
  | Issue the ls command to get file names and sizes for all |
  | files in the current directory and sub-directories.      |
  * -------------------------------------------------------- */
  cmd = 'ls -laRk' ckotdir
  rc = bpxwunix(cmd,,stdout.,stderr.)

  /* ---------------------------------------------- *
  | Display any error messages and if so then exit |
  * ---------------------------------------------- */
  if stderr.0 > 0 then do
    do i = 1 to stderr.0
      say stderr.i
    end
    exit 8
  end

  /* ------------------------- *
  | Define our work variables |
  * ------------------------- */
  parse value '' with subs files null zgstat_dsn
  mgen = 0
  hit = 0
  filec = 0

  /* ------------------------------------ *
  | Read in ../.zigi/dsn to get dcb info |
  * ------------------------------------ */
  cmd = 'cd' ckotdir '&& ls -la .zigi'
  x = bpxwunix(cmd,,co.,ce.)
  if x > 0 then do
    def_recfm = 'FB'
    def_lrecl = 80
    def_blksize = 32720
    def. = null
  end
  else do
    ckdd = 'ck'time('s')
    x = bpxwunix("cat '"ckotdir"/.zigi/dsn'",,ck.)
    def. = null
    zdsn. = null
    do i = 1 to ck.0
      if left(ck.i,1) = '#' then iterate
      if word(ck.i,1) = '*' then do
        parse value ck.i with . def_dsorg def_recfm def_lrecl def_blksize .
      end
      else do
        dsn = word(ck.i,1)          /* dataset name less hlq */
        def.dsn = subword(ck.i,2)   /* dataset dsorg  */
        zdsn.dsn = word(ck.i,6)     /* file extension */
      end
    end
  end

  Address TSO

  /* ------------------------------- *
  | Get the list of Binary Datasets |
  * ------------------------------- */
  call get_binfiles

  /* ---------------------------------------------------- *
  | Process the results of the ls command to:            |
  | 1. collect number of members per sub-directory       |
  | 2. collect bytes count (in k) for each sub-directory |
  | 3. collect info on sequential files                  |
  * ---------------------------------------------------- */
  if stdout.0 > 0 then
  do i = 1 to stdout.0
    select
      when pos(ckotdir,stdout.i) > 0 then do
        parse value stdout.i with (ckotdir)sub':'
        if left(sub,1) = '/' then sub = substr(sub,2)
        if strip(sub) /= '' then do
          size.sub = 0
          dir.sub = 0
          si = 0
          if left(sub,1) /= '.' then do
            subs = subs sub
          end
        end
      end
      when word(stdout.i,1) = 'total' then do
        hit = hit + 1
      end
      when hit > 1 & left(stdout.i,1) = '-' then
      if strip(sub) /= '' then do
        size.sub = size.sub + word(stdout.i,5)
        dir.sub = dir.sub + 1
      end
      when hit = 1 & left(stdout.i,1) = '-' then do
        file = word(stdout.i,9)
        if left(file,1) = '.' then iterate
        fx = translate(file,'??????????????????????????', ,
          'abcdefghijklmnopqrstuvwxyz')
        if pos('?',fx) > 0 then iterate
        size.file =  word(stdout.i,5)
        files = files file
      end
      otherwise nop
    end
  end

  /* -------------------------------------------- *
  | Process the individual files, if any         |
  | Allocation and Copy                          |
  * -------------------------------------------- */
  do i = 1 to words(files)
    parse value '' with zs1 zs2 zs3 zs4 zs5 zs6 zs7 zs8 zs9
    sub = word(files,i)
    fileg = "'"ckothlq"."sub"'"
    odir = "'"ckotdir"/"sub"'"
    bin = is_binfile(sub)
    if bin = 1 then type = 'Binary'
    else type = 'Text'
    say 'Copying' odir 'to' fileg 'as' type
    filec = filec + 1
    zfile.filec = fileg type
    x = check_file(fileg)
    if x = 0 then do
      call outtrap 'x.'
      Address TSO ,
        'delete' fileg
      call outtrap 'off'
    end
    tracks =  (size.sub%50000 + 1) * 2
    call get_dcb
    'alloc ds('fileg') new spa('tracks','tracks') tr dsorg(ps)' ,
      'recfm('recfm') lrecl('lrecl') blksize('blksize')'
    'free ds('fileg')'
    'oget' odir fileg type
  end

  /* -------------------------------------------- *
  | Process the sub-directories and initiate the |
  | Allocation and Copy                          |
  | Ignore subdirectories                        |
  * -------------------------------------------- */
  do isub = 1 to words(subs)
    parse value '' with zs1 zs2 zs3 zs4 zs5 zs6 zs7 zs8 zs9
    sub = word(subs,isub)
    bin = is_binfile(sub)
    if bin = 1 then type = 'Binary'
    else type = 'Text'
    fx = translate(sub,'??????????????????????????', ,
      'abcdefghijklmnopqrstuvwxyz')
    if pos('?',fx) > 0 then iterate
    tracks =  (size.sub%50000 + 1) * 2
    call alloc_copy_pds
  end

  say ' '
  say 'Completed - z/OS datasets created:'
  say ' '
  do i = 1 to filec
    say zfile.i
  end
  say ' '
  say 'Note that using this installation path does not allow the ISPF'
  say 'statistics to be recreated. Other than the missing ISPF statistics'
  say 'everything has been successfully installed on z/OS.'
  say ' '
  say 'To recreate the ISPF statistics use the ZGSTAT REXX program that is'
  say 'included with this  package in' "'"zgstat_dsn"'"
  say ' '
  say 'When under ISPF issue the command: TSO EX' "'"zgstat_dsn"(ZGSTAT)' EX"
  say ' '
  say 'When prompted respond thus:'
  say ' '
  say 'Enter the z/OS Dataset HLQ (Prefix):'
  say '> Respond with:' ckothlq
  say ' '
  say 'Enter the OMVS Directory for the Repository:'
  say '> Respond with:' ckotdir
  say ' '

  Exit

  /* ----------------------------------------------------- */
  /* number format code thanks to Doug Nadel               */
  /* ----------------------------------------------------- */
fix_num: procedure
  arg bytes
  str=strip(translate('0,123,456,789,abc,def', ,
    right(bytes,16,','), ,
    '0123456789abcdef'),'L',',')
  bytes = strip(str)
  return bytes

  /* ----------------------------------------------------------------- *
  | Allocate the PDS and perform the copy using cp                    |
  | - if the target PDS exists as a PDS, delete and realloc as a PDSE |
  | - if the target is a PDSE then it will NOT be reallocated         |
  | - The target PDS will be allocated as a PDSE version 2.           |
  | - if maxgen (mgen) is provided then member generations will       |
  |   also be defined at allocation                                   |
  | - Uppercase and remove defined extension for members              |
  * ----------------------------------------------------------------- */
Alloc_Copy_PDS:
  pds = "'"ckothlq"."sub"'"
  odir = "'"ckotdir"/"sub"/'"
  if pos('ZGSTAT.EXEC',pds) > 0 then zgstat_dsn = strip(pds,'B',"'")
  filec = filec + 1
  zfile.filec = pds
  x = check_file(pds)
  if x = 0 then do
    call outtrap 'x.'
    Address TSO ,
      'delete' pds
    call outtrap 'off'
  end
  call get_dcb
  if recfm = 'U' then do
    type = 'Load module'
  end
  say 'Copying' odir 'to' pds
  if mgen > 0 then gens = 'maxgens('mgen')'
  else gens = null
  'Alloc new spa('tracks','tracks') recfm('recfm') lrecl('lrecl')' ,
    'Blksize('blksize') Dsntype(Library,2) dsorg(po) dir(1)' ,
    'dsn('pds')' gens
  'Free ds('pds')'
  /* ---------------------------------------------------- *
  | Read directory to get all member file names and then |
  | adjust according and then do individual cp           |
  * ---------------------------------------------------- */
  target = strip(pds,'B',"'")
  /* Comment Start
  call syscalls 'ON'
     Comment End */
  address syscall
  rdir = strip(odir,'B',"'")
  rdir = strip(rdir,'T','/')
  'readdir' rdir 'mems.'

  mcount = 0
  tcount = mems.0 - 2
  do ii = 1 to mems.0
    if mems.ii = "." | mems.ii = ".." then do
      /* skip the . and .. things */
      iterate
    end
    m = mems.ii    /* ignore the translation */
    if zdsn.sub /= null then
    if right(m,length(zdsn.sub)) = zdsn.sub then do
      parse value m with m'.'.
      m = translate(m)
    end
    src = rdir'/'mems.ii
    bin = is_binfile(sub'/'mems.ii)
    if bin = 1 then binopt = '-B'
    else binopt = null
    if recfm = 'U' then binopt = '-X -I'
    src = usssafe(mems.ii)
    if left(src,1) = '#' then src = '\'src
    zos = usssafe("//'"target"("m")'")
    mcount = mcount + 1
    if binopt = null then type = 'Text'
    else if binopt = '-B' then  type = 'Binary'
    else if recfm = 'U' then type = 'Load module'
    say left('Copying' mcount 'of' tcount,24) 'Member:' m 'as' type
    cmd = 'cd' usssafe(rdir)
    cmd = cmd '&& cp -U -v' binopt src '"'zos'"'
    x = docmd(cmd)
    if x > 0 then do
      say ' '
      say 'Standard messages:'
      say ' '
      do vs = 1 to so.0;say so.vs;end
      say ' '
      say 'Error messages:'
      say ' '
      do vs = 1 to se.0;say se.vs;end
    end
  end
  return

get_dcb:
  if def.sub /= null then do
    parse value def.sub with dsorg recfm lrecl blksize .
    recfm = left(recfm,1) substr(recfm,2,1) substr(recfm,3,1)
  end
  else do
    recfm = left(def_recfm,1) substr(def_recfm,2,1) substr(def_recfm,3,1)
    lrecl = def_lrecl
    blksize = def_blksize
  end
  return

Check_File: Procedure
  arg dsn
  call outtrap 'x.'
  Address TSO 'Listd' dsn
  call outtrap 'off'
  if x.0 = 1 then return 8
  else return 0

usssafe: procedure
  parse arg dsn
  if pos('$',dsn) = 0 then return dsn
  /* Let's not usssafe it twice :) */
  if pos('\$',dsn) > 0 then return dsn
  dsn = strreplace(dsn, '$', '\$')
  return dsn

strreplace: Procedure
  string  = arg(1)
  strfrom = arg(2)
  strto   = arg(3)
  null = ''
  if pos(strfrom,string) = 0 then return string
  newString = null
  do i = 1 to length(string)
    if substr(string,i,1) /= strfrom
    then newstring = newstring''substr(string,i,1)
    else  newstring = newstring''strto
  end
  return newstring

get_binfiles:
  /* ---------------------------------------------------------\
  | Name:      binfiles                                        |
  |                                                            |
  | Function:  Fills the global binfiles. stem with all        |
  |            current repo files that are added as binary.    |
  \---------------------------------------------------------- */
  cmd = 'cd' ckotdir'/ &&'
  cmd = 'cat -W filecodeset=UTF-8,pgmcodeset=IBM-1047' ckotdir'/.gitattributes'
  cmd = cmd ' | grep git-encoding=BINARY'
  cmd = cmd '| cut -d" " -f1'
  x = docmd(cmd)
  if so.0 = 0 then do
    binfiles.0 = 0
    return 0
  end
  do b = 1 to so.0
    binfiles.b = so.b
  end
  binfiles.0 = so.0
  return 0

is_binfile: procedure expose binfiles.
  /* ---------------------------------------------------------\
  | Name:      is_binfile                                      |
  |                                                            |
  | Function:  Checks the global binfiles. stem for the        |
  |            provided dataset or dataset/member              |
  \---------------------------------------------------------- */
  parse arg file
  if datatype(binfiles.0) /= 'NUM' then return 0
  do bi = 1 to binfiles.0
    if right(binfiles.bi,1) = '*' then do
      parse value file with test'/'.
      if left(binfiles.bi,length(binfiles.bi)-2) = test
      then return 1
    end
    if binfiles.bi = file then return 1
  end
  return 0

docmd:
  parse arg cmd
  drop so. se.
  x = bpxwunix(cmd,,so.,se.)
  return x
