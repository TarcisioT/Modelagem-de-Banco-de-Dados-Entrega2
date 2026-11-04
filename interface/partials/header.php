<?php
require_once __DIR__ . '/../funcoes.php';
$titulo = $titulo ?? 'Hortifruti União';
?>
<!doctype html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titulo) ?> | Hortifruti União</title>
    <link rel="stylesheet" href="assets/style.css">
</head>
<body>
<div class="app-shell">
    <aside class="sidebar">
        <div class="brand">
            <span class="brand-mark">HU</span>
            <div><strong>Hortifruti União</strong><small>Interface acadêmica</small></div>
        </div>
        <nav class="nav">
            <a class="<?= navClass('index.php') ?>" href="index.php">Dashboard</a>
            <a class="<?= navClass('perdas.php') ?>" href="perdas.php">Perdas</a>
            <a class="<?= navClass('validade.php') ?>" href="validade.php">Validade</a>
            <a class="<?= navClass('vendas.php') ?>" href="vendas.php">Vendas</a>
            <a class="<?= navClass('estoque.php') ?>" href="estoque.php">Estoque</a>
            <a class="<?= navClass('auditoria.php') ?>" href="auditoria.php">Auditoria</a>
        </nav>
        <div class="sidebar-note">
            <span>Data da demonstração</span>
            <strong><?= e(dataBr(DATA_REFERENCIA)) ?></strong>
        </div>
    </aside>
    <main class="main">
        <header class="topbar">
            <div>
                <p class="eyebrow">Demonstração do banco MySQL</p>
                <h1><?= e($titulo) ?></h1>
            </div>
            <span class="badge badge-neutral">MySQL 8</span>
        </header>
