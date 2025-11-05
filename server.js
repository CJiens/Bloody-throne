// ----------------------------
// server.js - BLOODY-THRONE CON SISTEMA DE EQUIPOS Y VICTORIA - CORREGIDO
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
// SISTEMA DE TARJETAS ALEATORIAS
// ----------------------------
class CardSystem {
  static getRandomCards(count = 3) {
    const allCards = [
      {
        id: "damage_up",
        name: "Aumentar Daño",
        description: "+5 de daño permanente",
        cost: 30,
        type: "damage",
        value: 5
      },
      {
        id: "health_up",
        name: "Aumentar Vida",
        description: "+20 HP máximo permanente",
        cost: 25,
        type: "health",
        value: 20
      },
      {
        id: "gold_bonus",
        name: "Bonus de Oro",
        description: "+10% más oro por kills",
        cost: 35,
        type: "gold_bonus",
        value: 10
      },
      {
        id: "speed_up",
        name: "Aumentar Velocidad",
        description: "+10% de velocidad de movimiento",
        cost: 20,
        type: "speed",
        value: 10
      },
      {
        id: "attack_speed",
        name: "Velocidad de Ataque",
        description: "-15% de cooldown de ataque",
        cost: 40,
        type: "attack_speed",
        value: 15
      },
      {
        id: "critical_chance",
        name: "Golpe Crítico",
        description: "10% de chance de crítico (x2 daño)",
        cost: 45,
        type: "critical",
        value: 10
      }
    ];

    // Mezclar y seleccionar 'count' cartas aleatorias
    const shuffled = [...allCards].sort(() => Math.random() - 0.5);
    const selected = shuffled.slice(0, count);

    console.log("🎯 CARTAS ALEATORIAS GENERADAS (objetos completos):");
    selected.forEach(card => {
      console.log(`  - ${card.name} (ID: ${card.id}, Costo: ${card.cost}, Tipo: ${card.type})`);
    });

    return selected;
  }

  static applyCardEffect(player, card, economySystem) {
    console.log(`🃏 APLICANDO CARTA - Jugador: ${player.id}, Carta: ${card.name}`);

    switch (card.type) {
      case "damage":
        player.attack_damage += card.value;
        console.log(`⚔️ DAÑO AUMENTADO - Jugador ${player.id}: ${player.attack_damage - card.value} -> ${player.attack_damage}`);
        break;

      case "health":
        player.max_hp += card.value;
        player.hp += card.value; // También curar la vida extra
        console.log(`❤️ VIDA AUMENTADA - Jugador ${player.id}: ${player.max_hp - card.value} -> ${player.max_hp}`);
        break;

      case "gold_bonus":
        // Se maneja en el economy system
        if (!player.gold_bonus) player.gold_bonus = 0;
        player.gold_bonus += card.value;
        console.log(`💰 BONUS DE ORO - Jugador ${player.id}: +${player.gold_bonus}% oro`);
        break;

      case "speed":
        if (!player.speed_multiplier) player.speed_multiplier = 1;
        player.speed_multiplier += card.value / 100;
        console.log(`🏃 VELOCIDAD AUMENTADA - Jugador ${player.id}: ${((player.speed_multiplier - card.value / 100) * 100).toFixed(0)}% -> ${(player.speed_multiplier * 100).toFixed(0)}%`);
        break;

      case "attack_speed":
        if (!player.attack_speed_bonus) player.attack_speed_bonus = 0;
        player.attack_speed_bonus += card.value;
        console.log(`⚡ VEL. ATAQUE AUMENTADA - Jugador ${player.id}: +${player.attack_speed_bonus}%`);
        break;

      case "critical":
        if (!player.critical_chance) player.critical_chance = 0;
        player.critical_chance += card.value;
        console.log(`🎯 PROB. CRÍTICO - Jugador ${player.id}: ${player.critical_chance}%`);
        break;
    }

    return player;
  }
}

// ----------------------------
// SISTEMA ECONÓMICO (CORREGIDO)
// ----------------------------
class EconomySystem {
  constructor() {
    this.playerCurrencies = new Map(); // Cambiar a Map para mejor gestión
  }

  addCurrency(playerId, amount, player = null) {
    if (!this.playerCurrencies.has(playerId)) {
      this.playerCurrencies.set(playerId, 0);
    }

    let finalAmount = amount;

    // Aplicar bonus de oro si el jugador tiene
    if (player && player.gold_bonus) {
      const bonus = Math.floor(amount * (player.gold_bonus / 100));
      finalAmount += bonus;
      console.log(`💰 BONUS DE ORO APLICADO - +${bonus} (${player.gold_bonus}%)`);
    }

    const current = this.playerCurrencies.get(playerId);
    this.playerCurrencies.set(playerId, current + finalAmount);
    return this.playerCurrencies.get(playerId);
  }

  canAfford(playerId, cost) {
    return this.playerCurrencies.get(playerId) >= cost;
  }

  spendCurrency(playerId, cost) {
    if (this.canAfford(playerId, cost)) {
      const current = this.playerCurrencies.get(playerId);
      this.playerCurrencies.set(playerId, current - cost);
      return true;
    }
    return false;
  }

  getCurrency(playerId) {
    return this.playerCurrencies.get(playerId) || 0;
  }

  // NUEVO: Reiniciar monedas cuando sea necesario
  resetPlayerCurrency(playerId) {
    this.playerCurrencies.set(playerId, 0);
  }

  // NUEVO: Obtener todas las monedas (para debug)
  getAllCurrencies() {
    const result = {};
    for (const [playerId, amount] of this.playerCurrencies) {
      result[playerId] = amount;
    }
    return result;
  }
}

// ----------------------------
// SISTEMA DE OLEADAS
// ----------------------------
class WaveSystem {
  constructor() {
    this.currentWave = 0;
    this.waveInProgress = false;
    this.enemiesRemaining = 0;
    this.bossWaveInterval = 5; // Cada 5 oleadas aparece un jefe
    this.waveConfigs = {
      1: { enemies: 1, types: ['grunt'], reward: 50 },
      2: { enemies: 12, types: ['grunt', 'archer'], reward: 60 },
      3: { enemies: 15, types: ['grunt', 'archer'], reward: 70 },
      4: { enemies: 18, types: ['grunt', 'archer', 'mage'], reward: 80 },
      5: { enemies: 1, types: ['boss'], reward: 150 }, // Jefe
      6: { enemies: 20, types: ['grunt', 'archer', 'mage'], reward: 90 },
      // Continuar con más oleadas...
    };
  }

  getWaveConfig(waveNumber) {
    // Si es oleada de jefe
    if (waveNumber % this.bossWaveInterval === 0) {
      return {
        enemies: 1,
        types: ['boss'],
        reward: 100 + (waveNumber * 10),
        isBossWave: true
      };
    }

    // Oleadas normales progresivas
    const baseEnemies = 1 + (waveNumber * 2);
    const baseReward = 50 + (waveNumber * 10);

    return {
      enemies: baseEnemies,
      types: ['grunt', 'archer', 'mage'],
      reward: baseReward,
      isBossWave: false
    };
  }

  startNextWave() {
    this.currentWave++;
    const config = this.getWaveConfig(this.currentWave);
    this.waveInProgress = true;
    this.enemiesRemaining = config.enemies;

    console.log(`🌊 OLEADA ${this.currentWave} INICIADA - Enemigos: ${config.enemies}, Recompensa: ${config.reward}`);

    return config;
  }

  enemyDefeated() {
    this.enemiesRemaining--;
    return this.enemiesRemaining <= 0;
  }

  isBossWave() {
    return this.currentWave % this.bossWaveInterval === 0;
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

// Sistemas
const waveSystem = new WaveSystem();
const economySystem = new EconomySystem();

// Bases del juego
let bases = {
  1: {
    hp: 1000,
    maxHp: 1000,
    team: 1,
    x: -500,  // Posición izquierda
    y: 0
  },
  2: {
    hp: 1000,
    maxHp: 1000,
    team: 2,
    x: 500,   // Posición derecha
    y: 0
  }
};

// NUEVAS VARIABLES PARA SISTEMA DE EQUIPOS Y VICTORIA
let gameState = 'waiting'; // waiting, starting, playing, finished
let winningTeam = null;
const MAX_PLAYERS_PER_TEAM = 2;

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

// NUEVAS FUNCIONES PARA SISTEMA DE EQUIPOS
function getTeamCounts() {
  const counts = { 1: 0, 2: 0 };
  for (let playerId in players) {
    if (players[playerId].team > 0) {
      counts[players[playerId].team]++;
    }
  }
  return counts;
}

function broadcastTeamUpdate() {
  const teamCounts = getTeamCounts();
  const playersList = Object.values(players).map(p => ({
    id: p.id,
    username: p.username,
    team: p.team,
    classe: p.classe
  }));

  // Asegurar que las claves sean strings
  const teamCountsWithStrings = {
    "1": teamCounts[1],
    "2": teamCounts[2]
  };

  broadcast({
    type: 'team_update',
    team_counts: teamCountsWithStrings,
    players: playersList
  });
}


function checkGameStartConditions() {
  const teamCounts = getTeamCounts();
  const totalPlayers = Object.keys(players).length;

  // Condiciones para iniciar: al menos 1 jugador en cada equipo y todos tienen equipo
  const hasPlayersInBothTeams = teamCounts[1] > 0 && teamCounts[2] > 0;
  const allPlayersHaveTeams = Object.values(players).every(player => player.team > 0);
  const allPlayersHaveClass = Object.values(players).every(player =>
    player.classe && player.classe !== "" && player.classe !== "warrior"
  );

  if (hasPlayersInBothTeams && allPlayersHaveTeams && allPlayersHaveClass && totalPlayers >= 2) {
    console.log("🚀 CONDICIONES DE INICIO CUMPLIDAS - Iniciando juego en 5 segundos...");
    gameState = 'starting';

    broadcast({
      type: 'game_starting',
      countdown: 5
    });

    // Iniciar countdown
    let countdown = 5;
    const countdownInterval = setInterval(() => {
      countdown--;
      broadcast({
        type: 'game_start_countdown',
        countdown: countdown
      });

      if (countdown <= 0) {
        clearInterval(countdownInterval);
        startGame();
      }
    }, 1000);
  }
}

function startGame() {
  console.log("🎮 INICIANDO JUEGO!");
  gameState = 'playing';
  winningTeam = null; // Asegurar que no hay ganador previo

  // Resetear bases
  bases[1].hp = bases[1].maxHp;
  bases[2].hp = bases[2].maxHp;

  // Asegurar que todos los jugadores estén vivos
  for (let playerId in players) {
    players[playerId].is_alive = true;
    players[playerId].hp = players[playerId].max_hp;
  }

  broadcast({
    type: 'game_started'
  });

  // Iniciar primera oleada después de 3 segundos
  setTimeout(() => {
    startWave();
  }, 3000);
}

// NUEVAS FUNCIONES PARA SISTEMA DE RESPAWN
function startRespawnTimer(playerId) {
  const respawnInterval = setInterval(() => {
    if (players[playerId] && !players[playerId].is_alive) {
      players[playerId].respawn_timer--;

      // Notificar tiempo restante
      broadcast({
        type: 'respawn_countdown',
        player_id: parseInt(playerId),
        time_left: players[playerId].respawn_timer
      });

      if (players[playerId].respawn_timer <= 0) {
        clearInterval(respawnInterval);
        respawnPlayer(playerId);
      }
    } else {
      clearInterval(respawnInterval);
    }
  }, 1000);
}
function respawnPlayer(playerId) {
  if (players[playerId] && players[playerId].team > 0) {
    const team = players[playerId].team;
    const base = bases[team];

    // Solo respawn si la base sigue en pie
    if (base.hp > 0) {
      players[playerId].is_alive = true;
      players[playerId].hp = players[playerId].max_hp;
      players[playerId].x = base.x + (Math.random() * 100 - 50);
      players[playerId].y = base.y + (Math.random() * 100 - 50);

      console.log(`🔁 RESPAWN - Jugador ${playerId} en equipo ${team}`);

      broadcast({
        type: 'player_respawned',
        player: players[playerId]
      });
    } else {
      console.log(`❌ NO RESPAWN - Base del equipo ${team} destruida`);
    }
  }
}

// NUEVAS FUNCIONES PARA SISTEMA DE VICTORIA - CORREGIDAS
function checkBaseDestruction() {
  for (let team in bases) {
    if (bases[team].hp <= 0 && gameState === 'playing') {
      console.log(`💀 BASE DESTRUIDA - Equipo ${team}`);
      gameState = 'finished';
      winningTeam = team === '1' ? 2 : 1; // El equipo contrario gana
      
      console.log(`🎉 EQUIPO GANADOR: ${winningTeam}`);
      
      // Notificar fin del juego
      broadcast({
        type: 'game_over',
        winning_team: parseInt(winningTeam), // Asegurar que sea número
        reason: 'La base enemiga ha sido destruida'
      });
      
      // Reiniciar juego después de 5 segundos (reducido de 10)
      setTimeout(() => {
        resetGame();
      }, 5000);
      
      break;
    }
  }
}

// FUNCIÓN RESETGAME CORREGIDA
function resetGame() {
  console.log("🔄 REINICIANDO JUEGO COMPLETAMENTE");
  
  // Resetear estado del juego
  gameState = 'waiting';
  winningTeam = null;
  
  // Resetear bases
  bases[1].hp = bases[1].maxHp;
  bases[2].hp = bases[2].maxHp;
  
  // Limpiar enemigos y proyectiles
  enemies = {};
  projectiles = {};
  nextProjectileId = 1;
  
  // Resetear sistema de oleadas
  waveSystem.currentWave = 0;
  waveSystem.waveInProgress = false;
  waveSystem.enemiesRemaining = 0;
  
  // Resetear jugadores (mantener equipos pero resetear estado de juego)
  for (let playerId in players) {
    const player = players[playerId];
    
    // Resetear estado de vida y posición
    player.is_alive = true;
    player.hp = player.max_hp;
    player.respawn_timer = 0;
    
    // Posicionar en sus bases según equipo
    if (player.team > 0) {
      const base = bases[player.team];
      player.x = base.x + (Math.random() * 100 - 50);
      player.y = base.y + (Math.random() * 100 - 50);
    }
    
    // Resetear economía del jugador
    economySystem.resetPlayerCurrency(playerId);
  }
  
  console.log("✅ JUEGO REINICIADO - Todos los jugadores en estado inicial");
  
  // Broadcast del reset a todos los clientes
  broadcast({
    type: 'game_reset',
    players: players,
    bases: bases,
    game_state: gameState
  });
  
  // Enviar actualización de equipos
  broadcastTeamUpdate();
}

// Spawn de enemigos para oleada
function spawnWaveEnemies(waveConfig) {
  enemies = {}; // Limpiar enemigos anteriores

  if (waveConfig.isBossWave) {
    // Spawn del jefe
    spawnBoss();
  } else {
    // Spawn de enemigos normales
    for (let i = 1; i <= waveConfig.enemies; i++) {
      spawnEnemy(i, waveConfig.types);
    }
  }
}

function spawnEnemy(id, availableTypes) {
  const enemyType = availableTypes[Math.floor(Math.random() * availableTypes.length)];
  let x, y;

  // Spawn en áreas específicas según el equipo (simulando bases opuestas)
  const spawnArea = Math.random() > 0.5 ? 1 : 2;
  if (spawnArea === 1) {
    x = Math.random() * 400 - 600; // Lado izquierdo
    y = Math.random() * 400 - 200;
  } else {
    x = Math.random() * 400 + 200; // Lado derecho
    y = Math.random() * 400 - 200;
  }

  const baseHp = enemyType === 'grunt' ? 50 : enemyType === 'archer' ? 40 : enemyType === 'mage' ? 30 : 100;

  enemies[id] = {
    id: id,
    x: x,
    y: y,
    hp: baseHp,
    max_hp: baseHp,
    type: enemyType,
    team: spawnArea,
    attack_damage: enemyType === 'grunt' ? 10 : enemyType === 'archer' ? 8 : enemyType === 'mage' ? 12 : 15,
    move_speed: enemyType === 'grunt' ? 80 : enemyType === 'archer' ? 100 : enemyType === 'mage' ? 70 : 60
  };

  console.log(`👹 ENEMIGO SPAWNEADO - ID: ${id}, Tipo: ${enemyType}, Equipo: ${spawnArea}`);
}

function spawnBoss() {
  const bossId = 1;
  enemies[bossId] = {
    id: bossId,
    x: 0,
    y: 0,
    hp: 500,
    max_hp: 500,
    type: 'boss',
    team: 0, // Jefe neutral
    attack_damage: 25,
    move_speed: 50,
    phases: 2,
    current_phase: 1
  };

  console.log(`👹 JEFE INTERMEDIO SPAWNEADO - HP: 500, Daño: 25`);

  broadcast({
    type: 'boss_spawned',
    boss_data: enemies[bossId]
  });
}

// Game loop para actualizaciones
function startGameLoop() {
  if (gameLoop) clearInterval(gameLoop);

  gameLoop = setInterval(() => {
    // Solo actualizar si el juego está en progreso
    if (gameState === 'playing') {
      // Movimiento de enemigos (IA simple hacia bases)
      for (let enemyId in enemies) {
        const enemy = enemies[enemyId];
        if (enemy.type === 'boss') continue; // Jefe tiene comportamiento especial

        // Movimiento hacia la base enemiga
        const targetBase = enemy.team === 1 ? bases[2] : bases[1];
        const dx = targetBase.x - enemy.x;
        const dy = targetBase.y - enemy.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance > 50) { // Si no está muy cerca de la base
          enemy.x += (dx / distance) * enemy.move_speed * 0.016; // 60 FPS
          enemy.y += (dy / distance) * enemy.move_speed * 0.016;
        } else {
          // Atacar la base
          targetBase.hp -= enemy.attack_damage * 0.016;
          console.log(`💥 BASE ${targetBase.team} ATACADA - HP: ${Math.round(targetBase.hp)}`);

          if (targetBase.hp <= 0) {
            console.log(`💀 BASE ${targetBase.team} DESTRUIDA!`);
            targetBase.hp = 0;
            // La verificación de victoria se hace en checkBaseDestruction()
          }
        }
      }

      // Verificar fin de oleada
      if (waveSystem.waveInProgress && Object.keys(enemies).length === 0) {
        endCurrentWave();
      }

      // Verificar destrucción de bases
      checkBaseDestruction();
    }

    // Broadcast estado del juego (siempre, para mantener sincronización)
    broadcast({
      type: 'state',
      players,
      enemies,
      projectiles,
      bases,
      game_state: gameState, // Incluir estado del juego
      timestamp: Date.now()
    });
  }, 50); // 20 FPS para optimizar
}

function startWave() {
  const waveConfig = waveSystem.startNextWave();
  spawnWaveEnemies(waveConfig);

  broadcast({
    type: 'wave_started',
    wave_number: waveSystem.currentWave,
    enemy_count: waveConfig.enemies,
    is_boss_wave: waveConfig.isBossWave
  });

  console.log(`🌊 OLEADA ${waveSystem.currentWave} INICIADA`);
}

function endCurrentWave() {
  console.log(`🔚 TERMINANDO OLEADA ${waveSystem.currentWave}`);
  waveSystem.waveInProgress = false;
  const waveConfig = waveSystem.getWaveConfig(waveSystem.currentWave);

  // Recompensa de oleada para todos
  const reward = waveConfig.reward;
  console.log(`💰 RECOMPENSA DE OLEADA: ${reward} monedas para todos los jugadores`);

  for (let playerId in players) {
    const player = players[playerId];
    const newAmount = economySystem.addCurrency(playerId, reward, player);
    console.log(`💰 JUGADOR ${playerId} RECIBE +${reward} MONEDAS - Total: ${newAmount}`);

    broadcast({
      type: 'currency_updated',
      player_id: parseInt(playerId),
      amount: newAmount
    });
  }

  broadcast({ type: 'wave_ended' });
  console.log(`📨 SEÑAL wave_ended ENVIADA`);

  // Período de decisiones CON TARJETAS - CORREGIDO
  setTimeout(() => {
    console.log(`⏰ INICIANDO PERIODO DE DECISIONES para oleada ${waveSystem.currentWave + 1}`);

    // Generar y enviar tarjetas aleatorias a CADA jugador
    for (let playerId in players) {
      const player = players[playerId];
      const playerCurrency = economySystem.getCurrency(playerId);
      const randomCards = CardSystem.getRandomCards(3);

      // ✅ CORREGIDO: Guardar las cartas en el jugador ANTES de enviar
      player.current_cards = randomCards;

      // ✅ DEBUG: Verificar que las cartas se generaron correctamente
      console.log(`🃏 CARTAS GENERADAS PARA JUGADOR ${playerId}:`, randomCards.map(c => `${c.name} (${c.id})`));

      const ws = Array.from(clients.keys()).find(clientWs => {
        const clientData = clients.get(clientWs);
        return clientData && clientData.id == playerId;
      });

      if (ws && ws.readyState === WebSocket.OPEN) {
        // ✅ CORREGIDO: Asegurar que se envíen los objetos completos con estructura correcta
        const decisionMessage = {
          type: 'decision_period_started',
          duration: 30.0,
          currency: playerCurrency,
          cards: randomCards // ✅ Array de objetos completos
        };

        console.log(`✅ ENVIANDO CARTAS A JUGADOR ${playerId} -`, {
          cartas: randomCards.length,
          monedas: playerCurrency,
          estructura: decisionMessage.cards // Verificar estructura
        });

        ws.send(JSON.stringify(decisionMessage));

        // ✅ DEBUG adicional
        console.log(`📋 ESTRUCTURA DE DATOS ENVIADA - Cartas:`, JSON.stringify(randomCards, null, 2));
      } else {
        console.log(`❌ NO SE PUDO ENCONTRAR WS PARA JUGADOR ${playerId}`);
      }
    }

    console.log(`🎯 PERIODO DE DECISIONES INICIADO PARA ${Object.keys(players).length} JUGADORES`);

    // Iniciar siguiente oleada después del período
    setTimeout(() => {
      console.log(`🌊 INICIANDO OLEADA ${waveSystem.currentWave + 1} automáticamente`);
      startWave();
    }, 30000);

  }, 3000);
}

// Inicializar juego
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

            // CREAR JUGADOR SIN EQUIPO INICIAL
            const classConfig = ClassSystem.getClassConfig(userClasse);
            players[userId] = {
              id: userId,
              x: 0,
              y: 0,
              hp: classConfig.hp,
              max_hp: classConfig.hp,
              username: payload.username,
              animation_state: "Idle",
              classe: userClasse,
              is_ranged: classConfig.is_ranged,
              attack_damage: classConfig.attack_damage,
              attack_range: classConfig.attack_range,
              team: 0, // 0 = sin equipo, 1 = equipo azul, 2 = equipo rojo
              is_alive: true,
              respawn_timer: 0
            };

            // Inicializar monedas del jugador
            economySystem.addCurrency(userId, 0);

            console.log("✅ AUTENTICACIÓN EXITOSA - User:", payload.username, "ID:", userId, "Clase:", userClasse, "Equipo: Pendiente");

            // Enviar información de equipos al cliente
            const teamCounts = getTeamCounts();

            ws.send(JSON.stringify({
              type: 'auth_ok',
              player: players[userId],
              enemies,
              projectiles,
              bases,
              team_counts: teamCounts,
              game_state: gameState
            }));

            // Enviar a todos los clientes la actualización de equipos
            broadcastTeamUpdate();

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

    // --- SELECCIÓN DE EQUIPO ---
    else if (msg.type === 'select_team') {
      console.log("🎯 SELECCIÓN DE EQUIPO - User:", userId, " Equipo:", msg.team);

      if (players[userId]) {
        const requestedTeam = msg.team;
        const teamCounts = getTeamCounts();

        // Verificar si el equipo está lleno
        if (teamCounts[requestedTeam] >= MAX_PLAYERS_PER_TEAM) {
          ws.send(JSON.stringify({
            type: 'team_selection_failed',
            reason: 'team_full',
            team_counts: teamCounts
          }));
          return;
        }

        // Asignar equipo al jugador
        players[userId].team = requestedTeam;

        // Posicionar jugador en su base
        const base = bases[requestedTeam];
        players[userId].x = base.x + (Math.random() * 100 - 50);
        players[userId].y = base.y + (Math.random() * 100 - 50);
        players[userId].is_alive = true;

        console.log(`✅ EQUIPO ASIGNADO - User: ${userId}, Equipo: ${requestedTeam}, Pos: (${players[userId].x}, ${players[userId].y})`);

        // Notificar al jugador
        ws.send(JSON.stringify({
          type: 'team_selected',
          team: requestedTeam,
          position: { x: players[userId].x, y: players[userId].y }
        }));

        // Broadcast actualización de equipos a todos
        broadcastTeamUpdate();

        // Verificar si se pueden iniciar el juego
        checkGameStartConditions();
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
        checkGameStartConditions();
      }
    }

    // --- INICIAR SESIÓN DE JUEGO ---
    else if (msg.type === 'start_game_session') {
      console.log("🎮 INICIANDO SESIÓN DE JUEGO");
      broadcast({ type: 'game_session_started' });

      // Iniciar primera oleada después de 3 segundos
      setTimeout(() => {
        startWave();
      }, 3000);
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
      console.log("💥 ATAQUE RECIBIDO - From:", userId, " Target:", msg.targetType, msg.targetId, " Damage:", msg.damage);

      const target = msg.targetType === 'enemy' ? enemies[msg.targetId] : players[msg.targetId];
      if (!target) {
        console.log("❌ TARGET NO ENCONTRADO - Tipo:", msg.targetType, "ID:", msg.targetId);
        return;
      }

      const attacker = players[userId];
      if (!attacker) {
        console.log("❌ ATACANTE NO ENCONTRADO - UserID:", userId);
        return;
      }

      // Aplicar daño
      const damage = msg.damage || attacker.attack_damage;
      console.log(`🎯 APLICANDO DAÑO - ${damage} a ${msg.targetType} ${msg.targetId}, HP antes: ${target.hp}`);

      target.hp -= damage;
      if (target.hp < 0) target.hp = 0;

      console.log(`💥 DAÑO APLICADO - ${damage} a ${msg.targetType} ${msg.targetId}, HP restante: ${target.hp}`);

      if (target.hp <= 0) {
        console.log(`💀 ${msg.targetType.toUpperCase()} MUERTO - ID:`, msg.targetId, " Por:", userId);

        // ✅ CORREGIDO: Dar recompensa SOLO al jugador que mató
        if (msg.targetType === 'enemy') {
          const enemyType = target.type;
          let killReward = 0;

          // Determinar recompensa por tipo de enemigo
          switch (enemyType) {
            case 'grunt': killReward = 5; break;
            case 'archer': killReward = 8; break;
            case 'mage': killReward = 10; break;
            case 'boss': killReward = 50; break;
            default: killReward = 5;
          }

          // ✅ Dar recompensa SOLO al asesino
          const newAmount = economySystem.addCurrency(userId, killReward, players[userId]);
          console.log(`💰 RECOMPENSA POR KILL - Jugador ${userId} recibe +${killReward} por matar ${enemyType} - Total: ${newAmount}`);

          // Notificar SOLO al asesino de su nueva cantidad
          const killerWs = Array.from(clients.keys()).find(ws => {
            const clientData = clients.get(ws);
            return clientData && clientData.id == userId;
          });

          if (killerWs && killerWs.readyState === WebSocket.OPEN) {
            killerWs.send(JSON.stringify({
              type: 'currency_updated',
              player_id: parseInt(userId),
              amount: newAmount
            }));
          }

          delete enemies[msg.targetId];

          // Verificar si era el último enemigo
          if (Object.keys(enemies).length === 0 && waveSystem.waveInProgress) {
            endCurrentWave();
          }
        } else if (msg.targetType === 'player') {
          // Marcar jugador como muerto
          players[msg.targetId].is_alive = false;
          players[msg.targetId].respawn_timer = 5; // 5 segundos para respawn

          broadcast({
            type: 'player_dead',
            id: parseInt(msg.targetId),
            by: userId,
            respawn_time: 5
          });

          // Iniciar timer de respawn
          startRespawnTimer(msg.targetId);
        }

        broadcast({
          type: `${msg.targetType}_dead`,
          id: msg.targetId,
          by: userId,
          killer_id: userId,
          enemy_type: target.type
        });
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

        // Marcar jugador como muerto
        players[msg.player_id].is_alive = false;
        players[msg.player_id].respawn_timer = 5;

        broadcast({
          type: 'player_dead',
          id: parseInt(msg.player_id),
          by: projectile.owner_id,
          respawn_time: 5
        });

        // Iniciar timer de respawn
        startRespawnTimer(msg.player_id);
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

    // --- COMPRA DE CARTAS ---
    else if (msg.type === 'purchase_card') {
      console.log("🃏 COMPRA DE CARTA - User:", userId, " Carta:", msg.card_id);

      const player = players[userId];
      if (!player) {
        console.log("❌ JUGADOR NO ENCONTRADO");
        ws.send(JSON.stringify({
          type: 'card_purchase_failed',
          reason: 'player_not_found'
        }));
        return;
      }

      // ✅ CORREGIDO: Usar las cartas guardadas en el jugador
      const availableCards = player.current_cards || [];
      const card = availableCards.find(c => c.id === msg.card_id);

      if (!card) {
        console.log("❌ CARTA NO DISPONIBLE - ID:", msg.card_id, "Cartas disponibles:", availableCards.map(c => c.id));
        ws.send(JSON.stringify({
          type: 'card_purchase_failed',
          reason: 'card_not_available'
        }));
        return;
      }

      // Verificar si tiene suficiente dinero
      if (!economySystem.canAfford(userId, card.cost)) {
        console.log("❌ FONDOS INSUFICIENTES para carta - Necesita:", card.cost, "Tiene:", economySystem.getCurrency(userId));
        ws.send(JSON.stringify({
          type: 'card_purchase_failed',
          reason: 'insufficient_funds'
        }));
        return;
      }

      // Aplicar efecto de la carta
      CardSystem.applyCardEffect(player, card, economySystem);

      // Gastar el dinero
      economySystem.spendCurrency(userId, card.cost);
      const newBalance = economySystem.getCurrency(userId);

      console.log(`✅ CARTA COMPRADA - ${card.name} por ${card.cost} monedas. Balance restante: ${newBalance}`);

      // ✅ CORREGIDO: Remover la carta comprada de las disponibles
      player.current_cards = player.current_cards.filter(c => c.id !== msg.card_id);

      // Notificar al jugador
      ws.send(JSON.stringify({
        type: 'card_purchased',
        card: card,
        new_balance: newBalance
      }));

      // Actualizar monedas en todos los clientes
      broadcast({
        type: 'currency_updated',
        player_id: parseInt(userId),
        amount: newBalance
      });

      // Notificar a otros jugadores sobre la mejora (opcional)
      broadcastExcept(ws, {
        type: 'player_upgraded',
        player_id: parseInt(userId),
        upgrade_type: card.type,
        card_name: card.name
      });
    }

    // --- SISTEMA DE DECISIONES ECONÓMICAS ---
    else if (msg.type === 'player_decision') {
      console.log("🎯 DECISIÓN DEL JUGADOR - User:", userId, " Decisión:", msg.decision_type, " Objetivo:", msg.target, " Costo:", msg.cost);

      if (economySystem.canAfford(userId, msg.cost)) {
        economySystem.spendCurrency(userId, msg.cost);

        // Aplicar efecto según la decisión
        if (msg.decision_type === 'upgrade' && msg.target === 'self') {
          // Mejora al jugador mismo
          if (players[userId]) {
            players[userId].max_hp += 20;
            players[userId].hp = players[userId].max_hp;
            players[userId].attack_damage += 5;
            console.log(`✅ JUGADOR MEJORADO - User: ${userId}, HP: ${players[userId].max_hp}, Daño: ${players[userId].attack_damage}`);
          }
        } else if (msg.decision_type === 'curse' && msg.target === 'enemy') {
          // Mejorar enemigos del equipo rival
          const playerTeam = players[userId].team;
          const enemyTeam = playerTeam === 1 ? 2 : 1;

          for (let enemyId in enemies) {
            if (enemies[enemyId].team === enemyTeam) {
              enemies[enemyId].max_hp += 15;
              enemies[enemyId].hp = enemies[enemyId].max_hp;
              enemies[enemyId].attack_damage += 3;
            }
          }
          console.log(`☠️ ENEMIGOS DEL EQUIPO ${enemyTeam} MEJORADOS`);
        }

        // Actualizar monedas del jugador
        broadcast({
          type: 'currency_updated',
          player_id: parseInt(userId),
          amount: economySystem.getCurrency(userId)
        });

        broadcast({
          type: 'decision_applied',
          player_id: userId,
          decision_type: msg.decision_type,
          target: msg.target
        });

      } else {
        console.log("❌ FONDOS INSUFICIENTES - User:", userId);
        ws.send(JSON.stringify({
          type: 'decision_failed',
          reason: 'insufficient_funds'
        }));
      }
    }

    // --- SOLICITUD DE MONEDAS ---
    else if (msg.type === 'request_currency_update') {
      const newAmount = economySystem.addCurrency(userId, msg.amount, players[userId]);
      broadcast({
        type: 'currency_updated',
        player_id: parseInt(userId), // Asegurar que sea número
        amount: newAmount
      });

      // ✅ CORREGIDO: Obtener teamCounts actualizados
      const currentTeamCounts = getTeamCounts();
      
      ws.send(JSON.stringify({
        type: 'auth_ok',
        player: players[userId],
        enemies,
        projectiles,
        bases,
        team_counts: {
          "1": currentTeamCounts[1],
          "2": currentTeamCounts[2]
        },
        game_state: gameState
      }));
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

      // Actualizar equipos después de que un jugador se va
      broadcastTeamUpdate();
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
  console.log(`🎮 BLOODY-THRONE - Sistema de equipos y victoria activo`);
  console.log(`👥 Máximo ${MAX_PLAYERS_PER_TEAM} jugadores por equipo`);
  console.log(`💰 Sistema económico implementado`);
  console.log(`🃏 Sistema de cartas implementado`);
  console.log(`🔁 Sistema de respawn activo (5 segundos)`);
  console.log(`👹 Enemigos por oleada: progresivo`);
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