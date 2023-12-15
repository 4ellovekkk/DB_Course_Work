--Import/export in JSON format
CREATE OR REPLACE DIRECTORY MY_DIRECTORY AS '/opt/oracle/oradata/ORCLCDB';
CREATE OR REPLACE PROCEDURE ExportUsersReviewsToJson(
    p_directory in VARCHAR2,
    p_file_name in VARCHAR2
) AS
    file_handle UTL_FILE.FILE_TYPE;
    cursor_data SYS_REFCURSOR;
    json_data   CLOB;
BEGIN
    file_handle := UTL_FILE.FOPEN(p_directory, p_file_name, 'W');

    OPEN cursor_data FOR
        SELECT JSON_OBJECT(
                       'ID' VALUE to_nchar(VYDRA_DBA.CLIENT_INFO.ID),
                       'NAME' VALUE VYDRA_DBA.CLIENT_INFO.NAME,
                       'SURNAME' VALUE VYDRA_DBA.CLIENT_INFO.SURNAME,
                       'THIRDNAME' VALUE VYDRA_DBA.CLIENT_INFO.THIRDNAME,
                       'BIRTH_DATE' VALUE to_date(VYDRA_DBA.CLIENT_INFO.BIRTH_DATE),
                       'PHONE_NUMBER' VALUE VYDRA_DBA.CLIENT_INFO.PHONE_NUMBER
               ) AS json_object
        FROM CLIENT_INFO;

    LOOP
        FETCH cursor_data INTO json_data;
        EXIT WHEN cursor_data%NOTFOUND;
        UTL_FILE.PUT_LINE(file_handle, json_data);
    END LOOP;

    CLOSE cursor_data;
    UTL_FILE.FCLOSE(file_handle);

    DBMS_OUTPUT.PUT_LINE('Data exported successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

CREATE OR REPLACE FUNCTION IMPORT_DATA_FROM_JSON_TO_USERS_REVIEWS(
    p_directory VARCHAR2,
    p_file_name VARCHAR2
) RETURN NUMBER IS
    json_data   CLOB;
    file_handle UTL_FILE.FILE_TYPE;
    total_rows  NUMBER := 0;
BEGIN
    -- Открытие файла для чтения
    file_handle := UTL_FILE.FOPEN(p_directory, p_file_name, 'R');

    -- Обработка каждой строки в файле
    LOOP
        -- Чтение строки из файла
        BEGIN
            UTL_FILE.GET_LINE(file_handle, json_data);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Выход из цикла, если достигнут конец файла
                EXIT;
        END;
-- todo: fix json
        -- Вставка данных из JSON в таблицу
        INSERT INTO CLIENT_INFO (USERS_REVIEWS_ON_MOVIE_ID,
                                            USER_REVIEW_TEXT,
                                            DATE_OF_REVIEW,
                                            USER_PROFILE_ID,
                                            ALL_INFORMATION_ABOUT_FILM_ID)
        SELECT jt.USERS_REVIEWS_ON_MOVIE_ID,
               jt.USER_REVIEW_TEXT,
               TO_DATE(jt.DATE_OF_REVIEW, 'YYYY-MM-DD') AS DATE_OF_REVIEW,
               jt.USER_PROFILE_ID,
               jt.ALL_INFORMATION_ABOUT_FILM_ID
        FROM JSON_TABLE(json_data, '$'
                        COLUMNS (
                            USERS_REVIEWS_ON_MOVIE_ID NUMBER PATH '$.USERS_REVIEWS_ON_MOVIE_ID',
                            USER_REVIEW_TEXT VARCHAR2(1000) PATH '$.USER_REVIEW_TEXT',
                            DATE_OF_REVIEW VARCHAR2(10) PATH '$.DATE_OF_REVIEW',
                            USER_PROFILE_ID NUMBER PATH '$.USER_PROFILE_ID',
                            ALL_INFORMATION_ABOUT_FILM_ID NUMBER PATH '$.ALL_INFORMATION_ABOUT_FILM_ID'
                            )
             ) jt;

        -- Увеличение счетчика строк
        total_rows := total_rows + 1;
    END LOOP;

    -- Закрытие файла
    UTL_FILE.FCLOSE(file_handle);

    -- Фиксация транзакции
    COMMIT;

    -- Возвращение общего числа вставленных строк
    RETURN total_rows;
EXCEPTION
    -- Обработка исключений
    WHEN OTHERS THEN
        -- Откат транзакции в случае ошибки
        ROLLBACK;
        -- Повторное возбуждение исключения
        RAISE;
END;
/



BEGIN
    ExportUsersReviewsToJson('MY_DIRECTORY', 'users_reviews_data.json');
END;
/

DECLARE
    rows_inserted NUMBER;
BEGIN
    rows_inserted := IMPORT_DATA_FROM_JSON_TO_USERS_REVIEWS('MY_DIRECTORY', 'users_reviews_data.json');
    DBMS_OUTPUT.PUT_LINE('Total rows inserted: ' || rows_inserted);
END;
/
--SELECT * FROM USERS_REVIEWS_ON_MOVIE;
--DROP TABLE USERS_REVIEWS_ON_MOVIE PURGE;


