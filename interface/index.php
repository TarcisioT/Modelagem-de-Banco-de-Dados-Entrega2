<?php
declare(strict_types=1);
require_once __DIR__ . '/funcoes.php';
$titulo = 'Dashboard';
$erro = null;
$dados = [
    'vendas' => 0,
    'faturamento' => 0,
    'ticket' => 0,
    'perdas' => 0,
    'valor_perdas' => 0,
    'pendentes' => 0,
    'percentual_pendentes' => 0,
    'estoque_baixo' => 0,
    'vencendo' => 0,
    'vencidos' => 0,
];
$faturamentoDia = [];
$perdasMotivo = [];

try {
    $v = queryOne("SELECT COUNT(*) vendas, COALESCE(SUM(valor_total),0) faturamento, COALESCE(AVG(valor_total),0) ticket FROM VENDA WHERE status='concluida'");
    $dados['vendas'] = (int)($v['vendas'] ?? 0);
    $dados['faturamento'] = (float)($v['faturamento'] ?? 0);
    $dados['ticket'] = (float)($v['ticket'] ?? 0);

    $p = queryOne("SELECT COUNT(*) perdas, COALESCE(SUM(CASE WHEN situacao_lote='confirmado' THEN valor_estimado ELSE 0 END),0) valor_perdas, SUM(situacao_lote='lote_a_confirmar') pendentes, ROUND(SUM(situacao_lote='lote_a_confirmar')/NULLIF(COUNT(*),0)*100,2) percentual FROM PERDA WHERE status='valida'");
    $dados['perdas'] = (int)($p['perdas'] ?? 0);
    $dados['valor_perdas'] = (float)($p['valor_perdas'] ?? 0);
    $dados['pendentes'] = (int)($p['pendentes'] ?? 0);
    $dados['percentual_pendentes'] = (float)($p['percentual'] ?? 0);

    $dados['estoque_baixo'] = (int)(queryOne("SELECT COUNT(*) qtd FROM PRODUTO p JOIN vw_saldo_produto s ON s.id_produto=p.id_produto WHERE p.ativo=1 AND s.saldo_disponivel<p.estoque_minimo")['qtd'] ?? 0);

    $ref = DATA_REFERENCIA;
    $dados['vencendo'] = (int)(queryOne("SELECT COUNT(*) qtd FROM LOTE l JOIN PRODUTO p ON p.id_produto=l.id_produto JOIN SETOR s ON s.id_setor=p.id_setor WHERE l.quantidade_atual>0 AND l.data_validade IS NOT NULL AND l.data_validade>=:ref1 AND DATEDIFF(l.data_validade,:ref2)<=COALESCE(s.dias_alerta_validade,7)", ['ref1'=>$ref,'ref2'=>$ref])['qtd'] ?? 0);
    $dados['vencidos'] = (int)(queryOne("SELECT COUNT(*) qtd FROM LOTE WHERE quantidade_atual>0 AND data_validade<:ref", ['ref'=>$ref])['qtd'] ?? 0);

    $faturamentoDia = queryAll("SELECT DATE(data_hora) dia, COUNT(*) vendas, SUM(valor_total) faturamento FROM VENDA WHERE status='concluida' GROUP BY DATE(data_hora) ORDER BY dia DESC LIMIT 7");
    $perdasMotivo = queryAll("SELECT m.descricao motivo, COUNT(*) ocorrencias FROM PERDA p JOIN MOTIVO_PERDA m ON m.id_motivo=p.id_motivo WHERE p.status='valida' GROUP BY m.id_motivo,m.descricao ORDER BY ocorrencias DESC LIMIT 6");
} catch (Throwable $e) {
    $erro = $e->getMessage();
}

require __DIR__ . '/partials/header.php';
?>
<?php if ($erro): ?>
<div class="notice notice-danger"><strong>Não foi possível conectar ao banco.</strong><br><?= e($erro) ?><br><span class="muted">Confira host, porta, usuário e senha no arquivo config.php.</span></div>
<?php endif; ?>

<div class="notice notice-info">Interface demonstrativa ligada ao banco <strong>hortifruti_uniao</strong>. As consultas de validade usam a data fixa de referência <strong><?= e(dataBr(DATA_REFERENCIA)) ?></strong>, igual à massa acadêmica.</div>

<section class="cards">
    <div class="card metric"><div class="label">Vendas concluídas</div><div class="value"><?= e($dados['vendas']) ?></div><div class="hint">Base da G05</div></div>
    <div class="card metric"><div class="label">Faturamento</div><div class="value"><?= e(brl($dados['faturamento'])) ?></div><div class="hint">Somente vendas concluídas</div></div>
    <div class="card metric"><div class="label">Ticket médio</div><div class="value"><?= e(brl($dados['ticket'])) ?></div><div class="hint">Resumo da lógica da G06</div></div>
    <div class="card metric"><div class="label">Perdas válidas</div><div class="value"><?= e($dados['perdas']) ?></div><div class="hint">Custo confirmado: <?= e(brl($dados['valor_perdas'])) ?></div></div>
    <div class="card metric"><div class="label">Perdas a confirmar</div><div class="value"><?= e($dados['pendentes']) ?></div><div class="hint"><?= e(number_format($dados['percentual_pendentes'],2,',','.')) ?>% das perdas válidas</div></div>
    <div class="card metric"><div class="label">Abaixo do estoque mínimo</div><div class="value"><?= e($dados['estoque_baixo']) ?></div><div class="hint">Mesma condição da G07</div></div>
    <div class="card metric"><div class="label">Lotes próximos do vencimento</div><div class="value"><?= e($dados['vencendo']) ?></div><div class="hint">Data de referência <?= e(dataBr(DATA_REFERENCIA)) ?></div></div>
    <div class="card metric"><div class="label">Lotes vencidos com saldo</div><div class="value"><?= e($dados['vencidos']) ?></div><div class="hint">Mesma condição da G04</div></div>
</section>

<div class="grid-2">
    <section class="panel">
        <div class="panel-head"><h2>Faturamento por dia</h2><span class="badge badge-neutral">G05</span></div>
        <div class="table-wrap"><table><thead><tr><th>Dia</th><th>Vendas</th><th>Faturamento</th></tr></thead><tbody>
        <?php if (!$faturamentoDia): ?><tr><td colspan="3" class="empty">Sem dados.</td></tr><?php endif; ?>
        <?php foreach ($faturamentoDia as $row): ?><tr><td><?= e(dataBr($row['dia'])) ?></td><td><?= e($row['vendas']) ?></td><td><?= e(brl($row['faturamento'])) ?></td></tr><?php endforeach; ?>
        </tbody></table></div>
    </section>
    <section class="panel">
        <div class="panel-head"><h2>Ocorrências de perda por motivo</h2><span class="badge badge-neutral">G02</span></div>
        <div class="table-wrap"><table><thead><tr><th>Motivo</th><th>Ocorrências</th></tr></thead><tbody>
        <?php if (!$perdasMotivo): ?><tr><td colspan="2" class="empty">Sem dados.</td></tr><?php endif; ?>
        <?php foreach ($perdasMotivo as $row): ?><tr><td><?= e($row['motivo']) ?></td><td><?= e($row['ocorrencias']) ?></td></tr><?php endforeach; ?>
        </tbody></table></div>
    </section>
</div>
<?php require __DIR__ . '/partials/footer.php'; ?>
