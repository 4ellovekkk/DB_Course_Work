CREATE OR REPLACE PROCEDURE EXPORT_CLIENT_INFO(p_file_path IN VARCHAR2) AS
    v_json_file UTL_FILE.FILE_TYPE;
    v_max_id    NUMBER;
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





CREATE OR REPLACE PROCEDURE IMPORT_CLIENT_INFO(p_file_path IN VARCHAR2) AS
    v_bfile      BFILE;
    v_json_data  CLOB;
    v_json_array JSON_ARRAY_T;
BEGIN
    -- Open the BFILE for reading
    v_bfile := BFILENAME('IMPORT_DIR', p_file_path);
    DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);

    -- Read the JSON data into a CLOB
    DBMS_LOB.CREATETEMPORARY(v_json_data, TRUE);
    DBMS_LOB.LOADFROMFILE(v_json_data, v_bfile, DBMS_LOB.GETLENGTH(v_bfile));

    -- Close the BFILE
    DBMS_LOB.FILECLOSE(v_bfile);

    -- Parse and insert JSON data into CLIENT_INFO
    v_json_array := JSON_ARRAY_T(v_json_data);

    FOR i IN 1..v_json_array.COUNT LOOP
        DECLARE
            client_rec CLIENT_INFO%ROWTYPE;
        BEGIN
            client_rec.name := v_json_array(i).name;
            client_rec.surname := v_json_array(i).surname;
            client_rec.thirdname := v_json_array(i).thirdname;
            client_rec.birth_date := TO_DATE(v_json_array(i).birth_date, 'YYYY-MM-DD');
            client_rec.phone_number := v_json_array(i).phone_number;

            -- Check for NULL values before inserting
            IF client_rec.name IS NOT NULL AND client_rec.surname IS NOT NULL AND client_rec.birth_date IS NOT NULL AND client_rec.phone_number IS NOT NULL THEN
                INSERT INTO CLIENT_INFO (name, surname, thirdname, birth_date, phone_number)
                VALUES (client_rec.name, client_rec.surname, client_rec.thirdname, client_rec.birth_date, client_rec.phone_number);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- Handle any errors for individual records
                DBMS_OUTPUT.PUT_LINE('Error processing record ' || i || ': ' || SQLERRM);
        END;
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END IMPORT_CLIENT_INFO;
/
