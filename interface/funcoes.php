<?php
declare(strict_types=1);
require_once __DIR__ . '/conexao.php';

function e(mixed $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function brl(mixed $value): string
{
    return 'R$ ' . number_format((float)$value, 2, ',', '.');
}

function numero(mixed $value, int $casas = 3): string
{
    return number_format((float)$value, $casas, ',', '.');
}

function dataBr(?string $value): string
{
    if (!$value) return '—';
    $dt = new DateTime($value);
    return $dt->format('d/m/Y');
}

function dataHoraBr(?string $value): string
{
    if (!$value) return '—';
    $dt = new DateTime($value);
    return $dt->format('d/m/Y H:i');
}

function queryAll(string $sql, array $params = []): array
{
    $stmt = db()->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
}

function queryOne(string $sql, array $params = []): array
{
    $stmt = db()->prepare($sql);
    $stmt->execute($params);
    $row = $stmt->fetch();
    return $row ?: [];
}

function paginaAtual(): string
{
    return basename($_SERVER['PHP_SELF'] ?? 'index.php');
}

function navClass(string $file): string
{
    return paginaAtual() === $file ? 'nav-link active' : 'nav-link';
}

function refSql(): string
{
    return db()->quote(DATA_REFERENCIA);
}
