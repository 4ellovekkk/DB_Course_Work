CREATE OR REPLACE PROCEDURE get_user_info(p_user_id IN NUMBER)
AS
  v_first_name  VARCHAR2(50);
  v_second_name VARCHAR2(50);
  v_third_name  VARCHAR2(50);
    v_param_test number;
BEGIN
    v_param_test:=to_number(p_user_id);
  -- Validate that the provided parameter is a positive integer
  IF p_user_id IS NOT NULL AND p_user_id > 0 AND p_user_id = TRUNC(p_user_id) THEN
    -- Select user information
    SELECT CLIENT_INFO.NAME, CLIENT_INFO.SURNAME, CLIENT_INFO.THIRDNAME
    INTO v_first_name, v_second_name, v_third_name
    FROM CLIENT_INFO
    WHERE ID = p_user_id;

    -- Check if the user has a third name
    IF v_third_name IS NOT NULL THEN
      DBMS_OUTPUT.PUT_LINE('User ID: ' || p_user_id || ', First Name: ' || v_first_name ||
                           ', Second Name: ' || v_second_name || ', Third Name: ' || v_third_name);
    ELSE
      DBMS_OUTPUT.PUT_LINE('User ID: ' || p_user_id || ', First Name: ' || v_first_name ||
                           ', Second Name: ' || v_second_name || ', No Third Name');
    END IF;
  ELSE
    DBMS_OUTPUT.PUT_LINE('Invalid user ID provided.');
  END IF;

  EXCEPTION
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect type of parameter was passed');
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('User with ID ' || p_user_id || ' not found.');
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('An error occurred for User ID ' || p_user_id || ': ' || SQLERRM);
END get_user_info;
/







CREATE OR REPLACE PROCEDURE check_balance(client_id IN NUMBER)
AS
    balance NUMBER; -- Corrected the data type
    account_id NUMBER; -- Corrected the data type
    v_param_test number;
BEGIN
    v_param_test:=to_number(client_id);
    -- Removed unnecessary cast and adjusted the IF condition
  IF client_id IS NOT NULL AND client_id > 0 AND client_id = TRUNC(client_id) THEN
        SELECT ID, BALANCE INTO account_id, balance FROM CLIENT_ACCOUNT WHERE OWNER = client_id;
        DBMS_OUTPUT.PUT_LINE('Account id: ' || account_id || ' Balance: ' || balance);
    END IF;

    EXCEPTION
when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect type of parameter was passed');
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('User with ID ' || client_id || ' not found.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred for User ID ' || client_id || ': ' || SQLERRM);
END check_balance;
/

CREATE OR REPLACE PROCEDURE account_history(
    p_account_id IN NUMBER,
    p_from_date IN DATE,
    p_to_date IN DATE
)
AS
    v_operation_date DATE;
    v_operation NVARCHAR2(50);
        v_account int;
        v_param_check_number number;
    v_param_check_date date;
BEGIN
    v_param_check_number:=to_number(p_account_id);
    v_operation_date:=to_date(p_from_date);
    v_operation_date:=to_date(p_to_date);
    -- Validate input parameters
    IF p_account_id IS NULL OR p_from_date IS NULL OR p_to_date IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Invalid input parameters. Please provide valid values.');
        RETURN;
    END IF;

    -- Check if from_date is less than or equal to to_date
    IF p_from_date > p_to_date THEN
        DBMS_OUTPUT.PUT_LINE('Invalid date range. "From date" should be less than or equal to "To date".');
        RETURN;
    END IF;

    -- Select account history based on input parameters
    BEGIN
   select ACTION_DATE,ACTION,ACCOUNT into v_operation,v_operation,v_account from ACCOUNT_STATS inner join VYDRA_DBA.CLIENT_ACCOUNT CA on CA.ID = ACCOUNT_STATS.ACCOUNT where p_account_id=OWNER and ACTION_DATE>=p_from_date and ACTION_DATE<=p_to_date;
    EXCEPTION
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect type of parameter was passed');
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No records found for the specified account and date range.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
    END;

    -- Process the selected data as needed
    IF v_operation_date IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Account ID: ' || p_account_id ||
                             ', Operation Date: ' || v_operation_date ||
                             ', Operation: ' || v_operation);
    END IF;
END account_history;

CREATE OR REPLACE PROCEDURE transfer (
    p_sender_account IN NUMBER,
    p_receiver_account IN NUMBER,
    p_sender_id IN NUMBER,
    p_amount IN NUMBER
)
AS
    v_check_sender NUMBER;
    v_check_receiver NUMBER;
    v_check_parameter number;
BEGIN
    v_check_parameter:=to_number(p_sender_account);
    v_check_parameter:=to_number(p_receiver_account);
    v_check_parameter:=to_number(p_sender_id);
    v_check_parameter:=to_number(p_amount);
    -- Check if any parameter is NULL
    IF p_sender_account IS NULL OR p_receiver_account IS NULL OR p_sender_id IS NULL OR p_amount IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('One or more parameters were not correctly passed.');
        RETURN;
    END IF;

    -- Check sender account
    SELECT COUNT(*)
    INTO v_check_sender
    FROM CLIENT_ACCOUNT
    WHERE ID = p_sender_account
      AND OWNER = p_sender_id
      AND BALANCE >= p_amount;

    -- Check receiver account
    SELECT COUNT(*)
    INTO v_check_receiver
    FROM CLIENT_ACCOUNT
    WHERE ID = p_receiver_account;

    -- Validate sender and receiver
    IF v_check_sender = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Invalid sender data.');
        RETURN;
    END IF;

    IF v_check_receiver = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Invalid receiver data.');
        RETURN;
    END IF;

    -- Update balances
    UPDATE CLIENT_ACCOUNT
    SET BALANCE = BALANCE + p_amount
    WHERE ID = p_receiver_account;

    UPDATE CLIENT_ACCOUNT
    SET BALANCE = BALANCE - p_amount
    WHERE ID = p_sender_account;

    insert into ACCOUNT_STATS (account, action_date, action) VALUES (p_sender_account, sysdate,'debit from account '||p_sender_account||' in amount: '||p_amount);
    insert into ACCOUNT_STATS (account, action_date, action) VALUES (p_receiver_account, sysdate,'refill '||p_receiver_account||' in amount: '||p_amount);
    commit ;

    DBMS_OUTPUT.PUT_LINE('Successfully transferred ' || p_amount ||
                         ' from account ' || p_sender_account ||
                         ' to ' || p_receiver_account);
exception
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect parametres type');
END transfer;
/

--TODO: fix account history procedure

CREATE OR REPLACE PROCEDURE refill_account(p_account_id IN NUMBER, p_amount IN NUMBER) AS
BEGIN
    -- Проверка на NULL
    IF p_account_id IS NULL OR p_amount IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Incorrect parameters passed');
        RETURN;
    END IF;

    -- Попытка преобразования параметров к числовому типу
    BEGIN
        -- Проверка на отрицательное значение счета
        IF p_amount <= 0 THEN
            DBMS_OUTPUT.PUT_LINE('Amount must be greater than 0');
            RETURN;
        END IF;

        -- Проверка на существование счета
        IF (SELECT COUNT(*) FROM CLIENT_ACCOUNT WHERE ID = p_account_id) = 1 THEN
            UPDATE CLIENT_ACCOUNT SET BALANCE = BALANCE + p_amount WHERE ID = p_account_id;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Account refilled successfully');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Account does not exist');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Incorrect parameters passed');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
    END;
END refill_account;
/
