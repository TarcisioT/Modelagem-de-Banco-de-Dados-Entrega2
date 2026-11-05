# Dicionário de Dados — Hortifruti União

## Entrega 2 — Modelagem de Banco de Dados

### 1. Apresentação

**SGBD utilizado na validação:** MySQL 8.0.46  
**Compatibilidade do script:** MySQL 8.0.16 ou superior  
**Data da última revisão:** 05/11/2026

Este documento descreve a estrutura final do banco `hortifruti_uniao`, conforme o arquivo `script.sql` da Entrega 2. O projeto é acadêmico, usa dados fictícios e não possui integração com o sistema operacional do mercado.

A versão documentada contém **27 tabelas**, **193 colunas**, **27 chaves primárias** e **53 chaves estrangeiras**. O script também define **62 restrições `CHECK`**, **17 ocorrências de unicidade (`UNIQUE`)**, uma view de saldo, índices, triggers e procedures.

Os dois problemas centrais do trabalho são: **P1 — falta de controle sobre a perda de produtos** e **P2 — falta de controle de validade dos produtos**. As tabelas de perdas, lotes, recebimentos e saídas por lote dão a rastreabilidade necessária para as consultas gerenciais e auditorias do projeto.

### 2. Convenções utilizadas

- **PK**: chave primária.
- **FK**: chave estrangeira.
- **UQ**: valor ou combinação de valores com restrição `UNIQUE`.
- **NULL = Não**: o campo é obrigatório no esquema.
- **NULL = Sim**: o campo pode ficar sem valor.
- **Gerado**: valor calculado pelo próprio MySQL (`GENERATED ALWAYS AS`).
- Todas as FKs do script usam `ON DELETE RESTRICT`.

### 3. Resumo das tabelas

| Tabela | Finalidade | Colunas | FKs |
|---|---|---:|---:|
| `SETOR` | Cadastrar os setores do mercado e parametrizar quais setores vendem produtos e o prazo de alerta de validade. | 5 | 0 |
| `PRODUTO` | Cadastrar os produtos comercializados, seus dados de identificação, preço, estoque mínimo e regras básicas de venda. | 11 | 1 |
| `FORNECEDOR` | Cadastrar os fornecedores do mercado. | 7 | 0 |
| `FORNECEDOR_PRODUTO` | Representar a associação entre fornecedores e produtos, incluindo código do produto no fornecedor e último custo conhecido. | 5 | 2 |
| `FUNCIONARIO` | Cadastrar os funcionários, o setor de lotação, o perfil de acesso e a situação ativa/inativa. | 9 | 1 |
| `ESCALA` | Registrar dias de trabalho ou folga e horários previstos por funcionário. | 6 | 1 |
| `FORMA_PAGAMENTO` | Cadastrar formas de pagamento e indicar se podem ser usadas em vendas, pagamentos a fornecedores ou ambos. | 4 | 0 |
| `CAIXA` | Cadastrar os caixas físicos disponíveis no mercado. | 3 | 0 |
| `PEDIDO_COMPRA` | Registrar pedidos de compra feitos a fornecedores e o funcionário responsável. | 5 | 2 |
| `ITEM_PEDIDO_COMPRA` | Registrar os produtos, quantidades e custos previstos de cada pedido de compra. | 5 | 2 |
| `RECEBIMENTO` | Registrar o recebimento de mercadorias e os dados da nota fiscal de entrada. | 10 | 3 |
| `ITEM_RECEBIMENTO` | Registrar os produtos conferidos em cada recebimento, separando quantidades aceitas e recusadas. | 8 | 2 |
| `CONTA_PAGAR` | Registrar a obrigação financeira gerada por um recebimento e seu eventual pagamento. | 8 | 3 |
| `DEVOLUCAO_FORNECEDOR` | Registrar devoluções, trocas ou abatimentos relacionados a um recebimento. | 9 | 3 |
| `ITEM_DEVOLUCAO` | Registrar quais itens recebidos e quais quantidades fazem parte de uma devolução ao fornecedor. | 5 | 2 |
| `LOTE` | Controlar os lotes gerados a partir do recebimento, com validade, custo e saldo atual. | 9 | 2 |
| `MOTIVO_PERDA` | Cadastrar os motivos padronizados usados no registro de perdas. | 3 | 0 |
| `PERDA` | Registrar perdas de produtos, incluindo setor, motivo, funcionário, lote quando conhecido e valor estimado. | 13 | 6 |
| `PROMOCAO` | Registrar promoções vinculadas a lotes, com período e preço promocional. | 7 | 2 |
| `SESSAO_CAIXA` | Registrar abertura e fechamento de uma sessão de caixa, responsáveis e valores de conferência. | 12 | 3 |
| `TROCA_OPERADOR` | Registrar trocas de operador dentro de uma sessão de caixa. | 5 | 3 |
| `SANGRIA` | Registrar retiradas de numerário realizadas durante uma sessão de caixa. | 5 | 2 |
| `VENDA` | Registrar vendas vinculadas a uma sessão de caixa, operador e eventual cancelamento por supervisor. | 9 | 3 |
| `ITEM_VENDA` | Registrar os itens de cada venda, preservando quantidade/peso, preço praticado, subtotal e eventual cancelamento do item. | 10 | 3 |
| `PAGAMENTO` | Registrar uma ou mais formas de pagamento usadas em uma venda. | 4 | 2 |
| `DOCUMENTO_FISCAL` | Registrar os dados do documento fiscal associado a uma venda. | 8 | 1 |
| `SAIDA_LOTE` | Registrar as baixas de estoque por lote decorrentes de venda, perda ou estorno, preservando a rastreabilidade da movimentação. | 8 | 4 |

### 4. Estrutura detalhada das tabelas

#### 4.1 SETOR

**Finalidade:** Cadastrar os setores do mercado e parametrizar quais setores vendem produtos e o prazo de alerta de validade.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_setor` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de setor. |
| `nome` | `VARCHAR(60)` | UQ | Não | — | Nome do registro. |
| `descricao` | `VARCHAR(150)` | — | Sim | — | Descrição textual do registro. |
| `dias_alerta_validade` | `INT UNSIGNED` | — | Sim | — | Quantidade de dias usada como referência para alerta de produtos próximos do vencimento. |
| `vende_produto` | `TINYINT(1)` | — | Não | `1` | Indica se o setor é um setor de venda de produtos (1) ou não (0). |

**Unicidade:**
- `nome` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(vende_produto IN (0,1))`

#### 4.2 PRODUTO

**Finalidade:** Cadastrar os produtos comercializados, seus dados de identificação, preço, estoque mínimo e regras básicas de venda.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_produto` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de produto. |
| `id_setor` | `INT UNSIGNED` | FK | Não | — | Identificador do setor. |
| `codigo_interno` | `VARCHAR(20)` | UQ | Não | — | Código interno do produto. |
| `codigo_barras` | `VARCHAR(20)` | UQ | Sim | — | Código de barras do produto, quando houver. |
| `nome` | `VARCHAR(100)` | — | Não | — | Nome do registro. |
| `preco_venda` | `DECIMAL(10,2)` | — | Não | — | Preço de venda atual do produto. |
| `estoque_minimo` | `DECIMAL(10,3)` | — | Não | `0` | Estoque mínimo de referência para o produto. |
| `tipo_venda` | `VARCHAR(10)` | — | Não | — | Forma de comercialização do produto: por unidade ou por quilograma. |
| `tem_validade_impressa` | `TINYINT(1)` | — | Não | `1` | Indica se o produto normalmente possui validade impressa. |
| `venda_restrita_idade` | `TINYINT(1)` | — | Não | `0` | Indica se o produto exige restrição de venda por idade. |
| `ativo` | `TINYINT(1)` | — | Não | `1` | Indica se o cadastro está ativo (1) ou inativo (0). |

**Chaves estrangeiras:**
- `id_setor` → `SETOR.id_setor` (`ON DELETE RESTRICT`).

**Unicidade:**
- `codigo_interno` possui `UNIQUE`.
- `codigo_barras` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(preco_venda > 0)`
- `(estoque_minimo >= 0)`
- `(tipo_venda IN ('unidade','kg'))`
- `(tem_validade_impressa IN (0,1))`
- `(venda_restrita_idade IN (0,1))`
- `(ativo IN (0,1))`

#### 4.3 FORNECEDOR

**Finalidade:** Cadastrar os fornecedores do mercado.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_fornecedor` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de fornecedor. |
| `razao_social` | `VARCHAR(120)` | — | Não | — | Razão social do fornecedor. |
| `cnpj` | `VARCHAR(18)` | UQ | Não | — | CNPJ do fornecedor. |
| `telefone` | `VARCHAR(20)` | — | Sim | — | Telefone de contato. |
| `email` | `VARCHAR(120)` | — | Sim | — | Endereço de e-mail. |
| `endereco` | `VARCHAR(200)` | — | Sim | — | Endereço do fornecedor. |
| `ativo` | `TINYINT(1)` | — | Não | `1` | Indica se o cadastro está ativo (1) ou inativo (0). |

**Unicidade:**
- `cnpj` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(ativo IN (0,1))`

#### 4.4 FORNECEDOR_PRODUTO

**Finalidade:** Representar a associação entre fornecedores e produtos, incluindo código do produto no fornecedor e último custo conhecido.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_fornecedor_produto` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de fornecedor produto. |
| `id_fornecedor` | `INT UNSIGNED` | FK | Não | — | Identificador do fornecedor. |
| `id_produto` | `INT UNSIGNED` | FK | Não | — | Identificador do produto. |
| `codigo_no_fornecedor` | `VARCHAR(30)` | — | Sim | — | Código pelo qual o fornecedor identifica esse produto. |
| `ultimo_custo` | `DECIMAL(10,2)` | — | Sim | — | Último custo conhecido do produto para esse fornecedor. |

**Chaves estrangeiras:**
- `id_fornecedor` → `FORNECEDOR.id_fornecedor` (`ON DELETE RESTRICT`).
- `id_produto` → `PRODUTO.id_produto` (`ON DELETE RESTRICT`).

**Unicidade:**
- `CONSTRAINT uq_fornecedor_produto UNIQUE (id_fornecedor,id_produto)`

**Restrições `CHECK`:**
- `(ultimo_custo IS NULL OR ultimo_custo >= 0)`

#### 4.5 FUNCIONARIO

**Finalidade:** Cadastrar os funcionários, o setor de lotação, o perfil de acesso e a situação ativa/inativa.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_funcionario` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de funcionario. |
| `id_setor` | `INT UNSIGNED` | FK | Não | — | Identificador do setor. |
| `nome` | `VARCHAR(100)` | — | Não | — | Nome do registro. |
| `cpf` | `VARCHAR(14)` | UQ | Não | — | CPF do funcionário. |
| `cargo` | `VARCHAR(60)` | — | Não | — | Cargo do funcionário. |
| `telefone` | `VARCHAR(20)` | — | Sim | — | Telefone de contato. |
| `data_admissao` | `DATE` | — | Não | — | Data de admissão do funcionário. |
| `perfil_acesso` | `VARCHAR(20)` | — | Não | — | Perfil funcional previsto no banco: operador, supervisor, repositor, retaguarda ou gerência. |
| `ativo` | `TINYINT(1)` | — | Não | `1` | Indica se o cadastro está ativo (1) ou inativo (0). |

**Chaves estrangeiras:**
- `id_setor` → `SETOR.id_setor` (`ON DELETE RESTRICT`).

**Unicidade:**
- `cpf` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(perfil_acesso IN ('operador','supervisor','repositor','retaguarda','gerencia'))`
- `(ativo IN (0,1))`

#### 4.6 ESCALA

**Finalidade:** Registrar dias de trabalho ou folga e horários previstos por funcionário.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_escala` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de escala. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `data` | `DATE` | — | Não | — | Data do registro. |
| `tipo` | `VARCHAR(10)` | — | Não | — | Tipo de escala do dia: trabalho ou folga. |
| `hora_inicio` | `TIME` | — | Sim | — | Horário inicial da jornada. |
| `hora_fim` | `TIME` | — | Sim | — | Horário final da jornada. |

**Chaves estrangeiras:**
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Unicidade:**
- `CONSTRAINT uq_escala_func_data UNIQUE (id_funcionario,data)`

**Restrições `CHECK`:**
- `(tipo IN ('trabalho','folga'))`
- `((tipo='trabalho' AND hora_inicio IS NOT NULL AND hora_fim IS NOT NULL AND hora_fim > hora_inicio) OR (tipo='folga' AND hora_inicio IS NULL AND hora_fim IS NULL))`

#### 4.7 FORMA_PAGAMENTO

**Finalidade:** Cadastrar formas de pagamento e indicar se podem ser usadas em vendas, pagamentos a fornecedores ou ambos.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_forma` | `INT UNSIGNED` | PK | Não | — | Identificador da forma de pagamento. |
| `descricao` | `VARCHAR(50)` | UQ | Não | — | Descrição textual do registro. |
| `uso` | `VARCHAR(12)` | — | Não | — | Contexto em que a forma pode ser usada: venda, fornecedor ou ambos. |
| `ativo` | `TINYINT(1)` | — | Não | `1` | Indica se o cadastro está ativo (1) ou inativo (0). |

**Unicidade:**
- `descricao` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(uso IN ('venda','fornecedor','ambos'))`
- `(ativo IN (0,1))`

#### 4.8 CAIXA

**Finalidade:** Cadastrar os caixas físicos disponíveis no mercado.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_caixa` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de caixa. |
| `numero` | `INT UNSIGNED` | UQ | Não | — | Número do caixa. |
| `ativo` | `TINYINT(1)` | — | Não | `1` | Indica se o cadastro está ativo (1) ou inativo (0). |

**Unicidade:**
- `numero` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(ativo IN (0,1))`

#### 4.9 PEDIDO_COMPRA

**Finalidade:** Registrar pedidos de compra feitos a fornecedores e o funcionário responsável.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_pedido` | `INT UNSIGNED` | PK | Não | — | Identificador do pedido de compra. |
| `id_fornecedor` | `INT UNSIGNED` | FK | Não | — | Identificador do fornecedor. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `data_pedido` | `DATE` | — | Não | — | Data do pedido de compra. |
| `status` | `VARCHAR(12)` | — | Não | `'aberto'` | Situação do pedido: aberto, parcial, recebido ou cancelado. |

**Chaves estrangeiras:**
- `id_fornecedor` → `FORNECEDOR.id_fornecedor` (`ON DELETE RESTRICT`).
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(status IN ('aberto','parcial','recebido','cancelado'))`

#### 4.10 ITEM_PEDIDO_COMPRA

**Finalidade:** Registrar os produtos, quantidades e custos previstos de cada pedido de compra.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_item_pedido` | `INT UNSIGNED` | PK | Não | — | Identificador do item do pedido de compra. |
| `id_pedido` | `INT UNSIGNED` | FK | Não | — | Identificador do pedido de compra. |
| `id_produto` | `INT UNSIGNED` | FK | Não | — | Identificador do produto. |
| `quantidade` | `DECIMAL(10,3)` | — | Não | — | Quantidade registrada na operação. |
| `custo_previsto` | `DECIMAL(10,2)` | — | Não | — | Custo unitário previsto no pedido. |

**Chaves estrangeiras:**
- `id_pedido` → `PEDIDO_COMPRA.id_pedido` (`ON DELETE RESTRICT`).
- `id_produto` → `PRODUTO.id_produto` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(quantidade > 0)`
- `(custo_previsto >= 0)`

#### 4.11 RECEBIMENTO

**Finalidade:** Registrar o recebimento de mercadorias e os dados da nota fiscal de entrada.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_recebimento` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de recebimento. |
| `id_fornecedor` | `INT UNSIGNED` | FK | Não | — | Identificador do fornecedor. |
| `id_pedido` | `INT UNSIGNED` | FK | Sim | — | Identificador do pedido de compra. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `numero_nf` | `VARCHAR(30)` | — | Não | — | Número da nota fiscal de entrada. |
| `serie` | `VARCHAR(10)` | — | Não | — | Série do documento fiscal. |
| `chave_acesso` | `VARCHAR(44)` | UQ | Sim | — | Chave de acesso da nota fiscal de entrada, quando disponível. |
| `data_emissao` | `DATE` | — | Não | — | Data de emissão do documento. |
| `data_recebimento` | `DATETIME` | — | Não | — | Data e horário do recebimento. |
| `valor_total` | `DECIMAL(10,2)` | — | Não | — | Valor total do registro. |

**Chaves estrangeiras:**
- `id_fornecedor` → `FORNECEDOR.id_fornecedor` (`ON DELETE RESTRICT`).
- `id_pedido` → `PEDIDO_COMPRA.id_pedido` (`ON DELETE RESTRICT`).
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Unicidade:**
- `chave_acesso` possui `UNIQUE`.
- `CONSTRAINT uq_recebimento_nf UNIQUE (id_fornecedor,numero_nf,serie)`

**Restrições `CHECK`:**
- `(valor_total >= 0)`

#### 4.12 ITEM_RECEBIMENTO

**Finalidade:** Registrar os produtos conferidos em cada recebimento, separando quantidades aceitas e recusadas.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_item_recebimento` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de item recebimento. |
| `id_recebimento` | `INT UNSIGNED` | FK | Não | — | Identificador do recebimento. |
| `id_produto` | `INT UNSIGNED` | FK | Não | — | Identificador do produto. |
| `quantidade_nf` | `DECIMAL(10,3)` | — | Não | — | Quantidade informada na nota fiscal para o produto. |
| `quantidade_aceita` | `DECIMAL(10,3)` | — | Não | — | Quantidade aceita após a conferência do recebimento. |
| `quantidade_recusada` | `DECIMAL(10,3)` | — | Não | `0` | Quantidade recusada durante a conferência. |
| `custo_unitario_nf` | `DECIMAL(10,2)` | — | Não | — | Custo unitário informado na nota fiscal. |
| `observacao_divergencia` | `VARCHAR(200)` | — | Sim | — | Observação sobre divergência encontrada na conferência. |

**Chaves estrangeiras:**
- `id_recebimento` → `RECEBIMENTO.id_recebimento` (`ON DELETE RESTRICT`).
- `id_produto` → `PRODUTO.id_produto` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(quantidade_nf > 0)`
- `(quantidade_aceita >= 0)`
- `(quantidade_recusada >= 0)`
- `(quantidade_nf = quantidade_aceita + quantidade_recusada)`
- `(custo_unitario_nf >= 0)`

#### 4.13 CONTA_PAGAR

**Finalidade:** Registrar a obrigação financeira gerada por um recebimento e seu eventual pagamento.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_conta` | `INT UNSIGNED` | PK | Não | — | Identificador da conta a pagar. |
| `id_recebimento` | `INT UNSIGNED` | FK + UQ | Não | — | Identificador do recebimento. |
| `id_forma` | `INT UNSIGNED` | FK | Sim | — | Identificador da forma de pagamento. |
| `id_funcionario_pagamento` | `INT UNSIGNED` | FK | Sim | — | Funcionário responsável por registrar o pagamento da conta. |
| `data_vencimento` | `DATE` | — | Não | — | Data de vencimento da conta. |
| `valor` | `DECIMAL(10,2)` | — | Não | — | Valor monetário do registro. |
| `data_pagamento` | `DATETIME` | — | Sim | — | Data e horário do pagamento. |
| `status` | `VARCHAR(10)` | — | Não | `'aberta'` | Situação da conta: aberta, paga ou cancelada. |

**Chaves estrangeiras:**
- `id_recebimento` → `RECEBIMENTO.id_recebimento` (`ON DELETE RESTRICT`).
- `id_forma` → `FORMA_PAGAMENTO.id_forma` (`ON DELETE RESTRICT`).
- `id_funcionario_pagamento` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Unicidade:**
- `id_recebimento` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(valor > 0)`
- `(status IN ('aberta','paga','cancelada'))`
- `((status='paga' AND data_pagamento IS NOT NULL AND id_forma IS NOT NULL AND id_funcionario_pagamento IS NOT NULL) OR (status<>'paga' AND data_pagamento IS NULL))`

#### 4.14 DEVOLUCAO_FORNECEDOR

**Finalidade:** Registrar devoluções, trocas ou abatimentos relacionados a um recebimento.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_devolucao` | `INT UNSIGNED` | PK | Não | — | Identificador da devolução ao fornecedor. |
| `id_recebimento` | `INT UNSIGNED` | FK | Não | — | Identificador do recebimento. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `id_conta` | `INT UNSIGNED` | FK | Sim | — | Identificador da conta a pagar. |
| `data` | `DATE` | — | Não | — | Data do registro. |
| `tipo` | `VARCHAR(12)` | — | Não | — | Tipo da ocorrência: devolução, troca ou abatimento. |
| `motivo` | `VARCHAR(200)` | — | Não | — | Motivo informado para a operação. |
| `valor_abatimento` | `DECIMAL(10,2)` | — | Sim | — | Valor do abatimento financeiro, preenchido apenas quando o tipo for abatimento. |
| `status` | `VARCHAR(12)` | — | Não | `'aberta'` | Situação da devolução: aberta, concluída ou cancelada. |

**Chaves estrangeiras:**
- `id_recebimento` → `RECEBIMENTO.id_recebimento` (`ON DELETE RESTRICT`).
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).
- `id_conta` → `CONTA_PAGAR.id_conta` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(tipo IN ('devolucao','troca','abatimento'))`
- `(status IN ('aberta','concluida','cancelada'))`
- `((tipo='abatimento' AND valor_abatimento IS NOT NULL AND valor_abatimento > 0 AND id_conta IS NOT NULL) OR (tipo<>'abatimento' AND valor_abatimento IS NULL AND id_conta IS NULL))`

#### 4.15 ITEM_DEVOLUCAO

**Finalidade:** Registrar quais itens recebidos e quais quantidades fazem parte de uma devolução ao fornecedor.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_item_devolucao` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de item devolucao. |
| `id_devolucao` | `INT UNSIGNED` | FK | Não | — | Identificador da devolução ao fornecedor. |
| `id_item_recebimento` | `INT UNSIGNED` | FK | Não | — | Identificador do item de recebimento. |
| `quantidade` | `DECIMAL(10,3)` | — | Não | — | Quantidade registrada na operação. |
| `observacao` | `VARCHAR(200)` | — | Sim | — | Observação complementar. |

**Chaves estrangeiras:**
- `id_devolucao` → `DEVOLUCAO_FORNECEDOR.id_devolucao` (`ON DELETE RESTRICT`).
- `id_item_recebimento` → `ITEM_RECEBIMENTO.id_item_recebimento` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(quantidade > 0)`

#### 4.16 LOTE

**Finalidade:** Controlar os lotes gerados a partir do recebimento, com validade, custo e saldo atual.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_lote` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de lote. |
| `id_item_recebimento` | `INT UNSIGNED` | FK | Não | — | Item de recebimento que originou o lote. |
| `id_produto` | `INT UNSIGNED` | FK | Não | — | Identificador do produto. |
| `codigo_lote` | `VARCHAR(40)` | — | Sim | — | Código do lote informado pelo fabricante/fornecedor, quando existir. |
| `data_fabricacao` | `DATE` | — | Sim | — | Data de fabricação do lote, quando conhecida. |
| `data_validade` | `DATE` | — | Sim | — | Data de validade do lote, quando aplicável. |
| `quantidade_recebida` | `DECIMAL(10,3)` | — | Não | — | Quantidade inicialmente registrada no lote. |
| `quantidade_atual` | `DECIMAL(10,3)` | — | Não | — | Saldo físico atual do lote após as movimentações registradas. |
| `custo_unitario` | `DECIMAL(10,2)` | — | Não | — | Custo unitário do produto no lote. |

**Chaves estrangeiras:**
- `id_item_recebimento` → `ITEM_RECEBIMENTO.id_item_recebimento` (`ON DELETE RESTRICT`).
- `id_produto` → `PRODUTO.id_produto` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(quantidade_recebida > 0)`
- `(quantidade_atual >= 0 AND quantidade_atual <= quantidade_recebida)`
- `(custo_unitario >= 0)`
- `(data_validade IS NULL OR data_fabricacao IS NULL OR data_validade >= data_fabricacao)`

#### 4.17 MOTIVO_PERDA

**Finalidade:** Cadastrar os motivos padronizados usados no registro de perdas.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_motivo` | `INT UNSIGNED` | PK | Não | — | Identificador do motivo de perda. |
| `descricao` | `VARCHAR(80)` | UQ | Não | — | Descrição textual do registro. |
| `ativo` | `TINYINT(1)` | — | Não | `1` | Indica se o cadastro está ativo (1) ou inativo (0). |

**Unicidade:**
- `descricao` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(ativo IN (0,1))`

#### 4.18 PERDA

**Finalidade:** Registrar perdas de produtos, incluindo setor, motivo, funcionário, lote quando conhecido e valor estimado.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_perda` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de perda. |
| `id_produto` | `INT UNSIGNED` | FK | Não | — | Identificador do produto. |
| `id_setor` | `INT UNSIGNED` | FK | Não | — | Identificador do setor. |
| `id_motivo` | `INT UNSIGNED` | FK | Não | — | Identificador do motivo de perda. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `id_lote` | `INT UNSIGNED` | FK | Sim | — | Identificador do lote. |
| `id_perda_original` | `INT UNSIGNED` | FK | Sim | — | Perda anterior que está sendo corrigida ou substituída, quando aplicável. |
| `data_hora` | `DATETIME` | — | Não | — | Data e horário da ocorrência. |
| `quantidade` | `DECIMAL(10,3)` | — | Não | — | Quantidade registrada na operação. |
| `valor_estimado` | `DECIMAL(10,2)` | — | Sim | — | Valor estimado da perda; preenchido quando o lote está confirmado. |
| `situacao_lote` | `VARCHAR(18)` | — | Não | — | Indica se o lote da perda já foi confirmado ou ainda precisa ser identificado. |
| `status` | `VARCHAR(12)` | — | Não | `'valida'` | Indica se a perda é válida ou foi substituída por outro registro. |
| `observacao` | `VARCHAR(250)` | — | Sim | — | Observação complementar. |

**Chaves estrangeiras:**
- `id_produto` → `PRODUTO.id_produto` (`ON DELETE RESTRICT`).
- `id_setor` → `SETOR.id_setor` (`ON DELETE RESTRICT`).
- `id_motivo` → `MOTIVO_PERDA.id_motivo` (`ON DELETE RESTRICT`).
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).
- `id_lote` → `LOTE.id_lote` (`ON DELETE RESTRICT`).
- `id_perda_original` → `PERDA.id_perda` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(quantidade > 0)`
- `(situacao_lote IN ('confirmado','lote_a_confirmar'))`
- `(status IN ('valida','substituida'))`
- `((situacao_lote='confirmado' AND id_lote IS NOT NULL AND valor_estimado IS NOT NULL) OR (situacao_lote='lote_a_confirmar' AND id_lote IS NULL AND valor_estimado IS NULL))`

#### 4.19 PROMOCAO

**Finalidade:** Registrar promoções vinculadas a lotes, com período e preço promocional.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_promocao` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de promocao. |
| `id_lote` | `INT UNSIGNED` | FK | Não | — | Identificador do lote. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `data_inicio` | `DATE` | — | Não | — | Data de início da promoção. |
| `data_fim` | `DATE` | — | Não | — | Data de término da promoção. |
| `preco_normal` | `DECIMAL(10,2)` | — | Não | — | Preço normal do produto usado como referência para a promoção. |
| `preco_promocional` | `DECIMAL(10,2)` | — | Não | — | Preço promocional aplicado no período. |

**Chaves estrangeiras:**
- `id_lote` → `LOTE.id_lote` (`ON DELETE RESTRICT`).
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(preco_normal > 0)`
- `(preco_promocional > 0 AND preco_promocional < preco_normal)`
- `(data_fim >= data_inicio)`

#### 4.20 SESSAO_CAIXA

**Finalidade:** Registrar abertura e fechamento de uma sessão de caixa, responsáveis e valores de conferência.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_sessao` | `INT UNSIGNED` | PK | Não | — | Identificador da sessão de caixa. |
| `id_caixa` | `INT UNSIGNED` | FK | Não | — | Identificador do caixa. |
| `id_funcionario_abertura` | `INT UNSIGNED` | FK | Não | — | Funcionário responsável pela abertura da sessão de caixa. |
| `id_funcionario_fechamento` | `INT UNSIGNED` | FK | Sim | — | Funcionário responsável pelo fechamento da sessão, quando concluída. |
| `data_abertura` | `DATETIME` | — | Não | — | Data e horário de abertura da sessão. |
| `data_fechamento` | `DATETIME` | — | Sim | — | Data e horário de fechamento da sessão. |
| `fundo_inicial` | `DECIMAL(10,2)` | — | Não | `0` | Valor inicial disponível no caixa no momento da abertura. |
| `valor_esperado` | `DECIMAL(10,2)` | — | Sim | — | Valor esperado no fechamento da sessão. |
| `valor_contado` | `DECIMAL(10,2)` | — | Sim | — | Valor efetivamente contado no fechamento. |
| `diferenca` | `DECIMAL(10,2)` | — | Calculado | Gerado: `CASE WHEN valor_esperado IS NULL OR valor_contado IS NULL THEN NULL ELSE valor_contado - valor_esperado END` | Coluna gerada com valor_contado - valor_esperado. |
| `status` | `VARCHAR(10)` | — | Não | `'aberta'` | Status. |
| `caixa_aberto_unico` | `INT UNSIGNED` | — | Calculado | Gerado: `CASE WHEN status='aberta' THEN id_caixa ELSE NULL END` | Coluna gerada usada para impedir mais de uma sessão aberta no mesmo caixa. |

**Chaves estrangeiras:**
- `id_caixa` → `CAIXA.id_caixa` (`ON DELETE RESTRICT`).
- `id_funcionario_abertura` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).
- `id_funcionario_fechamento` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Unicidade:**
- `CONSTRAINT uq_caixa_sessao_aberta UNIQUE (caixa_aberto_unico)`

**Restrições `CHECK`:**
- `(fundo_inicial >= 0)`
- `(status IN ('aberta','fechada'))`
- `((status='aberta' AND data_fechamento IS NULL AND id_funcionario_fechamento IS NULL AND valor_esperado IS NULL AND valor_contado IS NULL) OR (status='fechada' AND data_fechamento IS NOT NULL AND id_funcionario_fechamento IS NOT NULL AND valor_esperado IS NOT NULL AND valor_contado IS NOT NULL))`

#### 4.21 TROCA_OPERADOR

**Finalidade:** Registrar trocas de operador dentro de uma sessão de caixa.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_troca` | `INT UNSIGNED` | PK | Não | — | Identificador da troca de operador. |
| `id_sessao` | `INT UNSIGNED` | FK | Não | — | Identificador da sessão de caixa. |
| `id_funcionario_anterior` | `INT UNSIGNED` | FK | Não | — | Funcionário que estava operando a sessão antes da troca. |
| `id_funcionario_novo` | `INT UNSIGNED` | FK | Não | — | Funcionário que assume a operação da sessão. |
| `data_hora` | `DATETIME` | — | Não | — | Data e horário da ocorrência. |

**Chaves estrangeiras:**
- `id_sessao` → `SESSAO_CAIXA.id_sessao` (`ON DELETE RESTRICT`).
- `id_funcionario_anterior` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).
- `id_funcionario_novo` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(id_funcionario_anterior <> id_funcionario_novo)`

#### 4.22 SANGRIA

**Finalidade:** Registrar retiradas de numerário realizadas durante uma sessão de caixa.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_sangria` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de sangria. |
| `id_sessao` | `INT UNSIGNED` | FK | Não | — | Identificador da sessão de caixa. |
| `id_funcionario` | `INT UNSIGNED` | FK | Não | — | Identificador do funcionário. |
| `data_hora` | `DATETIME` | — | Não | — | Data e horário da ocorrência. |
| `valor` | `DECIMAL(10,2)` | — | Não | — | Valor monetário do registro. |

**Chaves estrangeiras:**
- `id_sessao` → `SESSAO_CAIXA.id_sessao` (`ON DELETE RESTRICT`).
- `id_funcionario` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(valor > 0)`

#### 4.23 VENDA

**Finalidade:** Registrar vendas vinculadas a uma sessão de caixa, operador e eventual cancelamento por supervisor.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_venda` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de venda. |
| `id_sessao` | `INT UNSIGNED` | FK | Não | — | Identificador da sessão de caixa. |
| `id_funcionario_operador` | `INT UNSIGNED` | FK | Não | — | Funcionário que opera a venda dentro da sessão de caixa. |
| `id_funcionario_supervisor` | `INT UNSIGNED` | FK | Sim | — | Supervisor responsável pelo cancelamento da venda, quando aplicável. |
| `data_hora` | `DATETIME` | — | Não | — | Data e horário da ocorrência. |
| `valor_total` | `DECIMAL(10,2)` | — | Não | `0` | Valor total do registro. |
| `status` | `VARCHAR(15)` | — | Não | `'em_andamento'` | Situação da venda: em andamento, concluída ou cancelada. |
| `motivo_cancelamento` | `VARCHAR(200)` | — | Sim | — | Motivo informado para o cancelamento. |
| `data_hora_cancelamento` | `DATETIME` | — | Sim | — | Data e horário do cancelamento. |

**Chaves estrangeiras:**
- `id_sessao` → `SESSAO_CAIXA.id_sessao` (`ON DELETE RESTRICT`).
- `id_funcionario_operador` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).
- `id_funcionario_supervisor` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(valor_total >= 0)`
- `(status IN ('em_andamento','concluida','cancelada'))`
- `((status='cancelada' AND id_funcionario_supervisor IS NOT NULL AND motivo_cancelamento IS NOT NULL AND data_hora_cancelamento IS NOT NULL) OR (status<>'cancelada' AND id_funcionario_supervisor IS NULL AND motivo_cancelamento IS NULL AND data_hora_cancelamento IS NULL))`

#### 4.24 ITEM_VENDA

**Finalidade:** Registrar os itens de cada venda, preservando quantidade/peso, preço praticado, subtotal e eventual cancelamento do item.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_item_venda` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de item venda. |
| `id_venda` | `INT UNSIGNED` | FK | Não | — | Identificador da venda. |
| `id_produto` | `INT UNSIGNED` | FK | Não | — | Identificador do produto. |
| `id_funcionario_cancelamento` | `INT UNSIGNED` | FK | Sim | — | Funcionário responsável pelo cancelamento do item, quando aplicável. |
| `quantidade_ou_peso` | `DECIMAL(10,3)` | — | Não | — | Quantidade em unidades ou peso em quilogramas vendido no item. |
| `preco_unitario` | `DECIMAL(10,2)` | — | Não | — | Preço unitário praticado no momento da venda. |
| `subtotal` | `DECIMAL(10,2)` | — | Calculado | Gerado: `ROUND(quantidade_ou_peso * preco_unitario,2)` | Coluna gerada por quantidade_ou_peso × preco_unitario, arredondada para duas casas. |
| `status` | `VARCHAR(12)` | — | Não | `'ativo'` | Situação do item: ativo ou cancelado. |
| `motivo_cancelamento` | `VARCHAR(200)` | — | Sim | — | Motivo informado para o cancelamento. |
| `data_hora_cancelamento` | `DATETIME` | — | Sim | — | Data e horário do cancelamento. |

**Chaves estrangeiras:**
- `id_venda` → `VENDA.id_venda` (`ON DELETE RESTRICT`).
- `id_produto` → `PRODUTO.id_produto` (`ON DELETE RESTRICT`).
- `id_funcionario_cancelamento` → `FUNCIONARIO.id_funcionario` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(quantidade_ou_peso > 0)`
- `(preco_unitario > 0)`
- `(status IN ('ativo','cancelado'))`
- `((status='cancelado' AND id_funcionario_cancelamento IS NOT NULL AND motivo_cancelamento IS NOT NULL AND data_hora_cancelamento IS NOT NULL) OR (status='ativo' AND id_funcionario_cancelamento IS NULL AND motivo_cancelamento IS NULL AND data_hora_cancelamento IS NULL))`

#### 4.25 PAGAMENTO

**Finalidade:** Registrar uma ou mais formas de pagamento usadas em uma venda.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_pagamento` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de pagamento. |
| `id_venda` | `INT UNSIGNED` | FK | Não | — | Identificador da venda. |
| `id_forma` | `INT UNSIGNED` | FK | Não | — | Identificador da forma de pagamento. |
| `valor` | `DECIMAL(10,2)` | — | Não | — | Valor monetário do registro. |

**Chaves estrangeiras:**
- `id_venda` → `VENDA.id_venda` (`ON DELETE RESTRICT`).
- `id_forma` → `FORMA_PAGAMENTO.id_forma` (`ON DELETE RESTRICT`).

**Restrições `CHECK`:**
- `(valor > 0)`

#### 4.26 DOCUMENTO_FISCAL

**Finalidade:** Registrar os dados do documento fiscal associado a uma venda.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_documento` | `INT UNSIGNED` | PK | Não | — | Identificador do documento fiscal. |
| `id_venda` | `INT UNSIGNED` | FK + UQ | Não | — | Identificador da venda. |
| `tipo_documento` | `VARCHAR(10)` | — | Não | — | Tipo do documento fiscal: NFCe, SAT ou OUTRO. |
| `numero_documento` | `VARCHAR(30)` | — | Não | — | Número do documento fiscal. |
| `serie` | `VARCHAR(10)` | — | Sim | — | Série do documento fiscal. |
| `chave_acesso` | `VARCHAR(44)` | UQ | Sim | — | Chave de acesso do documento fiscal, quando disponível. |
| `data_emissao` | `DATETIME` | — | Não | — | Data de emissão do documento. |
| `situacao` | `VARCHAR(12)` | — | Não | — | Situação do documento: emitido ou cancelado. |

**Chaves estrangeiras:**
- `id_venda` → `VENDA.id_venda` (`ON DELETE RESTRICT`).

**Unicidade:**
- `id_venda` possui `UNIQUE`.
- `chave_acesso` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(tipo_documento IN ('NFCe','SAT','OUTRO'))`
- `(situacao IN ('emitido','cancelado'))`

#### 4.27 SAIDA_LOTE

**Finalidade:** Registrar as baixas de estoque por lote decorrentes de venda, perda ou estorno, preservando a rastreabilidade da movimentação.

| Coluna | Tipo | Chave | Permite NULL | Padrão / geração | Descrição |
|---|---|---|---|---|---|
| `id_saida_lote` | `INT UNSIGNED` | PK | Não | — | Identificador único do registro de saida lote. |
| `id_lote` | `INT UNSIGNED` | FK | Não | — | Identificador do lote. |
| `id_item_venda` | `INT UNSIGNED` | FK | Sim | — | Identificador do item de venda. |
| `id_perda` | `INT UNSIGNED` | FK | Sim | — | Identificador relacionado a outro registro do banco. |
| `id_saida_original` | `INT UNSIGNED` | FK + UQ | Sim | — | Saída original que está sendo revertida quando o registro é um estorno. |
| `quantidade` | `DECIMAL(10,3)` | — | Não | — | Quantidade registrada na operação. |
| `data_hora` | `DATETIME` | — | Não | — | Data e horário da ocorrência. |
| `tipo` | `VARCHAR(10)` | — | Não | — | Natureza da movimentação: venda, perda ou estorno. |

**Chaves estrangeiras:**
- `id_lote` → `LOTE.id_lote` (`ON DELETE RESTRICT`).
- `id_item_venda` → `ITEM_VENDA.id_item_venda` (`ON DELETE RESTRICT`).
- `id_perda` → `PERDA.id_perda` (`ON DELETE RESTRICT`).
- `id_saida_original` → `SAIDA_LOTE.id_saida_lote` (`ON DELETE RESTRICT`).

**Unicidade:**
- `id_saida_original` possui `UNIQUE`.

**Restrições `CHECK`:**
- `(quantidade > 0)`
- `(tipo IN ('venda','perda','estorno'))`
- `((tipo='venda' AND id_item_venda IS NOT NULL AND id_perda IS NULL AND id_saida_original IS NULL) OR (tipo='perda' AND id_item_venda IS NULL AND id_perda IS NOT NULL AND id_saida_original IS NULL) OR (tipo='estorno' AND id_item_venda IS NULL AND id_perda IS NULL AND id_saida_original IS NOT NULL))`

### 5. View auxiliar

#### vw_saldo_produto

**Finalidade:** consolidar o saldo dos lotes por produto, descontando perdas válidas que ainda estão com lote a confirmar.

| Coluna | Origem / cálculo |
|---|---|
| `id_produto` | `PRODUTO.id_produto` |
| `nome` | `PRODUTO.nome` |
| `saldo_lotes` | Soma de `LOTE.quantidade_atual` do produto. |
| `perdas_pendentes` | Soma das perdas válidas com `situacao_lote = 'lote_a_confirmar'`. |
| `saldo_disponivel` | `saldo_lotes - perdas_pendentes`. |

### 6. Índices adicionais

| Índice | Tabela | Coluna(s) |
|---|---|---|
| `idx_lote_validade` | `LOTE` | `data_validade` |
| `idx_lote_produto` | `LOTE` | `id_produto` |
| `idx_perda_data` | `PERDA` | `data_hora` |
| `idx_perda_setor` | `PERDA` | `id_setor` |
| `idx_perda_motivo` | `PERDA` | `id_motivo` |
| `idx_venda_data` | `VENDA` | `data_hora` |
| `idx_venda_sessao` | `VENDA` | `id_sessao` |
| `idx_item_venda_venda` | `ITEM_VENDA` | `id_venda` |
| `idx_item_venda_produto` | `ITEM_VENDA` | `id_produto` |
| `idx_pagamento_venda` | `PAGAMENTO` | `id_venda` |
| `idx_saida_lote_lote` | `SAIDA_LOTE` | `id_lote` |
| `idx_conta_venc_status` | `CONTA_PAGAR` | `data_vencimento,status` |

### 7. Objetos de integridade e operação

O `script.sql` também contém **27 triggers** e **9 procedures**. Esses objetos não entram na contagem de tabelas e colunas do dicionário, mas complementam as restrições declarativas (`PK`, `FK`, `UNIQUE` e `CHECK`) em regras que dependem de outras linhas, outras tabelas ou operações com vários passos.

Entre os exemplos estão validações de saldo de lote, consistência entre produto e lote, regras de perda, recebimento, pagamento, sessão de caixa, conclusão/cancelamento de venda e estornos.

### 8. Observações finais

- O dicionário foi montado a partir da estrutura `CREATE TABLE` do `script.sql` final.
- O banco usa `InnoDB` e foi escrito para MySQL 8.0.16 ou superior.
- Campos gerados, como `SESSAO_CAIXA.diferenca`, `SESSAO_CAIXA.caixa_aberto_unico` e `ITEM_VENDA.subtotal`, não devem ser preenchidos manualmente.
- O modelo conceitual possui 22 entidades e 48 relacionamentos; as cinco associações com atributos se tornam tabelas no modelo lógico, que totaliza 27 tabelas.
- Este arquivo documenta a implementação acadêmica, e não o banco de produção do Hortifruti União.
