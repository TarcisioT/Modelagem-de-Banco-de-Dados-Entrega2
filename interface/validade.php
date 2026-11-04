<?php
declare(strict_types=1);
require_once __DIR__ . '/funcoes.php';
$titulo = 'Validade';
$erro = null;
try {
    $ref = DATA_REFERENCIA;
    $proximos = queryAll("SELECT l.id_lote,l.codigo_lote,p.nome produto,s.nome setor,l.data_validade,l.quantidade_atual,DATEDIFF(l.data_validade,:r1) dias_restantes,CASE WHEN EXISTS(SELECT 1 FROM PROMOCAO pr WHERE pr.id_lote=l.id_lote AND :r2 BETWEEN pr.data_inicio AND pr.data_fim) THEN 'sim' ELSE 'nao' END promocao_vigente FROM LOTE l JOIN PRODUTO p ON p.id_produto=l.id_produto JOIN SETOR s ON s.id_setor=p.id_setor WHERE l.quantidade_atual>0 AND l.data_validade IS NOT NULL AND l.data_validade>=:r3 AND DATEDIFF(l.data_validade,:r4)<=COALESCE(s.dias_alerta_validade,7) ORDER BY l.data_validade,p.nome", ['r1'=>$ref,'r2'=>$ref,'r3'=>$ref,'r4'=>$ref]);
    $vencidos = queryAll("SELECT l.id_lote,l.codigo_lote,p.nome produto,s.nome setor,l.data_validade,l.quantidade_atual FROM LOTE l JOIN PRODUTO p ON p.id_produto=l.id_produto JOIN SETOR s ON s.id_setor=p.id_setor WHERE l.quantidade_atual>0 AND l.data_validade<:r ORDER BY l.data_validade", ['r'=>$ref]);
    $promocoes = queryAll("SELECT pr.id_promocao,p.nome produto,l.codigo_lote,pr.preco_normal,pr.preco_promocional,pr.data_inicio,pr.data_fim,CASE WHEN :r BETWEEN pr.data_inicio AND pr.data_fim THEN 'vigente' ELSE 'encerrada' END situacao FROM PROMOCAO pr JOIN LOTE l ON l.id_lote=pr.id_lote JOIN PRODUTO p ON p.id_produto=l.id_produto ORDER BY pr.data_inicio", ['r'=>$ref]);
    $alertas = queryAll("SELECT nome,dias_alerta_validade,COALESCE(dias_alerta_validade,7) alerta_utilizado FROM SETOR WHERE vende_produto=1 ORDER BY nome");
} catch(Throwable $e) { $erro=$e->getMessage(); $proximos=$vencidos=$promocoes=$alertas=[]; }
require __DIR__ . '/partials/header.php';
?>
<?php if($erro): ?><div class="notice notice-danger"><?= e($erro) ?></div><?php endif; ?>
<div class="notice notice-info">Data de referência da demonstração: <strong><?= e(dataBr(DATA_REFERENCIA)) ?></strong>. Não foi trocada por CURDATE() para preservar os resultados da massa.</div>
<section class="cards">
<div class="card metric"><div class="label">Próximos do vencimento</div><div class="value"><?= count($proximos) ?></div><div class="hint">G03</div></div>
<div class="card metric"><div class="label">Vencidos com saldo</div><div class="value"><?= count($vencidos) ?></div><div class="hint">G04</div></div>
<div class="card metric"><div class="label">Promoções cadastradas</div><div class="value"><?= count($promocoes) ?></div><div class="hint">G12</div></div>
</section>
<section class="panel"><div class="panel-head"><h2>G03 — lotes próximos do vencimento</h2><span class="badge badge-warn">P2 / KPI03</span></div><div class="table-wrap"><table><thead><tr><th>Lote</th><th>Produto</th><th>Setor</th><th>Validade</th><th>Dias</th><th>Saldo</th><th>Promoção</th></tr></thead><tbody><?php if(!$proximos): ?><tr><td colspan="7" class="empty">Nenhum lote no alerta.</td></tr><?php endif; ?><?php foreach($proximos as $r): ?><tr><td><?= e($r['codigo_lote'] ?: '#'.$r['id_lote']) ?></td><td><?= e($r['produto']) ?></td><td><?= e($r['setor']) ?></td><td><?= e(dataBr($r['data_validade'])) ?></td><td><?= e($r['dias_restantes']) ?></td><td><?= e(numero($r['quantidade_atual'])) ?></td><td><span class="badge <?= $r['promocao_vigente']==='sim'?'badge-ok':'badge-neutral' ?>"><?= e($r['promocao_vigente']) ?></span></td></tr><?php endforeach; ?></tbody></table></div></section>
<div class="grid-2">
<section class="panel"><div class="panel-head"><h2>G04 — vencidos com saldo</h2><span class="badge badge-danger">Atenção</span></div><div class="table-wrap"><table><thead><tr><th>Lote</th><th>Produto</th><th>Setor</th><th>Validade</th><th>Saldo</th></tr></thead><tbody><?php if(!$vencidos): ?><tr><td colspan="5" class="empty">Nenhum vencido com saldo.</td></tr><?php endif; ?><?php foreach($vencidos as $r): ?><tr><td><?= e($r['codigo_lote'] ?: '#'.$r['id_lote']) ?></td><td><?= e($r['produto']) ?></td><td><?= e($r['setor']) ?></td><td><?= e(dataBr($r['data_validade'])) ?></td><td><?= e(numero($r['quantidade_atual'])) ?></td></tr><?php endforeach; ?></tbody></table></div></section>
<section class="panel"><div class="panel-head"><h2>Prazo de alerta por setor</h2><span class="badge badge-neutral">SETOR</span></div><div class="table-wrap"><table><thead><tr><th>Setor</th><th>Configurado</th><th>Usado</th></tr></thead><tbody><?php foreach($alertas as $r): ?><tr><td><?= e($r['nome']) ?></td><td><?= $r['dias_alerta_validade']===null?'Padrão':e($r['dias_alerta_validade'].' dias') ?></td><td><?= e($r['alerta_utilizado'].' dias') ?></td></tr><?php endforeach; ?></tbody></table></div></section>
</div>
<section class="panel"><div class="panel-head"><h2>G12 — promoções</h2><span class="badge badge-neutral">Complementar</span></div><div class="table-wrap"><table><thead><tr><th>ID</th><th>Produto</th><th>Lote</th><th>Normal</th><th>Promocional</th><th>Início</th><th>Fim</th><th>Situação</th></tr></thead><tbody><?php foreach($promocoes as $r): ?><tr><td><?= e($r['id_promocao']) ?></td><td><?= e($r['produto']) ?></td><td><?= e($r['codigo_lote'] ?: '—') ?></td><td><?= e(brl($r['preco_normal'])) ?></td><td><?= e(brl($r['preco_promocional'])) ?></td><td><?= e(dataBr($r['data_inicio'])) ?></td><td><?= e(dataBr($r['data_fim'])) ?></td><td><span class="badge <?= $r['situacao']==='vigente'?'badge-ok':'badge-neutral' ?>"><?= e($r['situacao']) ?></span></td></tr><?php endforeach; ?></tbody></table></div></section>
<?php require __DIR__ . '/partials/footer.php'; ?>
