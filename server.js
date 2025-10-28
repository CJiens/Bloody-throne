// ----------------------------
// server.js - MULTIJUGADOR CON COLISIONES MANEJADAS POR CLIENTE
// ----------------------------
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const WebSocket = require('ws');
const http = require('http');
const morgan = require('morgan');

// ----------------------------
// CONFIGURACIÓN BÁSICA
// ----------------------------
const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(morgan('dev'));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://postgres:1234@localhost:5432/mydb',
});

const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret';
const PORT = process.env.PORT || 3001;

// ----------------------------
// SISTEMA DE CLASES
// ----------------------------
class ClassSystem {
  static getClassConfig(classe) {
    const configs = {
      "warrior": {
        "hp": 150,
        "speed": 180,
        "attack_damage": 15,
        "attack_range": 50,
        "is_ranged": false,
        "attack_cooldown": 0.6
      },
      "mage": {
        "hp": 80,
        "speed": 160,
        "attack_damage": 12,
        "attack_range": 300,
        "is_ranged": true,
        "attack_cooldown": 0.8
      },
      "archer": {
        "hp": 100,
        "speed": 200,
        "attack_damage": 10,
        "attack_range": 250,
        "is_ranged": true,
        "attack_cooldown": 0.5
      },
      "rogue": {
        "hp": 90,
        "speed": 220,
        "attack_damage": 12,
        "attack_range": 45,
        "is_ranged": false,
        "attack_cooldown": 0.4
      }
    };

    return configs[classe] || configs["warrior"];
  }
}

// ----------------------------
// SERVIDOR HTTP + WEBSOCKETS
// ----------------------------
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

let clients = new Map();
let players = {};
let enemies = {};
let projectiles = {};
let nextProjectileId = 1;
let gameLoop;

// NUEVO: Para evitar posesiones duplicadas
let possessedObjects = new Set();

// Broadcast helper
function broadcast(data) {
  const msg = JSON.stringify(data);
  for (const ws of wss.clients) {
    if (ws.readyState === WebSocket.OPEN) ws.send(msg);
  }
}

// Broadcast a todos excepto a un cliente específico
function broadcastExcept(exceptWs, data) {
  const msg = JSON.stringify(data);
  for (const ws of wss.clients) {
    if (ws !== exceptWs && ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }
}

// Crear enemigos iniciales
function spawnInitialEnemies() {
  enemies = {};
  const enemyTypes = ['grunt', 'archer', 'mage'];

  for (let i = 1; i <= 8; i++) {
    let x = Math.random() * 800 - 400;
    let y = Math.random() * 600 - 300;

    enemies[i] = {
      id: i,
      x: x,
      y: y,
      hp: 50,
      max_hp: 50,
      type: enemyTypes[Math.floor(Math.random() * enemyTypes.length)],
    };
  }
}

// Respawn enemigos periódicamente
function respawnEnemies() {
  const currentEnemyCount = Object.keys(enemies).length;
  const maxEnemies = 8;

  if (currentEnemyCount < maxEnemies) {
    const enemiesToSpawn = maxEnemies - currentEnemyCount;

    for (let i = 0; i < enemiesToSpawn; i++) {
      const newId = Math.max(...Object.keys(enemies).map(Number), 0) + 1;

      let x = Math.random() * 800 - 400;
      let y = Math.random() * 600 - 300;

      const enemyTypes = ['grunt', 'archer', 'mage'];
      enemies[newId] = {
        id: newId,
        x: x,
        y: y,
        hp: 50,
        max_hp: 50,
        type: enemyTypes[Math.floor(Math.random() * enemyTypes.length)],
      };

      broadcast({ type: 'enemy_spawned', enemy: enemies[newId] });
    }
  }
}

// Game loop para actualizaciones
function startGameLoop() {
  if (gameLoop) clearInterval(gameLoop);

  gameLoop = setInterval(() => {
    // Respawn enemigos cada 10 segundos
    if (Math.random() < 0.01) {
      respawnEnemies();
    }

    // Broadcast estado del juego
    broadcast({
      type: 'state',
      players,
      enemies,
      projectiles,
      timestamp: Date.now()
    });
  }, 50); // 20 FPS para optimizar
}

// Inicializar juego
spawnInitialEnemies();
startGameLoop();

// ----------------------------
// RUTAS HTTP (REST API)
// ----------------------------

app.get('/users', (req, res) => {
  res.send('Hola desde el endpoint /users');
});

// ---------- REGISTRO ----------
app.post('/api/register', async (req, res) => {
  const { username, email, password, classe = 'warrior' } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'username and password required' });

  try {
    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (username, email, password_hash, classe) VALUES ($1, $2, $3, $4) RETURNING id, username, classe',
      [username, email || null, hash, classe]
    );
    const user = result.rows[0];
    return res.json({ ok: true, user });
  } catch (err) {
    console.error('Register error:', err);
    if (err.code === '23505') return res.status(400).json({ error: 'username or email already exists' });
    return res.status(500).json({ error: 'internal' });
  }
});

// ---------- LOGIN ----------
app.post('/api/login', async (req, res) => {
  console.log('🔐 LOGIN ATTEMPT - Body:', req.body);

  const { username, password } = req.body;
  if (!username || !password)
    return res.status(400).json({ error: 'username and password required' });

  try {
    const { rows } = await pool.query(
      'SELECT id, username, password_hash, classe FROM users WHERE username = $1',
      [username]
    );
    if (rows.length === 0)
      return res.status(401).json({ error: 'invalid credentials' });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok)
      return res.status(401).json({ error: 'invalid credentials' });

    const token = jwt.sign(
      { id: user.id, username: user.username, classe: user.classe },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    await pool.query('INSERT INTO sessions (user_id, token) VALUES ($1, $2)', [user.id, token]);

    return res.json({
      ok: true,
      token,
      user: { id: user.id, username: user.username, classe: user.classe },
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: 'internal' });
  }
});

// ----------------------------
// MANEJO DE CONEXIONES WS
// ----------------------------
wss.on('connection', (ws) => {
  console.log("🔗 NUEVA CONEXIÓN WS");
  ws.isAlive = true;
  ws.on('pong', () => (ws.isAlive = true));

  let authed = false;
  let userId = null;
  let playerData = null;

  ws.on('message', async (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (err) {
      console.log("❌ MENSAJE JSON INVALIDO:", raw.toString());
      return;
    }

    console.log("📥 MENSAJE RECIBIDO - Tipo:", msg.type, " De:", userId);

    // AUTENTICACIÓN
    if (!authed) {
      if (msg.type === 'auth' && msg.token) {
        try {
          const payload = jwt.verify(msg.token, JWT_SECRET);
          authed = true;
          userId = payload.id;

          try {
            const userResult = await pool.query(
              'SELECT classe FROM users WHERE id = $1',
              [userId]
            );
            const userClasse = userResult.rows[0]?.classe || 'warrior';

            playerData = {
              id: userId,
              username: payload.username,
              classe: userClasse
            };

            clients.set(ws, playerData);

            // Crear jugador con clase por defecto
            const classConfig = ClassSystem.getClassConfig(userClasse);
            players[userId] = {
              id: userId,
              x: Math.random() * 200 - 100,
              y: Math.random() * 200 - 100,
              hp: classConfig.hp,
              max_hp: classConfig.hp,
              username: payload.username,
              animation_state: "Idle",
              classe: userClasse,
              is_ranged: classConfig.is_ranged,
              attack_damage: classConfig.attack_damage,
              attack_range: classConfig.attack_range
            };

            console.log("✅ AUTENTICACIÓN EXITOSA - User:", payload.username, "ID:", userId, "Clase:", userClasse);

            ws.send(JSON.stringify({
              type: 'auth_ok',
              player: players[userId],
              enemies,
              projectiles
            }));

            broadcastExcept(ws, { type: 'join', player: players[userId] });

          } catch (err) {
            console.error('Error getting user class:', err);
            ws.send(JSON.stringify({ type: 'auth_error', error: 'internal error' }));
            ws.close();
          }
        } catch (err) {
          console.error('Token verification error:', err);
          ws.send(JSON.stringify({ type: 'auth_error', error: 'invalid token' }));
          ws.close();
        }
      } else {
        ws.send(JSON.stringify({ type: 'error', error: 'not authed' }));
        ws.close();
      }
      return;
    }

    // --- MOVIMIENTO ---
    if (msg.type === 'move') {
      if (players[userId]) {
        players[userId].x = msg.x;
        players[userId].y = msg.y;
        broadcast({ type: 'player_moved', player: players[userId] });
      }
    }

    // --- ELECCIÓN DE CLASE ---
    else if (msg.type === 'choose_class') {
      console.log("🎯 ELECCIÓN DE CLASE - User:", userId, " Clase:", msg.classe);

      if (players[userId]) {
        const classConfig = ClassSystem.getClassConfig(msg.classe);
        
        players[userId].classe = msg.classe;
        players[userId].max_hp = classConfig.hp;
        players[userId].hp = classConfig.hp;
        players[userId].is_ranged = classConfig.is_ranged;
        players[userId].attack_damage = classConfig.attack_damage;
        players[userId].attack_range = classConfig.attack_range;

        console.log("✅ CLASE ACTUALIZADA - User:", userId, " Clase:", msg.classe, " HP:", players[userId].hp);

        // Notificar a TODOS los clientes inmediatamente
        broadcast({ 
            type: 'player_update', 
            player: players[userId] 
        });

        // Verificar si todos tienen clase elegida para iniciar juego
        const allPlayersHaveClass = Object.values(players).every(player => 
            player.classe && player.classe !== ""
        );
        
        if (allPlayersHaveClass && Object.keys(players).length >= 4) {
            console.log("🚀 TODOS LOS JUGADORES TIENEN CLASE - Iniciando juego...");
            broadcast({
                type: 'all_players_ready',
                message: 'Todos los jugadores están listos'
            });
        }
      }
    }

    // --- OBTENER ESTADO ---
    else if (msg.type === 'get_player_state') {
      ws.send(JSON.stringify({
        type: 'player_state_response',
        players: players,
        enemies: enemies,
        projectiles: projectiles
      }));
    }

    // --- ATAQUE MELEE ---
    else if (msg.type === 'attack') {
      console.log("💥 ATAQUE MELEE - From:", userId, " Target:", msg.targetType, msg.targetId);

      const target = msg.targetType === 'enemy' ? enemies[msg.targetId] : players[msg.targetId];
      if (!target) {
        console.log("❌ TARGET NO ENCONTRADO");
        return;
      }

      const attacker = players[userId];
      if (!attacker) return;

      // Aplicar daño
      const damage = msg.damage || attacker.attack_damage;
      target.hp -= damage;
      if (target.hp < 0) target.hp = 0;

      console.log(`💥 DAÑO APLICADO - ${damage} a ${msg.targetType} ${msg.targetId}, HP restante: ${target.hp}`);

      if (target.hp <= 0) {
        console.log(`💀 ${msg.targetType.toUpperCase()} MUERTO - ID:`, msg.targetId);
        broadcast({ type: `${msg.targetType}_dead`, id: msg.targetId, by: userId });

        if (msg.targetType === 'enemy') {
          delete enemies[msg.targetId];
        }
      } else {
        broadcast({ type: `${msg.targetType}_hit`, id: msg.targetId, hp: target.hp });
      }
    }

    // --- COLISIÓN PROYECTIL-JUGADOR (REPORTADA POR CLIENTE) ---
    else if (msg.type === 'projectile_hit') {
      console.log("💥 COLISIÓN PROYECTIL-JUGADOR - Proj:", msg.projectile_id, " Player:", msg.player_id);

      const projectile = projectiles[msg.projectile_id];
      const target = players[msg.player_id];

      if (!projectile || !target) {
        console.log("❌ Objetos no encontrados para colisión");
        return;
      }

      // Verificar que el proyectil no sea del mismo jugador
      if (projectile.owner_id === msg.player_id) {
        console.log("🚫 AUTO-DAÑO IGNORADO");
        return;
      }

      // Aplicar daño
      const damage = msg.damage || projectile.damage;
      target.hp -= damage;
      if (target.hp < 0) target.hp = 0;

      broadcast({ type: 'player_hit', id: parseInt(msg.player_id), hp: target.hp });

      if (target.hp <= 0) {
        console.log("💀 JUGADOR MUERTO - ID:", msg.player_id);
        broadcast({ type: 'player_dead', id: parseInt(msg.player_id), by: projectile.owner_id });
      }

      // Remover proyectil
      broadcast({ type: 'projectile_removed', id: msg.projectile_id });
      delete projectiles[msg.projectile_id];
    }

    // --- CHAT ---
    else if (msg.type === 'chat') {
      console.log("💬 CHAT - De:", userId, " Texto:", msg.text);
      broadcast({ type: 'chat', from: userId, fromUsername: players[userId]?.username, text: msg.text });
    }

    // --- ESTADO DE ANIMACIÓN ---
    else if (msg.type === 'player_state') {
      if (players[userId]) {
        players[userId].animation_state = msg.state;
        broadcast({
          type: 'player_state_update',
          id: userId,
          state: msg.state
        });
      }
    }

    // --- CREAR PROYECTIL ---
    else if (msg.type === 'create_projectile') {
      const id = nextProjectileId++;
      projectiles[id] = {
        id: id,
        x: msg.x,
        y: msg.y,
        direction_x: msg.direction_x,
        direction_y: msg.direction_y,
        damage: msg.damage,
        owner_id: msg.owner_id,
        speed: msg.speed || 400.0,
        classe: msg.classe || "warrior"
      };

      console.log("🚀 PROYECTIL CREADO - ID:", id, " Owner:", msg.owner_id, " Clase:", msg.classe);

      broadcast({
        type: 'projectile_created',
        id: id,
        x: msg.x,
        y: msg.y,
        direction_x: msg.direction_x,
        direction_y: msg.direction_y,
        damage: msg.damage,
        owner_id: msg.owner_id,
        speed: msg.speed || 400.0,
        classe: msg.classe || "warrior"
      });
    }

    // --- ACTUALIZAR PROYECTIL (para clientes dueños) ---
    else if (msg.type === 'update_projectile_position') {
      if (projectiles[msg.id] && projectiles[msg.id].owner_id === userId) {
        projectiles[msg.id].x = msg.x;
        projectiles[msg.id].y = msg.y;
      }
    }

    // --- REMOVER PROYECTIL ---
    else if (msg.type === 'remove_projectile') {
      if (projectiles[msg.id]) {
        console.log("🗑️ PROYECTIL REMOVIDO - ID:", msg.id);
        delete projectiles[msg.id];
        broadcast({ type: 'projectile_removed', id: msg.id });
      }
    }

    // --- JUGADOR SE CONVIERTE EN FANTASMA ---
    else if (msg.type === 'player_became_ghost') {
      console.log("👻 JUGADOR SE CONVIERTE EN FANTASMA - Player:", msg.player_id);
      
      // Remover al jugador de la lista de jugadores activos
      if (players[userId]) {
        delete players[userId];
      }
      
      broadcast({
        type: 'player_became_ghost',
        player_id: msg.player_id
      });
    }
    else if (msg.type === 'object_destroyed') {
    console.log("💥 OBJETO DESTRUIDO - Object:", msg.object_id);
    broadcast({
        type: 'object_destroyed',
        object_id: msg.object_id
    });
    }
    // --- FANTASMA POSEYENDO OBJETO ---
    else if (msg.type === 'ghost_possession_started') {
      const objectKey = `${msg.player_id}_${msg.object_id}`;
      
      // Verificar que no esté ya poseído
      if (possessedObjects.has(objectKey)) {
        console.log("❌ POSESIÓN DUPLICADA - Ya poseído:", objectKey);
        return;
      }
      
      console.log("👻 POSESIÓN INICIADA - Ghost:", msg.player_id, " Object:", msg.object_id);
      possessedObjects.add(objectKey);
      
      broadcast({
        type: 'ghost_possession_started',
        player_id: msg.player_id,
        object_id: msg.object_id
      });
    }

    else if (msg.type === 'ghost_possession_ended') {
      const objectKey = `${msg.player_id}_${msg.object_id}`;
      
      console.log("👻 POSESIÓN TERMINADA - Ghost:", msg.player_id, " Object:", msg.object_id);
      possessedObjects.delete(objectKey);
      
      broadcast({
        type: 'ghost_possession_ended',
        player_id: msg.player_id,
        object_id: msg.object_id
      });
    }

    // --- OBJETO LANZADO ---
    else if (msg.type === 'object_thrown') {
      console.log("🚀 OBJETO LANZADO - Object:", msg.object_id, " Direction:", msg.direction_x, msg.direction_y);
      broadcast({
        type: 'object_thrown',
        object_id: msg.object_id,
        direction_x: msg.direction_x,
        direction_y: msg.direction_y
      });
    }

    // --- PING ---
    else if (msg.type === 'ping') {
      ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
    }
  });

  ws.on('close', () => {
    console.log("🔴 CONEXIÓN CERRADA - User:", userId);
    const meta = clients.get(ws);
    if (meta) {
      delete players[meta.id];
      broadcast({ type: 'leave', id: meta.id });
      clients.delete(ws);
      
      // Limpiar posesiones de este jugador
      for (let key of possessedObjects) {
        if (key.startsWith(meta.id + '_')) {
          possessedObjects.delete(key);
        }
      }
    }
  });

  ws.on('error', (err) => {
    console.error("❌ ERROR WS - User:", userId, "Error:", err);
  });
});

// Ping/pong para desconectar inactivos
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      console.log("💀 DESCONECTANDO CLIENTE INACTIVO");
      ws.terminate();
      return;
    }
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);

// ----------------------------
// INICIAR SERVIDOR
// ----------------------------
server.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ HTTP + WS server corriendo en puerto ${PORT}`);
  console.log(`🎮 Sistema de colisiones manejado por cliente`);
  console.log(`👹 Enemigos iniciales: ${Object.keys(enemies).length}`);
  console.log(`👻 Sistema de fantasmas y objetos activado`);
}).on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.log(`❌ Puerto ${PORT} en uso. Intentando con puerto ${Number(PORT) + 1}...`);
    server.listen(Number(PORT) + 1, '0.0.0.0');
  } else {
    console.error('❌ Error del servidor:', err);
  }
});

// Manejo graceful de shutdown
process.on('SIGINT', () => {
  console.log('🛑 Apagando servidor...');
  if (gameLoop) clearInterval(gameLoop);
  wss.close(() => {
    server.close(() => {
      console.log('✅ Servidor apagado correctamente');
      process.exit(0);
    });
  });
});