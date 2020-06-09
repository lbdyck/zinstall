# ZGSTAT and zinstall.rex - ZIGI Utilities for the non-ZIGI site

**zinstall.rex** is a generic installation utility for ZIGI managed
repositories that are cloned to a site that does not have ZIGI
installed.

## Suggested Use

It is suggested that the zinstall.rex and the ZGSTAT.EXEC to included in
all ZIGI managed distributions as a way to allow non-ZIGI sites to
install the package.

## Usage

To use zinstall.rex, which should be installed in the base
directory of the Git repository, issue the command ./zinstall.rex from
the OMVS command prompt while in the Git repository directory.

The user will be prompted for the z/OS HLQ (dataset prefix) to be
used when copying the distributed files into new z/OS datasets.

Only files in the repository that are all upper case will be considered
as candidates to copy. Directories that are all upper case will be
have the files within it considered as members of a partitioned dataset
using the hlq followed by the directory name as the partitioned dataset
name.

After zinstall.rex completes, all the packaged datasets will now exist
as z/OS datasets.

Make note of the HLQ and the OMVS directory used for the repository at
this point.

At this point the user can exit OMVS and return to TSO/ISPF.

These datasets, if partitioned, will not have any ISPF statistics at
this time as neither Git, or OMVS, understand ISPF statistics. ZIGI
however does, and has retained those statistics in special files.

Once under TSO and ISPF execute the **ZGSTAT** command which will prompt
for the HLQ and the OMVS directory. It will then restore the ISPF
statistics to the partitioned datasets.
