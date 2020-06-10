Contents of this PDS

ZGSTAT     ISPF Exec to create ISPF statistics after the use of the
           ZIGI generic installation utility.

ZINSTALL   ZIGI generic installation utility to be used by ZIGI managed
           Git repositories to copy the relavent files into z/OS
           datasets.

Usage:

Repository owner
----------------

The repository owner should add this PDS to their repositories z/OS
datasets and then copy the ZINSTALL member into the repositories OMVS
direcotry as zinstall. Then issue "chtag +x zinstall" to make it
executable.

Then document that if a non-ZIGI user clones the repository to use the
zinstall file to install the files into z/OS datasets for use.

Repository Cloner
-----------------

After cloning a ZIGI managed repository that includes these tools, the
zinstall file must be executed to create the z/OS datasets. After
zinstall completes there are instructions to use the ZGSTAT exec which
will recreate the ISPF statistics for the distribuited partitioned
datasets.
