create PROCEDURE EXPORT_CLIENT_INFO AS
    v_json_file UTL_FILE.FILE_TYPE;
    v_max_id    NUMBER;
    p_file_path NVARCHAR2(100) := '/opt/oracle/oradata/ORCLCDB1/ORCLPDB1/your_filename.json';
BEGIN
    -- Open the file for writing
    v_json_file := UTL_FILE.FOPEN('EXPORT_DIR', p_file_path, 'W');

    -- Get the maximum ID
    SELECT MAX(id) INTO v_max_id FROM CLIENT_INFO;

    -- Write the JSON array start
    UTL_FILE.PUT_LINE(v_json_file, '[');

    -- Cursor to fetch data from CLIENT_INFO
    FOR client_rec IN (SELECT * FROM CLIENT_INFO)
        LOOP
            -- Write JSON object for each row
            UTL_FILE.PUT_LINE(
                    v_json_file,
                    '{"name": "' || client_rec.name || '"' ||
                    ',"surname": "' || client_rec.surname || '"' ||
                    ',"thirdname": "' || client_rec.thirdname || '"' ||
                    ',"birth_date": "' || TO_CHAR(client_rec.birth_date, 'YYYY-MM-DD') || '"' ||
                    ',"phone_number": "' || client_rec.phone_number || '"}'
            );

            -- Write comma for all records except the last one
            IF client_rec.id != v_max_id THEN
                UTL_FILE.PUT_LINE(v_json_file, ',');
            END IF;
        END LOOP;

    -- Write the JSON array end
    UTL_FILE.PUT_LINE(v_json_file, ']');

    -- Close the file
    UTL_FILE.FCLOSE(v_json_file);
EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END EXPORT_CLIENT_INFO;
/

create PROCEDURE generate_account_stats_data
IS
    v_account_id CLIENT_ACCOUNT.id%TYPE;
    v_action_date ACCOUNT_STATS.action_date%TYPE;
    v_action_id   ACTIONS.id%TYPE;
    v_amount      ACCOUNT_STATS.amount%TYPE;
BEGIN
    FOR i IN 1..10000 LOOP
        -- Генерация случайных данных
        v_account_id   := TRUNC(DBMS_RANDOM.VALUE(145, 98124)); -- Замените границы в зависимости от ваших требований
        v_action_date  := TO_DATE('01-JAN-2023', 'DD-MON-YYYY') + DBMS_RANDOM.VALUE(1, 365); -- Замените границы в зависимости от ваших требований
        v_action_id    := TRUNC(DBMS_RANDOM.VALUE(1, 4)); -- Значения id действий из таблицы ACTIONS (2, 3, 4)
        v_amount       := DBMS_RANDOM.VALUE(1, 1000); -- Замените границы в зависимости от ваших требований

        -- Вставка данных в таблицу
        INSERT INTO ACCOUNT_STATS (account, action_date, action, amount)
        VALUES (v_account_id, v_action_date, v_action_id, v_amount);
    END LOOP;
    COMMIT;
END generate_account_stats_data;
/

create PROCEDURE READ_JSON_FILE AS
    v_bfile     BFILE;
    v_json_data CLOB;
    p_file_path nvarchar2(60) := 'your_filename.json';
BEGIN
    -- Open the BFILE for reading
    v_bfile := BFILENAME('IMPORT_DIR', '/opt/oracle/oradata/ORCLCDB1/ORCLPDB1/your_filename.json');

    DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);

    -- Read the JSON data into a CLOB
    DBMS_LOB.CREATETEMPORARY(v_json_data, TRUE);
    DBMS_LOB.LOADFROMFILE(v_json_data, v_bfile, DBMS_LOB.GETLENGTH(v_bfile));

    -- Close the BFILE
    DBMS_LOB.FILECLOSE(v_bfile);

    -- Display JSON data on the console
    DBMS_OUTPUT.PUT_LINE('Contents of the JSON File:');
    DBMS_OUTPUT.PUT_LINE(v_json_data);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('File not found: ' || p_file_path);
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END READ_JSON_FILE;
/

create PROCEDURE generate_client_info_data
    IS
    v_name         CLIENT_INFO.name%TYPE;
    v_surname      CLIENT_INFO.surname%TYPE;
    v_thirdname    CLIENT_INFO.thirdname%TYPE;
    v_birth_date   CLIENT_INFO.birth_date%TYPE;
    v_phone_number CLIENT_INFO.phone_number%TYPE;
BEGIN
    FOR i IN 1..100000
        LOOP
            -- Генерация случайных данных
            v_name := DBMS_RANDOM.STRING('A', 10); -- Замените 10 на максимальную длину имени
            v_surname := DBMS_RANDOM.STRING('A', 10); -- Замените 10 на максимальную длину фамилии
            v_thirdname := DBMS_RANDOM.STRING('A', 10); -- Замените 10 на максимальную длину отчества
            v_birth_date := TO_DATE('01-JAN-1970', 'DD-MON-YYYY') +
                            DBMS_RANDOM.VALUE(1, 200000); -- Замените границы в зависимости от ваших требований
            v_phone_number := TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1000000000, 9999999999)));
            -- Генерация случайного 10-значного номера

            -- Вставка данных в таблицу
            INSERT INTO CLIENT_INFO (name, surname, thirdname, birth_date, phone_number)
            VALUES (v_name, v_surname, v_thirdname, v_birth_date, v_phone_number);
        END LOOP;
    COMMIT;
END generate_client_info_data;
/

create PROCEDURE generate_random_data
    IS
    v_owner_id     int;
    v_is_locked    NUMBER(1);
    v_account_type NUMBER(1);
    v_balance      NUMBER;
BEGIN
    FOR i IN 1..100000
        LOOP
            -- Генерация случайных данных
            v_owner_id := TRUNC(DBMS_RANDOM.VALUE(145, 98124)); -- Замените границы в зависимости от ваших требований
            v_is_locked := TRUNC(DBMS_RANDOM.VALUE(0, 2));
            v_account_type := TRUNC(DBMS_RANDOM.VALUE(0, 2));
            v_balance :=trunc(DBMS_RANDOM.VALUE(0, 100000),2);
            -- Замените границы в зависимости от ваших требований

            -- Вставка данных в таблицу
            INSERT INTO CLIENT_ACCOUNT (owner, is_locked, account_type, balance)
            VALUES (v_owner_id, v_is_locked, v_account_type, v_balance);
        END LOOP;
    COMMIT;
END generate_random_data;
/

