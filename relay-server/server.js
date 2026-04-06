/**
 * Phantom Crew — WebSocket Relay Server
 *
 * Peer-to-peer relay for up to 8 players per room.
 * All messages are JSON. Any player can host a room.
 * Messages are broadcast to all other players in the room
 * (no dedicated host required — fully peer-to-peer via relay).
 *
 * Supported client message types (all forwarded to room peers):
 *   hostRoom, joinRoom, listRooms, playerUpdate, startGame, roleAssign,
 *   playerMove, kill, reportBody, ventAction, sabotage, fixSabotage,
 *   taskComplete, emergencyMeeting, chatMessage, vote, voteResult,
 *   meetingEnd, gameOver, clientLeft, ping, pong
 *
 * Deploy to: Render, Railway, Fly.io, or any Node.js host
 */

const WebSocket = require('ws');

const PORT = process.env.PORT || 3000;
const MAX_PLAYERS = 8;
const ROOM_TTL_MS = 2 * 60 * 60 * 1000;  // 2 hours
const PING_INTERVAL_MS = 25000;
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000;

/**
 * rooms: Map<roomName, RoomRecord>
 * RoomRecord: {
 *   name: string,
 *   hostId: string,
 *   maxPlayers: number,
 *   phantomCount: number,
 *   players: Map<playerId, { ws, name, colorKey, connId }>,
 *   createdAt: number,
 *   phase: 'lobby'|'playing'|'ended',
 * }
 */
const rooms = new Map();

/** connections: Map<connId, { ws, playerId, roomName }> */
const connections = new Map();

let connCounter = 0;
const genConnId = () => `c${Date.now()}${++connCounter}`;

const wss = new WebSocket.Server({ port: PORT });
console.log(`[PhantomCrew] Relay server v2 on port ${PORT}`);

// ── Connection lifecycle ───────────────────────────────────────────────────

wss.on('connection', (ws) => {
  const connId = genConnId();
  connections.set(connId, { ws, playerId: null, roomName: null });

  ws.on('message', (raw) => {
    try { dispatch(connId, ws, JSON.parse(raw.toString())); }
    catch (e) { console.error('[msg error]', e.message); }
  });

  ws.on('close', () => onDisconnect(connId));
  ws.on('error', (err) => { console.error(`[conn ${connId}]`, err.message); onDisconnect(connId); });

  ws.send(JSON.stringify({ type: 'welcome', connId }));
});

// ── Message dispatcher ────────────────────────────────────────────────────

function dispatch(connId, ws, msg) {
  switch (msg.type) {
    case 'hostRoom':    return cmdHostRoom(connId, ws, msg);
    case 'joinRoom':    return cmdJoinRoom(connId, ws, msg);
    case 'listRooms':   return cmdListRooms(ws);
    case 'clientLeft':  return cmdLeave(connId);
    case 'ping':        return ws.send(JSON.stringify({ type: 'pong' }));
    case 'pong':        return; // ignore
    default:
      // All game messages — relay to everyone else in the room
      relayToRoom(connId, msg);
  }
}

// ── Commands ──────────────────────────────────────────────────────────────

function cmdHostRoom(connId, ws, msg) {
  const { room: roomName, sender: hostId, maxPlayers = MAX_PLAYERS, phantomCount = 2, playerName = 'Host', colorKey = 'cyan' } = msg;

  if (!roomName || !hostId) return sendError(ws, 'hostRoom requires room and sender');
  if (rooms.has(roomName)) return sendError(ws, `Room "${roomName}" already exists`);

  const room = {
    name: roomName,
    hostId,
    maxPlayers: Math.min(maxPlayers, MAX_PLAYERS),
    phantomCount,
    players: new Map(),
    createdAt: Date.now(),
    phase: 'lobby',
  };
  room.players.set(hostId, { ws, name: playerName, colorKey, connId });
  rooms.set(roomName, room);

  const conn = connections.get(connId);
  if (conn) { conn.playerId = hostId; conn.roomName = roomName; }

  console.log(`[room] created "${roomName}" by ${hostId} (max ${room.maxPlayers})`);
  ws.send(JSON.stringify({ type: 'room_created', room: roomName }));
}

function cmdJoinRoom(connId, ws, msg) {
  const { room: roomName, sender: playerId, playerName = 'Unknown', colorKey = 'cyan' } = msg;

  if (!roomName || !playerId) return sendError(ws, 'joinRoom requires room and sender');

  const room = rooms.get(roomName);
  if (!room) return sendError(ws, `Room "${roomName}" not found`);
  if (room.players.size >= room.maxPlayers) return sendError(ws, 'Room is full');
  if (room.phase !== 'lobby') return sendError(ws, 'Game already in progress');

  room.players.set(playerId, { ws, name: playerName, colorKey, connId });
  const conn = connections.get(connId);
  if (conn) { conn.playerId = playerId; conn.roomName = roomName; }

  console.log(`[room] "${roomName}" ← ${playerId} (${playerName}), now ${room.players.size}/${room.maxPlayers}`);

  // Confirm to the joining player
  ws.send(JSON.stringify({ type: 'joined_room', room: roomName }));

  // Notify everyone else a player joined
  broadcastExcept(room, playerId, {
    type: 'clientJoined',
    room: roomName,
    sender: playerId,
    playerName,
    colorKey,
  });

  // Send current player list to the new player
  const playerList = [...room.players.entries()].map(([pid, p]) => ({
    id: pid,
    name: p.name,
    colorKey: p.colorKey,
    isHost: pid === room.hostId,
  }));
  ws.send(JSON.stringify({ type: 'roomState', room: roomName, players: playerList }));
}

function cmdListRooms(ws) {
  const list = [];
  rooms.forEach((room, name) => {
    list.push({
      name,
      playerCount: room.players.size,
      maxPlayers: room.maxPlayers,
      hostId: room.hostId,
      phase: room.phase,
    });
  });
  ws.send(JSON.stringify({ type: 'roomList', rooms: list }));
}

function cmdLeave(connId) {
  const conn = connections.get(connId);
  if (!conn) return;
  onDisconnect(connId);
}

// ── Relay ─────────────────────────────────────────────────────────────────

function relayToRoom(connId, msg) {
  const conn = connections.get(connId);
  if (!conn?.roomName) return;

  const room = rooms.get(conn.roomName);
  if (!room) return;

  const senderId = conn.playerId;

  // Update phase if startGame is relayed
  if (msg.type === 'startGame') room.phase = 'playing';
  if (msg.type === 'gameOver') room.phase = 'ended';

  // Broadcast to everyone in the room except the sender
  broadcastExcept(room, senderId, msg);
}

// ── Helpers ───────────────────────────────────────────────────────────────

function broadcastExcept(room, excludeId, msg) {
  const raw = JSON.stringify(msg);
  room.players.forEach((player, pid) => {
    if (pid === excludeId) return;
    if (player.ws.readyState === WebSocket.OPEN) {
      player.ws.send(raw);
    }
  });
}

function sendError(ws, message) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'error', message }));
  }
}

function onDisconnect(connId) {
  const conn = connections.get(connId);
  if (!conn) return;
  connections.delete(connId);

  const { playerId, roomName } = conn;
  if (!roomName) return;

  const room = rooms.get(roomName);
  if (!room) return;

  room.players.delete(playerId);
  console.log(`[room] "${roomName}" ← ${playerId} left, ${room.players.size} remain`);

  if (room.players.size === 0) {
    rooms.delete(roomName);
    console.log(`[room] "${roomName}" closed (empty)`);
    return;
  }

  // If host left, pick a new host
  if (playerId === room.hostId) {
    const newHostId = room.players.keys().next().value;
    room.hostId = newHostId;
    console.log(`[room] "${roomName}" new host: ${newHostId}`);
  }

  // Notify remaining players
  broadcastExcept(room, null, {
    type: 'clientLeft',
    room: roomName,
    sender: playerId,
  });
}

// ── Maintenance ───────────────────────────────────────────────────────────

setInterval(() => {
  const now = Date.now();
  rooms.forEach((room, name) => {
    if (now - room.createdAt > ROOM_TTL_MS) {
      console.log(`[cleanup] removing stale room "${name}"`);
      broadcastExcept(room, null, { type: 'roomClosed', room: name });
      rooms.delete(name);
    }
  });
}, CLEANUP_INTERVAL_MS);

setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.readyState === WebSocket.OPEN) ws.ping();
  });
}, PING_INTERVAL_MS);

console.log('[PhantomCrew] Relay server ready.');
