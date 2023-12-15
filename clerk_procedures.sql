create or replace procedure client_creation(p_name in nvarchar2(30), p_suranme in nvarchar2(30),
                                            p_thirdname in nvarchar2(30), p_birth_date in date,
                                            p_phone_number nvarchar2(30))
    is
    v_nvarchar_check nvarchar2(50);
begin
    if p_name is not null and p_suranme is not null and p_birth_date is not null and p_phone_number is not null
    insert into CLIENT_INFO(name, surname, thirdname, birth_date, phone_number) values (p_name,p_suranme,p_thirdname,p_birth_date,p_phone_number);
end client_creation;