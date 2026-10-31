// Staff panel for the "आपका अच्छा समय" lead funnel.
//
// Plain browser JavaScript, no build step. Talks to Supabase with the public
// anon key plus the signed-in staff member's session; what each person can
// see and change is enforced by row-level security and the SECURITY DEFINER
// functions in supabase/migrations, not here. The role checks below only
// decide which buttons to show.
//
// Everything that came from a visitor or a staff member is rendered with
// textContent (through h() below), never as HTML.
(function () {
  'use strict';

  const CFG = window.KS_CONFIG || {};
  const PAGE_SIZE = 25;
  const EXPORT_CAP = 20000;
  const ROLE_RANK = { caller: 1, manager: 2, owner: 3 };
  const ROLE_LABEL = { owner: ['मालिक', 'Owner'], manager: ['मैनेजर', 'Manager'], caller: ['कॉलर', 'Caller'] };
  const STATUS = {
    new: ['नया', 'New'],
    contacted: ['संपर्क हुआ', 'Contacted'],
    interested: ['रुचि है', 'Interested'],
    paid: ['भुगतान हुआ', 'Paid'],
    not_interested: ['रुचि नहीं', 'Not interested'],
    invalid: ['गलत/अमान्य', 'Invalid'],
  };
  const EVENTS = {
    basis_open: ['"किस आधार पर" खोला', 'Opened the basis'],
    pdf_download: ['PDF डाउनलोड की', 'Downloaded the PDF'],
    whatsapp_click: ['WhatsApp बटन दबाया', 'Tapped WhatsApp'],
    upi_click: ['₹199 UPI बटन दबाया', 'Tapped UPI pay'],
    call_click: ['कॉल बटन दबाया', 'Tapped call'],
  };
  const KINDS = {
    note: ['नोट', 'Note'], status: ['स्टेटस', 'Status'], call: ['कॉल', 'Call'],
    payment: ['भुगतान', 'Payment'], assign: ['असाइन', 'Assignment'],
  };
  // Error codes raised by the database functions and manage-staff.
  const ERRORS = {
    not_staff: 'आप सक्रिय स्टाफ़ नहीं हैं / not active staff',
    forbidden: 'इसकी अनुमति नहीं है / not allowed for your role',
    lead_not_found: 'लीड नहीं मिली या आपकी पहुँच में नहीं / lead not found or not yours',
    already_assigned: 'यह लीड किसी और की हो चुकी है / already taken by someone else',
    bad_amount: 'राशि सही नहीं / invalid amount',
    empty_note: 'नोट खाली है / the note is empty',
    note_too_long: 'नोट बहुत लंबा है / note too long',
    no_such_staff: 'यह स्टाफ़ सक्रिय नहीं है / no such active staff',
    last_owner: 'कम से कम एक मालिक रहना चाहिए / at least one owner must remain',
    self: 'अपना खाता खुद बंद नहीं कर सकते / you cannot switch yourself off',
    already_staff: 'यह व्यक्ति पहले से स्टाफ़ में है / already staff',
    invite_failed: 'ईमेल निमंत्रण नहीं गया / invite email failed — try the temporary password',
    create_failed: 'खाता नहीं बना / could not create the account',
    'Invalid login credentials': 'ईमेल या पासवर्ड गलत है / wrong email or password',
  };

  let sb = null;          // the Supabase client
  let me = null;          // { user_id, name, role, active, email }
  let staffById = new Map();
  const filters = { q: '', status: '', src: '', from: '', to: '', scope: '' };
  let page = 0;

  // -------------------------------------------------------------------------
  // DOM helpers

  /** Element builder: attributes are set as attributes, children as text. */
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (k === 'value') el.value = v;
      else el.setAttribute(k, v === true ? '' : String(v));
    }
    el.append(...kids.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false)
      .map((c) => (c instanceof Node ? c : String(c))));
    return el;
  }
  /** Hindi label with the English in small text. */
  const bi = (pair) => [pair[0], ' ', h('small', null, pair[1])];
  const $ = (sel, root) => (root || document).querySelector(sel);
  const view = () => $('#view');

  function show(name) {
    document.querySelectorAll('[data-screen]').forEach((s) => { s.hidden = s.dataset.screen !== name; });
  }

  let toastTimer = 0;
  function toast(msg, isError) {
    const t = $('#toast');
    t.textContent = msg;
    t.className = 'toast' + (isError ? ' err' : '');
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.hidden = true; }, isError ? 6000 : 3000);
  }

  function errText(e) {
    const msg = (e && (e.message || e.error_description || e.error)) || String(e);
    for (const [k, v] of Object.entries(ERRORS)) if (msg.includes(k)) return v;
    return 'कुछ गड़बड़ हुई / something went wrong: ' + msg;
  }
  const fail = (e) => toast(errText(e), true);

  /** Runs an async action with the button disabled, toasting errors. */
  async function busy(btn, fn) {
    if (btn) btn.disabled = true;
    try { return await fn(); } catch (e) { fail(e); } finally { if (btn) btn.disabled = false; }
  }

  // -------------------------------------------------------------------------
  // Formatting

  const dtFmt = new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata', day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit',
  });
  const fmtDT = (ts) => (ts ? dtFmt.format(new Date(ts)) : '—');
  const inr = (n) => '₹' + Number(n || 0).toLocaleString('en-IN');
  const pct = (a, b) => (b ? Math.round((a / b) * 1000) / 10 + '%' : '—');
  const digits = (s) => String(s || '').replace(/\D/g, '');
  const staffName = (id) => (id ? (staffById.get(id) || {}).name || '?' : null);

  /** YYYY-MM-DD in IST, `daysAgo` days back. */
  function istDate(daysAgo) {
    return new Date(Date.now() + 330 * 60000 - (daysAgo || 0) * 86400000).toISOString().slice(0, 10);
  }
  const istStart = (ymd) => ymd + 'T00:00:00+05:30';
  function nextDay(ymd) {
    const d = new Date(ymd + 'T00:00:00Z');
    d.setUTCDate(d.getUTCDate() + 1);
    return d.toISOString().slice(0, 10);
  }

  function badge(status) {
    return h('span', { class: 'badge ' + status }, (STATUS[status] || [status])[0]);
  }

  /** A short "Android · Chrome" for the user agent; the full string is shown too. */
  function browserOf(ua) {
    if (!ua) return '—';
    const os = /Android/.test(ua) ? 'Android' : /iPhone|iPad|iOS/.test(ua) ? 'iPhone/iPad'
      : /Windows/.test(ua) ? 'Windows' : /Mac OS X/.test(ua) ? 'Mac' : /Linux/.test(ua) ? 'Linux' : '?';
    const br = /SamsungBrowser/.test(ua) ? 'Samsung Internet' : /Edg\//.test(ua) ? 'Edge'
      : /OPR\//.test(ua) ? 'Opera' : /FBAN|FBAV|Instagram/.test(ua) ? 'Facebook/Instagram app'
      : /CriOS|Chrome\//.test(ua) ? 'Chrome' : /FxiOS|Firefox\//.test(ua) ? 'Firefox'
      : /Safari\//.test(ua) ? 'Safari' : '?';
    return os + ' · ' + br;
  }

  // -------------------------------------------------------------------------
  // Boot and auth

  async function boot() {
    if (!CFG.supabaseUrl || !CFG.supabaseAnonKey) return show('noconfig');
    if (!window.supabase || !window.supabase.createClient) return show('nolib');

    // Invite and recovery links land here with the token in the hash; the
    // client reads it, and the person should then choose a password.
    const wantsPassword = /type=(invite|recovery)/.test(location.hash);
    sb = window.supabase.createClient(CFG.supabaseUrl, CFG.supabaseAnonKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'implicit' },
    });
    sb.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') show('setpw');
      if (event === 'SIGNED_OUT') { me = null; show('login'); }
    });
    wireStaticForms();

    const { data } = await sb.auth.getSession();
    if (!data.session) return show('login');
    await enter(data.session, wantsPassword);
  }

  async function enter(session, wantsPassword) {
    const { data, error } = await sb.from('staff').select('user_id, name, role, active')
      .eq('user_id', session.user.id).maybeSingle();
    if (error || !data || !data.active) return show('notstaff');
    me = Object.assign({}, data, { email: session.user.email });
    await loadStaff();
    $('#who').replaceChildren(me.name, h('br'), h('small', null, ROLE_LABEL[me.role].join(' · ')));
    document.querySelectorAll('#tabs [data-min-role]').forEach((a) => {
      a.hidden = !atLeast(a.dataset.minRole);
    });
    if (wantsPassword) return show('setpw');
    show('app');
    if (!location.hash.startsWith('#/')) location.hash = '#/leads';
    else route();
  }

  const atLeast = (role) => me && ROLE_RANK[me.role] >= ROLE_RANK[role];

  async function loadStaff() {
    const { data } = await sb.from('staff').select('user_id, name, role, active').order('name');
    staffById = new Map((data || []).map((s) => [s.user_id, s]));
  }

  function wireStaticForms() {
    document.querySelectorAll('[data-go]').forEach((a) => a.addEventListener('click', (ev) => {
      ev.preventDefault();
      const to = a.dataset.go;
      if (to === 'app') { if (me) { show('app'); route(); } else show('login'); } else show(to);
    }));
    document.querySelectorAll('[data-action="signout"]').forEach((b) => b.addEventListener('click', signOut));

    $('#login-form').addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const f = ev.target;
      const err = $('.error', f);
      err.hidden = true;
      await busy($('button', f), async () => {
        const { data, error } = await sb.auth.signInWithPassword({
          email: f.email.value.trim(), password: f.password.value,
        });
        if (error) { err.textContent = errText(error); err.hidden = false; return; }
        f.password.value = '';
        await enter(data.session, false);
      });
    });

    $('#forgot-form').addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const f = ev.target;
      await busy($('button', f), async () => {
        const { error } = await sb.auth.resetPasswordForEmail(f.email.value.trim(), {
          redirectTo: location.origin + location.pathname,
        });
        const ok = $('.ok', f);
        const err = $('.error', f);
        // The same answer whether or not the address is registered.
        if (error && !/rate|limit/i.test(error.message)) { err.textContent = errText(error); err.hidden = false; return; }
        err.hidden = true;
        ok.textContent = error ? 'बहुत बार कोशिश हुई, थोड़ी देर बाद करें / too many tries, wait a while'
          : 'अगर यह ईमेल रजिस्टर्ड है तो रीसेट लिंक भेज दिया गया है / if registered, a link is on its way';
        ok.hidden = false;
      });
    });

    $('#setpw-form').addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const f = ev.target;
      const err = $('.error', f);
      if (f.password.value.length < 10) { err.textContent = 'कम से कम 10 अक्षर / at least 10 characters'; err.hidden = false; return; }
      if (f.password.value !== f.password2.value) { err.textContent = 'दोनों पासवर्ड एक जैसे नहीं / passwords differ'; err.hidden = false; return; }
      err.hidden = true;
      await busy($('button', f), async () => {
        const { error } = await sb.auth.updateUser({ password: f.password.value });
        if (error) { err.textContent = errText(error); err.hidden = false; return; }
        f.reset();
        toast('पासवर्ड बदल गया / password saved');
        const { data } = await sb.auth.getSession();
        if (data.session) await enter(data.session, false); else show('login');
      });
    });
  }

  async function signOut() {
    await sb.auth.signOut();
    me = null;
    history.replaceState(null, '', location.pathname);
    show('login');
  }

  // -------------------------------------------------------------------------
  // Router

  function route() {
    if (!me) return;
    const hash = location.hash;
    let tab = 'leads';
    const m = /^#\/lead\/([0-9a-f-]{36})$/i.exec(hash);
    if (m) viewLead(m[1]);
    else if (hash === '#/dashboard' && atLeast('manager')) { tab = 'dashboard'; viewDashboard(); }
    else if (hash === '#/staff' && atLeast('owner')) { tab = 'staff'; viewStaff(); }
    else if (hash === '#/account') { tab = 'account'; viewAccount(); }
    else viewLeads();
    document.querySelectorAll('#tabs a').forEach((a) => a.classList.toggle('active', a.dataset.tab === tab));
    window.scrollTo(0, 0);
  }
  window.addEventListener('hashchange', route);

  // -------------------------------------------------------------------------
  // Leads list

  const LIST_COLS = 'id, code, created_at, name, phone, status, src, assigned_to, amount_paid, place_name';

  /** Applies the current filters to a PostgREST query on leads. */
  function applyFilters(qb) {
    // Characters that mean something in PostgREST's or=() syntax are dropped.
    const s = filters.q.replace(/[,()"\\*%:]/g, ' ').trim();
    if (s) {
      const parts = [`name.ilike.*${s}*`, `code.ilike.*${s}*`];
      let d = digits(s);
      if (d.length > 10) d = d.slice(-10);
      if (d.length >= 3) parts.push(`phone.like.*${d}*`);
      qb = qb.or(parts.join(','));
    }
    if (filters.status) qb = qb.eq('status', filters.status);
    if (filters.src) qb = qb.eq('src', filters.src);
    if (filters.from) qb = qb.gte('created_at', istStart(filters.from));
    if (filters.to) qb = qb.lt('created_at', istStart(nextDay(filters.to)));
    if (filters.scope === 'mine') qb = qb.eq('assigned_to', me.user_id);
    if (filters.scope === 'unassigned') qb = qb.is('assigned_to', null);
    return qb;
  }

  function viewLeads() {
    const list = h('div', null, h('p', { class: 'muted' }, 'लोड हो रहा है…'));
    let debounce = 0;
    const set = (k) => (ev) => {
      filters[k] = ev.target.value;
      page = 0;
      clearTimeout(debounce);
      debounce = setTimeout(() => loadList(list), k === 'q' ? 350 : 0);
    };
    const opt = (v, pair, cur) => h('option', { value: v, selected: v === cur }, pair[0] + ' / ' + pair[1]);

    const form = h('form', { class: 'panel', onsubmit: (ev) => ev.preventDefault() },
      h('div', { class: 'filters' },
        h('label', { class: 'wide' }, 'खोजें ', h('small', null, 'Search name / phone / code'),
          h('input', { type: 'search', value: filters.q, placeholder: 'राम / 98765 / KS-4821', oninput: set('q') })),
        h('label', null, 'स्टेटस ', h('small', null, 'Status'),
          h('select', { onchange: set('status') }, opt('', ['सभी', 'All'], filters.status),
            Object.entries(STATUS).map(([k, v]) => opt(k, v, filters.status)))),
        h('label', null, 'किसकी ', h('small', null, 'Whose'),
          h('select', { onchange: set('scope') },
            opt('', ['सभी', 'All'], filters.scope), opt('mine', ['मेरी', 'Mine'], filters.scope),
            opt('unassigned', ['किसी की नहीं', 'Unassigned'], filters.scope))),
      ),
      h('details', { class: 'more', open: !!(filters.src || filters.from || filters.to) },
        h('summary', null, 'और फ़िल्टर ', h('small', null, 'More filters')),
        h('div', { class: 'filters' },
          h('label', { class: 'wide' }, 'स्रोत (फ़्लायर कोड) ', h('small', null, 'Source / src'),
            h('input', { type: 'text', value: filters.src, list: 'src-list', placeholder: 'temple-hanuman-sec14', onchange: set('src') }),
            h('datalist', { id: 'src-list' })),
          h('label', null, 'से ', h('small', null, 'From'), h('input', { type: 'date', value: filters.from, onchange: set('from') })),
          h('label', null, 'तक ', h('small', null, 'To'), h('input', { type: 'date', value: filters.to, onchange: set('to') })),
        ),
        h('p', null, h('button', {
          type: 'button', class: 'btn',
          onclick: () => { Object.keys(filters).forEach((k) => { filters[k] = ''; }); page = 0; viewLeads(); },
        }, 'फ़िल्टर हटाएँ ', h('small', null, 'Clear'))),
      ),
      atLeast('manager') ? h('button', {
        type: 'button', class: 'btn block', onclick: (ev) => exportCsv(ev.currentTarget),
      }, 'CSV डाउनलोड ', h('small', null, 'Export these leads')) : null,
    );
    view().replaceChildren(form, list);
    loadList(list);
    if (atLeast('manager')) fillSrcList();
  }

  // Known sources for the src filter, from the last 90 days of stats.
  async function fillSrcList() {
    const { data } = await sb.rpc('lead_stats', {
      from_ts: istStart(istDate(90)), to_ts: new Date(Date.now() + 60000).toISOString(),
    });
    const dl = $('#src-list');
    if (!data || !dl) return;
    dl.replaceChildren(...data.by_src.filter((r) => r.src !== '(none)').map((r) => h('option', { value: r.src })));
  }

  async function loadList(container) {
    const from = page * PAGE_SIZE;
    const { data, count, error } = await applyFilters(sb.from('leads').select(LIST_COLS, { count: 'exact' }))
      .order('created_at', { ascending: false }).range(from, from + PAGE_SIZE - 1);
    if (error) { container.replaceChildren(h('p', { class: 'error' }, errText(error))); return; }
    if (!data.length) {
      container.replaceChildren(h('p', { class: 'muted center-text' }, 'कोई लीड नहीं मिली ', h('small', null, 'No leads match')));
      return;
    }
    const cards = h('ul', { class: 'cards' }, data.map((l) => h('li', null,
      h('a', { class: 'card', href: '#/lead/' + l.id },
        h('div', { class: 'row1' }, h('span', { class: 'name' }, l.name || '—'), badge(l.status)),
        h('div', { class: 'meta' },
          h('span', null, l.code), h('span', null, l.phone || ''), h('span', null, fmtDT(l.created_at))),
        h('div', { class: 'meta' },
          l.src ? h('span', null, '📍 ' + l.src) : null,
          h('span', null, l.assigned_to ? '👤 ' + staffName(l.assigned_to) : 'किसी की नहीं / unassigned'),
          l.amount_paid > 0 ? h('span', null, inr(l.amount_paid)) : null),
      ))));
    const total = count || 0;
    const pager = h('div', { class: 'pager' },
      h('button', { class: 'btn', disabled: page === 0, onclick: () => { page--; loadList(container); window.scrollTo(0, 0); } }, '← पिछला'),
      h('span', { class: 'muted' }, `${from + 1}–${from + data.length} / ${total}`),
      h('button', { class: 'btn', disabled: from + data.length >= total, onclick: () => { page++; loadList(container); window.scrollTo(0, 0); } }, 'अगला →'));
    container.replaceChildren(cards, pager);
  }

  // -------------------------------------------------------------------------
  // CSV export (manager+)

  function csvCell(v) {
    let s = v === null || v === undefined ? '' : String(v);
    // A cell starting with = + - @ is run as a formula by Excel and Sheets.
    if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
    return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }

  async function exportCsv(btn) {
    await busy(btn, async () => {
      const cols = 'code, created_at, name, phone, birth_date, birth_time, time_approx, place_name, lang, status, ' +
        'assigned_to, amount_paid, paid_at, src, utm_source, utm_medium, utm_campaign, kundli';
      const rows = [];
      for (let from = 0; from < EXPORT_CAP; from += 1000) {
        const { data, error } = await applyFilters(sb.from('leads').select(cols))
          .order('created_at', { ascending: false }).range(from, from + 999);
        if (error) throw error;
        rows.push(...data);
        if (data.length < 1000) break;
      }
      // Logged before the file exists: no log, no export.
      const { error: logErr } = await sb.rpc('log_export', { row_count: rows.length, filters: Object.assign({}, filters) });
      if (logErr) throw logErr;

      const head = ['code', 'created_at_ist', 'name', 'phone', 'birth_date', 'birth_time', 'time_approx', 'place',
        'lang', 'status', 'assigned_to', 'amount_paid', 'paid_at_ist', 'src', 'utm_source', 'utm_medium',
        'utm_campaign', 'rashi', 'lagna', 'nakshatra'];
      const lines = [head.join(',')];
      for (const r of rows) {
        const k = r.kundli || {};
        lines.push([r.code, fmtDT(r.created_at), r.name, r.phone, r.birth_date, r.birth_time, r.time_approx,
          r.place_name, r.lang, r.status, staffName(r.assigned_to), r.amount_paid, r.paid_at ? fmtDT(r.paid_at) : '',
          r.src, r.utm_source, r.utm_medium, r.utm_campaign, k.rashi, k.lagna, k.nakshatra].map(csvCell).join(','));
      }
      // The BOM makes Excel read the Devanagari as UTF-8.
      const blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
      const a = h('a', { href: URL.createObjectURL(blob), download: `kundlisaar-leads-${istDate(0)}.csv` });
      document.body.append(a);
      a.click();
      setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
      toast(`${rows.length} लीड्स डाउनलोड (लॉग हुआ) / exported and logged`);
    });
  }

  // -------------------------------------------------------------------------
  // Lead detail

  async function viewLead(id) {
    view().replaceChildren(h('p', { class: 'muted' }, 'लोड हो रहा है…'));
    const [leadRes, evRes, actRes] = await Promise.all([
      sb.from('leads').select('*').eq('id', id).maybeSingle(),
      sb.from('lead_events').select('event, created_at, ip, user_agent').eq('lead_id', id)
        .order('created_at', { ascending: false }).limit(200),
      sb.from('lead_activity').select('kind, text, actor, created_at').eq('lead_id', id)
        .order('created_at', { ascending: false }).limit(200),
    ]);
    const back = h('p', null, h('a', { href: '#/leads' }, '← लीड्स ', h('small', null, 'Back to leads')));
    const lead = leadRes.data;
    if (leadRes.error || !lead) {
      view().replaceChildren(back, h('p', { class: 'error' }, ERRORS.lead_not_found));
      return;
    }
    const reload = () => viewLead(id);
    const rpc = async (btn, name, args, okMsg) => busy(btn, async () => {
      const { error } = await sb.rpc(name, Object.assign({ lead: id }, args));
      if (error) throw error;
      toast(okMsg);
      reload();
    });

    // Header and the main actions
    const phone = digits(lead.phone);
    const CFG = window.KS_CONFIG || {};
    const price = CFG.passwordPrice || 199;
    const upi = CFG.upiId || 'pallavsharma353-1@okaxis';
    const waText = `नमस्ते ${lead.name || ''} जी, कुंडलीसार की ओर से नमस्कार। आपकी कुंडली (कोड ${lead.code}) ` +
      `का PDF पासवर्ड ₹${price} में मिलता है। UPI ID ${upi} पर ₹${price} भेजकर स्क्रीनशॉट यहीं भेज दीजिए, ` +
      'पासवर्ड तुरंत भेज दिया जाएगा। आपके अच्छे समय के बारे में कुछ पूछना हो तो बेझिझक लिखिए। धन्यवाद।';
    const secretBox = h('div');
    const mine = lead.assigned_to === me.user_id;

    const head = h('div', { class: 'panel' },
      h('div', { class: 'row1', style: 'display:flex;justify-content:space-between;gap:8px;align-items:baseline' },
        h('h2', { style: 'margin:0' }, lead.name || '—'), badge(lead.status)),
      h('p', { class: 'muted', style: 'margin:4px 0 12px' },
        h('strong', null, lead.code), ' · ', fmtDT(lead.created_at), ' · ',
        lead.assigned_to ? '👤 ' + staffName(lead.assigned_to) : 'किसी की नहीं / unassigned',
        lead.amount_paid > 0 ? ' · ' + inr(lead.amount_paid) : ''),
      h('div', { class: 'btnrow' },
        phone ? h('a', {
          class: 'btn primary', href: 'tel:+91' + phone,
          // The call itself happens in the phone app; this records the attempt.
          onclick: () => { sb.rpc('log_call', { lead: id, note: null }).then(() => setTimeout(reload, 800)); },
        }, '📞 कॉल ', h('small', null, 'Call')) : null,
        phone ? h('a', {
          class: 'btn haldi', target: '_blank', rel: 'noopener noreferrer',
          href: 'https://wa.me/91' + phone + '?text=' + encodeURIComponent(waText),
        }, 'WhatsApp') : null,
        h('button', {
          class: 'btn indigo', type: 'button', onclick: (ev) => busy(ev.currentTarget, async () => {
            const { data, error } = await sb.rpc('reveal_password', { lead: id });
            if (error) throw error;
            secretBox.replaceChildren(data
              ? h('div', { class: 'panel' },
                h('div', null, 'PDF पासवर्ड ', h('small', null, 'PDF password')),
                h('div', { class: 'secret' }, data),
                h('p', { class: 'muted', style: 'margin:4px 0 0' },
                  'यह देखना आपके नाम से लॉग हो गया है। ', h('small', null, 'This reveal was logged under your name.')))
              : h('p', { class: 'error' }, 'अनुमति नहीं — यह कोशिश भी लॉग हुई / not allowed; the attempt was logged'));
          }),
        }, '🔑 पासवर्ड ', h('small', null, 'Reveal')),
        !lead.assigned_to ? h('button', {
          class: 'btn', type: 'button',
          onclick: (ev) => rpc(ev.currentTarget, 'take_lead', {}, 'लीड आपकी हुई / lead is yours'),
        }, 'मैं लूँगा ', h('small', null, 'Take lead')) : mine ? h('span', { class: 'btn', style: 'border-style:dashed' }, 'आपकी लीड ', h('small', null, 'Yours')) : null,
      ),
      secretBox,
    );

    // Working the lead: status, note, payment, assignment, erasure
    const statusSel = h('select', null, Object.entries(STATUS).map(([k, v]) =>
      h('option', { value: k, selected: k === lead.status }, v[0] + ' / ' + v[1])));
    const statusNote = h('input', { type: 'text', maxlength: 2000, placeholder: 'छोटा नोट (वैकल्पिक) / optional note' });
    const noteBox = h('textarea', { maxlength: 2000, placeholder: 'क्या बात हुई? / What happened?' });
    const amount = h('input', { type: 'number', inputmode: 'numeric', min: 1, step: 1, placeholder: '₹' });
    const payNote = h('input', { type: 'text', maxlength: 2000, placeholder: 'किसलिए, कैसे (UPI…) / for what, how' });

    const work = h('div', { class: 'panel' },
      h('h3', null, ...bi(['काम', 'Work this lead'])),
      h('label', null, 'स्टेटस ', h('small', null, 'Status'), statusSel, statusNote),
      h('button', {
        class: 'btn block', type: 'button', onclick: (ev) => rpc(ev.currentTarget, 'set_lead_status',
          { new_status: statusSel.value, note: statusNote.value || null }, 'स्टेटस बदला / status saved'),
      }, 'स्टेटस सेव ', h('small', null, 'Save status')),
      h('hr', { style: 'border:0;border-top:1px solid var(--line);margin:16px 0' }),
      h('label', null, 'नोट ', h('small', null, 'Note'), noteBox),
      h('button', {
        class: 'btn block', type: 'button', onclick: (ev) => rpc(ev.currentTarget, 'add_note',
          { text: noteBox.value }, 'नोट जुड़ा / note added'),
      }, 'नोट जोड़ें ', h('small', null, 'Add note')),
      h('hr', { style: 'border:0;border-top:1px solid var(--line);margin:16px 0' }),
      h('label', null, 'भुगतान (रुपये) ', h('small', null, 'Payment in rupees'), amount, payNote),
      // The usual amounts, one tap each: the password, the report, a consultation.
      h('div', { class: 'quick-amounts', style: 'display:flex;gap:6px;flex-wrap:wrap;margin:-4px 0 10px' },
        [[199, 'पासवर्ड'], [299, 'रिपोर्ट'], [501, 'परामर्श'], [1100, 'विस्तृत परामर्श']].map(([n, what]) =>
          h('button', {
            class: 'btn', type: 'button', style: 'flex:1 1 auto;min-width:0',
            onclick: () => { amount.value = n; if (!payNote.value) payNote.value = what + ' (UPI)'; },
          }, `₹${n} `, h('small', null, what)))),
      h('button', {
        class: 'btn block', type: 'button', onclick: (ev) => {
          const n = parseInt(amount.value, 10);
          if (!(n > 0)) return toast(ERRORS.bad_amount, true);
          if (!confirm(`${inr(n)} का भुगतान दर्ज करें? / Record ${inr(n)}?`)) return;
          rpc(ev.currentTarget, 'record_payment', { amount: n, note: payNote.value || null }, 'भुगतान दर्ज / payment recorded');
        },
      }, 'भुगतान दर्ज करें ', h('small', null, 'Record payment')),
      atLeast('manager') ? assignBlock(lead, rpc) : null,
      atLeast('owner') ? h('div', null,
        h('hr', { style: 'border:0;border-top:1px solid var(--line);margin:16px 0' }),
        h('button', {
          class: 'btn danger block', type: 'button', onclick: (ev) => {
            const typed = prompt(`यह व्यक्ति की सारी निजी जानकारी हमेशा के लिए मिटा देगा (DPDP अनुरोध)।\n` +
              `This permanently erases their personal data.\nपुष्टि के लिए कोड टाइप करें / type the code: ${lead.code}`);
            if (typed === null) return;
            if (typed.trim().toUpperCase() !== lead.code) return toast('कोड मेल नहीं खाया / code did not match', true);
            busy(ev.currentTarget, async () => {
              const { error } = await sb.rpc('erase_lead', { lead: id });
              if (error) throw error;
              toast('मिटा दिया / erased');
              location.hash = '#/leads';
            });
          },
        }, 'निजी डेटा मिटाएँ ', h('small', null, 'Erase (owner)'))) : null,
    );

    view().replaceChildren(back, head, h('div', { class: 'detail-grid' },
      h('div', null, work, kundliPanel(lead.kundli)),
      h('div', null, detailsPanel(lead), sourcePanel(lead), timelinePanel(evRes.data || [], actRes.data || [])),
    ));
  }

  function assignBlock(lead, rpc) {
    const sel = h('select', null,
      h('option', { value: '' }, '— किसी की नहीं / unassigned —'),
      [...staffById.values()].filter((s) => s.active).map((s) =>
        h('option', { value: s.user_id, selected: s.user_id === lead.assigned_to },
          s.name + ' (' + ROLE_LABEL[s.role][0] + ')')));
    return h('div', null,
      h('hr', { style: 'border:0;border-top:1px solid var(--line);margin:16px 0' }),
      h('label', null, 'किसे दें ', h('small', null, 'Assign to'), sel),
      h('button', {
        class: 'btn block', type: 'button', onclick: (ev) => rpc(ev.currentTarget, 'assign_lead',
          { staff_user: sel.value || null }, 'असाइन हुआ / assigned'),
      }, 'असाइन करें ', h('small', null, 'Assign')));
  }

  const kv = (pairs) => h('dl', { class: 'kv' }, pairs.filter(Boolean).map(([k, v]) =>
    [h('dt', null, k), h('dd', null, v === null || v === undefined || v === '' ? '—' : v)]));

  function detailsPanel(l) {
    const time = l.birth_time ? String(l.birth_time).slice(0, 5) : '—';
    return h('div', { class: 'panel' },
      h('h3', null, ...bi(['विवरण', 'Details'])),
      kv([
        ['फ़ोन', l.phone],
        ['जन्म तिथि', l.birth_date],
        ['समय', time + (l.time_approx ? ' (अनुमानित / approx.)' : '')],
        ['स्थान', l.place_name],
        ['अक्षांश/देशांतर', l.lat !== null ? `${l.lat}, ${l.lon}` : null],
        ['टाइमज़ोन', l.tz ? `${l.tz} (UTC${l.utc_offset_min >= 0 ? '+' : ''}${l.utc_offset_min ?? ''} min)` : null],
        ['भाषा', l.lang],
        ['सहमति / consent', l.consent_at ? `${fmtDT(l.consent_at)} · v${l.consent_version || '?'}` : null],
        l.paid_at ? ['भुगतान', `${inr(l.amount_paid)} · ${fmtDT(l.paid_at)}`] : null,
      ]));
  }

  function kundliPanel(k) {
    if (!k || typeof k !== 'object') {
      return h('div', { class: 'panel' }, h('h3', null, ...bi(['कुंडली', 'Kundli'])), h('p', { class: 'muted' }, '—'));
    }
    const dasha = (d) => (d && typeof d === 'object' ? `${d.lord || '?'} (${d.end ? 'तक ' + d.end : ''})` : null);
    const answer = Array.isArray(k.answer) ? k.answer : [];
    const grahas = Array.isArray(k.grahas) ? k.grahas : [];
    return h('div', { class: 'panel' },
      h('h3', null, ...bi(['कुंडली सार', 'Kundli summary'])),
      kv([
        ['राशि', k.rashi], ['लग्न', k.lagna],
        ['नक्षत्र', k.nakshatra ? `${k.nakshatra}${k.pada ? ' · पद ' + k.pada : ''}` : null],
        ['महादशा', dasha(k.mahadasha)], ['अंतर्दशा', dasha(k.antardasha)],
      ]),
      answer.length ? h('div', null, h('h3', { style: 'margin-top:12px' }, ...bi(['जवाब जो दिखाया', 'Answer shown'])),
        h('ol', { class: 'answer' }, answer.map((line) => h('li', null, String(line))))) : null,
      grahas.length ? h('details', { class: 'more' }, h('summary', null, 'ग्रह ', h('small', null, 'Grahas')),
        h('div', { class: 'scroll' }, h('table', null,
          h('tr', null, h('th', null, 'ग्रह'), h('th', null, 'राशि'), h('th', { class: 'num' }, 'अंश'), h('th', { class: 'num' }, 'भाव')),
          grahas.map((g) => h('tr', null,
            h('td', null, String(g.graha ?? '')), h('td', null, String(g.sign ?? '')),
            h('td', { class: 'num' }, typeof g.degree === 'number' ? g.degree.toFixed(2) : String(g.degree ?? '')),
            h('td', { class: 'num' }, String(g.house ?? ''))))))) : null,
    );
  }

  function sourcePanel(l) {
    return h('div', { class: 'panel' },
      h('h3', null, ...bi(['स्रोत', 'Source'])),
      kv([
        ['src', l.src],
        ['utm', [l.utm_source, l.utm_medium, l.utm_campaign].filter(Boolean).join(' / ')],
        ['referrer', l.referrer],
        ['landing', l.landing_url],
        ['IP', l.ip],
        ['ब्राउज़र', l.user_agent ? h('span', null, browserOf(l.user_agent), h('br'), h('small', null, l.user_agent)) : null],
      ]));
  }

  function timelinePanel(events, activity) {
    const items = [
      ...events.map((e) => ({ at: e.created_at, ev: true, label: EVENTS[e.event] || [e.event, ''], text: null })),
      ...activity.map((a) => ({
        at: a.created_at, ev: false, label: KINDS[a.kind] || [a.kind, ''],
        text: a.text, who: staffName(a.actor) || '—',
      })),
    ].sort((a, b) => (a.at < b.at ? 1 : -1));
    return h('div', { class: 'panel' },
      h('h3', null, ...bi(['इतिहास', 'History'])),
      items.length ? h('ul', { class: 'timeline' }, items.map((i) => h('li', { class: i.ev ? 'event' : '' },
        h('div', { class: 'when' }, fmtDT(i.at), i.ev ? ' · विज़िटर / visitor' : ' · ' + i.who),
        h('div', null, h('strong', null, i.label[0]), ' ', h('small', null, i.label[1])),
        i.text ? h('div', null, i.text) : (i.ev || i.text !== null ? null : h('div', { class: 'muted' }, '(मिटाया / erased)')),
      ))) : h('p', { class: 'muted' }, '—'));
  }

  // -------------------------------------------------------------------------
  // Dashboard (manager+)

  let dashPeriod = 7;

  async function viewDashboard() {
    view().replaceChildren(h('p', { class: 'muted' }, 'लोड हो रहा है…'));
    const to = new Date(Date.now() + 60000).toISOString();
    const periods = [[1, ['आज', 'Today']], [7, ['7 दिन', '7 days']], [30, ['30 दिन', '30 days']], [90, ['90 दिन', '90 days']]];
    // "Today" is since midnight IST; "7 days" is today and the six before.
    const results = await Promise.all(periods.map(([d]) =>
      sb.rpc('lead_stats', { from_ts: istStart(istDate(d - 1)), to_ts: to })));
    const bad = results.find((r) => r.error);
    if (bad) { view().replaceChildren(h('p', { class: 'error' }, errText(bad.error))); return; }
    const stats = Object.fromEntries(periods.map(([d], i) => [d, results[i].data]));

    const metric = (pair, get) => h('tr', null, h('td', null, pair[0], ' ', h('small', null, pair[1])),
      periods.slice(0, 3).map(([d]) => h('td', { class: 'num' }, get(stats[d].totals))));
    const summary = h('div', { class: 'panel scroll' },
      h('h3', null, ...bi(['सारांश', 'Summary'])),
      h('table', null,
        h('tr', null, h('th', null, ''), periods.slice(0, 3).map(([, p]) => h('th', { class: 'num' }, p[0]))),
        metric(['लीड्स', 'Leads'], (t) => t.leads),
        metric(['डाउनलोड', 'Downloads'], (t) => t.downloads),
        metric(['संपर्क', 'Contacted'], (t) => t.contacted),
        metric(['भुगतान', 'Paid'], (t) => t.paid),
        metric(['कमाई', 'Revenue'], (t) => inr(t.revenue)),
        metric(['कन्वर्ज़न', 'Paid / leads'], (t) => pct(t.paid, t.leads))),
      h('p', { class: 'muted', style: 'margin:8px 0 0' }, h('small', null,
        'Counts are over leads that arrived in the period: "paid" means paid so far, whenever the payment came.')));

    const s = stats[dashPeriod];
    const seg = h('div', { class: 'seg' }, periods.map(([d, p]) => h('button', {
      type: 'button', class: 'btn' + (d === dashPeriod ? ' on' : ''),
      onclick: () => { dashPeriod = d; viewDashboard(); },
    }, p[0])));

    const bySrc = h('div', { class: 'panel' },
      h('h3', null, ...bi(['कौन सा फ़्लायर काम कर रहा है', 'Leads by source'])),
      seg,
      h('div', { class: 'scroll' }, h('table', null,
        h('tr', null, ['स्रोत / src', 'लीड', 'डाउनलोड', 'संपर्क', 'भुगतान', 'कमाई', 'कन्वर्ज़न'].map((t, i) =>
          h('th', { class: i ? 'num' : '' }, t))),
        s.by_src.length ? s.by_src.map((r) => h('tr', null,
          h('td', null, r.src === '(none)' ? '(बिना src / none)' : h('a', {
            href: '#/leads', onclick: () => { Object.keys(filters).forEach((k) => { filters[k] = ''; }); filters.src = r.src; page = 0; },
          }, r.src)),
          h('td', { class: 'num' }, r.leads), h('td', { class: 'num' }, r.downloads),
          h('td', { class: 'num' }, r.contacted), h('td', { class: 'num' }, r.paid),
          h('td', { class: 'num' }, inr(r.revenue)), h('td', { class: 'num' }, pct(r.paid, r.leads))))
          : h('tr', null, h('td', { colspan: 7, class: 'muted' }, '—')))));

    const statusRow = h('div', { class: 'stats' }, Object.entries(STATUS).map(([k, v]) =>
      h('div', { class: 'stat' }, h('div', { class: 'n' }, s.by_status[k] || 0), h('div', { class: 'l' }, v[0], ' ', h('small', null, v[1])))));

    const byDay = h('div', { class: 'panel scroll' },
      h('h3', null, ...bi(['दिन के हिसाब से', 'By day'])),
      h('table', null,
        h('tr', null, h('th', null, 'दिन'), h('th', { class: 'num' }, 'लीड'), h('th', { class: 'num' }, 'डाउनलोड'), h('th', { class: 'num' }, 'भुगतान')),
        s.by_day.slice().reverse().map((d) => h('tr', null, h('td', null, d.day),
          h('td', { class: 'num' }, d.leads), h('td', { class: 'num' }, d.downloads), h('td', { class: 'num' }, d.paid)))));

    view().replaceChildren(summary, bySrc,
      h('h3', null, ...bi(['स्टेटस', 'Status, selected period'])), statusRow, byDay);
  }

  // -------------------------------------------------------------------------
  // Staff (owner)

  async function callStaff(body) {
    const { data, error } = await sb.functions.invoke('manage-staff', { body });
    if (error) {
      let code = error.message;
      try { code = (await error.context.json()).error || code; } catch (_) { /* not JSON */ }
      throw new Error(code);
    }
    return data;
  }

  // `notice` is shown above the form, e.g. the one-time password after an invite.
  async function viewStaff(notice) {
    view().replaceChildren(h('p', { class: 'muted' }, 'लोड हो रहा है…'));
    let list;
    try { list = (await callStaff({ action: 'list' })).staff; } catch (e) {
      view().replaceChildren(h('p', { class: 'error' }, errText(e)));
      return;
    }
    const refresh = async () => { await loadStaff(); viewStaff(); };

    const roleSel = (s) => h('select', {
      disabled: !s.active || s.user_id === me.user_id,
      onchange: (ev) => {
        const sel = ev.target;
        busy(sel, async () => {
          await callStaff({ action: 'set_role', user_id: s.user_id, role: sel.value });
          toast('भूमिका बदली / role changed');
          await refresh();
        }).then(() => { sel.value = (staffById.get(s.user_id) || s).role; });
      },
    }, Object.entries(ROLE_LABEL).map(([k, v]) => h('option', { value: k, selected: k === s.role }, v[0] + ' / ' + v[1])));

    const toggle = (s) => h('button', {
      class: 'btn wide ' + (s.active ? 'danger' : ''), type: 'button',
      onclick: (ev) => {
        if (s.active && !confirm(`${s.name} का खाता बंद करें? उनकी खुली लीड्स वापस पूल में जाएँगी।\nDeactivate ${s.name}?`)) return;
        busy(ev.currentTarget, async () => {
          const r = await callStaff({ action: s.active ? 'deactivate' : 'reactivate', user_id: s.user_id });
          toast(s.active ? `बंद किया; ${r.released || 0} लीड्स वापस पूल में / deactivated` : 'फिर से चालू / reactivated');
          await refresh();
        });
      },
    }, s.active ? 'बंद करें / Deactivate' : 'चालू करें / Reactivate');

    const team = h('ul', { class: 'cards' }, list.map((s) => h('li', { class: 'card' },
      h('div', { class: 'row1' }, h('span', { class: 'name' }, s.name),
        h('span', { class: 'badge ' + (s.active ? 'paid' : 'invalid') }, s.active ? 'सक्रिय' : 'बंद')),
      h('div', { class: 'meta' }, h('span', null, s.email || '—'),
        h('span', null, 'आख़िरी लॉगिन: ' + fmtDT(s.last_sign_in_at))),
      // Your own role and account are changed by another owner, so the last
      // owner cannot lock everyone out by accident.
      h('div', { class: 'btnrow', style: 'margin:8px 0 0' },
        h('label', { style: 'margin:0', class: 'wide' }, h('small', null, 'भूमिका / role'), roleSel(s)),
        s.user_id === me.user_id ? null : toggle(s)),
    )));

    const form = h('form', {
      class: 'panel', onsubmit: (ev) => {
        ev.preventDefault();
        const f = ev.target;
        busy($('button', f), async () => {
          const r = await callStaff({
            action: 'invite', email: f.email.value.trim(), name: f.name.value.trim(), role: f.role.value,
            method: f.method.value, redirectTo: location.origin + location.pathname,
          });
          await loadStaff();
          viewStaff(r.tempPassword
            ? h('div', { class: 'panel' },
              h('p', null, h('strong', null, 'अस्थायी पासवर्ड — सिर्फ़ अभी दिखेगा '), h('small', null, 'Temporary password, shown once')),
              h('div', { class: 'secret long' }, r.tempPassword),
              h('p', null, 'इसे निजी तौर पर (कॉल या WhatsApp पर) भेजें। पहले लॉगिन के बाद "खाता" में जाकर पासवर्ड बदलने को कहें।'),
              h('button', {
                type: 'button', class: 'btn',
                onclick: () => navigator.clipboard.writeText(r.tempPassword).then(() => toast('कॉपी हुआ / copied')),
              }, 'कॉपी ', h('small', null, 'Copy')))
            : h('p', { class: 'ok' }, r.existing
              ? 'पहले से खाता था — स्टाफ़ में जोड़ दिया, वे अपने पुराने पासवर्ड से लॉगिन करें। / existing account added'
              : 'निमंत्रण ईमेल भेजा गया / invite email sent'));
        });
      },
    },
    h('h3', null, ...bi(['नया स्टाफ़ जोड़ें', 'Add staff'])),
    h('label', null, 'नाम ', h('small', null, 'Name'), h('input', { name: 'name', required: true, maxlength: 80 })),
    h('label', null, 'ईमेल ', h('small', null, 'Email'), h('input', { name: 'email', type: 'email', required: true, inputmode: 'email' })),
    h('label', null, 'भूमिका ', h('small', null, 'Role'), h('select', { name: 'role' },
      h('option', { value: 'caller' }, 'कॉलर / Caller'), h('option', { value: 'manager' }, 'मैनेजर / Manager'),
      h('option', { value: 'owner' }, 'मालिक / Owner'))),
    h('label', null, 'कैसे ', h('small', null, 'How'), h('select', { name: 'method' },
      h('option', { value: 'password' }, 'अस्थायी पासवर्ड बनाएँ (आसान) / temporary password'),
      h('option', { value: 'invite' }, 'ईमेल से निमंत्रण (SMTP चाहिए) / email invite'))),
    h('button', { class: 'btn primary block', type: 'submit' }, 'जोड़ें ', h('small', null, 'Add')));

    view().replaceChildren(
      notice || '',
      form,
      h('h3', null, ...bi(['टीम', 'Team'])),
      h('p', { class: 'muted' }, h('small', null,
        'Callers see only their own and unassigned leads; managers see all leads and the dashboard; ' +
        'owners also manage staff and can erase a lead.')),
      team);
  }

  // -------------------------------------------------------------------------
  // Account

  function viewAccount() {
    view().replaceChildren(h('div', { class: 'panel' },
      h('h3', null, ...bi(['आपका खाता', 'Your account'])),
      kv([['नाम', me.name], ['ईमेल', me.email], ['भूमिका', ROLE_LABEL[me.role].join(' / ')]]),
      h('div', { class: 'btnrow', style: 'margin-top:14px' },
        h('button', { class: 'btn wide', type: 'button', onclick: () => show('setpw') }, 'पासवर्ड बदलें ', h('small', null, 'Change password')),
        h('button', { class: 'btn danger wide', type: 'button', onclick: signOut }, 'लॉगआउट ', h('small', null, 'Sign out')))),
    h('p', { class: 'muted' }, h('small', null,
      'इन लीड्स में लोगों की निजी जानकारी है (DPDP Act)। स्क्रीनशॉट या बाहर शेयर न करें। / ' +
      'These leads are personal data under the DPDP Act: do not screenshot or share them outside this panel.')));
  }

  boot().catch((e) => { console.error(e); show('login'); toast(errText(e), true); });
})();
