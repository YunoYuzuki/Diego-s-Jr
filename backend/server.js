// =========================================================
// Limbo of Memories - Backend (Node.js + Express + MySQL)
// =========================================================
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');

const app = express();
app.use(cors());
app.use(express.json({ limit: '6mb' }));

app.get('/', (req, res) => {
    res.json({ status: 'ok', service: 'Limbo of Memories API' });
});

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET;

const MAX_FITAS_NORMAIS = 7;
const MAX_FITAS_DOURADAS = 2;
const MAX_CARTAS = 20;
const MAX_AVATAR_LENGTH = 5_000_000;
const COOLDOWN_DAYS = 14;

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306,
    waitForConnections: true,
    connectionLimit: 10
});

const ONLINE_THRESHOLD_MS = 2 * 60 * 1000; // 2 minutos

async function ensureUserColumns() {
    try {
        await pool.query("ALTER TABLE users ADD COLUMN last_seen DATETIME NULL DEFAULT NULL");
    } catch (e) { /* já existe */ }
    try {
        await pool.query("ALTER TABLE users ADD COLUMN banner_color VARCHAR(7) NULL DEFAULT '#8b5cf6'");
    } catch (e) { /* já existe */ }
}
ensureUserColumns().catch(err => console.error('ensureUserColumns', err));

function isOnline(lastSeen) {
    if (!lastSeen) return false;
    const t = new Date(lastSeen).getTime();
    if (Number.isNaN(t)) return false;
    return (Date.now() - t) <= ONLINE_THRESHOLD_MS;
}


function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Token não fornecido.' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const payload = jwt.verify(token, JWT_SECRET);
        req.userId = payload.userId;
        req.username = payload.username;
        req.role = payload.role || 'user';
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Token inválido ou expirado.' });
    }
}

async function adminMiddleware(req, res, next) {
    try {
        const [rows] = await pool.query(
            'SELECT role, is_banned FROM users WHERE id = ?',
            [req.userId]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (rows[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });
        if (rows[0].role !== 'admin') return res.status(403).json({ error: 'Acesso restrito a administradores.' });
        req.role = 'admin';
        next();
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao verificar permissões.' });
    }
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

// =========================================================
// AUTH
// =========================================================
app.post('/api/register', async (req, res) => {
    const { username, email, password } = req.body;
    if (!username || !email || !password) {
        return res.status(400).json({ error: 'Preencha usuário, e-mail e senha.' });
    }
    if (password.length < 6) {
        return res.status(400).json({ error: 'A senha precisa ter no mínimo 6 caracteres.' });
    }
    try {
        const [existing] = await pool.query(
            'SELECT id FROM users WHERE username = ? OR email = ?',
            [username, email]
        );
        if (existing.length > 0) {
            return res.status(409).json({ error: 'Usuário ou e-mail já cadastrado.' });
        }
        const passwordHash = await bcrypt.hash(password, 10);
        const [result] = await pool.query(
            'INSERT INTO users (username, email, password_hash, nickname) VALUES (?, ?, ?, ?)',
            [username, email, passwordHash, username]
        );
        await pool.query('INSERT INTO game_progress (user_id) VALUES (?)', [result.insertId]);
        const token = jwt.sign(
            { userId: result.insertId, username, role: 'user' },
            JWT_SECRET,
            { expiresIn: '7d' }
        );
        res.status(201).json({ token, username, nickname: username, role: 'user' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao criar conta.' });
    }
});

app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) {
        return res.status(400).json({ error: 'Preencha usuário e senha.' });
    }
    try {
        const [rows] = await pool.query(
            'SELECT id, username, password_hash, nickname, role, is_banned, ban_reason FROM users WHERE username = ?',
            [username]
        );
        if (rows.length === 0) {
            return res.status(401).json({ error: 'Usuário ou senha incorretos.' });
        }
        const user = rows[0];
        const valid = await bcrypt.compare(password, user.password_hash);
        if (!valid) {
            return res.status(401).json({ error: 'Usuário ou senha incorretos.' });
        }
        if (user.is_banned) {
            return res.status(403).json({
                error: 'Conta banida.',
                ban_reason: user.ban_reason || 'Sem motivo informado.',
                banned: true
            });
        }
        const token = jwt.sign(
            { userId: user.id, username: user.username, role: user.role || 'user' },
            JWT_SECRET,
            { expiresIn: '7d' }
        );
        res.json({
            token,
            username: user.username,
            nickname: user.nickname || user.username,
            role: user.role || 'user'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao entrar na conta.' });
    }
});

// =========================================================
// PROFILE
// =========================================================
app.get('/api/profile', authMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(
            `SELECT u.username, u.email, u.nickname, u.bio, u.avatar_data, u.role, u.is_banned, u.ban_reason,
                    u.nickname_changed_at, u.password_changed_at, u.last_seen, u.banner_color,
                    gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
             FROM users u
             LEFT JOIN game_progress gp ON gp.user_id = u.id
             WHERE u.id = ?`,
            [req.userId]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Usuário não encontrado.' });
        const p = rows[0];
        if (p.is_banned) {
            return res.status(403).json({
                error: 'Conta banida.',
                ban_reason: p.ban_reason || 'Sem motivo informado.',
                banned: true
            });
        }
        const nickDays = daysSince(p.nickname_changed_at);
        const passDays = daysSince(p.password_changed_at);
        res.json({
            username: p.username,
            email: p.email,
            nickname: p.nickname || p.username,
            bio: p.bio || '',
            avatar_data: p.avatar_data || null,
            role: p.role || 'user',
            banner_color: p.banner_color || '#8b5cf6',
            is_online: isOnline(p.last_seen),
            last_seen: p.last_seen || null,
            playtime_seconds: p.playtime_seconds || 0,
            fitas_normais: p.fitas_normais || 0,
            fitas_douradas: p.fitas_douradas || 0,
            todas_fitas_douradas: (p.fitas_douradas || 0) >= MAX_FITAS_DOURADAS,
            cartas: p.cartas || 0,
            max_fitas_normais: MAX_FITAS_NORMAIS,
            max_fitas_douradas: MAX_FITAS_DOURADAS,
            max_cartas: MAX_CARTAS,
            nickname_change_available: nickDays >= COOLDOWN_DAYS,
            nickname_next_change_at: nickDays >= COOLDOWN_DAYS ? null : nextChangeAt(p.nickname_changed_at),
            password_change_available: passDays >= COOLDOWN_DAYS,
            password_next_change_at: passDays >= COOLDOWN_DAYS ? null : nextChangeAt(p.password_changed_at)
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao buscar perfil.' });
    }
});

app.put('/api/profile', authMiddleware, async (req, res) => {
    const { nickname, bio, avatar_data, banner_color } = req.body;
    if (nickname !== undefined && nickname.length > 50) {
        return res.status(400).json({ error: 'O nickname pode ter no máximo 50 caracteres.' });
    }
    if (bio !== undefined && bio.length > 300) {
        return res.status(400).json({ error: 'A bio pode ter no máximo 300 caracteres.' });
    }
    if (avatar_data && avatar_data.length > MAX_AVATAR_LENGTH) {
        return res.status(400).json({ error: 'Imagem muito grande. Escolha uma foto menor.' });
    }
    try {
        const [check] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check.length && check[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        const fields = [];
        const values = [];
        // nickname aqui não aplica cooldown — use /account/nickname
        if (bio !== undefined) { fields.push('bio = ?'); values.push(bio || null); }
        if (avatar_data !== undefined) { fields.push('avatar_data = ?'); values.push(avatar_data || null); }
        if (banner_color !== undefined) {
            const c = String(banner_color || '').trim();
            if (!/^#[0-9A-Fa-f]{6}$/.test(c)) {
                return res.status(400).json({ error: 'Cor do banner inválida. Use formato #RRGGBB.' });
            }
            fields.push('banner_color = ?');
            values.push(c);
        }
        // permite nickname só se não for mudança "séria" via profile (frontend manda via account/nickname)
        if (nickname !== undefined && fields.length === 0 && avatar_data === undefined && bio === undefined) {
            // ignore pure nickname here
        } else if (nickname !== undefined) {
            // atualiza nickname sem cooldown se vier junto (compat), mas o frontend usa endpoint dedicado
            fields.push('nickname = ?');
            values.push(nickname || null);
        }

        if (fields.length === 0) {
            return res.status(400).json({ error: 'Nenhum campo para atualizar.' });
        }
        values.push(req.userId);
        await pool.query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, values);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao atualizar perfil.' });
    }
});

// Perfil público de outro jogador (precisa estar logado)
app.get('/api/players/:username', authMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(
            `SELECT u.username, u.nickname, u.bio, u.avatar_data, u.role, u.is_banned,
                    u.last_seen, u.banner_color,
                    gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
             FROM users u
             LEFT JOIN game_progress gp ON gp.user_id = u.id
             WHERE u.username = ?`,
            [req.params.username]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Jogador não encontrado.' });
        const p = rows[0];
        if (p.is_banned) return res.status(404).json({ error: 'Jogador não encontrado.' });
        res.json({
            username: p.username,
            banner_color: p.banner_color || '#8b5cf6',
            is_online: isOnline(p.last_seen),
            last_seen: p.last_seen || null,
            nickname: p.nickname || p.username,
            bio: p.bio || '',
            avatar_data: p.avatar_data || null,
            role: p.role || 'user',
            playtime_seconds: p.playtime_seconds || 0,
            fitas_normais: p.fitas_normais || 0,
            fitas_douradas: p.fitas_douradas || 0,
            todas_fitas_douradas: (p.fitas_douradas || 0) >= MAX_FITAS_DOURADAS,
            cartas: p.cartas || 0,
            max_fitas_normais: MAX_FITAS_NORMAIS,
            max_fitas_douradas: MAX_FITAS_DOURADAS,
            max_cartas: MAX_CARTAS
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao buscar jogador.' });
    }
});

// =========================================================
// ACCOUNT SECURITY (14 dias)
// =========================================================
app.put('/api/account/nickname', authMiddleware, async (req, res) => {
    const { nickname } = req.body;
    if (!nickname || !String(nickname).trim()) {
        return res.status(400).json({ error: 'Informe o novo nickname.' });
    }
    if (String(nickname).trim().length > 50) {
        return res.status(400).json({ error: 'O nickname pode ter no máximo 50 caracteres.' });
    }
    try {
        const [rows] = await pool.query(
            'SELECT nickname, nickname_changed_at, is_banned FROM users WHERE id = ?',
            [req.userId]
        );
        if (!rows.length) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (rows[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        const elapsed = daysSince(rows[0].nickname_changed_at);
        if (elapsed < COOLDOWN_DAYS) {
            return res.status(429).json({
                error: 'Você só pode alterar o nickname a cada 14 dias.',
                nickname_next_change_at: nextChangeAt(rows[0].nickname_changed_at)
            });
        }
        await pool.query(
            'UPDATE users SET nickname = ?, nickname_changed_at = NOW() WHERE id = ?',
            [String(nickname).trim(), req.userId]
        );
        res.json({ ok: true, nickname: String(nickname).trim() });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao alterar nickname.' });
    }
});

app.put('/api/account/password', authMiddleware, async (req, res) => {
    const { current_password, new_password } = req.body;
    if (!current_password || !new_password) {
        return res.status(400).json({ error: 'Informe a senha atual e a nova senha.' });
    }
    if (String(new_password).length < 8) {
        return res.status(400).json({ error: 'A nova senha precisa ter pelo menos 8 caracteres.' });
    }
    try {
        const [rows] = await pool.query(
            'SELECT password_hash, password_changed_at, is_banned FROM users WHERE id = ?',
            [req.userId]
        );
        if (!rows.length) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (rows[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        const elapsed = daysSince(rows[0].password_changed_at);
        if (elapsed < COOLDOWN_DAYS) {
            return res.status(429).json({
                error: 'Você só pode alterar a senha a cada 14 dias.',
                password_next_change_at: nextChangeAt(rows[0].password_changed_at)
            });
        }
        const valid = await bcrypt.compare(current_password, rows[0].password_hash);
        if (!valid) return res.status(401).json({ error: 'Senha atual incorreta.' });

        const hash = await bcrypt.hash(new_password, 10);
        await pool.query(
            'UPDATE users SET password_hash = ?, password_changed_at = NOW() WHERE id = ?',
            [hash, req.userId]
        );
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao alterar senha.' });
    }
});

// =========================================================
// PROGRESS + RANKING
// =========================================================
app.put('/api/progress', authMiddleware, async (req, res) => {
    const { playtime_seconds, fitas_normais, fitas_douradas, cartas } = req.body;
    if (
        playtime_seconds === undefined &&
        fitas_normais === undefined &&
        fitas_douradas === undefined &&
        cartas === undefined
    ) {
        return res.status(400).json({ error: 'Envie ao menos um campo de progresso.' });
    }
    const novoTempo = playtime_seconds !== undefined ? Math.max(0, Number(playtime_seconds) || 0) : 0;
    const novasFitasNormais = fitas_normais !== undefined ? clamp(fitas_normais, 0, MAX_FITAS_NORMAIS) : 0;
    const novasFitasDouradas = fitas_douradas !== undefined ? clamp(fitas_douradas, 0, MAX_FITAS_DOURADAS) : 0;
    const novasCartas = cartas !== undefined ? clamp(cartas, 0, MAX_CARTAS) : 0;
    try {
        const [check] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check.length && check[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        await pool.query(
            `INSERT INTO game_progress (user_id, playtime_seconds, fitas_normais, fitas_douradas, cartas)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                playtime_seconds = GREATEST(playtime_seconds, VALUES(playtime_seconds)),
                fitas_normais    = GREATEST(fitas_normais, VALUES(fitas_normais)),
                fitas_douradas   = GREATEST(fitas_douradas, VALUES(fitas_douradas)),
                cartas           = GREATEST(cartas, VALUES(cartas))`,
            [req.userId, novoTempo, novasFitasNormais, novasFitasDouradas, novasCartas]
        );
        res.json({ saved: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao salvar progresso.' });
    }
});

// Zera progresso da conta (Novo Jogo no cliente).
// Diferente do PUT /progress, este endpoint NÃO usa GREATEST — força 0.
app.post('/api/progress/reset', authMiddleware, async (req, res) => {
    try {
        const [check] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check.length && check[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        await pool.query(
            `INSERT INTO game_progress (user_id, playtime_seconds, fitas_normais, fitas_douradas, cartas)
             VALUES (?, 0, 0, 0, 0)
             ON DUPLICATE KEY UPDATE
                playtime_seconds = 0,
                fitas_normais = 0,
                fitas_douradas = 0,
                cartas = 0`,
            [req.userId]
        );
        res.json({ reset: true, playtime_seconds: 0, fitas_normais: 0, fitas_douradas: 0, cartas: 0 });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao resetar progresso.' });
    }
});


// Heartbeat: jogo chama a cada ~60s enquanto a sessão estiver ativa
app.post('/api/presence', authMiddleware, async (req, res) => {
    try {
        const [check] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check.length && check[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });
        await pool.query('UPDATE users SET last_seen = NOW() WHERE id = ?', [req.userId]);
        res.json({ ok: true, is_online: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao atualizar presença.' });
    }
});

// =========================================================
// CLOUD SAVES (save completo do jogo por slot)
// =========================================================
app.get('/api/saves', authMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(
            `SELECT slot, updated_at, CHAR_LENGTH(save_json) AS size
             FROM cloud_saves WHERE user_id = ? ORDER BY slot ASC`,
            [req.user.userId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar saves na nuvem.' });
    }
});

app.get('/api/saves/:slot', authMiddleware, async (req, res) => {
    try {
        const slot = parseInt(req.params.slot, 10);
        if (Number.isNaN(slot) || slot < 0 || slot > 20) {
            return res.status(400).json({ error: 'Slot inválido.' });
        }
        const [rows] = await pool.query(
            'SELECT save_json, updated_at FROM cloud_saves WHERE user_id = ? AND slot = ?',
            [req.user.userId, slot]
        );
        if (rows.length === 0) {
            return res.status(404).json({ error: 'Save não encontrado na nuvem.' });
        }
        let data;
        try {
            data = JSON.parse(rows[0].save_json);
        } catch (_) {
            return res.status(500).json({ error: 'Save corrompido na nuvem.' });
        }
        res.json({ slot, updated_at: rows[0].updated_at, data });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao baixar save da nuvem.' });
    }
});

app.put('/api/saves/:slot', authMiddleware, async (req, res) => {
    try {
        const slot = parseInt(req.params.slot, 10);
        if (Number.isNaN(slot) || slot < 0 || slot > 20) {
            return res.status(400).json({ error: 'Slot inválido.' });
        }
        const payload = req.body && req.body.data !== undefined ? req.body.data : req.body;
        if (payload === undefined || payload === null) {
            return res.status(400).json({ error: 'Envie os dados do save.' });
        }
        const saveJson = typeof payload === 'string' ? payload : JSON.stringify(payload);
        if (saveJson.length > 5_000_000) {
            return res.status(413).json({ error: 'Save grande demais.' });
        }
        await pool.query(
            `INSERT INTO cloud_saves (user_id, slot, save_json)
             VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE save_json = VALUES(save_json), updated_at = CURRENT_TIMESTAMP`,
            [req.user.userId, slot, saveJson]
        );
        res.json({ ok: true, slot });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao salvar na nuvem.' });
    }
});

app.delete('/api/saves/:slot', authMiddleware, async (req, res) => {
    try {
        const slot = parseInt(req.params.slot, 10);
        await pool.query('DELETE FROM cloud_saves WHERE user_id = ? AND slot = ?', [req.user.userId, slot]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar save na nuvem.' });
    }
});


app.get('/api/ranking', async (req, res) => {
    try {
        const [rows] = await pool.query(`
            SELECT u.username, u.nickname, u.bio, u.avatar_data, u.role,
                   gp.playtime_seconds,
                   gp.fitas_normais, gp.fitas_douradas, gp.cartas,
                   (gp.fitas_normais + gp.fitas_douradas + gp.cartas) AS total_coletado
            FROM game_progress gp
            JOIN users u ON u.id = gp.user_id
            WHERE u.is_banned = 0
            ORDER BY total_coletado DESC, gp.playtime_seconds ASC
            LIMIT 10
        `);
        res.json(rows);
    } catch (err) {
        // fallback se colunas novas ainda não existirem
        console.error(err);
        try {
            const [rows] = await pool.query(`
                SELECT u.username, u.nickname, gp.playtime_seconds,
                       gp.fitas_normais, gp.fitas_douradas, gp.cartas,
                       (gp.fitas_normais + gp.fitas_douradas + gp.cartas) AS total_coletado
                FROM game_progress gp
                JOIN users u ON u.id = gp.user_id
                ORDER BY total_coletado DESC, gp.playtime_seconds ASC
                LIMIT 10
            `);
            res.json(rows);
        } catch (err2) {
            console.error(err2);
            res.status(500).json({ error: 'Erro ao buscar ranking.' });
        }
    }
});

// =========================================================
// COMMUNITY (simples, só sobre o jogo)
// =========================================================
app.get('/api/community', authMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(`
            SELECT p.id, p.content, p.created_at, u.username, u.nickname, u.avatar_data
            FROM community_posts p
            JOIN users u ON u.id = p.user_id
            WHERE u.is_banned = 0
            ORDER BY p.created_at DESC
            LIMIT 50
        `);
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao carregar a comunidade.' });
    }
});

app.post('/api/community', authMiddleware, async (req, res) => {
    const content = String(req.body.content || '').trim();
    if (!content) return res.status(400).json({ error: 'Escreva uma mensagem.' });
    if (content.length > 500) return res.status(400).json({ error: 'Máximo de 500 caracteres.' });
    try {
        const [check] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check.length && check[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        // limite simples: no máximo 1 post a cada 30s
        const [recent] = await pool.query(
            'SELECT id FROM community_posts WHERE user_id = ? AND created_at > (NOW() - INTERVAL 30 SECOND) LIMIT 1',
            [req.userId]
        );
        if (recent.length) {
            return res.status(429).json({ error: 'Aguarde alguns segundos antes de postar de novo.' });
        }

        const [result] = await pool.query(
            'INSERT INTO community_posts (user_id, content) VALUES (?, ?)',
            [req.userId, content]
        );
        res.status(201).json({ id: result.insertId, ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao publicar.' });
    }
});

app.delete('/api/community/:id', authMiddleware, async (req, res) => {
    const postId = Number(req.params.id);
    if (!postId) return res.status(400).json({ error: 'ID inválido.' });
    try {
        const [rows] = await pool.query(
            'SELECT user_id FROM community_posts WHERE id = ?',
            [postId]
        );
        if (!rows.length) return res.status(404).json({ error: 'Post não encontrado.' });

        const [me] = await pool.query('SELECT role FROM users WHERE id = ?', [req.userId]);
        const isAdmin = me.length && me[0].role === 'admin';
        if (rows[0].user_id !== req.userId && !isAdmin) {
            return res.status(403).json({ error: 'Sem permissão.' });
        }
        await pool.query('DELETE FROM community_posts WHERE id = ?', [postId]);
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar post.' });
    }
});

// =========================================================
// BUG REPORTS
// =========================================================
app.post('/api/bugs', authMiddleware, async (req, res) => {
    const title = String(req.body.title || '').trim();
    const description = String(req.body.description || '').trim();
    if (!title || !description) {
        return res.status(400).json({ error: 'Preencha título e descrição.' });
    }
    if (title.length > 120) return res.status(400).json({ error: 'Título muito longo.' });
    if (description.length > 1000) return res.status(400).json({ error: 'Descrição muito longa.' });
    try {
        const [check] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [req.userId]);
        if (check.length && check[0].is_banned) return res.status(403).json({ error: 'Conta banida.' });

        await pool.query(
            'INSERT INTO bug_reports (user_id, title, description) VALUES (?, ?, ?)',
            [req.userId, title, description]
        );
        res.status(201).json({ ok: true, message: 'Bug reportado. Obrigado!' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao enviar report.' });
    }
});

app.get('/api/bugs/mine', authMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(
            `SELECT id, title, description, status, created_at
             FROM bug_reports WHERE user_id = ?
             ORDER BY created_at DESC LIMIT 20`,
            [req.userId]
        );
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar reports.' });
    }
});

// =========================================================
// ADMIN
// =========================================================
app.get('/api/admin/users', authMiddleware, adminMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(`
            SELECT u.id, u.username, u.email, u.nickname, u.role, u.is_banned, u.ban_reason, u.banned_at, u.created_at,
                   gp.playtime_seconds, gp.fitas_normais, gp.fitas_douradas, gp.cartas
            FROM users u
            LEFT JOIN game_progress gp ON gp.user_id = u.id
            ORDER BY u.created_at DESC
        `);
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar usuários.' });
    }
});

app.post('/api/admin/ban', authMiddleware, adminMiddleware, async (req, res) => {
    const { user_id, reason } = req.body;
    if (!user_id) return res.status(400).json({ error: 'Informe o user_id.' });
    if (Number(user_id) === req.userId) return res.status(400).json({ error: 'Você não pode banir a si mesmo.' });
    try {
        const [rows] = await pool.query('SELECT id, role FROM users WHERE id = ?', [user_id]);
        if (!rows.length) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (rows[0].role === 'admin') return res.status(400).json({ error: 'Não é possível banir outro administrador.' });
        await pool.query(
            'UPDATE users SET is_banned = 1, ban_reason = ?, banned_at = NOW() WHERE id = ?',
            [reason || 'Sem motivo informado.', user_id]
        );
        res.json({ ok: true, message: 'Usuário banido.' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao banir usuário.' });
    }
});

app.post('/api/admin/unban', authMiddleware, adminMiddleware, async (req, res) => {
    const { user_id } = req.body;
    if (!user_id) return res.status(400).json({ error: 'Informe o user_id.' });
    try {
        const [result] = await pool.query(
            'UPDATE users SET is_banned = 0, ban_reason = NULL, banned_at = NULL WHERE id = ?',
            [user_id]
        );
        if (result.affectedRows === 0) return res.status(404).json({ error: 'Usuário não encontrado.' });
        res.json({ ok: true, message: 'Ban removido.' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao remover ban.' });
    }
});

app.delete('/api/admin/users/:id', authMiddleware, adminMiddleware, async (req, res) => {
    const userId = Number(req.params.id);
    if (!userId) return res.status(400).json({ error: 'ID inválido.' });
    if (userId === req.userId) return res.status(400).json({ error: 'Você não pode apagar a si mesmo.' });
    try {
        const [rows] = await pool.query('SELECT id, role FROM users WHERE id = ?', [userId]);
        if (!rows.length) return res.status(404).json({ error: 'Usuário não encontrado.' });
        if (rows[0].role === 'admin') return res.status(400).json({ error: 'Não é possível apagar outro administrador.' });
        await pool.query('DELETE FROM users WHERE id = ?', [userId]);
        res.json({ ok: true, message: 'Conta apagada permanentemente.' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao apagar conta.' });
    }
});

app.get('/api/admin/bugs', authMiddleware, adminMiddleware, async (req, res) => {
    try {
        const [rows] = await pool.query(`
            SELECT b.id, b.title, b.description, b.status, b.created_at,
                   u.username, u.nickname
            FROM bug_reports b
            JOIN users u ON u.id = b.user_id
            ORDER BY FIELD(b.status, 'open', 'reviewing', 'resolved'), b.created_at DESC
            LIMIT 100
        `);
        res.json(rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao listar bugs.' });
    }
});

app.put('/api/admin/bugs/:id', authMiddleware, adminMiddleware, async (req, res) => {
    const id = Number(req.params.id);
    const status = String(req.body.status || '');
    if (!['open', 'reviewing', 'resolved'].includes(status)) {
        return res.status(400).json({ error: 'Status inválido.' });
    }
    try {
        const [result] = await pool.query(
            'UPDATE bug_reports SET status = ? WHERE id = ?',
            [status, id]
        );
        if (result.affectedRows === 0) return res.status(404).json({ error: 'Report não encontrado.' });
        res.json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao atualizar status.' });
    }
});

app.listen(PORT, () => {
    console.log(`Servidor rodando em http://localhost:${PORT}`);
});
