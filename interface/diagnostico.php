<?php
declare(strict_types=1);
require_once __DIR__.'/funcoes.php';
header('Content-Type: text/plain; charset=utf-8');
try {
    $versao=queryOne('SELECT VERSION() versao');
    $tabelas=queryOne("SELECT COUNT(*) qtd FROM information_schema.tables WHERE table_schema=:db AND table_type='BASE TABLE'",['db'=>DB_NAME]);
    $views=queryOne("SELECT COUNT(*) qtd FROM information_schema.views WHERE table_schema=:db",['db'=>DB_NAME]);
    echo "Conexao: OK\n";
    echo "Servidor: ".($versao['versao']??'')."\n";
    echo "Banco: ".DB_NAME."\n";
    echo "Tabelas: ".($tabelas['qtd']??0)."\n";
    echo "Views: ".($views['qtd']??0)."\n";
    echo "Data de referencia: ".DATA_REFERENCIA."\n";
    echo "Registro de perda: ".(PERMITIR_REGISTRO_PERDA?'ATIVADO':'DESATIVADO')."\n";
} catch(Throwable $e) {
    http_response_code(500);
    echo "Conexao: ERRO\n".$e->getMessage()."\n";
}
