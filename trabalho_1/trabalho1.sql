CREATE TABLE LEITOR
(COD_LEITOR INT NOT NULL PRIMARY KEY,
NOME_L VARCHAR(30));


CREATE TABLE FUNCIONARIO
(COD_FUNC INT NOT NULL PRIMARY KEY,
NOME_F VARCHAR(30));

 
CREATE TABLE TITULO
(COD_TIT INT NOT NULL PRIMARY KEY,
NOME_T VARCHAR(30));


CREATE TABLE RESERVA
(COD_RES INT NOT NULL PRIMARY KEY,
COD_LEITOR INT NOT NULL REFERENCES LEITOR(COD_LEITOR),
COD_TIT INT NOT NULL REFERENCES TITULO(COD_TIT),
COD_FUNC INT NOT NULL REFERENCES FUNCIONARIO(COD_FUNC),
DATA_HORA TIMESTAMP NOT NULL,
STATUS VARCHAR(1) CHECK (STATUS='I' OR STATUS='A'));

 
CREATE TABLE LIVRO
(COD_LIVRO INT NOT NULL PRIMARY KEY,
COD_TIT INT NOT NULL REFERENCES TITULO(COD_TIT));


CREATE TABLE EMPRESTIMO
(COD_EMPRESTIMO INT NOT NULL PRIMARY KEY,
COD_LEITOR INT NOT NULL REFERENCES LEITOR(COD_LEITOR),
COD_FUNC INT NOT NULL REFERENCES FUNCIONARIO(COD_FUNC),
DT_EMPRESTIMO DATE NOT NULL,
DT_PREV_DEVOLUCAO DATE NOT NULL,
DT_DEVOLUCAO DATE,
QUANT_LIVRO INT NOT NULL,
VALOR_MULTA FLOAT);


CREATE TABLE ITEM_EMPRESTIMO
(COD_ITEM SERIAL NOT NULL PRIMARY KEY,
COD_EMPRESTIMO INT NOT NULL REFERENCES EMPRESTIMO(COD_EMPRESTIMO),
COD_LIVRO INT NOT NULL REFERENCES LIVRO(COD_LIVRO));


/* Inserção de dados*/
    INSERT INTO LEITOR VALUES (1, 'MARIA');
    INSERT INTO LEITOR VALUES (2, 'KAIO');

    INSERT INTO FUNCIONARIO VALUES (1, 'JOÃO PEDRO');

    INSERT INTO TITULO VALUES (1, 'PRIMEIRA GUERRA MUNDIAL');
    INSERT INTO TITULO VALUES (2, 'PSICOLOGIA');

    INSERT INTO RESERVA VALUES (1, 1, 1, 1, now(), 'A');
    INSERT INTO RESERVA VALUES (7, 2, 2, 1, now(), 'A');

    INSERT INTO LIVRO VALUES (1, 1), (2, 1);
    insert into livro values (3, 1);
    INSERT INTO LIVRO VALUES (4, 2);

    INSERT INTO EMPRESTIMO VALUES (9, 1, 1, NOW(), '30/05/2022', NULL, 1, 0);

    INSERT INTO ITEM_EMPRESTIMO VALUES (default, 9, 1);

/* consultas */

SELECT * FROM LEITOR;
SELECT * FROM FUNCIONARIO;
SELECT * FROM TITULO;
SELECT * FROM LIVRO;
SELECT * FROM RESERVA;
SELECT * FROM EMPRESTIMO;
SELECT * FROM ITEM_EMPRESTIMO;

/*                             TRABALHO 1                                      */
/*
Crie um trigger que não permita a existência de dois ou mais itens
(tabela ITEM_EMPRÉSTIMO) do mesmo empréstimo com o mesmo código de livro.
*/

CREATE OR REPLACE FUNCTION validar_item_emprestimo() RETURNS trigger AS $$
BEGIN
    IF ((select count(cod_livro) from 
       (select * from item_emprestimo where cod_emprestimo = new.cod_emprestimo) as itens
        where cod_livro = new.cod_livro) > 1) THEN
        RAISE EXCEPTION 'mesmo empréstimo com o mesmo código de livro';
    ELSE
        RAISE NOTICE 'ITEM INSERIDO COM SUCESSO!';
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER validacao_item_emprestimo AFTER INSERT ON ITEM_EMPRESTIMO
FOR EACH ROW WHEN (pg_trigger_depth() = 0) EXECUTE PROCEDURE validar_item_emprestimo();

/*
Crie um trigger que altere o status da reserva de um leitor para I (Inativo)
sempre que ele tomar emprestado o livro do título que ele reservou.
*/

CREATE OR REPLACE FUNCTION alterar_status_reserva() RETURNS trigger AS $$
DECLARE 
codigo_leitor int := (select cod_leitor from emprestimo where cod_emprestimo = new.cod_emprestimo);
codigo_titulo int := (select cod_tit from livro where cod_livro = new.cod_livro);

BEGIN
    IF(EXISTS(SELECT FROM RESERVA WHERE RESERVA.COD_LEITOR = codigo_leitor)) then
        UPDATE RESERVA SET STATUS = 'I' WHERE RESERVA.COD_TIT = codigo_titulo;
        RAISE NOTICE 'STATUS DA RESERVA ATUALIZADO';
    ELSE
        RAISE NOTICE 'NÃO FOI POSSÍVEL ATUALIZAR O STATUS DA RESERVA';
    END IF;
    RETURN NULL;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER status_reserva AFTER INSERT ON item_emprestimo
FOR EACH ROW WHEN (pg_trigger_depth() = 0) EXECUTE PROCEDURE alterar_status_reserva();


/* Reservar um título de livro. Na reserva, 
o leitor não poderá reservar um título, 
caso haja algum livro daquele título disponível para empréstimo.
A função receberá o nome do leitor, o nome do título e o nome do
funcionário. Imagine que não existam dois nomes iguais na mesma tabela. 
Para a data e hora da reserva, sugere-se usar a função now(). 
Mensagens devem ser enviadas para o leitor informando-o do resultado
do processamento da função. Para isso, sugere-se usar "raise notice".
*/

CREATE OR REPLACE FUNCTION reservar_titulo(codigoReserva int, nomeLeitor varchar, tituloReserva varchar, nomeFuncionario varchar ) returns void 
AS $$
DECLARE

codigoLeitor int := (SELECT cod_leitor FROM LEITOR where LEITOR.NOME_L = nomeLeitor);
codigoFuncionario int := (SELECT cod_func FROM FUNCIONARIO WHERE FUNCIONARIO.NOME_F = nomeFuncionario);
codigoTitulo int:= (SELECT cod_tit from TITULO WHERE NOME_T = tituloReserva);


BEGIN 
    IF (EXISTS(SELECT * FROM EMPRESTIMO AS E join ITEM_EMPRESTIMO AS IT on E.cod_emprestimo = IT.cod_emprestimo
    JOIN LIVRO AS L ON IT.COD_LIVRO = L.COD_LIVRO JOIN TITULO AS T ON T.COD_TIT = L.COD_TIT 
    WHERE T.NOME_T = tituloReserva AND E.DT_DEVOLUCAO IS NULL)) THEN
        RAISE NOTICE 'Não é possível reservar o título';
    ELSE
        INSERT INTO RESERVA VALUES (codigoReserva, codigoLeitor, codigoTitulo, codigoFuncionario, now(), 'A' );
        RAISE NOTICE 'Livro reservado com sucesso';
    END IF;
END;
$$ LANGUAGE plpgsql;


SELECT  FROM reservar_titulo(2, 'MARIA', 'PSICOLOGIA', 'JOÃO PEDRO');


/*
Emprestar um único livro. No caso do empréstimo,
a função receberá o código do empréstimo,
o código do livro, a data do empréstimo, o nome do leitor 
e o nome do funcionário. Assim como na reserva, imagine que 
não existam dois nomes iguais na mesma tabela. Para inserção
na tabela empréstimo, a data de devolução deve ser nula
(ela só será preenchida quando o empréstimo for dado baixa)
e a data prevista de devolução deve ser dois dias após a
data do empréstimo. O empréstimo de um dado livro só poderá
ser efetivado se não existir nenhuma reserva ATIVA para
o título daquele livro ou se a reserva mais ANTIGA for do
mesmo leitor que está efetuando o empréstimo. Como sabemos,
o ato de emprestar consiste em inserir registros nas tabelas
Empréstimo e Item_empréstimo ou simplesmente inserir registros
na tabela Item_empréstimo e atualizar a tabela empréstimo
(quantidade de livros). Porém, para essa questão,
consideraremos que apenas um livro será emprestado em cada empréstimo.
Assim, você não se preocupará se já existe o mesmo código de
empréstimo na tabela empréstimo. Da mesma forma que na função anterior, 
mensagens devem ser enviadas para o leitor informando-o do resultado do processamento da função.
*/

CREATE OR REPLACE FUNCTION realizar_emprestimo(codigoEmprestimo int, codigoLivro int, 
dataEmprestimo date, nomeLeitor varchar, nomeFuncionario varchar) returns void as $$
DECLARE
codigoLeitor int := (SELECT cod_leitor FROM LEITOR where LEITOR.NOME_L = nomeLeitor);
codigoFuncionario int := (SELECT cod_func FROM FUNCIONARIO WHERE FUNCIONARIO.NOME_F = nomeFuncionario);
codigoTitulo int := (SELECT cod_tit FROM LIVRO WHERE cod_livro = codigoLivro);
dataPrevista date := dataEmprestimo + 2;
existeReserva boolean := EXISTS(SELECT * FROM RESERVA WHERE COD_TIT = codigoTitulo AND STATUS = 'A');
existeReservaLeitor boolean := EXISTS(SELECT * FROM RESERVA WHERE COD_TIT = codigoTitulo AND STATUS = 'A' AND DATA_HORA = 
                                      (SELECT MIN(DATA_HORA) FROM RESERVA)
                                      AND COD_LEITOR = codigoLeitor);
BEGIN
    IF(NOT existeReserva OR existeReservaLeitor) THEN
        INSERT INTO EMPRESTIMO VALUES (codigoEmprestimo, codigoLeitor, codigoFuncionario, dataEmprestimo, dataPrevista, null, 1, null);
        INSERT INTO ITEM_EMPRESTIMO VALUES (DEFAULT, codigoEmprestimo, codigoLivro);
        RAISE NOTICE 'EMPRÉSTIMO REALIZADO COM SUCESSO! ';
    ELSE
        RAISE NOTICE 'NÃO FOI POSSÍVEL REALIZAR O EMPRÉSTIMO';
    END IF;

END;
$$ LANGUAGE plpgsql;

select * from realizar_emprestimo(4, 2, '22/05/2022', 'MARIA', 'JOÃO PEDRO');


/*
 Dar baixa em um empréstimo. Por fim,
 o ato de dar baixa no empréstimo consiste em preencher a data de devolução
 e calcular, quando houver, o valor da multa. Considere o valor de R$ 2,50 
 por dia de atraso e para cada livro. Em outras palavras, 
 caso o leitor dê baixa em um empréstimo que possuía um livro com dois dias de atraso,
 o função deveria calcular uma multa no valor de R$ 5,00. A
 função deverá receber apenas o código do empréstimo que será dado baixa.
*/


CREATE OR REPLACE FUNCTION dar_baixa_emprestimo(codigoEmprestimo int) returns void as $$
DECLARE
valorMulta real := (CURRENT_DATE - (SELECT DT_PREV_DEVOLUCAO FROM EMPRESTIMO WHERE COD_EMPRESTIMO = codigoEmprestimo)) * 2.5;
BEGIN 
    UPDATE EMPRESTIMO SET DT_DEVOLUCAO = CURRENT_DATE, VALOR_MULTA = valorMulta WHERE COD_EMPRESTIMO = codigoEmprestimo;
    RAISE NOTICE 'DEVOLUÇÃO CONCLUÍDA COM SUCESSO! MULTA: R$ %', valorMulta;
END;
$$ LANGUAGE plpgsql;

select * from emprestimo;
select * from dar_baixa_emprestimo(4);