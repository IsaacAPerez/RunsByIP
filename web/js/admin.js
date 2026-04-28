const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// DOM elements
const loginSection = document.getElementById('login-section');
const dashboard = document.getElementById('dashboard');
const headerActions = document.getElementById('header-actions');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const createSessionForm = document.getElementById('create-session-form');
const sessionsList = document.getElementById('sessions-list');
const toast = document.getElementById('toast');

// Pre-fill date input to next Wednesday
function getNextWednesday() {
  const d = new Date();
  const day = d.getDay();
  const diff = (3 - day + 7) % 7 || 7;
  d.setDate(d.getDate() + diff);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
document.getElementById('new-session-date').value = getNextWednesday();

// Toast helper
function showToast(message, type = 'success') {
  toast.textContent = message;
  toast.className = `toast toast-${type} show`;
  setTimeout(() => toast.classList.remove('show'), 3000);
}

// Show dashboard
function showDashboard() {
  loginSection.classList.add('hidden');
  dashboard.classList.remove('hidden');
  headerActions.classList.remove('hidden');
  loadSessions();
}

// Format date for display
function formatDate(dateStr) {
  const date = new Date(dateStr + 'T00:00:00');
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
}

// Check existing auth session
async function checkAuth() {
  const { data: { session } } = await db.auth.getSession();
  if (session) showDashboard();
}

// Login
loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  loginError.classList.add('hidden');

  const email = document.getElementById('login-email').value;
  const password = document.getElementById('login-password').value;

  const { error } = await db.auth.signInWithPassword({ email, password });

  if (error) {
    loginError.textContent = error.message;
    loginError.classList.remove('hidden');
    return;
  }

  showDashboard();
});

// Logout
document.getElementById('logout-btn').addEventListener('click', async () => {
  await db.auth.signOut();
  location.reload();
});

// Load all sessions
async function loadSessions() {
  const { error: rpcErr } = await db.rpc('mark_past_sessions_completed');
  if (rpcErr) console.warn('mark_past_sessions_completed', rpcErr);

  const { data: sessions, error } = await db
    .from('sessions')
    .select('*')
    .order('date', { ascending: false });

  if (error) {
    showToast('Failed to load sessions', 'error');
    return;
  }

  sessionsList.innerHTML = '';

  if (!sessions || sessions.length === 0) {
    sessionsList.innerHTML = '<p class="text-muted text-center py-8">No sessions yet. Create one above.</p>';
    return;
  }

  for (const session of sessions) {
    const { data: rsvps } = await db
      .from('rsvps')
      .select('*')
      .eq('session_id', session.id)
      .order('created_at', { ascending: true });

    sessionsList.appendChild(buildSessionCard(session, rsvps || []));
  }
}

// Build a session card with RSVPs
// Every row in `rsvps` is a confirmed (paid) attendee — the stripe-webhook
// is the only insert path, triggered on payment_intent.succeeded.
function buildSessionCard(session, rsvps) {
  const card = document.createElement('div');
  card.className = 'bg-surface rounded-2xl border border-surface-light p-6';

  const statusColors = {
    open: 'bg-green-500/15 text-green-400',
    completed: 'bg-zinc-500/15 text-zinc-400',
    cancelled: 'bg-red-500/15 text-red-400',
  };

  const stRaw = session.status || 'open';
  const st = stRaw === 'confirmed' ? 'open' : stRaw;
  const sessionPk = String(session.id).trim();
  const nextPaymentsOpen = !session.payments_open;

  const paymentsBlock =
    st === 'open'
      ? `
    <div class="mb-4">
      <button type="button" data-admin-action="toggle-drop" data-session-id="${sessionPk}" data-next-open="${nextPaymentsOpen}"
        class="w-full flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-base transition-colors ${session.payments_open
          ? 'bg-red-600 active:bg-red-700 text-white'
          : 'bg-green-600 active:bg-green-700 text-white'
        }">
        ${session.payments_open
          ? '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg> Lock Payments'
          : '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z"/></svg> DROP IT \u2014 Open Payments'
        }
      </button>
      <p class="text-xs text-center mt-1.5 ${session.payments_open ? 'text-green-400' : 'text-muted-dark'}">
        ${session.payments_open ? 'Payments are LIVE' : 'Payments locked \u2014 players can see the session but can\u2019t pay yet'}
      </p>
    </div>
    `
      : '';

  const paymentsLockedNote =
    st === 'completed'
      ? '<p class="text-xs text-zinc-400 mb-4">Run date has passed — status is <strong class="text-white">completed</strong>. Payments stay off.</p>'
      : st === 'cancelled'
        ? ''
        : '';

  const rsvpBlock =
    rsvps.length > 0
      ? `
      <div class="border-t border-surface-light pt-4">
        <h4 class="text-sm font-medium text-muted mb-2">RSVPs</h4>
        <div class="space-y-2">
          ${rsvps
            .map(
              (rsvp) => `
            <div class="flex items-center justify-between text-sm" data-rsvp-id="${escapeHtml(rsvp.id)}">
              <div>
                <span class="text-white">${escapeHtml(rsvp.player_name)}</span>
                <span class="text-muted ml-2">${escapeHtml(rsvp.player_email)}</span>
              </div>
              <span class="text-green-400 text-xs font-medium">PAID</span>
            </div>
          `
            )
            .join('')}
        </div>
      </div>
    `
      : '<p class="text-muted text-sm">No RSVPs yet.</p>';

  const statusControls =
    st === 'cancelled'
      ? `
    <div class="border-t border-surface-light mt-4 pt-4 space-y-2">
      <p class="text-sm text-red-300/90">This run is <strong>cancelled</strong> and hidden from the public signup page.</p>
      <button type="button" data-admin-action="set-status" data-session-id="${sessionPk}" data-status="open"
        class="text-xs bg-surface-light hover:bg-surface-lighter text-white px-3 py-2 rounded-lg transition-colors">
        Reopen as Open
      </button>
    </div>
  `
      : st === 'completed'
        ? `
    <div class="border-t border-surface-light mt-4 pt-4 space-y-2">
      <p class="text-sm text-zinc-300/90">This run is <strong>completed</strong> (date passed). It no longer accepts signups.</p>
      <button type="button" data-admin-action="set-status" data-session-id="${sessionPk}" data-status="open"
        class="text-xs bg-surface-light hover:bg-surface-lighter text-white px-3 py-2 rounded-lg transition-colors">
        Reopen as Open
      </button>
    </div>
  `
        : `
    <div class="border-t border-surface-light mt-4 pt-4 space-y-2">
      <p class="text-xs text-muted">Public signup shows this run as <strong class="text-white">Open</strong> until you cancel it or the run date passes.</p>
      <button type="button" data-admin-action="set-status" data-session-id="${sessionPk}" data-status="cancelled"
        class="text-xs px-3 py-1.5 rounded-lg transition-colors font-medium bg-surface-light text-red-300 hover:bg-red-900/40 border border-red-900/50">
        Cancel run
      </button>
    </div>
  `;

  const deleteBlock = `
    <div class="border-t border-surface-light mt-4 pt-4 flex justify-end">
      <button type="button" data-admin-action="delete-session" data-session-id="${sessionPk}" data-rsvp-count="${rsvps.length}"
        class="text-xs font-medium px-3 py-2 rounded-lg border border-red-900/60 text-red-300 hover:bg-red-950/50 transition-colors">
        Delete event
      </button>
    </div>
  `;

  card.innerHTML = `
    <div class="flex items-center justify-between mb-4">
      <div>
        <h3 class="font-semibold text-lg">${formatDate(session.date)}</h3>
        <p class="text-sm text-muted">${escapeHtml(session.time)} · ${escapeHtml(session.location)}</p>
      </div>
      <div class="flex items-center gap-2">
        <span class="px-2.5 py-1 rounded-full text-xs font-medium ${statusColors[st] || statusColors.open}">${st}</span>
        <span class="text-sm text-muted">${rsvps.length}/${session.max_players}</span>
      </div>
    </div>

    ${paymentsLockedNote}
    ${paymentsBlock}
    ${rsvpBlock}
    ${statusControls}
    ${deleteBlock}
  `;

  return card;
}

// Create session
createSessionForm.addEventListener('submit', async (e) => {
  e.preventDefault();

  const date = document.getElementById('new-session-date').value;
  const time = document.getElementById('new-session-time').value;
  const location = document.getElementById('new-session-location').value;
  const maxPlayers = parseInt(document.getElementById('new-session-max-players').value, 10);
  const priceDollars = parseInt(document.getElementById('new-session-price').value, 10);

  const { error } = await db.from('sessions').insert({
    date,
    time,
    location,
    max_players: maxPlayers,
    price_cents: priceDollars * 100,
    status: 'open',
  });

  if (error) {
    showToast('Failed to create session: ' + error.message, 'error');
    return;
  }

  showToast('Session created!');
  document.getElementById('new-session-date').value = getNextWednesday();
  document.getElementById('new-session-location').value = '';
  loadSessions();
});

// Update session status
async function updateSessionStatus(sessionId, status) {
  const { error } = await db
    .from('sessions')
    .update({ status })
    .eq('id', sessionId);

  if (error) {
    showToast('Failed to update session: ' + error.message, 'error');
    return;
  }

  const messages = {
    cancelled: 'Session cancelled',
    open: 'Session reopened as open',
    completed: 'Status set to completed',
  };
  showToast(messages[status] || `Status set to ${status}`);
  loadSessions();
}

// Permanently remove session + dependents (RPC: POW votes/polls, RSVPs). Does not refund Stripe.
async function deleteSession(sessionId, rsvpCount) {
  const id = String(sessionId).trim();
  const n = Number(rsvpCount) || 0;
  const msg =
    n > 0
      ? `Delete this event and remove ${n} paid RSVP record(s) from the database?\n\nStripe payments are not refunded automatically — handle refunds in the Stripe dashboard if needed.\n\nThis cannot be undone.`
      : 'Permanently delete this event? This cannot be undone.';

  if (!confirm(msg)) return;

  const { data, error } = await db.rpc('delete_session_admin', { p_session_id: id });

  if (error) {
    showToast('Failed to delete event: ' + error.message, 'error');
    await loadSessions();
    return;
  }
  const ok = !!(data && data.ok);
  if (!ok) {
    showToast(
      'Nothing was deleted — session missing or admin check failed (profiles.role must be admin for your account).',
      'error',
    );
    await loadSessions();
    return;
  }

  showToast('Event deleted');
  await loadSessions();
}

// Toggle payments open/closed (shock drop)
async function toggleDrop(sessionId, open) {
  const { error } = await db
    .from('sessions')
    .update({ payments_open: open })
    .eq('id', sessionId);

  if (error) {
    showToast('Failed to toggle payments: ' + error.message, 'error');
    return;
  }

  showToast(open ? 'PAYMENTS ARE LIVE!' : 'Payments locked', open ? 'success' : 'error');
  loadSessions();
}

function escapeHtml(str) {
  if (str == null) return '';
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// One delegated listener — avoids broken inline onclick (CSP / scope) and keeps logic in one place
sessionsList.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-admin-action]');
  if (!btn) return;

  const action = btn.getAttribute('data-admin-action');
  const sessionId = btn.getAttribute('data-session-id');
  if (!sessionId) return;

  if (action === 'toggle-drop') {
    const nextOpen = btn.getAttribute('data-next-open') === 'true';
    await toggleDrop(sessionId, nextOpen);
    return;
  }

  if (action === 'set-status') {
    const status = btn.getAttribute('data-status');
    if (!status) return;
    if (status === 'cancelled') {
      if (!confirm('Cancel this run for everyone? It will disappear from the public signup page.')) return;
    }
    await updateSessionStatus(sessionId, status);
    return;
  }

  if (action === 'delete-session') {
    const count = btn.getAttribute('data-rsvp-count') || '0';
    await deleteSession(sessionId, count);
  }
});

// Init
checkAuth();
