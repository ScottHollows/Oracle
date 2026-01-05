
drop table TEST_EMPLOYEES;
drop table TEST_DEPARTMENT;

prompt ============================================
prompt create parent table

create table TEST_DEPARTMENT (
    org_id      number       not null,
    dept_id     number       not null,
    dept_name   varchar2(100)
);

-- add primary key
alter table TEST_DEPARTMENT
    add constraint pk_test_department
    primary key (org_id, dept_id);


prompt ============================================
prompt create child table

create table TEST_EMPLOYEES (
    emp_id       number        not null,
    org_id       number        null,
    dept_id      number        null,
    first_name   varchar2(100),
    surname      varchar2(100)
);

--  -- add primary key constraint. not needed for the test
--  alter table TEST_EMPLOYEES
--      add constraint pk_test_employees
--      primary key (emp_id);


prompt ============================================
prompt create optional multi column foreign key
prompt from Employees to Departments

-- add composit (multi column) foreign key to departments 
alter table TEST_EMPLOYEES
    add constraint emp_dept_fk
    foreign key (org_id, dept_id)
    references test_department (org_id, dept_id);

prompt ============================================
prompt Insert junk into the foreign key columns

insert into test_employees (
     emp_id,
     org_id,
     dept_id,
     first_name,
     surname
   ) values (
     1,
     null,               -- FK column 1.  If null value here
     374945874837909,    -- FK column 2.  ... you can enter any junk here
     'Fred',
     'Flinstone'
   );


prompt COMMIT if you want to
prompt No warnings !  No errors !

