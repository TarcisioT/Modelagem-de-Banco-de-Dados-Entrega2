<?php
declare(strict_types=1);
require_once __DIR__ . '/funcoes.php';
$titulo = 'Perdas';
$erro = null;
$mensagem = isset($_GET['ok']) ? 'Perda pendente registrada com sucesso.' : null;

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if (!PERMITIR_REGISTRO_PERDA) {
            throw new RuntimeException('O registro de perdas está desativado no config.php para proteger a massa da apresentação.');
        }

        $idProduto = filter_input(INPUT_POST, 'id_produto', FILTER_VALIDATE_INT);
        $idMotivo = filter_input(INPUT_POST, 'id_motivo', FILTER_VALIDATE_INT);
        $idFuncionario = filter_input(INPUT_POST, 'id_funcionario', FILTER_VALIDATE_INT);
        $quantidade = (float)($_POST['quantidade'] ?? 0);
        $dataHora = trim((string)($_POST['data_hora'] ?? ''));
        $observacao = trim((string)($_POST['observacao'] ?? ''));

        if (!$idProduto || !$idMotivo || !$idFuncionario || $quantidade <= 0 || $dataHora === '') {
            throw new RuntimeException('Preencha produto, motivo, funcionário, data/hora e uma quantidade maior que zero.');
        }

        $produto = queryOne("SELECT id_setor FROM PRODUTO WHERE id_produto=:id AND ativo=1", ['id'=>$idProduto]);
        if (!$produto) throw new RuntimeException('Produto ativo não encontrado.');

        $dataSql = (new DateTime($dataHora))->format('Y-m-d H:i:s');
        $stmt = db()->prepare('CALL registrar_perda_pendente(:produto,:setor,:motivo,:funcionario,:data,:quantidade,:observacao)');
        $stmt->execute([
            'produto'=>$idProduto,
            'setor'=>$produto['id_setor'],
            'motivo'=>$idMotivo,
            'funcionario'=>$idFuncionario,
            'data'=>$dataSql,
            'quantidade'=>$quantidade,
            'observacao'=>$observacao !== '' ? $observacao : null,
        ]);
        $stmt->closeCursor();
        header('Location: perdas.php?ok=1');
        exit;
    }

    $setores = queryAll("SELECT id_setor,nome FROM SETOR ORDER BY nome");
    $motivos = queryAll("SELECT id_motivo,descricao FROM MOTIVO_PERDA WHERE ativo=1 ORDER BY descricao");
    $produtos = queryAll("SELECT id_produto,nome FROM PRODUTO WHERE ativo=1 ORDER BY nome");
    $funcionarios = queryAll("SELECT id_funcionario,nome FROM FUNCIONARIO WHERE ativo=1 ORDER BY nome");

    $where = ['1=1']; $params = [];
    $fSetor = filter_input(INPUT_GET, 'setor', FILTER_VALIDATE_INT);
    $fMotivo = filter_input(INPUT_GET, 'motivo', FILTER_VALIDATE_INT);
    $fSituacao = (string)($_GET['situacao'] ?? '');
    if ($fSetor) { $where[]='p.id_setor=:setor'; $params['setor']=$fSetor; }
    if ($fMotivo) { $where[]='p.id_motivo=:motivo'; $params['motivo']=$fMotivo; }
    if (in_array($fSituacao,['confirmado','lote_a_confirmar'],true)) { $where[]='p.situacao_lote=:situacao'; $params['situacao']=$fSituacao; }

    $sql = "SELECT p.id_perda,p.data_hora,pr.nome produto,s.nome setor,m.descricao motivo,f.nome funcionario,l.codigo_lote,p.quantidade,p.valor_estimado,p.situacao_lote,p.status,p.observacao
            FROM PERDA p
            JOIN PRODUTO pr ON pr.id_produto=p.id_produto
            JOIN SETOR s ON s.id_setor=p.id_setor
            JOIN MOTIVO_PERDA m ON m.id_motivo=p.id_motivo
            JOIN FUNCIONARIO f ON f.id_funcionario=p.id_funcionario
            LEFT JOIN LOTE l ON l.id_lote=p.id_lote
            WHERE ".implode(' AND ',$where)."
            ORDER BY p.data_hora DESC,p.id_perda DESC LIMIT 150";
    $perdas = queryAll($sql,$params);

    $resumo = queryOne("SELECT COUNT(*) total, SUM(situacao_lote='lote_a_confirmar') pendentes, COALESCE(SUM(CASE WHEN situacao_lote='confirmado' THEN valor_estimado ELSE 0 END),0) valor_confirmado FROM PERDA WHERE status='valida'");
    $porMotivo = queryAll("SELECT DATE_FORMAT(p.data_hora,'%Y-%m') mes,m.descricao motivo,COUNT(*) ocorrencias FROM PERDA p JOIN MOTIVO_PERDA m ON m.id_motivo=p.id_motivo WHERE p.status='valida' GROUP BY DATE_FORMAT(p.data_hora,'%Y-%m'),m.id_motivo,m.descricao ORDER BY mes DESC,ocorrencias DESC");
} catch (Throwable $e) {
    $erro = $e->getMessage();
    $setores=$setores??[]; $motivos=$motivos??[]; $produtos=$produtos??[]; $funcionarios=$funcionarios??[]; $perdas=$perdas??[]; $resumo=$resumo??[]; $porMotivo=$porMotivo??[];
}

require __DIR__ . '/partials/header.php';
?>
<?php if ($mensagem): ?><div class="notice notice-ok"><?= e($mensagem) ?></div><?php endif; ?>
<?php if ($erro): ?><div class="notice notice-danger"><?= e($erro) ?></div><?php endif; ?>

<section class="cards">
    <div class="card metric"><div class="label">Perdas válidas</div><div class="value"><?= e($resumo['total'] ?? 0) ?></div><div class="hint">Registros atuais</div></div>
    <div class="card metric"><div class="label">Lote a confirmar</div><div class="value"><?= e($resumo['pendentes'] ?? 0) ?></div><div class="hint">Base da G11</div></div>
    <div class="card metric"><div class="label">Valor confirmado</div><div class="value"><?= e(brl($resumo['valor_confirmado'] ?? 0)) ?></div><div class="hint">Somente perdas com lote confirmado</div></div>
</section>

<section class="panel">
    <div class="panel-head"><h2>Consultar perdas</h2><span class="badge badge-neutral">Leitura</span></div>
    <form class="filters" method="get">
        <div class="field"><label>Setor</label><select name="setor"><option value="">Todos</option><?php foreach($setores as $x): ?><option value="<?= e($x['id_setor']) ?>" <?= (string)$fSetor===(string)$x['id_setor']?'selected':'' ?>><?= e($x['nome']) ?></option><?php endforeach; ?></select></div>
        <div class="field"><label>Motivo</label><select name="motivo"><option value="">Todos</option><?php foreach($motivos as $x): ?><option value="<?= e($x['id_motivo']) ?>" <?= (string)$fMotivo===(string)$x['id_motivo']?'selected':'' ?>><?= e($x['descricao']) ?></option><?php endforeach; ?></select></div>
        <div class="field"><label>Situação do lote</label><select name="situacao"><option value="">Todas</option><option value="confirmado" <?= $fSituacao==='confirmado'?'selected':'' ?>>Confirmado</option><option value="lote_a_confirmar" <?= $fSituacao==='lote_a_confirmar'?'selected':'' ?>>A confirmar</option></select></div>
        <button class="btn btn-primary">Filtrar</button><a class="btn btn-secondary" href="perdas.php">Limpar</a>
    </form>
    <div class="table-wrap"><table><thead><tr><th>ID</th><th>Data</th><th>Produto</th><th>Setor</th><th>Motivo</th><th>Qtd.</th><th>Valor</th><th>Lote</th><th>Situação</th><th>Funcionário</th></tr></thead><tbody>
    <?php if(!$perdas): ?><tr><td colspan="10" class="empty">Nenhuma perda encontrada.</td></tr><?php endif; ?>
    <?php foreach($perdas as $r): ?><tr><td><?= e($r['id_perda']) ?></td><td><?= e(dataHoraBr($r['data_hora'])) ?></td><td><?= e($r['produto']) ?></td><td><?= e($r['setor']) ?></td><td><?= e($r['motivo']) ?></td><td><?= e(numero($r['quantidade'])) ?></td><td><?= $r['valor_estimado']===null?'—':e(brl($r['valor_estimado'])) ?></td><td><?= e($r['codigo_lote'] ?: '—') ?></td><td><span class="badge <?= $r['situacao_lote']==='confirmado'?'badge-ok':'badge-warn' ?>"><?= e(str_replace('_',' ',$r['situacao_lote'])) ?></span></td><td><?= e($r['funcionario']) ?></td></tr><?php endforeach; ?>
    </tbody></table></div>
</section>

<div class="grid-2">
<section class="panel">
    <div class="panel-head"><h2>G02 — perdas por motivo</h2><span class="badge badge-neutral">KPI02</span></div>
    <div class="table-wrap"><table><thead><tr><th>Mês</th><th>Motivo</th><th>Ocorrências</th></tr></thead><tbody><?php foreach($porMotivo as $r): ?><tr><td><?= e($r['mes']) ?></td><td><?= e($r['motivo']) ?></td><td><?= e($r['ocorrencias']) ?></td></tr><?php endforeach; ?></tbody></table></div>
</section>
<section class="panel">
    <div class="panel-head"><h2>Registrar perda pendente</h2><span class="badge <?= PERMITIR_REGISTRO_PERDA?'badge-warn':'badge-neutral' ?>"><?= PERMITIR_REGISTRO_PERDA?'Ativado':'Desativado' ?></span></div>
    <?php if(!PERMITIR_REGISTRO_PERDA): ?><div class="notice notice-warn">Proteção da apresentação ativa. Para testar a procedure, altere <code>PERMITIR_REGISTRO_PERDA</code> para <code>true</code> no config.php. A operação altera a massa e não pode ser apagada diretamente.</div><?php endif; ?>
    <form method="post">
        <div class="field"><label>Produto</label><select name="id_produto" required <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>><option value="">Selecione</option><?php foreach($produtos as $x): ?><option value="<?= e($x['id_produto']) ?>"><?= e($x['nome']) ?></option><?php endforeach; ?></select></div><br>
        <div class="grid-2"><div class="field"><label>Motivo</label><select name="id_motivo" required <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>><option value="">Selecione</option><?php foreach($motivos as $x): ?><option value="<?= e($x['id_motivo']) ?>"><?= e($x['descricao']) ?></option><?php endforeach; ?></select></div><div class="field"><label>Funcionário</label><select name="id_funcionario" required <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>><option value="">Selecione</option><?php foreach($funcionarios as $x): ?><option value="<?= e($x['id_funcionario']) ?>"><?= e($x['nome']) ?></option><?php endforeach; ?></select></div></div><br>
        <div class="grid-2"><div class="field"><label>Data/hora</label><input type="datetime-local" name="data_hora" value="<?= e(DATA_REFERENCIA.'T12:00') ?>" required <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>></div><div class="field"><label>Quantidade</label><input type="number" step="0.001" min="0.001" name="quantidade" required <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>></div></div><br>
        <div class="field"><label>Observação</label><textarea name="observacao" maxlength="250" <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>></textarea></div><br>
        <button class="btn btn-primary" <?= PERMITIR_REGISTRO_PERDA?'':'disabled' ?>>Registrar com procedure</button>
    </form>
</section>
</div>
<?php require __DIR__ . '/partials/footer.php'; ?>
