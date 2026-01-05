
-- Example workaround #1 using a check constraint

alter table TEST_EMPLOYEES
  add constraint EMP_DEPT_FK_CHK
  check (
     /* validate optional multi-column foreign key */
        (org_id is null     and dept_id is null    )
     or (org_id is not null and dept_id is not null)
     );


-- Example workaround #2 using a trigger

create or replace trigger EMP_DEPT_FK_CHK_TRG
before insert or update
on TEST_EMPLOYEES
for each row
begin
  if not (   (:new.org_id is null     and :new.dept_id is null    )
          or (:new.org_id is not null and :new.dept_id is not null)
	 )
  then
      raise_application_error (-20000, 'Inconsistent values detected in foreign key (Employees -> Departments');
  end if;
end;
/
