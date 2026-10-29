-- Usuario de execucao: sem DDL e sem escrita no historico Flyway ou nas roles.
\set ON_ERROR_STOP on
GRANT CONNECT ON DATABASE autopecas TO autopecas_app;
GRANT USAGE ON SCHEMA public TO autopecas_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    public.clientes,
    public.clientes_pf,
    public.clientes_pj,
    public.veiculos,
    public.funcionarios,
    public.mecanicos,
    public.atendentes,
    public.pecas,
    public.servicos,
    public.ordens_servico,
    public.orcamentos,
    public.itens_orcamento_servico,
    public.itens_orcamento_peca,
    public.itens_servico_os,
    public.itens_peca_os,
    public.movimentacoes_estoque,
    public.historico_status_os
TO autopecas_app;
-- Inclui as sequences implicitas das colunas BIGSERIAL (<tabela>_id_seq): o INSERT
-- sem id chama nextval nelas e falha com 42501 se ficarem de fora.
GRANT USAGE, SELECT ON SEQUENCE
    public.os_numero_seq,
    public.mecanico_seq,
    public.atendente_seq,
    public.itens_orcamento_servico_id_seq,
    public.itens_orcamento_peca_id_seq,
    public.itens_servico_os_id_seq,
    public.itens_peca_os_id_seq,
    public.historico_status_os_id_seq
TO autopecas_app;

-- Nao usar ALTER DEFAULT PRIVILEGES global: tabelas futuras precisam de revisao.
-- Depois de novas migrations, atualize esta lista e execute o script novamente.
