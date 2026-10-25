-- Execute via psql, com o proprietario das tabelas, depois das migrations.
-- A senha e solicitada pelo comando password, sem literal neste arquivo.
\set ON_ERROR_STOP on
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lambda_auth') THEN
    CREATE ROLE lambda_auth LOGIN;
  END IF;
END
$$;
\password lambda_auth

GRANT CONNECT ON DATABASE autopecas TO lambda_auth;
GRANT USAGE ON SCHEMA public TO lambda_auth;
GRANT SELECT (id, ativo) ON public.clientes TO lambda_auth;
GRANT SELECT (id, cpf) ON public.clientes_pf TO lambda_auth;
GRANT SELECT (id, cnpj) ON public.clientes_pj TO lambda_auth;

-- Executar depois da migration V4 da aplicacao.
GRANT SELECT (id, cpf, ativo) ON public.funcionarios TO lambda_auth;
GRANT SELECT (funcionario_id, role) ON public.funcionario_roles TO lambda_auth;
