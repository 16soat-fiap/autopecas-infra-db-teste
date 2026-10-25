-- Executar como administrador depois de configurar os dois usuarios.
\set ON_ERROR_STOP on
DO $$
DECLARE
  usuario TEXT;
  tabela RECORD;
BEGIN
  FOREACH usuario IN ARRAY ARRAY['autopecas_app', 'lambda_auth'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname=usuario AND rolcanlogin
      AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole
      AND NOT rolreplication AND NOT rolbypassrls) THEN
      RAISE EXCEPTION 'Role ausente ou administrativa: %', usuario;
    END IF;
    IF has_schema_privilege(usuario, 'public', 'CREATE') THEN
      RAISE EXCEPTION 'Role pode criar objetos no schema public: %', usuario;
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind IN ('r','p','S')
        AND pg_has_role(usuario, c.relowner, 'USAGE')
    ) THEN
      RAISE EXCEPTION 'Role possui ou herda propriedade dos objetos: %', usuario;
    END IF;
  END LOOP;

  FOREACH usuario IN ARRAY ARRAY['public.flyway_schema_history','public.funcionario_roles'] LOOP
    IF has_table_privilege('autopecas_app', usuario, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN
      RAISE EXCEPTION 'Aplicacao tem acesso indevido a %', usuario;
    END IF;
  END LOOP;

  FOR tabela IN SELECT c.oid, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p') LOOP
    IF has_table_privilege('lambda_auth', tabela.oid, 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN
      RAISE EXCEPTION 'Lambda pode modificar tabela %', tabela.relname;
    END IF;
    IF tabela.relname NOT IN ('flyway_schema_history','funcionario_roles') AND (
      NOT has_table_privilege('autopecas_app', tabela.oid, 'SELECT') OR
      NOT has_table_privilege('autopecas_app', tabela.oid, 'INSERT') OR
      NOT has_table_privilege('autopecas_app', tabela.oid, 'UPDATE') OR
      NOT has_table_privilege('autopecas_app', tabela.oid, 'DELETE')
    ) THEN
      RAISE EXCEPTION 'Aplicacao sem permissao de dados em %', tabela.relname;
    END IF;
  END LOOP;

  FOR tabela IN SELECT c.oid, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='S' LOOP
    IF has_sequence_privilege('lambda_auth', tabela.oid, 'USAGE,UPDATE') THEN
      RAISE EXCEPTION 'Lambda pode modificar sequencia %', tabela.relname;
    END IF;
    IF NOT has_sequence_privilege('autopecas_app', tabela.oid, 'USAGE') OR
       NOT has_sequence_privilege('autopecas_app', tabela.oid, 'SELECT') THEN
      RAISE EXCEPTION 'Aplicacao sem permissao na sequencia %', tabela.relname;
    END IF;
  END LOOP;

  IF NOT has_column_privilege('lambda_auth','public.funcionarios','cpf','SELECT') OR
     NOT has_column_privilege('lambda_auth','public.funcionarios','ativo','SELECT') OR
     NOT has_column_privilege('lambda_auth','public.funcionario_roles','role','SELECT') THEN
    RAISE EXCEPTION 'Lambda sem permissao para autenticar funcionarios';
  END IF;
END
$$;
SELECT 'Permissoes verificadas' AS resultado;
