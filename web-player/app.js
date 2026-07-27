// Torrent Media Player - Interactive Engine Simulation & Preview

const presets = {
    bunny: {
        title: "Big Buck Bunny 1080p.mp4",
        size: "276.1 MB",
        poster: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
        src: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    },
    sintel: {
        title: "Sintel.2010.4K.mkv",
        size: "648.5 MB",
        poster: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/Sintel.jpg",
        src: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"
    },
    tears: {
        title: "Tears.of.Steel.720p.avi",
        size: "412.0 MB",
        poster: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg",
        src: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"
    }
};

let piecesCount = 40;
let bufferedPieces = 0;
let dlSpeedMbps = 0;
let peers = 0;
let seeds = 0;
let reannounceCount = 0;
let autoPlayTriggered = false;

const videoPlayer = document.getElementById("media-player");
const videoOverlay = document.getElementById("video-overlay");
const piecesContainer = document.getElementById("pieces-container");
const logTerminal = document.getElementById("log-terminal");
const magnetInput = document.getElementById("magnet-input");
const addBtn = document.getElementById("add-btn");

// Initialize Piece Map Grid
function initPieceMap() {
    piecesContainer.innerHTML = "";
    for (let i = 0; i < piecesCount; i++) {
        const block = document.createElement("div");
        block.className = "piece-block";
        block.id = `piece-${i}`;
        piecesContainer.appendChild(block);
    }
}

function logEvent(msg, type = "info") {
    const entry = document.createElement("div");
    entry.className = `log-entry ${type}`;
    const timestamp = new Date().toISOString().substring(11, 19);
    entry.innerText = `[${timestamp}] ${msg}`;
    logTerminal.appendChild(entry);
    logTerminal.scrollTop = logTerminal.scrollHeight;
}

function updateStatsUI() {
    const percent = Math.min(100, Math.round((bufferedPieces / piecesCount) * 100));
    document.getElementById("progress-percent").innerText = `${percent}%`;
    document.getElementById("pieces-buffered").innerText = `${bufferedPieces} / ${piecesCount} pieces`;
    document.getElementById("dl-speed").innerText = `${dlSpeedMbps.toFixed(1)} MB/s`;
    document.getElementById("peers-count").innerText = `${seeds} / ${peers}`;
    document.getElementById("reannounce-count").innerText = reannounceCount;
}

// Start Torrent Media Player Automation Loop
function startEngine(presetKey = "bunny") {
    const data = presets[presetKey] || presets.bunny;

    document.getElementById("current-title").innerText = data.title;
    document.getElementById("current-size").innerText = data.size;
    videoPlayer.poster = data.poster;
    videoPlayer.src = data.src;

    videoOverlay.classList.add("show");
    videoPlayer.pause();

    bufferedPieces = 0;
    dlSpeedMbps = 0;
    peers = 0;
    seeds = 0;
    reannounceCount = 0;
    autoPlayTriggered = false;
    initPieceMap();
    updateStatsUI();

    logEvent(`Added torrent media: ${data.title}`, "success");
    logEvent(`AutoPlayService: Forced Sequential Download (Pieces 0 → ${piecesCount - 1})`, "action");

    // Peer Reconnect Cycle
    let reconnectTimer = setInterval(() => {
        if (seeds < 10) {
            reannounceCount++;
            seeds += Math.floor(Math.random() * 8) + 4;
            peers += Math.floor(Math.random() * 5) + 2;
            logEvent(`PeerReconnectService: Tracker re-announced. Connected peers: ${seeds}`, "action");
            document.getElementById("reconnect-status").innerText = `Active (Re-announced ${reannounceCount}x)`;
        } else {
            clearInterval(reconnectTimer);
        }
    }, 2000);

    // Sequential Download Piece Fill Engine
    let downloadTimer = setInterval(() => {
        if (bufferedPieces < piecesCount) {
            dlSpeedMbps = 4.0 + Math.random() * 3.5;
            
            // Sequential filling (piece 0, 1, 2, 3...)
            const pieceBlock = document.getElementById(`piece-${bufferedPieces}`);
            if (pieceBlock) {
                pieceBlock.classList.add("buffered");
            }
            bufferedPieces++;
            updateStatsUI();

            // Auto-Play Trigger Condition: 2 pieces (initial sequential chunk ready)
            if (bufferedPieces >= 2 && !autoPlayTriggered) {
                autoPlayTriggered = true;
                videoOverlay.classList.remove("show");
                videoPlayer.play();
                logEvent(`AutoPlayService: Initial sequential buffer ready! Auto-launching fullscreen video playback.`, "highlight");
                document.getElementById("vlc-status").innerText = "Playing in VLC Engine";
            }
        } else {
            clearInterval(downloadTimer);
            dlSpeedMbps = 0;
            updateStatsUI();
            logEvent(`Torrent media download completed sequentially!`, "success");
        }
    }, 400);
}

// Preset Listeners
document.querySelectorAll(".preset-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        const presetKey = btn.getAttribute("data-preset");
        startEngine(presetKey);
    });
});

addBtn.addEventListener("click", () => {
    startEngine("bunny");
});

// Initialize on Load
initPieceMap();
startEngine("bunny");
