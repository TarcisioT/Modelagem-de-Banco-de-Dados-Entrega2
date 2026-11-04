# Interface demonstrativa — Hortifruti União

Esta pasta é um **extra visual para a apresentação acadêmica**. Ela não substitui o `script.sql`, o MySQL Workbench nem as consultas G/A exigidas pelo professor.

## Requisitos

- PHP 8.x com `pdo_mysql` habilitado.
- Apache (pode ser o Apache do XAMPP).
- **MySQL 8.0.16 ou superior** com o banco `hortifruti_uniao` já importado.
- Não use o MariaDB padrão do XAMPP para importar o script final, pois o script usa recursos/collation do MySQL 8.

## Como instalar no Windows/XAMPP

1. Copie a pasta `hortifruti_interface` para:
   `C:\xampp\htdocs\hortifruti_interface`
2. Abra `config.php`.
3. Confira:
   - `DB_HOST`
   - `DB_PORT`
   - `DB_USER`
   - `DB_PASS`
4. Deixe `DATA_REFERENCIA = '2026-11-01'` para a apresentação.
5. Deixe `PERMITIR_REGISTRO_PERDA = false` durante a apresentação.
6. Inicie o Apache no XAMPP.
7. O MySQL 8 precisa estar iniciado na porta informada em `config.php`.
8. Abra no navegador:
   `http://localhost/hortifruti_interface/`

## Páginas

- `index.php`: dashboard com cards e resumos.
- `perdas.php`: perdas, filtros, G02 e formulário opcional via `registrar_perda_pendente`.
- `validade.php`: G03, G04 e G12.
- `vendas.php`: vendas, detalhes, G05, G06 e G08.
- `estoque.php`: view `vw_saldo_produto`, estoque mínimo e lotes.
- `auditoria.php`: execução visual de A01 a A12.

## Proteção da massa

O formulário de perda vem desativado por padrão. A tabela PERDA possui proteção de histórico e uma perda registrada altera os saldos e indicadores. Para testar antes da apresentação, mude temporariamente:

```php
const PERMITIR_REGISTRO_PERDA = true;
```

Depois, para voltar exatamente à massa original, reimporte o `script.sql` validado.

## Observação importante

A interface foi feita como camada visual sobre o banco existente. Ela não cria tabelas e não muda o modelo lógico. As páginas de auditoria usam as consultas A01–A12 e as telas gerenciais reproduzem a lógica das consultas do trabalho.
