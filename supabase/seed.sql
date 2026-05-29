-- ============================================================
-- BCM Cronograma · Seed
-- Execute APÓS o schema.sql e APÓS Breno fazer o primeiro login
-- ============================================================

-- 1. Promover Breno a admin
UPDATE profiles SET role = 'admin', name = 'Breno Silva'
WHERE email = 'brenobcm@gmail.com';

-- 2. Projeto Special Dog
INSERT INTO projects (name, client, location, start_date, end_date, status, created_by)
SELECT 'Fábrica PET - Special Dog','Special Dog','Matheus Leme MG',
       '2026-04-20','2026-11-28','active', id
FROM auth.users WHERE email = 'brenobcm@gmail.com';

-- 3. Breno como membro
INSERT INTO project_members (project_id, user_id, role)
SELECT 1, id, 'admin' FROM auth.users WHERE email = 'brenobcm@gmail.com';

-- 4. Tarefas (61)
INSERT INTO tasks (project_id,category,name,start_date,end_date,duration,responsible,progress,order_idx) VALUES
-- Sistema de Alimentação
(1,'Sistema de Alimentação','Levantamento e projeto','2026-04-20','2026-05-10',21,'Engenharia',100,0),
(1,'Sistema de Alimentação','Aquisição de equipamentos','2026-05-01','2026-06-15',45,'Compras',60,1),
(1,'Sistema de Alimentação','Montagem mecânica','2026-05-20','2026-07-10',51,'Mecânica',10,2),
(1,'Sistema de Alimentação','Instalação elétrica','2026-06-15','2026-07-25',40,'Elétrica',0,3),
(1,'Sistema de Alimentação','Testes e comissionamento','2026-07-25','2026-08-10',16,'Automação',0,4),
-- Transportadores
(1,'Transportadores','Projeto e especificação','2026-04-20','2026-05-15',25,'Engenharia',100,0),
(1,'Transportadores','Fabricação','2026-05-10','2026-07-01',52,'Fabricação',30,1),
(1,'Transportadores','Montagem','2026-07-01','2026-08-15',45,'Mecânica',0,2),
(1,'Transportadores','Alinhamento e regulagem','2026-08-10','2026-08-25',15,'Mecânica',0,3),
(1,'Transportadores','Integração automação','2026-08-20','2026-09-05',16,'Automação',0,4),
-- Pesagem e Dosagem
(1,'Pesagem e Dosagem','Especificação técnica','2026-04-25','2026-05-20',25,'Engenharia',100,0),
(1,'Pesagem e Dosagem','Aquisição balanças','2026-05-15','2026-06-20',36,'Compras',80,1),
(1,'Pesagem e Dosagem','Montagem sistemas dosagem','2026-06-20','2026-08-01',42,'Mecânica',0,2),
(1,'Pesagem e Dosagem','Instalação transmissores','2026-07-15','2026-08-15',31,'Instrumentação',0,3),
(1,'Pesagem e Dosagem','Calibração e testes','2026-08-15','2026-09-01',17,'Instrumentação',0,4),
-- Misturadoras
(1,'Misturadoras','Projeto detalhado','2026-05-01','2026-05-25',24,'Engenharia',90,0),
(1,'Misturadoras','Aquisição misturadoras','2026-05-20','2026-07-10',51,'Compras',40,1),
(1,'Misturadoras','Instalação mecânica','2026-07-10','2026-08-20',41,'Mecânica',0,2),
(1,'Misturadoras','Instalação elétrica','2026-08-01','2026-08-25',24,'Elétrica',0,3),
(1,'Misturadoras','Comissionamento','2026-08-25','2026-09-10',16,'Automação',0,4),
-- Extrusora
(1,'Extrusora','Projeto e layout','2026-04-20','2026-05-15',25,'Engenharia',100,0),
(1,'Extrusora','Aquisição extrusora','2026-05-01','2026-06-30',60,'Compras',70,1),
(1,'Extrusora','Fundação e ancoragem','2026-06-01','2026-07-01',30,'Civil',20,2),
(1,'Extrusora','Instalação mecânica','2026-07-01','2026-08-15',45,'Mecânica',0,3),
(1,'Extrusora','Instalação elétrica e automação','2026-08-01','2026-09-15',45,'Elétrica',0,4),
(1,'Extrusora','Testes de produção','2026-09-15','2026-10-01',16,'Automação',0,5),
-- Secagem
(1,'Secagem','Projeto do sistema','2026-05-10','2026-06-01',22,'Engenharia',80,0),
(1,'Secagem','Aquisição secadores','2026-06-01','2026-07-20',49,'Compras',20,1),
(1,'Secagem','Montagem','2026-07-20','2026-09-01',43,'Mecânica',0,2),
(1,'Secagem','Instalação elétrica','2026-08-15','2026-09-15',31,'Elétrica',0,3),
(1,'Secagem','Testes e ajustes','2026-09-15','2026-10-01',16,'Automação',0,4),
-- Embalagem
(1,'Embalagem','Especificação embaladoras','2026-05-15','2026-06-10',26,'Engenharia',75,0),
(1,'Embalagem','Aquisição embaladoras','2026-06-10','2026-08-01',52,'Compras',10,1),
(1,'Embalagem','Instalação linha embalagem','2026-08-01','2026-09-20',50,'Mecânica',0,2),
(1,'Embalagem','Integração sistemas','2026-09-10','2026-10-10',30,'Automação',0,3),
(1,'Embalagem','Testes finais','2026-10-10','2026-10-25',15,'Automação',0,4),
-- Automação e Controle
(1,'Automação e Controle','Projeto SCADA','2026-04-20','2026-06-01',42,'Automação',85,0),
(1,'Automação e Controle','Aquisição CLPs e IHMs','2026-05-15','2026-06-30',46,'Compras',50,1),
(1,'Automação e Controle','Montagem painéis elétricos','2026-06-15','2026-08-15',61,'Elétrica',15,2),
(1,'Automação e Controle','Cabeamento e infraestrutura','2026-07-01','2026-09-01',62,'Elétrica',0,3),
(1,'Automação e Controle','Programação CLPs','2026-08-01','2026-10-01',61,'Automação',0,4),
(1,'Automação e Controle','Configuração SCADA','2026-09-01','2026-10-15',44,'Automação',0,5),
(1,'Automação e Controle','Testes integrados','2026-10-15','2026-11-01',17,'Automação',0,6),
(1,'Automação e Controle','Start-up e treinamento','2026-11-01','2026-11-20',19,'Automação',0,7),
-- Utilidades
(1,'Utilidades','Projeto ar comprimido','2026-05-01','2026-05-20',19,'Engenharia',100,0),
(1,'Utilidades','Instalação compressores','2026-05-20','2026-07-01',42,'Mecânica',30,1),
(1,'Utilidades','Rede de ar comprimido','2026-07-01','2026-08-15',45,'Mecânica',0,2),
(1,'Utilidades','Sistema de refrigeração','2026-06-15','2026-08-01',47,'Mecânica',0,3),
(1,'Utilidades','Tratamento de efluentes','2026-07-15','2026-09-15',62,'Civil',0,4),
-- Civil e Infraestrutura
(1,'Civil e Infraestrutura','Sondagem e topografia','2026-04-20','2026-04-30',10,'Civil',100,0),
(1,'Civil e Infraestrutura','Fundações','2026-05-01','2026-06-15',45,'Civil',80,1),
(1,'Civil e Infraestrutura','Estrutura metálica','2026-06-01','2026-08-01',61,'Civil',10,2),
(1,'Civil e Infraestrutura','Alvenaria e cobertura','2026-07-15','2026-09-15',62,'Civil',0,3),
(1,'Civil e Infraestrutura','Piso industrial','2026-08-15','2026-10-01',47,'Civil',0,4),
(1,'Civil e Infraestrutura','Instalações hidráulicas','2026-06-15','2026-08-15',61,'Civil',5,5),
(1,'Civil e Infraestrutura','Instalações elétricas prediais','2026-07-01','2026-09-01',62,'Elétrica',0,6),
-- Comissionamento Geral
(1,'Comissionamento Geral','Pré-comissionamento','2026-09-15','2026-10-10',25,'Automação',0,0),
(1,'Comissionamento Geral','Comissionamento por sistema','2026-10-10','2026-11-01',22,'Automação',0,1),
(1,'Comissionamento Geral','Comissionamento integrado','2026-11-01','2026-11-15',14,'Automação',0,2),
(1,'Comissionamento Geral','Performance test','2026-11-15','2026-11-25',10,'Automação',0,3),
(1,'Comissionamento Geral','Entrega e documentação','2026-11-25','2026-11-28',3,'Engenharia',0,4);
