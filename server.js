// ----------------------------
// server.js - BLOODY-THRONE CON JEFE PERMANENTE Y ATAQUES DE ÁREA
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
		this.minEnemies = 4;  // Mínimo de enemigos (par)
		this.maxEnemies = 12; // Máximo de enemigos (par)
	}

	getWaveConfig(waveNumber) {
	let numEnemies = this.minEnemies + Math.floor(Math.random() * ((this.maxEnemies - this.minEnemies) / 2 + 1)) * 2;
		
		const baseReward = 50 + (waveNumber * 10);

		return {
			enemies: numEnemies,
			types: ['grunt', 'archer', 'mage'],
			reward: baseReward,
			isBossWave: false
		};
	}

	startNextWave() {
		this.currentWave++;
		const config = this.getWaveConfig(this.currentWave);
		this.waveInProgress = true;
		this.enemiesRemaining = 6;

		console.log(`🌊 OLEADA ${this.currentWave} INICIADA - Enemigos: ${config.enemies}, Recompensa: ${config.reward}`)

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
// Busca esta sección y actualiza las coordenadas:
let bases = {
	1: {
		hp: 200,
		maxHp: 1000,
		team: 1,
		x: -1600,  // ← ACTUALIZAR a -1600
		y: -800    // ← ACTUALIZAR a -800
	},
	2: {
		hp: 200,
		maxHp: 1000,
		team: 2,
		x: 1400,   // ← ACTUALIZAR a 1400
		y: 400     // ← ACTUALIZAR a 400
	}
};

// Variables de estado del juego
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

// Enviar a un jugador específico
function sendToPlayer(playerId, data) {
	const playerWs = Array.from(clients.keys()).find(ws => {
		const clientData = clients.get(ws);
		return clientData && clientData.id == playerId;
	});

	if (playerWs && playerWs.readyState === WebSocket.OPEN) {
		playerWs.send(JSON.stringify(data));
		return true;
	}
	return false;
}

// ----------------------------
// SISTEMA DE EQUIPOS
// ----------------------------
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
	console.log("🎮 INICIANDO JUEGO CON JEFE PERMANENTE!");
	gameState = 'playing';

	// Resetear bases
	bases[1].hp = bases[1].maxHp;
	bases[2].hp = bases[2].maxHp;

	// Asegurar que todos los jugadores estén vivos
	for (let playerId in players) {
		players[playerId].is_alive = true;
		players[playerId].hp = players[playerId].max_hp;
	}

	// SPAWNEAR JEFE PERMANENTE
	//spawnPermanentBoss();

	broadcast({
		type: 'game_started'
	});

	console.log("✅ JUEGO INICIADO CON JEFE PERMANENTE");
}

// ----------------------------
// SISTEMA DE RESPAWN
// ----------------------------
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

			// 🎯 RESPAWN MÁS LEJOS DE LA BASE
			const respawnRange = 600;  // ← AUMENTADO el rango de respawn

			players[playerId].x = base.x + (Math.random() * respawnRange - respawnRange / 2);
			players[playerId].y = base.y + (Math.random() * respawnRange - respawnRange / 2);

			console.log(`🔁 RESPAWN - Jugador ${playerId} en equipo ${team}, Pos: (${players[playerId].x}, ${players[playerId].y})`);

			broadcast({
				type: 'player_respawned',
				player: players[playerId]
			});
		} else {
			console.log(`❌ NO RESPAWN - Base del equipo ${team} destruida`);
		}
	}
}

// ----------------------------
// SISTEMA DE VICTORIA
// ----------------------------
function checkBaseDestruction() {
	for (let team in bases) {
		if (bases[team].hp <= 0 && gameState === 'playing') {
			console.log(`💀 BASE DESTRUIDA - Equipo ${team}`);
			gameState = 'finished';
			winningTeam = team === '1' ? 2 : 1; // El equipo contrario gana

			broadcast({
				type: 'game_over',
				winning_team: winningTeam,
				reason: 'base_destroyed'
			});

			// Reiniciar juego después de 10 segundos
			setTimeout(() => {
				resetGame();
			}, 10000);

			break;
		}
	}
}

function resetGame() {
	console.log("🔄 REINICIANDO JUEGO");
	gameState = 'waiting';
	winningTeam = null;

	// Resetear jugadores (mantener equipos pero resetear estado)
	for (let playerId in players) {
		players[playerId].is_alive = true;
		players[playerId].hp = players[playerId].max_hp;
		players[playerId].respawn_timer = 0;

		// Posicionar en sus bases
		if (players[playerId].team > 0) {
			const base = bases[players[playerId].team];
			players[playerId].x = base.x + (Math.random() * 100 - 50);
			players[playerId].y = base.y + (Math.random() * 100 - 50);
		}
	}

	// Limpiar enemigos y proyectiles
	enemies = {};
	projectiles = {};

	// Resetear oleadas
	waveSystem.currentWave = 0;
	waveSystem.waveInProgress = false;

	// Resetear economía
	for (let playerId in players) {
		economySystem.resetPlayerCurrency(playerId);
	}

	/*// Limpiar jefe permanente
	if (permanentBoss) {
		delete enemies[permanentBoss.id];
		permanentBoss = null;
	}

	// Limpiar timer de respawn del jefe
	if (bossRespawnTimer) {
		clearTimeout(bossRespawnTimer);
		bossRespawnTimer = null;
	}*/

	console.log("✅ JUEGO REINICIADO - Todos los sistemas reseteados");
}

// ----------------------------
// SISTEMA DE OLEADAS
// ----------------------------
function spawnWaveEnemies(waveConfig) {
	enemies = {}; // Limpiar enemigos anteriores
// ✅ SISTEMA MEZCLADO: Algunos enemigos por equipo, algunos neutrales
	const totalEnemies = waveConfig.enemies;
	
	// Calcular distribución:
	// - 60% enemigos por equipo (30% cada equipo)
	// - 40% enemigos neutrales
	const teamEnemies = Math.floor(totalEnemies * 0.6);
	const neutralEnemies = totalEnemies - teamEnemies;
	
	// Asegurar que teamEnemies sea par para dividir entre equipos
	const enemiesPerTeam = Math.floor(teamEnemies / 2);
	
	console.log(`🎯 SPAWN MEZCLADO - Total: ${totalEnemies}, Equipo 1: ${enemiesPerTeam}, Equipo 2: ${enemiesPerTeam}, Neutrales: ${neutralEnemies}`);
	
	let nextId = 1;

	// Spawn enemigos equipo 1 (azul)
	for (let i = 0; i < enemiesPerTeam; i++) {
		spawnEnemy(nextId, waveConfig.types, 1);
		nextId++;
	}
	
	// Spawn enemigos equipo 2 (rojo)  
	for (let i = 0; i < enemiesPerTeam; i++) {
		spawnEnemy(nextId, waveConfig.types, 2);
		nextId++;
	}
	
	// Spawn enemigos neutrales (equipo 0 - blancos)
	for (let i = 0; i < neutralEnemies; i++) {
		spawnEnemy(nextId, waveConfig.types, 0);
		nextId++;
	}
	
	console.log(`✅ SPAWN COMPLETADO - Equipo 1: ${enemiesPerTeam}, Equipo 2: ${enemiesPerTeam}, Neutrales: ${neutralEnemies}`);
	//}
}


function spawnEnemy(id, availableTypes, forceTeam = null) {
    const enemyType = availableTypes[Math.floor(Math.random() * availableTypes.length)];
    let fixedTeam = forceTeam;
    
    let spawnPos;
    if (fixedTeam === 1) {
        // EQUIPO AZUL - Spawn EXCLUSIVAMENTE AL FRENTE de la base
        const basePos = bases[1];
        spawnPos = {
            x: basePos.x + 400 + (Math.random() * 400),  // Entre 400-800 unidades AL FRENTE (derecha)
            y: basePos.y + (Math.random() * 400 - 200)   // Entre -200 y +200 en Y (arriba/abajo del centro)
        };
        console.log(`👹 ENEMIGO AZUL SPAWNEADO AL FRENTE - Pos: (${spawnPos.x}, ${spawnPos.y})`);
    } else if (fixedTeam === 2) {
        // EQUIPO ROJO - Spawn EXCLUSIVAMENTE AL FRENTE de la base  
        const basePos = bases[2];
        spawnPos = {
            x: basePos.x - 400 - (Math.random() * 400),  // Entre 400-800 unidades AL FRENTE (izquierda)
            y: basePos.y + (Math.random() * 400 - 200)   // Entre -200 y +200 en Y (arriba/abajo del centro)
        };
        console.log(`👹 ENEMIGO ROJO SPAWNEADO AL FRENTE - Pos: (${spawnPos.x}, ${spawnPos.y})`);
    } else {
        // ENEMIGOS NEUTRALES - spawn en el centro del mapa
        spawnPos = {
            x: -400 + (Math.random() * 800),
            y: -400 + (Math.random() * 800)
        };
    }

    const baseHp = enemyType === 'grunt' ? 50 : enemyType === 'archer' ? 40 : enemyType === 'mage' ? 30 : 100;

    enemies[id] = {
        id: id,
        x: spawnPos.x,
        y: spawnPos.y,
        hp: baseHp,
        max_hp: baseHp,
        type: enemyType,
        team: fixedTeam,
        attack_damage: enemyType === 'grunt' ? 10 : enemyType === 'archer' ? 8 : enemyType === 'mage' ? 12 : 15,
        move_speed: enemyType === 'grunt' ? 80 : enemyType === 'archer' ? 100 : enemyType === 'mage' ? 70 : 60,
        spawn_area: fixedTeam,
        is_neutral: fixedTeam === 0,
        last_attack_time: 0,
        attack_cooldown: 1000
    };

    /*broadcast({
        type: 'enemy_spawned',
        enemy: enemies[id]
    });*/
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

    // Recompensa fija por oleada completada
    const reward = waveConfig.reward;
    console.log(`💰 RECOMPENSA DE OLEADA: ${reward} monedas para todos los jugadores`);

    for (let playerId in players) {
        const player = players[playerId];
        const newAmount = economySystem.addCurrency(playerId, reward, player);
        console.log(`💰 JUGADOR ${playerId} RECIBE +${reward} MONEDAS - Total: ${newAmount}`);

        sendToPlayer(playerId, {
            type: 'currency_updated',
            player_id: parseInt(playerId),
            amount: newAmount
        });
    }

    broadcast({ type: 'wave_ended' });
    console.log(`📨 SEÑAL wave_ended ENVIADA`);

    // Período de decisiones
    setTimeout(() => {
        console.log(`⏰ INICIANDO PERIODO DE DECISIONES para oleada ${waveSystem.currentWave + 1}`);

        for (let playerId in players) {
            const player = players[playerId];
            const playerCurrency = economySystem.getCurrency(playerId);
            const randomCards = CardSystem.getRandomCards(3);

            player.current_cards = randomCards;

            sendToPlayer(playerId, {
                type: 'decision_period_started',
                duration: 30.0,
                currency: playerCurrency,
                cards: randomCards
            });
        }

        console.log(`🎯 PERIODO DE DECISIONES INICIADO PARA ${Object.keys(players).length} JUGADORES`);

        // Iniciar siguiente oleada después del período
        setTimeout(() => {
            console.log(`🌊 INICIANDO OLEADA ${waveSystem.currentWave + 1} automáticamente`);
            startWave();
        }, 30000);

    }, 3000);
}
// ✅ FUNCIÓN MEJORADA PARA MOVIMIENTO DE ENEMIGOS NEUTRALES
function _moveNeutralEnemy(enemy) {
	// Buscar jugador más cercano
	let closestPlayer = null;
	let minDistance = Infinity;
	
	for (let playerId in players) {
		const player = players[playerId];
		if (player.is_alive) {
			const distance = Math.sqrt(
				Math.pow(player.x - enemy.x, 2) + Math.pow(player.y - enemy.y, 2)
			);
			
			if (distance < minDistance && distance < 800) { // Radio de detección aumentado a 800
				minDistance = distance;
				closestPlayer = player;
			}
		}
	}
	
	// Si encontramos un jugador, movernos DIRECTAMENTE hacia él
	if (closestPlayer) {
		const dx = closestPlayer.x - enemy.x;
		const dy = closestPlayer.y - enemy.y;
		const distance = Math.sqrt(dx * dx + dy * dy);
		
		if (distance > 0) {
			// ✅ MOVIMIENTO MÁS DECIDIDO - Sin cambios de dirección aleatorios
			const moveX = (dx / distance) * enemy.move_speed * 0.025; // Aumentada la velocidad
			const moveY = (dy / distance) * enemy.move_speed * 0.025;
			
			enemy.x += moveX;
			enemy.y += moveY;
			
			// ✅ VERIFICAR SI ESTÁ EN RANGO PARA ATACAR (distancia < 60)
			if (distance <= 60) {
				_attackPlayerWithNeutral(enemy, closestPlayer);
			}
		}
	} else {
		// Si no hay jugadores, movimiento aleatorio MÍNIMO
		if (Math.random() < 0.02) { // Solo 2% de probabilidad de moverse aleatoriamente
			const angle = Math.random() * Math.PI * 2;
			const distance = enemy.move_speed * 0.016;
			
			enemy.x += Math.cos(angle) * distance;
			enemy.y += Math.sin(angle) * distance;
		}
	}
	
	// Limitar el movimiento al área central del mapa
	enemy.x = Math.max(-1200, Math.min(1200, enemy.x));
	enemy.y = Math.max(-1000, Math.min(1000, enemy.y));
}

// ✅ FUNCIÓN MEJORADA CON COOLDOWN
function _attackPlayerWithNeutral(enemy, player) {
	const now = Date.now();
	
	// ✅ VERIFICAR COOLDOWN
	if (now - enemy.last_attack_time < enemy.attack_cooldown) {
		return; // Todavía en cooldown
	}
	
	// ✅ DAÑO DEL 5% DE LA VIDA MÁXIMA DEL PLAYER
	const damage = Math.floor(player.max_hp * 0.05);
	
	console.log(`💥 ENEMIGO NEUTRAL ${enemy.id} ATACA JUGADOR ${player.id} - Daño: ${damage} (5% de ${player.max_hp})`);
	
	// Aplicar daño al jugador
	player.hp -= damage;
	if (player.hp < 0) player.hp = 0;
	
	// Notificar a todos los clientes
	broadcast({
		type: 'player_hit',
		id: parseInt(player.id),
		hp: player.hp,
		damage: damage,
		attacker_id: enemy.id,
		attacker_type: 'neutral_enemy'
	});
	
	// Verificar si el jugador murió
	if (player.hp <= 0) {
		console.log(`💀 JUGADOR ${player.id} MUERTO POR ENEMIGO NEUTRAL ${enemy.id}`);
		player.is_alive = false;
		player.respawn_timer = 10;
		
		broadcast({
			type: 'player_dead',
			id: parseInt(player.id),
			by: enemy.id,
			respawn_time: 10,
			killer_type: 'neutral_enemy'
		});
		
		startRespawnTimer(player.id);
	}
	
	// ✅ ACTUALIZAR COOLDOWN
	enemy.last_attack_time = now;
}
// ----------------------------
// GAME LOOP PRINCIPAL
// ----------------------------
function startGameLoop() {
	if (gameLoop) clearInterval(gameLoop);

	gameLoop = setInterval(() => {
		// Movimiento de enemigos (IA mejorada hacia bases)
		for (let enemyId in enemies) {
			const enemy = enemies[enemyId];

			// Saltar el jefe permanente (ya tiene su propia IA)
			if (enemy.is_permanent) continue;
			
			if (enemy.type === 'boss_wave') continue; // Jefe de oleada tiene comportamiento especial
			if (enemy.team === 0) {
				// Enemigos neutrales: movimiento aleatorio o buscar jugadores
				_moveNeutralEnemy(enemy);
				continue;
			}
			// 🎯 MOVIMIENTO MEJORADO HACIA LA BASE ENEMIGA
			const targetBase = enemy.team === 1 ? bases[2] : bases[1];
			const dx = targetBase.x - enemy.x;
			const dy = targetBase.y - enemy.y;
			const distance = Math.sqrt(dx * dx + dy * dy);

			// ✅ NUEVO: Verificar que el enemigo no esté cerca de su base aliada
			const allyBase = bases[enemy.team];
			if (!allyBase) {
				console.log(`❌ BASE ALIADA NO ENCONTRADA para equipo ${enemy.team}`);
				continue;
			}
			const distanceToAllyBase = Math.sqrt(
				Math.pow(allyBase.x - enemy.x, 2) + Math.pow(allyBase.y - enemy.y, 2)
			);

			// Si el enemigo está muy cerca de su base aliada, moverse lejos de ella
			if (distanceToAllyBase < 300) {
				const awayFromAllyBaseX = (enemy.x - allyBase.x) / distanceToAllyBase;
				const awayFromAllyBaseY = (enemy.y - allyBase.y) / distanceToAllyBase;
				
				enemy.x += awayFromAllyBaseX * enemy.move_speed * 0.016;
				enemy.y += awayFromAllyBaseY * enemy.move_speed * 0.016;
				
				console.log(`🚫 ENEMIGO ${enemyId} ALEJÁNDOSE DE BASE ALIADA - Equipo: ${enemy.team}`);
			}
			// Si el enemigo está muy lejos de la base enemiga, moverse hacia ella
			else if (distance > 200) {
				// Movimiento suave hacia el objetivo
				const moveX = (dx / distance) * enemy.move_speed * 0.016;
				const moveY = (dy / distance) * enemy.move_speed * 0.016;
				
				enemy.x += moveX;
				enemy.y += moveY;
			} else {
				// Si está en rango de ataque, ATACAR PERO NO ACERCARSE MÁS
				targetBase.hp -= enemy.attack_damage * 0.016;
				
				// Debug del ataque ocasionalmente
				if (Math.random() < 0.02) { // 2% de chance cada frame
					console.log(`💥 ENEMIGO ${enemyId} ATACANDO BASE ENEMIGA ${targetBase.team} - HP restante: ${Math.round(targetBase.hp)}`);
				}

				if (targetBase.hp <= 0) {
					console.log(`💀 BASE ENEMIGA ${targetBase.team} DESTRUIDA POR ENEMIGOS!`);
					targetBase.hp = 0;
					checkBaseDestruction();
				}
			}
		}
		// Verificar fin de oleada
		if (waveSystem.waveInProgress && Object.keys(enemies).length === 0) {
			endCurrentWave();
		}

		// Verificar destrucción de bases
		checkBaseDestruction();

		// Broadcast estado del juego
		broadcast({
			type: 'state',
			players,
			enemies,
			projectiles,
			bases,
			timestamp: Date.now()
		});
	}, 20); // 20 FPS para optimizar
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

		else if (msg.type === 'select_team') {
			console.log("🎯 SELECCIÓN DE EQUIPO - User:", userId, " Equipo:", msg.team);

			if (players[userId]) {
				const requestedTeam = msg.team;
				const teamCounts = getTeamCounts();

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

				// 🎯 POSICIONAR JUGADOR MÁS LEJOS DE SU BASE
				const base = bases[requestedTeam];

				// Aumentar el rango de spawn de 200 a 600 unidades
				const spawnRangeX = 600;  // ← AUMENTADO de 200 a 600
				const spawnRangeY = 600;  // ← AUMENTADO de 200 a 600

				players[userId].x = base.x + (Math.random() * spawnRangeX - spawnRangeX / 2);
				players[userId].y = base.y + (Math.random() * spawnRangeY - spawnRangeY / 2);
				players[userId].is_alive = true;

				console.log(`✅ EQUIPO ASIGNADO - User: ${userId}, Equipo: ${requestedTeam}, Base: (${base.x}, ${base.y}), Pos: (${players[userId].x}, ${players[userId].y})`);

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

			// ✅ NUEVO: VERIFICAR QUE NO SE ATAQUE ENEMIGOS ALIADOS
			if (msg.targetType === 'enemy' && target.team === attacker.team) {
				console.log("🚫 ATAQUE BLOQUEADO - Jugador", userId, "no puede atacar a un enemigo aliado del equipo", attacker.team);
				// Opcional: Enviar mensaje de error al jugador
				ws.send(JSON.stringify({
					type: 'attack_blocked',
					reason: 'cannot_attack_ally_enemy'
				}));
				return;
			}

			// ✅ NUEVO: VERIFICAR QUE NO SE ATAQUE JUGADORES ALIADOS
			if (msg.targetType === 'player' && target.team === attacker.team) {
				console.log("🚫 ATAQUE BLOQUEADO - Jugador", userId, "no puede atacar a un jugador aliado del equipo", attacker.team);
				// Opcional: Enviar mensaje de error al jugador
				ws.send(JSON.stringify({
					type: 'attack_blocked',
					reason: 'cannot_attack_ally_player'
				}));
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
						case 'boss_wave': killReward = 30; break;
						case 'final_boss': killReward = 50; break; // Jefe permanente
						default: killReward = 5;
					}

					// ✅ Dar recompensa SOLO al asesino
					const newAmount = economySystem.addCurrency(userId, killReward, players[userId]);
					console.log(`💰 RECOMPENSA POR KILL - Jugador ${userId} recibe +${killReward} por matar ${enemyType} - Total: ${newAmount}`);

					// ✅ CORREGIDO: Notificar SOLO al asesino de su nueva cantidad
					sendToPlayer(userId, {
						type: 'currency_updated',
						player_id: parseInt(userId),
						amount: newAmount
					});

					// Manejar muerte del jefe permanente
					if (enemyType === 'final_boss') {
						handleBossDeath(msg.targetId);
					} else {
						delete enemies[msg.targetId];
					}

					// Verificar si era el último enemigo
					if (Object.keys(enemies).length === 0 && waveSystem.waveInProgress) {
						endCurrentWave();
					}
				} else if (msg.targetType === 'player') {
					// Marcar jugador como muerto
					players[msg.targetId].is_alive = false;
					players[msg.targetId].respawn_timer = 10; // 5 segundos para respawn

					broadcast({
						type: 'player_dead',
						id: parseInt(msg.targetId),
						by: userId,
						respawn_time: 10
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

		// --- ATAQUE DE ÁREA PARA ARQUERA ---
		else if (msg.type === 'area_attack') {
			console.log("🎯 ATAQUE DE ÁREA - From:", userId, " Position:", msg.x, msg.y, " Damage:", msg.damage);

			const attacker = players[userId];
			if (!attacker || attacker.classe !== 'archer') {
				console.log("❌ ATAQUE DE ÁREA NO AUTORIZADO - No es arquera o jugador no existe");
				return;
			}

			const areaRange = 154; // Radio del área de efecto (actualizado a 154px)
			const areaDamage = msg.damage || attacker.attack_damage;
			let hits = 0;

			console.log(`💥 BUSCANDO OBJETIVOS EN ÁREA - Centro: (${msg.x}, ${msg.y}), Radio: ${areaRange}`);

			// ✅ CORREGIDO: Aplicar daño a TODOS los tipos de objetivos

			// 1. ENEMIGOS NORMALES Y BOSSES
			let enemiesToRemove = [];
			for (let enemyId in enemies) {
				const enemy = enemies[enemyId];

				// ✅ NUEVO: SALTAR ENEMIGOS ALIADOS
				if (enemy.team === attacker.team) {
					console.log(`🤝 ENEMIGO ALIADO IGNORADO - ID: ${enemyId}, Equipo: ${enemy.team}`);
					continue;
				}

				const distance = Math.sqrt(
					Math.pow(enemy.x - msg.x, 2) + Math.pow(enemy.y - msg.y, 2)
				);

				if (distance <= areaRange) {
					console.log(`🎯 ${enemy.is_permanent ? 'JEFE' : 'ENEMIGO'} ${enemyId} EN ÁREA - Distancia: ${distance}, Aplicando daño: ${areaDamage}`);
					
					enemy.hp -= areaDamage;
					if (enemy.hp < 0) enemy.hp = 0;

					// Notificar que el enemigo fue golpeado
					broadcast({ 
						type: 'enemy_hit', 
						id: enemyId, 
						hp: enemy.hp 
					});

					hits++;

					// Manejar muerte del enemigo
					if (enemy.hp <= 0) {
						console.log(`💀 ${enemy.is_permanent ? 'JEFE' : 'ENEMIGO'} ${enemyId} MUERTO POR ATAQUE DE ÁREA`);
						
						// Dar recompensa al atacante
						const enemyType = enemy.type;
						let killReward = 0;
						
						// ✅ CORREGIDO: Incluir recompensa para el jefe permanente
						switch (enemyType) {
							case 'grunt': killReward = 5; break;
							case 'archer': killReward = 8; break;
							case 'mage': killReward = 10; break;
							case 'boss_wave': killReward = 30; break;
							case 'final_boss': killReward = 50; break;
							default: killReward = 5;
						}

						// ✅ CORREGIDO: Dar recompensa por jefe permanente también
						if (enemy.is_permanent) {
							killReward = 50; // Recompensa fija para jefe permanente
							console.log(`💰 RECOMPENSA POR JEFE PERMANENTE - +${killReward} monedas`);
						}

						const newAmount = economySystem.addCurrency(userId, killReward, attacker);
						console.log(`💰 RECOMPENSA POR KILL DE ÁREA - +${killReward} monedas`);

						sendToPlayer(userId, {
							type: 'currency_updated',
							player_id: parseInt(userId),
							amount: newAmount
						});

						// ✅ CORREGIDO: Manejar muertes después del bucle para evitar problemas de modificación durante iteración
						if (enemy.is_permanent) {
							handleBossDeath(enemyId);
						} else {
							enemiesToRemove.push(enemyId);
						}

						broadcast({
							type: 'enemy_dead',
							id: parseInt(enemyId), // ✅ CORREGIDO: Convertir a int para evitar el error
							by: userId,
							killer_id: userId,
							enemy_type: enemyType
						});
					}
				}
			}

			// ✅ CORREGIDO: Eliminar enemigos después del bucle para evitar problemas de modificación
			for (let enemyId of enemiesToRemove) {
				delete enemies[enemyId];
			}

			// 2. ✅ NUEVO: APLICAR DAÑO A BASES
			for (let team in bases) {
				const base = bases[team];
				const distance = Math.sqrt(
					Math.pow(base.x - msg.x, 2) + Math.pow(base.y - msg.y, 2)
				);

				if (distance <= areaRange) {
					console.log(`🏰 BASE ${team} EN ÁREA - Distancia: ${distance}, Aplicando daño: ${areaDamage}`);
					
					// ✅ CORREGIDO: Verificar correctamente el equipo del atacante
					const attackerTeam = attacker.team || 0;
					const baseTeam = parseInt(team);
					
					if (baseTeam !== attackerTeam) {
						base.hp -= areaDamage;
						if (base.hp < 0) base.hp = 0;

						console.log(`💥 BASE ${team} GOLPEADA - HP restante: ${base.hp}`);

						hits++;

						// Verificar si la base fue destruida
						if (base.hp <= 0) {
							console.log(`💀 BASE ${team} DESTRUIDA POR ATAQUE DE ÁREA!`);
							checkBaseDestruction();
						}

						// Notificar actualización de base
						broadcast({
							type: 'base_hit',
							team: baseTeam,
							hp: base.hp,
							max_hp: base.maxHp
						});
					}
				}
			}

			// 3. ✅ NUEVO: APLICAR DAÑO A JUGADORES RIVALES
			for (let playerId in players) {
				const player = players[playerId];
				
				// ✅ CORREGIDO: Verificar correctamente el equipo
				const playerTeam = player.team || 0;
				const attackerTeam = attacker.team || 0;
				
				// Solo jugadores vivos del equipo contrario
				if (player.is_alive && playerTeam !== attackerTeam) {
					const distance = Math.sqrt(
						Math.pow(player.x - msg.x, 2) + Math.pow(player.y - msg.y, 2)
					);

					if (distance <= areaRange) {
						console.log(`🎯 JUGADOR RIVAL ${playerId} EN ÁREA - Distancia: ${distance}, Aplicando daño: ${areaDamage}`);
						
						player.hp -= areaDamage;
						if (player.hp < 0) player.hp = 0;

						broadcast({ 
							type: 'player_hit', 
							id: parseInt(playerId), 
							hp: player.hp 
						});

						hits++;

						// Manejar muerte del jugador
						if (player.hp <= 0) {
							console.log(`💀 JUGADOR RIVAL ${playerId} MUERTO POR ATAQUE DE ÁREA`);
							
							player.is_alive = false;
							player.respawn_timer = 10;

							broadcast({
								type: 'player_dead',
								id: parseInt(playerId),
								by: userId,
								respawn_time: 10
							});

							startRespawnTimer(playerId);
						}
					}
				}
			}

			console.log(`✅ ATAQUE DE ÁREA COMPLETADO - ${hits} objetivos golpeados`);

			// Notificar a todos los clientes sobre el ataque de área
			broadcast({
				type: 'area_attack_effect',
				x: msg.x,
				y: msg.y,
				player_id: userId
			});
		}

		// --- ATAQUE DE ÁREA ROGUE ---
		else if (msg.type === 'rogue_area_attack') {
			console.log("🎯 ATAQUE DE ÁREA ROGUE - From:", userId, " Position:", msg.x, msg.y, " Damage:", msg.damage);

			const attacker = players[userId];
			if (!attacker || attacker.classe !== 'rogue') {
				console.log("❌ ATAQUE DE ÁREA ROGUE NO AUTORIZADO - No es rogue o jugador no existe");
				return;
			}

			const areaRange = 150;
			const areaDamage = msg.damage || attacker.attack_damage;
			let hits = 0;

			console.log(`💥 BUSCANDO OBJETIVOS EN ÁREA ROGUE - Centro: (${msg.x}, ${msg.y}), Radio: ${areaRange}`);

			let enemiesToRemove = [];
			for (let enemyId in enemies) {
				const enemy = enemies[enemyId];
				if (enemy.team === attacker.team) {
					continue;
				}
				const distance = Math.sqrt(
					Math.pow(enemy.x - msg.x, 2) + Math.pow(enemy.y - msg.y, 2)
				);

				if (distance <= areaRange) {
					console.log(`🎯 ENEMIGO ${enemyId} EN ÁREA ROGUE - Distancia: ${distance}, Aplicando daño: ${areaDamage}`);
					enemy.hp -= areaDamage;
					if (enemy.hp < 0) enemy.hp = 0;

					broadcast({
						type: 'enemy_hit',
						id: enemyId,
						hp: enemy.hp
					});

					hits++;

					if (enemy.hp <= 0) {
						console.log(`💀 ENEMIGO ${enemyId} MUERTO POR ATAQUE DE ÁREA ROGUE`);

						const enemyType = enemy.type;
						let killReward = 0;

						switch (enemyType) {
							case 'grunt': killReward = 5; break;
							case 'archer': killReward = 8; break;
							case 'mage': killReward = 10; break;
							case 'boss_wave': killReward = 30; break;
							case 'final_boss': killReward = 50; break;
							default: killReward = 5;
						}

						if (enemy.is_permanent) {
							killReward = 50;
							console.log(`💰 RECOMPENSA POR JEFE PERMANENTE - +${killReward} monedas`);
						}

						const newAmount = economySystem.addCurrency(userId, killReward, attacker);
						console.log(`💰 RECOMPENSA POR KILL DE ÁREA ROGUE - +${killReward} monedas`);

						sendToPlayer(userId, {
							type: 'currency_updated',
							player_id: parseInt(userId),
							amount: newAmount
						});

						if (enemy.is_permanent) {
							handleBossDeath(enemyId);
						} else {
							enemiesToRemove.push(enemyId);
						}

						broadcast({
							type: 'enemy_dead',
							id: parseInt(enemyId),
							by: userId,
							killer_id: userId,
							enemy_type: enemyType
						});
					}
				}
			}

			for (let enemyId of enemiesToRemove) {
				delete enemies[enemyId];
			}

			for (let team in bases) {
				const base = bases[team];
				const distance = Math.sqrt(
					Math.pow(base.x - msg.x, 2) + Math.pow(base.y - msg.y, 2)
				);

				if (distance <= areaRange) {
					console.log(`🏰 BASE ${team} EN ÁREA ROGUE - Distancia: ${distance}, Aplicando daño: ${areaDamage}`);

					const attackerTeam = attacker.team || 0;
					const baseTeam = parseInt(team);

					if (baseTeam !== attackerTeam) {
						base.hp -= areaDamage;
						if (base.hp < 0) base.hp = 0;

						console.log(`💥 BASE ${team} GOLPEADA - HP restante: ${base.hp}`);

						hits++;

						if (base.hp <= 0) {
							console.log(`💀 BASE ${team} DESTRUIDA POR ATAQUE DE ÁREA ROGUE!`);
							checkBaseDestruction();
						}

						broadcast({
							type: 'base_hit',
							team: baseTeam,
							hp: base.hp,
							max_hp: base.maxHp
						});
					}
				}
			}

			for (let playerId in players) {
				const player = players[playerId];

				const playerTeam = player.team || 0;
				const attackerTeam = attacker.team || 0;

				if (player.is_alive && playerTeam !== attackerTeam) {
					const distance = Math.sqrt(
						Math.pow(player.x - msg.x, 2) + Math.pow(player.y - msg.y, 2)
					);

					if (distance <= areaRange) {
						console.log(`🎯 JUGADOR RIVAL ${playerId} EN ÁREA ROGUE - Distancia: ${distance}, Aplicando daño: ${areaDamage}`);

						player.hp -= areaDamage;
						if (player.hp < 0) player.hp = 0;

						broadcast({
							type: 'player_hit',
							id: parseInt(playerId),
							hp: player.hp
						});

						hits++;

						if (player.hp <= 0) {
							console.log(`💀 JUGADOR RIVAL ${playerId} MUERTO POR ATAQUE DE ÁREA ROGUE`);

							player.is_alive = false;
							 player.respawn_timer= 10;

							broadcast({
								type: 'player_dead',
								id: parseInt(playerId),
								by: userId,
								respawn_time: 10
							});

							startRespawnTimer(playerId);
						}
					}
				}
			}

			console.log(`✅ ATAQUE DE ÁREA ROGUE COMPLETADO - ${hits} objetivos golpeados`);

			broadcast({
				type: 'rogue_area_attack_effect',
				x: msg.x,
				y: msg.y,
				player_id: userId
			});
		}

		// --- ATAQUE DE ÁREA MAGA (SOLO EFECTO VISUAL) ---
		else if (msg.type === 'mage_area_attack') {
			console.log("🎯 ATAQUE DE ÁREA MAGA - From:", userId, " Position:", msg.x, msg.y, " Damage:", msg.damage, " Team:", msg.team);

			const attacker = players[userId];
			if (!attacker || attacker.classe !== 'mage') {
				console.log("❌ ATAQUE DE ÁREA MAGA NO AUTORIZADO - No es maga o jugador no existe");
				return;
			}

			// SOLO crear efecto visual - el daño lo manejan los ticks
			console.log(`🔥 CREANDO ZONA DE DAÑO MAGA - Centro: (${msg.x}, ${msg.y}), Radio: 150px`);

			broadcast({
				type: 'mage_area_attack_effect',
				x: msg.x,
				y: msg.y,
				player_id: userId
			});
		}

		// --- DAÑO POR TICKS DEL ATAQUE DE ÁREA MAGA ---
		else if (msg.type === 'mage_area_damage_tick') {
			console.log("🔥 DAÑO POR TICK MAGA - Target:", msg.target_type, msg.target_id, " Damage:", msg.damage, " Owner:", msg.owner_id);

			const attacker = players[msg.owner_id];
			if (!attacker) {
				console.log("❌ ATACANTE NO ENCONTRADO");
				return;
			}

			// Aplicar daño según el tipo de objetivo
			switch (msg.target_type) {
				case 'player':
					_applyMageDamageToPlayer(msg.target_id, msg.damage, msg.owner_id, msg.owner_team);
					break;
				case 'enemy':
					_applyMageDamageToEnemy(msg.target_id, msg.damage, msg.owner_id, msg.owner_team);
					break;
				case 'base':
            _applyMageDamageToBase(msg.target_id, msg.damage, msg.owner_id);
            break;
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
				players[msg.player_id].respawn_timer = 10;

				broadcast({
					type: 'player_dead',
					id: parseInt(msg.player_id),
					by: projectile.owner_id,
					respawn_time: 10
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

			// ✅ CORREGIDO: Actualizar monedas SOLO al jugador específico
			sendToPlayer(userId, {
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

				// ✅ CORREGIDO: Actualizar monedas SOLO al jugador específico
				sendToPlayer(userId, {
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

			// ✅ CORREGIDO: Enviar solo al jugador específico
			sendToPlayer(userId, {
				type: 'currency_updated',
				player_id: parseInt(userId),
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

		// --- SOLICITUD DE RESPawN DEL JEFE ---
		else if (msg.type === 'request_boss_respawn') {
			handleBossRespawn();
		}

		// --- SOLICITUD DE SPAWN DEL JEFE ---
		else if (msg.type === 'request_boss_spawn') {
			// Spawnear jefe inmediatamente (para testing)
			spawnPermanentBoss();
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
// FUNCIONES AUXILIARES PARA EL DAÑO DE MAGA
// ----------------------------

// Función para aplicar daño de maga a jugador (SIMPLIFICADA)
function _applyMageDamageToPlayer(playerId, damage, ownerId) {
	console.log("🔥 _applyMageDamageToPlayer - playerId:", playerId, "ownerId:", ownerId);
	
	const target = players[playerId];
	if (!target) {
		console.log("❌ JUGADOR OBJETIVO NO ENCONTRADO - ID:", playerId);
		return;
	}

	// ✅ SOLO VERIFICAR: No dañar al propio jugador
	if (parseInt(playerId) === parseInt(ownerId)) {
		console.log("🚫 AUTO-DAÑO BLOQUEADO");
		return;
	}

	console.log("✅ DAÑO PERMITIDO - Aplicando daño a jugador:", playerId);

	const reducedDamage = 1;
	target.hp -= reducedDamage;
	if (target.hp < 0) target.hp = 0;

	console.log(`💥 MAGA DAÑA JUGADOR - ${reducedDamage} a ${playerId}, HP restante: ${target.hp}`);

	broadcast({ 
		type: 'player_hit', 
		id: parseInt(playerId), 
		hp: target.hp 
	});

	// Manejar muerte del jugador
	if (target.hp <= 0) {
		console.log(`💀 JUGADOR ${playerId} MUERTO POR ATAQUE DE ÁREA MAGA`);
		
		target.is_alive = false;
		target.respawn_timer = 10;

		broadcast({
			type: 'player_dead',
			id: parseInt(playerId),
			by: ownerId,
			respawn_time: 10
		});

		startRespawnTimer(playerId);
	}
}

// Función para aplicar daño de maga a enemigo (SIMPLIFICADA)
function _applyMageDamageToEnemy(enemyId, damage, ownerId) {
	const target = enemies[enemyId];
	if (!target) {
		console.log("❌ ENEMIGO OBJETIVO NO ENCONTRADO");
		return;
	}

	console.log("✅ DAÑO PERMITIDO - Aplicando daño a enemigo:", enemyId);

	const reducedDamage = 1;
	target.hp -= reducedDamage;
	if (target.hp < 0) target.hp = 0;

	console.log(`💥 MAGA DAÑA ENEMIGO - ${reducedDamage} a ${enemyId}, HP restante: ${target.hp}`);

	broadcast({ 
		type: 'enemy_hit', 
		id: enemyId, 
		hp: target.hp 
	});

	// Manejar muerte del enemigo
	if (target.hp <= 0) {
		console.log(`💀 ENEMIGO ${enemyId} MUERTO POR ATAQUE DE ÁREA MAGA`);
		
		const enemyType = target.type;
		let killReward = 0;
		
		switch (enemyType) {
			case 'grunt': killReward = 5; break;
			case 'archer': killReward = 8; break;
			case 'mage': killReward = 10; break;
			case 'boss_wave': killReward = 30; break;
			case 'final_boss': killReward = 50; break;
			default: killReward = 5;
		}

		if (target.is_permanent) {
			killReward = 50;
			console.log(`💰 RECOMPENSA POR JEFE PERMANENTE - +${killReward} monedas`);
		}

		const newAmount = economySystem.addCurrency(ownerId, killReward, players[ownerId]);
		console.log(`💰 RECOMPENSA POR KILL DE ÁREA MAGA - +${killReward} monedas`);

		sendToPlayer(ownerId, {
			type: 'currency_updated',
			player_id: parseInt(ownerId),
			amount: newAmount
		});

		if (target.is_permanent) {
			handleBossDeath(enemyId);
		} else {
			delete enemies[enemyId];
		}

		broadcast({
			type: 'enemy_dead',
			id: parseInt(enemyId),
			by: ownerId,
			killer_id: ownerId,
			enemy_type: enemyType
		});
	}
}
function _applyMageDamageToBase(baseTeam, damage, ownerId) {
    const base = bases[baseTeam];
    if (!base) {
        console.log("❌ BASE OBJETIVO NO ENCONTRADO");
        return;
    }

    console.log("✅ DAÑO PERMITIDO - Aplicando daño a base:", baseTeam);
	 const reducedDamage = 1;
    base.hp -=reducedDamage;
    if (base.hp < 0) base.hp = 0;

    console.log(`💥 MAGA DAÑA BASE - ${0.5} (reducido de ${reducedDamage}) a base ${baseTeam}, HP restante: ${base.hp}`);

    broadcast({
        type: 'base_hit',
        team: parseInt(baseTeam),
        hp: base.hp,
        max_hp: base.maxHp
    });

    if (base.hp <= 0) {
        console.log(`💀 BASE ${baseTeam} DESTRUIDA POR ATAQUE DE ÁREA MAGA!`);
        checkBaseDestruction();
    }
}
// ----------------------------
// INICIAR SERVIDOR CON BÚSQUEDA AUTOMÁTICA DE PUERTOS
// ----------------------------
function startServer(port) {
	server.listen(port, '0.0.0.0', () => {
		console.log(`✅ HTTP + WS server corriendo en puerto ${port}`);
		console.log(`🎮 BLOODY-THRONE - Sistema de jefe permanente activo`);
		console.log(`👥 Máximo ${MAX_PLAYERS_PER_TEAM} jugadores por equipo`);
		console.log(`💰 Sistema económico implementado`);
		console.log(`🃏 Sistema de cartas implementado`);
		console.log(`👹 Jefe permanente con IA avanzada`);
		console.log(`🔁 Sistema de respawn activo (5 segundos)`);
		console.log(`🔥 Ataques de área para arquera, rogue y maga implementados`);
	}).on('error', (err) => {
		if (err.code === 'EADDRINUSE') {
			console.log(`❌ Puerto ${port} en uso. Intentando con puerto ${port + 1}`);
			startServer(port + 1);
		} else {
			console.error('❌ Error del servidor:', err);
		}
	});
}

// Iniciar el servidor
startServer(PORT);

function coderlife() {
	while (alive) {
		eat();
		//sleep();
		code();
	}
}