// =========================================================
// Limbo of Memories - Backend (Node.js + Express + MySQL)
// =========================================================
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

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
    const cols = [
        "ALTER TABLE users ADD COLUMN last_seen DATETIME NULL DEFAULT NULL",
        "ALTER TABLE users ADD COLUMN banner_color VARCHAR(7) NULL DEFAULT '#8b5cf6'",
        "ALTER TABLE users ADD COLUMN email_verified TINYINT(1) NOT NULL DEFAULT 0",
        "ALTER TABLE users ADD COLUMN email_verify_token VARCHAR(64) NULL DEFAULT NULL",
        "ALTER TABLE users ADD COLUMN email_verify_expires DATETIME NULL DEFAULT NULL",
    ];
    for (const sql of cols) {
        try { await pool.query(sql); } catch (e) { /* já existe */ }
    }
    // Contas legadas (sem token de verificação) ficam liberadas
    try {
        await pool.query(
            "UPDATE users SET email_verified = 1 WHERE email_verified = 0 AND (email_verify_token IS NULL OR email_verify_token = '')"
        );
    } catch (e) { /* ignore */ }
}
ensureUserColumns().catch(err => console.error('ensureUserColumns', err));

const VERIFY_TOKEN_HOURS = 24;

// -------------------------------------------------------------------
// Envio de e-mail — dois provedores possíveis:
//
// 1) RESEND (recomendado): API por HTTPS, não depende de porta SMTP.
//    Hospedagens como Railway costumam bloquear/travar conexões SMTP
//    (porta 25/465/587), e isso faz o e-mail nunca sair sem nenhum erro
//    visível pro usuário — a conta fica criada mas travada pra sempre
//    esperando uma confirmação que nunca chega. Usando Resend (ou
//    qualquer API HTTP de e-mail) esse problema desaparece porque é só
//    uma requisição HTTPS normal, igual qualquer outra chamada de API.
//    Basta criar uma conta grátis em https://resend.com e definir
//    RESEND_API_KEY nas variáveis de ambiente.
//
// 2) SMTP tradicional (nodemailer) — mantido como alternativa/fallback
//    caso você prefira usar Gmail, Mailgun SMTP, etc. Se RESEND_API_KEY
//    estiver definida, ela tem prioridade; senão cai pro SMTP.
// -------------------------------------------------------------------

function createMailTransporter() {
    const host = process.env.SMTP_HOST;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;
    if (!host || !user || !pass) {
        console.warn('[email] SMTP incompleto. Defina SMTP_HOST, SMTP_USER e SMTP_PASS (ou use RESEND_API_KEY).');
        return null;
    }
    const port = Number(process.env.SMTP_PORT || 587);
    // Bug corrigido: porta 465 SEMPRE exige TLS implícito (secure=true).
    // Antes, se SMTP_SECURE não fosse setada, ficava sempre "false" e a
    // conexão na porta 465 falhava sem explicação. Agora, se SMTP_SECURE
    // não for definida explicitamente, deduzimos pelo valor da porta.
    const secure = process.env.SMTP_SECURE !== undefined
        ? String(process.env.SMTP_SECURE) === 'true'
        : port === 465;
    return nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass }
    });
}

function frontendBaseUrl() {
    return String(process.env.FRONTEND_URL || process.env.SITE_URL || 'https://limboofmemories.netlify.app').replace(/\/$/, '');
}

// Envia via Resend (API HTTPS). Retorna null se RESEND_API_KEY não estiver
// configurada (nesse caso o chamador cai pro SMTP), ou { sent, reason?, error? }.
async function sendViaResend(email, subject, text, html) {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) return null;

    const from = process.env.RESEND_FROM || process.env.SMTP_FROM || 'Limbo of Memories <onboarding@resend.dev>';
    try {
        const resp = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ from, to: email, subject, text, html })
        });
        const data = await resp.json().catch(() => ({}));
        if (!resp.ok) {
            console.error('[email] Resend recusou o envio:', resp.status, data);
            return { sent: false, reason: 'resend_error', error: (data && (data.message || data.name)) || `HTTP ${resp.status}` };
        }
        console.log('[email] enviado via Resend para', email, 'id=', data && data.id);
        return { sent: true };
    } catch (err) {
        console.error('[email] erro de rede ao chamar a API do Resend:', err && err.message ? err.message : err);
        return { sent: false, reason: 'resend_network_error', error: String(err && err.message || err) };
    }
}

async function sendVerificationEmail(email, username, rawToken) {
    const link = `${frontendBaseUrl()}/?verify=${encodeURIComponent(rawToken)}`;
    const subject = 'Confirme seu e-mail — Limbo of Memories';
    const text = [
        `Olá, ${username}!`,
        '',
        'Recebemos um pedido de cadastro no Limbo of Memories.',
        'Para ativar sua conta, abra o link abaixo (válido por 24 horas):',
        '',
        link,
        '',
        'Se você não criou esta conta, ignore este e-mail.'
    ].join('\n');
    const html = `
      <div style="font-family:Segoe UI,Arial,sans-serif;max-width:520px;margin:0 auto;padding:24px;background:#0f0f13;color:#e0e0e0;border-radius:12px;">
        <h2 style="color:#c4b5fd;margin:0 0 12px;">Limbo of Memories</h2>
        <p>Olá, <strong>${username}</strong>!</p>
        <p>Para ativar sua conta, confirme seu e-mail clicando no botão abaixo. O link vale por <strong>24 horas</strong>.</p>
        <p style="margin:28px 0;text-align:center;">
          <a href="${link}" style="display:inline-block;padding:12px 22px;background:linear-gradient(135deg,#8b5cf6,#6d28d9);color:#fff;text-decoration:none;border-radius:10px;font-weight:700;">Confirmar e-mail</a>
        </p>
        <p style="color:#a1a1aa;font-size:13px;">Se o botão não funcionar, copie e cole este link no navegador:<br>${link}</p>
        <p style="color:#a1a1aa;font-size:12px;margin-top:24px;">Se você não criou esta conta, ignore este e-mail.</p>
      </div>`;

    // 1) Resend primeiro, se configurado (mais confiável em hospedagens como Railway)
    const viaResend = await sendViaResend(email, subject, text, html);
    if (viaResend) {
        return { ...viaResend, link };
    }

    // 2) Fallback: SMTP tradicional
    const transporter = createMailTransporter();
    if (!transporter) {
        console.warn('[email] Nenhum provedor de e-mail configurado (RESEND_API_KEY ou SMTP_*). Link de verificação (dev):', link);
        return { sent: false, link, reason: 'no_provider_configured' };
    }
    const from = process.env.SMTP_FROM || process.env.SMTP_USER;
    try {
        const info = await transporter.sendMail({ from, to: email, subject, text, html });
        console.log('[email] enviado via SMTP para', email, 'id=', info && info.messageId);
        return { sent: true, link };
    } catch (err) {
        console.error('[email] falha SMTP:', err && err.message ? err.message : err);
        return { sent: false, link, reason: 'smtp_error', error: String(err && err.message || err) };
    }
}

// Testa a conexão de e-mail assim que o servidor sobe, pra aparecer um aviso
// claro no log ANTES de alguém tentar se cadastrar (em vez de descobrir o
// problema só quando um usuário reclamar que não recebeu nada).
async function checarConfiguracaoDeEmail() {
    if (process.env.RESEND_API_KEY) {
        console.log('[email] Provedor: Resend (API HTTPS). OK, nenhuma verificação de conexão necessária.');
        return;
    }
    const transporter = createMailTransporter();
    if (!transporter) {
        console.warn('[email] ATENÇÃO: nenhum provedor de e-mail configurado. Ninguém vai receber o e-mail de verificação até você definir RESEND_API_KEY ou SMTP_HOST/SMTP_USER/SMTP_PASS.');
        return;
    }
    try {
        await transporter.verify();
        console.log('[email] Provedor: SMTP. Conexão verificada com sucesso.');
    } catch (err) {
        console.error('[email] ATENÇÃO: falha ao conectar no SMTP configurado:', err && err.message ? err.message : err);
        console.error('[email] Causas comuns: host/porta errados, usuário ou senha incorretos (no Gmail é preciso gerar uma "Senha de app", a senha normal da conta NÃO funciona), ou a hospedagem está bloqueando a porta SMTP. Se o problema persistir, defina RESEND_API_KEY para usar envio por HTTPS em vez de SMTP.');
    }
}
checarConfiguracaoDeEmail();

function hashToken(raw) {
    return crypto.createHash('sha256').update(String(raw)).digest('hex');
}

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
    const emailNorm = String(email).trim().toLowerCase();
    const userNorm = String(username).trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNorm)) {
        return res.status(400).json({ error: 'Informe um e-mail válido.' });
    }
    if (!/^[a-zA-Z0-9_]{3,24}$/.test(userNorm)) {
        return res.status(400).json({ error: 'Usuário: 3–24 caracteres (letras, números ou _).' });
    }
    try {
        const [existing] = await pool.query(
            'SELECT id FROM users WHERE username = ? OR email = ?',
            [userNorm, emailNorm]
        );
        if (existing.length > 0) {
            return res.status(409).json({ error: 'Usuário ou e-mail já cadastrado.' });
        }
        const passwordHash = await bcrypt.hash(password, 10);
        const rawToken = crypto.randomBytes(32).toString('hex');
        const tokenHash = hashToken(rawToken);
        const expires = new Date(Date.now() + VERIFY_TOKEN_HOURS * 60 * 60 * 1000);

        const [result] = await pool.query(
            `INSERT INTO users (username, email, password_hash, nickname, email_verified, email_verify_token, email_verify_expires)
             VALUES (?, ?, ?, ?, 0, ?, ?)`,
            [userNorm, emailNorm, passwordHash, userNorm, tokenHash, expires]
        );
        await pool.query('INSERT INTO game_progress (user_id) VALUES (?)', [result.insertId]);

        let mailInfo = { sent: false };
        try {
            mailInfo = await sendVerificationEmail(emailNorm, userNorm, rawToken);
        } catch (mailErr) {
            console.error('[email] falha ao enviar verificação:', mailErr);
        }

        // Não devolve JWT — precisa confirmar o e-mail primeiro
        res.status(201).json({
            ok: true,
            needs_verification: true,
            email: emailNorm,
            username: userNorm,
            message: mailInfo.sent
                ? 'Conta criada! Enviamos um e-mail de confirmação. Abra o link para ativar sua conta.'
                : 'Conta criada! Não foi possível enviar o e-mail agora — use "Reenviar verificação" ou configure o SMTP no servidor.',
            // Em ambiente sem SMTP, o link aparece só no log do servidor (não no JSON público)
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao criar conta.' });
    }
});

app.post('/api/verify-email', async (req, res) => {
    const raw = String((req.body && req.body.token) || req.query.token || '').trim();
    if (!raw) {
        return res.status(400).json({ error: 'Token de verificação ausente.' });
    }
    try {
        const tokenHash = hashToken(raw);
        const [rows] = await pool.query(
            `SELECT id, username, nickname, role, email_verified, email_verify_expires
             FROM users WHERE email_verify_token = ? LIMIT 1`,
            [tokenHash]
        );
        if (!rows.length) {
            return res.status(400).json({ error: 'Link inválido ou já utilizado.' });
        }
        const user = rows[0];
        if (user.email_verified) {
            return res.json({ ok: true, already: true, message: 'E-mail já estava confirmado. Pode entrar.' });
        }
        if (user.email_verify_expires && new Date(user.email_verify_expires).getTime() < Date.now()) {
            return res.status(400).json({ error: 'Link expirado. Peça um novo e-mail de verificação.' });
        }
        await pool.query(
            `UPDATE users SET email_verified = 1, email_verify_token = NULL, email_verify_expires = NULL WHERE id = ?`,
            [user.id]
        );
        const token = jwt.sign(
            { userId: user.id, username: user.username, role: user.role || 'user' },
            JWT_SECRET,
            { expiresIn: '7d' }
        );
        res.json({
            ok: true,
            token,
            username: user.username,
            nickname: user.nickname || user.username,
            role: user.role || 'user',
            message: 'E-mail confirmado! Você já pode usar a conta.'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao verificar e-mail.' });
    }
});

app.post('/api/resend-verification', async (req, res) => {
    const emailNorm = String((req.body && req.body.email) || '').trim().toLowerCase();
    if (!emailNorm) {
        return res.status(400).json({ error: 'Informe o e-mail da conta.' });
    }
    try {
        const [rows] = await pool.query(
            'SELECT id, username, email_verified FROM users WHERE email = ? LIMIT 1',
            [emailNorm]
        );
        // Resposta genérica anti-enumeration
        if (!rows.length) {
            return res.json({ ok: true, message: 'Se o e-mail existir e ainda não estiver verificado, enviaremos um novo link.' });
        }
        const user = rows[0];
        if (user.email_verified) {
            return res.json({ ok: true, message: 'Esta conta já está verificada. Pode entrar normalmente.' });
        }
        const rawToken = crypto.randomBytes(32).toString('hex');
        const tokenHash = hashToken(rawToken);
        const expires = new Date(Date.now() + VERIFY_TOKEN_HOURS * 60 * 60 * 1000);
        await pool.query(
            'UPDATE users SET email_verify_token = ?, email_verify_expires = ? WHERE id = ?',
            [tokenHash, expires, user.id]
        );
        let mailInfo = { sent: false };
        try {
            mailInfo = await sendVerificationEmail(emailNorm, user.username, rawToken);
        } catch (mailErr) {
            console.error('[email] resend falhou:', mailErr);
            return res.status(500).json({
                error: 'Não foi possível enviar o e-mail agora. Confira SMTP_HOST / SMTP_USER / SMTP_PASS no Railway.',
                reason: 'smtp_error'
            });
        }
        if (!mailInfo.sent) {
            return res.status(503).json({
                error: mailInfo.reason === 'smtp_not_configured'
                    ? 'O servidor ainda não está configurado para enviar e-mails (SMTP). Peça ao admin para configurar SMTP_HOST, SMTP_USER e SMTP_PASS.'
                    : ('Falha ao enviar e-mail: ' + (mailInfo.error || 'erro SMTP')),
                reason: mailInfo.reason || 'smtp_error'
            });
        }
        res.json({ ok: true, message: 'Enviamos um novo link de verificação. Confira a caixa de entrada e o spam.' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Erro ao reenviar verificação.' });
    }
});

app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) {
        return res.status(400).json({ error: 'Preencha usuário e senha.' });
    }
    try {
        const [rows] = await pool.query(
            'SELECT id, username, password_hash, nickname, role, is_banned, ban_reason, email_verified, email FROM users WHERE username = ? OR email = ?',
            [username, username]
        );
        if (rows.length === 0) {
            return res.status(401).json({ error: 'Usuário ou senha incorretos.' });
        }
        const user = rows[0];
        const valid = await bcrypt.compare(password, user.password_hash);
        if (!valid) {
            return res.status(401).json({ error: 'Usuário ou senha incorretos.' });
        }
        // Contas novas precisam confirmar e-mail; legadas já vêm com email_verified=1
        if (user.email_verified === 0 || user.email_verified === false) {
            return res.status(403).json({
                error: 'Confirme seu e-mail antes de entrar. Verifique a caixa de entrada (e o spam).',
                needs_verification: true,
                email: user.email || null
            });
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
    // Competição: mais itens coletados vence; empate → menor tempo vence.
    // Quem tem 0 itens (nunca jogou de verdade) fica de fora.
    // playtime 0 com itens é tratado como 1s pra não "roubar" o 1º lugar.
    const sql = `
        SELECT u.username, u.nickname, u.bio, u.avatar_data, u.role,
               gp.playtime_seconds,
               gp.fitas_normais, gp.fitas_douradas, gp.cartas,
               (gp.fitas_normais + gp.fitas_douradas + gp.cartas) AS total_coletado,
               ROUND(
                   (gp.fitas_normais + gp.fitas_douradas + gp.cartas) * 3600
                   / GREATEST(gp.playtime_seconds, 1)
               , 2) AS eficiencia
        FROM game_progress gp
        JOIN users u ON u.id = gp.user_id
        WHERE u.is_banned = 0
          AND (gp.fitas_normais + gp.fitas_douradas + gp.cartas) > 0
        ORDER BY total_coletado DESC,
                 GREATEST(gp.playtime_seconds, 1) ASC
        LIMIT 50
    `;
    try {
        const [rows] = await pool.query(sql);
        res.json(rows);
    } catch (err) {
        console.error(err);
        try {
            const [rows] = await pool.query(`
                SELECT u.username, u.nickname, gp.playtime_seconds,
                       gp.fitas_normais, gp.fitas_douradas, gp.cartas,
                       (gp.fitas_normais + gp.fitas_douradas + gp.cartas) AS total_coletado
                FROM game_progress gp
                JOIN users u ON u.id = gp.user_id
                WHERE (gp.fitas_normais + gp.fitas_douradas + gp.cartas) > 0
                ORDER BY total_coletado DESC, GREATEST(gp.playtime_seconds, 1) ASC
                LIMIT 50
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
