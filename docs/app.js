// ==============================================================================
// Cyber Range Live Leaderboard Application Logic
// CPIFP Alan Turing - Curso de Especialización en Ciberseguridad
// ==============================================================================

import { DEFAULT_CONFIG } from './config.js';

// Application State
let activeConfig = { ...DEFAULT_CONFIG };
let studentsData = {};
let filterStatus = 'all';
let searchQuery = '';
let eventSource = null;
let pollTimer = null;

// DOM Elements Cache
const elements = {
  connectionStatus: document.getElementById('connection-status'),
  pulseDot: document.getElementById('pulse-dot'),
  statusText: document.getElementById('status-text'),
  metricOperatives: document.getElementById('metric-operatives'),
  metricTopScore: document.getElementById('metric-top-score'),
  metricAvgScore: document.getElementById('metric-avg-score'),
  metricCompleted: document.getElementById('metric-completed'),
  firstBloodGrid: document.getElementById('first-blood-grid'),
  leaderboardBody: document.getElementById('leaderboard-body'),
  searchInput: document.getElementById('search-input'),
  filterButtons: document.querySelectorAll('.filter-btn'),
  settingsBtn: document.getElementById('settings-btn'),
  settingsModal: document.getElementById('settings-modal'),
  closeModalBtn: document.getElementById('close-modal-btn'),
  cancelModalBtn: document.getElementById('cancel-modal-btn'),
  saveSettingsBtn: document.getElementById('save-settings-btn'),
  inputDbUrl: document.getElementById('input-db-url'),
  inputWorkshopId: document.getElementById('input-workshop-id'),
  demoDataBtn: document.getElementById('demo-data-btn')
};

// Initialize configuration from localStorage
function loadConfiguration() {
  const savedUrl = localStorage.getItem('turing_db_url');
  const savedWorkshop = localStorage.getItem('turing_workshop_id');

  if (savedUrl) activeConfig.databaseURL = savedUrl;
  if (savedWorkshop) activeConfig.workshopId = savedWorkshop;

  elements.inputDbUrl.value = activeConfig.databaseURL;
  elements.inputWorkshopId.value = activeConfig.workshopId;
}

// Save configuration from modal
function saveConfiguration() {
  const newUrl = elements.inputDbUrl.value.trim().replace(/\/$/, '');
  const newWorkshop = elements.inputWorkshopId.value.trim();

  if (newUrl) {
    activeConfig.databaseURL = newUrl;
    localStorage.setItem('turing_db_url', newUrl);
  }
  if (newWorkshop) {
    activeConfig.workshopId = newWorkshop;
    localStorage.setItem('turing_workshop_id', newWorkshop);
  }

  elements.settingsModal.classList.remove('active');
  restartConnection();
}

// Update connection status pill
function setConnectionState(state, message) {
  if (state === 'live') {
    elements.pulseDot.className = 'pulse-dot';
    elements.statusText.textContent = message || 'Live WebSocket';
  } else if (state === 'syncing') {
    elements.pulseDot.className = 'pulse-dot';
    elements.statusText.textContent = message || 'Polling Active';
  } else {
    elements.pulseDot.className = 'pulse-dot offline';
    elements.statusText.textContent = message || 'Offline / Standby';
  }
}

// Connect to Firebase Realtime Database using Server-Sent Events (SSE)
function connectRealtime() {
  if (eventSource) {
    eventSource.close();
  }

  const cleanUrl = activeConfig.databaseURL.replace(/\/$/, '');
  const sseEndpoint = `${cleanUrl}/workshops/${activeConfig.workshopId}/students.json`;

  try {
    eventSource = new EventSource(sseEndpoint);

    eventSource.addEventListener('put', (e) => {
      try {
        const payload = JSON.parse(e.data);
        if (payload.path === '/' && payload.data) {
          studentsData = payload.data;
        } else if (payload.path && payload.path !== '/') {
          const studentKey = payload.path.replace(/^\//, '').split('/')[0];
          if (!studentsData[studentKey]) studentsData[studentKey] = {};
          // Merge partial updates
          Object.assign(studentsData[studentKey], payload.data);
        }
        setConnectionState('live', 'Live RTDB');
        renderDashboard();
      } catch (err) {
        console.error('SSE JSON parse error:', err);
      }
    });

    eventSource.addEventListener('patch', (e) => {
      try {
        const payload = JSON.parse(e.data);
        if (payload.data) {
          Object.assign(studentsData, payload.data);
        }
        setConnectionState('live', 'Live RTDB');
        renderDashboard();
      } catch (err) {
        console.error('SSE patch error:', err);
      }
    });

    eventSource.onerror = () => {
      setConnectionState('syncing', 'Fallback Polling');
      fallbackPoll();
    };

    setConnectionState('live', 'Connecting...');
  } catch (err) {
    console.warn('EventSource initialization failed, using polling:', err);
    fallbackPoll();
  }
}

// Fallback HTTP polling if SSE is restricted by CORS or environment
async function fallbackPoll() {
  if (pollTimer) clearInterval(pollTimer);

  const fetchOnce = async () => {
    try {
      const cleanUrl = activeConfig.databaseURL.replace(/\/$/, '');
      const resp = await fetch(`${cleanUrl}/workshops/${activeConfig.workshopId}/students.json`, {
        cache: 'no-store'
      });
      if (resp.ok) {
        const data = await resp.json();
        if (data) {
          studentsData = data;
          setConnectionState('live', 'REST Sync');
          renderDashboard();
        }
      } else {
        setConnectionState('offline', 'DB Standby');
      }
    } catch {
      setConnectionState('offline', 'DB Standby');
    }
  };

  await fetchOnce();
  pollTimer = setInterval(fetchOnce, activeConfig.refreshIntervalMs);
}

function restartConnection() {
  if (eventSource) eventSource.close();
  if (pollTimer) clearInterval(pollTimer);
  connectRealtime();
}

// Parse student array from dictionary and calculate metrics
function processStudents() {
  if (!studentsData || typeof studentsData !== 'object') return [];

  const list = Object.keys(studentsData).map((key) => {
    const item = studentsData[key];
    const ch = item.challenges || {};

    let totalHints = 0;
    ['step1', 'step2', 'step3', 'step4'].forEach((step) => {
      if (ch[step] && Array.isArray(ch[step].hintsTaken)) {
        totalHints += ch[step].hintsTaken.length;
      }
    });

    return {
      id: key,
      alias: item.alias || key,
      registeredAt: item.registeredAt || 'Unknown',
      totalScore: Number(item.totalScore || 0),
      completedChallenges: Number(item.completedChallenges || 0),
      status: item.status || 'in_progress',
      challenges: ch,
      totalHints
    };
  });

  // Sort: Highest totalScore -> Highest completedChallenges -> Alphabetical
  list.sort((a, b) => {
    if (b.totalScore !== a.totalScore) return b.totalScore - a.totalScore;
    if (b.completedChallenges !== a.completedChallenges) return b.completedChallenges - a.completedChallenges;
    return a.alias.localeCompare(b.alias);
  });

  return list;
}

// Render Header Metrics & First Blood Showcase
function renderMetrics(students) {
  const totalOperatives = students.length;
  elements.metricOperatives.textContent = totalOperatives;

  if (totalOperatives === 0) {
    elements.metricTopScore.textContent = '0';
    elements.metricAvgScore.textContent = '0';
    elements.metricCompleted.textContent = '0';
    return;
  }

  const topScore = Math.max(...students.map(s => s.totalScore));
  const totalScoreSum = students.reduce((acc, s) => acc + s.totalScore, 0);
  const avgScore = Math.round(totalScoreSum / totalOperatives);
  const completedCount = students.filter(s => s.completedChallenges === 4).length;

  elements.metricTopScore.textContent = topScore;
  elements.metricAvgScore.textContent = avgScore;
  elements.metricCompleted.textContent = completedCount;

  // Calculate First Blood for each Step
  renderFirstBlood(students);
}

// Determine earliest solvers per step
function renderFirstBlood(students) {
  const steps = [
    { key: 'step1', name: 'Step 1: Memory Leak' },
    { key: 'step2', name: 'Step 2: Socket Breakout' },
    { key: 'step3', name: 'Step 3: DFIR YARA' },
    { key: 'step4', name: 'Step 4: CIS Hardening' }
  ];

  elements.firstBloodGrid.innerHTML = '';

  steps.forEach(step => {
    let earliest = null;
    let earliestTime = null;

    students.forEach(s => {
      const ch = s.challenges[step.key];
      if (ch && ch.completed && ch.completedAt) {
        if (!earliestTime || ch.completedAt < earliestTime) {
          earliest = s.alias;
          earliestTime = ch.completedAt;
        }
      }
    });

    const card = document.createElement('div');
    card.className = 'first-blood-card';
    card.innerHTML = `
      <div class="fb-task-info">
        <span class="fb-task-name">${step.name}</span>
        <span class="fb-agent-name">${earliest || 'Awaiting Solution...'}</span>
      </div>
      <div class="fb-time-badge">${earliestTime ? earliestTime.split(' ')[1] + ' ' + (earliestTime.split(' ')[2] || '') : '--:--'}</div>
    `;
    elements.firstBloodGrid.appendChild(card);
  });
}

// Render Leaderboard Table
function renderDashboard() {
  const students = processStudents();
  renderMetrics(students);

  // Apply filters
  const filtered = students.filter(s => {
    const matchesFilter = 
      filterStatus === 'all' ? true :
      filterStatus === 'completed' ? s.completedChallenges === 4 :
      filterStatus === 'in_progress' ? s.completedChallenges < 4 : true;

    const matchesSearch = s.alias.toLowerCase().includes(searchQuery.toLowerCase());

    return matchesFilter && matchesSearch;
  });

  if (filtered.length === 0) {
    elements.leaderboardBody.innerHTML = `
      <tr>
        <td colspan="7" class="empty-state">
          <div class="empty-state-title">No Operatives Found</div>
          <div>${students.length === 0 ? 'Awaiting incoming telemetry from active Killercoda sessions.' : 'No operative matches the current search or filter.'}</div>
        </td>
      </tr>
    `;
    return;
  }

  elements.leaderboardBody.innerHTML = '';

  filtered.forEach((s, index) => {
    const rank = index + 1;
    const rankClass = rank === 1 ? 'rank-1' : rank === 2 ? 'rank-2' : rank === 3 ? 'rank-3' : '';
    const initials = s.alias.slice(0, 2).toUpperCase();
    const progressPercent = Math.min(100, Math.round((s.totalScore / activeConfig.totalBaseScore) * 100));

    // Get last completed challenge timestamp
    let lastTime = s.registeredAt;
    ['step4', 'step3', 'step2', 'step1'].some(step => {
      if (s.challenges[step] && s.challenges[step].completed && s.challenges[step].completedAt) {
        lastTime = s.challenges[step].completedAt;
        return true;
      }
      return false;
    });

    // Step Matrix HTML
    const renderStepBadge = (stepKey, label) => {
      const ch = s.challenges[stepKey] || {};
      const isDone = ch.completed === true;
      const pts = ch.score !== undefined ? `${ch.score}p` : '--';
      const hints = ch.hintsTaken && ch.hintsTaken.length > 0 ? `H:${ch.hintsTaken.length}` : '';

      return `
        <div class="matrix-step ${isDone ? 'completed' : ''}" title="${label}">
          <span>${label}</span>
          <span class="step-pts">${isDone ? pts : '--'}</span>
          ${hints ? `<span class="hint-tag">${hints}</span>` : ''}
        </div>
      `;
    };

    const row = document.createElement('tr');
    row.innerHTML = `
      <td>
        <div class="rank-badge ${rankClass}">#${rank}</div>
      </td>
      <td>
        <div class="operative-cell">
          <div class="operative-avatar">${initials}</div>
          <div>
            <div class="operative-alias">${escapeHtml(s.alias)}</div>
            <div class="operative-registered">Reg: ${escapeHtml(s.registeredAt)}</div>
          </div>
        </div>
      </td>
      <td>
        <div class="score-cell">
          <span class="score-main">${s.totalScore}</span> <span style="font-size: 0.75rem; color: var(--text-muted);">/ 1000</span>
          <div class="score-progress-bar">
            <div class="score-progress-fill" style="width: ${progressPercent}%;"></div>
          </div>
        </div>
      </td>
      <td>
        <div class="challenge-matrix">
          ${renderStepBadge('step1', 'Ch 1')}
          ${renderStepBadge('step2', 'Ch 2')}
          ${renderStepBadge('step3', 'Ch 3')}
          ${renderStepBadge('step4', 'Ch 4')}
        </div>
      </td>
      <td>
        <span class="hint-count-badge ${s.totalHints > 0 ? 'has-hints' : ''}">
          ${s.totalHints > 0 ? `${s.totalHints} used` : 'None'}
        </span>
      </td>
      <td class="time-cell">
        ${escapeHtml(lastTime)}
      </td>
      <td>
        <span class="status-tag ${s.completedChallenges === 4 ? 'completed' : 'in-progress'}">
          ${s.completedChallenges === 4 ? 'Completed' : 'In Progress'}
        </span>
      </td>
    `;
    elements.leaderboardBody.appendChild(row);
  });
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Generate Realistic Sample Data for Demo / Preview
function loadDemoData() {
  studentsData = {
    "student_valkyrie": {
      "alias": "valkyrie_sec",
      "registeredAt": "2026-10-17 11:31:12 AM",
      "totalScore": 950,
      "completedChallenges": 4,
      "status": "completed",
      "challenges": {
        "step1": { "completed": true, "score": 200, "completedAt": "2026-10-17 11:41:20 AM", "hintsTaken": [] },
        "step2": { "completed": true, "score": 250, "completedAt": "2026-10-17 11:54:15 AM", "hintsTaken": [] },
        "step3": { "completed": true, "score": 275, "completedAt": "2026-10-17 12:12:30 PM", "hintsTaken": [1] },
        "step4": { "completed": true, "score": 225, "completedAt": "2026-10-17 12:28:40 PM", "hintsTaken": [] }
      }
    },
    "student_hexblade": {
      "alias": "hex_blade",
      "registeredAt": "2026-10-17 11:32:05 AM",
      "totalScore": 875,
      "completedChallenges": 4,
      "status": "completed",
      "challenges": {
        "step1": { "completed": true, "score": 175, "completedAt": "2026-10-17 11:43:50 AM", "hintsTaken": [1] },
        "step2": { "completed": true, "score": 220, "completedAt": "2026-10-17 11:59:10 AM", "hintsTaken": [1] },
        "step3": { "completed": true, "score": 300, "completedAt": "2026-10-17 12:17:05 PM", "hintsTaken": [] },
        "step4": { "completed": true, "score": 180, "completedAt": "2026-10-17 12:34:10 PM", "hintsTaken": [2] }
      }
    },
    "student_darkmatter": {
      "alias": "dark_matter",
      "registeredAt": "2026-10-17 11:33:40 AM",
      "totalScore": 725,
      "completedChallenges": 3,
      "status": "in_progress",
      "challenges": {
        "step1": { "completed": true, "score": 200, "completedAt": "2026-10-17 11:44:12 AM", "hintsTaken": [] },
        "step2": { "completed": true, "score": 250, "completedAt": "2026-10-17 11:58:30 AM", "hintsTaken": [] },
        "step3": { "completed": true, "score": 275, "completedAt": "2026-10-17 12:21:40 PM", "hintsTaken": [1] },
        "step4": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] }
      }
    },
    "student_zerotrace": {
      "alias": "zero_trace",
      "registeredAt": "2026-10-17 11:34:15 AM",
      "totalScore": 450,
      "completedChallenges": 2,
      "status": "in_progress",
      "challenges": {
        "step1": { "completed": true, "score": 200, "completedAt": "2026-10-17 11:46:02 AM", "hintsTaken": [] },
        "step2": { "completed": true, "score": 250, "completedAt": "2026-10-17 12:02:18 PM", "hintsTaken": [] },
        "step3": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [1, 2] },
        "step4": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] }
      }
    }
  };
  setConnectionState('live', 'Demo Cohort Mode');
  renderDashboard();
}

// Event Listeners Initialization
function setupEventListeners() {
  // Search
  elements.searchInput.addEventListener('input', (e) => {
    searchQuery = e.target.value;
    renderDashboard();
  });

  // Filters
  elements.filterButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      elements.filterButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      filterStatus = btn.dataset.status;
      renderDashboard();
    });
  });

  // Settings Modal
  elements.settingsBtn.addEventListener('click', () => {
    elements.settingsModal.classList.add('active');
  });

  elements.closeModalBtn.addEventListener('click', () => {
    elements.settingsModal.classList.remove('active');
  });

  elements.cancelModalBtn.addEventListener('click', () => {
    elements.settingsModal.classList.remove('active');
  });

  elements.saveSettingsBtn.addEventListener('click', saveConfiguration);

  // Demo Data Preview
  elements.demoDataBtn.addEventListener('click', loadDemoData);
}

// Bootstrap
document.addEventListener('DOMContentLoaded', () => {
  loadConfiguration();
  setupEventListeners();
  connectRealtime();
});
