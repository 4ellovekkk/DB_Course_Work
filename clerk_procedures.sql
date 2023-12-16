CREATE OR REPLACE PROCEDURE client_creation(
    p_name IN NVARCHAR2(30),
    p_surname IN NVARCHAR2(30),
    p_thirdname IN NVARCHAR2(30),
    p_birth_date IN DATE,
    p_phone_number NVARCHAR2(30)
)
    IS
    v_nvarchar_check NVARCHAR2(50);
    v_date_check     DATE;
BEGIN
    -- Exception handling
    BEGIN
        v_nvarchar_check := p_name;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Invalid value for name');
            RETURN;
    END;

    BEGIN
        v_nvarchar_check := p_surname;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Invalid value for surname');
            RETURN;
    END;

    BEGIN
        v_date_check := p_birth_date;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Invalid value for birth date');
            RETURN;
    END;

    BEGIN
        v_nvarchar_check := p_phone_number;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Invalid value for phone number');
            RETURN;
    END;

    IF p_name IS NOT NULL AND p_surname IS NOT NULL AND p_birth_date IS NOT NULL AND p_phone_number IS NOT NULL THEN
        IF p_thirdname IS NOT NULL THEN
            INSERT INTO CLIENT_INFO(name, surname, thirdname, birth_date, phone_number)
            VALUES (p_name, p_surname, p_thirdname, p_birth_date, p_phone_number);
        ELSE
            INSERT INTO CLIENT_INFO(name, surname, thirdname, birth_date, phone_number)
            VALUES (p_name, p_surname, '', p_birth_date, p_phone_number);
        END IF;
    END IF;
END client_creation;



CREATE OR REPLACE PROCEDURE CLERK_LOGIN(
    p_login IN NVARCHAR2(30),
    p_password IN NVARCHAR2(30)
) AS
    v_is_exists NUMBER;
BEGIN
    -- Check if the login and password exist in CLERK_LOGIN_PASSWORD table
    SELECT COUNT(*)
    INTO v_is_exists
    FROM CLERK_LOGIN_PASSWORD
    WHERE LOGIN = p_login
      AND PASSWORD = p_password;

    -- Handle the case when login or password is incorrect
    IF v_is_exists = 0 THEN
        -- Raise an exception for incorrect login or password
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect login or password');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Worker logged in successfully');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END CLERK_LOGIN;
/




