#!/usr/bin/env python3
"""Test database permissions in disposable PostgreSQL; never connects to AWS."""
from pathlib import Path
import secrets
import shutil
import subprocess
import time
import unittest
import uuid


class DatabasePermissionsTest(unittest.TestCase):
    @classmethod
    def command(cls, args, *, input=None, success=True):
        result = subprocess.run(args, input=input, text=True, capture_output=True, timeout=120)
        if success and result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result

    @classmethod
    def owner(cls, query=None, file=None, input=None, success=True):
        args = ["docker", "exec", "-i", cls.container, "psql", "-U", "postgres", "-d", "autopecas", "-v", "ON_ERROR_STOP=1"]
        args += ["-f", file] if file else ["-c", query]
        return cls.command(args, input=input, success=success)

    @classmethod
    def setUpClass(cls):
        if not shutil.which("docker"):
            raise RuntimeError("Docker CLI is required")
        cls.command(["docker", "info"])
        cls.container = "autopecas-db-permissions-" + uuid.uuid4().hex[:10]
        cls.password = secrets.token_hex(24)
        cls.addClassCleanup(lambda: subprocess.run(["docker", "rm", "-f", cls.container], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        cls.command(["docker", "run", "--rm", "-d", "--network", "none", "--name", cls.container,
                     "-e", "POSTGRES_PASSWORD=" + cls.password, "-e", "POSTGRES_DB=autopecas", "postgres:16-alpine"])
        for _ in range(60):
            ready = cls.command(["docker", "exec", cls.container, "pg_isready", "-h", "127.0.0.1", "-U", "postgres"], success=False)
            if ready.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError("PostgreSQL did not become ready")
        cls.command(["docker", "cp", str(Path(__file__).resolve().parent), cls.container + ":/scripts"])
        cls.owner(file="/scripts/tests/schema.sql")
        for name in ["lambda", "aplicacao"]:
            cls.owner(file="/scripts/criar-usuario-" + name + ".sql", input=cls.password + "\n" + cls.password + "\n")
        cls.owner(file="/scripts/verificar-permissoes.sql")

    def as_role(self, role, sql, denied=False):
        result = self.command(["docker", "exec", "-e", "PGPASSWORD=" + self.password, self.container,
                               "psql", "-h", "127.0.0.1", "-U", role, "-d", "autopecas",
                               "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate", "-Atc", sql], success=not denied)
        if denied:
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("42501", result.stderr)
        return result.stdout.strip()

    def test_application_crud_and_sequences(self):
        self.as_role("autopecas_app", "INSERT INTO clientes(id,nome) VALUES (1,'teste')")
        self.assertEqual(self.as_role("autopecas_app", "SELECT nome FROM clientes WHERE id=1"), "teste")
        self.as_role("autopecas_app", "UPDATE clientes SET nome='alterado' WHERE id=1")
        self.assertEqual(self.as_role("autopecas_app", "SELECT nome FROM clientes WHERE id=1"), "alterado")
        self.as_role("autopecas_app", "DELETE FROM clientes WHERE id=1")
        self.assertEqual(self.as_role("autopecas_app", "SELECT count(*) FROM clientes"), "0")
        self.assertEqual(self.as_role("autopecas_app", "SELECT nextval('os_numero_seq')"), "1")
        # Colunas BIGSERIAL: o INSERT sem id usa a sequence implicita da tabela.
        self.as_role("autopecas_app", "INSERT INTO historico_status_os(nome) VALUES ('teste')")

    def test_application_cannot_change_schema(self):
        for sql in ["CREATE TABLE public.indevida(id int)", "ALTER TABLE clientes ADD COLUMN indevida int", "DROP TABLE clientes"]:
            self.as_role("autopecas_app", sql, denied=True)

    def test_application_cannot_access_security_or_migration_tables(self):
        for sql in ["SELECT * FROM funcionario_roles", "SELECT * FROM flyway_schema_history",
                    "INSERT INTO funcionario_roles(funcionario_id,role) VALUES (1,'ADMIN')",
                    "DELETE FROM flyway_schema_history WHERE false"]:
            self.as_role("autopecas_app", sql, denied=True)

    def test_lambda_reads_only_required_columns(self):
        for sql in ["SELECT id,ativo FROM clientes", "SELECT id,cpf FROM clientes_pf",
                    "SELECT id,cnpj FROM clientes_pj", "SELECT id,cpf,ativo FROM funcionarios",
                    "SELECT funcionario_id,role FROM funcionario_roles"]:
            self.as_role("lambda_auth", sql)
        self.as_role("lambda_auth", "SELECT nome FROM clientes", denied=True)
        self.as_role("lambda_auth", "SELECT nome FROM funcionarios", denied=True)

    def test_lambda_cannot_write(self):
        for sql in ["UPDATE clientes SET ativo=false WHERE false", "DELETE FROM funcionario_roles WHERE false",
                    "INSERT INTO funcionario_roles(funcionario_id,role) VALUES (1,'ADMIN')",
                    "CREATE TABLE public.indevida(id int)", "SELECT nextval('os_numero_seq')"]:
            self.as_role("lambda_auth", sql, denied=True)

    def test_permissions_can_be_reapplied(self):
        self.owner(file="/scripts/permissoes-aplicacao.sql")
        self.owner(file="/scripts/verificar-permissoes.sql")

    def test_verification_rejects_excessive_permissions(self):
        for role, table in [("autopecas_app", "funcionario_roles"), ("lambda_auth", "clientes")]:
            try:
                self.owner(query="GRANT UPDATE ON " + table + " TO " + role)
                result = self.owner(file="/scripts/verificar-permissoes.sql", success=False)
                self.assertNotEqual(result.returncode, 0)
            finally:
                self.owner(query="REVOKE UPDATE ON " + table + " FROM " + role)
        try:
            self.owner(query="GRANT USAGE ON SEQUENCE os_numero_seq TO lambda_auth")
            result = self.owner(file="/scripts/verificar-permissoes.sql", success=False)
            self.assertNotEqual(result.returncode, 0)
        finally:
            self.owner(query="REVOKE USAGE ON SEQUENCE os_numero_seq FROM lambda_auth")
        self.owner(file="/scripts/verificar-permissoes.sql")


if __name__ == "__main__":
    unittest.main(verbosity=2)
