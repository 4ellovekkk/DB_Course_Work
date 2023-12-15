create table CLIENT_INFO
(
    id           int generated always as identity primary key,
    name         nvarchar2(30) not null,
    surname      nvarchar2(30) not null,
    thirdname    nvarchar2(30),
    birth_date   date          not null,
    phone_number nvarchar2(20)
) tablespace CLIENT_DATA;

CREATE TABLE CLIENT_ACCOUNT
(
    id           int generated always as identity primary key,
    owner        INT,
    is_locked    NUMBER(1) CHECK (is_locked IN (0, 1)),
    account_type NUMBER(1) CHECK (account_type IN (0, 1)),
    balance      NUMBER default 0,
    CONSTRAINT fk_client FOREIGN KEY (owner) REFERENCES CLIENT_INFO (id)
) TABLESPACE CLIENT_DATA;

create table ACCOUNT_STATS
(
    id          int generated always as identity primary key,
    account     int,
    action_date date,
    action      int,
    AMOUNT      float,
    constraint stats_fk1 foreign key (account) references CLIENT_ACCOUNT (id),
    constraint fk2_action foreign key (action) references actions (id)
) tablespace CLIENT_DATA;

create table actions
(
    id          int generated always as identity primary key,
    action_name nvarchar2(50)
) tablespace BANK_DATA;

create table credit_conditions
(
    id                  int generated always as identity primary key,
    procentage_per_year float,
    name                nvarchar2(50),
    termin              int,
    items_type          nvarchar2(90)
) tablespace BANK_DATA;

create table credit_state
(
    id              int generated always as identity primary key,
    is_payed        int check ( is_payed in (0, 1)),
    owner           int,
    current_debt    float,
    account_for_pay int,
    credit_type     int,
    constraint fk1_account foreign key (account_for_pay) references CLIENT_ACCOUNT (id),
    constraint fk2_owner foreign key (owner) references CLIENT_INFO (id),
    constraint fk3_credit_type foreign key (credit_type) references credit_conditions (id)
) tablespace BANK_DATA;

create table LOGIN_PASSWORD
(
    login    varchar(30) primary key,
    password varchar(30),
    id       int,
    constraint fk1 foreign key (id) references CLIENT_INFO (id)
) tablespace BANK_DATA;