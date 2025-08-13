WITH HIST AS (
    SELECT
        DISTINCT CAST(HS.DATA_ALTERACAO AS DATE) AS DATA_ALTERACAO,
        HS.CLIENTE_ID,
        HS.STATUS_ANTERIOR,
        HS.STATUS_ALTERADO,
        CASE
            WHEN HS.STATUS_ANTERIOR = 3
            AND HS.STATUS_ALTERADO = 33 THEN 'INADIMPLENCIA'
            WHEN HS.STATUS_ANTERIOR = 2
            AND HS.STATUS_ALTERADO = 3 THEN 'REATIVACAO'
            ELSE 'REATIVACAO'
        END AS ALTERACAO
    FROM
        HISTORICO_STATUS HS
    WHERE
        HS.STATUS_ALTERADO IN (3, 33)
        AND HS.STATUS_ANTERIOR IN (2, 3, 33)
),
CLUSTERS AS (
    SELECT
        CLIENTE_ID,
        COUNT(*) AS QTD_REATIVACOES,
        CASE
            WHEN COUNT(*) <= 1 THEN 'OCASIONAL'
            WHEN COUNT(*) <= 2 THEN 'MEDIANO'
            ELSE 'OFENSOR'
        END AS CLUSTER_ATUAL
    FROM
        HIST
    WHERE
        DATA_ALTERACAO BETWEEN DATEADD(MONTH, -6, GETDATE())
        AND GETDATE()
    GROUP BY
        CLIENTE_ID
),
HIST_COM_CLUSTER AS (
    SELECT
        H.*,
        CASE
            WHEN H.ALTERACAO = 'INADIMPLENCIA'
            AND C.CLUSTER_ATUAL IS NULL THEN 'SEM REATIVACAO'
            ELSE C.CLUSTER_ATUAL
        END AS CLUSTER_ATUAL
    FROM
        HIST H
        LEFT JOIN CLUSTERS C ON H.CLIENTE_ID = C.CLIENTE_ID
),
PARCELAS AS (
    SELECT
        CLIENTE_ID,
        COUNT(*) AS QTD_FATURAS_ABERTO
    FROM
        (
            SELECT
                CLIENTE_ID
            FROM
                FATURAS_CARTAO_CREDITO
            WHERE
                STATUS_PROVIDER = 'pending'
                AND DATA_VENCIMENTO >= DATEADD(MONTH, -4, GETDATE())
            UNION
            ALL
            SELECT
                CLIENTE_ID
            FROM
                FATURAS_CARNE
            WHERE
                STATUS_PROVIDER = 'overdue'
                AND DATA_VENCIMENTO >= DATEADD(MONTH, -4, GETDATE())
        ) AS FATURAS_ABERTAS
    GROUP BY
        CLIENTE_ID
),
HIST_INAD AS (
    SELECT
        C.ID,
        C.DATA_INICIO_PLANO,
        CASE
            WHEN DATEDIFF(
                DAY,
                C.DATA_INICIO_PLANO,
                CAST(GETDATE() AS DATE)
            ) < 2 THEN '1 Dia'
            WHEN DATEDIFF(
                DAY,
                C.DATA_INICIO_PLANO,
                CAST(GETDATE() AS DATE)
            ) <= 30 THEN CONCAT(
                DATEDIFF(
                    DAY,
                    C.DATA_INICIO_PLANO,
                    CAST(GETDATE() AS DATE)
                ),
                ' Dias'
            )
            ELSE CASE
                WHEN CEILING(
                    DATEDIFF(
                        DAY,
                        C.DATA_INICIO_PLANO,
                        CAST(GETDATE() AS DATE)
                    ) / 30.0
                ) > 12 THEN CONCAT(
                    FORMAT(
                        FLOOR(
                            CEILING(
                                DATEDIFF(
                                    DAY,
                                    C.DATA_INICIO_PLANO,
                                    CAST(GETDATE() AS DATE)
                                ) / 30.0
                            ) / 12.0
                        ),
                        'N0',
                        'pt-BR'
                    ),
                    ' Anos'
                )
                ELSE CONCAT(
                    FORMAT(
                        CEILING(
                            DATEDIFF(
                                DAY,
                                C.DATA_INICIO_PLANO,
                                CAST(GETDATE() AS DATE)
                            ) / 30.0
                        ),
                        'N0',
                        'pt-BR'
                    ),
                    ' Meses'
                )
            END
        END AS TEMPO_DE_CASA,
        C.DATA_NASCIMENTO,
        C.IDADE,
        CASE
            WHEN C.IDADE BETWEEN 0
            AND 18 THEN '0 a 18'
            WHEN C.IDADE BETWEEN 19
            AND 34 THEN '19 a 34'
            WHEN C.IDADE BETWEEN 35
            AND 55 THEN '35 a 55'
            WHEN C.IDADE BETWEEN 56
            AND 75 THEN '56 a 75'
            WHEN C.IDADE >= 76 THEN '75+'
            ELSE 'Idade inválida'
        END AS FAIXA_ETARIA,
        C.NOME,
        C.TELEFONE,
        C.TELEFONE_3,
        C.TELEFONE_4,
        c.TELEFONE_FIXO,
        C.CPF,
        C.ENDERECO_ID,
        TRIM(REPLACE(E.CEP, CHAR(9), '')) AS CEP,
        C.STATUS_CLIENTE_ID,
        SC.NOME AS STATUS_CLIENTE,
        C.FORMA_PAGAMENTO_ID,
        FP.NOME AS FORMA_PAGAMENTO,
        C.PLANO_ID,
        P.NOME AS PLANO,
        CASE
            WHEN C.TIPO_CONTRATO IS NULL THEN 'Contrato digital'
            ELSE C.TIPO_CONTRATO
        END AS TIPO_CONTRATO,
        C.GENERO,
        CASE
            WHEN C.FORMA_PAGAMENTO_ID = 14 THEN ISNULL(
                NULLIF(C.VALOR_DESCONTO_CARNE, 0),
                P.MENSALIDADE_CARNE
            )
            WHEN C.FORMA_PAGAMENTO_ID = 13 THEN ISNULL(
                NULLIF(C.VALOR_DESCONTO_CARTAO_CREDITO, 0),
                P.MENSALIDADE_CARTAO_CREDITO
            )
            ELSE NULL
        END AS DESCONTO_VALOR,
        CAST(I.DATA_ALTERACAO AS DATETIME) AS DATA_ALTERACAO,
        I.STATUS_ANTERIOR,
        I.STATUS_ALTERADO,
        I.ALTERACAO,
        I.CLUSTER_ATUAL AS CLUSTER,
        PC.QTD_FATURAS_ABERTO
    FROM
        CLIENTES C
        LEFT JOIN PLANOS P ON C.PLANO_ID = P.ID
        LEFT JOIN FORMAS_PAGAMENTO FP ON C.FORMA_PAGAMENTO_ID = FP.ID
        LEFT JOIN STATUS_CLIENTE SC ON C.STATUS_CLIENTE_ID = SC.ID
        LEFT JOIN ENDERECOS E ON C.ENDERECO_ID = E.ID
        LEFT JOIN HIST_COM_CLUSTER I ON C.ID = I.CLIENTE_ID
        LEFT JOIN PARCELAS PC ON C.ID = PC.CLIENTE_ID
    WHERE
        C.STATUS_CLIENTE_ID = 33
        AND C.FORMA_PAGAMENTO_ID IN (13, 14)
        AND C.ID NOT IN ('111295', '111302', '111304', '91225')
        AND P.ID <> 19
),
HIST_NUMERADO AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY ID
            ORDER BY
                DATA_ALTERACAO DESC
        ) AS RN
    FROM
        HIST_INAD
)
SELECT
    DATA_INICIO_PLANO,
    TEMPO_DE_CASA,
    DATA_NASCIMENTO,
    IDADE,
    FAIXA_ETARIA,
    NOME,
    TELEFONE,
    TELEFONE_3,
    TELEFONE_4,
    TELEFONE_FIXO,
    FORMA_PAGAMENTO,
    PLANO,
    GENERO,
    DESCONTO_VALOR,
    CLUSTER,
    QTD_FATURAS_ABERTO
FROM
    HIST_NUMERADO
WHERE
    RN = 1
ORDER BY
    ID;