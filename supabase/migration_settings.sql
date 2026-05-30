-- ============================================================
-- BCM · Dados Mestres: Cargos e Setores de Trabalho
-- Execute no Supabase: SQL Editor → New query → Run
-- ============================================================

CREATE TABLE IF NOT EXISTS job_titles (
  id         BIGSERIAL PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE,
  active     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE job_titles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "jt_read"  ON job_titles FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "jt_write" ON job_titles FOR ALL    TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

CREATE TABLE IF NOT EXISTS work_sectors (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  active      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE work_sectors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ws_read"  ON work_sectors FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ws_write" ON work_sectors FOR ALL    TO authenticated
  USING ((SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin','gestor'));

-- Seed: Cargos padrão BCM
INSERT INTO job_titles (name) VALUES
  ('Engenheiro Eletricista'),('Engenheiro de Automação'),('Engenheiro de Software'),
  ('Técnico em Automação'),('Técnico Eletrotécnico'),('Técnico de Campo'),
  ('Eletricista Industrial'),('Eletricista Instalador'),('Auxiliar Elétrico'),
  ('Montador de Painel'),('Programador CLP'),('Programador SCADA'),
  ('Projetista Elétrico'),('Desenhista CAD'),('Supervisor de Obras'),
  ('Encarregado de Obras'),('Assistente Técnico'),('Operador de Painel'),
  ('Gerente de Projetos'),('Coordenador de Automação'),('Diretor Industrial')
ON CONFLICT (name) DO NOTHING;

-- Seed: Setores padrão BCM
INSERT INTO work_sectors (name, description) VALUES
  ('Engenharia Elétrica',    'Projetos e especificações elétricas, dimensionamentos'),
  ('Engenharia de Software', 'Desenvolvimento de sistemas, SCADA, interfaces HMI'),
  ('Engenharia de Automação','CLPs, redes industriais, programação de automação'),
  ('Projetos',               'Documentação técnica, desenhos, diagramas unifilares'),
  ('Montagem de Painel',     'Montagem física de painéis elétricos e CCMs'),
  ('Montagem de Campo',      'Instalação elétrica em campo, cabeamento'),
  ('Comissionamento',        'Testes, start-up e comissionamento de sistemas'),
  ('Manutenção',             'Manutenção preventiva e corretiva'),
  ('Suporte Técnico',        'Suporte remoto e presencial pós-obra'),
  ('Administrativo',         'Gestão administrativa, compras, logística'),
  ('Direção',                'Diretoria e gerência executiva')
ON CONFLICT (name) DO NOTHING;
