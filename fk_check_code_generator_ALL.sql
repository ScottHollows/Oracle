clear scr
set trimspool on
spool fk_check_code_generator.log

-- =====================================================================
-- PURPOSE
--     Oracle allows multi-column foreign keys where some columns are NULL
--     and others are NOT NULL. This creates "partial" foreign keys that do
--     not match any parent row and silently break referential integrity.
--     
--     This script identifies those cases and generates a CHECK constraint
--     to enforce all-or-nothing population of the FK columns.
-- 
--     The SQL for check constraint will be similar to this
--     
--         ALTER TABLE EMPLOYEE
--           ADD CONSTRAINT EMP_DEPT_FK_CHK
--           CHECK (
--              /* validate optional multi-column foreign key */
--                    (ORG_ID is null     and DEPT_ID is null    )
--                 or (ORG_ID is not null and DEPT_ID is not null)
--              );
--
-- WARNING: This script does not check for existing *_CHK constraints.
-- If a constraint with the same name already exists, the generated SQL will fail.
--
-- Possible enhancements
---      *  Add DROP statements So you can regenerate constraints cleanly.
--       *  Add VALIDATE/NOVALIDATE options for large tables where validation is expensive.
--       *  Add detection of disabled or invalid FKs.  These are often ones with data problems
--       *  Generate SELECT statements to find bad rows.
--
--
-- Author     Scott Hollows
--            Web       www.scotthollows.com
--            LinkedIn  https://www.linkedin.com/in/scotthollows/
--            Email     scott.hollows@gmail.com
-- Copywrite  None.  Public domain
-- Legal      Use at your own risk
-- =====================================================================

set linesize 300
set pagesize 0
set heading  off
set verify   off

prompt
prompt Multi-column foreign with keys with optional columns
prompt

-- user options

accept INCLUDE_EXISTING_CHK prompt 'Include existing <FK>_CHK constraints [Y]/N : '
accept SCHEMA_FILTER        prompt 'Schema ?  All schemas (ALL), or enter schema name. Default [ALL] : '
accept CHECK_CONSTRAINT     prompt 'Generate check constraint SQL [Y]/N: '

prompt

with main as (
    SELECT
           CON.owner
          ,CON.table_name
          ,CON.constraint_name
          ,CONCOL.column_name
          ,CONCOL.position
          ,TABCOL.nullable
          -- add quoting for database objects with mixed-case or special-character name
          ,case when regexp_like(CON.owner          ,'^[A-Z][A-Z0-9_$#]*$') then CON.owner           else '"' || CON.owner           || '"' end as q_owner
          ,case when regexp_like(CON.table_name     ,'^[A-Z][A-Z0-9_$#]*$') then CON.table_name      else '"' || CON.table_name      || '"' end as q_table_name
          ,case when regexp_like(CON.constraint_name,'^[A-Z][A-Z0-9_$#]*$') then CON.constraint_name else '"' || CON.constraint_name || '"' end as q_constraint_name
          ,case when regexp_like(CONCOL.column_name ,'^[A-Z][A-Z0-9_$#]*$') then CONCOL.column_name  else '"' || CONCOL.column_name  || '"' end as q_column_name
    FROM all_constraints   CON
    JOIN all_cons_columns  CONCOL
                                on CON.owner           = CONCOL.owner
                               and CON.constraint_name = CONCOL.constraint_name
    JOIN all_objects       TAB
                                on TAB.owner       = CON.owner
                               and TAB.object_name = CON.table_name
                               and TAB.object_type = 'TABLE'
    JOIN all_tab_columns   TABCOL
                                on TABCOL.owner       = CONCOL.owner
                               and TABCOL.table_name  = CONCOL.table_name
                               and TABCOL.column_name = CONCOL.column_name
    WHERE CON.constraint_type = 'R'             -- foreign keys
      and CON.table_name      not like 'BIN$%'  -- exclude recycle bin
      and CON.constraint_name not like 'BIN$%'
      -- exclude system schemas that wont have FKs that we are about
      -- there might be more depending on what you have installed so update this
      and CON.owner not in ('SYS'     ,'SYSTEM'  ,'MDSYS'     ,'ODI_REPO_USER'          ,'XDB'     ,'CTXSYS' ,'ORDSYS'
                           ,'ORDDATA' ,'LBACSYS' ,'OUTLN'     ,'GSMADMIN_INTERNAL'      ,'OLAPSYS' ,'WMSYS'
                           ,'OJVMSYS' ,'DVSYS'   ,'DVF'       ,'REMOTE_SCHEDULER_AGENT' ,'GGSYS'   ,'AUDSYS'
                           ,'DBSNMP'  ,'SYSMAN'  ,'ANONYMOUS' ,'SI_INFORMTN_SCHEMA'     ,'APPQOSSYS'
                           ,'DIP'     ,'TSMSYS'  ,'EXFSYS'    ,'ORACLE_OCM'
                           )
      -- which schemas ?
      and (    upper(nvl('&&SCHEMA_FILTER' ,'ALL')) = 'ALL'
           or (    upper(nvl('&&SCHEMA_FILTER','ALL')) in ('','Y','USER')
	       and CON.owner = USER
	      )
           or (    upper(nvl('&&SCHEMA_FILTER','ALL')) not in ('','Y','USER','ALL')
	       and CON.owner = upper('&&SCHEMA_FILTER')
	      )
          )
      and not (    CON.owner like 'APEX%'
               and CON.table_name like '%FLOW%'    -- Exclude APEX metadata tables
              )
    )
SELECT
       '-- Table ' || q_owner || '.' || q_table_name
       || '      Foreign Key ' || q_constraint_name
       || case when nvl(upper('&&CHECK_CONSTRAINT'),'Y') = 'Y' then
               chr(10)
               || chr(10) || 'ALTER TABLE ' || q_owner || '.' || q_table_name
               || chr(10) || '  ADD CONSTRAINT ' || q_constraint_name || '_CHK'
               || chr(10) || '  CHECK ('
               || chr(10) || '     /* validate optional multi-column foreign key */'
               || chr(10) || '        (' || listagg(q_column_name || ' is null    ',' and ') within group (order by position) || ')'
               || chr(10) || '     or (' || listagg(q_column_name || ' is not null',' and ') within group (order by position) || ')'
               || chr(10) || '     );'
               || chr(10)
               || chr(10)
	  end
       as fk_and_check_constraint
FROM main
WHERE (    nvl('&&INCLUDE_EXISTING_CHK','Y') = 'Y'    -- option to include / exclude FK check constraints that already exist in the database
        or exists (select 1
                      from all_constraints CHK
                     where CHK.owner           = owner
                       and CHK.table_name      = table_name
                       and CHK.constraint_type = 'C'  -- check constraint
                       and CHK.constraint_name = constraint_name || '_CHK'
                   )
      )
GROUP BY owner, table_name, constraint_name, q_owner, q_table_name, q_constraint_name
HAVING count(*) > 1                                         -- only multi-column FKs
   and max(case when nullable = 'Y' then 1 else 0 end) = 1  -- FKs that use a NULL column
ORDER BY owner, table_name, constraint_name;


spool off

prompt Output saved to fk_check_code_generator.log

-- restore default settings
set linesize 80
set pagesize 14
set heading  on
set verify   on

