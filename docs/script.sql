-- Revisao KPI01/KPI09: unidades separadas, setores completos e bloqueios por produto.
-- G01: todos os setores de venda nos meses com vendas ou perdas confirmadas;
-- percentual NULL indica faturamento zero. G09: totais separados por kg/unidade.
-- Concorrencia: procedures usam READ COMMITTED e vendas/perdas bloqueiam PRODUTO
-- antes de ler o saldo agregado. Saidas e estornos participam do mesmo bloqueio.
-- Procedures controlam sua propria transacao: chamar fora de transacao externa.
-- Deadlock/timeout aborta a operacao via ROLLBACK; a aplicacao pode repetir a chamada.
-- Validacao: carga, auditorias e 57 verificacoes sequenciais no MySQL 8.0.46.
-- Conexoes simultaneas NAO foram testadas: ambiente de validacao bloqueia sockets.
-- Isso nao comprova concorrencia completa, desempenho ou todos os caminhos de DML.
-- ================================================================
-- BANCO DE DADOS - HORTIFRUTI UNIAO
-- Trabalho academico - Entrega 2
-- SGBD: MySQL 8.0.16 ou superior
-- ================================================================

DROP DATABASE IF EXISTS hortifruti_uniao;
CREATE DATABASE hortifruti_uniao CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE hortifruti_uniao;

-- ================================================================
-- 1. TABELAS
-- ================================================================

CREATE TABLE SETOR (
    id_setor INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE,
    descricao VARCHAR(150),
    dias_alerta_validade INT UNSIGNED NULL,
    vende_produto TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (vende_produto IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE PRODUTO (
    id_produto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_setor INT UNSIGNED NOT NULL,
    codigo_interno VARCHAR(20) NOT NULL UNIQUE,
    codigo_barras VARCHAR(20) NULL UNIQUE,
    nome VARCHAR(100) NOT NULL,
    preco_venda DECIMAL(10,2) NOT NULL,
    estoque_minimo DECIMAL(10,3) NOT NULL DEFAULT 0,
    tipo_venda VARCHAR(10) NOT NULL,
    tem_validade_impressa TINYINT(1) NOT NULL DEFAULT 1,
    venda_restrita_idade TINYINT(1) NOT NULL DEFAULT 0,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_produto_setor FOREIGN KEY (id_setor) REFERENCES SETOR(id_setor) ON DELETE RESTRICT,
    CHECK (preco_venda > 0),
    CHECK (estoque_minimo >= 0),
    CHECK (tipo_venda IN ('unidade','kg')),
    CHECK (tem_validade_impressa IN (0,1)),
    CHECK (venda_restrita_idade IN (0,1)),
    CHECK (ativo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE FORNECEDOR (
    id_fornecedor INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    razao_social VARCHAR(120) NOT NULL,
    cnpj VARCHAR(18) NOT NULL UNIQUE,
    telefone VARCHAR(20),
    email VARCHAR(120),
    endereco VARCHAR(200),
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (ativo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE FORNECEDOR_PRODUTO (
    id_fornecedor_produto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_fornecedor INT UNSIGNED NOT NULL,
    id_produto INT UNSIGNED NOT NULL,
    codigo_no_fornecedor VARCHAR(30),
    ultimo_custo DECIMAL(10,2),
    CONSTRAINT uq_fornecedor_produto UNIQUE (id_fornecedor,id_produto),
    CONSTRAINT fk_fp_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES FORNECEDOR(id_fornecedor) ON DELETE RESTRICT,
    CONSTRAINT fk_fp_produto FOREIGN KEY (id_produto) REFERENCES PRODUTO(id_produto) ON DELETE RESTRICT,
    CHECK (ultimo_custo IS NULL OR ultimo_custo >= 0)
) ENGINE=InnoDB;

CREATE TABLE FUNCIONARIO (
    id_funcionario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_setor INT UNSIGNED NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    cargo VARCHAR(60) NOT NULL,
    telefone VARCHAR(20),
    data_admissao DATE NOT NULL,
    perfil_acesso VARCHAR(20) NOT NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_funcionario_setor FOREIGN KEY (id_setor) REFERENCES SETOR(id_setor) ON DELETE RESTRICT,
    CHECK (perfil_acesso IN ('operador','supervisor','repositor','retaguarda','gerencia')),
    CHECK (ativo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE ESCALA (
    id_escala INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_funcionario INT UNSIGNED NOT NULL,
    data DATE NOT NULL,
    tipo VARCHAR(10) NOT NULL,
    hora_inicio TIME NULL,
    hora_fim TIME NULL,
    CONSTRAINT uq_escala_func_data UNIQUE (id_funcionario,data),
    CONSTRAINT fk_escala_funcionario FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (tipo IN ('trabalho','folga')),
    CHECK ((tipo='trabalho' AND hora_inicio IS NOT NULL AND hora_fim IS NOT NULL AND hora_fim > hora_inicio)
        OR (tipo='folga' AND hora_inicio IS NULL AND hora_fim IS NULL))
) ENGINE=InnoDB;

CREATE TABLE FORMA_PAGAMENTO (
    id_forma INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(50) NOT NULL UNIQUE,
    uso VARCHAR(12) NOT NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (uso IN ('venda','fornecedor','ambos')),
    CHECK (ativo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE CAIXA (
    id_caixa INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero INT UNSIGNED NOT NULL UNIQUE,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (ativo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE PEDIDO_COMPRA (
    id_pedido INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_fornecedor INT UNSIGNED NOT NULL,
    id_funcionario INT UNSIGNED NOT NULL,
    data_pedido DATE NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'aberto',
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES FORNECEDOR(id_fornecedor) ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_funcionario FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (status IN ('aberto','parcial','recebido','cancelado'))
) ENGINE=InnoDB;

CREATE TABLE ITEM_PEDIDO_COMPRA (
    id_item_pedido INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT UNSIGNED NOT NULL,
    id_produto INT UNSIGNED NOT NULL,
    quantidade DECIMAL(10,3) NOT NULL,
    custo_previsto DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_item_pedido_pedido FOREIGN KEY (id_pedido) REFERENCES PEDIDO_COMPRA(id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_item_pedido_produto FOREIGN KEY (id_produto) REFERENCES PRODUTO(id_produto) ON DELETE RESTRICT,
    CHECK (quantidade > 0),
    CHECK (custo_previsto >= 0)
) ENGINE=InnoDB;

CREATE TABLE RECEBIMENTO (
    id_recebimento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_fornecedor INT UNSIGNED NOT NULL,
    id_pedido INT UNSIGNED NULL,
    id_funcionario INT UNSIGNED NOT NULL,
    numero_nf VARCHAR(30) NOT NULL,
    serie VARCHAR(10) NOT NULL,
    chave_acesso VARCHAR(44) NULL UNIQUE,
    data_emissao DATE NOT NULL,
    data_recebimento DATETIME NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL,
    CONSTRAINT uq_recebimento_nf UNIQUE (id_fornecedor,numero_nf,serie),
    CONSTRAINT fk_receb_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES FORNECEDOR(id_fornecedor) ON DELETE RESTRICT,
    CONSTRAINT fk_receb_pedido FOREIGN KEY (id_pedido) REFERENCES PEDIDO_COMPRA(id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_receb_funcionario FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (valor_total >= 0)
) ENGINE=InnoDB;

CREATE TABLE ITEM_RECEBIMENTO (
    id_item_recebimento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_recebimento INT UNSIGNED NOT NULL,
    id_produto INT UNSIGNED NOT NULL,
    quantidade_nf DECIMAL(10,3) NOT NULL,
    quantidade_aceita DECIMAL(10,3) NOT NULL,
    quantidade_recusada DECIMAL(10,3) NOT NULL DEFAULT 0,
    custo_unitario_nf DECIMAL(10,2) NOT NULL,
    observacao_divergencia VARCHAR(200),
    CONSTRAINT fk_item_receb_receb FOREIGN KEY (id_recebimento) REFERENCES RECEBIMENTO(id_recebimento) ON DELETE RESTRICT,
    CONSTRAINT fk_item_receb_produto FOREIGN KEY (id_produto) REFERENCES PRODUTO(id_produto) ON DELETE RESTRICT,
    CHECK (quantidade_nf > 0),
    CHECK (quantidade_aceita >= 0),
    CHECK (quantidade_recusada >= 0),
    CHECK (quantidade_nf = quantidade_aceita + quantidade_recusada),
    CHECK (custo_unitario_nf >= 0)
) ENGINE=InnoDB;

CREATE TABLE CONTA_PAGAR (
    id_conta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_recebimento INT UNSIGNED NOT NULL UNIQUE,
    id_forma INT UNSIGNED NULL,
    id_funcionario_pagamento INT UNSIGNED NULL,
    data_vencimento DATE NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    data_pagamento DATETIME NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'aberta',
    CONSTRAINT fk_conta_receb FOREIGN KEY (id_recebimento) REFERENCES RECEBIMENTO(id_recebimento) ON DELETE RESTRICT,
    CONSTRAINT fk_conta_forma FOREIGN KEY (id_forma) REFERENCES FORMA_PAGAMENTO(id_forma) ON DELETE RESTRICT,
    CONSTRAINT fk_conta_func_pag FOREIGN KEY (id_funcionario_pagamento) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (valor > 0),
    CHECK (status IN ('aberta','paga','cancelada')),
    CHECK ((status='paga' AND data_pagamento IS NOT NULL AND id_forma IS NOT NULL AND id_funcionario_pagamento IS NOT NULL)
        OR (status<>'paga' AND data_pagamento IS NULL))
) ENGINE=InnoDB;

CREATE TABLE DEVOLUCAO_FORNECEDOR (
    id_devolucao INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_recebimento INT UNSIGNED NOT NULL,
    id_funcionario INT UNSIGNED NOT NULL,
    id_conta INT UNSIGNED NULL,
    data DATE NOT NULL,
    tipo VARCHAR(12) NOT NULL,
    motivo VARCHAR(200) NOT NULL,
    valor_abatimento DECIMAL(10,2) NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'aberta',
    CONSTRAINT fk_dev_receb FOREIGN KEY (id_recebimento) REFERENCES RECEBIMENTO(id_recebimento) ON DELETE RESTRICT,
    CONSTRAINT fk_dev_func FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CONSTRAINT fk_dev_conta FOREIGN KEY (id_conta) REFERENCES CONTA_PAGAR(id_conta) ON DELETE RESTRICT,
    CHECK (tipo IN ('devolucao','troca','abatimento')),
    CHECK (status IN ('aberta','concluida','cancelada')),
    CHECK ((tipo='abatimento' AND valor_abatimento IS NOT NULL AND valor_abatimento > 0 AND id_conta IS NOT NULL)
        OR (tipo<>'abatimento' AND valor_abatimento IS NULL AND id_conta IS NULL))
) ENGINE=InnoDB;

CREATE TABLE ITEM_DEVOLUCAO (
    id_item_devolucao INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_devolucao INT UNSIGNED NOT NULL,
    id_item_recebimento INT UNSIGNED NOT NULL,
    quantidade DECIMAL(10,3) NOT NULL,
    observacao VARCHAR(200),
    CONSTRAINT fk_item_dev_dev FOREIGN KEY (id_devolucao) REFERENCES DEVOLUCAO_FORNECEDOR(id_devolucao) ON DELETE RESTRICT,
    CONSTRAINT fk_item_dev_item_receb FOREIGN KEY (id_item_recebimento) REFERENCES ITEM_RECEBIMENTO(id_item_recebimento) ON DELETE RESTRICT,
    CHECK (quantidade > 0)
) ENGINE=InnoDB;

CREATE TABLE LOTE (
    id_lote INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_item_recebimento INT UNSIGNED NOT NULL,
    id_produto INT UNSIGNED NOT NULL,
    codigo_lote VARCHAR(40) NULL,
    data_fabricacao DATE NULL,
    data_validade DATE NULL,
    quantidade_recebida DECIMAL(10,3) NOT NULL,
    quantidade_atual DECIMAL(10,3) NOT NULL,
    custo_unitario DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_lote_item_receb FOREIGN KEY (id_item_recebimento) REFERENCES ITEM_RECEBIMENTO(id_item_recebimento) ON DELETE RESTRICT,
    CONSTRAINT fk_lote_produto FOREIGN KEY (id_produto) REFERENCES PRODUTO(id_produto) ON DELETE RESTRICT,
    CHECK (quantidade_recebida > 0),
    CHECK (quantidade_atual >= 0 AND quantidade_atual <= quantidade_recebida),
    CHECK (custo_unitario >= 0),
    CHECK (data_validade IS NULL OR data_fabricacao IS NULL OR data_validade >= data_fabricacao)
) ENGINE=InnoDB;

CREATE TABLE MOTIVO_PERDA (
    id_motivo INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(80) NOT NULL UNIQUE,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CHECK (ativo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE PERDA (
    id_perda INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_produto INT UNSIGNED NOT NULL,
    id_setor INT UNSIGNED NOT NULL,
    id_motivo INT UNSIGNED NOT NULL,
    id_funcionario INT UNSIGNED NOT NULL,
    id_lote INT UNSIGNED NULL,
    id_perda_original INT UNSIGNED NULL,
    data_hora DATETIME NOT NULL,
    quantidade DECIMAL(10,3) NOT NULL,
    valor_estimado DECIMAL(10,2) NULL,
    situacao_lote VARCHAR(18) NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'valida',
    observacao VARCHAR(250),
    CONSTRAINT fk_perda_produto FOREIGN KEY (id_produto) REFERENCES PRODUTO(id_produto) ON DELETE RESTRICT,
    CONSTRAINT fk_perda_setor FOREIGN KEY (id_setor) REFERENCES SETOR(id_setor) ON DELETE RESTRICT,
    CONSTRAINT fk_perda_motivo FOREIGN KEY (id_motivo) REFERENCES MOTIVO_PERDA(id_motivo) ON DELETE RESTRICT,
    CONSTRAINT fk_perda_func FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CONSTRAINT fk_perda_lote FOREIGN KEY (id_lote) REFERENCES LOTE(id_lote) ON DELETE RESTRICT,
    CONSTRAINT fk_perda_original FOREIGN KEY (id_perda_original) REFERENCES PERDA(id_perda) ON DELETE RESTRICT,
    CHECK (quantidade > 0),
    CHECK (situacao_lote IN ('confirmado','lote_a_confirmar')),
    CHECK (status IN ('valida','substituida')),
    CHECK ((situacao_lote='confirmado' AND id_lote IS NOT NULL AND valor_estimado IS NOT NULL)
        OR (situacao_lote='lote_a_confirmar' AND id_lote IS NULL AND valor_estimado IS NULL))
) ENGINE=InnoDB;

CREATE TABLE PROMOCAO (
    id_promocao INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_lote INT UNSIGNED NOT NULL,
    id_funcionario INT UNSIGNED NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    preco_normal DECIMAL(10,2) NOT NULL,
    preco_promocional DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_promocao_lote FOREIGN KEY (id_lote) REFERENCES LOTE(id_lote) ON DELETE RESTRICT,
    CONSTRAINT fk_promocao_func FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (preco_normal > 0),
    CHECK (preco_promocional > 0 AND preco_promocional < preco_normal),
    CHECK (data_fim >= data_inicio)
) ENGINE=InnoDB;

CREATE TABLE SESSAO_CAIXA (
    id_sessao INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_caixa INT UNSIGNED NOT NULL,
    id_funcionario_abertura INT UNSIGNED NOT NULL,
    id_funcionario_fechamento INT UNSIGNED NULL,
    data_abertura DATETIME NOT NULL,
    data_fechamento DATETIME NULL,
    fundo_inicial DECIMAL(10,2) NOT NULL DEFAULT 0,
    valor_esperado DECIMAL(10,2) NULL,
    valor_contado DECIMAL(10,2) NULL,
    diferenca DECIMAL(10,2) GENERATED ALWAYS AS (
        CASE WHEN valor_esperado IS NULL OR valor_contado IS NULL THEN NULL ELSE valor_contado - valor_esperado END
    ) STORED,
    status VARCHAR(10) NOT NULL DEFAULT 'aberta',
    caixa_aberto_unico INT UNSIGNED GENERATED ALWAYS AS (
        CASE WHEN status='aberta' THEN id_caixa ELSE NULL END
    ) STORED,
    CONSTRAINT uq_caixa_sessao_aberta UNIQUE (caixa_aberto_unico),
    CONSTRAINT fk_sessao_caixa FOREIGN KEY (id_caixa) REFERENCES CAIXA(id_caixa) ON DELETE RESTRICT,
    CONSTRAINT fk_sessao_func_abre FOREIGN KEY (id_funcionario_abertura) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CONSTRAINT fk_sessao_func_fecha FOREIGN KEY (id_funcionario_fechamento) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (fundo_inicial >= 0),
    CHECK (status IN ('aberta','fechada')),
    CHECK ((status='aberta' AND data_fechamento IS NULL AND id_funcionario_fechamento IS NULL AND valor_esperado IS NULL AND valor_contado IS NULL)
        OR (status='fechada' AND data_fechamento IS NOT NULL AND id_funcionario_fechamento IS NOT NULL AND valor_esperado IS NOT NULL AND valor_contado IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE TROCA_OPERADOR (
    id_troca INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_sessao INT UNSIGNED NOT NULL,
    id_funcionario_anterior INT UNSIGNED NOT NULL,
    id_funcionario_novo INT UNSIGNED NOT NULL,
    data_hora DATETIME NOT NULL,
    CONSTRAINT fk_troca_sessao FOREIGN KEY (id_sessao) REFERENCES SESSAO_CAIXA(id_sessao) ON DELETE RESTRICT,
    CONSTRAINT fk_troca_anterior FOREIGN KEY (id_funcionario_anterior) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CONSTRAINT fk_troca_novo FOREIGN KEY (id_funcionario_novo) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (id_funcionario_anterior <> id_funcionario_novo)
) ENGINE=InnoDB;

CREATE TABLE SANGRIA (
    id_sangria INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_sessao INT UNSIGNED NOT NULL,
    id_funcionario INT UNSIGNED NOT NULL,
    data_hora DATETIME NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_sangria_sessao FOREIGN KEY (id_sessao) REFERENCES SESSAO_CAIXA(id_sessao) ON DELETE RESTRICT,
    CONSTRAINT fk_sangria_func FOREIGN KEY (id_funcionario) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (valor > 0)
) ENGINE=InnoDB;

CREATE TABLE VENDA (
    id_venda INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_sessao INT UNSIGNED NOT NULL,
    id_funcionario_operador INT UNSIGNED NOT NULL,
    id_funcionario_supervisor INT UNSIGNED NULL,
    data_hora DATETIME NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL DEFAULT 0,
    status VARCHAR(15) NOT NULL DEFAULT 'em_andamento',
    motivo_cancelamento VARCHAR(200) NULL,
    data_hora_cancelamento DATETIME NULL,
    CONSTRAINT fk_venda_sessao FOREIGN KEY (id_sessao) REFERENCES SESSAO_CAIXA(id_sessao) ON DELETE RESTRICT,
    CONSTRAINT fk_venda_operador FOREIGN KEY (id_funcionario_operador) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CONSTRAINT fk_venda_supervisor FOREIGN KEY (id_funcionario_supervisor) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (valor_total >= 0),
    CHECK (status IN ('em_andamento','concluida','cancelada')),
    CHECK ((status='cancelada' AND id_funcionario_supervisor IS NOT NULL AND motivo_cancelamento IS NOT NULL AND data_hora_cancelamento IS NOT NULL)
        OR (status<>'cancelada' AND id_funcionario_supervisor IS NULL AND motivo_cancelamento IS NULL AND data_hora_cancelamento IS NULL))
) ENGINE=InnoDB;

CREATE TABLE ITEM_VENDA (
    id_item_venda INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venda INT UNSIGNED NOT NULL,
    id_produto INT UNSIGNED NOT NULL,
    id_funcionario_cancelamento INT UNSIGNED NULL,
    quantidade_ou_peso DECIMAL(10,3) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (ROUND(quantidade_ou_peso * preco_unitario,2)) STORED,
    status VARCHAR(12) NOT NULL DEFAULT 'ativo',
    motivo_cancelamento VARCHAR(200) NULL,
    data_hora_cancelamento DATETIME NULL,
    CONSTRAINT fk_item_venda_venda FOREIGN KEY (id_venda) REFERENCES VENDA(id_venda) ON DELETE RESTRICT,
    CONSTRAINT fk_item_venda_produto FOREIGN KEY (id_produto) REFERENCES PRODUTO(id_produto) ON DELETE RESTRICT,
    CONSTRAINT fk_item_venda_func_cancel FOREIGN KEY (id_funcionario_cancelamento) REFERENCES FUNCIONARIO(id_funcionario) ON DELETE RESTRICT,
    CHECK (quantidade_ou_peso > 0),
    CHECK (preco_unitario > 0),
    CHECK (status IN ('ativo','cancelado')),
    CHECK ((status='cancelado' AND id_funcionario_cancelamento IS NOT NULL AND motivo_cancelamento IS NOT NULL AND data_hora_cancelamento IS NOT NULL)
        OR (status='ativo' AND id_funcionario_cancelamento IS NULL AND motivo_cancelamento IS NULL AND data_hora_cancelamento IS NULL))
) ENGINE=InnoDB;

CREATE TABLE PAGAMENTO (
    id_pagamento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venda INT UNSIGNED NOT NULL,
    id_forma INT UNSIGNED NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_pagamento_venda FOREIGN KEY (id_venda) REFERENCES VENDA(id_venda) ON DELETE RESTRICT,
    CONSTRAINT fk_pagamento_forma FOREIGN KEY (id_forma) REFERENCES FORMA_PAGAMENTO(id_forma) ON DELETE RESTRICT,
    CHECK (valor > 0)
) ENGINE=InnoDB;

CREATE TABLE DOCUMENTO_FISCAL (
    id_documento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venda INT UNSIGNED NOT NULL UNIQUE,
    tipo_documento VARCHAR(10) NOT NULL,
    numero_documento VARCHAR(30) NOT NULL,
    serie VARCHAR(10),
    chave_acesso VARCHAR(44) NULL UNIQUE,
    data_emissao DATETIME NOT NULL,
    situacao VARCHAR(12) NOT NULL,
    CONSTRAINT fk_documento_venda FOREIGN KEY (id_venda) REFERENCES VENDA(id_venda) ON DELETE RESTRICT,
    CHECK (tipo_documento IN ('NFCe','SAT','OUTRO')),
    CHECK (situacao IN ('emitido','cancelado'))
) ENGINE=InnoDB;

CREATE TABLE SAIDA_LOTE (
    id_saida_lote INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_lote INT UNSIGNED NOT NULL,
    id_item_venda INT UNSIGNED NULL,
    id_perda INT UNSIGNED NULL,
    id_saida_original INT UNSIGNED NULL UNIQUE,
    quantidade DECIMAL(10,3) NOT NULL,
    data_hora DATETIME NOT NULL,
    tipo VARCHAR(10) NOT NULL,
    CONSTRAINT fk_saida_lote FOREIGN KEY (id_lote) REFERENCES LOTE(id_lote) ON DELETE RESTRICT,
    CONSTRAINT fk_saida_item_venda FOREIGN KEY (id_item_venda) REFERENCES ITEM_VENDA(id_item_venda) ON DELETE RESTRICT,
    CONSTRAINT fk_saida_perda FOREIGN KEY (id_perda) REFERENCES PERDA(id_perda) ON DELETE RESTRICT,
    CONSTRAINT fk_saida_original FOREIGN KEY (id_saida_original) REFERENCES SAIDA_LOTE(id_saida_lote) ON DELETE RESTRICT,
    CHECK (quantidade > 0),
    CHECK (tipo IN ('venda','perda','estorno')),
    CHECK ((tipo='venda' AND id_item_venda IS NOT NULL AND id_perda IS NULL AND id_saida_original IS NULL)
        OR (tipo='perda' AND id_item_venda IS NULL AND id_perda IS NOT NULL AND id_saida_original IS NULL)
        OR (tipo='estorno' AND id_item_venda IS NULL AND id_perda IS NULL AND id_saida_original IS NOT NULL))
) ENGINE=InnoDB;

-- ================================================================
-- 2. INDICES E VIEW DE SALDO
-- ================================================================

CREATE INDEX idx_lote_validade ON LOTE(data_validade);
CREATE INDEX idx_lote_produto ON LOTE(id_produto);
CREATE INDEX idx_perda_data ON PERDA(data_hora);
CREATE INDEX idx_perda_setor ON PERDA(id_setor);
CREATE INDEX idx_perda_motivo ON PERDA(id_motivo);
CREATE INDEX idx_venda_data ON VENDA(data_hora);
CREATE INDEX idx_venda_sessao ON VENDA(id_sessao);
CREATE INDEX idx_item_venda_venda ON ITEM_VENDA(id_venda);
CREATE INDEX idx_item_venda_produto ON ITEM_VENDA(id_produto);
CREATE INDEX idx_pagamento_venda ON PAGAMENTO(id_venda);
CREATE INDEX idx_saida_lote_lote ON SAIDA_LOTE(id_lote);
CREATE INDEX idx_conta_venc_status ON CONTA_PAGAR(data_vencimento,status);

CREATE VIEW vw_saldo_produto AS
SELECT p.id_produto,
       p.nome,
       COALESCE(SUM(l.quantidade_atual),0) AS saldo_lotes,
       COALESCE((SELECT SUM(pe.quantidade)
                 FROM PERDA pe
                 WHERE pe.id_produto=p.id_produto
                   AND pe.status='valida'
                   AND pe.situacao_lote='lote_a_confirmar'),0) AS perdas_pendentes,
       COALESCE(SUM(l.quantidade_atual),0) -
       COALESCE((SELECT SUM(pe.quantidade)
                 FROM PERDA pe
                 WHERE pe.id_produto=p.id_produto
                   AND pe.status='valida'
                   AND pe.situacao_lote='lote_a_confirmar'),0) AS saldo_disponivel
FROM PRODUTO p
LEFT JOIN LOTE l ON l.id_produto=p.id_produto
GROUP BY p.id_produto,p.nome;

-- ================================================================
-- 3. TRIGGERS
-- ================================================================

DELIMITER $$

CREATE TRIGGER trg_produto_bi_setor
BEFORE INSERT ON PRODUTO
FOR EACH ROW
BEGIN
    DECLARE v_vende TINYINT;
    SELECT vende_produto INTO v_vende FROM SETOR WHERE id_setor=NEW.id_setor;
    IF v_vende <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto deve pertencer a setor que vende produto';
    END IF;
END$$

CREATE TRIGGER trg_produto_bu_setor
BEFORE UPDATE ON PRODUTO
FOR EACH ROW
BEGIN
    DECLARE v_vende TINYINT;
    IF NEW.id_setor <> OLD.id_setor THEN
        SELECT vende_produto INTO v_vende FROM SETOR WHERE id_setor=NEW.id_setor;
        IF v_vende <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto deve pertencer a setor que vende produto';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_forma_pagamento_bu_uso
BEFORE UPDATE ON FORMA_PAGAMENTO
FOR EACH ROW
BEGIN
    IF NEW.uso <> OLD.uso AND (
        EXISTS(SELECT 1 FROM PAGAMENTO WHERE id_forma=OLD.id_forma LIMIT 1)
        OR EXISTS(SELECT 1 FROM CONTA_PAGAR WHERE id_forma=OLD.id_forma LIMIT 1)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nao e permitido alterar o uso de forma de pagamento com historico';
    END IF;
END$$

CREATE TRIGGER trg_pedido_bi_funcionario
BEFORE INSERT ON PEDIDO_COMPRA
FOR EACH ROW
BEGIN
    IF NOT EXISTS(SELECT 1 FROM FORNECEDOR WHERE id_fornecedor=NEW.id_fornecedor AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fornecedor inativo ou inexistente';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
    END IF;
END$$

CREATE TRIGGER trg_recebimento_bi_validar
BEFORE INSERT ON RECEBIMENTO
FOR EACH ROW
BEGIN
    DECLARE v_fornecedor_pedido INT UNSIGNED;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
    END IF;
    IF NEW.id_pedido IS NOT NULL THEN
        SELECT id_fornecedor INTO v_fornecedor_pedido FROM PEDIDO_COMPRA WHERE id_pedido=NEW.id_pedido;
        IF v_fornecedor_pedido <> NEW.id_fornecedor THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fornecedor do recebimento diferente do pedido';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_recebimento_bu_validar
BEFORE UPDATE ON RECEBIMENTO
FOR EACH ROW
BEGIN
    DECLARE v_fornecedor_pedido INT UNSIGNED;

    IF NEW.id_funcionario<>OLD.id_funcionario THEN
        IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
        END IF;
    END IF;

    IF NOT (NEW.id_pedido <=> OLD.id_pedido) OR NEW.id_fornecedor<>OLD.id_fornecedor THEN
        IF NEW.id_pedido IS NOT NULL THEN
            SELECT id_fornecedor INTO v_fornecedor_pedido
            FROM PEDIDO_COMPRA WHERE id_pedido=NEW.id_pedido;
            IF v_fornecedor_pedido <> NEW.id_fornecedor THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fornecedor do recebimento diferente do pedido';
            END IF;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_lote_bi_validar
BEFORE INSERT ON LOTE
FOR EACH ROW
BEGIN
    DECLARE v_produto INT UNSIGNED;
    DECLARE v_aceita DECIMAL(10,3);
    DECLARE v_custo DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,3);

    SELECT id_produto, quantidade_aceita, custo_unitario_nf
      INTO v_produto, v_aceita, v_custo
    FROM ITEM_RECEBIMENTO
    WHERE id_item_recebimento=NEW.id_item_recebimento FOR UPDATE;
    SELECT COALESCE(SUM(quantidade_recebida),0) INTO v_total FROM LOTE WHERE id_item_recebimento=NEW.id_item_recebimento;

    IF v_produto <> NEW.id_produto THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto do lote diferente do item recebido';
    END IF;
    IF NEW.quantidade_recebida + v_total > v_aceita THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantidade do lote maior que a quantidade aceita no item';
    END IF;

    SET NEW.custo_unitario = v_custo;
    SET NEW.quantidade_atual = NEW.quantidade_recebida;
END$$

CREATE TRIGGER trg_lote_bu_validar
BEFORE UPDATE ON LOTE
FOR EACH ROW
BEGIN
    -- Os dados de origem do lote formam o historico do recebimento.
    -- Depois de criado, so o saldo atual deve variar pelas movimentacoes.
    IF NEW.id_item_recebimento<>OLD.id_item_recebimento
       OR NEW.id_produto<>OLD.id_produto
       OR NEW.quantidade_recebida<>OLD.quantidade_recebida
       OR NEW.custo_unitario<>OLD.custo_unitario THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Dados de origem do lote nao podem ser alterados';
    END IF;
END$$

CREATE TRIGGER trg_conta_bi_forma
BEFORE INSERT ON CONTA_PAGAR
FOR EACH ROW
BEGIN
    IF NEW.id_forma IS NOT NULL AND NOT EXISTS(
        SELECT 1 FROM FORMA_PAGAMENTO WHERE id_forma=NEW.id_forma AND ativo=1 AND uso IN ('fornecedor','ambos')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Forma de pagamento nao permitida para fornecedor';
    END IF;
END$$

CREATE TRIGGER trg_conta_bu_pagamento
BEFORE UPDATE ON CONTA_PAGAR
FOR EACH ROW
BEGIN
    IF NEW.status='paga' AND OLD.status<>'paga' THEN
        IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario_pagamento AND ativo=1) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario do pagamento inativo ou inexistente';
        END IF;
        IF NOT EXISTS(SELECT 1 FROM FORMA_PAGAMENTO WHERE id_forma=NEW.id_forma AND ativo=1 AND uso IN ('fornecedor','ambos')) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Forma de pagamento nao permitida para fornecedor';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_devolucao_bi_validar
BEFORE INSERT ON DEVOLUCAO_FORNECEDOR
FOR EACH ROW
BEGIN
    DECLARE v_fornecedor_receb INT UNSIGNED;
    DECLARE v_fornecedor_conta INT UNSIGNED;
    DECLARE v_status_conta VARCHAR(10);
    DECLARE v_valor_conta DECIMAL(10,2);

    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
    END IF;

    IF NEW.tipo='abatimento' AND NEW.status<>'cancelada' THEN
        SELECT r.id_fornecedor, c.status, c.valor
          INTO v_fornecedor_conta, v_status_conta, v_valor_conta
        FROM CONTA_PAGAR c
        JOIN RECEBIMENTO r ON r.id_recebimento=c.id_recebimento
        WHERE c.id_conta=NEW.id_conta;

        SELECT id_fornecedor INTO v_fornecedor_receb
        FROM RECEBIMENTO WHERE id_recebimento=NEW.id_recebimento;

        IF v_fornecedor_conta <> v_fornecedor_receb THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Conta do abatimento pertence a outro fornecedor';
        END IF;
        IF v_status_conta <> 'aberta' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Abatimento so pode ser ligado a conta aberta';
        END IF;
        IF NEW.valor_abatimento > v_valor_conta THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Abatimento maior que o valor da conta';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_devolucao_bu_validar
BEFORE UPDATE ON DEVOLUCAO_FORNECEDOR
FOR EACH ROW
BEGIN
    DECLARE v_fornecedor_receb INT UNSIGNED;
    DECLARE v_fornecedor_conta INT UNSIGNED;
    DECLARE v_status_conta VARCHAR(10);
    DECLARE v_valor_conta DECIMAL(10,2);

    IF NEW.id_funcionario <> OLD.id_funcionario THEN
        IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
        END IF;
    END IF;

    IF NEW.tipo='abatimento' AND NEW.status<>'cancelada'
       AND (NEW.tipo<>OLD.tipo OR NOT (NEW.id_conta <=> OLD.id_conta)
            OR NOT (NEW.valor_abatimento <=> OLD.valor_abatimento)
            OR NEW.id_recebimento<>OLD.id_recebimento
            OR (OLD.status='cancelada' AND NEW.status<>'cancelada')) THEN

        SELECT r.id_fornecedor, c.status, c.valor
          INTO v_fornecedor_conta, v_status_conta, v_valor_conta
        FROM CONTA_PAGAR c
        JOIN RECEBIMENTO r ON r.id_recebimento=c.id_recebimento
        WHERE c.id_conta=NEW.id_conta;

        SELECT id_fornecedor INTO v_fornecedor_receb
        FROM RECEBIMENTO WHERE id_recebimento=NEW.id_recebimento;

        IF v_fornecedor_conta <> v_fornecedor_receb THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Conta do abatimento pertence a outro fornecedor';
        END IF;
        IF v_status_conta <> 'aberta' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Abatimento so pode ser ligado a conta aberta';
        END IF;
        IF NEW.valor_abatimento > v_valor_conta THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Abatimento maior que o valor da conta';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_item_devolucao_bi_validar
BEFORE INSERT ON ITEM_DEVOLUCAO
FOR EACH ROW
BEGIN
    DECLARE v_receb_dev INT UNSIGNED;
    DECLARE v_receb_item INT UNSIGNED;
    DECLARE v_recusada DECIMAL(10,3);
    DECLARE v_total_devolvido DECIMAL(10,3);
    DECLARE v_status_dev VARCHAR(12);

    SELECT id_recebimento, status INTO v_receb_dev, v_status_dev
    FROM DEVOLUCAO_FORNECEDOR WHERE id_devolucao=NEW.id_devolucao;

    SELECT id_recebimento, quantidade_recusada INTO v_receb_item, v_recusada
    FROM ITEM_RECEBIMENTO WHERE id_item_recebimento=NEW.id_item_recebimento;

    IF v_receb_dev <> v_receb_item THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Item devolvido nao pertence ao recebimento da devolucao';
    END IF;

    IF v_status_dev <> 'cancelada' THEN
        SELECT COALESCE(SUM(idv.quantidade),0) INTO v_total_devolvido
        FROM ITEM_DEVOLUCAO idv
        JOIN DEVOLUCAO_FORNECEDOR df ON df.id_devolucao=idv.id_devolucao
        WHERE idv.id_item_recebimento=NEW.id_item_recebimento
          AND df.status<>'cancelada';

        IF v_total_devolvido + NEW.quantidade > v_recusada THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Total devolvido maior que a quantidade recusada';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_item_devolucao_bu_validar
BEFORE UPDATE ON ITEM_DEVOLUCAO
FOR EACH ROW
BEGIN
    DECLARE v_receb_dev INT UNSIGNED;
    DECLARE v_receb_item INT UNSIGNED;
    DECLARE v_recusada DECIMAL(10,3);
    DECLARE v_total_devolvido DECIMAL(10,3);
    DECLARE v_status_dev VARCHAR(12);

    IF NEW.id_devolucao<>OLD.id_devolucao
       OR NEW.id_item_recebimento<>OLD.id_item_recebimento
       OR NEW.quantidade<>OLD.quantidade THEN

        SELECT id_recebimento, status INTO v_receb_dev, v_status_dev
        FROM DEVOLUCAO_FORNECEDOR WHERE id_devolucao=NEW.id_devolucao;

        SELECT id_recebimento, quantidade_recusada INTO v_receb_item, v_recusada
        FROM ITEM_RECEBIMENTO WHERE id_item_recebimento=NEW.id_item_recebimento;

        IF v_receb_dev <> v_receb_item THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Item devolvido nao pertence ao recebimento da devolucao';
        END IF;

        IF v_status_dev <> 'cancelada' THEN
            SELECT COALESCE(SUM(idv.quantidade),0) INTO v_total_devolvido
            FROM ITEM_DEVOLUCAO idv
            JOIN DEVOLUCAO_FORNECEDOR df ON df.id_devolucao=idv.id_devolucao
            WHERE idv.id_item_recebimento=NEW.id_item_recebimento
              AND idv.id_item_devolucao<>OLD.id_item_devolucao
              AND df.status<>'cancelada';

            IF v_total_devolvido + NEW.quantidade > v_recusada THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Total devolvido maior que a quantidade recusada';
            END IF;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_perda_bi_validar
BEFORE INSERT ON PERDA
FOR EACH ROW
BEGIN
    DECLARE v_setor INT UNSIGNED;
    DECLARE v_vende TINYINT;
    DECLARE v_prod_lote INT UNSIGNED;
    DECLARE v_saldo_lotes DECIMAL(10,3);

    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
    END IF;

    SELECT id_setor INTO v_setor FROM PRODUTO WHERE id_produto=NEW.id_produto FOR UPDATE;
    SELECT vende_produto INTO v_vende FROM SETOR WHERE id_setor=NEW.id_setor;
    IF v_setor <> NEW.id_setor OR v_vende <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Setor da perda deve ser o setor atual do produto';
    END IF;

    IF NEW.situacao_lote='confirmado' THEN
        SELECT id_produto INTO v_prod_lote FROM LOTE WHERE id_lote=NEW.id_lote;
        IF v_prod_lote <> NEW.id_produto THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote da perda pertence a outro produto';
        END IF;
    ELSE
        SELECT COALESCE(SUM(quantidade_atual),0) INTO v_saldo_lotes
        FROM LOTE WHERE id_produto=NEW.id_produto;
        SELECT v_saldo_lotes-COALESCE(SUM(quantidade),0) INTO v_saldo_lotes FROM PERDA WHERE id_produto=NEW.id_produto AND status='valida' AND situacao_lote='lote_a_confirmar';
        IF NEW.quantidade > v_saldo_lotes THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Perda pendente maior que o saldo dos lotes do produto';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_perda_bu_validar
BEFORE UPDATE ON PERDA
FOR EACH ROW
BEGIN
    DECLARE v_setor INT UNSIGNED;
    DECLARE v_vende TINYINT;
    DECLARE v_prod_lote INT UNSIGNED;

    IF NEW.id_funcionario<>OLD.id_funcionario THEN
        IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
        END IF;
    END IF;

    IF NEW.id_produto<>OLD.id_produto OR NEW.id_setor<>OLD.id_setor THEN
        SELECT id_setor INTO v_setor FROM PRODUTO WHERE id_produto=NEW.id_produto FOR UPDATE;
        SELECT vende_produto INTO v_vende FROM SETOR WHERE id_setor=NEW.id_setor;
        IF v_setor <> NEW.id_setor OR v_vende <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Setor da perda deve ser o setor atual do produto';
        END IF;
    END IF;

    IF NEW.situacao_lote='confirmado'
       AND (NEW.situacao_lote<>OLD.situacao_lote OR NOT (NEW.id_lote <=> OLD.id_lote)
            OR NEW.id_produto<>OLD.id_produto) THEN
        SELECT id_produto INTO v_prod_lote FROM LOTE WHERE id_lote=NEW.id_lote;
        IF v_prod_lote <> NEW.id_produto THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote da perda pertence a outro produto';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_promocao_bi_validar
BEFORE INSERT ON PROMOCAO
FOR EACH ROW
BEGIN
    DECLARE v_validade DATE;
    DECLARE v_preco DECIMAL(10,2);

    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
    END IF;

    SELECT l.data_validade, p.preco_venda INTO v_validade, v_preco
    FROM LOTE l JOIN PRODUTO p ON p.id_produto=l.id_produto
    WHERE l.id_lote=NEW.id_lote;

    IF v_validade IS NULL OR NEW.data_inicio > v_validade OR NEW.data_fim > v_validade THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Promocao deve terminar ate a validade do lote';
    END IF;
    IF NEW.preco_normal <> v_preco THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preco normal da promocao deve ser o preco atual do produto';
    END IF;
END$$

CREATE TRIGGER trg_promocao_bu_validar
BEFORE UPDATE ON PROMOCAO
FOR EACH ROW
BEGIN
    DECLARE v_validade DATE;
    DECLARE v_preco DECIMAL(10,2);

    IF NEW.id_funcionario<>OLD.id_funcionario THEN
        IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
        END IF;
    END IF;

    IF NEW.id_lote<>OLD.id_lote OR NEW.preco_normal<>OLD.preco_normal THEN
        SELECT p.preco_venda INTO v_preco
        FROM LOTE l JOIN PRODUTO p ON p.id_produto=l.id_produto
        WHERE l.id_lote=NEW.id_lote;
        IF NEW.preco_normal <> v_preco THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Preco normal da promocao deve ser o preco atual do produto';
        END IF;
    END IF;

    IF NEW.id_lote<>OLD.id_lote OR NEW.data_inicio<>OLD.data_inicio OR NEW.data_fim<>OLD.data_fim THEN
        SELECT data_validade INTO v_validade FROM LOTE WHERE id_lote=NEW.id_lote;
        IF v_validade IS NULL OR NEW.data_inicio > v_validade OR NEW.data_fim > v_validade THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Promocao deve terminar ate a validade do lote';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_sessao_bi_validar
BEFORE INSERT ON SESSAO_CAIXA
FOR EACH ROW
BEGIN
    IF NOT EXISTS(SELECT 1 FROM CAIXA WHERE id_caixa=NEW.id_caixa AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Caixa inativo ou inexistente';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario_abertura AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario de abertura inativo ou inexistente';
    END IF;
END$$

CREATE TRIGGER trg_troca_bi_validar
BEFORE INSERT ON TROCA_OPERADOR
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM SESSAO_CAIXA WHERE id_sessao=NEW.id_sessao;
    IF v_status <> 'aberta' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Troca de operador so pode ocorrer em sessao aberta';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario_novo AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Novo operador inativo ou inexistente';
    END IF;
END$$

CREATE TRIGGER trg_sangria_bi_validar
BEFORE INSERT ON SANGRIA
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM SESSAO_CAIXA WHERE id_sessao=NEW.id_sessao;
    IF v_status <> 'aberta' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sangria so pode ser registrada em sessao aberta';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario inativo ou inexistente';
    END IF;
END$$

CREATE TRIGGER trg_venda_bi_validar
BEFORE INSERT ON VENDA
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_operador INT UNSIGNED;
    SELECT status, id_funcionario_abertura INTO v_status, v_operador FROM SESSAO_CAIXA WHERE id_sessao=NEW.id_sessao;
    IF v_status <> 'aberta' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venda so pode ser aberta em sessao de caixa aberta';
    END IF;
    SELECT COALESCE((SELECT id_funcionario_novo FROM TROCA_OPERADOR WHERE id_sessao=NEW.id_sessao ORDER BY data_hora DESC,id_troca DESC LIMIT 1),v_operador)
      INTO v_operador;
    IF NEW.id_funcionario_operador <> v_operador THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Operador da venda diferente do operador atual da sessao';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario_operador AND ativo=1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Operador inativo ou inexistente';
    END IF;
END$$

CREATE TRIGGER trg_item_venda_bi_quantidade
BEFORE INSERT ON ITEM_VENDA
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(10);
    DECLARE v_ativo TINYINT;
    SELECT tipo_venda, ativo INTO v_tipo, v_ativo FROM PRODUTO WHERE id_produto=NEW.id_produto;
    IF v_ativo <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto inativo';
    END IF;
    IF v_tipo='unidade' AND NEW.quantidade_ou_peso <> FLOOR(NEW.quantidade_ou_peso) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto por unidade exige quantidade inteira';
    END IF;
END$$

CREATE TRIGGER trg_pagamento_bi_validar
BEFORE INSERT ON PAGAMENTO
FOR EACH ROW
BEGIN
    IF NOT EXISTS(SELECT 1 FROM FORMA_PAGAMENTO WHERE id_forma=NEW.id_forma AND ativo=1 AND uso IN ('venda','ambos')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Forma de pagamento nao permitida para venda';
    END IF;
END$$

CREATE TRIGGER trg_pagamento_bu_validar
BEFORE UPDATE ON PAGAMENTO
FOR EACH ROW
BEGIN
    IF NEW.id_forma<>OLD.id_forma THEN
        IF NOT EXISTS(SELECT 1 FROM FORMA_PAGAMENTO WHERE id_forma=NEW.id_forma AND ativo=1 AND uso IN ('venda','ambos')) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Forma de pagamento nao permitida para venda';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_saida_lote_bi_validar
BEFORE INSERT ON SAIDA_LOTE
FOR EACH ROW
BEGIN
    DECLARE v_saldo DECIMAL(10,3);
    DECLARE v_validade DATE;
    DECLARE v_prod_lote INT UNSIGNED;
    DECLARE v_prod_item INT UNSIGNED;
    DECLARE v_data_venda DATETIME;
    SELECT p.id_produto INTO v_prod_lote FROM PRODUTO p
    WHERE p.id_produto=(SELECT l.id_produto FROM LOTE l WHERE l.id_lote=NEW.id_lote) FOR UPDATE;
    SELECT quantidade_atual, data_validade, id_produto INTO v_saldo,v_validade,v_prod_lote
    FROM LOTE WHERE id_lote=NEW.id_lote FOR UPDATE;
    IF NEW.tipo IN ('venda','perda') AND NEW.quantidade > v_saldo THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Saida maior que o saldo do lote';
    END IF;
    IF NEW.tipo='venda' THEN
        SELECT iv.id_produto, v.data_hora INTO v_prod_item, v_data_venda
        FROM ITEM_VENDA iv JOIN VENDA v ON v.id_venda=iv.id_venda
        WHERE iv.id_item_venda=NEW.id_item_venda;
        IF v_prod_item <> v_prod_lote THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote e item de venda sao de produtos diferentes';
        END IF;
        IF v_validade IS NOT NULL AND DATE(v_data_venda) > v_validade THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote vencido nao pode ser vendido';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_saida_lote_ai_saldo
AFTER INSERT ON SAIDA_LOTE
FOR EACH ROW
BEGIN
    IF NEW.tipo='estorno' THEN
        UPDATE LOTE SET quantidade_atual=quantidade_atual+NEW.quantidade WHERE id_lote=NEW.id_lote;
    ELSE
        UPDATE LOTE SET quantidade_atual=quantidade_atual-NEW.quantidade WHERE id_lote=NEW.id_lote;
    END IF;
END$$

-- ================================================================
-- 4. PROCEDURES PRINCIPAIS
-- ================================================================

-- Procedure demonstrativa para registrar um recebimento com um item e um lote.
-- Para recebimentos maiores, os demais itens e lotes podem ser adicionados depois.
-- Adiciona um lote conferindo a soma dos lotes do item recebido.
-- Essa regra usa procedure porque depende da soma de varias linhas.
CREATE PROCEDURE adicionar_lote_recebimento(
    IN p_id_item_recebimento INT UNSIGNED,
    IN p_codigo_lote VARCHAR(40),
    IN p_data_fabricacao DATE,
    IN p_data_validade DATE,
    IN p_quantidade DECIMAL(10,3)
)
BEGIN
    DECLARE v_produto INT UNSIGNED;
    DECLARE v_aceita DECIMAL(10,3);
    DECLARE v_custo DECIMAL(10,2);
    DECLARE v_soma DECIMAL(10,3);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

    SELECT id_produto,quantidade_aceita,custo_unitario_nf
      INTO v_produto,v_aceita,v_custo
    FROM ITEM_RECEBIMENTO
    WHERE id_item_recebimento=p_id_item_recebimento
    FOR UPDATE;

    SELECT COALESCE(SUM(quantidade_recebida),0)
      INTO v_soma
    FROM LOTE
    WHERE id_item_recebimento=p_id_item_recebimento;

    IF v_soma + p_quantidade > v_aceita THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Soma dos lotes maior que a quantidade aceita no item';
    END IF;

    INSERT INTO LOTE(
        id_item_recebimento,id_produto,codigo_lote,data_fabricacao,data_validade,
        quantidade_recebida,quantidade_atual,custo_unitario
    ) VALUES(
        p_id_item_recebimento,v_produto,p_codigo_lote,p_data_fabricacao,p_data_validade,
        p_quantidade,p_quantidade,v_custo
    );

    COMMIT;
END$$

-- Registra abatimento conferindo o total ja ligado a conta.
CREATE PROCEDURE registrar_abatimento_fornecedor(
    IN p_id_recebimento INT UNSIGNED,
    IN p_id_funcionario INT UNSIGNED,
    IN p_id_conta INT UNSIGNED,
    IN p_data DATE,
    IN p_motivo VARCHAR(200),
    IN p_valor DECIMAL(10,2)
)
BEGIN
    DECLARE v_valor_conta DECIMAL(10,2);
    DECLARE v_soma DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

    SELECT valor INTO v_valor_conta
    FROM CONTA_PAGAR
    WHERE id_conta=p_id_conta AND status='aberta'
    FOR UPDATE;

    IF v_valor_conta IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Conta inexistente ou nao esta aberta';
    END IF;

    SELECT COALESCE(SUM(valor_abatimento),0) INTO v_soma
    FROM DEVOLUCAO_FORNECEDOR
    WHERE id_conta=p_id_conta AND tipo='abatimento' AND status<>'cancelada';

    IF v_soma + p_valor > v_valor_conta THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Soma dos abatimentos maior que o valor da conta';
    END IF;

    INSERT INTO DEVOLUCAO_FORNECEDOR(
        id_recebimento,id_funcionario,id_conta,data,tipo,motivo,valor_abatimento,status
    ) VALUES(
        p_id_recebimento,p_id_funcionario,p_id_conta,p_data,'abatimento',p_motivo,p_valor,'aberta'
    );

    COMMIT;
END$$

-- Registra perda sem lote usando o saldo disponivel real do produto.
CREATE PROCEDURE registrar_perda_pendente(
    IN p_id_produto INT UNSIGNED,
    IN p_id_setor INT UNSIGNED,
    IN p_id_motivo INT UNSIGNED,
    IN p_id_funcionario INT UNSIGNED,
    IN p_data DATETIME,
    IN p_quantidade DECIMAL(10,3),
    IN p_observacao VARCHAR(250)
)
BEGIN
    DECLARE v_saldo DECIMAL(10,3);
    DECLARE v_lock INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SELECT id_produto INTO v_lock FROM PRODUTO WHERE id_produto=p_id_produto FOR UPDATE;

    SELECT COALESCE(SUM(quantidade_atual),0)
      INTO v_saldo
    FROM LOTE
    WHERE id_produto=p_id_produto;

    SELECT v_saldo - COALESCE(SUM(quantidade),0)
      INTO v_saldo
    FROM PERDA
    WHERE id_produto=p_id_produto
      AND status='valida'
      AND situacao_lote='lote_a_confirmar';

    IF p_quantidade > COALESCE(v_saldo,0) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Perda pendente maior que o saldo disponivel do produto';
    END IF;

    INSERT INTO PERDA(
        id_produto,id_setor,id_motivo,id_funcionario,data_hora,quantidade,
        valor_estimado,situacao_lote,status,observacao
    ) VALUES(
        p_id_produto,p_id_setor,p_id_motivo,p_id_funcionario,p_data,p_quantidade,
        NULL,'lote_a_confirmar','valida',p_observacao
    );

    COMMIT;
END$$

CREATE PROCEDURE registrar_recebimento(
    IN p_id_fornecedor INT UNSIGNED,
    IN p_id_pedido INT UNSIGNED,
    IN p_id_funcionario INT UNSIGNED,
    IN p_numero_nf VARCHAR(30),
    IN p_serie VARCHAR(10),
    IN p_data_emissao DATE,
    IN p_data_recebimento DATETIME,
    IN p_valor_total DECIMAL(10,2),
    IN p_id_produto INT UNSIGNED,
    IN p_quantidade_nf DECIMAL(10,3),
    IN p_quantidade_aceita DECIMAL(10,3),
    IN p_custo_unitario DECIMAL(10,2),
    IN p_codigo_lote VARCHAR(40),
    IN p_data_validade DATE
)
BEGIN
    DECLARE v_id_recebimento INT UNSIGNED;
    DECLARE v_id_item INT UNSIGNED;
    DECLARE v_recusada DECIMAL(10,3);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_recusada = p_quantidade_nf - p_quantidade_aceita;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

    IF v_recusada < 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantidade aceita nao pode ser maior que a quantidade da nota';
    END IF;

    INSERT INTO RECEBIMENTO(
        id_fornecedor,id_pedido,id_funcionario,numero_nf,serie,
        data_emissao,data_recebimento,valor_total
    ) VALUES(
        p_id_fornecedor,p_id_pedido,p_id_funcionario,p_numero_nf,p_serie,
        p_data_emissao,p_data_recebimento,p_valor_total
    );
    SET v_id_recebimento = LAST_INSERT_ID();

    INSERT INTO ITEM_RECEBIMENTO(
        id_recebimento,id_produto,quantidade_nf,quantidade_aceita,
        quantidade_recusada,custo_unitario_nf
    ) VALUES(
        v_id_recebimento,p_id_produto,p_quantidade_nf,p_quantidade_aceita,
        v_recusada,p_custo_unitario
    );
    SET v_id_item = LAST_INSERT_ID();

    IF p_quantidade_aceita > 0 THEN
        INSERT INTO LOTE(
            id_item_recebimento,id_produto,codigo_lote,data_validade,
            quantidade_recebida,quantidade_atual,custo_unitario
        ) VALUES(
            v_id_item,p_id_produto,p_codigo_lote,p_data_validade,
            p_quantidade_aceita,p_quantidade_aceita,p_custo_unitario
        );
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE estornar_saida(IN p_id_saida INT UNSIGNED, IN p_data DATETIME)
BEGIN
    DECLARE v_lote INT UNSIGNED;
    DECLARE v_qtd DECIMAL(10,3);
    DECLARE v_tipo VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SELECT id_lote,quantidade,tipo INTO v_lote,v_qtd,v_tipo
    FROM SAIDA_LOTE WHERE id_saida_lote=p_id_saida FOR UPDATE;
    IF v_tipo='estorno' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nao e permitido estornar um estorno';
    END IF;
    IF EXISTS(SELECT 1 FROM SAIDA_LOTE WHERE id_saida_original=p_id_saida) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A baixa ja foi estornada';
    END IF;
    INSERT INTO SAIDA_LOTE(id_lote,id_saida_original,quantidade,data_hora,tipo)
    VALUES(v_lote,p_id_saida,v_qtd,p_data,'estorno');
    COMMIT;
END$$

CREATE PROCEDURE confirmar_lote_perda(IN p_id_perda INT UNSIGNED, IN p_id_lote INT UNSIGNED)
BEGIN
    DECLARE v_produto INT UNSIGNED;
    DECLARE v_prod_lote INT UNSIGNED;
    DECLARE v_qtd DECIMAL(10,3);
    DECLARE v_custo DECIMAL(10,2);
    DECLARE v_data DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SELECT p.id_produto INTO v_produto FROM PRODUTO p
    WHERE p.id_produto=(SELECT pe.id_produto FROM PERDA pe WHERE pe.id_perda=p_id_perda) FOR UPDATE;
    SET v_produto=NULL;
    SELECT id_produto,quantidade,data_hora INTO v_produto,v_qtd,v_data
    FROM PERDA WHERE id_perda=p_id_perda AND status='valida' AND situacao_lote='lote_a_confirmar' FOR UPDATE;
    IF v_produto IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Perda nao encontrada ou nao esta pendente';
    END IF;
    SELECT id_produto,custo_unitario INTO v_prod_lote,v_custo FROM LOTE WHERE id_lote=p_id_lote FOR UPDATE;
    IF v_prod_lote<>v_produto THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lote pertence a outro produto';
    END IF;
    UPDATE PERDA
       SET id_lote=p_id_lote, situacao_lote='confirmado', valor_estimado=ROUND(v_qtd*v_custo,2)
     WHERE id_perda=p_id_perda;
    INSERT INTO SAIDA_LOTE(id_lote,id_perda,quantidade,data_hora,tipo)
    VALUES(p_id_lote,p_id_perda,v_qtd,v_data,'perda');
    COMMIT;
END$$

CREATE PROCEDURE cancelar_venda(
    IN p_id_venda INT UNSIGNED,
    IN p_id_supervisor INT UNSIGNED,
    IN p_motivo VARCHAR(200),
    IN p_data DATETIME
)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_saida INT UNSIGNED;
    DECLARE v_status_venda VARCHAR(15);
    DECLARE c CURSOR FOR
        SELECT sl.id_saida_lote
        FROM SAIDA_LOTE sl
        JOIN ITEM_VENDA iv ON iv.id_item_venda=sl.id_item_venda
        WHERE iv.id_venda=p_id_venda AND iv.status='ativo' AND sl.tipo='venda'
          AND NOT EXISTS(SELECT 1 FROM SAIDA_LOTE e WHERE e.id_saida_original=sl.id_saida_lote)
        ORDER BY sl.id_saida_lote;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SET v_status_venda=NULL;
    SELECT status INTO v_status_venda FROM VENDA WHERE id_venda=p_id_venda FOR UPDATE;
    IF v_status_venda IS NULL OR v_status_venda<>'concluida' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Somente venda concluida pode ser cancelada';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=p_id_supervisor AND ativo=1 AND perfil_acesso IN ('supervisor','gerencia')) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cancelamento exige supervisor ativo';
    END IF;
    OPEN c;
    loop_estorno: LOOP
        FETCH c INTO v_saida;
        IF done=1 THEN LEAVE loop_estorno; END IF;
        INSERT INTO SAIDA_LOTE(id_lote,id_saida_original,quantidade,data_hora,tipo)
        SELECT id_lote,id_saida_lote,quantidade,p_data,'estorno'
        FROM SAIDA_LOTE WHERE id_saida_lote=v_saida;
    END LOOP;
    CLOSE c;
    UPDATE VENDA
       SET status='cancelada', id_funcionario_supervisor=p_id_supervisor,
           motivo_cancelamento=p_motivo, data_hora_cancelamento=p_data
     WHERE id_venda=p_id_venda;
    UPDATE DOCUMENTO_FISCAL SET situacao='cancelado' WHERE id_venda=p_id_venda;
    COMMIT;
END$$

CREATE PROCEDURE fechar_sessao(
    IN p_id_sessao INT UNSIGNED,
    IN p_id_funcionario INT UNSIGNED,
    IN p_data DATETIME,
    IN p_valor_contado DECIMAL(10,2)
)
BEGIN
    DECLARE v_fundo DECIMAL(10,2);
    DECLARE v_vendas DECIMAL(10,2);
    DECLARE v_sangrias DECIMAL(10,2);
    DECLARE v_esperado DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SELECT fundo_inicial INTO v_fundo FROM SESSAO_CAIXA WHERE id_sessao=p_id_sessao AND status='aberta' FOR UPDATE;
    IF v_fundo IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sessao nao encontrada ou ja fechada';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=p_id_funcionario AND ativo=1) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Funcionario de fechamento inativo';
    END IF;
    SELECT COALESCE(SUM(pg.valor),0) INTO v_vendas
    FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda
    JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma
    WHERE v.id_sessao=p_id_sessao AND v.status='concluida' AND fp.descricao='Dinheiro';
    SELECT COALESCE(SUM(valor),0) INTO v_sangrias FROM SANGRIA WHERE id_sessao=p_id_sessao;
    SET v_esperado=v_fundo+v_vendas-v_sangrias;
    UPDATE SESSAO_CAIXA
       SET status='fechada', data_fechamento=p_data, id_funcionario_fechamento=p_id_funcionario,
           valor_esperado=v_esperado, valor_contado=p_valor_contado
     WHERE id_sessao=p_id_sessao;
    COMMIT;
END$$

CREATE PROCEDURE concluir_venda(IN p_id_venda INT UNSIGNED)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_item INT UNSIGNED;
    DECLARE v_produto INT UNSIGNED;
    DECLARE v_qtd DECIMAL(10,3);
    DECLARE v_restante DECIMAL(10,3);
    DECLARE v_lote INT UNSIGNED;
    DECLARE v_saldo DECIMAL(10,3);
    DECLARE v_parte DECIMAL(10,3);
    DECLARE v_preco DECIMAL(10,2);
    DECLARE v_preco_promo DECIMAL(10,2);
    DECLARE v_data DATETIME;
    DECLARE v_novo_item INT UNSIGNED;
    DECLARE v_primeira TINYINT;
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_pago DECIMAL(10,2);
    DECLARE v_max_item INT UNSIGNED;
    DECLARE v_saldo_disponivel_produto DECIMAL(10,3);
    DECLARE c CURSOR FOR
        SELECT id_item_venda,id_produto,quantidade_ou_peso
        FROM ITEM_VENDA WHERE id_venda=p_id_venda AND status='ativo' AND id_item_venda<=v_max_item
        ORDER BY id_produto,id_item_venda;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done=1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SELECT data_hora INTO v_data FROM VENDA WHERE id_venda=p_id_venda AND status='em_andamento' FOR UPDATE;
    IF v_data IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venda nao encontrada ou nao esta em andamento';
    END IF;
    SELECT MAX(id_item_venda) INTO v_max_item FROM ITEM_VENDA WHERE id_venda=p_id_venda AND status='ativo';
    IF v_max_item IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venda sem itens ativos';
    END IF;

    OPEN c;
    loop_itens: LOOP
        FETCH c INTO v_item,v_produto,v_qtd;
        IF done=1 THEN LEAVE loop_itens; END IF;
        SELECT preco_venda INTO v_preco FROM PRODUTO WHERE id_produto=v_produto FOR UPDATE;
        SELECT COALESCE(SUM(l.quantidade_atual),0)
               - COALESCE((
                    SELECT SUM(pe.quantidade)
                    FROM PERDA pe
                    WHERE pe.id_produto=v_produto
                      AND pe.status='valida'
                      AND pe.situacao_lote='lote_a_confirmar'
                 ),0)
          INTO v_saldo_disponivel_produto
        FROM LOTE l
        WHERE l.id_produto=v_produto;

        IF v_qtd > v_saldo_disponivel_produto THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantidade da venda maior que o saldo disponivel do produto';
        END IF;

        SET v_restante=v_qtd;
        SET v_primeira=1;
        WHILE v_restante>0 DO
            SET v_lote=NULL;
            SELECT id_lote,quantidade_atual INTO v_lote,v_saldo
            FROM LOTE
            WHERE id_produto=v_produto AND quantidade_atual>0
              AND (data_validade IS NULL OR data_validade>=DATE(v_data))
            ORDER BY (data_validade IS NULL),data_validade,id_lote
            LIMIT 1 FOR UPDATE;
            IF v_lote IS NULL THEN
                ROLLBACK;
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Saldo insuficiente para concluir a venda';
            END IF;
            SET v_parte=LEAST(v_restante,v_saldo);
            SELECT preco_venda INTO v_preco FROM PRODUTO WHERE id_produto=v_produto;
            SET v_preco_promo=NULL;
            SELECT MIN(preco_promocional) INTO v_preco_promo
            FROM PROMOCAO
            WHERE id_lote=v_lote AND DATE(v_data) BETWEEN data_inicio AND data_fim;
            IF v_preco_promo IS NOT NULL THEN SET v_preco=v_preco_promo; END IF;
            IF v_primeira=1 THEN
                UPDATE ITEM_VENDA SET quantidade_ou_peso=v_parte,preco_unitario=v_preco WHERE id_item_venda=v_item;
                SET v_novo_item=v_item;
                SET v_primeira=0;
            ELSE
                INSERT INTO ITEM_VENDA(id_venda,id_produto,quantidade_ou_peso,preco_unitario,status)
                VALUES(p_id_venda,v_produto,v_parte,v_preco,'ativo');
                SET v_novo_item=LAST_INSERT_ID();
            END IF;
            INSERT INTO SAIDA_LOTE(id_lote,id_item_venda,quantidade,data_hora,tipo)
            VALUES(v_lote,v_novo_item,v_parte,v_data,'venda');
            SET v_restante=v_restante-v_parte;
        END WHILE;
    END LOOP;
    CLOSE c;

    SELECT ROUND(COALESCE(SUM(subtotal),0),2) INTO v_total
    FROM ITEM_VENDA WHERE id_venda=p_id_venda AND status='ativo';
    SELECT ROUND(COALESCE(SUM(valor),0),2) INTO v_pago FROM PAGAMENTO WHERE id_venda=p_id_venda;
    IF v_total<>v_pago THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pagamentos nao conferem com o total da venda';
    END IF;
    UPDATE VENDA SET valor_total=v_total,status='concluida' WHERE id_venda=p_id_venda;
    COMMIT;
END$$

DELIMITER ;

-- ================================================================
-- ================================================================
-- 5. MASSA DE DADOS FICTICIA - 200 VENDAS / 7 DIAS SIMULADOS
-- Hortifruti Uniao - Entrega 2
-- Periodo simulado: 26/10/2026 a 01/11/2026
-- Dados 100% ficticios. Nao reproduzem vendas ou pessoas reais.
-- Executar depois da criacao das tabelas, triggers e procedures.
-- ================================================================

USE hortifruti_uniao;

-- Permite substituir uma massa anterior ao testar apenas esta secao.
SET FOREIGN_KEY_CHECKS=0;
TRUNCATE TABLE SAIDA_LOTE;
TRUNCATE TABLE DOCUMENTO_FISCAL;
TRUNCATE TABLE PAGAMENTO;
TRUNCATE TABLE ITEM_VENDA;
TRUNCATE TABLE VENDA;
TRUNCATE TABLE SANGRIA;
TRUNCATE TABLE TROCA_OPERADOR;
TRUNCATE TABLE SESSAO_CAIXA;
TRUNCATE TABLE PROMOCAO;
TRUNCATE TABLE PERDA;
TRUNCATE TABLE MOTIVO_PERDA;
TRUNCATE TABLE LOTE;
TRUNCATE TABLE ITEM_DEVOLUCAO;
TRUNCATE TABLE DEVOLUCAO_FORNECEDOR;
TRUNCATE TABLE CONTA_PAGAR;
TRUNCATE TABLE ITEM_RECEBIMENTO;
TRUNCATE TABLE RECEBIMENTO;
TRUNCATE TABLE ITEM_PEDIDO_COMPRA;
TRUNCATE TABLE PEDIDO_COMPRA;
TRUNCATE TABLE CAIXA;
TRUNCATE TABLE FORMA_PAGAMENTO;
TRUNCATE TABLE ESCALA;
TRUNCATE TABLE FUNCIONARIO;
TRUNCATE TABLE FORNECEDOR_PRODUTO;
TRUNCATE TABLE FORNECEDOR;
TRUNCATE TABLE PRODUTO;
TRUNCATE TABLE SETOR;
SET FOREIGN_KEY_CHECKS=1;

-- 5.1 Cadastros

INSERT INTO SETOR (id_setor,nome,descricao,dias_alerta_validade,vende_produto) VALUES
(1,'Hortifruti','Frutas, legumes e verduras',NULL,1),
(2,'Padaria','Produtos de padaria',3,1),
(3,'Frios','Frios, queijos e fatiados',7,1),
(4,'Laticinios','Leites e derivados',7,1),
(5,'Embalados','Produtos industrializados e bebidas',10,1),
(6,'Secos','Graos, cereais e mercearia seca',15,1),
(7,'Caixa','Operacao dos caixas',NULL,0),
(8,'Retaguarda','Compras, recebimento e financeiro',NULL,0);

INSERT INTO PRODUTO (id_produto,id_setor,codigo_interno,codigo_barras,nome,preco_venda,estoque_minimo,tipo_venda,tem_validade_impressa,venda_restrita_idade,ativo) VALUES
(1,1,'P001',NULL,'Banana Prata',6.90,9.000,'kg',0,0,1),
(2,1,'P002',NULL,'Tomate Italiano',8.50,10.000,'kg',0,0,1),
(3,1,'P003',NULL,'Alface Crespa',9.39,11.000,'kg',0,0,1),
(4,1,'P004',NULL,'Maca Gala',11.12,12.000,'kg',0,0,1),
(5,1,'P005',NULL,'Mamao Formosa',12.85,13.000,'kg',0,0,1),
(6,1,'P006',NULL,'Cenoura',14.58,14.000,'kg',0,0,1),
(7,1,'P007',NULL,'Batata',16.31,15.000,'kg',0,0,1),
(8,1,'P008',NULL,'Laranja',18.04,8.000,'kg',0,0,1),
(9,1,'P009',NULL,'Abacate',19.77,9.000,'kg',0,0,1),
(10,1,'P010',NULL,'Manga',21.50,10.000,'kg',0,0,1),
(11,2,'P011','7890000000011','Pao de Forma',9.90,11.000,'unidade',1,0,1),
(12,2,'P012','7890000000012','Bolo de Chocolate',24.96,12.000,'unidade',1,0,1),
(13,2,'P013','7890000000013','Pao Integral',26.69,13.000,'unidade',1,0,1),
(14,2,'P014','7890000000014','Croissant',5.42,14.000,'unidade',1,0,1),
(15,2,'P015','7890000000015','Torrada',7.15,15.000,'unidade',1,0,1),
(16,2,'P016','7890000000016','Biscoito de Polvilho',8.88,8.000,'unidade',1,0,1),
(17,2,'P017','7890000000017','Rosquinha',10.61,9.000,'unidade',1,0,1),
(18,2,'P018','7890000000018','Pao de Leite',12.34,10.000,'unidade',1,0,1),
(19,2,'P019','7890000000019','Bolo de Milho',14.07,11.000,'unidade',1,0,1),
(20,2,'P020','7890000000020','Broa de Fuba',15.80,12.000,'unidade',1,0,1),
(21,3,'P021','7890000000021','Presunto Fatiado',12.90,13.000,'unidade',1,0,1),
(22,3,'P022','7890000000022','Queijo Mussarela 500g',18.90,14.000,'unidade',1,0,1),
(23,3,'P023','7890000000023','Peito de Peru',20.99,15.000,'unidade',1,0,1),
(24,3,'P024','7890000000024','Salame Fatiado',22.72,8.000,'unidade',1,0,1),
(25,3,'P025','7890000000025','Queijo Prato',24.45,9.000,'unidade',1,0,1),
(26,3,'P026','7890000000026','Mortadela',26.18,10.000,'unidade',1,0,1),
(27,3,'P027','7890000000027','Queijo Minas',4.91,11.000,'unidade',1,0,1),
(28,3,'P028','7890000000028','Provolone',6.64,12.000,'unidade',1,0,1),
(29,3,'P029','7890000000029','Copa Fatiada',8.37,13.000,'unidade',1,0,1),
(30,3,'P030','7890000000030','Ricota',10.10,14.000,'unidade',1,0,1),
(31,4,'P031','7890000000031','Leite Integral 1L',6.50,15.000,'unidade',1,0,1),
(32,4,'P032','7890000000032','Iogurte Natural',4.80,8.000,'unidade',1,0,1),
(33,4,'P033','7890000000033','Manteiga 200g',15.29,9.000,'unidade',1,0,1),
(34,4,'P034','7890000000034','Creme de Leite',17.02,10.000,'unidade',1,0,1),
(35,4,'P035','7890000000035','Leite Desnatado 1L',18.75,11.000,'unidade',1,0,1),
(36,4,'P036','7890000000036','Iogurte de Morango',20.48,12.000,'unidade',1,0,1),
(37,4,'P037','7890000000037','Queijo Cottage',22.21,13.000,'unidade',1,0,1),
(38,4,'P038','7890000000038','Bebida Lactea',23.94,14.000,'unidade',1,0,1),
(39,4,'P039','7890000000039','Leite Fermentado',25.67,15.000,'unidade',1,0,1),
(40,4,'P040','7890000000040','Coalhada',4.40,8.000,'unidade',1,0,1),
(41,5,'P041','7890000000041','Biscoito Integral',7.50,9.000,'unidade',1,0,1),
(42,5,'P042','7890000000042','Suco de Uva 1L',12.50,10.000,'unidade',1,0,1),
(43,5,'P043','7890000000043','Molho de Tomate',9.59,11.000,'unidade',1,0,1),
(44,5,'P044','7890000000044','Atum em Lata',11.32,12.000,'unidade',1,0,1),
(45,5,'P045','7890000000045','Sardinha em Lata',13.05,13.000,'unidade',1,0,1),
(46,5,'P046','7890000000046','Cafe 500g',14.78,14.000,'unidade',1,0,1),
(47,5,'P047','7890000000047','Achocolatado',16.51,15.000,'unidade',1,0,1),
(48,5,'P048','7890000000048','Agua de Coco',18.24,60.000,'unidade',1,0,1),
(49,5,'P049','7890000000049','Refrigerante 2L',19.97,9.000,'unidade',1,0,1),
(50,5,'P050','7890000000050','Bebida 750ml',21.70,10.000,'unidade',1,1,1),
(51,6,'P051','7890000000051','Arroz 5kg',27.90,11.000,'unidade',1,0,1),
(52,6,'P052','7890000000052','Feijao 1kg',25.16,12.000,'unidade',1,0,1),
(53,6,'P053','7890000000053','Macarrao 500g',26.89,13.000,'unidade',1,0,1),
(54,6,'P054','7890000000054','Acucar 1kg',5.62,14.000,'unidade',1,0,1),
(55,6,'P055','7890000000055','Farinha de Trigo 1kg',7.35,25.000,'unidade',1,0,1),
(56,6,'P056','7890000000056','Aveia 500g',9.08,25.000,'unidade',1,0,1),
(57,6,'P057','7890000000057','Granola 500g',10.81,25.000,'unidade',1,0,1),
(58,6,'P058','7890000000058','Lentilha 500g',12.54,25.000,'unidade',1,0,1),
(59,6,'P059','7890000000059','Grao de Bico 500g',14.27,25.000,'unidade',1,0,1),
(60,6,'P060','7890000000060','Milho para Pipoca 500g',16.00,25.000,'unidade',1,0,1);

INSERT INTO FORNECEDOR (id_fornecedor,razao_social,cnpj,telefone,email,endereco,ativo) VALUES
(1,'Fornecedor Ficticio 01','90.001.037/0001-17','11980000001','fornecedor01@exemplo.test','Endereco ficticio 1, Sao Paulo - SP',1),
(2,'Fornecedor Ficticio 02','90.002.074/0001-34','11980000002','fornecedor02@exemplo.test','Endereco ficticio 2, Sao Paulo - SP',1),
(3,'Fornecedor Ficticio 03','90.003.111/0001-51','11980000003','fornecedor03@exemplo.test','Endereco ficticio 3, Sao Paulo - SP',1),
(4,'Fornecedor Ficticio 04','90.004.148/0001-68','11980000004','fornecedor04@exemplo.test','Endereco ficticio 4, Sao Paulo - SP',1),
(5,'Fornecedor Ficticio 05','90.005.185/0001-85','11980000005','fornecedor05@exemplo.test','Endereco ficticio 5, Sao Paulo - SP',1),
(6,'Fornecedor Ficticio 06','90.006.222/0001-02','11980000006','fornecedor06@exemplo.test','Endereco ficticio 6, Sao Paulo - SP',1),
(7,'Fornecedor Ficticio 07','90.007.259/0001-19','11980000007','fornecedor07@exemplo.test','Endereco ficticio 7, Sao Paulo - SP',1),
(8,'Fornecedor Ficticio 08','90.008.296/0001-36','11980000008','fornecedor08@exemplo.test','Endereco ficticio 8, Sao Paulo - SP',1),
(9,'Fornecedor Ficticio 09','90.009.333/0001-53','11980000009','fornecedor09@exemplo.test','Endereco ficticio 9, Sao Paulo - SP',1),
(10,'Fornecedor Ficticio 10','90.010.370/0001-70','11980000010','fornecedor10@exemplo.test','Endereco ficticio 10, Sao Paulo - SP',1),
(11,'Fornecedor Ficticio 11','90.011.407/0001-87','11980000011','fornecedor11@exemplo.test','Endereco ficticio 11, Sao Paulo - SP',1),
(12,'Fornecedor Ficticio 12','90.012.444/0001-04','11980000012','fornecedor12@exemplo.test','Endereco ficticio 12, Sao Paulo - SP',1);

INSERT INTO FORNECEDOR_PRODUTO (id_fornecedor_produto,id_fornecedor,id_produto,codigo_no_fornecedor,ultimo_custo) VALUES
(1,1,1,'F01-P001',4.00),
(2,1,2,'F01-P002',4.93),
(3,1,3,'F01-P003',5.45),
(4,1,4,'F01-P004',6.45),
(5,1,5,'F01-P005',7.45),
(6,1,6,'F01-P006',8.46),
(7,2,7,'F02-P007',9.46),
(8,2,8,'F02-P008',10.46),
(9,2,9,'F02-P009',11.47),
(10,2,10,'F02-P010',12.47),
(11,2,11,'F02-P011',5.74),
(12,2,12,'F02-P012',14.48),
(13,3,13,'F03-P013',15.48),
(14,3,14,'F03-P014',3.14),
(15,3,15,'F03-P015',4.15),
(16,3,16,'F03-P016',5.15),
(17,3,17,'F03-P017',6.15),
(18,3,18,'F03-P018',7.16),
(19,4,19,'F04-P019',8.16),
(20,4,20,'F04-P020',9.16),
(21,4,21,'F04-P021',7.48),
(22,4,22,'F04-P022',10.96),
(23,4,23,'F04-P023',12.17),
(24,4,24,'F04-P024',13.18),
(25,5,25,'F05-P025',14.18),
(26,5,26,'F05-P026',15.18),
(27,5,27,'F05-P027',2.85),
(28,5,28,'F05-P028',3.85),
(29,5,29,'F05-P029',4.85),
(30,5,30,'F05-P030',5.86),
(31,6,31,'F06-P031',3.77),
(32,6,32,'F06-P032',2.78),
(33,6,33,'F06-P033',8.87),
(34,6,34,'F06-P034',9.87),
(35,6,35,'F06-P035',10.88),
(36,6,36,'F06-P036',11.88),
(37,7,37,'F07-P037',12.88),
(38,7,38,'F07-P038',13.89),
(39,7,39,'F07-P039',14.89),
(40,7,40,'F07-P040',2.55),
(41,7,41,'F07-P041',4.35),
(42,7,42,'F07-P042',7.25),
(43,8,43,'F08-P043',5.56),
(44,8,44,'F08-P044',6.57),
(45,8,45,'F08-P045',7.57),
(46,8,46,'F08-P046',8.57),
(47,8,47,'F08-P047',9.58),
(48,8,48,'F08-P048',10.58),
(49,9,49,'F09-P049',11.58),
(50,9,50,'F09-P050',12.59),
(51,9,51,'F09-P051',16.18),
(52,9,52,'F09-P052',14.59),
(53,9,53,'F09-P053',15.60),
(54,9,54,'F09-P054',3.26),
(55,10,55,'F10-P055',4.26),
(56,10,56,'F10-P056',5.27),
(57,10,57,'F10-P057',6.27),
(58,10,58,'F10-P058',7.27),
(59,10,59,'F10-P059',8.28),
(60,10,60,'F10-P060',9.28),
(61,11,1,'F11-P001',4.21),
(62,12,2,'F12-P002',5.19),
(63,11,3,'F11-P003',5.73),
(64,12,4,'F12-P004',6.78),
(65,11,5,'F11-P005',7.84),
(66,12,6,'F12-P006',8.89),
(67,11,7,'F11-P007',9.95),
(68,12,8,'F12-P008',11.00),
(69,11,9,'F11-P009',12.06),
(70,12,10,'F12-P010',13.12),
(71,11,11,'F11-P011',6.04),
(72,12,12,'F12-P012',15.23),
(73,11,13,'F11-P013',16.28),
(74,12,14,'F12-P014',3.31),
(75,11,15,'F11-P015',4.36),
(76,12,16,'F12-P016',5.42),
(77,11,17,'F11-P017',6.47),
(78,12,18,'F12-P018',7.53),
(79,11,19,'F11-P019',8.58),
(80,12,20,'F12-P020',9.64),
(81,11,21,'F11-P021',7.87),
(82,12,22,'F12-P022',11.53),
(83,11,23,'F11-P023',12.80),
(84,12,24,'F12-P024',13.86),
(85,11,25,'F11-P025',14.91),
(86,12,26,'F12-P026',15.97),
(87,11,27,'F11-P027',3.00),
(88,12,28,'F12-P028',4.05),
(89,11,29,'F11-P029',5.11),
(90,12,30,'F12-P030',6.16);

INSERT INTO FUNCIONARIO (id_funcionario,id_setor,nome,cpf,cargo,telefone,data_admissao,perfil_acesso,ativo) VALUES
(1,7,'Funcionario Ficticio 01','900.000.000-01','Operador de Caixa','11970000001','2023-02-02','operador',1),
(2,7,'Funcionario Ficticio 02','900.000.000-02','Operador de Caixa','11970000002','2024-03-03','operador',1),
(3,7,'Funcionario Ficticio 03','900.000.000-03','Operador de Caixa','11970000003','2025-04-04','operador',1),
(4,7,'Funcionario Ficticio 04','900.000.000-04','Operador de Caixa','11970000004','2022-05-05','operador',1),
(5,7,'Funcionario Ficticio 05','900.000.000-05','Operador de Caixa','11970000005','2023-06-06','operador',1),
(6,7,'Funcionario Ficticio 06','900.000.000-06','Operador de Caixa','11970000006','2024-07-07','operador',1),
(7,7,'Funcionario Ficticio 07','900.000.000-07','Operador de Caixa','11970000007','2025-08-08','operador',1),
(8,7,'Funcionario Ficticio 08','900.000.000-08','Operador de Caixa','11970000008','2022-09-09','operador',1),
(9,7,'Funcionario Ficticio 09','900.000.000-09','Supervisor de Caixa','11970000009','2023-10-10','supervisor',1),
(10,7,'Funcionario Ficticio 10','900.000.000-10','Supervisor de Caixa','11970000010','2024-11-11','supervisor',1),
(11,8,'Funcionario Ficticio 11','900.000.000-11','Assistente de Retaguarda','11970000011','2025-12-12','retaguarda',1),
(12,8,'Funcionario Ficticio 12','900.000.000-12','Assistente de Retaguarda','11970000012','2022-01-13','retaguarda',1),
(13,8,'Funcionario Ficticio 13','900.000.000-13','Assistente de Retaguarda','11970000013','2023-02-14','retaguarda',1),
(14,1,'Funcionario Ficticio 14','900.000.000-14','Repositor Hortifruti','11970000014','2024-03-15','repositor',1),
(15,4,'Funcionario Ficticio 15','900.000.000-15','Repositor Laticinios','11970000015','2025-04-16','repositor',1),
(16,8,'Funcionario Ficticio 16','900.000.000-16','Gerente','11970000016','2022-05-17','gerencia',1);

INSERT INTO ESCALA (id_escala,id_funcionario,data,tipo,hora_inicio,hora_fim) VALUES
(1,1,'2026-10-26','folga',NULL,NULL),
(2,2,'2026-10-26','trabalho','07:30:00','18:00:00'),
(3,3,'2026-10-26','trabalho','07:30:00','18:00:00'),
(4,4,'2026-10-26','trabalho','07:30:00','18:00:00'),
(5,5,'2026-10-26','trabalho','07:30:00','18:00:00'),
(6,6,'2026-10-26','trabalho','07:30:00','18:00:00'),
(7,7,'2026-10-26','trabalho','07:30:00','18:00:00'),
(8,8,'2026-10-26','trabalho','07:30:00','18:00:00'),
(9,9,'2026-10-26','trabalho','08:00:00','18:30:00'),
(10,10,'2026-10-26','trabalho','08:00:00','18:30:00'),
(11,11,'2026-10-26','trabalho','08:00:00','17:00:00'),
(12,12,'2026-10-26','trabalho','08:00:00','17:00:00'),
(13,13,'2026-10-26','trabalho','08:00:00','17:00:00'),
(14,14,'2026-10-26','trabalho','07:00:00','16:00:00'),
(15,15,'2026-10-26','trabalho','07:00:00','16:00:00'),
(16,16,'2026-10-26','trabalho','08:00:00','18:00:00'),
(17,1,'2026-10-27','trabalho','07:30:00','18:00:00'),
(18,2,'2026-10-27','folga',NULL,NULL),
(19,3,'2026-10-27','trabalho','07:30:00','18:00:00'),
(20,4,'2026-10-27','trabalho','07:30:00','18:00:00'),
(21,5,'2026-10-27','trabalho','07:30:00','18:00:00'),
(22,6,'2026-10-27','trabalho','07:30:00','18:00:00'),
(23,7,'2026-10-27','trabalho','07:30:00','18:00:00'),
(24,8,'2026-10-27','trabalho','07:30:00','18:00:00'),
(25,9,'2026-10-27','trabalho','08:00:00','18:30:00'),
(26,10,'2026-10-27','trabalho','08:00:00','18:30:00'),
(27,11,'2026-10-27','trabalho','08:00:00','17:00:00'),
(28,12,'2026-10-27','trabalho','08:00:00','17:00:00'),
(29,13,'2026-10-27','trabalho','08:00:00','17:00:00'),
(30,14,'2026-10-27','trabalho','07:00:00','16:00:00'),
(31,15,'2026-10-27','trabalho','07:00:00','16:00:00'),
(32,16,'2026-10-27','trabalho','08:00:00','18:00:00'),
(33,1,'2026-10-28','trabalho','07:30:00','18:00:00'),
(34,2,'2026-10-28','trabalho','07:30:00','18:00:00'),
(35,3,'2026-10-28','folga',NULL,NULL),
(36,4,'2026-10-28','trabalho','07:30:00','18:00:00'),
(37,5,'2026-10-28','trabalho','07:30:00','18:00:00'),
(38,6,'2026-10-28','trabalho','07:30:00','18:00:00'),
(39,7,'2026-10-28','trabalho','07:30:00','18:00:00'),
(40,8,'2026-10-28','trabalho','07:30:00','18:00:00'),
(41,9,'2026-10-28','trabalho','08:00:00','18:30:00'),
(42,10,'2026-10-28','trabalho','08:00:00','18:30:00'),
(43,11,'2026-10-28','trabalho','08:00:00','17:00:00'),
(44,12,'2026-10-28','trabalho','08:00:00','17:00:00'),
(45,13,'2026-10-28','trabalho','08:00:00','17:00:00'),
(46,14,'2026-10-28','trabalho','07:00:00','16:00:00'),
(47,15,'2026-10-28','trabalho','07:00:00','16:00:00'),
(48,16,'2026-10-28','trabalho','08:00:00','18:00:00'),
(49,1,'2026-10-29','trabalho','07:30:00','18:00:00'),
(50,2,'2026-10-29','trabalho','07:30:00','18:00:00'),
(51,3,'2026-10-29','trabalho','07:30:00','18:00:00'),
(52,4,'2026-10-29','folga',NULL,NULL),
(53,5,'2026-10-29','trabalho','07:30:00','18:00:00'),
(54,6,'2026-10-29','trabalho','07:30:00','18:00:00'),
(55,7,'2026-10-29','trabalho','07:30:00','18:00:00'),
(56,8,'2026-10-29','trabalho','07:30:00','18:00:00'),
(57,9,'2026-10-29','trabalho','08:00:00','18:30:00'),
(58,10,'2026-10-29','trabalho','08:00:00','18:30:00'),
(59,11,'2026-10-29','trabalho','08:00:00','17:00:00'),
(60,12,'2026-10-29','trabalho','08:00:00','17:00:00'),
(61,13,'2026-10-29','trabalho','08:00:00','17:00:00'),
(62,14,'2026-10-29','trabalho','07:00:00','16:00:00'),
(63,15,'2026-10-29','trabalho','07:00:00','16:00:00'),
(64,16,'2026-10-29','trabalho','08:00:00','18:00:00'),
(65,1,'2026-10-30','trabalho','07:30:00','18:00:00'),
(66,2,'2026-10-30','trabalho','07:30:00','18:00:00'),
(67,3,'2026-10-30','trabalho','07:30:00','18:00:00'),
(68,4,'2026-10-30','trabalho','07:30:00','18:00:00'),
(69,5,'2026-10-30','folga',NULL,NULL),
(70,6,'2026-10-30','trabalho','07:30:00','18:00:00'),
(71,7,'2026-10-30','trabalho','07:30:00','18:00:00'),
(72,8,'2026-10-30','trabalho','07:30:00','18:00:00'),
(73,9,'2026-10-30','trabalho','08:00:00','18:30:00'),
(74,10,'2026-10-30','trabalho','08:00:00','18:30:00'),
(75,11,'2026-10-30','trabalho','08:00:00','17:00:00'),
(76,12,'2026-10-30','trabalho','08:00:00','17:00:00'),
(77,13,'2026-10-30','trabalho','08:00:00','17:00:00'),
(78,14,'2026-10-30','trabalho','07:00:00','16:00:00'),
(79,15,'2026-10-30','trabalho','07:00:00','16:00:00'),
(80,16,'2026-10-30','trabalho','08:00:00','18:00:00'),
(81,1,'2026-10-31','trabalho','07:30:00','18:00:00'),
(82,2,'2026-10-31','trabalho','07:30:00','18:00:00'),
(83,3,'2026-10-31','trabalho','07:30:00','18:00:00'),
(84,4,'2026-10-31','trabalho','07:30:00','18:00:00'),
(85,5,'2026-10-31','trabalho','07:30:00','18:00:00'),
(86,6,'2026-10-31','folga',NULL,NULL),
(87,7,'2026-10-31','trabalho','07:30:00','18:00:00'),
(88,8,'2026-10-31','trabalho','07:30:00','18:00:00'),
(89,9,'2026-10-31','trabalho','08:00:00','18:30:00'),
(90,10,'2026-10-31','trabalho','08:00:00','18:30:00'),
(91,11,'2026-10-31','trabalho','08:00:00','17:00:00'),
(92,12,'2026-10-31','trabalho','08:00:00','17:00:00'),
(93,13,'2026-10-31','trabalho','08:00:00','17:00:00'),
(94,14,'2026-10-31','trabalho','07:00:00','16:00:00'),
(95,15,'2026-10-31','trabalho','07:00:00','16:00:00'),
(96,16,'2026-10-31','trabalho','08:00:00','18:00:00'),
(97,1,'2026-11-01','trabalho','07:30:00','18:00:00'),
(98,2,'2026-11-01','trabalho','07:30:00','18:00:00'),
(99,3,'2026-11-01','trabalho','07:30:00','18:00:00'),
(100,4,'2026-11-01','trabalho','07:30:00','18:00:00'),
(101,5,'2026-11-01','trabalho','07:30:00','18:00:00'),
(102,6,'2026-11-01','trabalho','07:30:00','18:00:00'),
(103,7,'2026-11-01','folga',NULL,NULL),
(104,8,'2026-11-01','trabalho','07:30:00','18:00:00'),
(105,9,'2026-11-01','trabalho','08:00:00','18:30:00'),
(106,10,'2026-11-01','trabalho','08:00:00','18:30:00'),
(107,11,'2026-11-01','trabalho','08:00:00','17:00:00'),
(108,12,'2026-11-01','trabalho','08:00:00','17:00:00'),
(109,13,'2026-11-01','trabalho','08:00:00','17:00:00'),
(110,14,'2026-11-01','trabalho','07:00:00','16:00:00'),
(111,15,'2026-11-01','trabalho','07:00:00','16:00:00'),
(112,16,'2026-11-01','trabalho','08:00:00','18:00:00');

INSERT INTO FORMA_PAGAMENTO (id_forma,descricao,uso,ativo) VALUES
(1,'Dinheiro','venda',1),
(2,'Debito','venda',1),
(3,'Credito','venda',1),
(4,'Pix','ambos',1),
(5,'Vale-alimentacao','venda',1),
(6,'Boleto','fornecedor',1),
(7,'Transferencia','fornecedor',1);

INSERT INTO CAIXA (id_caixa,numero,ativo) VALUES
(1,1,1),
(2,2,1),
(3,3,1),
(4,4,1),
(5,5,1),
(6,6,1),
(7,7,1);

-- 5.2 Compras, recebimentos, financeiro e estoque

INSERT INTO PEDIDO_COMPRA (id_pedido,id_fornecedor,id_funcionario,data_pedido,status) VALUES
(1,1,11,'2026-10-02','recebido'),
(2,2,12,'2026-10-03','recebido'),
(3,3,13,'2026-10-04','recebido'),
(4,4,11,'2026-10-05','recebido'),
(5,5,12,'2026-10-06','recebido'),
(6,6,13,'2026-10-07','recebido'),
(7,7,11,'2026-10-08','recebido'),
(8,8,12,'2026-10-09','recebido'),
(9,9,13,'2026-10-10','recebido'),
(10,10,11,'2026-10-11','recebido'),
(11,10,12,'2026-10-30','aberto'),
(12,1,13,'2026-10-24','cancelado');

INSERT INTO ITEM_PEDIDO_COMPRA (id_item_pedido,id_pedido,id_produto,quantidade,custo_previsto) VALUES
(1,1,1,55.000,4.00),
(2,1,2,55.000,4.93),
(3,1,3,55.000,5.45),
(4,1,4,55.000,6.45),
(5,1,5,55.000,7.45),
(6,1,6,55.000,8.46),
(7,2,7,55.000,9.46),
(8,2,8,55.000,10.46),
(9,2,9,55.000,11.47),
(10,2,10,55.000,12.47),
(11,2,11,55.000,5.74),
(12,2,12,55.000,14.48),
(13,3,13,55.000,15.48),
(14,3,14,55.000,3.14),
(15,3,15,55.000,4.15),
(16,3,16,55.000,5.15),
(17,3,17,55.000,6.15),
(18,3,18,55.000,7.16),
(19,4,19,55.000,8.16),
(20,4,20,55.000,9.16),
(21,4,21,55.000,7.48),
(22,4,22,55.000,10.96),
(23,4,23,55.000,12.17),
(24,4,24,55.000,13.18),
(25,5,25,55.000,14.18),
(26,5,26,55.000,15.18),
(27,5,27,55.000,2.85),
(28,5,28,55.000,3.85),
(29,5,29,55.000,4.85),
(30,5,30,55.000,5.86),
(31,6,31,55.000,3.77),
(32,6,32,55.000,2.78),
(33,6,33,55.000,8.87),
(34,6,34,55.000,9.87),
(35,6,35,55.000,10.88),
(36,6,36,55.000,11.88),
(37,7,37,55.000,12.88),
(38,7,38,55.000,13.89),
(39,7,39,55.000,14.89),
(40,7,40,55.000,2.55),
(41,7,41,55.000,4.35),
(42,7,42,55.000,7.25),
(43,8,43,55.000,5.56),
(44,8,44,55.000,6.57),
(45,8,45,55.000,7.57),
(46,8,46,55.000,8.57),
(47,8,47,55.000,9.58),
(48,8,48,55.000,10.58),
(49,9,49,55.000,11.58),
(50,9,50,55.000,12.59),
(51,9,51,55.000,16.18),
(52,9,52,55.000,14.59),
(53,9,53,55.000,15.60),
(54,9,54,55.000,3.26),
(55,10,55,15.000,4.26),
(56,10,56,15.000,5.27),
(57,10,57,15.000,6.27),
(58,10,58,15.000,7.27),
(59,10,59,15.000,8.28),
(60,10,60,15.000,9.28),
(61,11,55,40.000,4.26),
(62,11,56,40.000,5.27),
(63,11,57,40.000,6.27),
(64,11,58,40.000,7.27),
(65,11,59,40.000,8.28),
(66,11,60,40.000,9.28),
(67,12,1,20.000,4.00),
(68,12,2,20.000,4.93),
(69,12,11,20.000,5.74),
(70,12,12,20.000,14.48);

INSERT INTO RECEBIMENTO (id_recebimento,id_fornecedor,id_pedido,id_funcionario,numero_nf,serie,chave_acesso,data_emissao,data_recebimento,valor_total) VALUES
(1,1,1,11,'NF00001','1','80000000000000000000000000000000000000000001','2026-10-15','2026-10-15 09:00:00',1849.93),
(2,2,2,12,'NF00002','1','80000000000000000000000000000000000000000002','2026-10-16','2026-10-16 09:00:00',3233.38),
(3,3,3,13,'NF00003','1','80000000000000000000000000000000000000000003','2026-10-17','2026-10-17 09:00:00',2092.46),
(4,4,4,11,'NF00004','1','80000000000000000000000000000000000000000004','2026-10-18','2026-10-18 09:00:00',3071.82),
(5,5,5,12,'NF00005','1','80000000000000000000000000000000000000000005','2026-10-19','2026-10-19 09:00:00',2366.86),
(6,6,6,13,'NF00006','1','80000000000000000000000000000000000000000006','2026-10-20','2026-10-20 09:00:00',2410.04),
(7,7,7,11,'NF00007','1','80000000000000000000000000000000000000000007','2026-10-21','2026-10-21 09:00:00',2790.50),
(8,8,8,12,'NF00008','1','80000000000000000000000000000000000000000008','2026-10-22','2026-10-22 09:00:00',2421.50),
(9,9,9,13,'NF00009','1','80000000000000000000000000000000000000000009','2026-10-23','2026-10-23 09:00:00',3690.00),
(10,10,10,11,'NF00010','1','80000000000000000000000000000000000000000010','2026-10-24','2026-10-24 09:00:00',406.30),
(11,11,NULL,12,'NF00011','1','80000000000000000000000000000000000000000011','2026-10-24','2026-10-24 10:00:00',90.60),
(12,12,NULL,13,'NF00012','1','80000000000000000000000000000000000000000012','2026-10-25','2026-10-25 10:00:00',127.85);

INSERT INTO ITEM_RECEBIMENTO (id_item_recebimento,id_recebimento,id_produto,quantidade_nf,quantidade_aceita,quantidade_recusada,custo_unitario_nf,observacao_divergencia) VALUES
(1,1,1,52.000,50.000,2.000,4.00,'Divergencia ficticia na conferencia'),
(2,1,2,51.000,50.000,1.000,4.93,'Divergencia ficticia na conferencia'),
(3,1,3,50.000,50.000,0.000,5.45,NULL),
(4,1,4,50.000,50.000,0.000,6.45,NULL),
(5,1,5,50.000,50.000,0.000,7.45,NULL),
(6,1,6,50.000,50.000,0.000,8.46,NULL),
(7,2,7,52.000,50.000,2.000,9.46,'Divergencia ficticia na conferencia'),
(8,2,8,51.000,50.000,1.000,10.46,'Divergencia ficticia na conferencia'),
(9,2,9,50.000,50.000,0.000,11.47,NULL),
(10,2,10,50.000,50.000,0.000,12.47,NULL),
(11,2,11,50.000,50.000,0.000,5.74,NULL),
(12,2,12,50.000,50.000,0.000,14.48,NULL),
(13,3,13,52.000,50.000,2.000,15.48,'Divergencia ficticia na conferencia'),
(14,3,14,50.000,50.000,0.000,3.14,NULL),
(15,3,15,50.000,50.000,0.000,4.15,NULL),
(16,3,16,50.000,50.000,0.000,5.15,NULL),
(17,3,17,50.000,50.000,0.000,6.15,NULL),
(18,3,18,50.000,50.000,0.000,7.16,NULL),
(19,4,19,52.000,50.000,2.000,8.16,'Divergencia ficticia na conferencia'),
(20,4,20,50.000,50.000,0.000,9.16,NULL),
(21,4,21,50.000,50.000,0.000,7.48,NULL),
(22,4,22,50.000,50.000,0.000,10.96,NULL),
(23,4,23,50.000,50.000,0.000,12.17,NULL),
(24,4,24,50.000,50.000,0.000,13.18,NULL),
(25,5,25,52.000,50.000,2.000,14.18,'Divergencia ficticia na conferencia'),
(26,5,26,50.000,50.000,0.000,15.18,NULL),
(27,5,27,50.000,50.000,0.000,2.85,NULL),
(28,5,28,50.000,50.000,0.000,3.85,NULL),
(29,5,29,50.000,50.000,0.000,4.85,NULL),
(30,5,30,50.000,50.000,0.000,5.86,NULL),
(31,6,31,52.000,50.000,2.000,3.77,'Divergencia ficticia na conferencia'),
(32,6,32,50.000,50.000,0.000,2.78,NULL),
(33,6,33,50.000,50.000,0.000,8.87,NULL),
(34,6,34,50.000,50.000,0.000,9.87,NULL),
(35,6,35,50.000,50.000,0.000,10.88,NULL),
(36,6,36,50.000,50.000,0.000,11.88,NULL),
(37,7,37,50.000,50.000,0.000,12.88,NULL),
(38,7,38,50.000,50.000,0.000,13.89,NULL),
(39,7,39,50.000,50.000,0.000,14.89,NULL),
(40,7,40,50.000,50.000,0.000,2.55,NULL),
(41,7,41,50.000,50.000,0.000,4.35,NULL),
(42,7,42,50.000,50.000,0.000,7.25,NULL),
(43,8,43,50.000,50.000,0.000,5.56,NULL),
(44,8,44,50.000,50.000,0.000,6.57,NULL),
(45,8,45,50.000,50.000,0.000,7.57,NULL),
(46,8,46,50.000,50.000,0.000,8.57,NULL),
(47,8,47,50.000,50.000,0.000,9.58,NULL),
(48,8,48,50.000,50.000,0.000,10.58,NULL),
(49,9,49,50.000,50.000,0.000,11.58,NULL),
(50,9,50,50.000,50.000,0.000,12.59,NULL),
(51,9,51,50.000,50.000,0.000,16.18,NULL),
(52,9,52,50.000,50.000,0.000,14.59,NULL),
(53,9,53,50.000,50.000,0.000,15.60,NULL),
(54,9,54,50.000,50.000,0.000,3.26,NULL),
(55,10,55,10.000,10.000,0.000,4.26,NULL),
(56,10,56,10.000,10.000,0.000,5.27,NULL),
(57,10,57,10.000,10.000,0.000,6.27,NULL),
(58,10,58,10.000,10.000,0.000,7.27,NULL),
(59,10,59,10.000,10.000,0.000,8.28,NULL),
(60,10,60,10.000,10.000,0.000,9.28,NULL),
(61,11,1,5.000,5.000,0.000,4.21,NULL),
(62,11,11,5.000,5.000,0.000,6.04,NULL),
(63,11,21,5.000,5.000,0.000,7.87,NULL),
(64,12,31,5.000,5.000,0.000,3.97,NULL),
(65,12,41,5.000,5.000,0.000,4.58,NULL),
(66,12,51,5.000,5.000,0.000,17.02,NULL);

INSERT INTO CONTA_PAGAR (id_conta,id_recebimento,id_forma,id_funcionario_pagamento,data_vencimento,valor,data_pagamento,status) VALUES
(1,1,6,11,'2026-10-28',1849.93,'2026-10-28 15:00:00','paga'),
(2,2,NULL,NULL,'2026-10-28',3233.38,NULL,'aberta'),
(3,3,4,13,'2026-10-30',2092.46,'2026-10-30 15:00:00','paga'),
(4,4,NULL,NULL,'2026-10-30',3071.82,NULL,'aberta'),
(5,5,NULL,NULL,'2026-11-05',2366.86,NULL,'aberta'),
(6,6,NULL,NULL,'2026-11-06',2410.04,NULL,'cancelada'),
(7,7,6,11,'2026-10-31',2790.50,'2026-10-30 15:00:00','paga'),
(8,8,NULL,NULL,'2026-11-10',2421.50,NULL,'aberta'),
(9,9,4,13,'2026-11-01',3690.00,'2026-10-28 15:00:00','paga'),
(10,10,NULL,NULL,'2026-11-12',406.30,NULL,'aberta'),
(11,11,7,12,'2026-11-08',90.60,'2026-10-30 15:00:00','paga'),
(12,12,NULL,NULL,'2026-11-15',127.85,NULL,'aberta');

INSERT INTO DEVOLUCAO_FORNECEDOR (id_devolucao,id_recebimento,id_funcionario,id_conta,data,tipo,motivo,valor_abatimento,status) VALUES
(1,1,11,NULL,'2026-10-16','troca','Mercadoria fora do padrao',NULL,'concluida'),
(2,2,12,2,'2026-10-17','abatimento','Mercadoria danificada na conferencia',15.00,'concluida'),
(3,3,13,NULL,'2026-10-18','devolucao','Mercadoria recusada',NULL,'concluida'),
(4,4,11,NULL,'2026-10-19','troca','Mercadoria fora do padrao',NULL,'aberta'),
(5,5,12,5,'2026-10-20','abatimento','Compensacao na proxima nota',10.00,'concluida'),
(6,6,13,NULL,'2026-10-21','devolucao','Mercadoria recusada',NULL,'concluida');

INSERT INTO ITEM_DEVOLUCAO (id_item_devolucao,id_devolucao,id_item_recebimento,quantidade,observacao) VALUES
(1,1,1,2.000,'Quantidade dentro do total recusado'),
(2,2,7,2.000,'Quantidade dentro do total recusado'),
(3,3,13,2.000,'Quantidade dentro do total recusado'),
(4,4,19,2.000,'Quantidade dentro do total recusado'),
(5,5,25,2.000,'Quantidade dentro do total recusado'),
(6,6,31,2.000,'Quantidade dentro do total recusado');

INSERT INTO LOTE (id_lote,id_item_recebimento,id_produto,codigo_lote,data_fabricacao,data_validade,quantidade_recebida,quantidade_atual,custo_unitario) VALUES
(1,1,1,'L001-A',NULL,NULL,40.000,40.000,4.00),
(2,1,1,'L001-B',NULL,NULL,10.000,10.000,4.00),
(3,2,2,'L002-A',NULL,NULL,40.000,40.000,4.93),
(4,2,2,'L002-B',NULL,NULL,10.000,10.000,4.93),
(5,3,3,'L003-A',NULL,NULL,40.000,40.000,5.45),
(6,3,3,'L003-B',NULL,NULL,10.000,10.000,5.45),
(7,4,4,'L004-A',NULL,NULL,40.000,40.000,6.45),
(8,4,4,'L004-B',NULL,NULL,10.000,10.000,6.45),
(9,5,5,'L005-A',NULL,NULL,40.000,40.000,7.45),
(10,5,5,'L005-B',NULL,NULL,10.000,10.000,7.45),
(11,6,6,'L006-A',NULL,NULL,40.000,40.000,8.46),
(12,6,6,'L006-B',NULL,NULL,10.000,10.000,8.46),
(13,7,7,'L007-A',NULL,NULL,40.000,40.000,9.46),
(14,7,7,'L007-B',NULL,NULL,10.000,10.000,9.46),
(15,8,8,'L008-A',NULL,NULL,40.000,40.000,10.46),
(16,8,8,'L008-B',NULL,NULL,10.000,10.000,10.46),
(17,9,9,'L009-A',NULL,NULL,40.000,40.000,11.47),
(18,9,9,'L009-B',NULL,NULL,10.000,10.000,11.47),
(19,10,10,'L010-A',NULL,NULL,40.000,40.000,12.47),
(20,10,10,'L010-B',NULL,NULL,10.000,10.000,12.47),
(21,11,11,'L011-A','2026-09-01','2027-06-30',40.000,40.000,5.74),
(22,11,11,'L011-B','2026-09-15','2026-11-03',10.000,10.000,5.74),
(23,12,12,'L012-A','2026-09-01','2027-06-30',40.000,40.000,14.48),
(24,12,12,'L012-B','2026-09-15','2026-11-02',10.000,10.000,14.48),
(25,13,13,'L013-A','2026-09-01','2027-06-30',40.000,40.000,15.48),
(26,13,13,'L013-B','2026-09-15','2027-03-01',10.000,10.000,15.48),
(27,14,14,'L014-A','2026-09-01','2027-06-30',40.000,40.000,3.14),
(28,14,14,'L014-B','2026-09-15','2027-03-01',10.000,10.000,3.14),
(29,15,15,'L015-A','2026-09-01','2027-06-30',40.000,40.000,4.15),
(30,15,15,'L015-B','2026-09-15','2027-03-01',10.000,10.000,4.15),
(31,16,16,'L016-A','2026-09-01','2027-06-30',40.000,40.000,5.15),
(32,16,16,'L016-B','2026-09-15','2027-03-01',10.000,10.000,5.15),
(33,17,17,'L017-A','2026-09-01','2027-06-30',40.000,40.000,6.15),
(34,17,17,'L017-B','2026-09-15','2027-03-01',10.000,10.000,6.15),
(35,18,18,'L018-A','2026-09-01','2027-06-30',40.000,40.000,7.16),
(36,18,18,'L018-B','2026-09-15','2027-03-01',10.000,10.000,7.16),
(37,19,19,'L019-A','2026-09-01','2027-06-30',40.000,40.000,8.16),
(38,19,19,'L019-B','2026-09-15','2027-03-01',10.000,10.000,8.16),
(39,20,20,'L020-A','2026-09-01','2027-06-30',40.000,40.000,9.16),
(40,20,20,'L020-B','2026-09-15','2027-03-01',10.000,10.000,9.16),
(41,21,21,'L021-A','2026-09-01','2027-06-30',40.000,40.000,7.48),
(42,21,21,'L021-B','2026-09-15','2026-11-04',10.000,10.000,7.48),
(43,22,22,'L022-A','2026-09-01','2027-06-30',40.000,40.000,10.96),
(44,22,22,'L022-B','2026-09-15','2026-10-31',10.000,10.000,10.96),
(45,23,23,'L023-A','2026-09-01','2027-06-30',40.000,40.000,12.17),
(46,23,23,'L023-B','2026-09-15','2027-03-01',10.000,10.000,12.17),
(47,24,24,'L024-A','2026-09-01','2027-06-30',40.000,40.000,13.18),
(48,24,24,'L024-B','2026-09-15','2027-03-01',10.000,10.000,13.18),
(49,25,25,'L025-A','2026-09-01','2027-06-30',40.000,40.000,14.18),
(50,25,25,'L025-B','2026-09-15','2027-03-01',10.000,10.000,14.18),
(51,26,26,'L026-A','2026-09-01','2027-06-30',40.000,40.000,15.18),
(52,26,26,'L026-B','2026-09-15','2027-03-01',10.000,10.000,15.18),
(53,27,27,'L027-A','2026-09-01','2027-06-30',40.000,40.000,2.85),
(54,27,27,'L027-B','2026-09-15','2027-03-01',10.000,10.000,2.85),
(55,28,28,'L028-A','2026-09-01','2027-06-30',40.000,40.000,3.85),
(56,28,28,'L028-B','2026-09-15','2027-03-01',10.000,10.000,3.85),
(57,29,29,'L029-A','2026-09-01','2027-06-30',40.000,40.000,4.85),
(58,29,29,'L029-B','2026-09-15','2027-03-01',10.000,10.000,4.85),
(59,30,30,'L030-A','2026-09-01','2027-06-30',40.000,40.000,5.86),
(60,30,30,'L030-B','2026-09-15','2027-03-01',10.000,10.000,5.86),
(61,31,31,'L031-A','2026-09-01','2027-06-30',40.000,40.000,3.77),
(62,31,31,'L031-B','2026-09-15','2026-11-06',10.000,10.000,3.77),
(63,32,32,'L032-A','2026-09-01','2027-06-30',40.000,40.000,2.78),
(64,32,32,'L032-B','2026-09-15','2026-11-05',10.000,10.000,2.78),
(65,33,33,'L033-A','2026-09-01','2027-06-30',40.000,40.000,8.87),
(66,33,33,'L033-B','2026-09-15','2027-03-01',10.000,10.000,8.87),
(67,34,34,'L034-A','2026-09-01','2027-06-30',40.000,40.000,9.87),
(68,34,34,'L034-B','2026-09-15','2027-03-01',10.000,10.000,9.87),
(69,35,35,'L035-A','2026-09-01','2027-06-30',40.000,40.000,10.88),
(70,35,35,'L035-B','2026-09-15','2027-03-01',10.000,10.000,10.88),
(71,36,36,'L036-A','2026-09-01','2027-06-30',40.000,40.000,11.88),
(72,36,36,'L036-B','2026-09-15','2027-03-01',10.000,10.000,11.88),
(73,37,37,'L037-A','2026-09-01','2027-06-30',40.000,40.000,12.88),
(74,37,37,'L037-B','2026-09-15','2027-03-01',10.000,10.000,12.88),
(75,38,38,'L038-A','2026-09-01','2027-06-30',40.000,40.000,13.89),
(76,38,38,'L038-B','2026-09-15','2027-03-01',10.000,10.000,13.89),
(77,39,39,'L039-A','2026-09-01','2027-06-30',40.000,40.000,14.89),
(78,39,39,'L039-B','2026-09-15','2027-03-01',10.000,10.000,14.89),
(79,40,40,'L040-A','2026-09-01','2027-06-30',40.000,40.000,2.55),
(80,40,40,'L040-B','2026-09-15','2027-03-01',10.000,10.000,2.55),
(81,41,41,'L041-A','2026-09-01','2027-06-30',40.000,40.000,4.35),
(82,41,41,'L041-B','2026-09-15','2026-10-25',10.000,10.000,4.35),
(83,42,42,'L042-A','2026-09-01','2027-06-30',40.000,40.000,7.25),
(84,42,42,'L042-B','2026-09-15','2026-11-09',10.000,10.000,7.25),
(85,43,43,'L043-A','2026-09-01','2027-06-30',40.000,40.000,5.56),
(86,43,43,'L043-B','2026-09-15','2027-03-01',10.000,10.000,5.56),
(87,44,44,'L044-A','2026-09-01','2027-06-30',40.000,40.000,6.57),
(88,44,44,'L044-B','2026-09-15','2027-03-01',10.000,10.000,6.57),
(89,45,45,'L045-A','2026-09-01','2027-06-30',40.000,40.000,7.57),
(90,45,45,'L045-B','2026-09-15','2027-03-01',10.000,10.000,7.57),
(91,46,46,'L046-A','2026-09-01','2027-06-30',40.000,40.000,8.57),
(92,46,46,'L046-B','2026-09-15','2027-03-01',10.000,10.000,8.57),
(93,47,47,'L047-A','2026-09-01','2027-06-30',40.000,40.000,9.58),
(94,47,47,'L047-B','2026-09-15','2027-03-01',10.000,10.000,9.58),
(95,48,48,'L048-A','2026-09-01','2027-06-30',40.000,40.000,10.58),
(96,48,48,'L048-B','2026-09-15','2027-03-01',10.000,10.000,10.58),
(97,49,49,'L049-A','2026-09-01','2027-06-30',40.000,40.000,11.58),
(98,49,49,'L049-B','2026-09-15','2027-03-01',10.000,10.000,11.58),
(99,50,50,'L050-A','2026-09-01','2027-06-30',40.000,40.000,12.59),
(100,50,50,'L050-B','2026-09-15','2027-03-01',10.000,10.000,12.59),
(101,51,51,'L051-A','2026-09-01','2027-06-30',40.000,40.000,16.18),
(102,51,51,'L051-B','2026-09-15','2026-11-10',10.000,10.000,16.18),
(103,52,52,'L052-A','2026-09-01','2027-06-30',40.000,40.000,14.59),
(104,52,52,'L052-B','2026-09-15','2027-03-01',10.000,10.000,14.59),
(105,53,53,'L053-A','2026-09-01','2027-06-30',40.000,40.000,15.60),
(106,53,53,'L053-B','2026-09-15','2027-03-01',10.000,10.000,15.60),
(107,54,54,'L054-A','2026-09-01','2027-06-30',40.000,40.000,3.26),
(108,54,54,'L054-B','2026-09-15','2027-03-01',10.000,10.000,3.26),
(109,55,55,'L055-A','2026-09-01','2027-06-30',7.000,7.000,4.26),
(110,55,55,'L055-B','2026-09-15','2027-03-01',3.000,3.000,4.26),
(111,56,56,'L056-A','2026-09-01','2027-06-30',7.000,7.000,5.27),
(112,56,56,'L056-B','2026-09-15','2027-03-01',3.000,3.000,5.27),
(113,57,57,'L057-A','2026-09-01','2027-06-30',7.000,7.000,6.27),
(114,57,57,'L057-B','2026-09-15','2027-03-01',3.000,3.000,6.27),
(115,58,58,'L058-A','2026-09-01','2027-06-30',7.000,7.000,7.27),
(116,58,58,'L058-B','2026-09-15','2027-03-01',3.000,3.000,7.27),
(117,59,59,'L059-A','2026-09-01','2027-06-30',7.000,7.000,8.28),
(118,59,59,'L059-B','2026-09-15','2027-03-01',3.000,3.000,8.28),
(119,60,60,'L060-A','2026-09-01','2027-06-30',7.000,7.000,9.28),
(120,60,60,'L060-B','2026-09-15','2027-03-01',3.000,3.000,9.28),
(121,61,1,'LX001',NULL,NULL,5.000,5.000,4.21),
(122,62,11,'LX011','2026-10-20','2027-07-31',5.000,5.000,6.04),
(123,63,21,'LX021','2026-10-20','2027-07-31',5.000,5.000,7.87),
(124,64,31,'LX031','2026-10-20','2027-07-31',5.000,5.000,3.97),
(125,65,41,'LX041','2026-10-20','2027-07-31',5.000,5.000,4.58),
(126,66,51,'LX051','2026-10-20','2027-07-31',5.000,5.000,17.02);

INSERT INTO MOTIVO_PERDA (id_motivo,descricao,ativo) VALUES
(1,'Vencimento',1),
(2,'Maturacao excessiva',1),
(3,'Dano causado por cliente',1),
(4,'Quebra de embalagem',1),
(5,'Problema de armazenamento',1),
(6,'Qualidade inadequada',1),
(7,'Avaria no manuseio',1),
(8,'Outros',1);

INSERT INTO PROMOCAO (id_promocao,id_lote,id_funcionario,data_inicio,data_fim,preco_normal,preco_promocional) VALUES
(1,22,16,'2026-10-30','2026-11-03',9.90,7.92),
(2,64,16,'2026-10-30','2026-11-05',4.80,3.84),
(3,44,16,'2026-10-27','2026-10-31',18.90,15.12),
(4,84,16,'2026-10-28','2026-11-09',12.50,10.00),
(5,24,16,'2026-10-30','2026-11-02',24.96,19.97);

-- 5.3 Vendas e caixas: 200 vendas distribuidas em 7 dias ficticios
-- Distribuicao: 25, 27, 28, 30, 32, 33 e 25 vendas.

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(1,1,2,'2026-10-26 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(1,1,2,NULL,'2026-10-26 10:08:00',53.65,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(1,1,8,NULL,0.750,18.04,'ativo',NULL,NULL),
(2,1,19,NULL,1.000,14.07,'ativo',NULL,NULL),
(3,1,31,NULL,2.000,6.50,'ativo',NULL,NULL),
(4,1,45,NULL,1.000,13.05,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(15,1,NULL,NULL,0.750,'2026-10-26 10:08:00','venda'),
(37,2,NULL,NULL,1.000,'2026-10-26 10:08:00','venda'),
(61,3,NULL,NULL,2.000,'2026-10-26 10:08:00','venda'),
(89,4,NULL,NULL,1.000,'2026-10-26 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(1,1,2,53.65);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(1,1,'NFCe','000001','1','90000000000000000000000000000000000000000001','2026-10-26 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(2,1,2,NULL,'2026-10-26 11:56:00',137.23,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(5,2,15,NULL,1.000,7.15,'ativo',NULL,NULL),
(6,2,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(7,2,38,NULL,1.000,23.94,'ativo',NULL,NULL),
(8,2,53,NULL,2.000,26.89,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(29,5,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(51,6,NULL,NULL,2.000,'2026-10-26 11:56:00','venda'),
(75,7,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(105,8,NULL,NULL,2.000,'2026-10-26 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(2,2,3,137.23);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(2,2,'NFCe','000002','1','90000000000000000000000000000000000000000002','2026-10-26 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(3,1,2,NULL,'2026-10-26 13:43:59',93.77,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(9,3,22,NULL,2.000,18.90,'ativo',NULL,NULL),
(10,3,33,NULL,1.000,15.29,'ativo',NULL,NULL),
(11,3,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(12,3,6,NULL,1.000,14.58,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(43,9,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(65,10,NULL,NULL,1.000,'2026-10-26 13:43:59','venda'),
(89,11,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(11,12,NULL,NULL,1.000,'2026-10-26 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(3,3,4,93.77);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(3,3,'NFCe','000003','1','90000000000000000000000000000000000000000003','2026-10-26 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(4,1,2,NULL,'2026-10-26 15:32:00',97.44,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(13,4,29,NULL,1.000,8.37,'ativo',NULL,NULL),
(14,4,40,NULL,2.000,4.40,'ativo',NULL,NULL),
(15,4,53,NULL,1.000,26.89,'ativo',NULL,NULL),
(16,4,13,NULL,2.000,26.69,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(57,13,NULL,NULL,1.000,'2026-10-26 15:32:00','venda'),
(79,14,NULL,NULL,2.000,'2026-10-26 15:32:00','venda'),
(105,15,NULL,NULL,1.000,'2026-10-26 15:32:00','venda'),
(25,16,NULL,NULL,2.000,'2026-10-26 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(4,4,5,97.44);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(4,4,'NFCe','000004','1','90000000000000000000000000000000000000000004','2026-10-26 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 557.09 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=1 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(1,9,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(2,2,3,'2026-10-26 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(5,2,3,NULL,'2026-10-26 10:08:00',91.50,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(17,5,36,NULL,2.000,20.48,'ativo',NULL,NULL),
(18,5,47,NULL,1.000,16.51,'ativo',NULL,NULL),
(19,5,6,NULL,1.250,14.58,'ativo',NULL,NULL),
(20,5,20,NULL,1.000,15.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(71,17,NULL,NULL,2.000,'2026-10-26 10:08:00','venda'),
(93,18,NULL,NULL,1.000,'2026-10-26 10:08:00','venda'),
(11,19,NULL,NULL,1.250,'2026-10-26 10:08:00','venda'),
(39,20,NULL,NULL,1.000,'2026-10-26 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(5,5,1,91.50);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(5,5,'NFCe','000005','1','90000000000000000000000000000000000000000005','2026-10-26 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(6,2,3,NULL,'2026-10-26 11:56:00',54.73,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(21,6,43,NULL,1.000,9.59,'ativo',NULL,NULL),
(22,6,1,NULL,1.250,6.90,'ativo',NULL,NULL),
(23,6,13,NULL,1.000,26.69,'ativo',NULL,NULL),
(24,6,27,NULL,2.000,4.91,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(85,21,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(1,22,NULL,NULL,1.250,'2026-10-26 11:56:00','venda'),
(25,23,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(53,24,NULL,NULL,2.000,'2026-10-26 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(6,6,2,54.73);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(6,6,'NFCe','000006','1','90000000000000000000000000000000000000000006','2026-10-26 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(7,2,3,NULL,'2026-10-26 13:43:59',113.44,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(25,7,51,NULL,2.000,27.90,'ativo',NULL,NULL),
(26,7,8,NULL,0.500,18.04,'ativo',NULL,NULL),
(27,7,20,NULL,2.000,15.80,'ativo',NULL,NULL),
(28,7,34,NULL,1.000,17.02,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(101,25,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(15,26,NULL,NULL,0.500,'2026-10-26 13:43:59','venda'),
(39,27,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(67,28,NULL,NULL,1.000,'2026-10-26 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(7,7,3,113.44);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(7,7,'NFCe','000007','1','90000000000000000000000000000000000000000007','2026-10-26 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(8,2,3,NULL,'2026-10-26 15:32:00',39.77,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(29,8,4,NULL,0.500,11.12,'ativo',NULL,NULL),
(30,8,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(31,8,27,NULL,1.000,4.91,'ativo',NULL,NULL),
(32,8,41,NULL,2.000,7.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(7,29,NULL,NULL,0.500,'2026-10-26 15:32:00','venda'),
(29,30,NULL,NULL,2.000,'2026-10-26 15:32:00','venda'),
(53,31,NULL,NULL,1.000,'2026-10-26 15:32:00','venda'),
(81,32,NULL,NULL,2.000,'2026-10-26 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(8,8,4,39.77);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(8,8,'NFCe','000008','1','90000000000000000000000000000000000000000008','2026-10-26 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 499.44 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=2 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(2,10,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(3,3,4,'2026-10-26 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(9,3,4,NULL,'2026-10-26 10:08:00',92.71,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(33,9,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(34,9,22,NULL,1.000,18.90,'ativo',NULL,NULL),
(35,9,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(36,9,49,NULL,1.000,19.97,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(21,33,NULL,NULL,2.000,'2026-10-26 10:08:00','venda'),
(43,34,NULL,NULL,1.000,'2026-10-26 10:08:00','venda'),
(67,35,NULL,NULL,2.000,'2026-10-26 10:08:00','venda'),
(97,36,NULL,NULL,1.000,'2026-10-26 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(9,9,5,92.71);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(9,9,'NFCe','000009','1','90000000000000000000000000000000000000000009','2026-10-26 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(10,3,4,NULL,'2026-10-26 11:56:00',42.96,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(37,10,18,NULL,1.000,12.34,'ativo',NULL,NULL),
(38,10,29,NULL,2.000,8.37,'ativo',NULL,NULL),
(39,10,41,NULL,1.000,7.50,'ativo',NULL,NULL),
(40,10,2,NULL,0.750,8.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(35,37,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(57,38,NULL,NULL,2.000,'2026-10-26 11:56:00','venda'),
(81,39,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(3,40,NULL,NULL,0.750,'2026-10-26 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(10,10,1,25.78),
(11,10,3,17.18);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(10,10,'NFCe','000010','1','90000000000000000000000000000000000000000010','2026-10-26 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(11,3,4,NULL,'2026-10-26 13:43:59',129.09,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(41,11,25,NULL,2.000,24.45,'ativo',NULL,NULL),
(42,11,36,NULL,1.000,20.48,'ativo',NULL,NULL),
(43,11,49,NULL,2.000,19.97,'ativo',NULL,NULL),
(44,11,9,NULL,1.000,19.77,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(49,41,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(71,42,NULL,NULL,1.000,'2026-10-26 13:43:59','venda'),
(97,43,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(17,44,NULL,NULL,1.000,'2026-10-26 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(12,11,2,129.09);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(11,11,'NFCe','000011','1','90000000000000000000000000000000000000000011','2026-10-26 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(12,3,4,NULL,'2026-10-26 15:32:00',50.24,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(45,12,32,NULL,1.000,4.80,'ativo',NULL,NULL),
(46,12,43,NULL,2.000,9.59,'ativo',NULL,NULL),
(47,12,2,NULL,1.000,8.50,'ativo',NULL,NULL),
(48,12,16,NULL,2.000,8.88,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(63,45,NULL,NULL,1.000,'2026-10-26 15:32:00','venda'),
(85,46,NULL,NULL,2.000,'2026-10-26 15:32:00','venda'),
(3,47,NULL,NULL,1.000,'2026-10-26 15:32:00','venda'),
(31,48,NULL,NULL,2.000,'2026-10-26 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(13,12,3,50.24);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(12,12,'NFCe','000012','1','90000000000000000000000000000000000000000012','2026-10-26 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(1,3,9,'2026-10-26 13:00:00',90.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 450.00 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=3 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(3,9,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(4,4,5,'2026-10-26 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(13,4,5,NULL,'2026-10-26 10:08:00',124.94,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(49,13,39,NULL,2.000,25.67,'ativo',NULL,NULL),
(50,13,51,NULL,1.000,27.90,'ativo',NULL,NULL),
(51,13,9,NULL,1.250,19.77,'ativo',NULL,NULL),
(52,13,23,NULL,1.000,20.99,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(77,49,NULL,NULL,2.000,'2026-10-26 10:08:00','venda'),
(101,50,NULL,NULL,1.000,'2026-10-26 10:08:00','venda'),
(17,51,NULL,NULL,1.250,'2026-10-26 10:08:00','venda'),
(45,52,NULL,NULL,1.000,'2026-10-26 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(14,13,4,124.94);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(13,13,'NFCe','000013','1','90000000000000000000000000000000000000000013','2026-10-26 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(14,4,5,NULL,'2026-10-26 11:56:00',57.76,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(53,14,46,NULL,1.000,14.78,'ativo',NULL,NULL),
(54,14,4,NULL,1.250,11.12,'ativo',NULL,NULL),
(55,14,16,NULL,1.000,8.88,'ativo',NULL,NULL),
(56,14,30,NULL,2.000,10.10,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(91,53,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(7,54,NULL,NULL,1.250,'2026-10-26 11:56:00','venda'),
(31,55,NULL,NULL,1.000,'2026-10-26 11:56:00','venda'),
(59,56,NULL,NULL,2.000,'2026-10-26 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(15,14,5,57.76);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(14,14,'NFCe','000014','1','90000000000000000000000000000000000000000014','2026-10-26 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(15,4,5,NULL,'2026-10-26 13:43:59',85.33,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(57,15,54,NULL,2.000,5.62,'ativo',NULL,NULL),
(58,15,11,NULL,1.000,9.90,'ativo',NULL,NULL),
(59,15,23,NULL,2.000,20.99,'ativo',NULL,NULL),
(60,15,37,NULL,1.000,22.21,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(107,57,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(21,58,NULL,NULL,1.000,'2026-10-26 13:43:59','venda'),
(45,59,NULL,NULL,2.000,'2026-10-26 13:43:59','venda'),
(73,60,NULL,NULL,1.000,'2026-10-26 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(16,15,1,85.33);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(15,15,'NFCe','000015','1','90000000000000000000000000000000000000000015','2026-10-26 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(16,4,5,NULL,'2026-10-26 15:32:00',65.58,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(61,16,7,NULL,0.500,16.31,'ativo',NULL,NULL),
(62,16,18,NULL,2.000,12.34,'ativo',NULL,NULL),
(63,16,30,NULL,1.000,10.10,'ativo',NULL,NULL),
(64,16,44,NULL,2.000,11.32,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(13,61,NULL,NULL,0.500,'2026-10-26 15:32:00','venda'),
(35,62,NULL,NULL,2.000,'2026-10-26 15:32:00','venda'),
(59,63,NULL,NULL,1.000,'2026-10-26 15:32:00','venda'),
(87,64,NULL,NULL,2.000,'2026-10-26 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(17,16,2,65.58);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(16,16,'NFCe','000016','1','90000000000000000000000000000000000000000016','2026-10-26 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 483.61 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=4 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(4,10,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(5,5,6,'2026-10-26 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(17,5,6,NULL,'2026-10-26 10:35:00',104.87,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(65,17,14,NULL,2.000,5.42,'ativo',NULL,NULL),
(66,17,25,NULL,1.000,24.45,'ativo',NULL,NULL),
(67,17,37,NULL,2.000,22.21,'ativo',NULL,NULL),
(68,17,52,NULL,1.000,25.16,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(27,65,NULL,NULL,2.000,'2026-10-26 10:35:00','venda'),
(49,66,NULL,NULL,1.000,'2026-10-26 10:35:00','venda'),
(73,67,NULL,NULL,2.000,'2026-10-26 10:35:00','venda'),
(103,68,NULL,NULL,1.000,'2026-10-26 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(18,17,3,104.87);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(17,17,'NFCe','000017','1','90000000000000000000000000000000000000000017','2026-10-26 10:36:00','emitido');

INSERT INTO TROCA_OPERADOR (id_troca,id_sessao,id_funcionario_anterior,id_funcionario_novo,data_hora) VALUES
(1,5,6,9,'2026-10-26 12:49:00');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(18,5,9,NULL,'2026-10-26 12:50:00',43.46,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(69,18,21,NULL,1.000,12.90,'ativo',NULL,NULL),
(70,18,32,NULL,2.000,4.80,'ativo',NULL,NULL),
(71,18,44,NULL,1.000,11.32,'ativo',NULL,NULL),
(72,18,5,NULL,0.750,12.85,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(41,69,NULL,NULL,1.000,'2026-10-26 12:50:00','venda'),
(63,70,NULL,NULL,2.000,'2026-10-26 12:50:00','venda'),
(87,71,NULL,NULL,1.000,'2026-10-26 12:50:00','venda'),
(9,72,NULL,NULL,0.750,'2026-10-26 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(19,18,4,43.46);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(18,18,'NFCe','000018','1','90000000000000000000000000000000000000000018','2026-10-26 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(19,5,9,NULL,'2026-10-26 15:05:00',114.23,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(73,19,28,NULL,2.000,6.64,'ativo',NULL,NULL),
(74,19,39,NULL,1.000,25.67,'ativo',NULL,NULL),
(75,19,52,NULL,2.000,25.16,'ativo',NULL,NULL),
(76,19,12,NULL,1.000,24.96,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(55,73,NULL,NULL,2.000,'2026-10-26 15:05:00','venda'),
(77,74,NULL,NULL,1.000,'2026-10-26 15:05:00','venda'),
(103,75,NULL,NULL,2.000,'2026-10-26 15:05:00','venda'),
(23,76,NULL,NULL,1.000,'2026-10-26 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(20,19,5,114.23);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(19,19,'NFCe','000019','1','90000000000000000000000000000000000000000019','2026-10-26 15:06:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 437.56 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=5 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(5,9,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(6,6,7,'2026-10-26 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(20,6,7,NULL,'2026-10-26 10:35:00',89.30,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(77,20,35,NULL,1.000,18.75,'ativo',NULL,NULL),
(78,20,46,NULL,2.000,14.78,'ativo',NULL,NULL),
(79,20,5,NULL,1.000,12.85,'ativo',NULL,NULL),
(80,20,19,NULL,2.000,14.07,'ativo',NULL,NULL),
(81,20,10,10,0.500,21.50,'cancelado','Item retirado antes da conclusao','2026-10-26 10:36:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(69,77,NULL,NULL,1.000,'2026-10-26 10:35:00','venda'),
(91,78,NULL,NULL,2.000,'2026-10-26 10:35:00','venda'),
(9,79,NULL,NULL,1.000,'2026-10-26 10:35:00','venda'),
(37,80,NULL,NULL,2.000,'2026-10-26 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(21,20,1,53.58),
(22,20,3,35.72);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(20,20,'SAT','000020','1','90000000000000000000000000000000000000000020','2026-10-26 10:36:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(21,6,7,NULL,'2026-10-26 12:50:00',106.72,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(82,21,42,NULL,2.000,12.50,'ativo',NULL,NULL),
(83,21,54,NULL,1.000,5.62,'ativo',NULL,NULL),
(84,21,12,NULL,2.000,24.96,'ativo',NULL,NULL),
(85,21,26,NULL,1.000,26.18,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(83,82,NULL,NULL,2.000,'2026-10-26 12:50:00','venda'),
(107,83,NULL,NULL,1.000,'2026-10-26 12:50:00','venda'),
(23,84,NULL,NULL,2.000,'2026-10-26 12:50:00','venda'),
(51,85,NULL,NULL,1.000,'2026-10-26 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(23,21,2,106.72);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(21,21,'NFCe','000021','1','90000000000000000000000000000000000000000021','2026-10-26 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(22,6,7,NULL,'2026-10-26 15:05:00',86.74,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(86,22,50,NULL,1.000,21.70,'ativo',NULL,NULL),
(87,22,7,NULL,1.250,16.31,'ativo',NULL,NULL),
(88,22,19,NULL,1.000,14.07,'ativo',NULL,NULL),
(89,22,33,NULL,2.000,15.29,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(99,86,NULL,NULL,1.000,'2026-10-26 15:05:00','venda'),
(13,87,NULL,NULL,1.250,'2026-10-26 15:05:00','venda'),
(37,88,NULL,NULL,1.000,'2026-10-26 15:05:00','venda'),
(65,89,NULL,NULL,2.000,'2026-10-26 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(24,22,3,86.74);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(22,22,'NFCe','000022','1','90000000000000000000000000000000000000000022','2026-10-26 15:06:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(2,6,10,'2026-10-26 13:00:00',80.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 402.76 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=6 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(6,10,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(7,7,8,'2026-10-26 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(23,7,8,NULL,'2026-10-26 10:35:00',73.92,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(90,23,3,NULL,1.250,9.39,'ativo',NULL,NULL),
(91,23,14,NULL,1.000,5.42,'ativo',NULL,NULL),
(92,23,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(93,23,40,NULL,1.000,4.40,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(5,90,NULL,NULL,1.250,'2026-10-26 10:35:00','venda'),
(27,91,NULL,NULL,1.000,'2026-10-26 10:35:00','venda'),
(51,92,NULL,NULL,2.000,'2026-10-26 10:35:00','venda'),
(79,93,NULL,NULL,1.000,'2026-10-26 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(25,23,4,73.92);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(23,23,'NFCe','000023','1','90000000000000000000000000000000000000000023','2026-10-26 10:36:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(24,7,8,NULL,'2026-10-26 12:50:00',84.86,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(94,24,10,NULL,0.500,21.50,'ativo',NULL,NULL),
(95,24,21,NULL,2.000,12.90,'ativo',NULL,NULL),
(96,24,33,NULL,1.000,15.29,'ativo',NULL,NULL),
(97,24,47,NULL,2.000,16.51,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(19,94,NULL,NULL,0.500,'2026-10-26 12:50:00','venda'),
(41,95,NULL,NULL,2.000,'2026-10-26 12:50:00','venda'),
(65,96,NULL,NULL,1.000,'2026-10-26 12:50:00','venda'),
(93,97,NULL,NULL,2.000,'2026-10-26 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(26,24,5,84.86);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(24,24,'NFCe','000024','1','90000000000000000000000000000000000000000024','2026-10-26 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(25,7,8,NULL,'2026-10-26 15:05:00',40.11,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(98,25,17,NULL,2.000,10.61,'ativo',NULL,NULL),
(99,25,28,NULL,1.000,6.64,'ativo',NULL,NULL),
(100,25,40,NULL,2.000,4.40,'ativo',NULL,NULL),
(101,25,1,NULL,0.500,6.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(33,98,NULL,NULL,2.000,'2026-10-26 15:05:00','venda'),
(55,99,NULL,NULL,1.000,'2026-10-26 15:05:00','venda'),
(79,100,NULL,NULL,2.000,'2026-10-26 15:05:00','venda'),
(1,101,NULL,NULL,0.500,'2026-10-26 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(27,25,1,40.11);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(25,25,'NFCe','000025','1','90000000000000000000000000000000000000000025','2026-10-26 15:06:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 423.89 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=7 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(7,9,'2026-10-26 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(8,1,1,'2026-10-27 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(26,8,1,NULL,'2026-10-27 10:08:00',90.26,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(102,26,24,NULL,1.000,22.72,'ativo',NULL,NULL),
(103,26,35,NULL,2.000,18.75,'ativo',NULL,NULL),
(104,26,47,NULL,1.000,16.51,'ativo',NULL,NULL),
(105,26,8,NULL,0.750,18.04,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(47,102,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(69,103,NULL,NULL,2.000,'2026-10-27 10:08:00','venda'),
(93,104,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(15,105,NULL,NULL,0.750,'2026-10-27 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(28,26,2,90.26);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(26,26,'NFCe','000026','1','90000000000000000000000000000000000000000026','2026-10-27 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(27,8,1,NULL,'2026-10-27 11:56:00',37.83,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(106,27,31,NULL,2.000,6.50,'ativo',NULL,NULL),
(107,27,42,NULL,1.000,12.50,'ativo',NULL,NULL),
(108,27,1,NULL,0.750,6.90,'ativo',NULL,NULL),
(109,27,15,NULL,1.000,7.15,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(61,106,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(83,107,NULL,NULL,1.000,'2026-10-27 11:56:00','venda'),
(1,108,NULL,NULL,0.750,'2026-10-27 11:56:00','venda'),
(29,109,NULL,NULL,1.000,'2026-10-27 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(29,27,3,37.83);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(27,27,'NFCe','000027','1','90000000000000000000000000000000000000000027','2026-10-27 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(28,8,1,NULL,'2026-10-27 13:43:59',123.18,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(110,28,38,NULL,1.000,23.94,'ativo',NULL,NULL),
(111,28,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(112,28,8,NULL,1.000,18.04,'ativo',NULL,NULL),
(113,28,22,NULL,2.000,18.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(75,110,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(99,111,NULL,NULL,2.000,'2026-10-27 13:43:59','venda'),
(15,112,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(43,113,NULL,NULL,2.000,'2026-10-27 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(30,28,4,123.18);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(28,28,'NFCe','000028','1','90000000000000000000000000000000000000000028','2026-10-27 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(29,8,1,NULL,'2026-10-27 15:32:00',58.16,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(114,29,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(115,29,3,NULL,1.000,9.39,'ativo',NULL,NULL),
(116,29,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(117,29,29,NULL,1.000,8.37,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(89,114,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(5,115,NULL,NULL,1.000,'2026-10-27 15:32:00','venda'),
(29,116,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(57,117,NULL,NULL,1.000,'2026-10-27 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(31,29,5,58.16);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(29,29,'NFCe','000029','1','90000000000000000000000000000000000000000029','2026-10-27 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 459.43 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=8 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(8,10,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(9,2,3,'2026-10-27 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(30,9,3,NULL,'2026-10-27 10:08:00',113.63,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(118,30,53,NULL,1.000,26.89,'ativo',NULL,NULL),
(119,30,10,NULL,1.250,21.50,'ativo',NULL,NULL),
(120,30,22,NULL,1.000,18.90,'ativo',NULL,NULL),
(121,30,36,NULL,2.000,20.48,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(105,118,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(19,119,NULL,NULL,1.250,'2026-10-27 10:08:00','venda'),
(43,120,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(71,121,NULL,NULL,2.000,'2026-10-27 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(32,30,1,68.18),
(33,30,3,45.45);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(30,30,'NFCe','000030','1','90000000000000000000000000000000000000000030','2026-10-27 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(31,9,3,NULL,'2026-10-27 11:56:00',55.17,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(122,31,6,NULL,1.250,14.58,'ativo',NULL,NULL),
(123,31,17,NULL,1.000,10.61,'ativo',NULL,NULL),
(124,31,29,NULL,2.000,8.37,'ativo',NULL,NULL),
(125,31,43,NULL,1.000,9.59,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(11,122,NULL,NULL,1.250,'2026-10-27 11:56:00','venda'),
(33,123,NULL,NULL,1.000,'2026-10-27 11:56:00','venda'),
(57,124,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(85,125,NULL,NULL,1.000,'2026-10-27 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(34,31,2,55.17);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(31,31,'NFCe','000031','1','90000000000000000000000000000000000000000031','2026-10-27 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(32,9,3,NULL,'2026-10-27 13:43:59',148.41,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(126,32,13,NULL,1.000,26.69,'ativo',NULL,NULL),
(127,32,24,NULL,2.000,22.72,'ativo',NULL,NULL),
(128,32,36,NULL,1.000,20.48,'ativo',NULL,NULL),
(129,32,51,NULL,2.000,27.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(25,126,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(47,127,NULL,NULL,2.000,'2026-10-27 13:43:59','venda'),
(71,128,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(101,129,NULL,NULL,2.000,'2026-10-27 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(35,32,3,148.41);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(32,32,'NFCe','000032','1','90000000000000000000000000000000000000000032','2026-10-27 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(33,9,3,NULL,'2026-10-27 15:32:00',62.84,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(130,33,20,NULL,2.000,15.80,'ativo',NULL,NULL),
(131,33,31,NULL,1.000,6.50,'ativo',NULL,NULL),
(132,33,43,NULL,2.000,9.59,'ativo',NULL,NULL),
(133,33,4,NULL,0.500,11.12,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(39,130,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(61,131,NULL,NULL,1.000,'2026-10-27 15:32:00','venda'),
(85,132,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(7,133,NULL,NULL,0.500,'2026-10-27 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(36,33,4,62.84);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(33,33,'NFCe','000033','1','90000000000000000000000000000000000000000033','2026-10-27 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(3,9,9,'2026-10-27 13:00:00',70.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 485.05 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=9 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(9,9,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(10,3,4,'2026-10-27 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(34,10,4,NULL,'2026-10-27 10:08:00',100.49,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(134,34,27,NULL,1.000,4.91,'ativo',NULL,NULL),
(135,34,38,NULL,2.000,23.94,'ativo',NULL,NULL),
(136,34,51,NULL,1.000,27.90,'ativo',NULL,NULL),
(137,34,11,NULL,2.000,9.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(53,134,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(75,135,NULL,NULL,2.000,'2026-10-27 10:08:00','venda'),
(101,136,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(21,137,NULL,NULL,2.000,'2026-10-27 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(37,34,5,100.49);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(34,34,'NFCe','000034','1','90000000000000000000000000000000000000000034','2026-10-27 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(35,10,4,NULL,'2026-10-27 11:56:00',67.77,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(138,35,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(139,35,45,NULL,1.000,13.05,'ativo',NULL,NULL),
(140,35,4,NULL,0.750,11.12,'ativo',NULL,NULL),
(141,35,18,NULL,1.000,12.34,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(67,138,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(89,139,NULL,NULL,1.000,'2026-10-27 11:56:00','venda'),
(7,140,NULL,NULL,0.750,'2026-10-27 11:56:00','venda'),
(35,141,NULL,NULL,1.000,'2026-10-27 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(38,35,1,67.77);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(35,35,'NFCe','000035','1','90000000000000000000000000000000000000000035','2026-10-27 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(36,10,4,NULL,'2026-10-27 13:43:59',120.08,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(142,36,41,NULL,1.000,7.50,'ativo',NULL,NULL),
(143,36,53,NULL,2.000,26.89,'ativo',NULL,NULL),
(144,36,11,NULL,1.000,9.90,'ativo',NULL,NULL),
(145,36,25,NULL,2.000,24.45,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(81,142,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(105,143,NULL,NULL,2.000,'2026-10-27 13:43:59','venda'),
(21,144,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(49,145,NULL,NULL,2.000,'2026-10-27 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(39,36,2,120.08);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(36,36,'NFCe','000036','1','90000000000000000000000000000000000000000036','2026-10-27 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(37,10,4,NULL,'2026-10-27 15:32:00',84.00,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(146,37,49,NULL,2.000,19.97,'ativo',NULL,NULL),
(147,37,6,NULL,1.000,14.58,'ativo',NULL,NULL),
(148,37,18,NULL,2.000,12.34,'ativo',NULL,NULL),
(149,37,32,NULL,1.000,4.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(97,146,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(11,147,NULL,NULL,1.000,'2026-10-27 15:32:00','venda'),
(35,148,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(63,149,NULL,NULL,1.000,'2026-10-27 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(40,37,3,84.00);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(37,37,'NFCe','000037','1','90000000000000000000000000000000000000000037','2026-10-27 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 574.34 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=10 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(10,10,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(11,4,5,'2026-10-27 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(38,11,5,NULL,'2026-10-27 10:08:00',137.67,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(150,38,2,NULL,1.000,8.50,'ativo',NULL,NULL),
(151,38,13,NULL,2.000,26.69,'ativo',NULL,NULL),
(152,38,25,NULL,1.000,24.45,'ativo',NULL,NULL),
(153,38,39,NULL,2.000,25.67,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(3,150,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(25,151,NULL,NULL,2.000,'2026-10-27 10:08:00','venda'),
(49,152,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(77,153,NULL,NULL,2.000,'2026-10-27 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(41,38,4,137.67);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(38,38,'NFCe','000038','1','90000000000000000000000000000000000000000038','2026-10-27 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(39,11,5,NULL,'2026-10-27 11:56:00',64.89,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(154,39,9,NULL,1.250,19.77,'ativo',NULL,NULL),
(155,39,20,NULL,1.000,15.80,'ativo',NULL,NULL),
(156,39,32,NULL,2.000,4.80,'ativo',NULL,NULL),
(157,39,46,NULL,1.000,14.78,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(17,154,NULL,NULL,1.250,'2026-10-27 11:56:00','venda'),
(39,155,NULL,NULL,1.000,'2026-10-27 11:56:00','venda'),
(63,156,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(91,157,NULL,NULL,1.000,'2026-10-27 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(42,39,5,64.89);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(39,39,'NFCe','000039','1','90000000000000000000000000000000000000000039','2026-10-27 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(40,11,5,NULL,'2026-10-27 13:43:59',55.61,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(158,40,16,NULL,1.000,8.88,'ativo',NULL,NULL),
(159,40,27,NULL,2.000,4.91,'ativo',NULL,NULL),
(160,40,39,NULL,1.000,25.67,'ativo',NULL,NULL),
(161,40,54,NULL,2.000,5.62,'ativo',NULL,NULL),
(162,40,19,9,1.000,14.07,'cancelado','Item retirado antes da conclusao','2026-10-27 13:44:59');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(31,158,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(53,159,NULL,NULL,2.000,'2026-10-27 13:43:59','venda'),
(77,160,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(107,161,NULL,NULL,2.000,'2026-10-27 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(43,40,1,33.37),
(44,40,3,22.24);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(40,40,'SAT','000040','1','90000000000000000000000000000000000000000040','2026-10-27 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(41,11,5,NULL,'2026-10-27 15:32:00',96.72,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(163,41,23,NULL,2.000,20.99,'ativo',NULL,NULL),
(164,41,34,NULL,1.000,17.02,'ativo',NULL,NULL),
(165,41,46,NULL,2.000,14.78,'ativo',NULL,NULL),
(166,41,7,NULL,0.500,16.31,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(45,163,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(67,164,NULL,NULL,1.000,'2026-10-27 15:32:00','venda'),
(91,165,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(13,166,NULL,NULL,0.500,'2026-10-27 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(45,41,2,96.72);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(41,41,'NFCe','000041','1','90000000000000000000000000000000000000000041','2026-10-27 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 579.89 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=11 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(11,9,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(12,5,6,'2026-10-27 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(42,12,6,NULL,'2026-10-27 10:08:00',41.56,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(167,42,30,NULL,1.000,10.10,'ativo',NULL,NULL),
(168,42,41,NULL,2.000,7.50,'ativo',NULL,NULL),
(169,42,54,NULL,1.000,5.62,'ativo',NULL,NULL),
(170,42,14,NULL,2.000,5.42,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(59,167,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(81,168,NULL,NULL,2.000,'2026-10-27 10:08:00','venda'),
(107,169,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(27,170,NULL,NULL,2.000,'2026-10-27 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(46,42,3,41.56);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(42,42,'NFCe','000042','1','90000000000000000000000000000000000000000042','2026-10-27 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(43,12,6,NULL,'2026-10-27 11:56:00',89.52,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(171,43,37,NULL,2.000,22.21,'ativo',NULL,NULL),
(172,43,49,NULL,1.000,19.97,'ativo',NULL,NULL),
(173,43,7,NULL,0.750,16.31,'ativo',NULL,NULL),
(174,43,21,NULL,1.000,12.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(73,171,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(97,172,NULL,NULL,1.000,'2026-10-27 11:56:00','venda'),
(13,173,NULL,NULL,0.750,'2026-10-27 11:56:00','venda'),
(41,174,NULL,NULL,1.000,'2026-10-27 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(47,43,4,89.52);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(43,43,'NFCe','000043','1','90000000000000000000000000000000000000000043','2026-10-27 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(44,12,6,NULL,'2026-10-27 13:43:59',36.40,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(175,44,44,NULL,1.000,11.32,'ativo',NULL,NULL),
(176,44,2,NULL,0.750,8.50,'ativo',NULL,NULL),
(177,44,14,NULL,1.000,5.42,'ativo',NULL,NULL),
(178,44,28,NULL,2.000,6.64,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(87,175,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(3,176,NULL,NULL,0.750,'2026-10-27 13:43:59','venda'),
(27,177,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(55,178,NULL,NULL,2.000,'2026-10-27 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(48,44,5,36.40);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(44,44,'NFCe','000044','1','90000000000000000000000000000000000000000044','2026-10-27 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(45,12,6,NULL,'2026-10-27 15:32:00',114.64,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(179,45,52,NULL,2.000,25.16,'ativo',NULL,NULL),
(180,45,9,NULL,1.000,19.77,'ativo',NULL,NULL),
(181,45,21,NULL,2.000,12.90,'ativo',NULL,NULL),
(182,45,35,NULL,1.000,18.75,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(103,179,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(17,180,NULL,NULL,1.000,'2026-10-27 15:32:00','venda'),
(41,181,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(69,182,NULL,NULL,1.000,'2026-10-27 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(49,45,1,114.64);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(45,45,'NFCe','000045','1','90000000000000000000000000000000000000000045','2026-10-27 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(4,12,10,'2026-10-27 13:00:00',60.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 372.12 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=12 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(12,10,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(13,6,7,'2026-10-27 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(46,13,7,NULL,'2026-10-27 10:08:00',62.25,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(183,46,5,NULL,1.000,12.85,'ativo',NULL,NULL),
(184,46,16,NULL,2.000,8.88,'ativo',NULL,NULL),
(185,46,28,NULL,1.000,6.64,'ativo',NULL,NULL),
(186,46,42,NULL,2.000,12.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(9,183,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(31,184,NULL,NULL,2.000,'2026-10-27 10:08:00','venda'),
(55,185,NULL,NULL,1.000,'2026-10-27 10:08:00','venda'),
(83,186,NULL,NULL,2.000,'2026-10-27 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(50,46,2,62.25);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(46,46,'NFCe','000046','1','90000000000000000000000000000000000000000046','2026-10-27 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(47,13,7,NULL,'2026-10-27 11:56:00',130.11,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(187,47,12,NULL,2.000,24.96,'ativo',NULL,NULL),
(188,47,23,NULL,1.000,20.99,'ativo',NULL,NULL),
(189,47,35,NULL,2.000,18.75,'ativo',NULL,NULL),
(190,47,50,NULL,1.000,21.70,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(23,187,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(45,188,NULL,NULL,1.000,'2026-10-27 11:56:00','venda'),
(69,189,NULL,NULL,2.000,'2026-10-27 11:56:00','venda'),
(99,190,NULL,NULL,1.000,'2026-10-27 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(51,47,3,130.11);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(47,47,'NFCe','000047','1','90000000000000000000000000000000000000000047','2026-10-27 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(48,13,7,NULL,'2026-10-27 13:43:59',58.51,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(191,48,19,NULL,1.000,14.07,'ativo',NULL,NULL),
(192,48,30,NULL,2.000,10.10,'ativo',NULL,NULL),
(193,48,42,NULL,1.000,12.50,'ativo',NULL,NULL),
(194,48,3,NULL,1.250,9.39,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(37,191,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(59,192,NULL,NULL,2.000,'2026-10-27 13:43:59','venda'),
(83,193,NULL,NULL,1.000,'2026-10-27 13:43:59','venda'),
(5,194,NULL,NULL,1.250,'2026-10-27 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(52,48,4,58.51);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(48,48,'NFCe','000048','1','90000000000000000000000000000000000000000048','2026-10-27 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(49,13,7,NULL,'2026-10-27 15:32:00',128.72,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(195,49,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(196,49,37,NULL,1.000,22.21,'ativo',NULL,NULL),
(197,49,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(198,49,10,NULL,0.500,21.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(51,195,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(73,196,NULL,NULL,1.000,'2026-10-27 15:32:00','venda'),
(99,197,NULL,NULL,2.000,'2026-10-27 15:32:00','venda'),
(19,198,NULL,NULL,0.500,'2026-10-27 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(53,49,5,128.72);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(49,49,'NFCe','000049','1','90000000000000000000000000000000000000000049','2026-10-27 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 554.59 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=13 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(13,9,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(14,7,8,'2026-10-27 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(50,14,8,NULL,'2026-10-27 10:35:00',63.85,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(199,50,33,NULL,1.000,15.29,'ativo',NULL,NULL),
(200,50,44,NULL,2.000,11.32,'ativo',NULL,NULL),
(201,50,3,NULL,0.500,9.39,'ativo',NULL,NULL),
(202,50,17,NULL,2.000,10.61,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(65,199,NULL,NULL,1.000,'2026-10-27 10:35:00','venda'),
(87,200,NULL,NULL,2.000,'2026-10-27 10:35:00','venda'),
(5,201,NULL,NULL,0.500,'2026-10-27 10:35:00','venda'),
(33,202,NULL,NULL,2.000,'2026-10-27 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(54,50,1,38.31),
(55,50,3,25.54);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(50,50,'NFCe','000050','1','90000000000000000000000000000000000000000050','2026-10-27 10:36:00','emitido');

CALL cancelar_venda(50,10,'Cancelamento ficticio para teste','2026-10-27 10:40:00');


INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(51,14,8,NULL,'2026-10-27 12:50:00',72.81,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(203,51,40,NULL,2.000,4.40,'ativo',NULL,NULL),
(204,51,52,NULL,1.000,25.16,'ativo',NULL,NULL),
(205,51,10,NULL,0.750,21.50,'ativo',NULL,NULL),
(206,51,24,NULL,1.000,22.72,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(79,203,NULL,NULL,2.000,'2026-10-27 12:50:00','venda'),
(103,204,NULL,NULL,1.000,'2026-10-27 12:50:00','venda'),
(19,205,NULL,NULL,0.750,'2026-10-27 12:50:00','venda'),
(47,206,NULL,NULL,1.000,'2026-10-27 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(56,51,2,72.81);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(51,51,'NFCe','000051','1','90000000000000000000000000000000000000000051','2026-10-27 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(52,14,8,NULL,'2026-10-27 15:05:00',49.76,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(207,52,47,NULL,1.000,16.51,'ativo',NULL,NULL),
(208,52,5,NULL,0.750,12.85,'ativo',NULL,NULL),
(209,52,17,NULL,1.000,10.61,'ativo',NULL,NULL),
(210,52,31,NULL,2.000,6.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(93,207,NULL,NULL,1.000,'2026-10-27 15:05:00','venda'),
(9,208,NULL,NULL,0.750,'2026-10-27 15:05:00','venda'),
(33,209,NULL,NULL,1.000,'2026-10-27 15:05:00','venda'),
(61,210,NULL,NULL,2.000,'2026-10-27 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(57,52,3,49.76);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(52,52,'NFCe','000052','1','90000000000000000000000000000000000000000052','2026-10-27 15:06:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 322.57 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=14 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(14,10,'2026-10-27 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(15,1,1,'2026-10-28 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(53,15,1,NULL,'2026-10-28 10:08:00',99.52,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(211,53,1,NULL,0.750,6.90,'ativo',NULL,NULL),
(212,53,12,NULL,1.000,24.96,'ativo',NULL,NULL),
(213,53,24,NULL,2.000,22.72,'ativo',NULL,NULL),
(214,53,38,NULL,1.000,23.94,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(1,211,NULL,NULL,0.750,'2026-10-28 10:08:00','venda'),
(23,212,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(47,213,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(75,214,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(58,53,4,99.52);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(53,53,'NFCe','000053','1','90000000000000000000000000000000000000000053','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(54,15,1,NULL,'2026-10-28 11:56:00',78.78,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(215,54,8,NULL,1.000,18.04,'ativo',NULL,NULL),
(216,54,19,NULL,2.000,14.07,'ativo',NULL,NULL),
(217,54,31,NULL,1.000,6.50,'ativo',NULL,NULL),
(218,54,45,NULL,2.000,13.05,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(15,215,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(37,216,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(61,217,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(89,218,NULL,NULL,2.000,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(59,54,5,78.78);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(54,54,'NFCe','000054','1','90000000000000000000000000000000000000000054','2026-10-28 11:57:00','emitido');

INSERT INTO TROCA_OPERADOR (id_troca,id_sessao,id_funcionario_anterior,id_funcionario_novo,data_hora) VALUES
(2,15,1,9,'2026-10-28 13:42:59');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(55,15,9,NULL,'2026-10-28 13:43:59',115.25,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(219,55,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(220,55,26,NULL,1.000,26.18,'ativo',NULL,NULL),
(221,55,38,NULL,2.000,23.94,'ativo',NULL,NULL),
(222,55,53,NULL,1.000,26.89,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(29,219,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(51,220,NULL,NULL,1.000,'2026-10-28 13:43:59','venda'),
(75,221,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(105,222,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(60,55,1,115.25);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(55,55,'NFCe','000055','1','90000000000000000000000000000000000000000055','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(56,15,9,NULL,'2026-10-28 15:32:00',80.76,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(223,56,22,NULL,1.000,18.90,'ativo',NULL,NULL),
(224,56,33,NULL,2.000,15.29,'ativo',NULL,NULL),
(225,56,45,NULL,1.000,13.05,'ativo',NULL,NULL),
(226,56,6,NULL,1.250,14.58,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(43,223,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(65,224,NULL,NULL,2.000,'2026-10-28 15:32:00','venda'),
(89,225,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(11,226,NULL,NULL,1.250,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(61,56,2,80.76);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(56,56,'NFCe','000056','1','90000000000000000000000000000000000000000056','2026-10-28 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(5,15,9,'2026-10-28 13:00:00',90.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 507.81 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=15 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(15,9,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(16,2,2,'2026-10-28 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(57,16,2,NULL,'2026-10-28 10:08:00',101.61,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(227,57,29,NULL,2.000,8.37,'ativo',NULL,NULL),
(228,57,40,NULL,1.000,4.40,'ativo',NULL,NULL),
(229,57,53,NULL,2.000,26.89,'ativo',NULL,NULL),
(230,57,13,NULL,1.000,26.69,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(57,227,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(79,228,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(105,229,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(25,230,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(62,57,3,101.61);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(57,57,'NFCe','000057','1','90000000000000000000000000000000000000000057','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(58,16,2,NULL,'2026-10-28 11:56:00',92.39,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(231,58,36,NULL,1.000,20.48,'ativo',NULL,NULL),
(232,58,47,NULL,2.000,16.51,'ativo',NULL,NULL),
(233,58,6,NULL,0.500,14.58,'ativo',NULL,NULL),
(234,58,20,NULL,2.000,15.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(71,231,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(93,232,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(11,233,NULL,NULL,0.500,'2026-10-28 11:56:00','venda'),
(39,234,NULL,NULL,2.000,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(63,58,4,92.39);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(58,58,'NFCe','000058','1','90000000000000000000000000000000000000000058','2026-10-28 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(59,16,2,NULL,'2026-10-28 13:43:59',80.92,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(235,59,43,NULL,2.000,9.59,'ativo',NULL,NULL),
(236,59,1,NULL,0.500,6.90,'ativo',NULL,NULL),
(237,59,13,NULL,2.000,26.69,'ativo',NULL,NULL),
(238,59,27,NULL,1.000,4.91,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(85,235,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(1,236,NULL,NULL,0.500,'2026-10-28 13:43:59','venda'),
(25,237,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(53,238,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(64,59,5,80.92);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(59,59,'NFCe','000059','1','90000000000000000000000000000000000000000059','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(60,16,2,NULL,'2026-10-28 15:32:00',91.27,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(239,60,51,NULL,1.000,27.90,'ativo',NULL,NULL),
(240,60,8,NULL,0.750,18.04,'ativo',NULL,NULL),
(241,60,20,NULL,1.000,15.80,'ativo',NULL,NULL),
(242,60,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(243,60,28,10,1.000,6.64,'cancelado','Item retirado antes da conclusao','2026-10-28 15:33:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(101,239,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(15,240,NULL,NULL,0.750,'2026-10-28 15:32:00','venda'),
(39,241,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(67,242,NULL,NULL,2.000,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(65,60,1,54.76),
(66,60,3,36.51);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(60,60,'SAT','000060','1','90000000000000000000000000000000000000000060','2026-10-28 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 516.19 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=16 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(16,10,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(17,3,4,'2026-10-28 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(61,17,4,NULL,'2026-10-28 10:08:00',32.81,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(244,61,4,NULL,0.750,11.12,'ativo',NULL,NULL),
(245,61,15,NULL,1.000,7.15,'ativo',NULL,NULL),
(246,61,27,NULL,2.000,4.91,'ativo',NULL,NULL),
(247,61,41,NULL,1.000,7.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(7,244,NULL,NULL,0.750,'2026-10-28 10:08:00','venda'),
(29,245,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(53,246,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(81,247,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(67,61,2,32.81);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(61,61,'NFCe','000061','1','90000000000000000000000000000000000000000061','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(62,17,4,NULL,'2026-10-28 11:56:00',104.66,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(248,62,11,NULL,1.000,9.90,'ativo',NULL,NULL),
(249,62,22,NULL,2.000,18.90,'ativo',NULL,NULL),
(250,62,34,NULL,1.000,17.02,'ativo',NULL,NULL),
(251,62,49,NULL,2.000,19.97,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(21,248,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(43,249,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(67,250,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(97,251,NULL,NULL,2.000,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(68,62,3,104.66);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(62,62,'NFCe','000062','1','90000000000000000000000000000000000000000062','2026-10-28 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(63,17,4,NULL,'2026-10-28 13:43:59',56.55,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(252,63,18,NULL,2.000,12.34,'ativo',NULL,NULL),
(253,63,29,NULL,1.000,8.37,'ativo',NULL,NULL),
(254,63,41,NULL,2.000,7.50,'ativo',NULL,NULL),
(255,63,2,NULL,1.000,8.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(35,252,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(57,253,NULL,NULL,1.000,'2026-10-28 13:43:59','venda'),
(81,254,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(3,255,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(69,63,4,56.55);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(63,63,'NFCe','000063','1','90000000000000000000000000000000000000000063','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(64,17,4,NULL,'2026-10-28 15:32:00',110.09,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(256,64,25,NULL,1.000,24.45,'ativo',NULL,NULL),
(257,64,36,NULL,2.000,20.48,'ativo',NULL,NULL),
(258,64,49,NULL,1.000,19.97,'ativo',NULL,NULL),
(259,64,9,NULL,1.250,19.77,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(49,256,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(71,257,NULL,NULL,2.000,'2026-10-28 15:32:00','venda'),
(97,258,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(17,259,NULL,NULL,1.250,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(70,64,5,110.09);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(64,64,'NFCe','000064','1','90000000000000000000000000000000000000000064','2026-10-28 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 479.11 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=17 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(17,9,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(18,4,5,'2026-10-28 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(65,18,5,NULL,'2026-10-28 10:08:00',38.70,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(260,65,32,NULL,2.000,4.80,'ativo',NULL,NULL),
(261,65,43,NULL,1.000,9.59,'ativo',NULL,NULL),
(262,65,2,NULL,1.250,8.50,'ativo',NULL,NULL),
(263,65,16,NULL,1.000,8.88,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(63,260,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(85,261,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(3,262,NULL,NULL,1.250,'2026-10-28 10:08:00','venda'),
(31,263,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(71,65,1,38.70);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(65,65,'NFCe','000065','1','90000000000000000000000000000000000000000065','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(66,18,5,NULL,'2026-10-28 11:56:00',133.34,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(264,66,39,NULL,1.000,25.67,'ativo',NULL,NULL),
(265,66,51,NULL,2.000,27.90,'ativo',NULL,NULL),
(266,66,9,NULL,0.500,19.77,'ativo',NULL,NULL),
(267,66,23,NULL,2.000,20.99,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(77,264,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(101,265,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(17,266,NULL,NULL,0.500,'2026-10-28 11:56:00','venda'),
(45,267,NULL,NULL,2.000,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(72,66,2,133.34);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(66,66,'NFCe','000066','1','90000000000000000000000000000000000000000066','2026-10-28 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(67,18,5,NULL,'2026-10-28 13:43:59',62.98,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(268,67,46,NULL,2.000,14.78,'ativo',NULL,NULL),
(269,67,4,NULL,0.500,11.12,'ativo',NULL,NULL),
(270,67,16,NULL,2.000,8.88,'ativo',NULL,NULL),
(271,67,30,NULL,1.000,10.10,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(91,268,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(7,269,NULL,NULL,0.500,'2026-10-28 13:43:59','venda'),
(31,270,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(59,271,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(73,67,3,62.98);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(67,67,'NFCe','000067','1','90000000000000000000000000000000000000000067','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(68,18,5,NULL,'2026-10-28 15:32:00',90.83,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(272,68,54,NULL,1.000,5.62,'ativo',NULL,NULL),
(273,68,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(274,68,23,NULL,1.000,20.99,'ativo',NULL,NULL),
(275,68,37,NULL,2.000,22.21,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(107,272,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(21,273,NULL,NULL,2.000,'2026-10-28 15:32:00','venda'),
(45,274,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(73,275,NULL,NULL,2.000,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(74,68,4,90.83);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(68,68,'NFCe','000068','1','90000000000000000000000000000000000000000068','2026-10-28 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(6,18,10,'2026-10-28 13:00:00',80.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 445.85 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=18 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(18,10,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(19,5,6,'2026-10-28 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(69,19,6,NULL,'2026-10-28 10:08:00',56.09,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(276,69,7,NULL,0.750,16.31,'ativo',NULL,NULL),
(277,69,18,NULL,1.000,12.34,'ativo',NULL,NULL),
(278,69,30,NULL,2.000,10.10,'ativo',NULL,NULL),
(279,69,44,NULL,1.000,11.32,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(13,276,NULL,NULL,0.750,'2026-10-28 10:08:00','venda'),
(35,277,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(59,278,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(87,279,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(75,69,5,56.09);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(69,69,'NFCe','000069','1','90000000000000000000000000000000000000000069','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(70,19,6,NULL,'2026-10-28 11:56:00',126.85,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(280,70,14,NULL,1.000,5.42,'ativo',NULL,NULL),
(281,70,25,NULL,2.000,24.45,'ativo',NULL,NULL),
(282,70,37,NULL,1.000,22.21,'ativo',NULL,NULL),
(283,70,52,NULL,2.000,25.16,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(27,280,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(49,281,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(73,282,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(103,283,NULL,NULL,2.000,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(76,70,1,76.11),
(77,70,3,50.74);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(70,70,'NFCe','000070','1','90000000000000000000000000000000000000000070','2026-10-28 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(71,19,6,NULL,'2026-10-28 13:43:59',66.09,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(284,71,21,NULL,2.000,12.90,'ativo',NULL,NULL),
(285,71,32,NULL,1.000,4.80,'ativo',NULL,NULL),
(286,71,44,NULL,2.000,11.32,'ativo',NULL,NULL),
(287,71,5,NULL,1.000,12.85,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(41,284,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(63,285,NULL,NULL,1.000,'2026-10-28 13:43:59','venda'),
(87,286,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(9,287,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(78,71,2,66.09);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(71,71,'NFCe','000071','1','90000000000000000000000000000000000000000071','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(72,19,6,NULL,'2026-10-28 15:32:00',133.06,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(288,72,28,NULL,1.000,6.64,'ativo',NULL,NULL),
(289,72,39,NULL,2.000,25.67,'ativo',NULL,NULL),
(290,72,52,NULL,1.000,25.16,'ativo',NULL,NULL),
(291,72,12,NULL,2.000,24.96,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(55,288,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(77,289,NULL,NULL,2.000,'2026-10-28 15:32:00','venda'),
(103,290,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(23,291,NULL,NULL,2.000,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(79,72,3,133.06);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(72,72,'NFCe','000072','1','90000000000000000000000000000000000000000072','2026-10-28 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 607.09 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=19 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(19,9,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(20,6,7,'2026-10-28 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(73,20,7,NULL,'2026-10-28 10:08:00',82.41,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(292,73,35,NULL,2.000,18.75,'ativo',NULL,NULL),
(293,73,46,NULL,1.000,14.78,'ativo',NULL,NULL),
(294,73,5,NULL,1.250,12.85,'ativo',NULL,NULL),
(295,73,19,NULL,1.000,14.07,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(69,292,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(91,293,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(9,294,NULL,NULL,1.250,'2026-10-28 10:08:00','venda'),
(37,295,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(80,73,4,82.41);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(73,73,'NFCe','000073','1','90000000000000000000000000000000000000000073','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(74,20,7,NULL,'2026-10-28 11:56:00',101.06,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(296,74,42,NULL,1.000,12.50,'ativo',NULL,NULL),
(297,74,54,NULL,2.000,5.62,'ativo',NULL,NULL),
(298,74,12,NULL,1.000,24.96,'ativo',NULL,NULL),
(299,74,26,NULL,2.000,26.18,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(83,296,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(107,297,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(23,298,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(51,299,NULL,NULL,2.000,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(81,74,5,101.06);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(74,74,'NFCe','000074','1','90000000000000000000000000000000000000000074','2026-10-28 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(75,20,7,NULL,'2026-10-28 13:43:59',94.99,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(300,75,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(301,75,7,NULL,0.500,16.31,'ativo',NULL,NULL),
(302,75,19,NULL,2.000,14.07,'ativo',NULL,NULL),
(303,75,33,NULL,1.000,15.29,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(99,300,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(13,301,NULL,NULL,0.500,'2026-10-28 13:43:59','venda'),
(37,302,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(65,303,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(82,75,1,94.99);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(75,75,'NFCe','000075','1','90000000000000000000000000000000000000000075','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(76,20,7,NULL,'2026-10-28 15:32:00',50.52,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(304,76,3,NULL,0.500,9.39,'ativo',NULL,NULL),
(305,76,14,NULL,2.000,5.42,'ativo',NULL,NULL),
(306,76,26,NULL,1.000,26.18,'ativo',NULL,NULL),
(307,76,40,NULL,2.000,4.40,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(5,304,NULL,NULL,0.500,'2026-10-28 15:32:00','venda'),
(27,305,NULL,NULL,2.000,'2026-10-28 15:32:00','venda'),
(51,306,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(79,307,NULL,NULL,2.000,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(83,76,2,50.52);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(76,76,'NFCe','000076','1','90000000000000000000000000000000000000000076','2026-10-28 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 480.98 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=20 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(20,10,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(21,7,8,'2026-10-28 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(77,21,8,NULL,'2026-10-28 10:08:00',76.12,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(308,77,10,NULL,0.750,21.50,'ativo',NULL,NULL),
(309,77,21,NULL,1.000,12.90,'ativo',NULL,NULL),
(310,77,33,NULL,2.000,15.29,'ativo',NULL,NULL),
(311,77,47,NULL,1.000,16.51,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(19,308,NULL,NULL,0.750,'2026-10-28 10:08:00','venda'),
(41,309,NULL,NULL,1.000,'2026-10-28 10:08:00','venda'),
(65,310,NULL,NULL,2.000,'2026-10-28 10:08:00','venda'),
(93,311,NULL,NULL,1.000,'2026-10-28 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(84,77,3,76.12);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(77,77,'NFCe','000077','1','90000000000000000000000000000000000000000077','2026-10-28 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(78,21,8,NULL,'2026-10-28 11:56:00',33.47,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(312,78,17,NULL,1.000,10.61,'ativo',NULL,NULL),
(313,78,28,NULL,2.000,6.64,'ativo',NULL,NULL),
(314,78,40,NULL,1.000,4.40,'ativo',NULL,NULL),
(315,78,1,NULL,0.750,6.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(33,312,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(55,313,NULL,NULL,2.000,'2026-10-28 11:56:00','venda'),
(79,314,NULL,NULL,1.000,'2026-10-28 11:56:00','venda'),
(1,315,NULL,NULL,0.750,'2026-10-28 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(85,78,4,33.47);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(78,78,'NFCe','000078','1','90000000000000000000000000000000000000000078','2026-10-28 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(79,21,8,NULL,'2026-10-28 13:43:59',115.25,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(316,79,24,NULL,2.000,22.72,'ativo',NULL,NULL),
(317,79,35,NULL,1.000,18.75,'ativo',NULL,NULL),
(318,79,47,NULL,2.000,16.51,'ativo',NULL,NULL),
(319,79,8,NULL,1.000,18.04,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(47,316,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(69,317,NULL,NULL,1.000,'2026-10-28 13:43:59','venda'),
(93,318,NULL,NULL,2.000,'2026-10-28 13:43:59','venda'),
(15,319,NULL,NULL,1.000,'2026-10-28 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(86,79,5,115.25);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(79,79,'NFCe','000079','1','90000000000000000000000000000000000000000079','2026-10-28 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(80,21,8,NULL,'2026-10-28 15:32:00',52.70,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(320,80,31,NULL,1.000,6.50,'ativo',NULL,NULL),
(321,80,42,NULL,2.000,12.50,'ativo',NULL,NULL),
(322,80,1,NULL,1.000,6.90,'ativo',NULL,NULL),
(323,80,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(324,80,37,9,1.000,22.21,'cancelado','Item retirado antes da conclusao','2026-10-28 15:33:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(61,320,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(83,321,NULL,NULL,2.000,'2026-10-28 15:32:00','venda'),
(1,322,NULL,NULL,1.000,'2026-10-28 15:32:00','venda'),
(29,323,NULL,NULL,2.000,'2026-10-28 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(87,80,1,31.62),
(88,80,3,21.08);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(80,80,'SAT','000080','1','90000000000000000000000000000000000000000080','2026-10-28 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(7,21,9,'2026-10-28 13:00:00',70.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 382.54 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=21 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(21,9,'2026-10-28 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(22,1,1,'2026-10-29 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(81,22,1,NULL,'2026-10-29 09:50:00',111.03,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(325,81,38,NULL,2.000,23.94,'ativo',NULL,NULL),
(326,81,50,NULL,1.000,21.70,'ativo',NULL,NULL),
(327,81,8,NULL,1.250,18.04,'ativo',NULL,NULL),
(328,81,22,NULL,1.000,18.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(75,325,NULL,NULL,2.000,'2026-10-29 09:50:00','venda'),
(99,326,NULL,NULL,1.000,'2026-10-29 09:50:00','venda'),
(15,327,NULL,NULL,1.250,'2026-10-29 09:50:00','venda'),
(43,328,NULL,NULL,1.000,'2026-10-29 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(89,81,2,111.03);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(81,81,'NFCe','000081','1','90000000000000000000000000000000000000000081','2026-10-29 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(82,22,1,NULL,'2026-10-29 11:20:00',48.68,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(329,82,45,NULL,1.000,13.05,'ativo',NULL,NULL),
(330,82,3,NULL,1.250,9.39,'ativo',NULL,NULL),
(331,82,15,NULL,1.000,7.15,'ativo',NULL,NULL),
(332,82,29,NULL,2.000,8.37,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(89,329,NULL,NULL,1.000,'2026-10-29 11:20:00','venda'),
(5,330,NULL,NULL,1.250,'2026-10-29 11:20:00','venda'),
(29,331,NULL,NULL,1.000,'2026-10-29 11:20:00','venda'),
(57,332,NULL,NULL,2.000,'2026-10-29 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(90,82,3,48.68);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(82,82,'NFCe','000082','1','90000000000000000000000000000000000000000082','2026-10-29 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(83,22,1,NULL,'2026-10-29 12:50:00',122.81,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(333,83,53,NULL,2.000,26.89,'ativo',NULL,NULL),
(334,83,10,NULL,0.500,21.50,'ativo',NULL,NULL),
(335,83,22,NULL,2.000,18.90,'ativo',NULL,NULL),
(336,83,36,NULL,1.000,20.48,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(105,333,NULL,NULL,2.000,'2026-10-29 12:50:00','venda'),
(19,334,NULL,NULL,0.500,'2026-10-29 12:50:00','venda'),
(43,335,NULL,NULL,2.000,'2026-10-29 12:50:00','venda'),
(71,336,NULL,NULL,1.000,'2026-10-29 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(91,83,4,122.81);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(83,83,'NFCe','000083','1','90000000000000000000000000000000000000000083','2026-10-29 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(84,22,1,NULL,'2026-10-29 14:20:00',56.06,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(337,84,6,NULL,0.500,14.58,'ativo',NULL,NULL),
(338,84,17,NULL,2.000,10.61,'ativo',NULL,NULL),
(339,84,29,NULL,1.000,8.37,'ativo',NULL,NULL),
(340,84,43,NULL,2.000,9.59,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(11,337,NULL,NULL,0.500,'2026-10-29 14:20:00','venda'),
(33,338,NULL,NULL,2.000,'2026-10-29 14:20:00','venda'),
(57,339,NULL,NULL,1.000,'2026-10-29 14:20:00','venda'),
(85,340,NULL,NULL,2.000,'2026-10-29 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(92,84,5,56.06);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(84,84,'NFCe','000084','1','90000000000000000000000000000000000000000084','2026-10-29 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(85,22,1,NULL,'2026-10-29 15:50:00',144.96,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(341,85,13,NULL,2.000,26.69,'ativo',NULL,NULL),
(342,85,24,NULL,1.000,22.72,'ativo',NULL,NULL),
(343,85,36,NULL,2.000,20.48,'ativo',NULL,NULL),
(344,85,51,NULL,1.000,27.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(25,341,NULL,NULL,2.000,'2026-10-29 15:50:00','venda'),
(47,342,NULL,NULL,1.000,'2026-10-29 15:50:00','venda'),
(71,343,NULL,NULL,2.000,'2026-10-29 15:50:00','venda'),
(101,344,NULL,NULL,1.000,'2026-10-29 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(93,85,1,144.96);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(85,85,'NFCe','000085','1','90000000000000000000000000000000000000000085','2026-10-29 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 683.54 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=22 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(22,10,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(23,2,2,'2026-10-29 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(86,23,2,NULL,'2026-10-29 09:50:00',46.73,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(345,86,20,NULL,1.000,15.80,'ativo',NULL,NULL),
(346,86,31,NULL,2.000,6.50,'ativo',NULL,NULL),
(347,86,43,NULL,1.000,9.59,'ativo',NULL,NULL),
(348,86,4,NULL,0.750,11.12,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(39,345,NULL,NULL,1.000,'2026-10-29 09:50:00','venda'),
(61,346,NULL,NULL,2.000,'2026-10-29 09:50:00','venda'),
(85,347,NULL,NULL,1.000,'2026-10-29 09:50:00','venda'),
(7,348,NULL,NULL,0.750,'2026-10-29 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(94,86,2,46.73);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(86,86,'NFCe','000086','1','90000000000000000000000000000000000000000086','2026-10-29 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(87,23,2,NULL,'2026-10-29 11:20:00',99.46,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(349,87,27,NULL,2.000,4.91,'ativo',NULL,NULL),
(350,87,38,NULL,1.000,23.94,'ativo',NULL,NULL),
(351,87,51,NULL,2.000,27.90,'ativo',NULL,NULL),
(352,87,11,NULL,1.000,9.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(53,349,NULL,NULL,2.000,'2026-10-29 11:20:00','venda'),
(75,350,NULL,NULL,1.000,'2026-10-29 11:20:00','venda'),
(101,351,NULL,NULL,2.000,'2026-10-29 11:20:00','venda'),
(21,352,NULL,NULL,1.000,'2026-10-29 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(95,87,3,99.46);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(87,87,'NFCe','000087','1','90000000000000000000000000000000000000000087','2026-10-29 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(88,23,2,NULL,'2026-10-29 12:50:00',78.92,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(353,88,34,NULL,1.000,17.02,'ativo',NULL,NULL),
(354,88,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(355,88,4,NULL,1.000,11.12,'ativo',NULL,NULL),
(356,88,18,NULL,2.000,12.34,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(67,353,NULL,NULL,1.000,'2026-10-29 12:50:00','venda'),
(89,354,NULL,NULL,2.000,'2026-10-29 12:50:00','venda'),
(7,355,NULL,NULL,1.000,'2026-10-29 12:50:00','venda'),
(35,356,NULL,NULL,2.000,'2026-10-29 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(96,88,4,78.92);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(88,88,'NFCe','000088','1','90000000000000000000000000000000000000000088','2026-10-29 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(89,23,2,NULL,'2026-10-29 14:20:00',86.14,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(357,89,41,NULL,2.000,7.50,'ativo',NULL,NULL),
(358,89,53,NULL,1.000,26.89,'ativo',NULL,NULL),
(359,89,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(360,89,25,NULL,1.000,24.45,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(81,357,NULL,NULL,2.000,'2026-10-29 14:20:00','venda'),
(105,358,NULL,NULL,1.000,'2026-10-29 14:20:00','venda'),
(21,359,NULL,NULL,2.000,'2026-10-29 14:20:00','venda'),
(49,360,NULL,NULL,1.000,'2026-10-29 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(97,89,5,86.14);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(89,89,'NFCe','000089','1','90000000000000000000000000000000000000000089','2026-10-29 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(90,23,2,NULL,'2026-10-29 15:50:00',60.14,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(361,90,49,NULL,1.000,19.97,'ativo',NULL,NULL),
(362,90,6,NULL,1.250,14.58,'ativo',NULL,NULL),
(363,90,18,NULL,1.000,12.34,'ativo',NULL,NULL),
(364,90,32,NULL,2.000,4.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(97,361,NULL,NULL,1.000,'2026-10-29 15:50:00','venda'),
(11,362,NULL,NULL,1.250,'2026-10-29 15:50:00','venda'),
(35,363,NULL,NULL,1.000,'2026-10-29 15:50:00','venda'),
(63,364,NULL,NULL,2.000,'2026-10-29 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(98,90,1,36.08),
(99,90,3,24.06);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(90,90,'NFCe','000090','1','90000000000000000000000000000000000000000090','2026-10-29 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 596.39 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=23 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(23,9,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(24,3,3,'2026-10-29 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(91,24,3,NULL,'2026-10-29 10:08:00',111.89,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(365,91,2,NULL,1.250,8.50,'ativo',NULL,NULL),
(366,91,13,NULL,1.000,26.69,'ativo',NULL,NULL),
(367,91,25,NULL,2.000,24.45,'ativo',NULL,NULL),
(368,91,39,NULL,1.000,25.67,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(3,365,NULL,NULL,1.250,'2026-10-29 10:08:00','venda'),
(25,366,NULL,NULL,1.000,'2026-10-29 10:08:00','venda'),
(49,367,NULL,NULL,2.000,'2026-10-29 10:08:00','venda'),
(77,368,NULL,NULL,1.000,'2026-10-29 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(100,91,2,111.89);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(91,91,'NFCe','000091','1','90000000000000000000000000000000000000000091','2026-10-29 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(92,24,3,NULL,'2026-10-29 11:56:00',75.85,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(369,92,9,NULL,0.500,19.77,'ativo',NULL,NULL),
(370,92,20,NULL,2.000,15.80,'ativo',NULL,NULL),
(371,92,32,NULL,1.000,4.80,'ativo',NULL,NULL),
(372,92,46,NULL,2.000,14.78,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(17,369,NULL,NULL,0.500,'2026-10-29 11:56:00','venda'),
(39,370,NULL,NULL,2.000,'2026-10-29 11:56:00','venda'),
(63,371,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(91,372,NULL,NULL,2.000,'2026-10-29 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(101,92,3,75.85);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(92,92,'NFCe','000092','1','90000000000000000000000000000000000000000092','2026-10-29 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(93,24,3,NULL,'2026-10-29 13:43:59',79.63,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(373,93,16,NULL,2.000,8.88,'ativo',NULL,NULL),
(374,93,27,NULL,1.000,4.91,'ativo',NULL,NULL),
(375,93,39,NULL,2.000,25.67,'ativo',NULL,NULL),
(376,93,54,NULL,1.000,5.62,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(31,373,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(53,374,NULL,NULL,1.000,'2026-10-29 13:43:59','venda'),
(77,375,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(107,376,NULL,NULL,1.000,'2026-10-29 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(102,93,4,79.63);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(93,93,'NFCe','000093','1','90000000000000000000000000000000000000000093','2026-10-29 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(94,24,3,NULL,'2026-10-29 15:32:00',82.04,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(377,94,23,NULL,1.000,20.99,'ativo',NULL,NULL),
(378,94,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(379,94,46,NULL,1.000,14.78,'ativo',NULL,NULL),
(380,94,7,NULL,0.750,16.31,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(45,377,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(67,378,NULL,NULL,2.000,'2026-10-29 15:32:00','venda'),
(91,379,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(13,380,NULL,NULL,0.750,'2026-10-29 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(103,94,5,82.04);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(94,94,'NFCe','000094','1','90000000000000000000000000000000000000000094','2026-10-29 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(8,24,10,'2026-10-29 13:00:00',60.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 439.41 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=24 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(24,10,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(25,4,5,'2026-10-29 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(95,25,5,NULL,'2026-10-29 10:08:00',44.36,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(381,95,30,NULL,2.000,10.10,'ativo',NULL,NULL),
(382,95,41,NULL,1.000,7.50,'ativo',NULL,NULL),
(383,95,54,NULL,2.000,5.62,'ativo',NULL,NULL),
(384,95,14,NULL,1.000,5.42,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(59,381,NULL,NULL,2.000,'2026-10-29 10:08:00','venda'),
(81,382,NULL,NULL,1.000,'2026-10-29 10:08:00','venda'),
(107,383,NULL,NULL,2.000,'2026-10-29 10:08:00','venda'),
(27,384,NULL,NULL,1.000,'2026-10-29 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(104,95,1,44.36);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(95,95,'NFCe','000095','1','90000000000000000000000000000000000000000095','2026-10-29 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(96,25,5,NULL,'2026-10-29 11:56:00',104.26,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(385,96,37,NULL,1.000,22.21,'ativo',NULL,NULL),
(386,96,49,NULL,2.000,19.97,'ativo',NULL,NULL),
(387,96,7,NULL,1.000,16.31,'ativo',NULL,NULL),
(388,96,21,NULL,2.000,12.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(73,385,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(97,386,NULL,NULL,2.000,'2026-10-29 11:56:00','venda'),
(13,387,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(41,388,NULL,NULL,2.000,'2026-10-29 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(105,96,2,104.26);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(96,96,'NFCe','000096','1','90000000000000000000000000000000000000000096','2026-10-29 11:57:00','emitido');

INSERT INTO TROCA_OPERADOR (id_troca,id_sessao,id_funcionario_anterior,id_funcionario_novo,data_hora) VALUES
(3,25,5,9,'2026-10-29 13:42:59');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(97,25,9,NULL,'2026-10-29 13:43:59',48.62,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(389,97,44,NULL,2.000,11.32,'ativo',NULL,NULL),
(390,97,2,NULL,1.000,8.50,'ativo',NULL,NULL),
(391,97,14,NULL,2.000,5.42,'ativo',NULL,NULL),
(392,97,28,NULL,1.000,6.64,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(87,389,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(3,390,NULL,NULL,1.000,'2026-10-29 13:43:59','venda'),
(27,391,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(55,392,NULL,NULL,1.000,'2026-10-29 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(106,97,3,48.62);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(97,97,'NFCe','000097','1','90000000000000000000000000000000000000000097','2026-10-29 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(98,25,9,NULL,'2026-10-29 15:32:00',100.27,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(393,98,52,NULL,1.000,25.16,'ativo',NULL,NULL),
(394,98,9,NULL,1.250,19.77,'ativo',NULL,NULL),
(395,98,21,NULL,1.000,12.90,'ativo',NULL,NULL),
(396,98,35,NULL,2.000,18.75,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(103,393,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(17,394,NULL,NULL,1.250,'2026-10-29 15:32:00','venda'),
(41,395,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(69,396,NULL,NULL,2.000,'2026-10-29 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(107,98,4,100.27);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(98,98,'NFCe','000098','1','90000000000000000000000000000000000000000098','2026-10-29 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 472.51 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=25 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(25,9,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(26,5,6,'2026-10-29 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(99,26,6,NULL,'2026-10-29 10:08:00',50.72,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(397,99,5,NULL,1.250,12.85,'ativo',NULL,NULL),
(398,99,16,NULL,1.000,8.88,'ativo',NULL,NULL),
(399,99,28,NULL,2.000,6.64,'ativo',NULL,NULL),
(400,99,42,NULL,1.000,12.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(9,397,NULL,NULL,1.250,'2026-10-29 10:08:00','venda'),
(31,398,NULL,NULL,1.000,'2026-10-29 10:08:00','venda'),
(55,399,NULL,NULL,2.000,'2026-10-29 10:08:00','venda'),
(83,400,NULL,NULL,1.000,'2026-10-29 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(108,99,5,50.72);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(99,99,'NFCe','000099','1','90000000000000000000000000000000000000000099','2026-10-29 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(100,26,6,NULL,'2026-10-29 11:56:00',129.09,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(401,100,12,NULL,1.000,24.96,'ativo',NULL,NULL),
(402,100,23,NULL,2.000,20.99,'ativo',NULL,NULL),
(403,100,35,NULL,1.000,18.75,'ativo',NULL,NULL),
(404,100,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(405,100,46,10,1.000,14.78,'cancelado','Item retirado antes da conclusao','2026-10-29 11:57:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(23,401,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(45,402,NULL,NULL,2.000,'2026-10-29 11:56:00','venda'),
(69,403,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(99,404,NULL,NULL,2.000,'2026-10-29 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(109,100,1,77.45),
(110,100,3,51.64);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(100,100,'SAT','000100','1','90000000000000000000000000000000000000000100','2026-10-29 11:57:00','emitido');

CALL cancelar_venda(100,10,'Cancelamento ficticio para teste','2026-10-29 12:01:00');


INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(101,26,6,NULL,'2026-10-29 13:43:59',67.94,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(406,101,19,NULL,2.000,14.07,'ativo',NULL,NULL),
(407,101,30,NULL,1.000,10.10,'ativo',NULL,NULL),
(408,101,42,NULL,2.000,12.50,'ativo',NULL,NULL),
(409,101,3,NULL,0.500,9.39,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(37,406,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(59,407,NULL,NULL,1.000,'2026-10-29 13:43:59','venda'),
(83,408,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(5,409,NULL,NULL,0.500,'2026-10-29 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(111,101,2,67.94);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(101,101,'NFCe','000101','1','90000000000000000000000000000000000000000101','2026-10-29 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(102,26,6,NULL,'2026-10-29 15:32:00',108.43,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(410,102,26,NULL,1.000,26.18,'ativo',NULL,NULL),
(411,102,37,NULL,2.000,22.21,'ativo',NULL,NULL),
(412,102,50,NULL,1.000,21.70,'ativo',NULL,NULL),
(413,102,10,NULL,0.750,21.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(51,410,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(73,411,NULL,NULL,2.000,'2026-10-29 15:32:00','venda'),
(99,412,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(19,413,NULL,NULL,0.750,'2026-10-29 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(112,102,3,108.43);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(102,102,'NFCe','000102','1','90000000000000000000000000000000000000000102','2026-10-29 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 427.09 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=26 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(26,10,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(27,6,7,'2026-10-29 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(103,27,7,NULL,'2026-10-29 10:08:00',59.55,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(414,103,33,NULL,2.000,15.29,'ativo',NULL,NULL),
(415,103,44,NULL,1.000,11.32,'ativo',NULL,NULL),
(416,103,3,NULL,0.750,9.39,'ativo',NULL,NULL),
(417,103,17,NULL,1.000,10.61,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(65,414,NULL,NULL,2.000,'2026-10-29 10:08:00','venda'),
(87,415,NULL,NULL,1.000,'2026-10-29 10:08:00','venda'),
(5,416,NULL,NULL,0.750,'2026-10-29 10:08:00','venda'),
(33,417,NULL,NULL,1.000,'2026-10-29 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(113,103,4,59.55);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(103,103,'NFCe','000103','1','90000000000000000000000000000000000000000103','2026-10-29 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(104,27,7,NULL,'2026-10-29 11:56:00',121.66,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(418,104,40,NULL,1.000,4.40,'ativo',NULL,NULL),
(419,104,52,NULL,2.000,25.16,'ativo',NULL,NULL),
(420,104,10,NULL,1.000,21.50,'ativo',NULL,NULL),
(421,104,24,NULL,2.000,22.72,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(79,418,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(103,419,NULL,NULL,2.000,'2026-10-29 11:56:00','venda'),
(19,420,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(47,421,NULL,NULL,2.000,'2026-10-29 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(114,104,5,121.66);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(104,104,'NFCe','000104','1','90000000000000000000000000000000000000000104','2026-10-29 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(105,27,7,NULL,'2026-10-29 13:43:59',73.59,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(422,105,47,NULL,2.000,16.51,'ativo',NULL,NULL),
(423,105,5,NULL,1.000,12.85,'ativo',NULL,NULL),
(424,105,17,NULL,2.000,10.61,'ativo',NULL,NULL),
(425,105,31,NULL,1.000,6.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(93,422,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(9,423,NULL,NULL,1.000,'2026-10-29 13:43:59','venda'),
(33,424,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(61,425,NULL,NULL,1.000,'2026-10-29 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(115,105,1,73.59);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(105,105,'NFCe','000105','1','90000000000000000000000000000000000000000105','2026-10-29 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(106,27,7,NULL,'2026-10-29 15:32:00',127.42,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(426,106,1,NULL,1.000,6.90,'ativo',NULL,NULL),
(427,106,12,NULL,2.000,24.96,'ativo',NULL,NULL),
(428,106,24,NULL,1.000,22.72,'ativo',NULL,NULL),
(429,106,38,NULL,2.000,23.94,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(1,426,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(23,427,NULL,NULL,2.000,'2026-10-29 15:32:00','venda'),
(47,428,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(75,429,NULL,NULL,2.000,'2026-10-29 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(116,106,2,127.42);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(106,106,'NFCe','000106','1','90000000000000000000000000000000000000000106','2026-10-29 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(9,27,9,'2026-10-29 13:00:00',90.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 517.22 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=27 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(27,9,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(28,7,8,'2026-10-29 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(107,28,8,NULL,'2026-10-29 10:08:00',62.67,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(430,107,8,NULL,1.250,18.04,'ativo',NULL,NULL),
(431,107,19,NULL,1.000,14.07,'ativo',NULL,NULL),
(432,107,31,NULL,2.000,6.50,'ativo',NULL,NULL),
(433,107,45,NULL,1.000,13.05,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(15,430,NULL,NULL,1.250,'2026-10-29 10:08:00','venda'),
(37,431,NULL,NULL,1.000,'2026-10-29 10:08:00','venda'),
(61,432,NULL,NULL,2.000,'2026-10-29 10:08:00','venda'),
(89,433,NULL,NULL,1.000,'2026-10-29 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(117,107,3,62.67);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(107,107,'NFCe','000107','1','90000000000000000000000000000000000000000107','2026-10-29 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(108,28,8,NULL,'2026-10-29 11:56:00',137.23,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(434,108,15,NULL,1.000,7.15,'ativo',NULL,NULL),
(435,108,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(436,108,38,NULL,1.000,23.94,'ativo',NULL,NULL),
(437,108,53,NULL,2.000,26.89,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(29,434,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(51,435,NULL,NULL,2.000,'2026-10-29 11:56:00','venda'),
(75,436,NULL,NULL,1.000,'2026-10-29 11:56:00','venda'),
(105,437,NULL,NULL,2.000,'2026-10-29 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(118,108,4,137.23);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(108,108,'NFCe','000108','1','90000000000000000000000000000000000000000108','2026-10-29 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(109,28,8,NULL,'2026-10-29 13:43:59',86.48,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(438,109,22,NULL,2.000,18.90,'ativo',NULL,NULL),
(439,109,33,NULL,1.000,15.29,'ativo',NULL,NULL),
(440,109,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(441,109,6,NULL,0.500,14.58,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(43,438,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(65,439,NULL,NULL,1.000,'2026-10-29 13:43:59','venda'),
(89,440,NULL,NULL,2.000,'2026-10-29 13:43:59','venda'),
(11,441,NULL,NULL,0.500,'2026-10-29 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(119,109,5,86.48);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(109,109,'NFCe','000109','1','90000000000000000000000000000000000000000109','2026-10-29 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(110,28,8,NULL,'2026-10-29 15:32:00',97.44,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(442,110,29,NULL,1.000,8.37,'ativo',NULL,NULL),
(443,110,40,NULL,2.000,4.40,'ativo',NULL,NULL),
(444,110,53,NULL,1.000,26.89,'ativo',NULL,NULL),
(445,110,13,NULL,2.000,26.69,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(57,442,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(79,443,NULL,NULL,2.000,'2026-10-29 15:32:00','venda'),
(105,444,NULL,NULL,1.000,'2026-10-29 15:32:00','venda'),
(25,445,NULL,NULL,2.000,'2026-10-29 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(120,110,1,58.46),
(121,110,3,38.98);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(110,110,'NFCe','000110','1','90000000000000000000000000000000000000000110','2026-10-29 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 533.82 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=28 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(28,10,'2026-10-29 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(29,1,1,'2026-10-30 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(111,29,1,NULL,'2026-10-30 09:50:00',84.21,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(446,111,36,NULL,2.000,20.48,'ativo',NULL,NULL),
(447,111,47,NULL,1.000,16.51,'ativo',NULL,NULL),
(448,111,6,NULL,0.750,14.58,'ativo',NULL,NULL),
(449,111,20,NULL,1.000,15.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(71,446,NULL,NULL,2.000,'2026-10-30 09:50:00','venda'),
(93,447,NULL,NULL,1.000,'2026-10-30 09:50:00','venda'),
(11,448,NULL,NULL,0.750,'2026-10-30 09:50:00','venda'),
(39,449,NULL,NULL,1.000,'2026-10-30 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(122,111,2,84.21);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(111,111,'NFCe','000111','1','90000000000000000000000000000000000000000111','2026-10-30 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(112,29,1,NULL,'2026-10-30 11:20:00',51.28,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(450,112,43,NULL,1.000,9.59,'ativo',NULL,NULL),
(451,112,1,NULL,0.750,6.90,'ativo',NULL,NULL),
(452,112,13,NULL,1.000,26.69,'ativo',NULL,NULL),
(453,112,27,NULL,2.000,4.91,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(85,450,NULL,NULL,1.000,'2026-10-30 11:20:00','venda'),
(1,451,NULL,NULL,0.750,'2026-10-30 11:20:00','venda'),
(25,452,NULL,NULL,1.000,'2026-10-30 11:20:00','venda'),
(53,453,NULL,NULL,2.000,'2026-10-30 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(123,112,3,51.28);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(112,112,'NFCe','000112','1','90000000000000000000000000000000000000000112','2026-10-30 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(113,29,1,NULL,'2026-10-30 12:50:00',122.46,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(454,113,51,NULL,2.000,27.90,'ativo',NULL,NULL),
(455,113,8,NULL,1.000,18.04,'ativo',NULL,NULL),
(456,113,20,NULL,2.000,15.80,'ativo',NULL,NULL),
(457,113,34,NULL,1.000,17.02,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(101,454,NULL,NULL,2.000,'2026-10-30 12:50:00','venda'),
(15,455,NULL,NULL,1.000,'2026-10-30 12:50:00','venda'),
(39,456,NULL,NULL,2.000,'2026-10-30 12:50:00','venda'),
(67,457,NULL,NULL,1.000,'2026-10-30 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(124,113,4,122.46);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(113,113,'NFCe','000113','1','90000000000000000000000000000000000000000113','2026-10-30 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(114,29,1,NULL,'2026-10-30 14:20:00',45.33,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(458,114,4,NULL,1.000,11.12,'ativo',NULL,NULL),
(459,114,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(460,114,27,NULL,1.000,4.91,'ativo',NULL,NULL),
(461,114,41,NULL,2.000,7.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(7,458,NULL,NULL,1.000,'2026-10-30 14:20:00','venda'),
(29,459,NULL,NULL,2.000,'2026-10-30 14:20:00','venda'),
(53,460,NULL,NULL,1.000,'2026-10-30 14:20:00','venda'),
(81,461,NULL,NULL,2.000,'2026-10-30 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(125,114,5,45.33);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(114,114,'NFCe','000114','1','90000000000000000000000000000000000000000114','2026-10-30 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(115,29,1,NULL,'2026-10-30 15:50:00',92.71,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(462,115,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(463,115,22,NULL,1.000,18.90,'ativo',NULL,NULL),
(464,115,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(465,115,49,NULL,1.000,19.97,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(21,462,NULL,NULL,2.000,'2026-10-30 15:50:00','venda'),
(43,463,NULL,NULL,1.000,'2026-10-30 15:50:00','venda'),
(67,464,NULL,NULL,2.000,'2026-10-30 15:50:00','venda'),
(97,465,NULL,NULL,1.000,'2026-10-30 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(126,115,1,92.71);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(115,115,'NFCe','000115','1','90000000000000000000000000000000000000000115','2026-10-30 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 570.99 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=29 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(29,9,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(30,2,2,'2026-10-30 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(116,30,2,NULL,'2026-10-30 09:50:00',47.21,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(466,116,18,NULL,1.000,12.34,'ativo',NULL,NULL),
(467,116,29,NULL,2.000,8.37,'ativo',NULL,NULL),
(468,116,41,NULL,1.000,7.50,'ativo',NULL,NULL),
(469,116,2,NULL,1.250,8.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(35,466,NULL,NULL,1.000,'2026-10-30 09:50:00','venda'),
(57,467,NULL,NULL,2.000,'2026-10-30 09:50:00','venda'),
(81,468,NULL,NULL,1.000,'2026-10-30 09:50:00','venda'),
(3,469,NULL,NULL,1.250,'2026-10-30 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(127,116,2,47.21);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(116,116,'NFCe','000116','1','90000000000000000000000000000000000000000116','2026-10-30 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(117,30,2,NULL,'2026-10-30 11:20:00',119.21,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(470,117,25,NULL,2.000,24.45,'ativo',NULL,NULL),
(471,117,36,NULL,1.000,20.48,'ativo',NULL,NULL),
(472,117,49,NULL,2.000,19.97,'ativo',NULL,NULL),
(473,117,9,NULL,0.500,19.77,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(49,470,NULL,NULL,2.000,'2026-10-30 11:20:00','venda'),
(71,471,NULL,NULL,1.000,'2026-10-30 11:20:00','venda'),
(97,472,NULL,NULL,2.000,'2026-10-30 11:20:00','venda'),
(17,473,NULL,NULL,0.500,'2026-10-30 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(128,117,3,119.21);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(117,117,'NFCe','000117','1','90000000000000000000000000000000000000000117','2026-10-30 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(118,30,2,NULL,'2026-10-30 12:50:00',45.99,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(474,118,32,NULL,1.000,4.80,'ativo',NULL,NULL),
(475,118,43,NULL,2.000,9.59,'ativo',NULL,NULL),
(476,118,2,NULL,0.500,8.50,'ativo',NULL,NULL),
(477,118,16,NULL,2.000,8.88,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(63,474,NULL,NULL,1.000,'2026-10-30 12:50:00','venda'),
(85,475,NULL,NULL,2.000,'2026-10-30 12:50:00','venda'),
(3,476,NULL,NULL,0.500,'2026-10-30 12:50:00','venda'),
(31,477,NULL,NULL,2.000,'2026-10-30 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(129,118,4,45.99);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(118,118,'NFCe','000118','1','90000000000000000000000000000000000000000118','2026-10-30 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(119,30,2,NULL,'2026-10-30 14:20:00',115.06,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(478,119,39,NULL,2.000,25.67,'ativo',NULL,NULL),
(479,119,51,NULL,1.000,27.90,'ativo',NULL,NULL),
(480,119,9,NULL,0.750,19.77,'ativo',NULL,NULL),
(481,119,23,NULL,1.000,20.99,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(77,478,NULL,NULL,2.000,'2026-10-30 14:20:00','venda'),
(101,479,NULL,NULL,1.000,'2026-10-30 14:20:00','venda'),
(17,480,NULL,NULL,0.750,'2026-10-30 14:20:00','venda'),
(45,481,NULL,NULL,1.000,'2026-10-30 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(130,119,5,115.06);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(119,119,'NFCe','000119','1','90000000000000000000000000000000000000000119','2026-10-30 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(120,30,2,NULL,'2026-10-30 15:50:00',52.20,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(482,120,46,NULL,1.000,14.78,'ativo',NULL,NULL),
(483,120,4,NULL,0.750,11.12,'ativo',NULL,NULL),
(484,120,16,NULL,1.000,8.88,'ativo',NULL,NULL),
(485,120,30,NULL,2.000,10.10,'ativo',NULL,NULL),
(486,120,2,10,0.500,8.50,'cancelado','Item retirado antes da conclusao','2026-10-30 15:51:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(91,482,NULL,NULL,1.000,'2026-10-30 15:50:00','venda'),
(7,483,NULL,NULL,0.750,'2026-10-30 15:50:00','venda'),
(31,484,NULL,NULL,1.000,'2026-10-30 15:50:00','venda'),
(59,485,NULL,NULL,2.000,'2026-10-30 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(131,120,1,31.32),
(132,120,3,20.88);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(120,120,'SAT','000120','1','90000000000000000000000000000000000000000120','2026-10-30 15:51:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(10,30,10,'2026-10-30 13:00:00',80.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 501.67 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=30 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(30,10,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(31,3,3,'2026-10-30 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(121,31,3,NULL,'2026-10-30 09:50:00',85.33,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(487,121,54,NULL,2.000,5.62,'ativo',NULL,NULL),
(488,121,11,NULL,1.000,9.90,'ativo',NULL,NULL),
(489,121,23,NULL,2.000,20.99,'ativo',NULL,NULL),
(490,121,37,NULL,1.000,22.21,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(107,487,NULL,NULL,2.000,'2026-10-30 09:50:00','venda'),
(21,488,NULL,NULL,1.000,'2026-10-30 09:50:00','venda'),
(45,489,NULL,NULL,2.000,'2026-10-30 09:50:00','venda'),
(73,490,NULL,NULL,1.000,'2026-10-30 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(133,121,2,85.33);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(121,121,'NFCe','000121','1','90000000000000000000000000000000000000000121','2026-10-30 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(122,31,3,NULL,'2026-10-30 11:20:00',73.73,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(491,122,7,NULL,1.000,16.31,'ativo',NULL,NULL),
(492,122,18,NULL,2.000,12.34,'ativo',NULL,NULL),
(493,122,30,NULL,1.000,10.10,'ativo',NULL,NULL),
(494,122,44,NULL,2.000,11.32,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(13,491,NULL,NULL,1.000,'2026-10-30 11:20:00','venda'),
(35,492,NULL,NULL,2.000,'2026-10-30 11:20:00','venda'),
(59,493,NULL,NULL,1.000,'2026-10-30 11:20:00','venda'),
(87,494,NULL,NULL,2.000,'2026-10-30 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(134,122,3,73.73);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(122,122,'NFCe','000122','1','90000000000000000000000000000000000000000122','2026-10-30 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(123,31,3,NULL,'2026-10-30 12:50:00',104.87,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(495,123,14,NULL,2.000,5.42,'ativo',NULL,NULL),
(496,123,25,NULL,1.000,24.45,'ativo',NULL,NULL),
(497,123,37,NULL,2.000,22.21,'ativo',NULL,NULL),
(498,123,52,NULL,1.000,25.16,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(27,495,NULL,NULL,2.000,'2026-10-30 12:50:00','venda'),
(49,496,NULL,NULL,1.000,'2026-10-30 12:50:00','venda'),
(73,497,NULL,NULL,2.000,'2026-10-30 12:50:00','venda'),
(103,498,NULL,NULL,1.000,'2026-10-30 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(135,123,4,104.87);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(123,123,'NFCe','000123','1','90000000000000000000000000000000000000000123','2026-10-30 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(124,31,3,NULL,'2026-10-30 14:20:00',49.88,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(499,124,21,NULL,1.000,12.90,'ativo',NULL,NULL),
(500,124,32,NULL,2.000,4.80,'ativo',NULL,NULL),
(501,124,44,NULL,1.000,11.32,'ativo',NULL,NULL),
(502,124,5,NULL,1.250,12.85,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(41,499,NULL,NULL,1.000,'2026-10-30 14:20:00','venda'),
(63,500,NULL,NULL,2.000,'2026-10-30 14:20:00','venda'),
(87,501,NULL,NULL,1.000,'2026-10-30 14:20:00','venda'),
(9,502,NULL,NULL,1.250,'2026-10-30 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(136,124,5,49.88);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(124,124,'NFCe','000124','1','90000000000000000000000000000000000000000124','2026-10-30 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(125,31,3,NULL,'2026-10-30 15:50:00',114.23,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(503,125,28,NULL,2.000,6.64,'ativo',NULL,NULL),
(504,125,39,NULL,1.000,25.67,'ativo',NULL,NULL),
(505,125,52,NULL,2.000,25.16,'ativo',NULL,NULL),
(506,125,12,NULL,1.000,24.96,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(55,503,NULL,NULL,2.000,'2026-10-30 15:50:00','venda'),
(77,504,NULL,NULL,1.000,'2026-10-30 15:50:00','venda'),
(103,505,NULL,NULL,2.000,'2026-10-30 15:50:00','venda'),
(23,506,NULL,NULL,1.000,'2026-10-30 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(137,125,1,114.23);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(125,125,'NFCe','000125','1','90000000000000000000000000000000000000000125','2026-10-30 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 653.04 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=31 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(31,9,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(32,4,4,'2026-10-30 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(126,32,4,NULL,'2026-10-30 09:50:00',82.88,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(507,126,35,NULL,1.000,18.75,'ativo',NULL,NULL),
(508,126,46,NULL,2.000,14.78,'ativo',NULL,NULL),
(509,126,5,NULL,0.500,12.85,'ativo',NULL,NULL),
(510,126,19,NULL,2.000,14.07,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(69,507,NULL,NULL,1.000,'2026-10-30 09:50:00','venda'),
(91,508,NULL,NULL,2.000,'2026-10-30 09:50:00','venda'),
(9,509,NULL,NULL,0.500,'2026-10-30 09:50:00','venda'),
(37,510,NULL,NULL,2.000,'2026-10-30 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(138,126,2,82.88);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(126,126,'NFCe','000126','1','90000000000000000000000000000000000000000126','2026-10-30 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(127,32,4,NULL,'2026-10-30 11:20:00',106.72,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(511,127,42,NULL,2.000,12.50,'ativo',NULL,NULL),
(512,127,54,NULL,1.000,5.62,'ativo',NULL,NULL),
(513,127,12,NULL,2.000,24.96,'ativo',NULL,NULL),
(514,127,26,NULL,1.000,26.18,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(83,511,NULL,NULL,2.000,'2026-10-30 11:20:00','venda'),
(107,512,NULL,NULL,1.000,'2026-10-30 11:20:00','venda'),
(23,513,NULL,NULL,2.000,'2026-10-30 11:20:00','venda'),
(51,514,NULL,NULL,1.000,'2026-10-30 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(139,127,3,106.72);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(127,127,'NFCe','000127','1','90000000000000000000000000000000000000000127','2026-10-30 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(128,32,4,NULL,'2026-10-30 12:50:00',78.58,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(515,128,50,NULL,1.000,21.70,'ativo',NULL,NULL),
(516,128,7,NULL,0.750,16.31,'ativo',NULL,NULL),
(517,128,19,NULL,1.000,14.07,'ativo',NULL,NULL),
(518,128,33,NULL,2.000,15.29,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(99,515,NULL,NULL,1.000,'2026-10-30 12:50:00','venda'),
(13,516,NULL,NULL,0.750,'2026-10-30 12:50:00','venda'),
(37,517,NULL,NULL,1.000,'2026-10-30 12:50:00','venda'),
(65,518,NULL,NULL,2.000,'2026-10-30 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(140,128,4,78.58);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(128,128,'NFCe','000128','1','90000000000000000000000000000000000000000128','2026-10-30 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(129,32,4,NULL,'2026-10-30 14:20:00',69.22,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(519,129,3,NULL,0.750,9.39,'ativo',NULL,NULL),
(520,129,14,NULL,1.000,5.42,'ativo',NULL,NULL),
(521,129,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(522,129,40,NULL,1.000,4.40,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(5,519,NULL,NULL,0.750,'2026-10-30 14:20:00','venda'),
(27,520,NULL,NULL,1.000,'2026-10-30 14:20:00','venda'),
(51,521,NULL,NULL,2.000,'2026-10-30 14:20:00','venda'),
(79,522,NULL,NULL,1.000,'2026-10-30 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(141,129,5,69.22);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(129,129,'NFCe','000129','1','90000000000000000000000000000000000000000129','2026-10-30 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(130,32,4,NULL,'2026-10-30 15:50:00',95.61,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(523,130,10,NULL,1.000,21.50,'ativo',NULL,NULL),
(524,130,21,NULL,2.000,12.90,'ativo',NULL,NULL),
(525,130,33,NULL,1.000,15.29,'ativo',NULL,NULL),
(526,130,47,NULL,2.000,16.51,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(19,523,NULL,NULL,1.000,'2026-10-30 15:50:00','venda'),
(41,524,NULL,NULL,2.000,'2026-10-30 15:50:00','venda'),
(65,525,NULL,NULL,1.000,'2026-10-30 15:50:00','venda'),
(93,526,NULL,NULL,2.000,'2026-10-30 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(142,130,1,57.37),
(143,130,3,38.24);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(130,130,'NFCe','000130','1','90000000000000000000000000000000000000000130','2026-10-30 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 583.01 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=32 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(32,10,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(33,5,6,'2026-10-30 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(131,33,6,NULL,'2026-10-30 10:08:00',43.56,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(527,131,17,NULL,2.000,10.61,'ativo',NULL,NULL),
(528,131,28,NULL,1.000,6.64,'ativo',NULL,NULL),
(529,131,40,NULL,2.000,4.40,'ativo',NULL,NULL),
(530,131,1,NULL,1.000,6.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(33,527,NULL,NULL,2.000,'2026-10-30 10:08:00','venda'),
(55,528,NULL,NULL,1.000,'2026-10-30 10:08:00','venda'),
(79,529,NULL,NULL,2.000,'2026-10-30 10:08:00','venda'),
(1,530,NULL,NULL,1.000,'2026-10-30 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(144,131,2,43.56);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(131,131,'NFCe','000131','1','90000000000000000000000000000000000000000131','2026-10-30 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(132,33,6,NULL,'2026-10-30 11:56:00',99.28,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(531,132,24,NULL,1.000,22.72,'ativo',NULL,NULL),
(532,132,35,NULL,2.000,18.75,'ativo',NULL,NULL),
(533,132,47,NULL,1.000,16.51,'ativo',NULL,NULL),
(534,132,8,NULL,1.250,18.04,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(47,531,NULL,NULL,1.000,'2026-10-30 11:56:00','venda'),
(69,532,NULL,NULL,2.000,'2026-10-30 11:56:00','venda'),
(93,533,NULL,NULL,1.000,'2026-10-30 11:56:00','venda'),
(15,534,NULL,NULL,1.250,'2026-10-30 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(145,132,3,99.28);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(132,132,'NFCe','000132','1','90000000000000000000000000000000000000000132','2026-10-30 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(133,33,6,NULL,'2026-10-30 13:43:59',41.28,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(535,133,31,NULL,2.000,6.50,'ativo',NULL,NULL),
(536,133,42,NULL,1.000,12.50,'ativo',NULL,NULL),
(537,133,1,NULL,1.250,6.90,'ativo',NULL,NULL),
(538,133,15,NULL,1.000,7.15,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(61,535,NULL,NULL,2.000,'2026-10-30 13:43:59','venda'),
(83,536,NULL,NULL,1.000,'2026-10-30 13:43:59','venda'),
(1,537,NULL,NULL,1.250,'2026-10-30 13:43:59','venda'),
(29,538,NULL,NULL,1.000,'2026-10-30 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(146,133,4,41.28);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(133,133,'NFCe','000133','1','90000000000000000000000000000000000000000133','2026-10-30 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(134,33,6,NULL,'2026-10-30 15:32:00',114.16,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(539,134,38,NULL,1.000,23.94,'ativo',NULL,NULL),
(540,134,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(541,134,8,NULL,0.500,18.04,'ativo',NULL,NULL),
(542,134,22,NULL,2.000,18.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(75,539,NULL,NULL,1.000,'2026-10-30 15:32:00','venda'),
(99,540,NULL,NULL,2.000,'2026-10-30 15:32:00','venda'),
(15,541,NULL,NULL,0.500,'2026-10-30 15:32:00','venda'),
(43,542,NULL,NULL,2.000,'2026-10-30 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(147,134,5,114.16);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(134,134,'NFCe','000134','1','90000000000000000000000000000000000000000134','2026-10-30 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(11,33,9,'2026-10-30 13:00:00',70.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 403.28 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=33 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(33,9,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(34,6,7,'2026-10-30 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(135,34,7,NULL,'2026-10-30 10:08:00',53.47,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(543,135,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(544,135,3,NULL,0.500,9.39,'ativo',NULL,NULL),
(545,135,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(546,135,29,NULL,1.000,8.37,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(89,543,NULL,NULL,2.000,'2026-10-30 10:08:00','venda'),
(5,544,NULL,NULL,0.500,'2026-10-30 10:08:00','venda'),
(29,545,NULL,NULL,2.000,'2026-10-30 10:08:00','venda'),
(57,546,NULL,NULL,1.000,'2026-10-30 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(148,135,1,53.47);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(135,135,'NFCe','000135','1','90000000000000000000000000000000000000000135','2026-10-30 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(136,34,7,NULL,'2026-10-30 11:56:00',102.88,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(547,136,53,NULL,1.000,26.89,'ativo',NULL,NULL),
(548,136,10,NULL,0.750,21.50,'ativo',NULL,NULL),
(549,136,22,NULL,1.000,18.90,'ativo',NULL,NULL),
(550,136,36,NULL,2.000,20.48,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(105,547,NULL,NULL,1.000,'2026-10-30 11:56:00','venda'),
(19,548,NULL,NULL,0.750,'2026-10-30 11:56:00','venda'),
(43,549,NULL,NULL,1.000,'2026-10-30 11:56:00','venda'),
(71,550,NULL,NULL,2.000,'2026-10-30 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(149,136,2,102.88);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(136,136,'NFCe','000136','1','90000000000000000000000000000000000000000136','2026-10-30 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(137,34,7,NULL,'2026-10-30 13:43:59',47.88,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(551,137,6,NULL,0.750,14.58,'ativo',NULL,NULL),
(552,137,17,NULL,1.000,10.61,'ativo',NULL,NULL),
(553,137,29,NULL,2.000,8.37,'ativo',NULL,NULL),
(554,137,43,NULL,1.000,9.59,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(11,551,NULL,NULL,0.750,'2026-10-30 13:43:59','venda'),
(33,552,NULL,NULL,1.000,'2026-10-30 13:43:59','venda'),
(57,553,NULL,NULL,2.000,'2026-10-30 13:43:59','venda'),
(85,554,NULL,NULL,1.000,'2026-10-30 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(150,137,3,47.88);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(137,137,'NFCe','000137','1','90000000000000000000000000000000000000000137','2026-10-30 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(138,34,7,NULL,'2026-10-30 15:32:00',148.41,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(555,138,13,NULL,1.000,26.69,'ativo',NULL,NULL),
(556,138,24,NULL,2.000,22.72,'ativo',NULL,NULL),
(557,138,36,NULL,1.000,20.48,'ativo',NULL,NULL),
(558,138,51,NULL,2.000,27.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(25,555,NULL,NULL,1.000,'2026-10-30 15:32:00','venda'),
(47,556,NULL,NULL,2.000,'2026-10-30 15:32:00','venda'),
(71,557,NULL,NULL,1.000,'2026-10-30 15:32:00','venda'),
(101,558,NULL,NULL,2.000,'2026-10-30 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(151,138,4,148.41);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(138,138,'NFCe','000138','1','90000000000000000000000000000000000000000138','2026-10-30 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 552.64 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=34 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(34,10,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(35,7,8,'2026-10-30 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(139,35,8,NULL,'2026-10-30 10:08:00',68.40,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(559,139,20,NULL,2.000,15.80,'ativo',NULL,NULL),
(560,139,31,NULL,1.000,6.50,'ativo',NULL,NULL),
(561,139,43,NULL,2.000,9.59,'ativo',NULL,NULL),
(562,139,4,NULL,1.000,11.12,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(39,559,NULL,NULL,2.000,'2026-10-30 10:08:00','venda'),
(61,560,NULL,NULL,1.000,'2026-10-30 10:08:00','venda'),
(85,561,NULL,NULL,2.000,'2026-10-30 10:08:00','venda'),
(7,562,NULL,NULL,1.000,'2026-10-30 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(152,139,5,68.40);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(139,139,'NFCe','000139','1','90000000000000000000000000000000000000000139','2026-10-30 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(140,35,8,NULL,'2026-10-30 11:56:00',100.49,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(563,140,27,NULL,1.000,4.91,'ativo',NULL,NULL),
(564,140,38,NULL,2.000,23.94,'ativo',NULL,NULL),
(565,140,51,NULL,1.000,27.90,'ativo',NULL,NULL),
(566,140,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(567,140,11,9,1.000,9.90,'cancelado','Item retirado antes da conclusao','2026-10-30 11:57:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(53,563,NULL,NULL,1.000,'2026-10-30 11:56:00','venda'),
(75,564,NULL,NULL,2.000,'2026-10-30 11:56:00','venda'),
(101,565,NULL,NULL,1.000,'2026-10-30 11:56:00','venda'),
(21,566,NULL,NULL,2.000,'2026-10-30 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(153,140,1,60.29),
(154,140,3,40.20);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(140,140,'SAT','000140','1','90000000000000000000000000000000000000000140','2026-10-30 11:57:00','emitido');

INSERT INTO TROCA_OPERADOR (id_troca,id_sessao,id_funcionario_anterior,id_funcionario_novo,data_hora) VALUES
(4,35,8,9,'2026-10-30 13:42:59');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(141,35,9,NULL,'2026-10-30 13:43:59',73.33,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(568,141,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(569,141,45,NULL,1.000,13.05,'ativo',NULL,NULL),
(570,141,4,NULL,1.250,11.12,'ativo',NULL,NULL),
(571,141,18,NULL,1.000,12.34,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(67,568,NULL,NULL,2.000,'2026-10-30 13:43:59','venda'),
(89,569,NULL,NULL,1.000,'2026-10-30 13:43:59','venda'),
(7,570,NULL,NULL,1.250,'2026-10-30 13:43:59','venda'),
(35,571,NULL,NULL,1.000,'2026-10-30 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(155,141,2,73.33);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(141,141,'NFCe','000141','1','90000000000000000000000000000000000000000141','2026-10-30 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(142,35,9,NULL,'2026-10-30 15:32:00',120.08,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(572,142,41,NULL,1.000,7.50,'ativo',NULL,NULL),
(573,142,53,NULL,2.000,26.89,'ativo',NULL,NULL),
(574,142,11,NULL,1.000,9.90,'ativo',NULL,NULL),
(575,142,25,NULL,2.000,24.45,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(81,572,NULL,NULL,1.000,'2026-10-30 15:32:00','venda'),
(105,573,NULL,NULL,2.000,'2026-10-30 15:32:00','venda'),
(21,574,NULL,NULL,1.000,'2026-10-30 15:32:00','venda'),
(49,575,NULL,NULL,2.000,'2026-10-30 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(156,142,3,120.08);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(142,142,'NFCe','000142','1','90000000000000000000000000000000000000000142','2026-10-30 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 587.30 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=35 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(35,9,'2026-10-30 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(36,1,1,'2026-10-31 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(143,36,1,NULL,'2026-10-31 09:50:00',76.71,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(576,143,49,NULL,2.000,19.97,'ativo',NULL,NULL),
(577,143,6,NULL,0.500,14.58,'ativo',NULL,NULL),
(578,143,18,NULL,2.000,12.34,'ativo',NULL,NULL),
(579,143,32,NULL,1.000,4.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(97,576,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(11,577,NULL,NULL,0.500,'2026-10-31 09:50:00','venda'),
(35,578,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(63,579,NULL,NULL,1.000,'2026-10-31 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(157,143,4,76.71);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(143,143,'NFCe','000143','1','90000000000000000000000000000000000000000143','2026-10-31 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(144,36,1,NULL,'2026-10-31 11:20:00',133.42,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(580,144,2,NULL,0.500,8.50,'ativo',NULL,NULL),
(581,144,13,NULL,2.000,26.69,'ativo',NULL,NULL),
(582,144,25,NULL,1.000,24.45,'ativo',NULL,NULL),
(583,144,39,NULL,2.000,25.67,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(3,580,NULL,NULL,0.500,'2026-10-31 11:20:00','venda'),
(25,581,NULL,NULL,2.000,'2026-10-31 11:20:00','venda'),
(49,582,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(77,583,NULL,NULL,2.000,'2026-10-31 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(158,144,5,133.42);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(144,144,'NFCe','000144','1','90000000000000000000000000000000000000000144','2026-10-31 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(145,36,1,NULL,'2026-10-31 12:50:00',55.01,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(584,145,9,NULL,0.750,19.77,'ativo',NULL,NULL),
(585,145,20,NULL,1.000,15.80,'ativo',NULL,NULL),
(586,145,32,NULL,2.000,4.80,'ativo',NULL,NULL),
(587,145,46,NULL,1.000,14.78,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(17,584,NULL,NULL,0.750,'2026-10-31 12:50:00','venda'),
(39,585,NULL,NULL,1.000,'2026-10-31 12:50:00','venda'),
(63,586,NULL,NULL,2.000,'2026-10-31 12:50:00','venda'),
(91,587,NULL,NULL,1.000,'2026-10-31 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(159,145,1,55.01);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(145,145,'NFCe','000145','1','90000000000000000000000000000000000000000145','2026-10-31 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(146,36,1,NULL,'2026-10-31 14:20:00',55.61,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(588,146,16,NULL,1.000,8.88,'ativo',NULL,NULL),
(589,146,27,NULL,2.000,4.91,'ativo',NULL,NULL),
(590,146,39,NULL,1.000,25.67,'ativo',NULL,NULL),
(591,146,54,NULL,2.000,5.62,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(31,588,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(53,589,NULL,NULL,2.000,'2026-10-31 14:20:00','venda'),
(77,590,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(107,591,NULL,NULL,2.000,'2026-10-31 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(160,146,2,55.61);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(146,146,'NFCe','000146','1','90000000000000000000000000000000000000000146','2026-10-31 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(147,36,1,NULL,'2026-10-31 15:50:00',104.87,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(592,147,23,NULL,2.000,20.99,'ativo',NULL,NULL),
(593,147,34,NULL,1.000,17.02,'ativo',NULL,NULL),
(594,147,46,NULL,2.000,14.78,'ativo',NULL,NULL),
(595,147,7,NULL,1.000,16.31,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(45,592,NULL,NULL,2.000,'2026-10-31 15:50:00','venda'),
(67,593,NULL,NULL,1.000,'2026-10-31 15:50:00','venda'),
(91,594,NULL,NULL,2.000,'2026-10-31 15:50:00','venda'),
(13,595,NULL,NULL,1.000,'2026-10-31 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(161,147,3,104.87);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(147,147,'NFCe','000147','1','90000000000000000000000000000000000000000147','2026-10-31 15:51:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(12,36,10,'2026-10-31 13:00:00',60.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 515.62 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=36 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(36,10,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(37,2,2,'2026-10-31 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(148,37,2,NULL,'2026-10-31 09:50:00',41.56,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(596,148,30,NULL,1.000,10.10,'ativo',NULL,NULL),
(597,148,41,NULL,2.000,7.50,'ativo',NULL,NULL),
(598,148,54,NULL,1.000,5.62,'ativo',NULL,NULL),
(599,148,14,NULL,2.000,5.42,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(59,596,NULL,NULL,1.000,'2026-10-31 09:50:00','venda'),
(81,597,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(107,598,NULL,NULL,1.000,'2026-10-31 09:50:00','venda'),
(27,599,NULL,NULL,2.000,'2026-10-31 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(162,148,4,41.56);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(148,148,'NFCe','000148','1','90000000000000000000000000000000000000000148','2026-10-31 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(149,37,2,NULL,'2026-10-31 11:20:00',97.68,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(600,149,37,NULL,2.000,22.21,'ativo',NULL,NULL),
(601,149,49,NULL,1.000,19.97,'ativo',NULL,NULL),
(602,149,7,NULL,1.250,16.31,'ativo',NULL,NULL),
(603,149,21,NULL,1.000,12.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(73,600,NULL,NULL,2.000,'2026-10-31 11:20:00','venda'),
(97,601,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(13,602,NULL,NULL,1.250,'2026-10-31 11:20:00','venda'),
(41,603,NULL,NULL,1.000,'2026-10-31 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(163,149,5,97.68);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(149,149,'NFCe','000149','1','90000000000000000000000000000000000000000149','2026-10-31 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(150,37,2,NULL,'2026-10-31 12:50:00',40.65,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(604,150,44,NULL,1.000,11.32,'ativo',NULL,NULL),
(605,150,2,NULL,1.250,8.50,'ativo',NULL,NULL),
(606,150,14,NULL,1.000,5.42,'ativo',NULL,NULL),
(607,150,28,NULL,2.000,6.64,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(87,604,NULL,NULL,1.000,'2026-10-31 12:50:00','venda'),
(3,605,NULL,NULL,1.250,'2026-10-31 12:50:00','venda'),
(27,606,NULL,NULL,1.000,'2026-10-31 12:50:00','venda'),
(55,607,NULL,NULL,2.000,'2026-10-31 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(164,150,1,24.39),
(165,150,3,16.26);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(150,150,'NFCe','000150','1','90000000000000000000000000000000000000000150','2026-10-31 12:51:00','emitido');

CALL cancelar_venda(150,9,'Cancelamento ficticio para teste','2026-10-31 12:55:00');


INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(151,37,2,NULL,'2026-10-31 14:20:00',104.76,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(608,151,52,NULL,2.000,25.16,'ativo',NULL,NULL),
(609,151,9,NULL,0.500,19.77,'ativo',NULL,NULL),
(610,151,21,NULL,2.000,12.90,'ativo',NULL,NULL),
(611,151,35,NULL,1.000,18.75,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(103,608,NULL,NULL,2.000,'2026-10-31 14:20:00','venda'),
(17,609,NULL,NULL,0.500,'2026-10-31 14:20:00','venda'),
(41,610,NULL,NULL,2.000,'2026-10-31 14:20:00','venda'),
(69,611,NULL,NULL,1.000,'2026-10-31 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(166,151,2,104.76);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(151,151,'NFCe','000151','1','90000000000000000000000000000000000000000151','2026-10-31 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(152,37,2,NULL,'2026-10-31 15:50:00',55.83,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(612,152,5,NULL,0.500,12.85,'ativo',NULL,NULL),
(613,152,16,NULL,2.000,8.88,'ativo',NULL,NULL),
(614,152,28,NULL,1.000,6.64,'ativo',NULL,NULL),
(615,152,42,NULL,2.000,12.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(9,612,NULL,NULL,0.500,'2026-10-31 15:50:00','venda'),
(31,613,NULL,NULL,2.000,'2026-10-31 15:50:00','venda'),
(55,614,NULL,NULL,1.000,'2026-10-31 15:50:00','venda'),
(83,615,NULL,NULL,2.000,'2026-10-31 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(167,152,3,55.83);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(152,152,'NFCe','000152','1','90000000000000000000000000000000000000000152','2026-10-31 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 474.83 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=37 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(37,9,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(38,3,3,'2026-10-31 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(153,38,3,NULL,'2026-10-31 09:50:00',130.11,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(616,153,12,NULL,2.000,24.96,'ativo',NULL,NULL),
(617,153,23,NULL,1.000,20.99,'ativo',NULL,NULL),
(618,153,35,NULL,2.000,18.75,'ativo',NULL,NULL),
(619,153,50,NULL,1.000,21.70,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(23,616,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(45,617,NULL,NULL,1.000,'2026-10-31 09:50:00','venda'),
(69,618,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(99,619,NULL,NULL,1.000,'2026-10-31 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(168,153,4,130.11);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(153,153,'NFCe','000153','1','90000000000000000000000000000000000000000153','2026-10-31 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(154,38,3,NULL,'2026-10-31 11:20:00',53.81,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(620,154,19,NULL,1.000,14.07,'ativo',NULL,NULL),
(621,154,30,NULL,2.000,10.10,'ativo',NULL,NULL),
(622,154,42,NULL,1.000,12.50,'ativo',NULL,NULL),
(623,154,3,NULL,0.750,9.39,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(37,620,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(59,621,NULL,NULL,2.000,'2026-10-31 11:20:00','venda'),
(83,622,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(5,623,NULL,NULL,0.750,'2026-10-31 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(169,154,5,53.81);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(154,154,'NFCe','000154','1','90000000000000000000000000000000000000000154','2026-10-31 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(155,38,3,NULL,'2026-10-31 12:50:00',139.47,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(624,155,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(625,155,37,NULL,1.000,22.21,'ativo',NULL,NULL),
(626,155,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(627,155,10,NULL,1.000,21.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(51,624,NULL,NULL,2.000,'2026-10-31 12:50:00','venda'),
(73,625,NULL,NULL,1.000,'2026-10-31 12:50:00','venda'),
(99,626,NULL,NULL,2.000,'2026-10-31 12:50:00','venda'),
(19,627,NULL,NULL,1.000,'2026-10-31 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(170,155,1,139.47);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(155,155,'NFCe','000155','1','90000000000000000000000000000000000000000155','2026-10-31 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(156,38,3,NULL,'2026-10-31 14:20:00',68.54,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(628,156,33,NULL,1.000,15.29,'ativo',NULL,NULL),
(629,156,44,NULL,2.000,11.32,'ativo',NULL,NULL),
(630,156,3,NULL,1.000,9.39,'ativo',NULL,NULL),
(631,156,17,NULL,2.000,10.61,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(65,628,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(87,629,NULL,NULL,2.000,'2026-10-31 14:20:00','venda'),
(5,630,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(33,631,NULL,NULL,2.000,'2026-10-31 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(171,156,2,68.54);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(156,156,'NFCe','000156','1','90000000000000000000000000000000000000000156','2026-10-31 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(157,38,3,NULL,'2026-10-31 15:50:00',83.56,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(632,157,40,NULL,2.000,4.40,'ativo',NULL,NULL),
(633,157,52,NULL,1.000,25.16,'ativo',NULL,NULL),
(634,157,10,NULL,1.250,21.50,'ativo',NULL,NULL),
(635,157,24,NULL,1.000,22.72,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(79,632,NULL,NULL,2.000,'2026-10-31 15:50:00','venda'),
(103,633,NULL,NULL,1.000,'2026-10-31 15:50:00','venda'),
(19,634,NULL,NULL,1.250,'2026-10-31 15:50:00','venda'),
(47,635,NULL,NULL,1.000,'2026-10-31 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(172,157,3,83.56);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(157,157,'NFCe','000157','1','90000000000000000000000000000000000000000157','2026-10-31 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 675.49 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=38 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(38,10,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(39,4,4,'2026-10-31 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(158,39,4,NULL,'2026-10-31 09:50:00',56.18,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(636,158,47,NULL,1.000,16.51,'ativo',NULL,NULL),
(637,158,5,NULL,1.250,12.85,'ativo',NULL,NULL),
(638,158,17,NULL,1.000,10.61,'ativo',NULL,NULL),
(639,158,31,NULL,2.000,6.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(93,636,NULL,NULL,1.000,'2026-10-31 09:50:00','venda'),
(9,637,NULL,NULL,1.250,'2026-10-31 09:50:00','venda'),
(33,638,NULL,NULL,1.000,'2026-10-31 09:50:00','venda'),
(61,639,NULL,NULL,2.000,'2026-10-31 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(173,158,4,56.18);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(158,158,'NFCe','000158','1','90000000000000000000000000000000000000000158','2026-10-31 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(159,39,4,NULL,'2026-10-31 11:20:00',102.97,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(640,159,1,NULL,1.250,6.90,'ativo',NULL,NULL),
(641,159,12,NULL,1.000,24.96,'ativo',NULL,NULL),
(642,159,24,NULL,2.000,22.72,'ativo',NULL,NULL),
(643,159,38,NULL,1.000,23.94,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(1,640,NULL,NULL,1.250,'2026-10-31 11:20:00','venda'),
(23,641,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(47,642,NULL,NULL,2.000,'2026-10-31 11:20:00','venda'),
(75,643,NULL,NULL,1.000,'2026-10-31 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(174,159,5,102.97);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(159,159,'NFCe','000159','1','90000000000000000000000000000000000000000159','2026-10-31 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(160,39,4,NULL,'2026-10-31 12:50:00',69.76,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(644,160,8,NULL,0.500,18.04,'ativo',NULL,NULL),
(645,160,19,NULL,2.000,14.07,'ativo',NULL,NULL),
(646,160,31,NULL,1.000,6.50,'ativo',NULL,NULL),
(647,160,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(648,160,20,9,1.000,15.80,'cancelado','Item retirado antes da conclusao','2026-10-31 12:51:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(15,644,NULL,NULL,0.500,'2026-10-31 12:50:00','venda'),
(37,645,NULL,NULL,2.000,'2026-10-31 12:50:00','venda'),
(61,646,NULL,NULL,1.000,'2026-10-31 12:50:00','venda'),
(89,647,NULL,NULL,2.000,'2026-10-31 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(175,160,1,41.86),
(176,160,3,27.90);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(160,160,'SAT','000160','1','90000000000000000000000000000000000000000160','2026-10-31 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(161,39,4,NULL,'2026-10-31 14:20:00',115.25,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(649,161,15,NULL,2.000,7.15,'ativo',NULL,NULL),
(650,161,26,NULL,1.000,26.18,'ativo',NULL,NULL),
(651,161,38,NULL,2.000,23.94,'ativo',NULL,NULL),
(652,161,53,NULL,1.000,26.89,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(29,649,NULL,NULL,2.000,'2026-10-31 14:20:00','venda'),
(51,650,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(75,651,NULL,NULL,2.000,'2026-10-31 14:20:00','venda'),
(105,652,NULL,NULL,1.000,'2026-10-31 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(177,161,2,115.25);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(161,161,'NFCe','000161','1','90000000000000000000000000000000000000000161','2026-10-31 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(162,39,4,NULL,'2026-10-31 15:50:00',73.47,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(653,162,22,NULL,1.000,18.90,'ativo',NULL,NULL),
(654,162,33,NULL,2.000,15.29,'ativo',NULL,NULL),
(655,162,45,NULL,1.000,13.05,'ativo',NULL,NULL),
(656,162,6,NULL,0.750,14.58,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(43,653,NULL,NULL,1.000,'2026-10-31 15:50:00','venda'),
(65,654,NULL,NULL,2.000,'2026-10-31 15:50:00','venda'),
(89,655,NULL,NULL,1.000,'2026-10-31 15:50:00','venda'),
(11,656,NULL,NULL,0.750,'2026-10-31 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(178,162,3,73.47);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(162,162,'NFCe','000162','1','90000000000000000000000000000000000000000162','2026-10-31 15:51:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(13,39,9,'2026-10-31 13:00:00',90.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 552.63 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=39 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(39,9,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(40,5,5,'2026-10-31 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(163,40,5,NULL,'2026-10-31 09:50:00',101.61,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(657,163,29,NULL,2.000,8.37,'ativo',NULL,NULL),
(658,163,40,NULL,1.000,4.40,'ativo',NULL,NULL),
(659,163,53,NULL,2.000,26.89,'ativo',NULL,NULL),
(660,163,13,NULL,1.000,26.69,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(57,657,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(79,658,NULL,NULL,1.000,'2026-10-31 09:50:00','venda'),
(105,659,NULL,NULL,2.000,'2026-10-31 09:50:00','venda'),
(25,660,NULL,NULL,1.000,'2026-10-31 09:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(179,163,4,101.61);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(163,163,'NFCe','000163','1','90000000000000000000000000000000000000000163','2026-10-31 09:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(164,40,5,NULL,'2026-10-31 11:20:00',99.68,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(661,164,36,NULL,1.000,20.48,'ativo',NULL,NULL),
(662,164,47,NULL,2.000,16.51,'ativo',NULL,NULL),
(663,164,6,NULL,1.000,14.58,'ativo',NULL,NULL),
(664,164,20,NULL,2.000,15.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(71,661,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(93,662,NULL,NULL,2.000,'2026-10-31 11:20:00','venda'),
(11,663,NULL,NULL,1.000,'2026-10-31 11:20:00','venda'),
(39,664,NULL,NULL,2.000,'2026-10-31 11:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(180,164,5,99.68);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(164,164,'NFCe','000164','1','90000000000000000000000000000000000000000164','2026-10-31 11:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(165,40,5,NULL,'2026-10-31 12:50:00',84.37,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(665,165,43,NULL,2.000,9.59,'ativo',NULL,NULL),
(666,165,1,NULL,1.000,6.90,'ativo',NULL,NULL),
(667,165,13,NULL,2.000,26.69,'ativo',NULL,NULL),
(668,165,27,NULL,1.000,4.91,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(85,665,NULL,NULL,2.000,'2026-10-31 12:50:00','venda'),
(1,666,NULL,NULL,1.000,'2026-10-31 12:50:00','venda'),
(25,667,NULL,NULL,2.000,'2026-10-31 12:50:00','venda'),
(53,668,NULL,NULL,1.000,'2026-10-31 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(181,165,1,84.37);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(165,165,'NFCe','000165','1','90000000000000000000000000000000000000000165','2026-10-31 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(166,40,5,NULL,'2026-10-31 14:20:00',100.29,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(669,166,51,NULL,1.000,27.90,'ativo',NULL,NULL),
(670,166,8,NULL,1.250,18.04,'ativo',NULL,NULL),
(671,166,20,NULL,1.000,15.80,'ativo',NULL,NULL),
(672,166,34,NULL,2.000,17.02,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(101,669,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(15,670,NULL,NULL,1.250,'2026-10-31 14:20:00','venda'),
(39,671,NULL,NULL,1.000,'2026-10-31 14:20:00','venda'),
(67,672,NULL,NULL,2.000,'2026-10-31 14:20:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(182,166,2,100.29);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(166,166,'NFCe','000166','1','90000000000000000000000000000000000000000166','2026-10-31 14:21:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(167,40,5,NULL,'2026-10-31 15:50:00',38.37,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(673,167,4,NULL,1.250,11.12,'ativo',NULL,NULL),
(674,167,15,NULL,1.000,7.15,'ativo',NULL,NULL),
(675,167,27,NULL,2.000,4.91,'ativo',NULL,NULL),
(676,167,41,NULL,1.000,7.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(7,673,NULL,NULL,1.250,'2026-10-31 15:50:00','venda'),
(29,674,NULL,NULL,1.000,'2026-10-31 15:50:00','venda'),
(53,675,NULL,NULL,2.000,'2026-10-31 15:50:00','venda'),
(81,676,NULL,NULL,1.000,'2026-10-31 15:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(183,167,3,38.37);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(167,167,'NFCe','000167','1','90000000000000000000000000000000000000000167','2026-10-31 15:51:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 576.32 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=40 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(40,10,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(41,6,7,'2026-10-31 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(168,41,7,NULL,'2026-10-31 10:08:00',104.66,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(677,168,11,NULL,1.000,9.90,'ativo',NULL,NULL),
(678,168,22,NULL,2.000,18.90,'ativo',NULL,NULL),
(679,168,34,NULL,1.000,17.02,'ativo',NULL,NULL),
(680,168,49,NULL,2.000,19.97,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(21,677,NULL,NULL,1.000,'2026-10-31 10:08:00','venda'),
(43,678,NULL,NULL,2.000,'2026-10-31 10:08:00','venda'),
(67,679,NULL,NULL,1.000,'2026-10-31 10:08:00','venda'),
(97,680,NULL,NULL,2.000,'2026-10-31 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(184,168,4,104.66);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(168,168,'NFCe','000168','1','90000000000000000000000000000000000000000168','2026-10-31 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(169,41,7,NULL,'2026-10-31 11:56:00',52.30,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(681,169,18,NULL,2.000,12.34,'ativo',NULL,NULL),
(682,169,29,NULL,1.000,8.37,'ativo',NULL,NULL),
(683,169,41,NULL,2.000,7.50,'ativo',NULL,NULL),
(684,169,2,NULL,0.500,8.50,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(35,681,NULL,NULL,2.000,'2026-10-31 11:56:00','venda'),
(57,682,NULL,NULL,1.000,'2026-10-31 11:56:00','venda'),
(81,683,NULL,NULL,2.000,'2026-10-31 11:56:00','venda'),
(3,684,NULL,NULL,0.500,'2026-10-31 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(185,169,5,52.30);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(169,169,'NFCe','000169','1','90000000000000000000000000000000000000000169','2026-10-31 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(170,41,7,NULL,'2026-10-31 13:43:59',100.21,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(685,170,25,NULL,1.000,24.45,'ativo',NULL,NULL),
(686,170,36,NULL,2.000,20.48,'ativo',NULL,NULL),
(687,170,49,NULL,1.000,19.97,'ativo',NULL,NULL),
(688,170,9,NULL,0.750,19.77,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(49,685,NULL,NULL,1.000,'2026-10-31 13:43:59','venda'),
(71,686,NULL,NULL,2.000,'2026-10-31 13:43:59','venda'),
(97,687,NULL,NULL,1.000,'2026-10-31 13:43:59','venda'),
(17,688,NULL,NULL,0.750,'2026-10-31 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(186,170,1,60.13),
(187,170,3,40.08);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(170,170,'NFCe','000170','1','90000000000000000000000000000000000000000170','2026-10-31 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(171,41,7,NULL,'2026-10-31 15:32:00',34.45,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(689,171,32,NULL,2.000,4.80,'ativo',NULL,NULL),
(690,171,43,NULL,1.000,9.59,'ativo',NULL,NULL),
(691,171,2,NULL,0.750,8.50,'ativo',NULL,NULL),
(692,171,16,NULL,1.000,8.88,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(63,689,NULL,NULL,2.000,'2026-10-31 15:32:00','venda'),
(85,690,NULL,NULL,1.000,'2026-10-31 15:32:00','venda'),
(3,691,NULL,NULL,0.750,'2026-10-31 15:32:00','venda'),
(31,692,NULL,NULL,1.000,'2026-10-31 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(188,171,2,34.45);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(171,171,'NFCe','000171','1','90000000000000000000000000000000000000000171','2026-10-31 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 466.62 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=41 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(41,9,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(42,7,8,'2026-10-31 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(172,42,8,NULL,'2026-10-31 10:08:00',143.22,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(693,172,39,NULL,1.000,25.67,'ativo',NULL,NULL),
(694,172,51,NULL,2.000,27.90,'ativo',NULL,NULL),
(695,172,9,NULL,1.000,19.77,'ativo',NULL,NULL),
(696,172,23,NULL,2.000,20.99,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(77,693,NULL,NULL,1.000,'2026-10-31 10:08:00','venda'),
(101,694,NULL,NULL,2.000,'2026-10-31 10:08:00','venda'),
(17,695,NULL,NULL,1.000,'2026-10-31 10:08:00','venda'),
(45,696,NULL,NULL,2.000,'2026-10-31 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(189,172,3,143.22);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(172,172,'NFCe','000172','1','90000000000000000000000000000000000000000172','2026-10-31 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(173,42,8,NULL,'2026-10-31 11:56:00',68.54,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(697,173,46,NULL,2.000,14.78,'ativo',NULL,NULL),
(698,173,4,NULL,1.000,11.12,'ativo',NULL,NULL),
(699,173,16,NULL,2.000,8.88,'ativo',NULL,NULL),
(700,173,30,NULL,1.000,10.10,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(91,697,NULL,NULL,2.000,'2026-10-31 11:56:00','venda'),
(7,698,NULL,NULL,1.000,'2026-10-31 11:56:00','venda'),
(31,699,NULL,NULL,2.000,'2026-10-31 11:56:00','venda'),
(59,700,NULL,NULL,1.000,'2026-10-31 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(190,173,4,68.54);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(173,173,'NFCe','000173','1','90000000000000000000000000000000000000000173','2026-10-31 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(174,42,8,NULL,'2026-10-31 13:43:59',90.83,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(701,174,54,NULL,1.000,5.62,'ativo',NULL,NULL),
(702,174,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(703,174,23,NULL,1.000,20.99,'ativo',NULL,NULL),
(704,174,37,NULL,2.000,22.21,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(107,701,NULL,NULL,1.000,'2026-10-31 13:43:59','venda'),
(21,702,NULL,NULL,2.000,'2026-10-31 13:43:59','venda'),
(45,703,NULL,NULL,1.000,'2026-10-31 13:43:59','venda'),
(73,704,NULL,NULL,2.000,'2026-10-31 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(191,174,5,90.83);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(174,174,'NFCe','000174','1','90000000000000000000000000000000000000000174','2026-10-31 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(175,42,8,NULL,'2026-10-31 15:32:00',64.25,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(705,175,7,NULL,1.250,16.31,'ativo',NULL,NULL),
(706,175,18,NULL,1.000,12.34,'ativo',NULL,NULL),
(707,175,30,NULL,2.000,10.10,'ativo',NULL,NULL),
(708,175,44,NULL,1.000,11.32,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(13,705,NULL,NULL,1.250,'2026-10-31 15:32:00','venda'),
(35,706,NULL,NULL,1.000,'2026-10-31 15:32:00','venda'),
(59,707,NULL,NULL,2.000,'2026-10-31 15:32:00','venda'),
(87,708,NULL,NULL,1.000,'2026-10-31 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(192,175,1,64.25);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(175,175,'NFCe','000175','1','90000000000000000000000000000000000000000175','2026-10-31 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(14,42,10,'2026-10-31 13:00:00',80.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 486.84 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=42 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(42,10,'2026-10-31 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(43,1,1,'2026-11-01 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(176,43,1,NULL,'2026-11-01 10:08:00',126.85,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(709,176,14,NULL,1.000,5.42,'ativo',NULL,NULL),
(710,176,25,NULL,2.000,24.45,'ativo',NULL,NULL),
(711,176,37,NULL,1.000,22.21,'ativo',NULL,NULL),
(712,176,52,NULL,2.000,25.16,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(27,709,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(49,710,NULL,NULL,2.000,'2026-11-01 10:08:00','venda'),
(73,711,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(103,712,NULL,NULL,2.000,'2026-11-01 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(193,176,2,126.85);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(176,176,'NFCe','000176','1','90000000000000000000000000000000000000000176','2026-11-01 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(177,43,1,NULL,'2026-11-01 11:56:00',59.67,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(713,177,21,NULL,2.000,12.90,'ativo',NULL,NULL),
(714,177,32,NULL,1.000,4.80,'ativo',NULL,NULL),
(715,177,44,NULL,2.000,11.32,'ativo',NULL,NULL),
(716,177,5,NULL,0.500,12.85,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(41,713,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(63,714,NULL,NULL,1.000,'2026-11-01 11:56:00','venda'),
(87,715,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(9,716,NULL,NULL,0.500,'2026-11-01 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(194,177,3,59.67);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(177,177,'NFCe','000177','1','90000000000000000000000000000000000000000177','2026-11-01 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(178,43,1,NULL,'2026-11-01 13:43:59',133.06,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(717,178,28,NULL,1.000,6.64,'ativo',NULL,NULL),
(718,178,39,NULL,2.000,25.67,'ativo',NULL,NULL),
(719,178,52,NULL,1.000,25.16,'ativo',NULL,NULL),
(720,178,12,NULL,2.000,24.96,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(55,717,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(77,718,NULL,NULL,2.000,'2026-11-01 13:43:59','venda'),
(103,719,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(23,720,NULL,NULL,2.000,'2026-11-01 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(195,178,4,133.06);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(178,178,'NFCe','000178','1','90000000000000000000000000000000000000000178','2026-11-01 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(179,43,1,NULL,'2026-11-01 15:32:00',75.99,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(721,179,35,NULL,2.000,18.75,'ativo',NULL,NULL),
(722,179,46,NULL,1.000,14.78,'ativo',NULL,NULL),
(723,179,5,NULL,0.750,12.85,'ativo',NULL,NULL),
(724,179,19,NULL,1.000,14.07,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(69,721,NULL,NULL,2.000,'2026-11-01 15:32:00','venda'),
(91,722,NULL,NULL,1.000,'2026-11-01 15:32:00','venda'),
(9,723,NULL,NULL,0.750,'2026-11-01 15:32:00','venda'),
(37,724,NULL,NULL,1.000,'2026-11-01 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(196,179,5,75.99);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(179,179,'NFCe','000179','1','90000000000000000000000000000000000000000179','2026-11-01 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 620.57 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=43 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(43,9,'2026-11-01 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(44,2,2,'2026-11-01 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(180,44,2,NULL,'2026-11-01 10:08:00',101.06,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(725,180,42,NULL,1.000,12.50,'ativo',NULL,NULL),
(726,180,54,NULL,2.000,5.62,'ativo',NULL,NULL),
(727,180,12,NULL,1.000,24.96,'ativo',NULL,NULL),
(728,180,26,NULL,2.000,26.18,'ativo',NULL,NULL),
(729,180,29,10,1.000,8.37,'cancelado','Item retirado antes da conclusao','2026-11-01 10:09:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(83,725,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(107,726,NULL,NULL,2.000,'2026-11-01 10:08:00','venda'),
(23,727,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(51,728,NULL,NULL,2.000,'2026-11-01 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(197,180,1,60.64),
(198,180,3,40.42);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(180,180,'SAT','000180','1','90000000000000000000000000000000000000000180','2026-11-01 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(181,44,2,NULL,'2026-11-01 11:56:00',103.14,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(730,181,50,NULL,2.000,21.70,'ativo',NULL,NULL),
(731,181,7,NULL,1.000,16.31,'ativo',NULL,NULL),
(732,181,19,NULL,2.000,14.07,'ativo',NULL,NULL),
(733,181,33,NULL,1.000,15.29,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(99,730,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(13,731,NULL,NULL,1.000,'2026-11-01 11:56:00','venda'),
(37,732,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(65,733,NULL,NULL,1.000,'2026-11-01 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(199,181,2,103.14);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(181,181,'NFCe','000181','1','90000000000000000000000000000000000000000181','2026-11-01 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(182,44,2,NULL,'2026-11-01 13:43:59',55.21,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(734,182,3,NULL,1.000,9.39,'ativo',NULL,NULL),
(735,182,14,NULL,2.000,5.42,'ativo',NULL,NULL),
(736,182,26,NULL,1.000,26.18,'ativo',NULL,NULL),
(737,182,40,NULL,2.000,4.40,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(5,734,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(27,735,NULL,NULL,2.000,'2026-11-01 13:43:59','venda'),
(51,736,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(79,737,NULL,NULL,2.000,'2026-11-01 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(200,182,3,55.21);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(182,182,'NFCe','000182','1','90000000000000000000000000000000000000000182','2026-11-01 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(183,44,2,NULL,'2026-11-01 15:32:00',86.87,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(738,183,10,NULL,1.250,21.50,'ativo',NULL,NULL),
(739,183,21,NULL,1.000,12.90,'ativo',NULL,NULL),
(740,183,33,NULL,2.000,15.29,'ativo',NULL,NULL),
(741,183,47,NULL,1.000,16.51,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(19,738,NULL,NULL,1.250,'2026-11-01 15:32:00','venda'),
(41,739,NULL,NULL,1.000,'2026-11-01 15:32:00','venda'),
(65,740,NULL,NULL,2.000,'2026-11-01 15:32:00','venda'),
(93,741,NULL,NULL,1.000,'2026-11-01 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(201,183,4,86.87);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(183,183,'NFCe','000183','1','90000000000000000000000000000000000000000183','2026-11-01 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 496.28 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=44 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(44,10,'2026-11-01 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(45,3,3,'2026-11-01 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(184,45,3,NULL,'2026-11-01 10:08:00',36.92,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(742,184,17,NULL,1.000,10.61,'ativo',NULL,NULL),
(743,184,28,NULL,2.000,6.64,'ativo',NULL,NULL),
(744,184,40,NULL,1.000,4.40,'ativo',NULL,NULL),
(745,184,1,NULL,1.250,6.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(33,742,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(55,743,NULL,NULL,2.000,'2026-11-01 10:08:00','venda'),
(79,744,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(1,745,NULL,NULL,1.250,'2026-11-01 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(202,184,5,36.92);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(184,184,'NFCe','000184','1','90000000000000000000000000000000000000000184','2026-11-01 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(185,45,3,NULL,'2026-11-01 11:56:00',106.23,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(746,185,24,NULL,2.000,22.72,'ativo',NULL,NULL),
(747,185,35,NULL,1.000,18.75,'ativo',NULL,NULL),
(748,185,47,NULL,2.000,16.51,'ativo',NULL,NULL),
(749,185,8,NULL,0.500,18.04,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(47,746,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(69,747,NULL,NULL,1.000,'2026-11-01 11:56:00','venda'),
(93,748,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(15,749,NULL,NULL,0.500,'2026-11-01 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(203,185,1,106.23);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(185,185,'NFCe','000185','1','90000000000000000000000000000000000000000185','2026-11-01 11:57:00','emitido');

INSERT INTO TROCA_OPERADOR (id_troca,id_sessao,id_funcionario_anterior,id_funcionario_novo,data_hora) VALUES
(5,45,3,9,'2026-11-01 13:42:59');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(186,45,9,NULL,'2026-11-01 13:43:59',49.25,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(750,186,31,NULL,1.000,6.50,'ativo',NULL,NULL),
(751,186,42,NULL,2.000,12.50,'ativo',NULL,NULL),
(752,186,1,NULL,0.500,6.90,'ativo',NULL,NULL),
(753,186,15,NULL,2.000,7.15,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(61,750,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(83,751,NULL,NULL,2.000,'2026-11-01 13:43:59','venda'),
(1,752,NULL,NULL,0.500,'2026-11-01 13:43:59','venda'),
(29,753,NULL,NULL,2.000,'2026-11-01 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(204,186,2,49.25);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(186,186,'NFCe','000186','1','90000000000000000000000000000000000000000186','2026-11-01 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(187,45,9,NULL,'2026-11-01 15:32:00',102.01,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(754,187,38,NULL,2.000,23.94,'ativo',NULL,NULL),
(755,187,50,NULL,1.000,21.70,'ativo',NULL,NULL),
(756,187,8,NULL,0.750,18.04,'ativo',NULL,NULL),
(757,187,22,NULL,1.000,18.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(75,754,NULL,NULL,2.000,'2026-11-01 15:32:00','venda'),
(99,755,NULL,NULL,1.000,'2026-11-01 15:32:00','venda'),
(15,756,NULL,NULL,0.750,'2026-11-01 15:32:00','venda'),
(43,757,NULL,NULL,1.000,'2026-11-01 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(205,187,3,102.01);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(187,187,'NFCe','000187','1','90000000000000000000000000000000000000000187','2026-11-01 15:33:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(15,45,9,'2026-11-01 13:00:00',70.00);

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 397.91 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=45 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(45,9,'2026-11-01 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(46,4,4,'2026-11-01 08:00:00',200.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(188,46,4,NULL,'2026-11-01 10:08:00',43.98,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(758,188,45,NULL,1.000,13.05,'ativo',NULL,NULL),
(759,188,3,NULL,0.750,9.39,'ativo',NULL,NULL),
(760,188,15,NULL,1.000,7.15,'ativo',NULL,NULL),
(761,188,29,NULL,2.000,8.37,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(89,758,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(5,759,NULL,NULL,0.750,'2026-11-01 10:08:00','venda'),
(29,760,NULL,NULL,1.000,'2026-11-01 10:08:00','venda'),
(57,761,NULL,NULL,2.000,'2026-11-01 10:08:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(206,188,4,43.98);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(188,188,'NFCe','000188','1','90000000000000000000000000000000000000000188','2026-11-01 10:09:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(189,46,4,NULL,'2026-11-01 11:56:00',133.56,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(762,189,53,NULL,2.000,26.89,'ativo',NULL,NULL),
(763,189,10,NULL,1.000,21.50,'ativo',NULL,NULL),
(764,189,22,NULL,2.000,18.90,'ativo',NULL,NULL),
(765,189,36,NULL,1.000,20.48,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(105,762,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(19,763,NULL,NULL,1.000,'2026-11-01 11:56:00','venda'),
(43,764,NULL,NULL,2.000,'2026-11-01 11:56:00','venda'),
(71,765,NULL,NULL,1.000,'2026-11-01 11:56:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(207,189,5,133.56);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(189,189,'NFCe','000189','1','90000000000000000000000000000000000000000189','2026-11-01 11:57:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(190,46,4,NULL,'2026-11-01 13:43:59',63.35,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(766,190,6,NULL,1.000,14.58,'ativo',NULL,NULL),
(767,190,17,NULL,2.000,10.61,'ativo',NULL,NULL),
(768,190,29,NULL,1.000,8.37,'ativo',NULL,NULL),
(769,190,43,NULL,2.000,9.59,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(11,766,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(33,767,NULL,NULL,2.000,'2026-11-01 13:43:59','venda'),
(57,768,NULL,NULL,1.000,'2026-11-01 13:43:59','venda'),
(85,769,NULL,NULL,2.000,'2026-11-01 13:43:59','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(208,190,1,38.01),
(209,190,3,25.34);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(190,190,'NFCe','000190','1','90000000000000000000000000000000000000000190','2026-11-01 13:44:59','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(191,46,4,NULL,'2026-11-01 15:32:00',144.96,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(770,191,13,NULL,2.000,26.69,'ativo',NULL,NULL),
(771,191,24,NULL,1.000,22.72,'ativo',NULL,NULL),
(772,191,36,NULL,2.000,20.48,'ativo',NULL,NULL),
(773,191,51,NULL,1.000,27.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(25,770,NULL,NULL,2.000,'2026-11-01 15:32:00','venda'),
(47,771,NULL,NULL,1.000,'2026-11-01 15:32:00','venda'),
(71,772,NULL,NULL,2.000,'2026-11-01 15:32:00','venda'),
(101,773,NULL,NULL,1.000,'2026-11-01 15:32:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(210,191,2,144.96);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(191,191,'NFCe','000191','1','90000000000000000000000000000000000000000191','2026-11-01 15:33:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 585.85 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=46 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(46,10,'2026-11-01 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(47,5,5,'2026-11-01 08:00:00',225.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(192,47,5,NULL,'2026-11-01 10:35:00',52.29,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(774,192,20,NULL,1.000,15.80,'ativo',NULL,NULL),
(775,192,31,NULL,2.000,6.50,'ativo',NULL,NULL),
(776,192,43,NULL,1.000,9.59,'ativo',NULL,NULL),
(777,192,4,NULL,1.250,11.12,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(39,774,NULL,NULL,1.000,'2026-11-01 10:35:00','venda'),
(61,775,NULL,NULL,2.000,'2026-11-01 10:35:00','venda'),
(85,776,NULL,NULL,1.000,'2026-11-01 10:35:00','venda'),
(7,777,NULL,NULL,1.250,'2026-11-01 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(211,192,3,52.29);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(192,192,'NFCe','000192','1','90000000000000000000000000000000000000000192','2026-11-01 10:36:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(193,47,5,NULL,'2026-11-01 12:50:00',99.46,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(778,193,27,NULL,2.000,4.91,'ativo',NULL,NULL),
(779,193,38,NULL,1.000,23.94,'ativo',NULL,NULL),
(780,193,51,NULL,2.000,27.90,'ativo',NULL,NULL),
(781,193,11,NULL,1.000,9.90,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(53,778,NULL,NULL,2.000,'2026-11-01 12:50:00','venda'),
(75,779,NULL,NULL,1.000,'2026-11-01 12:50:00','venda'),
(101,780,NULL,NULL,2.000,'2026-11-01 12:50:00','venda'),
(21,781,NULL,NULL,1.000,'2026-11-01 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(212,193,4,99.46);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(193,193,'NFCe','000193','1','90000000000000000000000000000000000000000193','2026-11-01 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(194,47,5,NULL,'2026-11-01 15:05:00',73.36,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(782,194,34,NULL,1.000,17.02,'ativo',NULL,NULL),
(783,194,45,NULL,2.000,13.05,'ativo',NULL,NULL),
(784,194,4,NULL,0.500,11.12,'ativo',NULL,NULL),
(785,194,18,NULL,2.000,12.34,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(67,782,NULL,NULL,1.000,'2026-11-01 15:05:00','venda'),
(89,783,NULL,NULL,2.000,'2026-11-01 15:05:00','venda'),
(7,784,NULL,NULL,0.500,'2026-11-01 15:05:00','venda'),
(35,785,NULL,NULL,2.000,'2026-11-01 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(213,194,5,73.36);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(194,194,'NFCe','000194','1','90000000000000000000000000000000000000000194','2026-11-01 15:06:00','emitido');

-- Contagem ficticia da gaveta: exclui recebimentos que nao sao dinheiro.
SET @contado_gaveta = 450.11 - (SELECT COALESCE(SUM(pg.valor),0) FROM PAGAMENTO pg JOIN VENDA v ON v.id_venda=pg.id_venda JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE v.id_sessao=47 AND v.status='concluida' AND fp.descricao<>'Dinheiro');
CALL fechar_sessao(47,9,'2026-11-01 18:00:00',@contado_gaveta);

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(48,6,6,'2026-11-01 08:00:00',150.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(195,48,6,NULL,'2026-11-01 10:35:00',86.14,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(786,195,41,NULL,2.000,7.50,'ativo',NULL,NULL),
(787,195,53,NULL,1.000,26.89,'ativo',NULL,NULL),
(788,195,11,NULL,2.000,9.90,'ativo',NULL,NULL),
(789,195,25,NULL,1.000,24.45,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(81,786,NULL,NULL,2.000,'2026-11-01 10:35:00','venda'),
(105,787,NULL,NULL,1.000,'2026-11-01 10:35:00','venda'),
(21,788,NULL,NULL,2.000,'2026-11-01 10:35:00','venda'),
(49,789,NULL,NULL,1.000,'2026-11-01 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(214,195,1,86.14);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(195,195,'NFCe','000195','1','90000000000000000000000000000000000000000195','2026-11-01 10:36:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(196,48,6,NULL,'2026-11-01 12:50:00',52.85,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(790,196,49,NULL,1.000,19.97,'ativo',NULL,NULL),
(791,196,6,NULL,0.750,14.58,'ativo',NULL,NULL),
(792,196,18,NULL,1.000,12.34,'ativo',NULL,NULL),
(793,196,32,NULL,2.000,4.80,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(97,790,NULL,NULL,1.000,'2026-11-01 12:50:00','venda'),
(11,791,NULL,NULL,0.750,'2026-11-01 12:50:00','venda'),
(35,792,NULL,NULL,1.000,'2026-11-01 12:50:00','venda'),
(63,793,NULL,NULL,2.000,'2026-11-01 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(215,196,2,52.85);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(196,196,'NFCe','000196','1','90000000000000000000000000000000000000000196','2026-11-01 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(197,48,6,NULL,'2026-11-01 15:05:00',107.64,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(794,197,2,NULL,0.750,8.50,'ativo',NULL,NULL),
(795,197,13,NULL,1.000,26.69,'ativo',NULL,NULL),
(796,197,25,NULL,2.000,24.45,'ativo',NULL,NULL),
(797,197,39,NULL,1.000,25.67,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(3,794,NULL,NULL,0.750,'2026-11-01 15:05:00','venda'),
(25,795,NULL,NULL,1.000,'2026-11-01 15:05:00','venda'),
(49,796,NULL,NULL,2.000,'2026-11-01 15:05:00','venda'),
(77,797,NULL,NULL,1.000,'2026-11-01 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(216,197,3,107.64);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(197,197,'NFCe','000197','1','90000000000000000000000000000000000000000197','2026-11-01 15:06:00','emitido');

INSERT INTO SANGRIA (id_sangria,id_sessao,id_funcionario,data_hora,valor) VALUES
(16,48,10,'2026-11-01 13:00:00',60.00);

-- Sessao mantida aberta de proposito para demonstrar estado atual.

INSERT INTO SESSAO_CAIXA (id_sessao,id_caixa,id_funcionario_abertura,data_abertura,fundo_inicial,status) VALUES
(49,7,8,'2026-11-01 08:00:00',175.00,'aberta');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(198,49,8,NULL,'2026-11-01 10:35:00',85.73,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(798,198,9,NULL,1.000,19.77,'ativo',NULL,NULL),
(799,198,20,NULL,2.000,15.80,'ativo',NULL,NULL),
(800,198,32,NULL,1.000,4.80,'ativo',NULL,NULL),
(801,198,46,NULL,2.000,14.78,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(17,798,NULL,NULL,1.000,'2026-11-01 10:35:00','venda'),
(39,799,NULL,NULL,2.000,'2026-11-01 10:35:00','venda'),
(63,800,NULL,NULL,1.000,'2026-11-01 10:35:00','venda'),
(91,801,NULL,NULL,2.000,'2026-11-01 10:35:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(217,198,4,85.73);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(198,198,'NFCe','000198','1','90000000000000000000000000000000000000000198','2026-11-01 10:36:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(199,49,8,NULL,'2026-11-01 12:50:00',79.63,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(802,199,16,NULL,2.000,8.88,'ativo',NULL,NULL),
(803,199,27,NULL,1.000,4.91,'ativo',NULL,NULL),
(804,199,39,NULL,2.000,25.67,'ativo',NULL,NULL),
(805,199,54,NULL,1.000,5.62,'ativo',NULL,NULL);

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(31,802,NULL,NULL,2.000,'2026-11-01 12:50:00','venda'),
(53,803,NULL,NULL,1.000,'2026-11-01 12:50:00','venda'),
(77,804,NULL,NULL,2.000,'2026-11-01 12:50:00','venda'),
(107,805,NULL,NULL,1.000,'2026-11-01 12:50:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(218,199,5,79.63);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(199,199,'NFCe','000199','1','90000000000000000000000000000000000000000199','2026-11-01 12:51:00','emitido');

INSERT INTO VENDA (id_venda,id_sessao,id_funcionario_operador,id_funcionario_supervisor,data_hora,valor_total,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(200,49,8,NULL,'2026-11-01 15:05:00',90.20,'concluida',NULL,NULL);

INSERT INTO ITEM_VENDA (id_item_venda,id_venda,id_produto,id_funcionario_cancelamento,quantidade_ou_peso,preco_unitario,status,motivo_cancelamento,data_hora_cancelamento) VALUES
(806,200,23,NULL,1.000,20.99,'ativo',NULL,NULL),
(807,200,34,NULL,2.000,17.02,'ativo',NULL,NULL),
(808,200,46,NULL,1.000,14.78,'ativo',NULL,NULL),
(809,200,7,NULL,1.250,16.31,'ativo',NULL,NULL),
(810,200,38,9,1.000,23.94,'cancelado','Item retirado antes da conclusao','2026-11-01 15:06:00');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(45,806,NULL,NULL,1.000,'2026-11-01 15:05:00','venda'),
(67,807,NULL,NULL,2.000,'2026-11-01 15:05:00','venda'),
(91,808,NULL,NULL,1.000,'2026-11-01 15:05:00','venda'),
(13,809,NULL,NULL,1.250,'2026-11-01 15:05:00','venda');

INSERT INTO PAGAMENTO (id_pagamento,id_venda,id_forma,valor) VALUES
(219,200,1,54.12),
(220,200,3,36.08);

INSERT INTO DOCUMENTO_FISCAL (id_documento,id_venda,tipo_documento,numero_documento,serie,chave_acesso,data_emissao,situacao) VALUES
(200,200,'SAT','000200','1','90000000000000000000000000000000000000000200','2026-11-01 15:06:00','emitido');

CALL cancelar_venda(200,9,'Cancelamento ficticio para teste','2026-11-01 15:10:00');


-- Sessao mantida aberta de proposito para demonstrar estado atual.

-- 5.4 Perdas. Inseridas depois das vendas apenas por ordem de carga; as datas preservam o periodo simulado.

INSERT INTO PERDA (id_perda,id_produto,id_setor,id_motivo,id_funcionario,id_lote,id_perda_original,data_hora,quantidade,valor_estimado,situacao_lote,status,observacao) VALUES
(1,1,1,1,14,1,NULL,'2026-10-26 17:00:00',1.250,5.00,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(2,2,1,2,14,3,NULL,'2026-10-27 17:07:00',1.250,6.16,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(3,3,1,3,14,5,NULL,'2026-10-28 17:14:00',1.250,6.81,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(4,11,2,4,16,21,NULL,'2026-10-29 17:21:00',2.000,11.48,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(5,12,2,5,16,23,NULL,'2026-10-30 17:28:00',1.000,14.48,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(6,13,2,6,16,25,NULL,'2026-10-31 17:35:00',2.000,30.96,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(7,21,3,7,16,41,NULL,'2026-11-01 17:42:00',1.000,7.48,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(8,22,3,8,16,43,NULL,'2026-10-26 17:04:00',2.000,21.92,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(9,23,3,1,16,45,NULL,'2026-10-27 17:11:00',1.000,12.17,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(10,31,4,2,15,61,NULL,'2026-10-28 17:18:00',2.000,7.54,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(11,32,4,3,15,63,NULL,'2026-10-29 17:25:00',1.000,2.78,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(12,33,4,4,15,65,NULL,'2026-10-30 17:32:00',2.000,17.74,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(13,41,5,5,16,81,NULL,'2026-10-31 17:39:00',1.000,4.35,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(14,42,5,6,16,83,NULL,'2026-11-01 17:01:00',2.000,14.50,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(15,43,5,7,16,85,NULL,'2026-10-26 17:08:00',1.000,5.56,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(16,51,6,8,16,101,NULL,'2026-10-27 17:15:00',2.000,32.36,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(17,52,6,1,16,103,NULL,'2026-10-28 17:22:00',1.000,14.59,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(18,53,6,2,16,105,NULL,'2026-10-29 17:29:00',2.000,31.20,'confirmado','valida','Perda ficticia confirmada para demonstracao'),
(19,4,1,1,14,NULL,NULL,'2026-10-26 15:00:00',0.750,NULL,'lote_a_confirmar','valida','Perda ficticia aguardando confirmacao do lote'),
(20,14,2,2,16,NULL,NULL,'2026-10-27 15:09:00',1.000,NULL,'lote_a_confirmar','valida','Perda ficticia aguardando confirmacao do lote'),
(21,24,3,3,16,NULL,NULL,'2026-10-28 15:18:00',1.000,NULL,'lote_a_confirmar','valida','Perda ficticia aguardando confirmacao do lote'),
(22,34,4,4,15,NULL,NULL,'2026-10-29 15:27:00',1.000,NULL,'lote_a_confirmar','valida','Perda ficticia aguardando confirmacao do lote'),
(23,44,5,5,16,NULL,NULL,'2026-10-30 15:36:00',1.000,NULL,'lote_a_confirmar','valida','Perda ficticia aguardando confirmacao do lote'),
(24,54,6,6,16,NULL,NULL,'2026-10-31 15:00:00',1.000,NULL,'lote_a_confirmar','valida','Perda ficticia aguardando confirmacao do lote');

INSERT INTO SAIDA_LOTE (id_lote,id_item_venda,id_perda,id_saida_original,quantidade,data_hora,tipo) VALUES
(1,NULL,1,NULL,1.250,'2026-10-26 17:00:00','perda'),
(3,NULL,2,NULL,1.250,'2026-10-27 17:07:00','perda'),
(5,NULL,3,NULL,1.250,'2026-10-28 17:14:00','perda'),
(21,NULL,4,NULL,2.000,'2026-10-29 17:21:00','perda'),
(23,NULL,5,NULL,1.000,'2026-10-30 17:28:00','perda'),
(25,NULL,6,NULL,2.000,'2026-10-31 17:35:00','perda'),
(41,NULL,7,NULL,1.000,'2026-11-01 17:42:00','perda'),
(43,NULL,8,NULL,2.000,'2026-10-26 17:04:00','perda'),
(45,NULL,9,NULL,1.000,'2026-10-27 17:11:00','perda'),
(61,NULL,10,NULL,2.000,'2026-10-28 17:18:00','perda'),
(63,NULL,11,NULL,1.000,'2026-10-29 17:25:00','perda'),
(65,NULL,12,NULL,2.000,'2026-10-30 17:32:00','perda'),
(81,NULL,13,NULL,1.000,'2026-10-31 17:39:00','perda'),
(83,NULL,14,NULL,2.000,'2026-11-01 17:01:00','perda'),
(85,NULL,15,NULL,1.000,'2026-10-26 17:08:00','perda'),
(101,NULL,16,NULL,2.000,'2026-10-27 17:15:00','perda'),
(103,NULL,17,NULL,1.000,'2026-10-28 17:22:00','perda'),
(105,NULL,18,NULL,2.000,'2026-10-29 17:29:00','perda');

-- 5.5 Conferencias rapidas da massa

SELECT 'VENDA' AS tabela, COUNT(*) AS registros FROM VENDA
UNION ALL SELECT 'ITEM_VENDA',COUNT(*) FROM ITEM_VENDA
UNION ALL SELECT 'PAGAMENTO',COUNT(*) FROM PAGAMENTO
UNION ALL SELECT 'SAIDA_LOTE',COUNT(*) FROM SAIDA_LOTE
UNION ALL SELECT 'SESSAO_CAIXA',COUNT(*) FROM SESSAO_CAIXA;

SELECT DATE(data_hora) AS dia,COUNT(*) AS vendas_registradas,SUM(status='cancelada') AS canceladas,SUM(status='concluida') AS concluidas
FROM VENDA GROUP BY DATE(data_hora) ORDER BY dia;

SELECT status,COUNT(*) AS quantidade FROM VENDA GROUP BY status ORDER BY status;


-- ================================================================
-- 6. EXEMPLOS DE SELECT COM JOIN
-- ================================================================

-- Produtos e setores
SELECT p.id_produto,p.nome,s.nome AS setor,p.preco_venda
FROM PRODUTO p JOIN SETOR s ON s.id_setor=p.id_setor
ORDER BY s.nome,p.nome;

-- Recebimentos e fornecedores
SELECT r.id_recebimento,r.numero_nf,f.razao_social,r.data_recebimento,r.valor_total
FROM RECEBIMENTO r JOIN FORNECEDOR f ON f.id_fornecedor=r.id_fornecedor
ORDER BY r.data_recebimento;

-- Vendas e operador
SELECT v.id_venda,v.data_hora,fn.nome AS operador,v.valor_total,v.status
FROM VENDA v JOIN FUNCIONARIO fn ON fn.id_funcionario=v.id_funcionario_operador
ORDER BY v.data_hora;

-- ================================================================
-- 7. EXEMPLOS DE UPDATE E DELETE
-- ================================================================

-- UPDATE simples: correcao de preco
UPDATE PRODUTO SET preco_venda=preco_venda+0.10 WHERE id_produto=1;

-- UPDATE de historico: fornecedor com movimentacao e apenas inativado
UPDATE FORNECEDOR SET ativo=0 WHERE id_fornecedor=3;

-- DELETE permitido somente em registro sem historico
INSERT INTO PRODUTO(id_setor,codigo_interno,nome,preco_venda,estoque_minimo,tipo_venda,tem_validade_impressa,venda_restrita_idade,ativo)
VALUES(6,'TESTE-EXCLUIR','Produto cadastrado por engano',1.00,0,'unidade',1,0,1);
DELETE FROM PRODUTO WHERE codigo_interno='TESTE-EXCLUIR';

INSERT INTO ESCALA(id_funcionario,data,tipo,hora_inicio,hora_fim)
VALUES(1,'2027-01-15','folga',NULL,NULL);
DELETE FROM ESCALA WHERE id_funcionario=1 AND data='2027-01-15';

-- ================================================================
-- 8. CONSULTAS GERENCIAIS - G01 A G12
-- ================================================================

-- G01 - Qual o custo das perdas em relacao as vendas de cada setor por mes?
-- Atende: P1 e KPI01. Inclui todos os setores de venda nos meses com movimento.
-- Sem faturamento, percentual NULL significa nao aplicavel (nunca zero artificial).
WITH perdas AS (
 SELECT id_setor,DATE_FORMAT(data_hora,'%Y-%m') mes,SUM(valor_estimado) valor_perdas
 FROM PERDA WHERE status='valida' AND situacao_lote='confirmado'
 GROUP BY id_setor,DATE_FORMAT(data_hora,'%Y-%m')
), vendas AS (
 SELECT p.id_setor,DATE_FORMAT(v.data_hora,'%Y-%m') mes,SUM(i.subtotal) valor_vendas
 FROM VENDA v JOIN ITEM_VENDA i ON i.id_venda=v.id_venda AND i.status='ativo'
 JOIN PRODUTO p ON p.id_produto=i.id_produto
 WHERE v.status='concluida'
 GROUP BY p.id_setor,DATE_FORMAT(v.data_hora,'%Y-%m')
), meses AS (
 SELECT mes FROM perdas UNION SELECT mes FROM vendas
), setores AS (
 SELECT id_setor FROM SETOR WHERE vende_produto=1
 UNION SELECT id_setor FROM perdas UNION SELECT id_setor FROM vendas
)
SELECT s.nome AS setor,m.mes,COALESCE(v.valor_vendas,0) AS valor_vendas,
 COALESCE(pe.valor_perdas,0) AS valor_perdas,
 ROUND(COALESCE(pe.valor_perdas,0)/NULLIF(COALESCE(v.valor_vendas,0),0)*100,2) AS percentual_perdas
FROM setores base JOIN SETOR s ON s.id_setor=base.id_setor CROSS JOIN meses m
LEFT JOIN vendas v ON v.id_setor=s.id_setor AND v.mes=m.mes
LEFT JOIN perdas pe ON pe.id_setor=s.id_setor AND pe.mes=m.mes
ORDER BY m.mes,s.nome;

-- G02 - Quantas ocorrencias de perda houve por motivo e por mes?
-- Atende: P1 e KPI02
SELECT DATE_FORMAT(p.data_hora,'%Y-%m') AS mes,m.descricao AS motivo,COUNT(*) AS ocorrencias
FROM PERDA p JOIN MOTIVO_PERDA m ON m.id_motivo=p.id_motivo
WHERE p.status='valida'
GROUP BY DATE_FORMAT(p.data_hora,'%Y-%m'),m.id_motivo,m.descricao
ORDER BY mes,ocorrencias DESC;

-- G03 - Quais lotes estao proximos do vencimento em 01/11/2026?
-- Atende: P2 e KPI03. No uso real, trocar a data fixa por CURDATE().
SELECT l.id_lote,p.nome AS produto,s.nome AS setor,l.data_validade,l.quantidade_atual,
       DATEDIFF(l.data_validade,'2026-11-01') AS dias_restantes,
       CASE WHEN EXISTS(SELECT 1 FROM PROMOCAO pr WHERE pr.id_lote=l.id_lote AND '2026-11-01' BETWEEN pr.data_inicio AND pr.data_fim)
            THEN 'sim' ELSE 'nao' END AS promocao_vigente
FROM LOTE l
JOIN PRODUTO p ON p.id_produto=l.id_produto
JOIN SETOR s ON s.id_setor=p.id_setor
WHERE l.quantidade_atual>0 AND l.data_validade IS NOT NULL
  AND l.data_validade>='2026-11-01'
  AND DATEDIFF(l.data_validade,'2026-11-01') <= COALESCE(s.dias_alerta_validade,7)
ORDER BY l.data_validade,p.nome;

-- G04 - Quais lotes ja venceram e ainda possuem saldo em 01/11/2026?
-- Atende: P2 e KPI04. No uso real, trocar a data fixa por CURDATE().
SELECT l.id_lote,p.nome AS produto,s.nome AS setor,l.data_validade,l.quantidade_atual
FROM LOTE l JOIN PRODUTO p ON p.id_produto=l.id_produto JOIN SETOR s ON s.id_setor=p.id_setor
WHERE l.quantidade_atual>0 AND l.data_validade<'2026-11-01'
ORDER BY l.data_validade;

-- G05 - Qual foi o faturamento por dia?
-- Atende: KPI05
SELECT DATE(data_hora) AS dia,COUNT(*) AS vendas,SUM(valor_total) AS faturamento
FROM VENDA WHERE status='concluida'
GROUP BY DATE(data_hora) ORDER BY dia;

-- G06 - Qual foi o ticket medio por dia?
-- Atende: KPI06
SELECT DATE(data_hora) AS dia,ROUND(AVG(valor_total),2) AS ticket_medio
FROM VENDA WHERE status='concluida'
GROUP BY DATE(data_hora) ORDER BY dia;

-- G07 - Quais produtos estao abaixo do estoque minimo e ja possuem pedido aberto?
-- Atende: KPI07 e RF20
SELECT p.id_produto,p.nome,s.saldo_disponivel,p.estoque_minimo,
       CASE WHEN EXISTS(
            SELECT 1 FROM ITEM_PEDIDO_COMPRA ip
            JOIN PEDIDO_COMPRA pc ON pc.id_pedido=ip.id_pedido
            WHERE ip.id_produto=p.id_produto AND pc.status IN ('aberto','parcial'))
            THEN 'sim' ELSE 'nao' END AS pedido_em_aberto
FROM PRODUTO p JOIN vw_saldo_produto s ON s.id_produto=p.id_produto
WHERE p.ativo=1 AND s.saldo_disponivel<p.estoque_minimo
ORDER BY s.saldo_disponivel;

-- G08 - Qual a taxa de cancelamento das vendas por mes?
-- Atende: KPI08
SELECT DATE_FORMAT(data_hora,'%Y-%m') AS mes,COUNT(*) AS vendas_registradas,
       SUM(status='cancelada') AS vendas_canceladas,
       ROUND(SUM(status='cancelada')/COUNT(*)*100,2) AS taxa_cancelamento
FROM VENDA
GROUP BY DATE_FORMAT(data_hora,'%Y-%m') ORDER BY mes;

-- G09 - Quais fornecedores tiveram mais mercadoria recusada por unidade de medida?
-- Atende: KPI09. Compare quantidades apenas dentro da mesma unidade_medida.
SELECT f.id_fornecedor,f.razao_social,
 p.tipo_venda AS unidade_medida,SUM(ir.quantidade_recusada) AS quantidade_recusada
FROM ITEM_RECEBIMENTO ir
JOIN RECEBIMENTO r ON r.id_recebimento=ir.id_recebimento
JOIN FORNECEDOR f ON f.id_fornecedor=r.id_fornecedor
JOIN PRODUTO p ON p.id_produto=ir.id_produto
GROUP BY f.id_fornecedor,f.razao_social,p.tipo_venda
HAVING SUM(ir.quantidade_recusada)>0
ORDER BY unidade_medida,quantidade_recusada DESC,f.id_fornecedor;

-- G10 - Quanto existe de contas em aberto, separando vencidas e a vencer?
-- Atende: KPI10
SELECT CASE WHEN c.data_vencimento<'2026-11-01' THEN 'vencida' ELSE 'a vencer' END AS situacao_vencimento,
       COUNT(*) AS quantidade_contas,
       SUM(c.valor-COALESCE(a.total_abatimento,0)) AS saldo_a_pagar
FROM CONTA_PAGAR c
LEFT JOIN (
    SELECT id_conta,SUM(valor_abatimento) total_abatimento
    FROM DEVOLUCAO_FORNECEDOR
    WHERE tipo='abatimento' AND status<>'cancelada'
    GROUP BY id_conta
) a ON a.id_conta=c.id_conta
WHERE c.status='aberta'
GROUP BY CASE WHEN c.data_vencimento<'2026-11-01' THEN 'vencida' ELSE 'a vencer' END;

-- G11 - Quantas perdas ainda estao com lote a confirmar e ha quanto tempo?
-- Atende: P1 e KPI11
SELECT p.id_perda,pr.nome AS produto,p.data_hora,p.quantidade,
       DATEDIFF('2026-11-01',DATE(p.data_hora)) AS dias_pendente
FROM PERDA p JOIN PRODUTO pr ON pr.id_produto=p.id_produto
WHERE p.status='valida' AND p.situacao_lote='lote_a_confirmar'
ORDER BY p.data_hora;

SELECT ROUND(
    SUM(status='valida' AND situacao_lote='lote_a_confirmar') /
    NULLIF(SUM(status='valida'),0) * 100,2
) AS percentual_perdas_pendentes
FROM PERDA;

-- G12 - Quais promocoes estao vigentes ou encerradas em 01/11/2026?
-- Atende: P2
SELECT pr.id_promocao,p.nome AS produto,l.codigo_lote,pr.preco_normal,pr.preco_promocional,
       pr.data_inicio,pr.data_fim,
       CASE WHEN '2026-11-01' BETWEEN pr.data_inicio AND pr.data_fim THEN 'vigente' ELSE 'encerrada' END AS situacao
FROM PROMOCAO pr
JOIN LOTE l ON l.id_lote=pr.id_lote
JOIN PRODUTO p ON p.id_produto=l.id_produto
ORDER BY pr.data_inicio;

-- ================================================================
-- 9. CONSULTAS DE AUDITORIA - A01 A A12
-- ================================================================

-- A01 - Existem perdas validas ainda sem lote confirmado?
-- Verifica: RN42 e RN52. Pode retornar pendencias legitimas.
SELECT id_perda,id_produto,data_hora,quantidade
FROM PERDA
WHERE status='valida' AND situacao_lote='lote_a_confirmar';

-- O saldo disponivel nao deve ficar negativo por acumulacao de pendencias.
SELECT * FROM vw_saldo_produto WHERE saldo_disponivel<0;

-- A02 - Existe pedido nao cancelado sem nenhum item?
-- Verifica: RN09
SELECT pc.id_pedido
FROM PEDIDO_COMPRA pc
LEFT JOIN ITEM_PEDIDO_COMPRA ip ON ip.id_pedido=pc.id_pedido
WHERE pc.status<>'cancelado'
GROUP BY pc.id_pedido
HAVING COUNT(ip.id_item_pedido)=0;

-- A03 - Existe venda concluida sem item ativo?
-- Verifica: RN23
SELECT v.id_venda
FROM VENDA v
LEFT JOIN ITEM_VENDA iv ON iv.id_venda=v.id_venda AND iv.status='ativo'
WHERE v.status='concluida'
GROUP BY v.id_venda
HAVING COUNT(iv.id_item_venda)=0;

-- A04 - Existe venda concluida cujo pagamento nao bate com o total?
-- Verifica: RN24
-- Como os valores sao DECIMAL(10,2), diferenca de um centavo tambem deve aparecer.
SELECT v.id_venda,v.valor_total,COALESCE(SUM(pg.valor),0) AS total_pago
FROM VENDA v LEFT JOIN PAGAMENTO pg ON pg.id_venda=v.id_venda
WHERE v.status='concluida'
GROUP BY v.id_venda,v.valor_total
HAVING v.valor_total<>COALESCE(SUM(pg.valor),0);

-- A05 - Existe lote ligado a produto diferente do item recebido?
-- Verifica: RN14 e regra de normalizacao
SELECT l.id_lote,l.id_produto,ir.id_produto AS produto_item
FROM LOTE l JOIN ITEM_RECEBIMENTO ir ON ir.id_item_recebimento=l.id_item_recebimento
WHERE l.id_produto<>ir.id_produto;

-- A06 - Existe lote com saldo negativo ou maior que a quantidade recebida?
-- Verifica: RN16 e RN17
SELECT id_lote,quantidade_recebida,quantidade_atual
FROM LOTE
WHERE quantidade_atual<0 OR quantidade_atual>quantidade_recebida;

-- A07 - Existe item recebido em que aceita + recusada difere da nota?
-- Verifica: RN12
SELECT id_item_recebimento,quantidade_nf,quantidade_aceita,quantidade_recusada
FROM ITEM_RECEBIMENTO
WHERE quantidade_nf<>quantidade_aceita+quantidade_recusada;

-- A08 - Algum item devolvido ultrapassa a quantidade recusada?
-- Verifica: RN37
SELECT ir.id_item_recebimento,ir.quantidade_recusada,COALESCE(SUM(idv.quantidade),0) AS total_devolvido
FROM ITEM_RECEBIMENTO ir
JOIN ITEM_DEVOLUCAO idv ON idv.id_item_recebimento=ir.id_item_recebimento
GROUP BY ir.id_item_recebimento,ir.quantidade_recusada
HAVING SUM(idv.quantidade)>ir.quantidade_recusada;

-- Complemento da A07 - A soma dos lotes passa da quantidade aceita do item?
SELECT ir.id_item_recebimento,ir.quantidade_aceita,COALESCE(SUM(l.quantidade_recebida),0) AS total_lotes
FROM ITEM_RECEBIMENTO ir
LEFT JOIN LOTE l ON l.id_item_recebimento=ir.id_item_recebimento
GROUP BY ir.id_item_recebimento,ir.quantidade_aceita
HAVING COALESCE(SUM(l.quantidade_recebida),0)>ir.quantidade_aceita;

-- Complemento da A08 - A soma dos abatimentos passa do valor da conta?
SELECT c.id_conta,c.valor,COALESCE(SUM(df.valor_abatimento),0) AS total_abatimentos
FROM CONTA_PAGAR c
JOIN DEVOLUCAO_FORNECEDOR df ON df.id_conta=c.id_conta
WHERE df.tipo='abatimento' AND df.status<>'cancelada'
GROUP BY c.id_conta,c.valor
HAVING COALESCE(SUM(df.valor_abatimento),0)>c.valor;

-- A09 - Existe saida de lote com origem incoerente com o tipo?
-- Verifica: RN17 e RN28
SELECT sl.*
FROM SAIDA_LOTE sl
LEFT JOIN SAIDA_LOTE orig ON orig.id_saida_lote=sl.id_saida_original
WHERE NOT (
    (sl.tipo='venda' AND sl.id_item_venda IS NOT NULL AND sl.id_perda IS NULL AND sl.id_saida_original IS NULL)
 OR (sl.tipo='perda' AND sl.id_item_venda IS NULL AND sl.id_perda IS NOT NULL AND sl.id_saida_original IS NULL)
 OR (sl.tipo='estorno' AND sl.id_item_venda IS NULL AND sl.id_perda IS NULL AND sl.id_saida_original IS NOT NULL
     AND orig.tipo<>'estorno' AND orig.id_lote=sl.id_lote AND orig.quantidade=sl.quantidade)
);

-- A10 - Existe venda cancelada com baixa de venda ainda sem estorno?
-- Verifica: RN54
SELECT v.id_venda,sl.id_saida_lote
FROM VENDA v
JOIN ITEM_VENDA iv ON iv.id_venda=v.id_venda AND iv.status='ativo'
JOIN SAIDA_LOTE sl ON sl.id_item_venda=iv.id_item_venda AND sl.tipo='venda'
LEFT JOIN SAIDA_LOTE est ON est.id_saida_original=sl.id_saida_lote
WHERE v.status='cancelada' AND est.id_saida_lote IS NULL;

-- A11 - Existe sessao fechada sem dados de fechamento?
-- Verifica: RN32 e RN56
SELECT id_sessao
FROM SESSAO_CAIXA
WHERE status='fechada' AND (data_fechamento IS NULL OR id_funcionario_fechamento IS NULL OR valor_esperado IS NULL OR valor_contado IS NULL);

-- A12 - Existe conta paga sem forma, data ou funcionario de pagamento?
-- Verifica: RN35 e RN56
SELECT id_conta
FROM CONTA_PAGAR
WHERE status='paga' AND (id_forma IS NULL OR data_pagamento IS NULL OR id_funcionario_pagamento IS NULL);

-- ================================================================

-- A carga acima e uma importacao historica administrativa. A partir daqui,
-- estas protecoes exigem o fluxo de venda em andamento para novas operacoes.
DELIMITER $$
CREATE TRIGGER trg_venda_bi_status
BEFORE INSERT ON VENDA FOR EACH ROW
BEGIN
 IF NEW.status<>'em_andamento' OR NEW.valor_total<>0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nova venda deve iniciar em andamento e sem total';
 END IF;
END$$
CREATE TRIGGER trg_venda_bu_fluxo
BEFORE UPDATE ON VENDA FOR EACH ROW
BEGIN
 IF OLD.status='cancelada' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venda cancelada nao pode ser alterada';
 END IF;
 IF NEW.id_sessao<>OLD.id_sessao OR NEW.id_funcionario_operador<>OLD.id_funcionario_operador OR NEW.data_hora<>OLD.data_hora THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Origem da venda nao pode ser alterada';
 END IF;
 IF OLD.status='concluida' AND NEW.status<>'cancelada' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venda concluida somente pode ser cancelada';
 END IF;
 IF NEW.status='concluida' THEN
  IF NOT EXISTS(SELECT 1 FROM ITEM_VENDA WHERE id_venda=OLD.id_venda AND status='ativo')
    OR NEW.valor_total<>(SELECT COALESCE(SUM(subtotal),0) FROM ITEM_VENDA WHERE id_venda=OLD.id_venda AND status='ativo')
    OR NEW.valor_total<>(SELECT COALESCE(SUM(valor),0) FROM PAGAMENTO WHERE id_venda=OLD.id_venda)
    OR EXISTS(SELECT 1 FROM ITEM_VENDA i WHERE i.id_venda=OLD.id_venda AND i.status='ativo' AND i.quantidade_ou_peso<>(SELECT COALESCE(SUM(sl.quantidade),0) FROM SAIDA_LOTE sl WHERE sl.id_item_venda=i.id_item_venda AND sl.tipo='venda')) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Conclusao exige itens pagamentos e baixas correspondentes';
  END IF;
 END IF;
 IF NEW.status='cancelada' THEN
  IF OLD.status<>'concluida' OR NOT EXISTS(SELECT 1 FROM FUNCIONARIO WHERE id_funcionario=NEW.id_funcionario_supervisor AND ativo=1 AND perfil_acesso IN ('supervisor','gerencia'))
    OR EXISTS(SELECT 1 FROM SAIDA_LOTE sl JOIN ITEM_VENDA i USING(id_item_venda) WHERE i.id_venda=OLD.id_venda AND sl.tipo='venda' AND NOT EXISTS(SELECT 1 FROM SAIDA_LOTE e WHERE e.id_saida_original=sl.id_saida_lote)) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cancelamento exige autorizacao e estorno completo';
  END IF;
 END IF;
END$$
CREATE TRIGGER trg_venda_au_fiscal
AFTER UPDATE ON VENDA FOR EACH ROW
BEGIN
 IF NEW.status='cancelada' AND OLD.status<>'cancelada' THEN
  UPDATE DOCUMENTO_FISCAL SET situacao='cancelado' WHERE id_venda=NEW.id_venda;
 END IF;
END$$
CREATE TRIGGER trg_item_venda_bi_fluxo
BEFORE INSERT ON ITEM_VENDA FOR EACH ROW
BEGIN
 IF NOT EXISTS(SELECT 1 FROM VENDA WHERE id_venda=NEW.id_venda AND status='em_andamento') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Itens somente em venda em andamento';
 END IF;
END$$
CREATE TRIGGER trg_item_venda_bu_fluxo
BEFORE UPDATE ON ITEM_VENDA FOR EACH ROW
BEGIN
 IF NEW.id_venda<>OLD.id_venda OR NOT EXISTS(SELECT 1 FROM VENDA WHERE id_venda=OLD.id_venda AND status='em_andamento') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Item de venda encerrada nao pode ser alterado';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM PRODUTO WHERE id_produto=NEW.id_produto AND ativo=1) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto inativo';
 END IF;
 IF (SELECT tipo_venda FROM PRODUTO WHERE id_produto=NEW.id_produto)='unidade' AND NEW.quantidade_ou_peso<>FLOOR(NEW.quantidade_ou_peso) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Produto por unidade exige quantidade inteira';
 END IF;
END$$
CREATE TRIGGER trg_item_venda_bd_historico
BEFORE DELETE ON ITEM_VENDA FOR EACH ROW
BEGIN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Itens devem ser cancelados e nao excluidos';
END$$
CREATE TRIGGER trg_perda_bd_historico
BEFORE DELETE ON PERDA FOR EACH ROW
BEGIN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Perda deve ser substituida e nao excluida';
END$$
CREATE TRIGGER trg_perda_bu_saldo
BEFORE UPDATE ON PERDA FOR EACH ROW
BEGIN
 DECLARE v_id INT;
 DECLARE v_saldo DECIMAL(10,3);
 SELECT id_produto INTO v_id FROM PRODUTO WHERE id_produto=NEW.id_produto FOR UPDATE;
 IF NEW.status='valida' AND NEW.situacao_lote='lote_a_confirmar' THEN
  SELECT COALESCE(SUM(quantidade_atual),0) INTO v_saldo FROM LOTE WHERE id_produto=NEW.id_produto;
  SELECT v_saldo-COALESCE(SUM(quantidade),0) INTO v_saldo FROM PERDA WHERE id_produto=NEW.id_produto AND id_perda<>OLD.id_perda AND status='valida' AND situacao_lote='lote_a_confirmar';
  IF NEW.quantidade>v_saldo THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Perda pendente maior que saldo disponivel';
  END IF;
 END IF;
END$$
CREATE TRIGGER trg_pedido_bu_fornecedor
BEFORE UPDATE ON PEDIDO_COMPRA FOR EACH ROW
BEGIN
 IF NEW.id_fornecedor<>OLD.id_fornecedor AND NOT EXISTS(SELECT 1 FROM FORNECEDOR WHERE id_fornecedor=NEW.id_fornecedor AND ativo=1) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fornecedor inativo';
 END IF;
END$$
CREATE TRIGGER trg_pagamento_bi_fluxo
BEFORE INSERT ON PAGAMENTO FOR EACH ROW
BEGIN
 IF NOT EXISTS(SELECT 1 FROM VENDA WHERE id_venda=NEW.id_venda AND status='em_andamento') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pagamento exige venda em andamento';
 END IF;
END$$
CREATE TRIGGER trg_pagamento_bu_fluxo
BEFORE UPDATE ON PAGAMENTO FOR EACH ROW
BEGIN
 IF NEW.id_venda<>OLD.id_venda OR NOT EXISTS(SELECT 1 FROM VENDA WHERE id_venda=OLD.id_venda AND status='em_andamento') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pagamento de venda encerrada nao pode ser alterado';
 END IF;
END$$
DELIMITER ;

-- 10. PERFIS DE ACESSO (ROLES)
-- ================================================================

CREATE ROLE IF NOT EXISTS 'role_caixa','role_retaguarda','role_gerencia';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'role_caixa','role_retaguarda','role_gerencia';

GRANT SELECT ON hortifruti_uniao.PRODUTO TO 'role_caixa';
GRANT SELECT ON hortifruti_uniao.FORMA_PAGAMENTO TO 'role_caixa';
GRANT SELECT,INSERT ON hortifruti_uniao.VENDA TO 'role_caixa';
GRANT SELECT,INSERT,UPDATE ON hortifruti_uniao.ITEM_VENDA TO 'role_caixa';
GRANT SELECT,INSERT ON hortifruti_uniao.PAGAMENTO TO 'role_caixa';

GRANT SELECT,INSERT,UPDATE ON hortifruti_uniao.PEDIDO_COMPRA TO 'role_retaguarda';
GRANT SELECT,INSERT,UPDATE ON hortifruti_uniao.ITEM_PEDIDO_COMPRA TO 'role_retaguarda';
GRANT SELECT ON hortifruti_uniao.RECEBIMENTO TO 'role_retaguarda';
GRANT SELECT ON hortifruti_uniao.ITEM_RECEBIMENTO TO 'role_retaguarda';
GRANT SELECT ON hortifruti_uniao.LOTE TO 'role_retaguarda';
GRANT SELECT,INSERT,UPDATE ON hortifruti_uniao.CONTA_PAGAR TO 'role_retaguarda';

GRANT SELECT ON hortifruti_uniao.* TO 'role_gerencia';
GRANT SELECT ON hortifruti_uniao.PERDA TO 'role_gerencia';
GRANT INSERT,UPDATE ON hortifruti_uniao.PROMOCAO TO 'role_gerencia';
GRANT SELECT (id_funcionario,nome,cargo,id_setor,perfil_acesso,ativo) ON hortifruti_uniao.FUNCIONARIO TO 'role_caixa';
GRANT SELECT (id_fornecedor,razao_social,ativo) ON hortifruti_uniao.FORNECEDOR TO 'role_caixa';

-- Observacao: o trabalho nao cria usuarios MySQL reais nem liga usuario ao funcionario.
-- As roles mostram apenas como as permissoes poderiam ser separadas por perfil.

GRANT EXECUTE ON PROCEDURE hortifruti_uniao.concluir_venda TO 'role_caixa';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.registrar_recebimento TO 'role_retaguarda';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.adicionar_lote_recebimento TO 'role_retaguarda';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.registrar_abatimento_fornecedor TO 'role_retaguarda';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.cancelar_venda TO 'role_gerencia';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.fechar_sessao TO 'role_gerencia';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.registrar_perda_pendente TO 'role_gerencia';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.confirmar_lote_perda TO 'role_gerencia';
GRANT EXECUTE ON PROCEDURE hortifruti_uniao.estornar_saida TO 'role_gerencia';
