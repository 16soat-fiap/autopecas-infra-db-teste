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
GRANT USAGE, SELECT ON SEQUENCE public.os_numero_seq, public.mecanico_seq, public.atendente_seq TO autopecas_app;

-- Nao usar ALTER DEFAULT PRIVILEGES global: tabelas futuras precisam de revisao.
-- Depois de novas migrations, atualize esta lista e execute o script novamente.
