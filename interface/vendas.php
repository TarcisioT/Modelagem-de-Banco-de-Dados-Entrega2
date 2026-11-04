<?php
declare(strict_types=1);
require_once __DIR__ . '/funcoes.php';
$titulo = 'Vendas';
$erro = null;
try {
    $status = (string)($_GET['status'] ?? '');
    $inicio = trim((string)($_GET['inicio'] ?? ''));
    $fim = trim((string)($_GET['fim'] ?? ''));
    $where=['1=1']; $params=[];
    if (in_array($status,['em_andamento','concluida','cancelada'],true)) { $where[]='v.status=:status'; $params['status']=$status; }
    if ($inicio!=='') { $where[]='DATE(v.data_hora)>=:inicio'; $params['inicio']=$inicio; }
    if ($fim!=='') { $where[]='DATE(v.data_hora)<=:fim'; $params['fim']=$fim; }

    $vendas = queryAll("SELECT v.id_venda,v.data_hora,v.valor_total,v.status,v.motivo_cancelamento,c.numero caixa,f.nome operador,
        (SELECT COUNT(*) FROM ITEM_VENDA iv WHERE iv.id_venda=v.id_venda AND iv.status='ativo') itens_ativos,
        (SELECT GROUP_CONCAT(CONCAT(fp.descricao,' - R$ ',FORMAT(pg.valor,2)) ORDER BY fp.descricao SEPARATOR ' / ') FROM PAGAMENTO pg JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE pg.id_venda=v.id_venda) pagamentos
        FROM VENDA v JOIN SESSAO_CAIXA sc ON sc.id_sessao=v.id_sessao JOIN CAIXA c ON c.id_caixa=sc.id_caixa JOIN FUNCIONARIO f ON f.id_funcionario=v.id_funcionario_operador
        WHERE ".implode(' AND ',$where)." ORDER BY v.data_hora DESC,v.id_venda DESC LIMIT 120",$params);

    $g05 = queryAll("SELECT DATE(data_hora) dia,COUNT(*) vendas,SUM(valor_total) faturamento FROM VENDA WHERE status='concluida' GROUP BY DATE(data_hora) ORDER BY dia");
    $g06 = queryAll("SELECT DATE(data_hora) dia,ROUND(AVG(valor_total),2) ticket_medio FROM VENDA WHERE status='concluida' GROUP BY DATE(data_hora) ORDER BY dia");
    $g08 = queryAll("SELECT DATE_FORMAT(data_hora,'%Y-%m') mes,COUNT(*) vendas_registradas,SUM(status='cancelada') vendas_canceladas,ROUND(SUM(status='cancelada')/COUNT(*)*100,2) taxa_cancelamento FROM VENDA GROUP BY DATE_FORMAT(data_hora,'%Y-%m') ORDER BY mes");
    $resumo = queryOne("SELECT COUNT(*) total,SUM(status='concluida') concluidas,SUM(status='cancelada') canceladas,COALESCE(SUM(CASE WHEN status='concluida' THEN valor_total ELSE 0 END),0) faturamento FROM VENDA");

    $idVenda = filter_input(INPUT_GET,'venda',FILTER_VALIDATE_INT);
    $detalhe = null; $itens=[]; $pagamentos=[];
    if ($idVenda) {
        $detalhe = queryOne("SELECT v.*,c.numero caixa,op.nome operador,sup.nome supervisor FROM VENDA v JOIN SESSAO_CAIXA sc ON sc.id_sessao=v.id_sessao JOIN CAIXA c ON c.id_caixa=sc.id_caixa JOIN FUNCIONARIO op ON op.id_funcionario=v.id_funcionario_operador LEFT JOIN FUNCIONARIO sup ON sup.id_funcionario=v.id_funcionario_supervisor WHERE v.id_venda=:id",['id'=>$idVenda]);
        $itens = queryAll("SELECT iv.id_item_venda,p.nome produto,iv.quantidade_ou_peso,iv.preco_unitario,iv.subtotal,iv.status FROM ITEM_VENDA iv JOIN PRODUTO p ON p.id_produto=iv.id_produto WHERE iv.id_venda=:id ORDER BY iv.id_item_venda",['id'=>$idVenda]);
        $pagamentos = queryAll("SELECT fp.descricao forma,pg.valor FROM PAGAMENTO pg JOIN FORMA_PAGAMENTO fp ON fp.id_forma=pg.id_forma WHERE pg.id_venda=:id ORDER BY pg.id_pagamento",['id'=>$idVenda]);
    }
} catch(Throwable $e) { $erro=$e->getMessage(); $vendas=$g05=$g06=$g08=$itens=$pagamentos=[]; $resumo=[]; $detalhe=null; }
require __DIR__ . '/partials/header.php';
?>
<?php if($erro): ?><div class="notice notice-danger"><?= e($erro) ?></div><?php endif; ?>
<section class="cards">
<div class="card metric"><div class="label">Vendas registradas</div><div class="value"><?= e($resumo['total'] ?? 0) ?></div><div class="hint">Todas as situações</div></div>
<div class="card metric"><div class="label">Concluídas</div><div class="value"><?= e($resumo['concluidas'] ?? 0) ?></div><div class="hint">Entram no faturamento</div></div>
<div class="card metric"><div class="label">Canceladas</div><div class="value"><?= e($resumo['canceladas'] ?? 0) ?></div><div class="hint">Base da G08</div></div>
<div class="card metric"><div class="label">Faturamento</div><div class="value"><?= e(brl($resumo['faturamento'] ?? 0)) ?></div><div class="hint">Somente concluídas</div></div>
</section>
<section class="panel"><div class="panel-head"><h2>Últimas vendas</h2><span class="badge badge-neutral">Consulta visual</span></div>
<form class="filters" method="get"><div class="field"><label>Status</label><select name="status"><option value="">Todos</option><?php foreach(['em_andamento'=>'Em andamento','concluida'=>'Concluída','cancelada'=>'Cancelada'] as $k=>$v): ?><option value="<?= e($k) ?>" <?= $status===$k?'selected':'' ?>><?= e($v) ?></option><?php endforeach; ?></select></div><div class="field"><label>De</label><input type="date" name="inicio" value="<?= e($inicio) ?>"></div><div class="field"><label>Até</label><input type="date" name="fim" value="<?= e($fim) ?>"></div><button class="btn btn-primary">Filtrar</button><a class="btn btn-secondary" href="vendas.php">Limpar</a></form>
<div class="table-wrap"><table><thead><tr><th>ID</th><th>Data</th><th>Caixa</th><th>Operador</th><th>Itens</th><th>Total</th><th>Status</th><th>Pagamentos</th><th></th></tr></thead><tbody><?php if(!$vendas): ?><tr><td colspan="9" class="empty">Nenhuma venda encontrada.</td></tr><?php endif; ?><?php foreach($vendas as $r): ?><tr><td><?= e($r['id_venda']) ?></td><td><?= e(dataHoraBr($r['data_hora'])) ?></td><td><?= e($r['caixa']) ?></td><td><?= e($r['operador']) ?></td><td><?= e($r['itens_ativos']) ?></td><td><?= e(brl($r['valor_total'])) ?></td><td><span class="badge <?= $r['status']==='concluida'?'badge-ok':($r['status']==='cancelada'?'badge-danger':'badge-warn') ?>"><?= e(str_replace('_',' ',$r['status'])) ?></span></td><td><?= e($r['pagamentos'] ?: '—') ?></td><td><a class="btn btn-secondary" href="vendas.php?venda=<?= e($r['id_venda']) ?>">Ver</a></td></tr><?php endforeach; ?></tbody></table></div></section>
<?php if($detalhe): ?><section class="panel"><div class="panel-head"><h2>Venda #<?= e($detalhe['id_venda']) ?></h2><a class="btn btn-secondary" href="vendas.php">Fechar detalhe</a></div><div class="kpi-line"><span class="badge badge-neutral">Caixa <?= e($detalhe['caixa']) ?></span><span class="badge badge-neutral">Operador: <?= e($detalhe['operador']) ?></span><span class="badge <?= $detalhe['status']==='concluida'?'badge-ok':'badge-warn' ?>"><?= e($detalhe['status']) ?></span><span class="badge badge-neutral"><?= e(brl($detalhe['valor_total'])) ?></span></div><br><div class="grid-2"><div><h3>Itens</h3><div class="table-wrap"><table><thead><tr><th>Produto</th><th>Qtd.</th><th>Preço</th><th>Subtotal</th><th>Status</th></tr></thead><tbody><?php foreach($itens as $r): ?><tr><td><?= e($r['produto']) ?></td><td><?= e(numero($r['quantidade_ou_peso'])) ?></td><td><?= e(brl($r['preco_unitario'])) ?></td><td><?= e(brl($r['subtotal'])) ?></td><td><?= e($r['status']) ?></td></tr><?php endforeach; ?></tbody></table></div></div><div><h3>Pagamentos</h3><div class="table-wrap"><table><thead><tr><th>Forma</th><th>Valor</th></tr></thead><tbody><?php foreach($pagamentos as $r): ?><tr><td><?= e($r['forma']) ?></td><td><?= e(brl($r['valor'])) ?></td></tr><?php endforeach; ?></tbody></table></div></div></div></section><?php endif; ?>
<div class="grid-2"><section class="panel"><div class="panel-head"><h2>G05 — faturamento por dia</h2><span class="badge badge-neutral">KPI05</span></div><div class="table-wrap"><table><thead><tr><th>Dia</th><th>Vendas</th><th>Faturamento</th></tr></thead><tbody><?php foreach($g05 as $r): ?><tr><td><?= e(dataBr($r['dia'])) ?></td><td><?= e($r['vendas']) ?></td><td><?= e(brl($r['faturamento'])) ?></td></tr><?php endforeach; ?></tbody></table></div></section><section class="panel"><div class="panel-head"><h2>G06 — ticket médio</h2><span class="badge badge-neutral">KPI06</span></div><div class="table-wrap"><table><thead><tr><th>Dia</th><th>Ticket médio</th></tr></thead><tbody><?php foreach($g06 as $r): ?><tr><td><?= e(dataBr($r['dia'])) ?></td><td><?= e(brl($r['ticket_medio'])) ?></td></tr><?php endforeach; ?></tbody></table></div></section></div>
<section class="panel"><div class="panel-head"><h2>G08 — cancelamento por mês</h2><span class="badge badge-neutral">KPI08</span></div><div class="table-wrap"><table><thead><tr><th>Mês</th><th>Registradas</th><th>Canceladas</th><th>Taxa</th></tr></thead><tbody><?php foreach($g08 as $r): ?><tr><td><?= e($r['mes']) ?></td><td><?= e($r['vendas_registradas']) ?></td><td><?= e($r['vendas_canceladas']) ?></td><td><?= e(number_format((float)$r['taxa_cancelamento'],2,',','.')) ?>%</td></tr><?php endforeach; ?></tbody></table></div></section>
<?php require __DIR__ . '/partials/footer.php'; ?>
