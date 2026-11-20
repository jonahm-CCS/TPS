import { config } from './cloud.js';

const icon = '<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 11.5a7.5 7.5 0 0 1-7.5 7.5H4l1.8-3.4A7.5 7.5 0 1 1 20 11.5Z"/><path d="M8 10h8m-8 4h5"/></svg>';
const allowedFiles = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf'];
const emojis = ['😀', '👍', '✅', '👀', '🙏', '⚠️', '🛠️', '📋', '📦', '🎉', '💪', '🔥'];
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[c]);
const nowInNorfolk = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
});

let context, dialog;
let workspaceEpoch = 0;
let conversations = [], canManage = false, selected = null, posts = [], historyFrom = null;
let search = '', pendingDraft, loading = false, error = '', mode = 'board';
let updateAfter = 0;
const $ = selector => dialog?.querySelector(selector);
const totalUnread = () => conversations.filter(c => !c.archived).reduce((total, chat) => total + chat.unread, 0);

export function boardButtonMarkup() {
  return `<button type="button" class="board-launch" data-board-open aria-label="Message Board" title="Message Board">${icon}<b data-board-count hidden></b></button>`;
}

export function boardNotificationMarkup() {
  return '<button type="button" class="board-inbox-link" data-board-open>Message Board <b data-board-count hidden></b></button>';
}

export function bindBoardTriggers(root = document) {
  root.querySelectorAll('[data-board-open]').forEach(button => { button.onclick = openBoard; });
  updateCounters();
}

function updateCounters() {
  const count = totalUnread();
  document.querySelectorAll('[data-board-open]').forEach(button => {
    button.classList.toggle('board-has-unread', count > 0);
    button.setAttribute('aria-label', count ? `Message Board, ${count} unread` : 'Message Board');
    const badge = button.querySelector('[data-board-count]');
    badge.hidden = !count;
    badge.textContent = count > 99 ? '99+' : count;
  });
}

export function mountMessageBoard(next) {
  if (context?.key !== next?.key) {
    closeBoard();
    workspaceEpoch++;
    mode = 'board';
    selected = null;
    posts = [];
    historyFrom = null;
    conversations = [];
    canManage = false;
    pendingDraft = null;
    loading = false;
    search = error = '';
  }
  context = next;
  bindBoardTriggers();
  if (next) refresh();
}

async function json(path, body) {
  const response = await fetch(config.url + path, {
    method: 'POST',
    headers: { apikey: config.key, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  const data = await response.json();
  if (!response.ok) {
    const failure = new Error(data.message || data.msg || 'Message Board request failed.');
    failure.status = response.status;
    throw failure;
  }
  return data;
}

async function boardRequest(action, args = {}) {
  const station = context, epoch = workspaceEpoch;
  if (!station) throw new Error('Open your TPS workspace to use Message Board.');
  const result = await json('/rest/v1/rpc/tps_message_board', {
    action, args: { ...args, badge: station.badge, number: station.number },
  });
  if (epoch !== workspaceEpoch) throw new Error('The TPS workspace changed.');
  return result;
}

function openBoard() {
  if (!context) return;
  if (!dialog) {
    dialog = document.createElement('dialog');
    dialog.id = 'message-board';
    dialog.setAttribute('aria-labelledby', 'board-title');
    document.body.append(dialog);
    dialog.addEventListener('close', () => { selected = null; posts = []; historyFrom = null; mode = 'board'; });
  }
  if (!dialog.open) dialog.showModal();
  render();
  refresh();
}

function closeBoard() { if (dialog?.open) dialog.close(); }

function render() {
  if (!dialog?.open) return;
  dialog.innerHTML = `<header class="board-top"><div>${icon}<h2 id="board-title">Message Board</h2></div>
    <button type="button" id="board-close" aria-label="Close Message Board">×</button></header>
    <div id="board-error" role="status">${escape(error)}</div><div id="board-content"></div>`;
  $('#board-close').onclick = closeBoard;
  if (mode === 'create') renderCreate(); else renderLayout();
}

function showError(message) {
  error = message;
  if ($('#board-error')) $('#board-error').textContent = message;
}

function audienceLabel(chat) {
  if (chat.audience === 'all') return 'All production areas';
  if (chat.audience === 'areas') return chat.targets.length + ' production area' + (chat.targets.length === 1 ? '' : 's');
  return chat.targets.length === 1 ? '1 selected employee' : chat.targets.length + ' selected employees';
}

function renderLayout() {
  $('#board-content').innerHTML = `<div class="board-layout">
    <aside class="board-sidebar"><div class="board-sidebar-head"><strong id="board-total"></strong>
    ${canManage ? '<button class="primary" id="board-new">+ New Chat</button>' : ''}</div>
    <label class="board-search-label">Search conversations<input type="search" id="board-search" placeholder="Find a conversation" value="${escape(search)}"></label>
    <div id="board-conversations"></div></aside><section id="board-thread" aria-label="Conversation"></section></div>`;
  $('#board-new')?.addEventListener('click', () => { mode = 'create'; showError(''); renderCreate(); });
  $('#board-search').oninput = event => { search = event.target.value; renderConversations(); };
  renderConversations();
  renderThread();
}

function renderConversations() {
  const root = $('#board-conversations');
  if (!root) return;
  $('#board-total').textContent = totalUnread() + ' unread';
  const query = search.trim().toLowerCase();
  const visible = conversations.filter(chat => (chat.title + ' ' + audienceLabel(chat)).toLowerCase().includes(query));
  root.innerHTML = visible.map(chat => `<button class="board-chat" data-chat="${chat.id}" aria-pressed="${chat.id === selected}">
    <span><strong>${escape(chat.title)}</strong><small>${escape(audienceLabel(chat))}${chat.archived ? ' · Archived' : ''}</small></span>
    ${chat.unread && !chat.archived ? `<b>${chat.unread}</b>` : ''}</button>`).join('')
    || '<p class="board-empty">No conversations found.</p>';
  root.querySelectorAll('[data-chat]').forEach(button => { button.onclick = () => selectChat(button.dataset.chat); });
}

async function selectChat(id) {
  if (id === selected) return;
  selected = id; posts = []; historyFrom = null; pendingDraft = null;
  showError('');
  renderConversations();
  renderThread();
  await refresh();
}

function renderThread() {
  const thread = $('#board-thread');
  if (!thread) return;
  const chat = conversations.find(entry => entry.id === selected);
  if (!chat) {
    thread.innerHTML = '<p class="board-empty">Select a conversation to read and reply.</p>';
    return;
  }
  thread.innerHTML = `<div class="board-thread-head"><div><h3>${escape(chat.title)}</h3><small>${escape(audienceLabel(chat))}</small></div>
    ${chat.manageable ? `<button type="button" id="board-manage">Manage</button>` : ''}</div>
    <div id="board-posts" tabindex="0" aria-label="Message history"></div>
    ${chat.archived ? '<p class="board-empty">This conversation is archived.</p>' : `<form id="board-reply">
      <label for="board-text">Message</label><textarea id="board-text" rows="2" maxlength="4000" placeholder="Type a message…"></textarea>
      <details class="board-emoji"><summary aria-label="Choose an emoji">😀 Emoji</summary><div>
      ${emojis.map(glyph => `<button type="button" data-emoji="${glyph}">${glyph}</button>`).join('')}</div></details>
      <div class="board-reply-options"><label>Photo or PDF <input type="file" id="board-file" accept="${allowedFiles.join(',')}"></label>
      <label>Job reference <input type="text" id="board-job" maxlength="60" placeholder="Job number"></label>
      <button class="primary" type="submit">Send</button></div>
    </form>`}`;
  $('#board-manage')?.addEventListener('click', () => renderManage(chat));
  $('#board-reply')?.addEventListener('submit', sendPost);
  dialog.querySelectorAll('[data-emoji]').forEach(button => {
    button.onclick = () => {
      const text = $('#board-text');
      if (text.value.length + button.dataset.emoji.length <= text.maxLength) {
        text.setRangeText(button.dataset.emoji, text.selectionStart, text.selectionEnd, 'end');
      }
      text.focus();
      button.closest('details').open = false;
    };
  });
  renderPosts(true);
}

function renderPosts(toEnd = false, prepend = false) {
  const root = $('#board-posts');
  if (!root) return;
  const priorHeight = root.scrollHeight, priorTop = root.scrollTop;
  const nearEnd = priorHeight - priorTop - root.clientHeight < 72;
  root.innerHTML = (posts.length >= 60 && historyFrom !== false ? '<button type="button" id="board-older">Load older messages</button>' : '')
    + (posts.map(post => `<article class="board-post${post.mine ? ' board-own-post' : ''}">
      <div><strong>${escape(post.sender)}</strong><time datetime="${escape(post.sent_at)}">${escape(nowInNorfolk.format(new Date(post.sent_at)))} ET</time></div>
      ${post.body ? `<p>${escape(post.body)}</p>` : ''}
      ${post.job_id ? `<span class="board-job-ref">Job #${escape(post.job_id)}</span>` : ''}
      ${post.attachment ? `<button type="button" data-board-file="${post.id}">Download ${escape(post.attachment.name)}</button>` : ''}
    </article>`).join('') || '<p class="board-empty">No messages yet.</p>');
  if (prepend) root.scrollTop = priorTop + root.scrollHeight - priorHeight;
  else if (nearEnd || toEnd) root.scrollTop = root.scrollHeight;
  $('#board-older')?.addEventListener('click', loadOlder);
  root.querySelectorAll('[data-board-file]').forEach(button => { button.onclick = () => downloadAttachment(button.dataset.boardFile); });
}

async function loadOlder(event) {
  const chat = selected;
  const before = posts[0]?.id;
  if (!before) return;
  event.currentTarget.disabled = true;
  try {
    const older = await boardRequest('history', { chat, before });
    if (selected !== chat) return;
    posts = [...new Map([...older, ...posts].map(post => [post.id, post])).values()];
    historyFrom = older.length === 60 ? older[0].id : false;
    renderPosts(false, true);
  } catch (failure) {
    if (selected === chat) showError(failure.message);
  } finally { event.currentTarget.disabled = false; }
}

async function downloadAttachment(post) {
  const chat = selected;
  try {
    const file = await boardRequest('attachment', { chat, post });
    if (!file || selected !== chat) return;
    const bytes = Uint8Array.from(atob(file.data), character => character.charCodeAt(0));
    const url = URL.createObjectURL(new Blob([bytes], { type: file.type }));
    const link = document.createElement('a');
    link.href = url;
    link.download = file.name;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  } catch (failure) {
    if (selected === chat) showError(failure.message);
  }
}

function fileData(file) {
  if (!file) return Promise.resolve(null);
  if (!allowedFiles.includes(file.type) || file.size > 5 * 1024 * 1024) {
    return Promise.reject(new Error('Choose a photo or PDF up to 5 MB.'));
  }
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve({ name: file.name, type: file.type, data: reader.result.split(',')[1] });
    reader.onerror = () => reject(new Error('Could not read the attachment.'));
    reader.readAsDataURL(file);
  });
}

async function sendPost(event) {
  event.preventDefault();
  const form = event.currentTarget, button = form.querySelector('[type=submit]');
  const chat = selected, text = $('#board-text'), job = $('#board-job'), input = $('#board-file');
  const draft = { chat, body: text.value.trim(), job: job.value.trim().replace(/^#/, ''), file: input.files[0] };
  if (!draft.body && !draft.job && !draft.file) return;
  if (!pendingDraft || Object.keys(draft).some(k => pendingDraft[k] !== draft[k])) {
    pendingDraft = { ...draft, key: crypto.randomUUID() };
  }
  const key = pendingDraft.key;
  button.disabled = true;
  try {
    const file = await fileData(draft.file);
    if (selected !== chat || !form.isConnected) return;
    await boardRequest('send', { ...draft, file, key });
    if (selected !== chat || !form.isConnected) return;
    if (text.value.trim() === draft.body) text.value = '';
    if (job.value.trim().replace(/^#/, '') === draft.job) job.value = '';
    if (input.files[0] === draft.file) input.value = '';
    pendingDraft = null;
    showError('');
    await refresh();
  } catch (failure) {
    if (selected === chat) showError(failure.message);
  } finally { button.disabled = false; }
}

function renderCreate() {
  $('#board-content').innerHTML = `<form id="board-create">
    <h3>Create New Chat</h3>
    <label>Conversation name<input name="title" maxlength="100" required></label>
    <label>Who should participate?<select name="audience">
      <option value="all">All production areas</option><option value="areas">Selected production areas</option>
      <option value="employees">Individual or selected employees</option>
    </select></label>
    <fieldset id="board-targets" hidden><legend id="board-target-label"></legend>
      <label>Search<input id="board-target-search" type="search"></label><div id="board-target-options"></div>
    </fieldset>
    <div class="board-actions"><button type="button" id="board-cancel">Cancel</button>
    <button type="submit" class="primary">Create chat</button></div>
  </form>`;
  const form = $('#board-create'), checked = new Set();
  const update = () => {
    const audience = form.elements.audience.value;
    $('#board-targets').hidden = audience === 'all';
    if (audience === 'all') return;
    const isArea = audience === 'areas';
    $('#board-target-label').textContent = isArea ? 'Select production areas' : 'Select employees';
    const query = $('#board-target-search').value.trim().toLowerCase();
    const records = isArea ? context.areas : context.employees;
    $('#board-target-options').innerHTML = records.filter(record => record.name.toLowerCase().includes(query))
      .map(record => `<label><input type="checkbox" value="${escape(record.id)}" ${checked.has(record.id) ? 'checked' : ''}> ${escape(record.name)}</label>`).join('');
  };
  form.elements.audience.onchange = () => { checked.clear(); $('#board-target-search').value = ''; update(); };
  $('#board-target-search').oninput = update;
  $('#board-target-options').onchange = event => {
    if (event.target.checked) checked.add(event.target.value); else checked.delete(event.target.value);
  };
  $('#board-cancel').onclick = () => { mode = 'board'; showError(''); renderLayout(); };
  form.onsubmit = async event => {
    event.preventDefault();
    const button = form.querySelector('[type=submit]');
    if (form.elements.audience.value !== 'all' && !checked.size) {
      showError('Select at least one recipient.'); return;
    }
    button.disabled = true;
    try {
      const created = await boardRequest('create', { title: form.elements.title.value,
        audience: form.elements.audience.value, targets: [...checked] });
      if (!form.isConnected || !dialog.open) return;
      await loadConversations();
      mode = 'board'; selected = created.id; posts = []; search = '';
      showError(''); renderLayout();
      await refresh();
    } catch (failure) { if (form.isConnected) showError(failure.message); }
    finally { button.disabled = false; }
  };
  update();
  form.elements.title.focus();
}

function renderManage(chat) {
  const root = $('#board-thread');
  root.innerHTML = `<form id="board-edit"><h3>Manage conversation</h3>
    <label>Conversation name<input name="title" value="${escape(chat.title)}" maxlength="100" required></label>
    <div class="board-actions"><button type="button" id="board-edit-cancel">Cancel</button>
    <button type="button" id="board-archive">${chat.archived ? 'Restore' : 'Archive'}</button>
    <button type="submit" class="primary">Save name</button></div></form>`;
  const form = $('#board-edit');
  const save = async action => {
    const buttons = form.querySelectorAll('button');
    buttons.forEach(button => { button.disabled = true; });
    try {
      await boardRequest(action, { chat: chat.id, title: form.elements.title.value });
      if (!form.isConnected || selected !== chat.id) return;
      await loadConversations();
      showError(''); renderLayout(); await refresh();
    } catch (failure) { if (form.isConnected) showError(failure.message); }
    finally { buttons.forEach(button => { button.disabled = false; }); }
  };
  $('#board-edit-cancel').onclick = renderThread;
  $('#board-archive').onclick = () => save(chat.archived ? 'restore' : 'archive');
  form.onsubmit = event => { event.preventDefault(); save('rename'); };
  form.elements.title.focus();
}

async function loadConversations() {
  const origin = context?.key, epoch = workspaceEpoch;
  const data = await boardRequest('list');
  if (context?.key !== origin || epoch !== workspaceEpoch) return false;
  const roleChanged = canManage !== data.manage;
  if (JSON.stringify(conversations) !== JSON.stringify(data.conversations)) {
    conversations = data.conversations;
    updateCounters();
    renderConversations();
  }
  canManage = data.manage;
  if (roleChanged && dialog?.open && mode==='board' && $('#board-content')) renderLayout();
  return true;
}

async function refresh() {
  if (!context || loading || document.hidden) return;
  const origin = context?.key, epoch = workspaceEpoch;
  loading = true;
  try {
    if (!await loadConversations() || !dialog?.open || mode !== 'board') return;
    const chat = selected;
    if (!chat) return;
    if (!conversations.some(c => c.id === chat)) {
      selected = null; posts = []; renderLayout(); return;
    }
    const current = await boardRequest('history', { chat });
    if (selected !== chat || !dialog.open || context?.key !== origin || epoch !== workspaceEpoch) return;
    const next = [...new Map([...posts.filter(post => !current.length || post.id < current[0].id), ...current]
      .map(post => [post.id, post])).values()];
    if (JSON.stringify(next) !== JSON.stringify(posts)) {
      posts = next;
      renderPosts();
    }
    const summary = conversations.find(c => c.id === chat);
    if (current.length && summary?.unread && !document.hidden && $('#board-posts')) {
      await boardRequest('read', { chat, through: current.at(-1).id });
      await loadConversations();
    }
  } catch (failure) {
    if (context?.key === origin && dialog?.open) showError(failure.message);
  } finally { if (workspaceEpoch === epoch) loading = false; }
}

setInterval(() => {
  if (Date.now() < updateAfter) return;
  updateAfter = Date.now() + (dialog?.open ? 0 : 6000);
  refresh();
}, 3000);
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
