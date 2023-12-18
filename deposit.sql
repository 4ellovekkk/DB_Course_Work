CREATE OR REPLACE PROCEDURE CREATE_DEPOSIT(
    p_user_id IN INT,
    p_deposit_condition IN INT,
    p_amount IN NUMBER
) AS
    v_account_id INT;
BEGIN
    -- Проверка на существование пользователя
    IF NOT EXISTS (SELECT 1 FROM CLIENT_INFO WHERE ID = p_user_id) THEN
        RAISE_APPLICATION_ERROR(-20001, 'User with ID ' || p_user_id || ' does not exist');
        RETURN;
    END IF;

    -- Вставка записи в таблицу CLIENT_ACCOUNT
    INSERT INTO CLIENT_ACCOUNT(owner, is_locked, account_type, balance)
    VALUES (p_user_id, 0, 1, p_amount);

    -- Получение ID созданного счета
    SELECT ID
    INTO v_account_id
    FROM CLIENT_ACCOUNT
    WHERE ROWNUM = 1
      AND ACCOUNT_TYPE = 1
    ORDER BY ID DESC;

    -- Вставка записи в таблицу DEPOSIT_STATE
    INSERT INTO DEPOSIT_STATE(owner, current_amount, account_for_pay, deposit_type, start_date)
    VALUES (p_user_id, p_amount, v_account_id, p_deposit_condition, TRUNC(SYSDATE));

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No data found for the specified conditions');
    WHEN VALUE_ERROR THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid value passed');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004, 'An error occurred: ' || SQLERRM);
END CREATE_DEPOSIT;
/

CREATE OR REPLACE PROCEDURE COUNT_DEPOSIT_PROFIT(p_account_id IN INT, p_owner IN INT) AS
    v_deposit_type INT;
    v_basic_amount FLOAT;
    v_recounts     INT;
    v_percentage   FLOAT;
    v_counter      INT := 1;
BEGIN
    -- Обработка NO_DATA_FOUND, если запись в DEPOSIT_STATE не найдена
    BEGIN
        SELECT DEPOSIT_TYPE, CURRENT_AMOUNT
        INTO v_deposit_type, v_basic_amount
        FROM DEPOSIT_STATE
        WHERE OWNER = p_owner
          AND ACCOUNT_FOR_PAY = p_account_id;

        -- Обработка NO_DATA_FOUND, если запись в DEPOSIT_CONDITIONS не найдена
        BEGIN
            SELECT TERMIN, PROCENTAGE_PER_YEAR
            INTO v_recounts, v_percentage
            FROM DEPOSIT_CONDITIONS
            WHERE ID = v_deposit_type;

            -- Проверка, что процент неотрицателен
            IF v_percentage < 0 THEN
                RAISE_APPLICATION_ERROR(-20001, 'Invalid percentage value');
            END IF;

            -- Обработка ZERO_DIVIDE, чтобы избежать деления на 0
            IF v_percentage = 0 THEN
                RAISE_APPLICATION_ERROR(-20002, 'Percentage cannot be zero');
            END IF;

            LOOP
                v_basic_amount := v_basic_amount + (v_basic_amount * (v_percentage / 100));
                v_counter := v_counter + 1;

                -- Выход из цикла при достижении v_recounts
                EXIT WHEN v_counter > v_recounts;
            END LOOP;

            DBMS_OUTPUT.PUT_LINE('Total amount at the end of the deposit term will be: ' || v_basic_amount);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('No data found in DEPOSIT_CONDITIONS for the specified deposit type');
            WHEN ZERO_DIVIDE THEN
                DBMS_OUTPUT.PUT_LINE('Percentage value is zero, causing division by zero');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
        END;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No data found in DEPOSIT_STATE for the specified account and owner');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
    END;
END COUNT_DEPOSIT_PROFIT;
