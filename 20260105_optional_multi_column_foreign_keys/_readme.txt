
Files
====================
_readme.txt                        this file
example.png                        Example data model and insert
example_workaround.sql             Example workaround.  Constraint and trigger examples
fk_check_code_generator_ALL.sql    Run this to show a list of FKs that are problematic
                                   and also generate SQL for check constraints to fix them 
fk_check_code_generator_DBA.sql    DBA version of above


Explanation
====================
The following is a text version of this post ...
   https://scotthollows.com/2026/01/05/oracle-foreign-keys-do-not-always-work/


Oracle foreign keys do not always work
I’ll show how to break them and how to fix them
 
Im not talking about DISABLED or DEFERRED or NOVALIDATE foreign keys – No, this is different.
 
This is for a specific scenario – a multi column foreign key with one or more optional columns
 
If you insert a row that has a NULL in one of the FK columns, you can enter junk values into the other FK columns - oh dear !

NOT A BUG
This is not a bug. This is the intended, documented behaviour and is part of the ANSI SQL standard. So its not technically “broken”, however Im sure you dont like it because your data quality is at risk due to this unexpected feature.
 
WORKAROUND
There is a simple workaround
Create a check constraint (or trigger) that verifies all of the FK columns in a row have a value, or none of them have a value.
 
ALTER TABLE ADMIN.EMPLOYEES
ADD CONSTRAINT EMP_DEPT_FK_CHK
CHECK (
/* validate optional multi-column foreign key */
(ORG_ID IS NULL AND DEPT_ID IS NULL)
OR
(ORG_ID IS NOT NULL AND DEPT_ID IS NOT NULL)
);
 
BONUS DOWNLOAD
- Demo scripts
- A script that shows the problematic FKs and generates check constraints SQL to fix them
