  /*---------------------  rexx procedure  -------------------- *
  | Name:      ZGSTAT                                          |
  |                                                            |
  | Function:  To work with the ZIGI Generic Installation      |
  |            tool to add the ISPF statistics to the ZIGI     |
  |            managed partitioned datasets after they have    |
  |            been created by the ZGINSTALL.                  |
  |                                                            |
  | Syntax:    %zgstat hlq directory                           |
  |                                                            |
  |            HLQ is the z/OS HLQ used during the ZGINSTALL   |
  |                                                            |
  |            directory is the OMVS directory where the       |
  |            ZGINSTALl was run from                          |
  |                                                            |
  |            It the options are not provided then they       |
  |            will be prompted for.                           |
  |                                                            |
  | Dependencies: Uses a modified copy of the ZIGI zigistat    |
  |               exec                                         |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            06/09/20 LBD - Creation                         |
  |                                                            |
  | ---------------------------------------------------------- |
  |    ZIGI - the z/OS ISPF Git Interface                      |
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
  parse arg hlq repodir

  if hlq = '' then do
     say 'ZIGI Git Repository ISPF Statistics Utility'
     say '-------------------------------------------'
     say ' '
     say 'Enter the requested values or blank to exit.'
     say ' '
     say 'Enter the z/OS Dataset HLQ (Prefix):'
     pull hlq
     if strip(hlq) = '' then call cancel
     say 'Enter the OMVS Directory for the Repository:'
     parse pull repodir
     if strip(repodir) = '' then call cancel
     end

  hlq = translate(hlq)

  repodir = repodir
  address syscall
  'readdir' repodir 'files.'

  if files.0 = 0 then do
     say ' '
     say 'The directory specified is not the correct directory.'
     say 'Try again.'
     exit 8
     end

  do i = 1 to files.0
    file = files.i
    if left(file,1) = '.' then iterate
    /* check for lower case so ignore these */
    fx = translate(file,'??????????????????????????', ,
      'abcdefghijklmnopqrstuvwxyz')
    if pos('?',fx) > 0 then iterate
    dsname = "'"hlq"."file"'"
    x = zigistat(dsname repodir'/.zigi/'file 'U')
  end
  exit

Cancel:
  Say 'ZGSTAT utility canceled.'
  exit 8

  /* --------------------  rexx procedure  -------------------- *
  | Name:      zigistat                                        |
  |                                                            |
  | Function:  Collect or Compare the ISPF Stats for all       |
  |            members in a PDS                                |
  |                                                            |
  | Syntax:    x=zigistat(dsname filepath option)              |
  |                                                            |
  |            dsname is the z/OS dataset name to work with    |
  |                                                            |
  |            filepath is the OMVS file where the stats are   |
  |            stored and consists of:                         |
  |                localdir/repodir/.ZIGI/filename             |
  |                filename is the OMVS file that represents   |
  |                the z/OS PDS dataset name                   |
  |                                                            |
  | Options:   C - compare stats                               |
  |            S - save stats                                  |
  |            U - update stats to those saved                 |
  |                used when creating/refreshing datasets      |
  |                                                            |
  | Vars:      statmems ispf variable for selective update     |
  |                                                            |
  | Usage                                                      |
  |   Notes: Subroutine of ZIGI                                |
  |          Returns string of members changed                 |
  |                                                            |
  | Dependencies:                                              |
  |          ISPF services                                     |
  |                                                            |
  | Return:                                                    |
  |          0 - stats saved or stats applied                  |
  |          8 - no dsname provided                            |
  |         12 - no filepath provided                          |
  |         16 - no option provided                            |
  |         20 - stats file in /.zigi missing                  |
  |     string - string of members with different stats        |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            06/09/20 LBD - Modified and included here       |
  |            06/09/20 LBD - Bypass stat update for lmod      |
  |            05/08/20 LBD - Support Load Libraries           |
  |            01/08/20 LBD - Selecitve stat update if statmems|
  |            01/05/20 LBD - Correct special chars in filepath|
  |                           using usssafe routine            |
  |            11/22/19 LBD - If a member has no stats - add   |
  |            11/18/19 LBD - Many fixes and add Debug         |
  |            11/15/19 LBD - Creation                         |
  |                                                            |
  | ---------------------------------------------------------- |
  |    ZIGI - the z/OS ISPF Git Interface                      |
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
zigistat: Procedure

  /* --------------- *
  | Define defaults |
  * --------------- */
  parse value '' with null string m. rx allmems
  zdd = 'ZS'time('s')

  /* --------------------------------- *
  | Check for parms and return if not |
  * --------------------------------- */
  parse arg dsn filepath opt
  if dsn      = null then return 8
  if filepath = null then return 12
  if opt      = null then return 16
  opt         = translate(opt)   /* make upper case */

  /* --------------------------------------- *
  | If option C or U then read in the stats |
  | - check if stats member exists rc=16    |
  | - read into stem stats.                 |
  * --------------------------------------- */
  if pos(opt,'C U') > 0 then do
    x = check_stats_file(filepath)
    rc = x
    if rc > 0 then return x
    drop stats.
    cmd = 'cat' usssafe(filepath)
    x = bpxwunix(cmd,,stats.,se.)
    do i = 1 to stats.0
      stats.i = translate(stats.i,' ','0D'x)
    end
  end

  /* ------------------ *
  * Define ISPF Dataid *
  * ------------------ */
  Address ISPExec
  "LMINIT DATAID(STATUS) DATASET("dsn")"
  "LMOPEN DATAID("STATUS") OPTION(INPUT)"

  /* ---------------------------------- *
  | Get dataset recfm (check for lmod) |
  * ---------------------------------- */
  x = listdsi(dsn)

  /* ------------ *
  * Set defaults *
  * ------------ */
  parse value null with member mem. ,
    ZLCDATE ZLMDATE ZLVERS ZLMOD ZLMTIME ZLCNORC,
    ZLINORC ZLMNORC ZLUSER ,
    zlcnorce zlinorce zlmnorce ,
    zlsize zlamod zlrmode zlattr zlalias zlssi
  mem.0  = 0

  /* ----------------------- *
  * Now process all members *
  * ----------------------- */
  do forever
    "LMMLIST Dataid("status") OPTION(LIST) MEMBER(MEMBER)" ,
      "STATS(YES)"
    /* --------------------------------- *
    * If RC 4 or more leave the do loop *
    * --------------------------------- */
    if rc > 3 then leave
    /* -------------------------------- *
    | Check if no stats then add them. |
    * -------------------------------- */
    if sysrecfm /= 'U' then
    if zlcdate = null then do
      'LMMSTATS DATAID('status') Member('member') user('sysvar(sysuid)')'
      "LMMFind DATAID("status") Member("member") STATS(YES)"
    end
    /* ------------------------------ *
    * Add each member info to a stem *
    * ------------------------------ */
    c = mem.0 + 1
    if sysrecfm /= 'U'
    then mem.c = strip(member ,
      ZLCDATE  ZLMDATE  ZLVERS ZLMOD ZLMTIME ZLCNORC ,
      ZLINORC ZLMNORC ZLUSER ,
      zlcnorce zlinorce zlmnorce)
    else mem.c = strip(member ,
      zlsize zlamod zlrmode zlattr zlalias zlssi)
    mem.0 = c
    if opt = 'C' then allmems = allmems member
  end

  /* ------------------------- *
  * Close and Free the Dataid *
  * ------------------------- */
  "LMClose Dataid("status")"
  "LMFree  Dataid("status")"

  /* ----------------------------------------------- *
  | Process the data based on the provided options: |
  |                                                 |
  |    C - compare stats                            |
  |    S - save stats                               |
  |    U - update stats to those saved              |
  |        used when creating/refreshing datasets   |
  * ----------------------------------------------- */
  Select
    /* ---------------------------------------------------------- *
    | Update ISPF Stats:                                         |
    |  - all members in the ZIGI stats member will have their    |
    |    ispf stats updated to reflect the saved stats           |
    |  - Use statmems ispf var for selective stat updates        |
    |  - new members will not be updated as we don't know about  |
    |   them                                                     |
    |  - members with no stats will have stats added if they are |
    |    in the saved stats member                               |
    * ---------------------------------------------------------- */
    When opt = 'U' then
    if sysrecfm /= 'U' then do
      'vget (statmems)'
      if statmems /= null then do
      end
      "LMINIT DATAID(zstats) DATASET("dsn")"
      "LMOPEN DATAID("zstats") OPTION(INPUT)"
      do i = 1 to stats.0
        parse value stats.i with member ZLCDATE ZLMDATE ZLVERS ZLMOD ,
          ZLMTIME ZLCNORC ZLINORC ZLMNORC ZLUSER ZLCNORCE ,
          ZLINORCE ZLMNORCE .
        if statmems /= null then
        if wordpos(member,statmems) = 0 then iterate
        if zlcdate = null then ,
          'LMMSTATS DATAID('zstats') Member('member') user('sysvar(sysuid)')'
        else ,
          'LMMSTATS DATAID('zstats') MEMBER('member') VERSION('zlvers')' ,
          'MODLEVEL('zlmod') CREATED('zlcdate') MODDATE('zlmdate')' ,
          'MODTIME('zlmtime') INITSIZE('zlinorc')' ,
          'MODRECS('zlmnorc') USER('zluser')'
      end
      "LMClose Dataid("zstats")"
      "LMFree  Dataid("zstats")"
      return 0
    end
    /* ----------------------------------------------------------- *
    | Compare ISPF stats.                                         |
    |                                                             |
    | Comparison will be from the active datasets ISPF stats with |
    | the saved stats found in ISPF stats file in /.zigi          |
    |                                                             |
    | If a member is in the active but not in the saved list then |
    | it will be added to the returned string.                    |
    |                                                             |
    | If a members saved stats do not match the active stats then |
    | it will be added to the returned string.                    |
    * ----------------------------------------------------------- */
    When opt = 'C' then do
      /* 1st setup the saved stem for easy comparison */
      do i = 1 to stats.0
        parse value stats.i with savedmem data
        m.savedmem = strip(data)
      end
      /* now compare active to saved */
      do i = 1 to mem.0
        parse value mem.i with actmem data
        data = strip(data)
        if m.actmem = null then string = string actmem
        else if data /= m.actmem then string = string actmem
      end
      'vput (allmems)'
      return string
    end
    Otherwise nop  /* should never get here */
  end

  /* -------------------------------------------- *
  | Check to see if the provided filepath exists |
  | rc 0 it does                                 |
  | rc 20 it does not                            |
  * -------------------------------------------- */
Check_Stats_File:
  save_address = address()
  address syscall 'lstat' filepath 'file.'
  if file.0 = 0 then do
    ADDRESS value(save_address)
    return 20
  end
  else return 0

docmd:
  parse arg cmd
  drop so. se.
  x = bpxwunix(cmd,,so.,se.)
  return x

  /* ---------------------------------- *
  | Make the z/OS dsname safe for OMVS |
  * ---------------------------------- */
usssafe: procedure
  parse arg dsn
  if pos('$',dsn) = 0 then return dsn
  /* Let's not usssafe it twice :) */
  if pos('\$',dsn) > 0 then return dsn
  dsn = strreplace(dsn, '$', '\$')
  return dsn

STRREPLACE:
  ORIGINAL = ARG(1)
  OLDTXT = ARG(2)
  NEWTXT = ARG(3)
  /* YOU CAN CHANGE THE BELOW KEY (TMPTXT), WHICH IS USED AS A TEMPORARY
  POINTER TO IDENTIFY THE TEXT TO BE REPLACED */
  TMPTXT = '6A53CD2EW1F'
  NEWSTR = ORIGINAL
  DO WHILE POS(OLDTXT,NEWSTR) > 0
    NEWSTR = SUBSTR(NEWSTR, 1 , POS(OLDTXT,NEWSTR)-1) ||,
      TMPTXT || SUBSTR(NEWSTR, POS(OLDTXT,NEWSTR) + LENGTH(OLDTXT))
  END
  DO WHILE POS(TMPTXT,NEWSTR) > 0
    NEWSTR = SUBSTR(NEWSTR, 1 , POS(TMPTXT,NEWSTR)-1) ||,
      NEWTXT || SUBSTR(NEWSTR, POS(TMPTXT,NEWSTR) + LENGTH(TMPTXT))
  END
  RETURN NEWSTR
