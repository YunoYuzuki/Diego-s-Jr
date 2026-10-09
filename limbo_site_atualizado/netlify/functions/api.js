// =========================================================
// Limbo of Memories — API (Netlify Functions + Turso HTTP)
// Conta, ranking, amizades, chat, busca estilo Riot (nome#tag)
// =========================================================
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const serverless = require('serverless-http');

const app = express();
app.use(cors());
app.use(express.json({ limit: '6mb' }));
// Netlify às vezes entrega body string/base64 sem passar pelo json parser
app.use((req, _res, next) => {
    if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) return next();
    let raw = req.body;
    if (Buffer.isBuffer(raw)) raw = raw.toString('utf8');
    if (typeof raw === 'string' && raw.trim()) {
        try { req.body = JSON.parse(raw); } catch (_) { /* deixa como está */ }
    }
    if (!req.body || typeof req.body !== 'object') req.body = {};
    next();
});

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-troque-em-producao';
const MAX_FITAS_NORMAIS = 7;
const MAX_FITAS_DOURADAS = 2;
const MAX_CARTAS = 20;
const MAX_AVATAR_LENGTH = 5_000_000;
const COOLDOWN_DAYS = 15; // senha e nickname
const ONLINE_THRESHOLD_MS = 2 * 60 * 1000;
const VERIFY_TOKEN_HOURS = 24;

// ---------- Turso HTTP ----------
let schemaReady = false;

function tursoConfig() {
    let url = process.env.TURSO_DATABASE_URL || process.env.LIBSQL_URL || '';
    const authToken = process.env.TURSO_AUTH_TOKEN || '';
    if (!url) {
        const err = new Error('TURSO_DATABASE_URL não configurada.');
        err.code = 'NO_DB';
        throw err;
    }
    url = url.replace(/^libsql:\/\//i, 'https://');
    if (!url.startsWith('http')) url = 'https://' + url;
    return { url: url.replace(/\/$/, ''), authToken };
}

function encodeArg(v) {
    if (v === null || v === undefined) return { type: 'null' };
    if (typeof v === 'number') {
        if (Number.isInteger(v)) return { type: 'integer', value: String(v) };
        return { type: 'float', value: String(v) };
    }
    if (typeof v === 'bigint') return { type: 'integer', value: String(v) };
    if (typeof v === 'boolean') return { type: 'integer', value: v ? '1' : '0' };
    return { type: 'text', value: String(v) };
}

function decodeValue(cell) {
    if (cell == null) return null;
    if (typeof cell !== 'object') return cell;
    if (cell.type === 'null') return null;
    if (cell.type === 'integer') {
        const n = Number(cell.value);
        return Number.isSafeInteger(n) ? n : cell.value;
    }
    if (cell.type === 'float') return Number(cell.value);
    return cell.value;
}

async function tursoPipeline(stmts) {
    const { url, authToken } = tursoConfig();
    const requests = stmts.map((s) => ({
        type: 'execute',
        stmt: { sql: s.sql, args: (s.args || []).map(encodeArg) }
    }));
    requests.push({ type: 'close' });
    const res = await fetch(url + '/v2/pipeline', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + authToken, 'Content-Type': 'application/json' },
        body: JSON.stringify({ requests })
    });
    const body = await res.json().catch(() => null);
    if (!res.ok) throw new Error('Turso HTTP ' + res.status + ': ' + JSON.stringify(body));
    const results = (body && body.results) || [];
    const out = [];
    for (let i = 0; i < stmts.length; i++) {
        const r = results[i];
        if (!r || r.type === 'error') {
            throw new Error((r && r.error && (r.error.message || JSON.stringify(r.error))) || 'query error');
        }
        const result = (r.response && r.response.result) || {};
        const cols = (result.cols || []).map((c) => c.name);
        const rows = (result.rows || []).map((row) => {
            const o = {};
            for (let c = 0; c < cols.length; c++) o[cols[c]] = decodeValue(row[c]);
            return o;
        });
        const rawId = result.last_insert_rowid;
        let lastId = 0;
        if (rawId != null) {
            if (typeof rawId === 'object' && rawId.value != null) lastId = Number(rawId.value);
            else lastId = Number(rawId);
            if (!Number.isFinite(lastId)) lastId = 0;
        }
        const rawAff = result.affected_row_count;
        let aff = 0;
        if (rawAff != null) {
            if (typeof rawAff === 'object' && rawAff.value != null) aff = Number(rawAff.value);
            else aff = Number(rawAff);
            if (!Number.isFinite(aff)) aff = 0;
        }
        out.push({
            columns: cols,
            rows,
            lastInsertRowid: lastId,
            rowsAffected: aff
        });
    }
    return out;
}

async function ensureSchema() {
    if (schemaReady) return;
    const statements = [
        `CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            nickname TEXT DEFAULT NULL,
            bio TEXT DEFAULT NULL,
            avatar_data TEXT DEFAULT NULL,
            role TEXT NOT NULL DEFAULT 'user',
            is_banned INTEGER NOT NULL DEFAULT 0,
            ban_reason TEXT DEFAULT NULL,
            banned_at TEXT DEFAULT NULL,
            nickname_changed_at TEXT DEFAULT NULL,
            password_changed_at TEXT DEFAULT NULL,
            last_seen TEXT DEFAULT NULL,
            banner_color TEXT DEFAULT '#8b5cf6',
            email_verified INTEGER NOT NULL DEFAULT 0,
            email_verify_token TEXT DEFAULT NULL,
            email_verify_expires TEXT DEFAULT NULL,
            player_tag TEXT DEFAULT '0000',
            created_at TEXT DEFAULT (datetime('now'))
        )`,
        `CREATE TABLE IF NOT EXISTS game_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE,
            playtime_seconds INTEGER NOT NULL DEFAULT 0,
            fitas_normais INTEGER NOT NULL DEFAULT 0,
            fitas_douradas INTEGER NOT NULL DEFAULT 0,
            cartas INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS community_posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS bug_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'open',
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS cloud_saves (
            user_id INTEGER NOT NULL,
            slot INTEGER NOT NULL,
            save_json TEXT NOT NULL,
            updated_at TEXT DEFAULT (datetime('now')),
            PRIMARY KEY (user_id, slot),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS friend_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_user_id INTEGER NOT NULL,
            to_user_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (to_user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS friendships (
            user_id INTEGER NOT NULL,
            friend_id INTEGER NOT NULL,
            created_at TEXT DEFAULT (datetime('now')),
            PRIMARY KEY (user_id, friend_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (friend_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS direct_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_id INTEGER NOT NULL,
            recipient_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now')),
            read_at TEXT DEFAULT NULL,
            FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS community_reactions (
            post_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            value INTEGER NOT NULL,
            PRIMARY KEY (post_id, user_id),
            FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS community_comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            parent_id INTEGER DEFAULT NULL,
            content TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE TABLE IF NOT EXISTS friend_duels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            challenger_id INTEGER NOT NULL,
            challenged_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT DEFAULT (datetime('now')),
            accepted_at TEXT DEFAULT NULL,
            FOREIGN KEY (challenger_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (challenged_id) REFERENCES users(id) ON DELETE CASCADE
        )`,
        `CREATE INDEX IF NOT EXISTS idx_progress_playtime ON game_progress (playtime_seconds ASC)`,
        `CREATE INDEX IF NOT EXISTS idx_users_tag ON users (player_tag)`,
        `CREATE INDEX IF NOT EXISTS idx_dm_pair ON direct_messages (sender_id, recipient_id, created_at)`,
        `CREATE INDEX IF NOT EXISTS idx_fr_to ON friend_requests (to_user_id, status)`,
    ];
    for (const sql of statements) {
        try { await tursoPipeline([{ sql, args: [] }]); } catch (e) { console.error('[schema]', e.message); }
    }
    // colunas extras se banco antigo
    const alters = [
        `ALTER TABLE users ADD COLUMN player_tag TEXT DEFAULT '0000'`,
        `ALTER TABLE community_posts ADD COLUMN image_data TEXT DEFAULT NULL`,
        `ALTER TABLE bug_reports ADD COLUMN resolved_at TEXT DEFAULT NULL`,
    ];
    for (const sql of alters) {
        try { await tursoPipeline([{ sql, args: [] }]); } catch (_) {}
    }
    try {
        await tursoPipeline([{ sql: `UPDATE users SET email_verified = 1 WHERE email_verified = 0`, args: [] }]);
    } catch (_) {}
    try {
        await tursoPipeline([{ sql: `UPDATE users SET role = 'admin' WHERE username = ?`, args: ['YunoYuzuki'] }]);
    } catch (_) {}
    // tags vazias
    try {
        await tursoPipeline([{ sql: `UPDATE users SET player_tag = printf('%04d', (id * 73) % 10000) WHERE player_tag IS NULL OR player_tag = '' OR player_tag = '0000'`, args: [] }]);
    } catch (_) {}
    schemaReady = true;
}

async function qAll(sql, args = []) {
    const [r] = await tursoPipeline([{ sql, args }]);
    return r.rows;
}
async function qOne(sql, args = []) {
    const rows = await qAll(sql, args);
    return rows[0] || null;
}
async function qRun(sql, args = []) {
    const [r] = await tursoPipeline([{ sql, args }]);
    return { insertId: Number(r.lastInsertRowid || 0), changes: Number(r.rowsAffected || 0) };
}

function riotId(u) {
    const tag = String(u.player_tag || '0000').padStart(4, '0').slice(0, 5);
    return (u.username || '') + '#' + tag;
}

function publicUser(u, gp) {
    return {
        id: u.id,
        username: u.username,
        nickname: u.nickname || u.username,
        player_tag: String(u.player_tag || '0000').padStart(4, '0'),
        riot_id: riotId(u),
        bio: u.bio || '',
        avatar_data: u.avatar_data || null,
        banner_color: u.banner_color || '#8b5cf6',
        role: u.role || 'user',
        is_online: isOnline(u.last_seen),
        last_seen: u.last_seen || null,
        playtime_seconds: (gp && gp.playtime_seconds) || u.playtime_seconds || 0,
        fitas_normais: (gp && gp.fitas_normais) || u.fitas_normais || 0,
        fitas_douradas: (gp && gp.fitas_douradas) || u.fitas_douradas || 0,
        cartas: (gp && gp.cartas) || u.cartas || 0,
        max_fitas_normais: MAX_FITAS_NORMAIS,
        max_fitas_douradas: MAX_FITAS_DOURADAS,
        max_cartas: MAX_CARTAS
    };
}

function isOnline(lastSeen) {
    if (!lastSeen) return false;
    const t = new Date(lastSeen).getTime();
    if (Number.isNaN(t)) return false;
    return Date.now() - t <= ONLINE_THRESHOLD_MS;
}
function clamp(value, min, max) {
    const n = Number(value);
    if (Number.isNaN(n)) return min;
    return Math.min(Math.max(n, min), max);
}
function daysSince(dateVal) {
    if (!dateVal) return Infinity;
    const t = new Date(dateVal).getTime();
    if (Number.isNaN(t)) return Infinity;
    return (Date.now() - t) / (1000 * 60 * 60 * 24);
}
function nextChangeAt(dateVal) {
    if (!dateVal) return null;
    const d = new Date(dateVal);
    if (Number.isNaN(d.getTime())) return null;
    d.setDate(d.getDate() + COOLDOWN_DAYS);
    return d.toISOString();
}
function hashToken(raw) {
    return crypto.createHash('sha256').update(String(raw)).digest('hex');
}
async function genPlayerTag() {
    for (let i = 0; i < 20; i++) {
        const tag = String(Math.floor(Math.random() * 10000)).padStart(4, '0');
        // tags are not globally unique alone; uniqueness is username#tag — username already unique
        return tag;
    }
    return '1000';
}

function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Token não fornecido.' });
    }
    try {
        const payload = jwt.verify(authHeader.split(' ')[1], JWT_SECRET);
        req.userId = payload.userId;
        req.username = payload.username;
        req.role = payload.role || 'user';
        next();
    } catch {
        return res.status(401).json({ error: 'Token inválido ou expirado.' });
    }
}

async function adminMiddleware(req, res, next) {
    try {
        const row = await qOne('SELECT role, is_banned FROM users WHERE id = ?', [req.userId]);
        if (!row) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (row.is_banned) return res.status(403).json({ error: 'Conta banida.' });
        if (row.role !== 'admin') return res.status(403).json({ error: 'Acesso restrito a administradores.' });
        req.role = 'admin';
        next();
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao verificar permissões.' });
    }
}

async function areFriends(a, b) {
    const row = await qOne(
        `SELECT 1 AS ok FROM friendships WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?) LIMIT 1`,
        [a, b, b, a]
    );
    return !!row;
}

app.use(async (req, res, next) => {
    const p = (req.path || req.url || '').split('?')[0];
    if (p === '/' || p === '/api' || p === '/api/') return next();
    try {
        await ensureSchema();
        next();
    } catch (err) {
        console.error('ensureSchema', err);
        res.status(500).json({
            error: 'Banco indisponível. Configure TURSO_DATABASE_URL e TURSO_AUTH_TOKEN.',
            detail: String(err && err.message ? err.message : err)
        });
    }
});

app.get(['/', '/api', '/api/'], (_req, res) => {
    res.json({
        status: 'ok',
        service: 'Limbo of Memories API',
        mode: 'netlify-functions',
        features: ['profile', 'ranking', 'friends', 'chat', 'search', 'cloud_saves'],
        has_turso_url: !!(process.env.TURSO_DATABASE_URL || process.env.LIBSQL_URL),
        has_turso_token: !!process.env.TURSO_AUTH_TOKEN,
        has_jwt: !!process.env.JWT_SECRET
    });
});

// ===================== AUTH =====================
async function handleRegister(req, res) {
    const { username, email, password } = req.body || {};
    if (!username || !email || !password) return res.status(400).json({ error: 'Preencha usuário, e-mail e senha.' });
    if (String(password).length < 6) return res.status(400).json({ error: 'A senha precisa ter no mínimo 6 caracteres.' });
    const emailNorm = String(email).trim().toLowerCase();
    const userNorm = String(username).trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) return res.status(400).json({ error: 'Informe um e-mail válido.' });
    if (!/^[a-zA-Z0-9_]{3,24}$/.test(userNorm)) return res.status(400).json({ error: 'Usuário: 3–24 caracteres (letras, números ou _).' });
    try {
        const existing = await qOne('SELECT id FROM users WHERE username = ? OR email = ?', [userNorm, emailNorm]);
        if (existing) return res.status(409).json({ error: 'Usuário ou e-mail já cadastrado.' });
        const passwordHash = await bcrypt.hash(password, 10);
        const tag = await genPlayerTag();
        const result = await qRun(
            `INSERT INTO users (username, email, password_hash, nickname, email_verified, player_tag)
             VALUES (?, ?, ?, ?, 1, ?)`,
            [userNorm, emailNorm, passwordHash, userNorm, tag]
        );
        await qRun('INSERT INTO game_progress (user_id) VALUES (?)', [result.insertId]);
        const token = jwt.sign({ userId: result.insertId, username: userNorm, role: 'user' }, JWT_SECRET, { expiresIn: '7d' });
        res.status(201).json({
            ok: true, token, username: userNorm, nickname: userNorm, role: 'user',
            player_tag: tag, riot_id: userNorm + '#' + tag,
            message: 'Conta criada! Você já pode entrar.'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao criar conta.' });
    }
}

async function handleLogin(req, res) {
    const { username, password } = req.body || {};
    if (!username || !password) return res.status(400).json({ error: 'Informe usuário e senha.' });
    try {
        const login = String(username).trim();
        // aceita nome, email ou nome#tag
        let user = null;
        if (login.includes('#')) {
            const [name, tag] = login.split('#');
            user = await qOne(
                `SELECT id, username, nickname, password_hash, role, is_banned, ban_reason, player_tag
                 FROM users WHERE lower(username) = lower(?) AND player_tag = ?`,
                [name.trim(), String(tag).trim().padStart(4, '0')]
            );
        } else {
            user = await qOne(
                `SELECT id, username, nickname, password_hash, role, is_banned, ban_reason, player_tag
                 FROM users WHERE username = ? OR email = ?`,
                [login, login.toLowerCase()]
            );
        }
        if (!user) return res.status(401).json({ error: 'Usuário ou senha incorretos.' });
        if (user.is_banned) return res.status(403).json({ error: 'Conta banida.', ban_reason: user.ban_reason || null });
        const ok = await bcrypt.compare(password, user.password_hash);
        if (!ok) return res.status(401).json({ error: 'Usuário ou senha incorretos.' });
        const token = jwt.sign({ userId: user.id, username: user.username, role: user.role || 'user' }, JWT_SECRET, { expiresIn: '7d' });
        await qRun(`UPDATE users SET last_seen = datetime('now') WHERE id = ?`, [user.id]);
        res.json({
            ok: true, token, username: user.username, nickname: user.nickname || user.username,
            role: user.role || 'user', player_tag: user.player_tag, riot_id: riotId(user)
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao entrar.' });
    }
}

app.post(['/api/register', '/register'], handleRegister);
app.post(['/api/login', '/login'], handleLogin);

app.post(['/api/verify-email', '/verify-email'], async (req, res) => {
    res.json({ ok: true, message: 'Verificação não obrigatória.' });
});
app.post(['/api/resend-verification', '/resend-verification'], async (req, res) => {
    res.json({ ok: true, message: 'Verificação não obrigatória.' });
});

// ===================== PROFILE =====================
app.get(['/api/profile', '/profile'], authMiddleware, async (req, res) => {
    try {
        const p = await qOne(
            `SELECT u.*, gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
             FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id WHERE u.id = ?`,
            [req.userId]
        );
        if (!p) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (p.is_banned) return res.status(403).json({ error: 'Conta banida.', ban_reason: p.ban_reason || null });
        const nickDays = daysSince(p.nickname_changed_at);
        const passDays = daysSince(p.password_changed_at);
        res.json({
            ...publicUser(p),
            email: p.email,
            email_verified: !!p.email_verified,
            nickname_change_available: nickDays >= COOLDOWN_DAYS,
            nickname_next_change_at: nickDays >= COOLDOWN_DAYS ? null : nextChangeAt(p.nickname_changed_at),
            password_change_available: passDays >= COOLDOWN_DAYS,
            password_next_change_at: passDays >= COOLDOWN_DAYS ? null : nextChangeAt(p.password_changed_at),
            cooldown_days: COOLDOWN_DAYS
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao buscar perfil.' });
    }
});

app.put(['/api/profile', '/profile'], authMiddleware, async (req, res) => {
    const { bio, avatar_data, banner_color } = req.body || {};
    if (bio !== undefined && String(bio).length > 300) return res.status(400).json({ error: 'A bio pode ter no máximo 300 caracteres.' });
    if (avatar_data && String(avatar_data).length > MAX_AVATAR_LENGTH) return res.status(400).json({ error: 'Imagem muito grande.' });
    try {
        const check = await qOne('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check && check.is_banned) return res.status(403).json({ error: 'Conta banida.' });
        const fields = [];
        const values = [];
        if (bio !== undefined) { fields.push('bio = ?'); values.push(bio || null); }
        if (avatar_data !== undefined) { fields.push('avatar_data = ?'); values.push(avatar_data || null); }
        if (banner_color !== undefined) {
            const c = String(banner_color || '').trim();
            if (!/^#[0-9A-Fa-f]{6}$/.test(c)) return res.status(400).json({ error: 'Cor inválida.' });
            fields.push('banner_color = ?'); values.push(c);
        }
        if (!fields.length) return res.status(400).json({ error: 'Nenhum campo para atualizar.' });
        values.push(req.userId);
        await qRun(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, values);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao atualizar perfil.' });
    }
});

app.get(['/api/players/:username', '/players/:username'], authMiddleware, async (req, res) => {
    try {
        let name = req.params.username;
        let tag = null;
        if (name.includes('#')) {
            const parts = name.split('#');
            name = parts[0];
            tag = parts[1];
        }
        let p;
        if (tag) {
            p = await qOne(
                `SELECT u.*, gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
                 FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id
                 WHERE lower(u.username) = lower(?) AND u.player_tag = ?`,
                [name, String(tag).padStart(4, '0')]
            );
        } else {
            p = await qOne(
                `SELECT u.*, gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
                 FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id WHERE u.username = ?`,
                [name]
            );
        }
        if (!p || p.is_banned) return res.status(404).json({ error: 'Jogador não encontrado.' });
        const friend = await areFriends(req.userId, p.id);
        res.json({ ...publicUser(p), is_friend: friend, is_self: p.id === req.userId });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao buscar jogador.' });
    }
});

// Busca: nome, nickname, id numérico, ou nome#tag
app.get(['/api/search', '/search'], authMiddleware, async (req, res) => {
    try {
        const q = String(req.query.q || '').trim();
        if (q.length < 1) return res.json([]);
        let rows = [];
        if (/^\d+$/.test(q)) {
            rows = await qAll(
                `SELECT u.id, u.username, u.nickname, u.player_tag, u.avatar_data, u.banner_color, u.last_seen, u.role,
                        gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
                 FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id
                 WHERE u.id = ? AND u.is_banned = 0 LIMIT 10`,
                [Number(q)]
            );
        } else if (q.includes('#')) {
            const [name, tag] = q.split('#');
            rows = await qAll(
                `SELECT u.id, u.username, u.nickname, u.player_tag, u.avatar_data, u.banner_color, u.last_seen, u.role,
                        gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
                 FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id
                 WHERE lower(u.username) = lower(?) AND u.player_tag = ? AND u.is_banned = 0 LIMIT 10`,
                [name.trim(), String(tag).trim().padStart(4, '0')]
            );
        } else {
            const like = '%' + q.toLowerCase() + '%';
            rows = await qAll(
                `SELECT u.id, u.username, u.nickname, u.player_tag, u.avatar_data, u.banner_color, u.last_seen, u.role,
                        gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
                 FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id
                 WHERE u.is_banned = 0 AND (lower(u.username) LIKE ? OR lower(COALESCE(u.nickname,'')) LIKE ?)
                 ORDER BY u.username ASC LIMIT 20`,
                [like, like]
            );
        }
        res.json(rows.map((r) => publicUser(r)));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro na busca.' });
    }
});

app.put(['/api/account/nickname', '/account/nickname'], authMiddleware, async (req, res) => {
    const nickname = String((req.body && req.body.nickname) || '').trim();
    if (!nickname || nickname.length > 50) return res.status(400).json({ error: 'Nickname inválido (1–50).' });
    try {
        const u = await qOne('SELECT is_banned, nickname_changed_at FROM users WHERE id = ?', [req.userId]);
        if (!u) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (u.is_banned) return res.status(403).json({ error: 'Conta banida.' });
        if (daysSince(u.nickname_changed_at) < COOLDOWN_DAYS) {
            return res.status(429).json({
                error: `Aguarde ${COOLDOWN_DAYS} dias entre mudanças de nickname.`,
                next_change_at: nextChangeAt(u.nickname_changed_at)
            });
        }
        await qRun(`UPDATE users SET nickname = ?, nickname_changed_at = datetime('now') WHERE id = ?`, [nickname, req.userId]);
        res.json({ ok: true, nickname });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao alterar nickname.' });
    }
});

app.put(['/api/account/password', '/account/password'], authMiddleware, async (req, res) => {
    const { current_password, new_password } = req.body || {};
    if (!current_password || !new_password) return res.status(400).json({ error: 'Informe a senha atual e a nova.' });
    if (String(new_password).length < 6) return res.status(400).json({ error: 'Nova senha: mín. 6 caracteres.' });
    try {
        const u = await qOne('SELECT password_hash, is_banned, password_changed_at FROM users WHERE id = ?', [req.userId]);
        if (!u) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (u.is_banned) return res.status(403).json({ error: 'Conta banida.' });
        if (daysSince(u.password_changed_at) < COOLDOWN_DAYS) {
            return res.status(429).json({
                error: `Aguarde ${COOLDOWN_DAYS} dias entre mudanças de senha.`,
                next_change_at: nextChangeAt(u.password_changed_at)
            });
        }
        const ok = await bcrypt.compare(current_password, u.password_hash);
        if (!ok) return res.status(401).json({ error: 'Senha atual incorreta.' });
        const hash = await bcrypt.hash(String(new_password), 10);
        await qRun(`UPDATE users SET password_hash = ?, password_changed_at = datetime('now') WHERE id = ?`, [hash, req.userId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao alterar senha.' });
    }
});

// ===================== PROGRESS / PRESENCE =====================
app.put(['/api/progress', '/progress'], authMiddleware, async (req, res) => {
    try {
        const check = await qOne('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check && check.is_banned) return res.status(403).json({ error: 'Conta banida.' });
        const playtime_seconds = clamp(req.body.playtime_seconds, 0, 99999999);
        const fitas_normais = clamp(req.body.fitas_normais, 0, MAX_FITAS_NORMAIS);
        const fitas_douradas = clamp(req.body.fitas_douradas, 0, MAX_FITAS_DOURADAS);
        const cartas = clamp(req.body.cartas, 0, MAX_CARTAS);
        const existing = await qOne('SELECT user_id, playtime_seconds, fitas_normais, fitas_douradas, cartas FROM game_progress WHERE user_id = ?', [req.userId]);
        if (existing) {
            // GREATEST — só sobe
            await qRun(
                `UPDATE game_progress SET
                   playtime_seconds = MAX(playtime_seconds, ?),
                   fitas_normais = MAX(fitas_normais, ?),
                   fitas_douradas = MAX(fitas_douradas, ?),
                   cartas = MAX(cartas, ?),
                   updated_at = datetime('now')
                 WHERE user_id = ?`,
                [playtime_seconds, fitas_normais, fitas_douradas, cartas, req.userId]
            );
        } else {
            await qRun(
                `INSERT INTO game_progress (user_id, playtime_seconds, fitas_normais, fitas_douradas, cartas) VALUES (?, ?, ?, ?, ?)`,
                [req.userId, playtime_seconds, fitas_normais, fitas_douradas, cartas]
            );
        }
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao salvar progresso.' });
    }
});

app.post(['/api/progress/reset', '/progress/reset'], authMiddleware, async (req, res) => {
    try {
        await qRun(
            `UPDATE game_progress SET playtime_seconds = 0, fitas_normais = 0, fitas_douradas = 0, cartas = 0, updated_at = datetime('now') WHERE user_id = ?`,
            [req.userId]
        );
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao resetar progresso.' });
    }
});

app.post(['/api/presence', '/presence'], authMiddleware, async (req, res) => {
    try {
        await qRun(`UPDATE users SET last_seen = datetime('now') WHERE id = ?`, [req.userId]);
        res.json({ ok: true, is_online: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao atualizar presença.' });
    }
});

// ===================== CLOUD SAVES =====================
function summarizeSaveJson(saveJson) {
    let data = {};
    try { data = typeof saveJson === 'string' ? JSON.parse(saveJson) : saveJson || {}; }
    catch (_) { return { capitulo: '?', playtime_seconds: 0, fitas: 0, cartas: 0, corrupt: true }; }
    const fr = data.fitas_reproduzidas || {};
    let fitas = 0;
    if (Array.isArray(fr)) fitas = fr.length;
    else if (fr && typeof fr === 'object') for (const k of Object.keys(fr)) if (fr[k]) fitas += 1;
    const cartasArr = data.cartas || [];
    let cartas = 0;
    if (Array.isArray(cartasArr)) cartas = cartasArr.length;
    else if (cartasArr && typeof cartasArr === 'object') cartas = Object.keys(cartasArr).length;
    return { capitulo: data.capitulo || 'O Limbo', playtime_seconds: parseInt(data.playtime_seconds || 0, 10) || 0, fitas, cartas, corrupt: false };
}

app.get(['/api/saves', '/saves'], authMiddleware, async (req, res) => {
    try {
        const rows = await qAll(`SELECT slot, updated_at, length(save_json) AS size, save_json FROM cloud_saves WHERE user_id = ? ORDER BY slot ASC`, [req.userId]);
        res.json(rows.map((r) => {
            const sum = summarizeSaveJson(r.save_json);
            return { slot: r.slot, updated_at: r.updated_at, size: r.size, ...sum };
        }));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar saves.' });
    }
});

app.get(['/api/saves/:slot', '/saves/:slot'], authMiddleware, async (req, res) => {
    try {
        const slot = parseInt(req.params.slot, 10);
        if (Number.isNaN(slot) || slot < 0 || slot > 20) return res.status(400).json({ error: 'Slot inválido.' });
        const row = await qOne('SELECT save_json, updated_at FROM cloud_saves WHERE user_id = ? AND slot = ?', [req.userId, slot]);
        if (!row) return res.status(404).json({ error: 'Save não encontrado.' });
        res.json({ slot, updated_at: row.updated_at, data: JSON.parse(row.save_json) });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao baixar save.' });
    }
});

app.put(['/api/saves/:slot', '/saves/:slot'], authMiddleware, async (req, res) => {
    try {
        const slot = parseInt(req.params.slot, 10);
        if (Number.isNaN(slot) || slot < 0 || slot > 20) return res.status(400).json({ error: 'Slot inválido.' });
        const payload = req.body && req.body.data !== undefined ? req.body.data : req.body;
        if (payload == null) return res.status(400).json({ error: 'Envie os dados do save.' });
        const saveJson = typeof payload === 'string' ? payload : JSON.stringify(payload);
        if (saveJson.length > 5_000_000) return res.status(413).json({ error: 'Save grande demais.' });
        await qRun(
            `INSERT INTO cloud_saves (user_id, slot, save_json, updated_at) VALUES (?, ?, ?, datetime('now'))
             ON CONFLICT(user_id, slot) DO UPDATE SET save_json = excluded.save_json, updated_at = datetime('now')`,
            [req.userId, slot, saveJson]
        );
        res.json({ ok: true, slot });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao salvar na nuvem.' });
    }
});

app.delete(['/api/saves/:slot', '/saves/:slot'], authMiddleware, async (req, res) => {
    try {
        await qRun('DELETE FROM cloud_saves WHERE user_id = ? AND slot = ?', [req.userId, parseInt(req.params.slot, 10)]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar save.' });
    }
});

// ===================== RANKING (só quem tem progresso) =====================
app.get(['/api/ranking', '/ranking'], async (_req, res) => {
    try {
        const rows = await qAll(`
            SELECT u.username, u.nickname, u.player_tag, u.avatar_data, u.banner_color, u.last_seen, u.id,
                   gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
            FROM game_progress gp
            JOIN users u ON u.id = gp.user_id
            WHERE u.is_banned = 0
              AND (gp.fitas_normais > 0 OR gp.fitas_douradas > 0 OR gp.cartas > 0 OR gp.playtime_seconds > 60)
            ORDER BY gp.fitas_douradas DESC, gp.fitas_normais DESC, gp.cartas DESC, gp.playtime_seconds ASC
            LIMIT 50
        `);
        res.json(rows.map((r) => publicUser(r)));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao carregar ranking.' });
    }
});

// ===================== FRIENDS =====================
app.get(['/api/friends', '/friends'], authMiddleware, async (req, res) => {
    try {
        const rows = await qAll(
            `SELECT u.id, u.username, u.nickname, u.player_tag, u.avatar_data, u.banner_color, u.last_seen,
                    gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
             FROM friendships f
             JOIN users u ON u.id = f.friend_id
             LEFT JOIN game_progress gp ON gp.user_id = u.id
             WHERE f.user_id = ? AND u.is_banned = 0
             ORDER BY u.nickname COLLATE NOCASE ASC`,
            [req.userId]
        );
        res.json(rows.map((r) => publicUser(r)));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar amigos.' });
    }
});

app.get(['/api/friends/requests', '/friends/requests'], authMiddleware, async (req, res) => {
    try {
        const incoming = await qAll(
            `SELECT fr.id, fr.from_user_id, fr.created_at, u.username, u.nickname, u.player_tag, u.avatar_data
             FROM friend_requests fr JOIN users u ON u.id = fr.from_user_id
             WHERE fr.to_user_id = ? AND fr.status = 'pending' ORDER BY fr.created_at DESC`,
            [req.userId]
        );
        const outgoing = await qAll(
            `SELECT fr.id, fr.to_user_id, fr.created_at, u.username, u.nickname, u.player_tag, u.avatar_data
             FROM friend_requests fr JOIN users u ON u.id = fr.to_user_id
             WHERE fr.from_user_id = ? AND fr.status = 'pending' ORDER BY fr.created_at DESC`,
            [req.userId]
        );
        res.json({
            incoming: incoming.map((r) => ({ id: r.id, created_at: r.created_at, user: { id: r.from_user_id, username: r.username, nickname: r.nickname, player_tag: r.player_tag, riot_id: r.username + '#' + r.player_tag, avatar_data: r.avatar_data } })),
            outgoing: outgoing.map((r) => ({ id: r.id, created_at: r.created_at, user: { id: r.to_user_id, username: r.username, nickname: r.nickname, player_tag: r.player_tag, riot_id: r.username + '#' + r.player_tag, avatar_data: r.avatar_data } }))
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar pedidos.' });
    }
});

app.post(['/api/friends/request', '/friends/request'], authMiddleware, async (req, res) => {
    try {
        let toId = Number(req.body && req.body.to_user_id);
        const toRiot = String((req.body && (req.body.to_riot_id || req.body.riot_id || req.body.query)) || '').trim();
        if (!toId && toRiot) {
            if (toRiot.includes('#')) {
                const [name, tag] = toRiot.split('#');
                const u = await qOne(`SELECT id FROM users WHERE lower(username)=lower(?) AND player_tag=?`, [name.trim(), String(tag).trim().padStart(4, '0')]);
                if (u) toId = u.id;
            } else if (/^\d+$/.test(toRiot)) {
                toId = Number(toRiot);
            } else {
                const u = await qOne(`SELECT id FROM users WHERE lower(username)=lower(?)`, [toRiot]);
                if (u) toId = u.id;
            }
        }
        if (!toId) return res.status(404).json({ error: 'Jogador não encontrado.' });
        if (toId === req.userId) return res.status(400).json({ error: 'Não pode adicionar a si mesmo.' });
        const target = await qOne('SELECT id, is_banned FROM users WHERE id = ?', [toId]);
        if (!target || target.is_banned) return res.status(404).json({ error: 'Jogador não encontrado.' });
        if (await areFriends(req.userId, toId)) return res.status(409).json({ error: 'Vocês já são amigos.' });
        const existing = await qOne(
            `SELECT id, status FROM friend_requests WHERE
             ((from_user_id=? AND to_user_id=?) OR (from_user_id=? AND to_user_id=?)) AND status='pending' LIMIT 1`,
            [req.userId, toId, toId, req.userId]
        );
        if (existing) return res.status(409).json({ error: 'Já existe um pedido pendente.' });
        const result = await qRun(
            `INSERT INTO friend_requests (from_user_id, to_user_id, status) VALUES (?, ?, 'pending')`,
            [req.userId, toId]
        );
        res.status(201).json({ ok: true, id: result.insertId });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao enviar pedido.' });
    }
});

app.post(['/api/friends/accept', '/friends/accept'], authMiddleware, async (req, res) => {
    try {
        const id = Number(req.body && req.body.request_id);
        const fr = await qOne(`SELECT * FROM friend_requests WHERE id = ? AND to_user_id = ? AND status = 'pending'`, [id, req.userId]);
        if (!fr) return res.status(404).json({ error: 'Pedido não encontrado.' });
        await qRun(`UPDATE friend_requests SET status = 'accepted' WHERE id = ?`, [id]);
        // mutual
        await qRun(`INSERT OR IGNORE INTO friendships (user_id, friend_id) VALUES (?, ?)`, [fr.from_user_id, fr.to_user_id]);
        await qRun(`INSERT OR IGNORE INTO friendships (user_id, friend_id) VALUES (?, ?)`, [fr.to_user_id, fr.from_user_id]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao aceitar pedido.' });
    }
});

app.post(['/api/friends/reject', '/friends/reject'], authMiddleware, async (req, res) => {
    try {
        const id = Number(req.body && req.body.request_id);
        await qRun(`UPDATE friend_requests SET status = 'rejected' WHERE id = ? AND to_user_id = ? AND status = 'pending'`, [id, req.userId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao recusar pedido.' });
    }
});

app.delete(['/api/friends/:id', '/friends/:id'], authMiddleware, async (req, res) => {
    try {
        const fid = Number(req.params.id);
        await qRun(`DELETE FROM friendships WHERE (user_id=? AND friend_id=?) OR (user_id=? AND friend_id=?)`, [req.userId, fid, fid, req.userId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao remover amigo.' });
    }
});

// ===================== CHAT =====================
app.get(['/api/chat/:friendId', '/chat/:friendId'], authMiddleware, async (req, res) => {
    try {
        const fid = Number(req.params.friendId);
        if (!(await areFriends(req.userId, fid))) return res.status(403).json({ error: 'Só é possível conversar com amigos.' });
        const rows = await qAll(
            `SELECT id, sender_id, recipient_id, content, created_at, read_at
             FROM direct_messages
             WHERE (sender_id=? AND recipient_id=?) OR (sender_id=? AND recipient_id=?)
             ORDER BY created_at ASC LIMIT 200`,
            [req.userId, fid, fid, req.userId]
        );
        await qRun(
            `UPDATE direct_messages SET read_at = datetime('now')
             WHERE sender_id = ? AND recipient_id = ? AND read_at IS NULL`,
            [fid, req.userId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao carregar chat.' });
    }
});

app.post(['/api/chat/:friendId', '/chat/:friendId'], authMiddleware, async (req, res) => {
    try {
        const fid = Number(req.params.friendId);
        const content = String((req.body && req.body.content) || '').trim();
        if (!content) return res.status(400).json({ error: 'Mensagem vazia.' });
        if (content.length > 1000) return res.status(400).json({ error: 'Máx. 1000 caracteres.' });
        if (!(await areFriends(req.userId, fid))) return res.status(403).json({ error: 'Só é possível conversar com amigos.' });
        const result = await qRun(
            `INSERT INTO direct_messages (sender_id, recipient_id, content) VALUES (?, ?, ?)`,
            [req.userId, fid, content]
        );
        res.status(201).json({ ok: true, id: result.insertId });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao enviar mensagem.' });
    }
});

// ===================== COMMUNITY / BUGS / DUELOS =====================
async function purgeResolvedBugs() {
    try {
        await qRun(`DELETE FROM bug_reports WHERE status = 'resolved' AND resolved_at IS NOT NULL AND datetime(resolved_at) <= datetime('now', '-1 hour')`);
    } catch (_) {}
}

async function enrichPosts(posts, viewerId) {
    if (!posts.length) return [];
    const ids = posts.map((p) => p.id);
    const placeholders = ids.map(() => '?').join(',');
    const reactions = await qAll(
        `SELECT post_id, value, COUNT(*) AS c FROM community_reactions WHERE post_id IN (${placeholders}) GROUP BY post_id, value`,
        ids
    );
    const myReact = await qAll(
        `SELECT post_id, value FROM community_reactions WHERE user_id = ? AND post_id IN (${placeholders})`,
        [viewerId, ...ids]
    );
    const comments = await qAll(
        `SELECT c.id, c.post_id, c.user_id, c.parent_id, c.content, c.created_at,
                u.username, u.nickname, u.avatar_data, u.player_tag
         FROM community_comments c JOIN users u ON u.id = c.user_id
         WHERE c.post_id IN (${placeholders}) AND u.is_banned = 0
         ORDER BY c.created_at ASC`,
        ids
    );
    const likeMap = {}, dislikeMap = {}, myMap = {};
    for (const r of reactions) {
        if (Number(r.value) === 1) likeMap[r.post_id] = Number(r.c);
        if (Number(r.value) === -1) dislikeMap[r.post_id] = Number(r.c);
    }
    for (const r of myReact) myMap[r.post_id] = Number(r.value);
    const byPost = {};
    for (const c of comments) {
        if (!byPost[c.post_id]) byPost[c.post_id] = [];
        byPost[c.post_id].push({
            id: c.id, parent_id: c.parent_id, content: c.content, created_at: c.created_at,
            user: { id: c.user_id, username: c.username, nickname: c.nickname, avatar_data: c.avatar_data, player_tag: c.player_tag, riot_id: c.username + '#' + String(c.player_tag || '0000').padStart(4, '0') }
        });
    }
    return posts.map((p) => ({
        ...p,
        likes: likeMap[p.id] || 0,
        dislikes: dislikeMap[p.id] || 0,
        my_reaction: myMap[p.id] || 0,
        comments: byPost[p.id] || [],
        riot_id: p.username + '#' + String(p.player_tag || '0000').padStart(4, '0')
    }));
}

app.get(['/api/community', '/community'], authMiddleware, async (req, res) => {
    try {
        const rows = await qAll(`
            SELECT p.id, p.content, p.image_data, p.created_at, p.user_id,
                   u.username, u.nickname, u.avatar_data, u.role, u.player_tag
            FROM community_posts p JOIN users u ON u.id = p.user_id
            WHERE u.is_banned = 0 ORDER BY p.created_at DESC LIMIT 60`);
        res.json(await enrichPosts(rows, req.userId));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao carregar comunidade.' });
    }
});

app.post(['/api/community', '/community', '/api/community/', '/community/'], authMiddleware, async (req, res) => {
    try {
        const body = (req.body && typeof req.body === 'object') ? req.body : {};
        const content = String(body.content || '').trim();
        let image_data = body.image_data || body.imageData || null;
        if (image_data != null) image_data = String(image_data);
        if (image_data === '') image_data = null;

        if (!content && !image_data) {
            return res.status(400).json({ error: 'Escreva algo ou envie uma foto.' });
        }
        if (content.length > 1000) {
            return res.status(400).json({ error: 'Máximo 1000 caracteres.' });
        }
        if (image_data && image_data.length > 2_500_000) {
            return res.status(400).json({ error: 'Imagem muito grande.' });
        }

        // Conta banida não posta
        const me = await qOne('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (!me) return res.status(401).json({ error: 'Sessão inválida. Faça login de novo.' });
        if (me.is_banned) return res.status(403).json({ error: 'Conta banida.' });

        // Cooldown leve (não bloqueia se a query de tempo falhar)
        try {
            const recent = await qOne(
                `SELECT id FROM community_posts WHERE user_id=? AND created_at > datetime('now','-12 seconds') LIMIT 1`,
                [req.userId]
            );
            if (recent) return res.status(429).json({ error: 'Aguarde alguns segundos.' });
        } catch (_) { /* ignora */ }

        // Garante coluna image_data (bancos antigos)
        try {
            await tursoPipeline([{ sql: `ALTER TABLE community_posts ADD COLUMN image_data TEXT DEFAULT NULL`, args: [] }]);
        } catch (_) { /* já existe */ }

        let result;
        try {
            result = await qRun(
                'INSERT INTO community_posts (user_id, content, image_data) VALUES (?, ?, ?)',
                [req.userId, content || '', image_data]
            );
        } catch (err1) {
            // Fallback se a coluna image_data ainda não existir / rejeitar
            console.error('community insert c/ imagem falhou, tentando sem imagem:', err1 && err1.message);
            result = await qRun(
                'INSERT INTO community_posts (user_id, content) VALUES (?, ?)',
                [req.userId, content || (image_data ? '[imagem]' : '')]
            );
        }

        const newId = result && result.insertId ? result.insertId : 0;
        // Confirma que gravou
        if (!newId) {
            const last = await qOne(
                `SELECT id FROM community_posts WHERE user_id=? ORDER BY id DESC LIMIT 1`,
                [req.userId]
            );
            return res.status(201).json({ id: last ? last.id : 0, ok: true });
        }
        return res.status(201).json({ id: newId, ok: true });
    } catch (err) {
        console.error('POST /community', err);
        res.status(500).json({
            error: 'Erro ao publicar.',
            detail: String(err && err.message ? err.message : err)
        });
    }
});

app.delete(['/api/community/:id', '/community/:id'], authMiddleware, async (req, res) => {
    try {
        const postId = Number(req.params.id);
        const row = await qOne('SELECT user_id FROM community_posts WHERE id = ?', [postId]);
        if (!row) return res.status(404).json({ error: 'Post não encontrado.' });
        const me = await qOne('SELECT role FROM users WHERE id = ?', [req.userId]);
        if (row.user_id !== req.userId && !(me && me.role === 'admin')) return res.status(403).json({ error: 'Sem permissão.' });
        await qRun('DELETE FROM community_reactions WHERE post_id = ?', [postId]);
        await qRun('DELETE FROM community_comments WHERE post_id = ?', [postId]);
        await qRun('DELETE FROM community_posts WHERE id = ?', [postId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar.' });
    }
});

app.post(['/api/community/:id/react', '/community/:id/react'], authMiddleware, async (req, res) => {
    try {
        const postId = Number(req.params.id);
        let value = Number(req.body && req.body.value);
        if (![1, -1, 0].includes(value)) return res.status(400).json({ error: 'Reação inválida.' });
        const post = await qOne('SELECT id FROM community_posts WHERE id = ?', [postId]);
        if (!post) return res.status(404).json({ error: 'Post não encontrado.' });
        if (value === 0) {
            await qRun('DELETE FROM community_reactions WHERE post_id = ? AND user_id = ?', [postId, req.userId]);
        } else {
            await qRun(
                `INSERT INTO community_reactions (post_id, user_id, value) VALUES (?, ?, ?)
                 ON CONFLICT(post_id, user_id) DO UPDATE SET value = excluded.value`,
                [postId, req.userId, value]
            );
        }
        const likes = await qOne(`SELECT COUNT(*) AS c FROM community_reactions WHERE post_id=? AND value=1`, [postId]);
        const dislikes = await qOne(`SELECT COUNT(*) AS c FROM community_reactions WHERE post_id=? AND value=-1`, [postId]);
        res.json({ ok: true, likes: Number(likes && likes.c) || 0, dislikes: Number(dislikes && dislikes.c) || 0, my_reaction: value });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao reagir.' });
    }
});

app.post(['/api/community/:id/comments', '/community/:id/comments'], authMiddleware, async (req, res) => {
    try {
        const postId = Number(req.params.id);
        const content = String((req.body && req.body.content) || '').trim();
        const parent_id = req.body && req.body.parent_id != null ? Number(req.body.parent_id) : null;
        if (!content) return res.status(400).json({ error: 'Comentário vazio.' });
        if (content.length > 500) return res.status(400).json({ error: 'Máx. 500 caracteres.' });
        const post = await qOne('SELECT id FROM community_posts WHERE id = ?', [postId]);
        if (!post) return res.status(404).json({ error: 'Post não encontrado.' });
        if (parent_id) {
            const parent = await qOne('SELECT id FROM community_comments WHERE id = ? AND post_id = ?', [parent_id, postId]);
            if (!parent) return res.status(404).json({ error: 'Comentário pai não encontrado.' });
        }
        const result = await qRun(
            'INSERT INTO community_comments (post_id, user_id, parent_id, content) VALUES (?, ?, ?, ?)',
            [postId, req.userId, parent_id, content]
        );
        res.status(201).json({ ok: true, id: result.insertId });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao comentar.' });
    }
});

app.delete(['/api/community/comments/:id', '/community/comments/:id'], authMiddleware, async (req, res) => {
    try {
        const id = Number(req.params.id);
        const row = await qOne('SELECT user_id FROM community_comments WHERE id = ?', [id]);
        if (!row) return res.status(404).json({ error: 'Comentário não encontrado.' });
        const me = await qOne('SELECT role FROM users WHERE id = ?', [req.userId]);
        if (row.user_id !== req.userId && !(me && me.role === 'admin')) return res.status(403).json({ error: 'Sem permissão.' });
        await qRun('DELETE FROM community_comments WHERE id = ? OR parent_id = ?', [id, id]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar comentário.' });
    }
});

// ---- Bugs ----
app.post(['/api/bugs', '/bugs'], authMiddleware, async (req, res) => {
    const title = String((req.body && req.body.title) || '').trim();
    const description = String((req.body && req.body.description) || '').trim();
    if (!title || !description) return res.status(400).json({ error: 'Preencha título e descrição.' });
    try {
        await qRun('INSERT INTO bug_reports (user_id, title, description, status) VALUES (?, ?, ?, ?)',
            [req.userId, title.slice(0, 120), description.slice(0, 2000), 'open']);
        res.status(201).json({ ok: true, message: 'Bug reportado.' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao enviar report.' });
    }
});

app.get(['/api/bugs/mine', '/bugs/mine'], authMiddleware, async (req, res) => {
    try {
        await purgeResolvedBugs();
        res.json(await qAll(`SELECT id, title, description, status, created_at, resolved_at FROM bug_reports WHERE user_id=? ORDER BY created_at DESC LIMIT 30`, [req.userId]));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro.' });
    }
});

// ---- Duelos entre amigos ----
app.get(['/api/duels', '/duels'], authMiddleware, async (req, res) => {
    try {
        const rows = await qAll(
            `SELECT d.*,
                c.username AS challenger_username, c.nickname AS challenger_nickname, c.player_tag AS challenger_tag, c.avatar_data AS challenger_avatar,
                e.username AS challenged_username, e.nickname AS challenged_nickname, e.player_tag AS challenged_tag, e.avatar_data AS challenged_avatar,
                gp1.fitas_normais AS c_fitas, gp1.fitas_douradas AS c_douradas, gp1.cartas AS c_cartas, gp1.playtime_seconds AS c_time,
                gp2.fitas_normais AS e_fitas, gp2.fitas_douradas AS e_douradas, gp2.cartas AS e_cartas, gp2.playtime_seconds AS e_time
             FROM friend_duels d
             JOIN users c ON c.id = d.challenger_id
             JOIN users e ON e.id = d.challenged_id
             LEFT JOIN game_progress gp1 ON gp1.user_id = d.challenger_id
             LEFT JOIN game_progress gp2 ON gp2.user_id = d.challenged_id
             WHERE (d.challenger_id = ? OR d.challenged_id = ?) AND d.status IN ('pending','active')
             ORDER BY d.created_at DESC LIMIT 40`,
            [req.userId, req.userId]
        );
        res.json(rows.map((d) => ({
            id: d.id, status: d.status, created_at: d.created_at, accepted_at: d.accepted_at,
            challenger: { id: d.challenger_id, username: d.challenger_username, nickname: d.challenger_nickname, player_tag: d.challenger_tag, avatar_data: d.challenger_avatar, riot_id: d.challenger_username + '#' + String(d.challenger_tag || '0000').padStart(4, '0'), fitas_normais: d.c_fitas || 0, fitas_douradas: d.c_douradas || 0, cartas: d.c_cartas || 0, playtime_seconds: d.c_time || 0 },
            challenged: { id: d.challenged_id, username: d.challenged_username, nickname: d.challenged_nickname, player_tag: d.challenged_tag, avatar_data: d.challenged_avatar, riot_id: d.challenged_username + '#' + String(d.challenged_tag || '0000').padStart(4, '0'), fitas_normais: d.e_fitas || 0, fitas_douradas: d.e_douradas || 0, cartas: d.e_cartas || 0, playtime_seconds: d.e_time || 0 },
            is_challenger: d.challenger_id === req.userId
        })));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar duelos.' });
    }
});

app.post(['/api/duels', '/duels'], authMiddleware, async (req, res) => {
    try {
        const toId = Number(req.body && req.body.to_user_id);
        if (!toId || toId === req.userId) return res.status(400).json({ error: 'Adversário inválido.' });
        if (!(await areFriends(req.userId, toId))) return res.status(403).json({ error: 'Só pode desafiar amigos.' });
        const existing = await qOne(
            `SELECT id FROM friend_duels WHERE status IN ('pending','active') AND
             ((challenger_id=? AND challenged_id=?) OR (challenger_id=? AND challenged_id=?)) LIMIT 1`,
            [req.userId, toId, toId, req.userId]
        );
        if (existing) return res.status(409).json({ error: 'Já existe um duelo pendente ou ativo com este amigo.' });
        const r = await qRun(`INSERT INTO friend_duels (challenger_id, challenged_id, status) VALUES (?, ?, 'pending')`, [req.userId, toId]);
        res.status(201).json({ ok: true, id: r.insertId });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao criar duelo.' });
    }
});

app.post(['/api/duels/:id/accept', '/duels/:id/accept'], authMiddleware, async (req, res) => {
    try {
        const id = Number(req.params.id);
        const d = await qOne(`SELECT * FROM friend_duels WHERE id=? AND challenged_id=? AND status='pending'`, [id, req.userId]);
        if (!d) return res.status(404).json({ error: 'Duelo não encontrado.' });
        await qRun(`UPDATE friend_duels SET status='active', accepted_at=datetime('now') WHERE id=?`, [id]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao aceitar duelo.' });
    }
});

app.post(['/api/duels/:id/decline', '/duels/:id/decline'], authMiddleware, async (req, res) => {
    try {
        const id = Number(req.params.id);
        await qRun(`UPDATE friend_duels SET status='declined' WHERE id=? AND challenged_id=? AND status='pending'`, [id, req.userId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao recusar duelo.' });
    }
});

app.delete(['/api/duels/:id', '/duels/:id'], authMiddleware, async (req, res) => {
    try {
        const id = Number(req.params.id);
        await qRun(`DELETE FROM friend_duels WHERE id=? AND (challenger_id=? OR challenged_id=?)`, [id, req.userId, req.userId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao encerrar duelo.' });
    }
});

// ===================== ADMIN =====================
app.get(['/api/admin/users', '/admin/users'], authMiddleware, adminMiddleware, async (_req, res) => {
    try {
        res.json(await qAll(`SELECT u.id, u.username, u.email, u.nickname, u.player_tag, u.role, u.is_banned, u.ban_reason, u.banned_at, u.created_at,
            gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
            FROM users u LEFT JOIN game_progress gp ON gp.user_id = u.id ORDER BY u.created_at DESC`));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro.' });
    }
});

app.post(['/api/admin/ban', '/admin/ban'], authMiddleware, adminMiddleware, async (req, res) => {
    const uid = Number(req.body && req.body.user_id);
    if (!uid || uid === req.userId) return res.status(400).json({ error: 'user_id inválido.' });
    await qRun(`UPDATE users SET is_banned=1, ban_reason=?, banned_at=datetime('now') WHERE id=?`, [String((req.body && req.body.reason) || '').slice(0, 500) || null, uid]);
    res.json({ ok: true });
});

app.post(['/api/admin/unban', '/admin/unban'], authMiddleware, adminMiddleware, async (req, res) => {
    const uid = Number(req.body && req.body.user_id);
    await qRun(`UPDATE users SET is_banned=0, ban_reason=NULL, banned_at=NULL WHERE id=?`, [uid]);
    res.json({ ok: true });
});

app.delete(['/api/admin/users/:id', '/admin/users/:id'], authMiddleware, adminMiddleware, async (req, res) => {
    try {
        const uid = Number(req.params.id);
        if (!uid) return res.status(400).json({ error: 'ID inválido.' });
        if (uid === req.userId) return res.status(400).json({ error: 'Não pode apagar a própria conta.' });
        const target = await qOne('SELECT id, username, role FROM users WHERE id = ?', [uid]);
        if (!target) return res.status(404).json({ error: 'Usuário não encontrado.' });
        // Limpa dados relacionados (Turso pode não forçar FK CASCADE)
        await qRun('DELETE FROM direct_messages WHERE sender_id = ? OR recipient_id = ?', [uid, uid]);
        await qRun('DELETE FROM friendships WHERE user_id = ? OR friend_id = ?', [uid, uid]);
        await qRun('DELETE FROM friend_requests WHERE from_user_id = ? OR to_user_id = ?', [uid, uid]);
        await qRun('DELETE FROM community_reactions WHERE user_id = ? OR post_id IN (SELECT id FROM community_posts WHERE user_id = ?)', [uid, uid]);
        await qRun('DELETE FROM community_comments WHERE user_id = ? OR post_id IN (SELECT id FROM community_posts WHERE user_id = ?)', [uid, uid]);
        await qRun('DELETE FROM community_posts WHERE user_id = ?', [uid]);
        await qRun('DELETE FROM friend_duels WHERE challenger_id = ? OR challenged_id = ?', [uid, uid]);
        await qRun('DELETE FROM bug_reports WHERE user_id = ?', [uid]);
        await qRun('DELETE FROM cloud_saves WHERE user_id = ?', [uid]);
        await qRun('DELETE FROM game_progress WHERE user_id = ?', [uid]);
        await qRun('DELETE FROM users WHERE id = ?', [uid]);
        res.json({ ok: true, deleted: target.username });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar conta.' });
    }
});

app.get(['/api/admin/bugs', '/admin/bugs'], authMiddleware, adminMiddleware, async (_req, res) => {
    try {
        await purgeResolvedBugs();
        res.json(await qAll(`SELECT b.*, u.username, u.nickname, u.player_tag FROM bug_reports b JOIN users u ON u.id=b.user_id ORDER BY
            CASE b.status WHEN 'open' THEN 0 WHEN 'reviewing' THEN 1 ELSE 2 END, b.created_at DESC LIMIT 100`));
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar bugs.' });
    }
});

app.put(['/api/admin/bugs/:id', '/admin/bugs/:id'], authMiddleware, adminMiddleware, async (req, res) => {
    try {
        const status = String((req.body && req.body.status) || '');
        // open = Em aberto | reviewing = Analisando | resolved = Resolvido (some em 1h)
        if (!['open', 'reviewing', 'resolved'].includes(status)) {
            return res.status(400).json({ error: 'Status inválido. Use open, reviewing ou resolved.' });
        }
        if (status === 'resolved') {
            await qRun(`UPDATE bug_reports SET status=?, resolved_at=datetime('now') WHERE id=?`, [status, Number(req.params.id)]);
        } else {
            await qRun(`UPDATE bug_reports SET status=?, resolved_at=NULL WHERE id=?`, [status, Number(req.params.id)]);
        }
        res.json({ ok: true, status });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao atualizar bug.' });
    }
});

app.delete(['/api/admin/bugs/:id', '/admin/bugs/:id'], authMiddleware, adminMiddleware, async (req, res) => {
    try {
        await qRun('DELETE FROM bug_reports WHERE id = ?', [Number(req.params.id)]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar bug.' });
    }
});

app.get(['/api/admin/users/:id/saves', '/admin/users/:id/saves'], authMiddleware, adminMiddleware, async (req, res) => {
    const rows = await qAll(`SELECT slot, updated_at, length(save_json) AS size, save_json FROM cloud_saves WHERE user_id=? ORDER BY slot`, [parseInt(req.params.id, 10)]);
    res.json(rows.map((r) => ({ slot: r.slot, updated_at: r.updated_at, size: r.size, ...summarizeSaveJson(r.save_json) })));
});

app.delete(['/api/admin/users/:id/saves/:slot', '/admin/users/:id/saves/:slot'], authMiddleware, adminMiddleware, async (req, res) => {
    await qRun('DELETE FROM cloud_saves WHERE user_id=? AND slot=?', [parseInt(req.params.id, 10), parseInt(req.params.slot, 10)]);
    res.json({ ok: true });
});

app.delete(['/api/admin/users/:id/saves', '/admin/users/:id/saves'], authMiddleware, adminMiddleware, async (req, res) => {
    await qRun('DELETE FROM cloud_saves WHERE user_id=?', [parseInt(req.params.id, 10)]);
    res.json({ ok: true });
});

// Export
const expressHandler = serverless(app, { binary: false });

function normalizeEvent(event) {
    let path = event.path || event.rawPath || event.requestContext?.http?.path || '/';
    // Strip function prefix variants
    path = path.replace(/^\/\.netlify\/functions\/api/, '/api');
    path = path.replace(/^\/\.netlify\/functions\/api\//, '/api/');
    // Some redirects deliver only the splat ("/community") without /api
    if (path !== '/api' && !path.startsWith('/api/') && path !== '/') {
        const roots = ['/register','/login','/profile','/ranking','/community','/bugs','/saves','/progress','/presence','/account','/admin','/players','/friends','/chat','/search','/duels','/verify','/resend'];
        if (roots.some((r) => path === r || path.startsWith(r + '/'))) path = '/api' + path;
    }
    // Trailing slash normalize (keep root)
    if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
    event.path = path;
    // Body base64 (Netlify)
    if (event.isBase64Encoded && typeof event.body === 'string') {
        try {
            event.body = Buffer.from(event.body, 'base64').toString('utf8');
            event.isBase64Encoded = false;
        } catch (_) {}
    }
    return event;
}

exports.handler = async (event, context) => {
    try {
        return await expressHandler(normalizeEvent(event), context);
    } catch (err) {
        console.error('handler crash', err);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Erro interno na function.', detail: String(err && err.message ? err.message : err) })
        };
    }
};
