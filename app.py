import os, sqlite3, json, math
from datetime import datetime, timedelta, date
from typing import Optional, List
from functools import wraps

from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from jose import JWTError, jwt
from passlib.context import CryptContext

# ─── Config ─────────────────────────────────────────────────────────────────
SECRET_KEY = os.environ.get("SECRET_KEY", "bcm-gantt-secret-key-change-in-production-2026")
ALGORITHM  = "HS256"
TOKEN_TTL  = 60 * 24  # minutes
DB_PATH    = os.environ.get("DB_PATH", os.path.join(os.path.dirname(__file__), "gantt.db"))

pwd_ctx = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2  = OAuth2PasswordBearer(tokenUrl="/api/auth/login")
app     = FastAPI(title="BCM Gantt API", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ─── Database ────────────────────────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
    finally:
        conn.close()

def init_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS users (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        name     TEXT NOT NULL,
        email    TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role     TEXT NOT NULL DEFAULT 'tecnico',
        active   INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS projects (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        client      TEXT,
        location    TEXT,
        start_date  TEXT,
        end_date    TEXT,
        status      TEXT DEFAULT 'active',
        created_by  INTEGER REFERENCES users(id),
        created_at  TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS project_members (
        project_id  INTEGER REFERENCES projects(id) ON DELETE CASCADE,
        user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
        role        TEXT NOT NULL,
        PRIMARY KEY (project_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS tasks (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id   INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        category     TEXT NOT NULL,
        name         TEXT NOT NULL,
        start_date   TEXT NOT NULL,
        end_date     TEXT NOT NULL,
        duration     INTEGER,
        responsible  TEXT,
        progress     INTEGER DEFAULT 0,
        order_idx    INTEGER DEFAULT 0,
        created_at   TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS progress_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id    INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        user_id    INTEGER NOT NULL REFERENCES users(id),
        progress   INTEGER NOT NULL,
        note       TEXT,
        created_at TEXT DEFAULT (datetime('now'))
    );
    """)
    conn.commit()

    # Seed admin if no users
    row = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()
    if row["c"] == 0:
        conn.execute(
            "INSERT INTO users (name,email,password,role) VALUES (?,?,?,?)",
            ("Breno Silva", "brenobcm@gmail.com", pwd_ctx.hash("#0612Breno"), "admin")
        )
        conn.commit()
        _seed_special_dog(conn)

    conn.close()

def _seed_special_dog(conn):
    conn.execute("""INSERT INTO projects (name,client,location,start_date,end_date,status,created_by)
        VALUES ('Fábrica PET - Special Dog','Special Dog','Matheus Leme MG','2026-04-20','2026-11-28','active',1)""")
    pid = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
    tasks = [
        # Sistema de Alimentação
        ("Sistema de Alimentação","Levantamento e projeto","2026-04-20","2026-05-10",21,"Engenharia",100,0),
        ("Sistema de Alimentação","Aquisição de equipamentos","2026-05-01","2026-06-15",45,"Compras",60,1),
        ("Sistema de Alimentação","Montagem mecânica","2026-05-20","2026-07-10",51,"Mecânica",10,2),
        ("Sistema de Alimentação","Instalação elétrica","2026-06-15","2026-07-25",40,"Elétrica",0,3),
        ("Sistema de Alimentação","Testes e comissionamento","2026-07-25","2026-08-10",16,"Automação",0,4),
        # Transportadores
        ("Transportadores","Projeto e especificação","2026-04-20","2026-05-15",25,"Engenharia",100,5),
        ("Transportadores","Fabricação","2026-05-10","2026-07-01",52,"Fabricação",30,6),
        ("Transportadores","Montagem","2026-07-01","2026-08-15",45,"Mecânica",0,7),
        ("Transportadores","Alinhamento e regulagem","2026-08-10","2026-08-25",15,"Mecânica",0,8),
        ("Transportadores","Integração automação","2026-08-20","2026-09-05",16,"Automação",0,9),
        # Pesagem e Dosagem
        ("Pesagem e Dosagem","Especificação técnica","2026-04-25","2026-05-20",25,"Engenharia",100,10),
        ("Pesagem e Dosagem","Aquisição balanças","2026-05-15","2026-06-20",36,"Compras",80,11),
        ("Pesagem e Dosagem","Montagem sistemas dosagem","2026-06-20","2026-08-01",42,"Mecânica",0,12),
        ("Pesagem e Dosagem","Instalação transmissores","2026-07-15","2026-08-15",31,"Instrumentação",0,13),
        ("Pesagem e Dosagem","Calibração e testes","2026-08-15","2026-09-01",17,"Instrumentação",0,14),
        # Misturadoras
        ("Misturadoras","Projeto detalhado","2026-05-01","2026-05-25",24,"Engenharia",90,15),
        ("Misturadoras","Aquisição misturadoras","2026-05-20","2026-07-10",51,"Compras",40,16),
        ("Misturadoras","Instalação mecânica","2026-07-10","2026-08-20",41,"Mecânica",0,17),
        ("Misturadoras","Instalação elétrica","2026-08-01","2026-08-25",24,"Elétrica",0,18),
        ("Misturadoras","Comissionamento","2026-08-25","2026-09-10",16,"Automação",0,19),
        # Extrusora
        ("Extrusora","Projeto e layout","2026-04-20","2026-05-15",25,"Engenharia",100,20),
        ("Extrusora","Aquisição extrusora","2026-05-01","2026-06-30",60,"Compras",70,21),
        ("Extrusora","Fundação e ancoragem","2026-06-01","2026-07-01",30,"Civil",20,22),
        ("Extrusora","Instalação mecânica","2026-07-01","2026-08-15",45,"Mecânica",0,23),
        ("Extrusora","Instalação elétrica e automação","2026-08-01","2026-09-15",45,"Elétrica",0,24),
        ("Extrusora","Testes de produção","2026-09-15","2026-10-01",16,"Automação",0,25),
        # Secagem
        ("Secagem","Projeto do sistema","2026-05-10","2026-06-01",22,"Engenharia",80,26),
        ("Secagem","Aquisição secadores","2026-06-01","2026-07-20",49,"Compras",20,27),
        ("Secagem","Montagem","2026-07-20","2026-09-01",43,"Mecânica",0,28),
        ("Secagem","Instalação elétrica","2026-08-15","2026-09-15",31,"Elétrica",0,29),
        ("Secagem","Testes e ajustes","2026-09-15","2026-10-01",16,"Automação",0,30),
        # Embalagem
        ("Embalagem","Especificação embaladoras","2026-05-15","2026-06-10",26,"Engenharia",75,31),
        ("Embalagem","Aquisição embaladoras","2026-06-10","2026-08-01",52,"Compras",10,32),
        ("Embalagem","Instalação linha embalagem","2026-08-01","2026-09-20",50,"Mecânica",0,33),
        ("Embalagem","Integração sistemas","2026-09-10","2026-10-10",30,"Automação",0,34),
        ("Embalagem","Testes finais","2026-10-10","2026-10-25",15,"Automação",0,35),
        # Automação e Controle
        ("Automação e Controle","Projeto SCADA","2026-04-20","2026-06-01",42,"Automação",85,36),
        ("Automação e Controle","Aquisição CLPs e IHMs","2026-05-15","2026-06-30",46,"Compras",50,37),
        ("Automação e Controle","Montagem painéis elétricos","2026-06-15","2026-08-15",61,"Elétrica",15,38),
        ("Automação e Controle","Cabeamento e infraestrutura","2026-07-01","2026-09-01",62,"Elétrica",0,39),
        ("Automação e Controle","Programação CLPs","2026-08-01","2026-10-01",61,"Automação",0,40),
        ("Automação e Controle","Configuração SCADA","2026-09-01","2026-10-15",44,"Automação",0,41),
        ("Automação e Controle","Testes integrados","2026-10-15","2026-11-01",17,"Automação",0,42),
        ("Automação e Controle","Start-up e treinamento","2026-11-01","2026-11-20",19,"Automação",0,43),
        # Utilidades
        ("Utilidades","Projeto ar comprimido","2026-05-01","2026-05-20",19,"Engenharia",100,44),
        ("Utilidades","Instalação compressores","2026-05-20","2026-07-01",42,"Mecânica",30,45),
        ("Utilidades","Rede de ar comprimido","2026-07-01","2026-08-15",45,"Mecânica",0,46),
        ("Utilidades","Sistema de refrigeração","2026-06-15","2026-08-01",47,"Mecânica",0,47),
        ("Utilidades","Tratamento de efluentes","2026-07-15","2026-09-15",62,"Civil",0,48),
        # Civil e Infraestrutura
        ("Civil e Infraestrutura","Sondagem e topografia","2026-04-20","2026-04-30",10,"Civil",100,49),
        ("Civil e Infraestrutura","Fundações","2026-05-01","2026-06-15",45,"Civil",80,50),
        ("Civil e Infraestrutura","Estrutura metálica","2026-06-01","2026-08-01",61,"Civil",10,51),
        ("Civil e Infraestrutura","Alvenaria e cobertura","2026-07-15","2026-09-15",62,"Civil",0,52),
        ("Civil e Infraestrutura","Piso industrial","2026-08-15","2026-10-01",47,"Civil",0,53),
        ("Civil e Infraestrutura","Instalações hidráulicas","2026-06-15","2026-08-15",61,"Civil",5,54),
        ("Civil e Infraestrutura","Instalações elétricas prediais","2026-07-01","2026-09-01",62,"Elétrica",0,55),
        # Comissionamento Geral
        ("Comissionamento Geral","Pré-comissionamento","2026-09-15","2026-10-10",25,"Automação",0,56),
        ("Comissionamento Geral","Comissionamento por sistema","2026-10-10","2026-11-01",22,"Automação",0,57),
        ("Comissionamento Geral","Comissionamento integrado","2026-11-01","2026-11-15",14,"Automação",0,58),
        ("Comissionamento Geral","Performance test","2026-11-15","2026-11-25",10,"Automação",0,59),
        ("Comissionamento Geral","Entrega e documentação","2026-11-25","2026-11-28",3,"Engenharia",0,60),
    ]
    for t in tasks:
        cat,name,sd,ed,dur,resp,prog,idx = t
        conn.execute(
            "INSERT INTO tasks (project_id,category,name,start_date,end_date,duration,responsible,progress,order_idx) VALUES (?,?,?,?,?,?,?,?,?)",
            (pid,cat,name,sd,ed,dur,resp,prog,idx)
        )
    conn.commit()

# ─── Auth ────────────────────────────────────────────────────────────────────
def hash_pw(pw): return pwd_ctx.hash(pw)
def verify_pw(pw, h): return pwd_ctx.verify(pw, h)

def create_token(data: dict):
    exp = datetime.utcnow() + timedelta(minutes=TOKEN_TTL)
    return jwt.encode({**data, "exp": exp}, SECRET_KEY, algorithm=ALGORITHM)

async def current_user(token: str = Depends(oauth2), db=Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        uid = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido")
    user = db.execute("SELECT * FROM users WHERE id=? AND active=1", (uid,)).fetchone()
    if not user:
        raise HTTPException(status_code=401, detail="Usuário não encontrado")
    return dict(user)

def require_roles(*roles):
    async def dep(u=Depends(current_user)):
        if u["role"] not in roles:
            raise HTTPException(status_code=403, detail="Acesso negado")
        return u
    return dep

# ─── Pydantic models ─────────────────────────────────────────────────────────
class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    role: str = "tecnico"

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    role: Optional[str] = None
    active: Optional[int] = None

class ProjectCreate(BaseModel):
    name: str
    client: Optional[str] = None
    location: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None

class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    client: Optional[str] = None
    location: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    status: Optional[str] = None

class TaskCreate(BaseModel):
    category: str
    name: str
    start_date: str
    end_date: str
    duration: Optional[int] = None
    responsible: Optional[str] = None
    progress: int = 0
    order_idx: int = 0

class TaskUpdate(BaseModel):
    category: Optional[str] = None
    name: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    duration: Optional[int] = None
    responsible: Optional[str] = None
    progress: Optional[int] = None
    order_idx: Optional[int] = None

class ProgressUpdate(BaseModel):
    progress: int
    note: Optional[str] = None

class MemberAdd(BaseModel):
    user_id: int
    role: str

# ─── Routes: Auth ────────────────────────────────────────────────────────────
@app.post("/api/auth/login")
async def login(form: OAuth2PasswordRequestForm = Depends(), db=Depends(get_db)):
    user = db.execute("SELECT * FROM users WHERE email=? AND active=1", (form.username,)).fetchone()
    if not user or not verify_pw(form.password, user["password"]):
        raise HTTPException(status_code=401, detail="Credenciais inválidas")
    token = create_token({"sub": str(user["id"]), "role": user["role"]})
    return {"access_token": token, "token_type": "bearer", "role": user["role"], "name": user["name"]}

@app.get("/api/auth/me")
async def me(u=Depends(current_user)):
    return {k: v for k, v in u.items() if k != "password"}

# ─── Routes: Users ───────────────────────────────────────────────────────────
@app.get("/api/users")
async def list_users(db=Depends(get_db), u=Depends(require_roles("admin"))):
    rows = db.execute("SELECT id,name,email,role,active,created_at FROM users ORDER BY name").fetchall()
    return [dict(r) for r in rows]

@app.post("/api/users", status_code=201)
async def create_user(body: UserCreate, db=Depends(get_db), u=Depends(require_roles("admin"))):
    if db.execute("SELECT id FROM users WHERE email=?", (body.email,)).fetchone():
        raise HTTPException(400, "Email já cadastrado")
    db.execute("INSERT INTO users (name,email,password,role) VALUES (?,?,?,?)",
               (body.name, body.email, hash_pw(body.password), body.role))
    db.commit()
    return {"ok": True}

@app.put("/api/users/{uid}")
async def update_user(uid: int, body: UserUpdate, db=Depends(get_db), u=Depends(require_roles("admin"))):
    fields, vals = [], []
    if body.name is not None:     fields.append("name=?");     vals.append(body.name)
    if body.email is not None:    fields.append("email=?");    vals.append(body.email)
    if body.password is not None: fields.append("password=?"); vals.append(hash_pw(body.password))
    if body.role is not None:     fields.append("role=?");     vals.append(body.role)
    if body.active is not None:   fields.append("active=?");   vals.append(body.active)
    if fields:
        db.execute(f"UPDATE users SET {','.join(fields)} WHERE id=?", (*vals, uid))
        db.commit()
    return {"ok": True}

@app.delete("/api/users/{uid}")
async def delete_user(uid: int, db=Depends(get_db), u=Depends(require_roles("admin"))):
    db.execute("UPDATE users SET active=0 WHERE id=?", (uid,))
    db.commit()
    return {"ok": True}

# ─── Routes: Projects ────────────────────────────────────────────────────────
@app.get("/api/projects")
async def list_projects(db=Depends(get_db), u=Depends(current_user)):
    if u["role"] == "admin":
        rows = db.execute("SELECT * FROM projects ORDER BY created_at DESC").fetchall()
    else:
        rows = db.execute("""
            SELECT p.* FROM projects p
            JOIN project_members pm ON pm.project_id=p.id
            WHERE pm.user_id=? ORDER BY p.created_at DESC
        """, (u["id"],)).fetchall()
    return [dict(r) for r in rows]

@app.post("/api/projects", status_code=201)
async def create_project(body: ProjectCreate, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    db.execute(
        "INSERT INTO projects (name,client,location,start_date,end_date,created_by) VALUES (?,?,?,?,?,?)",
        (body.name, body.client, body.location, body.start_date, body.end_date, u["id"])
    )
    db.commit()
    pid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    db.execute("INSERT OR IGNORE INTO project_members VALUES (?,?,?)", (pid, u["id"], u["role"]))
    db.commit()
    return {"id": pid}

@app.get("/api/projects/{pid}")
async def get_project(pid: int, db=Depends(get_db), u=Depends(current_user)):
    proj = db.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
    if not proj:
        raise HTTPException(404, "Projeto não encontrado")
    if u["role"] != "admin":
        mem = db.execute("SELECT 1 FROM project_members WHERE project_id=? AND user_id=?", (pid, u["id"])).fetchone()
        if not mem:
            raise HTTPException(403, "Acesso negado")
    return dict(proj)

@app.put("/api/projects/{pid}")
async def update_project(pid: int, body: ProjectUpdate, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    fields, vals = [], []
    if body.name is not None:       fields.append("name=?");       vals.append(body.name)
    if body.client is not None:     fields.append("client=?");     vals.append(body.client)
    if body.location is not None:   fields.append("location=?");   vals.append(body.location)
    if body.start_date is not None: fields.append("start_date=?"); vals.append(body.start_date)
    if body.end_date is not None:   fields.append("end_date=?");   vals.append(body.end_date)
    if body.status is not None:     fields.append("status=?");     vals.append(body.status)
    if fields:
        db.execute(f"UPDATE projects SET {','.join(fields)} WHERE id=?", (*vals, pid))
        db.commit()
    return {"ok": True}

# ─── Routes: Members ─────────────────────────────────────────────────────────
@app.get("/api/projects/{pid}/members")
async def list_members(pid: int, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    rows = db.execute("""
        SELECT u.id,u.name,u.email,u.role as user_role, pm.role as project_role
        FROM project_members pm JOIN users u ON u.id=pm.user_id
        WHERE pm.project_id=?
    """, (pid,)).fetchall()
    return [dict(r) for r in rows]

@app.post("/api/projects/{pid}/members", status_code=201)
async def add_member(pid: int, body: MemberAdd, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    db.execute("INSERT OR REPLACE INTO project_members VALUES (?,?,?)", (pid, body.user_id, body.role))
    db.commit()
    return {"ok": True}

@app.delete("/api/projects/{pid}/members/{uid}")
async def remove_member(pid: int, uid: int, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    db.execute("DELETE FROM project_members WHERE project_id=? AND user_id=?", (pid, uid))
    db.commit()
    return {"ok": True}

# ─── Routes: Tasks ───────────────────────────────────────────────────────────
@app.get("/api/projects/{pid}/tasks")
async def list_tasks(pid: int, db=Depends(get_db), u=Depends(current_user)):
    if u["role"] != "admin":
        mem = db.execute("SELECT 1 FROM project_members WHERE project_id=? AND user_id=?", (pid, u["id"])).fetchone()
        if not mem:
            raise HTTPException(403, "Acesso negado")
    rows = db.execute(
        "SELECT * FROM tasks WHERE project_id=? ORDER BY category, order_idx, id",
        (pid,)
    ).fetchall()
    return [dict(r) for r in rows]

@app.post("/api/projects/{pid}/tasks", status_code=201)
async def create_task(pid: int, body: TaskCreate, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    db.execute(
        "INSERT INTO tasks (project_id,category,name,start_date,end_date,duration,responsible,progress,order_idx) VALUES (?,?,?,?,?,?,?,?,?)",
        (pid, body.category, body.name, body.start_date, body.end_date, body.duration, body.responsible, body.progress, body.order_idx)
    )
    db.commit()
    tid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return {"id": tid}

@app.put("/api/projects/{pid}/tasks/{tid}")
async def update_task(pid: int, tid: int, body: TaskUpdate, db=Depends(get_db), u=Depends(require_roles("admin","gestor","tecnico"))):
    if u["role"] == "tecnico":
        if body.progress is None:
            raise HTTPException(403, "Técnico só pode atualizar progresso")
        allowed = {"progress"}
        body_dict = {k: v for k, v in body.dict().items() if k == "progress" and v is not None}
    else:
        body_dict = {k: v for k, v in body.dict().items() if v is not None}

    fields, vals = [], []
    for k, v in body_dict.items():
        fields.append(f"{k}=?"); vals.append(v)
    if fields:
        db.execute(f"UPDATE tasks SET {','.join(fields)} WHERE id=? AND project_id=?", (*vals, tid, pid))
        db.commit()
    return {"ok": True}

@app.delete("/api/projects/{pid}/tasks/{tid}")
async def delete_task(pid: int, tid: int, db=Depends(get_db), u=Depends(require_roles("admin","gestor"))):
    db.execute("DELETE FROM tasks WHERE id=? AND project_id=?", (tid, pid))
    db.commit()
    return {"ok": True}

# ─── Routes: Progress log ────────────────────────────────────────────────────
@app.post("/api/projects/{pid}/tasks/{tid}/progress")
async def log_progress(pid: int, tid: int, body: ProgressUpdate, db=Depends(get_db), u=Depends(current_user)):
    if u["role"] == "cliente":
        raise HTTPException(403, "Cliente não pode atualizar progresso")
    db.execute("UPDATE tasks SET progress=? WHERE id=? AND project_id=?", (body.progress, tid, pid))
    db.execute("INSERT INTO progress_log (task_id,user_id,progress,note) VALUES (?,?,?,?)",
               (tid, u["id"], body.progress, body.note))
    db.commit()
    return {"ok": True}

@app.get("/api/projects/{pid}/tasks/{tid}/progress")
async def get_progress_log(pid: int, tid: int, db=Depends(get_db), u=Depends(current_user)):
    rows = db.execute("""
        SELECT pl.*, u.name as user_name FROM progress_log pl
        JOIN users u ON u.id=pl.user_id
        WHERE pl.task_id=? ORDER BY pl.created_at DESC
    """, (tid,)).fetchall()
    return [dict(r) for r in rows]

# ─── Static files + SPA fallback ─────────────────────────────────────────────
static_dir = os.path.join(os.path.dirname(__file__), "static")
app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/")
async def root():
    return FileResponse(os.path.join(static_dir, "login.html"))

@app.get("/dash")
async def dash():
    return FileResponse(os.path.join(static_dir, "dash.html"))

@app.get("/project/{pid}")
async def project_page(pid: int):
    return FileResponse(os.path.join(static_dir, "project.html"))

@app.get("/users")
async def users_page():
    return FileResponse(os.path.join(static_dir, "users.html"))

# ─── Start ───────────────────────────────────────────────────────────────────
init_db()

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8766))
    uvicorn.run("app:app", host="0.0.0.0", port=port, loop="asyncio")
