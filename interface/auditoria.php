<?php
declare(strict_types=1);
require_once __DIR__ . '/funcoes.php';
$titulo='Auditoria';

$auditorias = [
'A01'=>['pergunta'=>'Existem perdas válidas ainda sem lote confirmado?','regra'=>'RN42 e RN52','nota'=>'Pode retornar pendências legítimas da massa de demonstração.','consultas'=>[
['titulo'=>'Perdas pendentes','sql'=>"SELECT id_perda,id_produto,data_hora,quantidade FROM PERDA WHERE status='valida' AND situacao_lote='lote_a_confirmar'"],
['titulo'=>'Saldo disponível negativo','sql'=>"SELECT * FROM vw_saldo_produto WHERE saldo_disponivel<0"]]],
'A02'=>['pergunta'=>'Existe pedido não cancelado sem nenhum item?','regra'=>'RN09','consultas'=>[[ 'titulo'=>'Pedidos sem itens','sql'=>"SELECT pc.id_pedido FROM PEDIDO_COMPRA pc LEFT JOIN ITEM_PEDIDO_COMPRA ip ON ip.id_pedido=pc.id_pedido WHERE pc.status<>'cancelado' GROUP BY pc.id_pedido HAVING COUNT(ip.id_item_pedido)=0"]]],
'A03'=>['pergunta'=>'Existe venda concluída sem item ativo?','regra'=>'RN23','consultas'=>[[ 'titulo'=>'Vendas sem item ativo','sql'=>"SELECT v.id_venda FROM VENDA v LEFT JOIN ITEM_VENDA iv ON iv.id_venda=v.id_venda AND iv.status='ativo' WHERE v.status='concluida' GROUP BY v.id_venda HAVING COUNT(iv.id_item_venda)=0"]]],
'A04'=>['pergunta'=>'Existe venda concluída cujo pagamento não bate com o total?','regra'=>'RN24','consultas'=>[[ 'titulo'=>'Diferença entre venda e pagamento','sql'=>"SELECT v.id_venda,v.valor_total,COALESCE(SUM(pg.valor),0) AS total_pago FROM VENDA v LEFT JOIN PAGAMENTO pg ON pg.id_venda=v.id_venda WHERE v.status='concluida' GROUP BY v.id_venda,v.valor_total HAVING ABS(v.valor_total-COALESCE(SUM(pg.valor),0))>0.01"]]],
'A05'=>['pergunta'=>'Existe lote ligado a produto diferente do item recebido?','regra'=>'RN14 e regra de normalização','consultas'=>[[ 'titulo'=>'Lote e item com produtos diferentes','sql'=>"SELECT l.id_lote,l.id_produto,ir.id_produto AS produto_item FROM LOTE l JOIN ITEM_RECEBIMENTO ir ON ir.id_item_recebimento=l.id_item_recebimento WHERE l.id_produto<>ir.id_produto"]]],
'A06'=>['pergunta'=>'Existe lote com saldo negativo ou maior que a quantidade recebida?','regra'=>'RN16 e RN17','consultas'=>[[ 'titulo'=>'Saldos inválidos de lote','sql'=>"SELECT id_lote,quantidade_recebida,quantidade_atual FROM LOTE WHERE quantidade_atual<0 OR quantidade_atual>quantidade_recebida"]]],
'A07'=>['pergunta'=>'Existe item recebido em que aceita + recusada difere da nota?','regra'=>'RN12','consultas'=>[
['titulo'=>'Quantidade aceita + recusada','sql'=>"SELECT id_item_recebimento,quantidade_nf,quantidade_aceita,quantidade_recusada FROM ITEM_RECEBIMENTO WHERE quantidade_nf<>quantidade_aceita+quantidade_recusada"],
['titulo'=>'Complemento: lotes acima da quantidade aceita','sql'=>"SELECT ir.id_item_recebimento,ir.quantidade_aceita,COALESCE(SUM(l.quantidade_recebida),0) AS total_lotes FROM ITEM_RECEBIMENTO ir LEFT JOIN LOTE l ON l.id_item_recebimento=ir.id_item_recebimento GROUP BY ir.id_item_recebimento,ir.quantidade_aceita HAVING COALESCE(SUM(l.quantidade_recebida),0)>ir.quantidade_aceita"]]],
'A08'=>['pergunta'=>'Algum item devolvido ultrapassa a quantidade recusada?','regra'=>'RN37','consultas'=>[
['titulo'=>'Quantidade devolvida acima da recusada','sql'=>"SELECT ir.id_item_recebimento,ir.quantidade_recusada,COALESCE(SUM(idv.quantidade),0) AS total_devolvido FROM ITEM_RECEBIMENTO ir JOIN ITEM_DEVOLUCAO idv ON idv.id_item_recebimento=ir.id_item_recebimento GROUP BY ir.id_item_recebimento,ir.quantidade_recusada HAVING SUM(idv.quantidade)>ir.quantidade_recusada"],
['titulo'=>'Complemento: abatimentos acima da conta','sql'=>"SELECT c.id_conta,c.valor,COALESCE(SUM(df.valor_abatimento),0) AS total_abatimentos FROM CONTA_PAGAR c JOIN DEVOLUCAO_FORNECEDOR df ON df.id_conta=c.id_conta WHERE df.tipo='abatimento' AND df.status<>'cancelada' GROUP BY c.id_conta,c.valor HAVING COALESCE(SUM(df.valor_abatimento),0)>c.valor"]]],
'A09'=>['pergunta'=>'Existe saída de lote com origem incoerente com o tipo?','regra'=>'RN17 e RN28','consultas'=>[[ 'titulo'=>'Saídas incoerentes','sql'=>"SELECT sl.* FROM SAIDA_LOTE sl LEFT JOIN SAIDA_LOTE orig ON orig.id_saida_lote=sl.id_saida_original WHERE NOT ((sl.tipo='venda' AND sl.id_item_venda IS NOT NULL AND sl.id_perda IS NULL AND sl.id_saida_original IS NULL) OR (sl.tipo='perda' AND sl.id_item_venda IS NULL AND sl.id_perda IS NOT NULL AND sl.id_saida_original IS NULL) OR (sl.tipo='estorno' AND sl.id_item_venda IS NULL AND sl.id_perda IS NULL AND sl.id_saida_original IS NOT NULL AND orig.tipo<>'estorno' AND orig.id_lote=sl.id_lote AND orig.quantidade=sl.quantidade))"]]],
'A10'=>['pergunta'=>'Existe venda cancelada com baixa de venda ainda sem estorno?','regra'=>'RN54','consultas'=>[[ 'titulo'=>'Baixas sem estorno','sql'=>"SELECT v.id_venda,sl.id_saida_lote FROM VENDA v JOIN ITEM_VENDA iv ON iv.id_venda=v.id_venda AND iv.status='ativo' JOIN SAIDA_LOTE sl ON sl.id_item_venda=iv.id_item_venda AND sl.tipo='venda' LEFT JOIN SAIDA_LOTE est ON est.id_saida_original=sl.id_saida_lote WHERE v.status='cancelada' AND est.id_saida_lote IS NULL"]]],
'A11'=>['pergunta'=>'Existe sessão fechada sem dados de fechamento?','regra'=>'RN32 e RN56','consultas'=>[[ 'titulo'=>'Sessões incompletas','sql'=>"SELECT id_sessao FROM SESSAO_CAIXA WHERE status='fechada' AND (data_fechamento IS NULL OR id_funcionario_fechamento IS NULL OR valor_esperado IS NULL OR valor_contado IS NULL)"]]],
'A12'=>['pergunta'=>'Existe conta paga sem forma, data ou funcionário de pagamento?','regra'=>'RN35 e RN56','consultas'=>[[ 'titulo'=>'Contas pagas incompletas','sql'=>"SELECT id_conta FROM CONTA_PAGAR WHERE status='paga' AND (id_forma IS NULL OR data_pagamento IS NULL OR id_funcionario_pagamento IS NULL)"]]],
];

$codigo = strtoupper((string)($_GET['codigo'] ?? ''));
$selecionada = $auditorias[$codigo] ?? null;
$resultados=[]; $erro=null;
if($selecionada){
    try{
        foreach($selecionada['consultas'] as $q){
            $resultados[]=['titulo'=>$q['titulo'],'rows'=>queryAll($q['sql'])];
        }
    }catch(Throwable $e){$erro=$e->getMessage();}
}
require __DIR__.'/partials/header.php';
?>
<?php if($erro): ?><div class="notice notice-danger"><?= e($erro) ?></div><?php endif; ?>
<div class="notice notice-info">Cada botão executa a consulta de auditoria correspondente do script. Resultado vazio significa que aquela inconsistência não foi encontrada.</div>
<div class="audit-list">
<?php foreach($auditorias as $cod=>$a): ?><a class="audit-card <?= $codigo===$cod?'active':'' ?>" href="auditoria.php?codigo=<?= e($cod) ?>"><strong><?= e($cod) ?> · <?= e($a['regra']) ?></strong><small><?= e($a['pergunta']) ?></small></a><?php endforeach; ?>
</div>
<?php if(!$selecionada): ?><section class="panel" style="margin-top:18px"><div class="empty">Escolha uma auditoria acima para executar.</div></section><?php else: ?>
<section class="panel" style="margin-top:18px"><div class="panel-head"><div><h2><?= e($codigo) ?> — <?= e($selecionada['pergunta']) ?></h2><p>Verifica: <?= e($selecionada['regra']) ?></p></div><span class="badge badge-neutral"><?= count($selecionada['consultas']) ?> consulta(s)</span></div><?php if(isset($selecionada['nota'])): ?><div class="notice notice-warn"><?= e($selecionada['nota']) ?></div><?php endif; ?></section>
<?php foreach($resultados as $bloco): ?><section class="panel"><div class="panel-head"><h2><?= e($bloco['titulo']) ?></h2><span class="badge <?= count($bloco['rows'])===0?'badge-ok':'badge-warn' ?>"><?= count($bloco['rows']) ?> resultado(s)</span></div><?php if(!$bloco['rows']): ?><div class="notice notice-ok">Nenhuma inconsistência encontrada.</div><?php else: ?><div class="table-wrap"><table><thead><tr><?php foreach(array_keys($bloco['rows'][0]) as $col): ?><th><?= e($col) ?></th><?php endforeach; ?></tr></thead><tbody><?php foreach($bloco['rows'] as $row): ?><tr><?php foreach($row as $v): ?><td><?= e($v===null?'—':$v) ?></td><?php endforeach; ?></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></section><?php endforeach; ?>
<?php endif; ?>
<?php require __DIR__.'/partials/footer.php'; ?>
