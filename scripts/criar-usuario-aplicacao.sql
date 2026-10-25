-- Executar como proprietario das tabelas depois das migrations.
\set ON_ERROR_STOP on
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='autopecas_app') THEN
    CREATE ROLE autopecas_app LOGIN NOCREATEDB NOCREATEROLE;
  END IF;
END
$$;
\password autopecas_app
\ir permissoes-aplicacao.sql
