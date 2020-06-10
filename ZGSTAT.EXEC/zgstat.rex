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
  |            06/10/20 LBD - Usability enhancements           |
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

  Address ISPExec
  load_info = loadispf()

  'addpop'
  'Display Panel(zgstat)'
  drc = rc
  'rempop'
  if drc > 0 then call cancel

  address syscall ,
  'readdir' repodir 'files.'

  if files.0 = 0 then do
    zedsmsg = 'Error'
    zedlmsg = 'The directory specified is not the correct directory.'
    'setmsg msg(isrz001)'
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
    x = listdsi(dsname)
    if sysdsorg /= 'PO' then iterate
    msg1 = 'Applying ISPF Statistics to:'
    msg2 = dsname
    'Control Display Lock'
    'Addpop'
    'Display Panel(zgpop)'
    'Rempop'
    x = zigistat(dsname repodir'/.zigi/'file 'U')
  end

Done:
  x = dropispf(load_info)
  zedsmsg = 'Completed.'
  zedlmsg = 'ZGSTAT completed ISPF statistics updates.'
  'setmsg msg(isrz001)'
  exit 0

Cancel:
  x = dropispf(load_info)
  Say 'ZGSTAT utility canceled.'
  exit 8

  /* Inline ISPF Elements - must remain within a comment
>Start
>Panel zgstat
)Attr
  _ type(input) caps(on) hilite(uscore)
  $ type(input) caps(off) hilite(uscore)
)Body Window(65,7)
+
+Enter the z/OS Dataset HLQ (Prefix):
_hlq                          +
+
+Enter the OMVS Directory for the Repository:
$repodir                                                      +
+
)Init
 &zwinttl = 'ZIGI Statistics Apply Utility'
)Proc
  ver (&hlq,nb,dsname)
  ver (&repodir,nb)
)End
>Panel zgpop
)Attr
 @ type(output) caps(off) intens(low)
)Body Window(46,4)
+
@msg1
@msg2
+
)Init
 &zwinttl = 'ZIGI Statistics Apply Utility'
)Proc
  ver (&hlq,nb,dsname)
  ver (&repodir,nb)
)End
>End   */

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

  /* --------------------  rexx procedure  -------------------- *
  * Name:      LoadISPF                                        *
  *                                                            *
  * Function:  Load ISPF elements that are inline in the       *
  *            REXX source code.                               *
  *                                                            *
  * Syntax:    load_info = loadispf()                          *
  *            rc = dropispf(load_info)                        *
  *                                                            *
  *            The inline ISPF resources are limited to        *
  *            ISPF Messages, Panels, and Skeletons,           *
  *                 CLISTs and EXECs are also supported.       *
  *                                                            *
  *            The inline resources must start in column 1     *
  *            and use the following syntax:                   *
  *                                                            *
  *            >START    used to indicate the start of the     *
  *                      inline data                           *
  *                                                            *
  *            >END    - used to indicate the end of the       *
  *                      inline data                           *
  *                                                            *
  *            Each resource begins with a type record:        *
  *            >type name                                      *
  *               where type is CLIST, EXEC, MSG, PANEL, SKEL  *
  *                     name is the name of the element        *
  *                                                            *
  * Sample usage:                                              *
  *          -* rexx *-                                        *
  *          load_info = loadispf()                            *
  *          ... magic code happens here (your code) ...       *
  *          rc = dropispf(load_info)                          *
  *          exit                                              *
  *          >Start inline elements                            *
  *          >Panel panel1                                     *
  *          ...                                               *
  *          >Msg msg1                                         *
  *          ...                                               *
  *          >End of inline elements                           *
  *                                                            *
  * Returns:   the list of ddnames allocated for use along     *
  *            with the libdef's performed or altlib           *
  *                                                            *
  *            format is ddname libdef ddname libdef ...       *
  *                   libdef may be altlibc or altlibe         *
  *                   for altlib clist or altlib exec          *
  *                                                            *
  * Notes:     Entire routine must be included with REXX       *
  *            exec - inline with the code.                    *
  *                                                            *
  * Comments:  The entire rexx program is processed from the   *
  *            last record to the first to find the >START     *
  *            record at which point all records from that     *
  *            point on are processed until the >END           *
  *            statement or the end of the program is found.   *
  *                                                            *
  *            It is *strongly* suggested that the inline      *
  *            elements be at the very end of your code so     *
  *            that the search for them is faster.             *
  *                                                            *
  *            Inline ISPTLIB or ISPLLIB were not supported    *
  *            because the values for these would have to be   *
  *            in hex.                                         *
  *                                                            *
  * Author:    Lionel B. Dyck                                  *
  *                                                            *
  * History:                                                   *
  *            01/09/19 - Include DROPISPF routine             *
  *            08/29/17 - Fixup static values that were vars   *
  *            05/31/17 - Change default directory count       *
  *            12/09/16 - update for add_it routine            *
  *            05/10/16 - correction for clist and exec        *
  *            04/19/16 - bug correction                       *
  *            06/04/04 - Enhancements for speed               *
  *            08/05/02 - Creation                             *
  *                                                            *
  * ---------------------------------------------------------- *
  * Disclaimer: There is no warranty, either explicit or       *
  * implied with this code. Use it at your own risk as there   *
  * is no recourse from either the author or his employeer.    *
  * ---------------------------------------------------------- */
LoadISPF: Procedure

  parse value "" with null kmsg kpanel kskel first returns ,
    kclist kexec
  /* ------------------------------------------------------- *
  * Find the InLine ISPF Elements and load them into a stem *
  * variable.                                               *
  *                                                         *
  * Elements keyword syntax:                                *
  * >START - start of inline data                           *
  * >CLIST name                                             *
  * >EXEC name                                              *
  * >MSG name                                               *
  * >PANEL name                                             *
  * >SKEL name                                              *
  * >END   - end of all inline data (optional if last)      *
  * ------------------------------------------------------- */
  last_line = sourceline()
  do i = last_line to 1 by -1
    line = sourceline(i)
    if translate(left(line,6)) = ">START " then leave
  end
  rec = 0
  /* --------------------------------------------------- *
  * Flag types of ISPF resources by testing each record *
  * then add each record to the data. stem variable.    *
  * --------------------------------------------------- */
  do j = i+1 to last_line
    line = sourceline(j)
    if translate(left(line,5)) = ">END "   then leave
    if translate(left(line,7)) = ">CLIST " then kclist = 1
    if translate(left(line,6)) = ">EXEC "  then kexec  = 1
    if translate(left(line,5)) = ">MSG "   then kmsg   = 1
    if translate(left(line,7)) = ">PANEL " then kpanel = 1
    if translate(left(line,6)) = ">SKEL "  then kskel  = 1
    rec  = rec + 1
    data.rec = line
  end

  /* ----------------------------------------------------- *
  * Now create the Library and Load the Member(s)         *
  * ----------------------------------------------------- */
  Address ISPExec
  /* ----------------------------- *
  * Assign dynamic random ddnames *
  * ----------------------------- */
  clistdd = "lc"random(999)
  execdd  = "le"random(999)
  msgdd   = "lm"random(999)
  paneldd = "lp"random(999)
  skeldd  = "ls"random(999)

  /* ---------------------------------------- *
  *  LmInit and LmOpen each resource library *
  * ---------------------------------------- */
  if kclist <> null then do
    call alloc_dd clistdd
    "Lminit dataid(clist) ddname("clistdd")"
    "LmOpen dataid("clist") Option(Output)"
    returns = strip(returns clistdd 'ALTLIBC')
  end
  if kexec <> null then do
    call alloc_dd execdd
    "Lminit dataid(exec) ddname("execdd")"
    "LmOpen dataid("exec") Option(Output)"
    returns = strip(returns execdd 'ALTLIBE')
  end
  if kmsg <> null then do
    call alloc_dd msgdd
    "Lminit dataid(msg) ddname("msgdd")"
    "LmOpen dataid("msg") Option(Output)"
    returns = strip(returns msgdd 'ISPMLIB')
  end
  if kpanel <> null then do
    call alloc_dd paneldd
    "Lminit dataid(panel) ddname("paneldd")"
    "LmOpen dataid("panel") Option(Output)"
    returns = strip(returns paneldd 'ISPPLIB')
  end
  if kskel <> null then do
    call alloc_dd skeldd
    "Lminit dataid(skel) ddname("skeldd")"
    "LmOpen dataid("skel") Option(Output)"
    returns = strip(returns skeldd 'ISPSLIB')
  end

  /* ----------------------------------------------- *
  * Process all records in the data. stem variable. *
  * ----------------------------------------------- */
  do i = 1 to rec
    record = data.i
    recordu = translate(record)
    if left(recordu,5) = ">END " then leave
    if left(recordu,7) = ">CLIST " then do
      if first = 1 then call add_it
      type = "Clist"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,6) = ">EXEC " then do
      if first = 1 then call add_it
      type = "Exec"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,5) = ">MSG " then do
      if first = 1 then call add_it
      type = "Msg"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,7) = ">PANEL " then do
      if first = 1 then call add_it
      type = "Panel"
      first = 1
      parse value record with x name
      iterate
    end
    if left(recordu,6) = ">SKEL " then do
      if first = 1 then call add_it
      type = "Skel"
      first = 1
      parse value record with x name
      iterate
    end
    /* --------------------------------------------*
    * Put the record into the appropriate library *
    * based on the record type.                   *
    * ------------------------------------------- */
    Select
      When type = "Clist" then
      "LmPut dataid("clist") MODE(INVAR)" ,
        "DataLoc(record) DataLen(255)"
      When type = "Exec" then
      "LmPut dataid("exec") MODE(INVAR)" ,
        "DataLoc(record) DataLen(255)"
      When type = "Msg" then
      "LmPut dataid("msg") MODE(INVAR)" ,
        "DataLoc(record) DataLen(80)"
      When type = "Panel" then
      "LmPut dataid("panel") MODE(INVAR)" ,
        "DataLoc(record) DataLen(80)"
      When type = "Skel" then
      "LmPut dataid("skel") MODE(INVAR)" ,
        "DataLoc(record) DataLen(80)"
      Otherwise nop
    end
  end
  if type <> null then call add_it
  /* ---------------------------------------------------- *
  * Processing completed - now lmfree the allocation and *
  * Libdef the library.                                  *
  * ---------------------------------------------------- */
  if kclist <> null then do
    Address TSO,
      "Altlib Act Application(Clist) File("clistdd")"
    "LmFree dataid("clist")"
  end
  if kexec <> null then do
    Address TSO,
      "Altlib Act Application(Exec) File("execdd")"
    "LmFree dataid("exec")"
  end
  if kmsg <> null then do
    "LmFree dataid("msg")"
    "Libdef ISPMlib Library ID("msgdd") Stack"
  end
  if kpanel <> null then do
    "Libdef ISPPlib Library ID("paneldd") Stack"
    "LmFree dataid("panel")"
  end
  if kskel <> null then do
    "Libdef ISPSlib Library ID("skeldd") Stack"
    "LmFree dataid("skel")"
  end
  return returns

  /* --------------------------- *
  * Add the Member using LmmAdd *
  * based upon type of resource *
  * --------------------------- */
Add_It:
  Select
    When type = "Clist" then
    "LmmAdd dataid("clist") Member("name")"
    When type = "Exec" then
    "LmmAdd dataid("exec") Member("name")"
    When type = "Msg" then
    "LmmAdd dataid("msg") Member("name")"
    When type = "Panel" then
    "LmmAdd dataid("panel") Member("name")"
    When type = "Skel" then
    "LmmAdd dataid("skel") Member("name")"
    Otherwise nop
  end
  type = null
  return

  /* ------------------------------ *
  * ALlocate the temp ispf library *
  * ------------------------------ */
Alloc_DD:
  arg dd
  Address TSO
  if pos(left(dd,2),"lc le") > 0 then
  "Alloc f("dd") unit(sysda) spa(5,5) dir(5)",
    "recfm(v b) lrecl(255) blksize(32760)"
  else
  "Alloc f("dd") unit(sysda) spa(5,5) dir(5)",
    "recfm(f b) lrecl(80) blksize(23440)"
  return

  /* --------------------  rexx procedure  -------------------- *
  * Name:      DropISPF                                        *
  *                                                            *
  * Function:  Remove ISPF LIBDEF's and deactivate ALTLIB's    *
  *            that were created by the LoadISPF function.     *
  *                                                            *
  * Syntax:    rc = dropispf(load_info)                        *
  *                                                            *
  * Author:    Janko                                           *
  *                                                            *
  * History:                                                   *
  *            12/05/18 - Creation                             *
  * ---------------------------------------------------------- */
DropISPF: Procedure
  arg load_info
  Address ISPEXEC
  do until length(load_info) = 0
    parse value load_info with dd libd load_info
    if left(libd,6) = "ALTLIB" then do
      if libd = "ALTLIBC" then lib = "CLIST"
      else lib = "EXEC"
      Address TSO,
        "Altlib Deact Application("lib")"
    end
    else "libdef" libd
    address tso "free f("dd")"
  end
  return 0
