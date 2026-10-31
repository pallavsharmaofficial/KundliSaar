// The "आपका अच्छा समय" landing page.
//
// The kundli is computed here in the browser by the app's own engine
// (funnel.js, compiled from tools/funnel/funnel_main.dart). The details and a
// summary of the result go to the submit-lead edge function, which stores
// them and hands back a lead code and this visitor's PDF password. The PDF is
// made here too, locked with that password; the visitor gets the password by
// calling or messaging the number on the page.
(function () {
  'use strict';

  var CFG = window.KS_CONFIG || {};
  var PHONE = CFG.contactPhone || '9910144125';
  var WA = CFG.whatsappPhone || '91' + PHONE;
  var backendReady = !!(CFG.supabaseUrl && CFG.supabaseAnonKey);

  var $ = function (id) { return document.getElementById(id); };

  // ---------------------------------------------------------------- source

  // Which flyer, shop or post brought this visitor: ?src=... on the QR code.
  var params = new URLSearchParams(location.search);
  var source = {
    src: (params.get('src') || 'direct').slice(0, 60),
    utm_source: (params.get('utm_source') || '').slice(0, 60),
    utm_medium: (params.get('utm_medium') || '').slice(0, 60),
    utm_campaign: (params.get('utm_campaign') || '').slice(0, 60),
    referrer: (document.referrer || '').slice(0, 300),
    landing_url: location.href.slice(0, 500),
  };

  // ---------------------------------------------------------------- engine

  // Loaded in the background while the visitor fills the form: it is the
  // biggest file on the page and nothing needs it before the button.
  var engine = new Promise(function (resolve, reject) {
    var s = document.createElement('script');
    s.src = 'funnel.js';
    s.async = true;
    s.onload = function () {
      var tries = 0;
      (function wait() {
        if (typeof window.ksCompute === 'function') return resolve();
        if (++tries > 100) return reject(new Error('engine'));
        setTimeout(wait, 30);
      })();
    };
    s.onerror = function () { reject(new Error('engine')); };
    document.head.appendChild(s);
  });

  // ---------------------------------------------------------------- places

  var places = null;
  var placesLoading = null;
  var picked = null;

  function fold(v) {
    return (v || '').toLowerCase().trim()
      .normalize('NFD').replace(/[̀-ͯ]/g, '');
  }

  function loadPlaces() {
    if (places) return Promise.resolve(places);
    if (!placesLoading) {
      placesLoading = fetch('places.json')
        .then(function (r) { return r.json(); })
        .then(function (j) {
          // Indian places first, each list already biggest first.
          var all = j.places;
          var india = all.filter(function (p) { return p.c === 'IN'; });
          var rest = all.filter(function (p) { return p.c !== 'IN'; });
          places = india.concat(rest).map(function (p) {
            p.k = p.s || fold(p.n);
            p.ak = fold(p.a);
            return p;
          });
          return places;
        });
    }
    return placesLoading;
  }

  function searchPlaces(q) {
    var needle = fold(q);
    if (!needle || !places) return [];
    var starts = [], contains = [];
    for (var i = 0; i < places.length; i++) {
      var p = places[i];
      if (p.k.indexOf(needle) === 0) starts.push(p);
      else if (needle.length > 2 && (p.k.indexOf(needle) > 0 || p.ak.indexOf(needle) === 0)) contains.push(p);
      if (starts.length >= 8) break;
    }
    return starts.concat(contains).slice(0, 8);
  }

  function placeLabel(p) {
    return p.n + (p.a && p.a !== p.n ? ', ' + p.a : '') + (p.c !== 'IN' ? ' (' + p.c + ')' : '');
  }

  var placeInput = $('place');
  var list = $('place-list');
  var active = -1;
  var shown = [];

  function renderList() {
    list.textContent = '';
    shown.forEach(function (p, i) {
      var li = document.createElement('li');
      li.setAttribute('role', 'option');
      li.setAttribute('aria-selected', i === active ? 'true' : 'false');
      li.textContent = p.n;
      var small = document.createElement('small');
      small.textContent = ' ' + [p.a, p.c !== 'IN' ? p.c : ''].filter(Boolean).join(', ');
      li.appendChild(small);
      li.addEventListener('mousedown', function (e) { e.preventDefault(); choose(p); });
      list.appendChild(li);
    });
    list.hidden = shown.length === 0;
  }

  function choose(p) {
    picked = p;
    placeInput.value = placeLabel(p);
    placeInput.removeAttribute('aria-invalid');
    shown = [];
    renderList();
    var note = $('place-picked');
    note.textContent = '✓ ' + placeLabel(p);
    note.hidden = false;
    $('place-hint').hidden = true;
  }

  placeInput.addEventListener('focus', loadPlaces);
  placeInput.addEventListener('input', function () {
    picked = null;
    $('place-picked').hidden = true;
    $('place-hint').hidden = false;
    loadPlaces().then(function () {
      shown = searchPlaces(placeInput.value);
      active = shown.length ? 0 : -1;
      renderList();
    });
  });
  placeInput.addEventListener('keydown', function (e) {
    if (list.hidden) return;
    if (e.key === 'ArrowDown') { active = Math.min(active + 1, shown.length - 1); renderList(); e.preventDefault(); }
    else if (e.key === 'ArrowUp') { active = Math.max(active - 1, 0); renderList(); e.preventDefault(); }
    else if (e.key === 'Enter' && active >= 0) { choose(shown[active]); e.preventDefault(); }
    else if (e.key === 'Escape') { shown = []; renderList(); }
  });
  placeInput.addEventListener('blur', function () {
    setTimeout(function () { shown = []; renderList(); }, 150);
  });

  // ---------------------------------------------------------------- form

  $('date').max = new Date().toISOString().slice(0, 10);

  function normPhone(v) {
    var d = (v || '').replace(/[^\d]/g, '');
    if (d.length === 12 && d.indexOf('91') === 0) d = d.slice(2);
    if (d.length === 11 && d[0] === '0') d = d.slice(1);
    return /^[6-9]\d{9}$/.test(d) ? d : null;
  }

  function fail(msg, field) {
    var e = $('form-error');
    e.textContent = msg;
    e.hidden = false;
    if (field) { field.setAttribute('aria-invalid', 'true'); field.focus(); }
  }

  var lead = null;     // { leadId, code, password } from the backend
  var birthJson = null;
  var reading = null;

  $('birth-form').addEventListener('submit', function (ev) {
    ev.preventDefault();
    $('form-error').hidden = true;
    Array.prototype.forEach.call(document.querySelectorAll('[aria-invalid]'), function (n) { n.removeAttribute('aria-invalid'); });

    var name = $('name').value.trim();
    var phone = normPhone($('phone').value);
    var date = $('date').value;
    var time = $('time').value;
    if (!name) return fail('कृपया अपना नाम लिखिए।', $('name'));
    if (!phone) return fail('कृपया सही 10 अंकों का मोबाइल नंबर लिखिए।', $('phone'));
    if (!date || date < '1900-01-01' || date > $('date').max) return fail('कृपया सही जन्म तिथि चुनिए।', $('date'));
    if (!time) return fail('कृपया जन्म का समय भरिए। सही न पता हो तो अंदाज़े से भरकर नीचे निशान लगाइए।', $('time'));
    if (!picked) return fail('कृपया जन्म स्थान लिखकर सूची में से चुनिए।', placeInput);
    if (!$('consent').checked) return fail('आगे बढ़ने के लिए सहमति वाले बॉक्स पर निशान लगाइए।', $('consent'));

    var birth = {
      name: name,
      date: date,
      time: time,
      timeApprox: $('time-approx').checked,
      place: { name: placeLabel(picked), lat: picked.y, lon: picked.x, tz: picked.z },
    };
    birthJson = JSON.stringify(birth);

    var btn = $('submit');
    btn.disabled = true;
    btn.textContent = 'आपकी कुंडली बन रही है…';

    engine
      .then(function () {
        // Give the button's new words a frame to show before the work.
        return new Promise(function (r) { setTimeout(r, 30); });
      })
      .then(function () {
        reading = JSON.parse(window.ksCompute(birthJson));
        showResult(birth, reading);
        return submitLead(name, phone, birth, reading);
      })
      .catch(function (err) {
        console.error(err);
        if (!reading) fail('माफ़ कीजिए, कुंडली नहीं बन पाई। कृपया पेज दोबारा खोलकर कोशिश कीजिए।');
      })
      .then(function () {
        btn.disabled = false;
        btn.textContent = 'मेरा अच्छा समय दिखाइए';
      });
  });

  function api(name, body) {
    return fetch(CFG.supabaseUrl.replace(/\/$/, '') + '/functions/v1/' + name, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: CFG.supabaseAnonKey,
        Authorization: 'Bearer ' + CFG.supabaseAnonKey,
      },
      body: JSON.stringify(body),
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (j) {
        if (!r.ok) { var e = new Error(j.error || ('http ' + r.status)); e.code = j.error; throw e; }
        return j;
      });
    });
  }

  function submitLead(name, phone, birth, r) {
    if (!backendReady) {
      lead = null;
      setDownloadState('offline');
      return Promise.resolve();
    }
    var body = {
      name: name,
      phone: phone,
      birth: {
        date: birth.date,
        time: birth.time,
        timeApprox: birth.timeApprox,
        place: birth.place,
        utcOffsetMinutes: r.utcOffsetMinutes,
      },
      kundli: {
        lagna: r.lagna,
        rashi: r.rashi,
        nakshatra: r.nakshatra,
        pada: r.pada,
        mahadasha: r.mahadasha,
        antardasha: r.antardasha,
        answer: r.answer,
        grahas: r.grahas,
      },
      source: source,
      consent: true,
      consentVersion: '2026-10-31',
      lang: 'hi',
      website: $('website').value,
    };
    var attempt = function (n) {
      return api('submit-lead', body).catch(function (e) {
        if (n > 0 && e.code !== 'phone' && e.code !== 'consent' && e.code !== 'rate') {
          return new Promise(function (res) { setTimeout(res, 1500); }).then(function () { return attempt(n - 1); });
        }
        throw e;
      });
    };
    return attempt(2).then(function (j) {
      lead = j;
      setDownloadState('ready');
    }).catch(function (e) {
      lead = null;
      setDownloadState(e.code === 'rate' ? 'rate' : 'error');
    });
  }

  // ---------------------------------------------------------------- result

  function showResult(birth, r) {
    $('form-card').hidden = true;
    var res = $('result');
    res.hidden = false;
    $('r-hello').textContent = birth.name + ' जी, आपकी कुंडली के अनुसार:';
    $('r-rashi').textContent = r.rashi;
    $('r-lagna').textContent = r.lagna;
    $('r-nak').textContent = r.nakshatra;
    var ul = $('r-answer');
    ul.textContent = '';
    r.answer.forEach(function (line) {
      var li = document.createElement('li');
      li.textContent = line;
      ul.appendChild(li);
    });
    $('r-approx').hidden = !birth.timeApprox;

    $('b-nak').textContent = r.nakshatra + ', स्वामी ' + r.nakshatraLord;
    $('b-maha').textContent = r.mahadasha ? r.mahadasha.lord : '—';
    $('b-antar').textContent = r.antardasha ? r.antardasha.lord : '—';
    var tb = $('b-grahas');
    tb.textContent = '';
    r.grahas.forEach(function (g) {
      var tr = document.createElement('tr');
      [g.graha + (g.retro ? ' (वक्री)' : ''), g.sign, g.degree.toFixed(2) + '°', String(g.house)].forEach(function (v) {
        var td = document.createElement('td');
        td.textContent = v;
        tr.appendChild(td);
      });
      tb.appendChild(tr);
    });
    setDownloadState(backendReady ? 'saving' : 'offline');
    res.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  $('basis').addEventListener('toggle', function () {
    if ($('basis').open) track('basis_open');
  });

  // ---------------------------------------------------------------- download

  function setDownloadState(state) {
    var btn = $('download');
    var err = $('dl-error');
    err.hidden = true;
    btn.disabled = state !== 'ready';
    if (state === 'saving') btn.textContent = 'एक क्षण…';
    else if (state === 'ready') btn.textContent = 'पूरी कुंडली PDF डाउनलोड करें';
    else {
      btn.textContent = 'पूरी कुंडली PDF डाउनलोड करें';
      err.textContent = state === 'rate'
        ? 'इस नेटवर्क से बहुत सारी कुंडलियाँ बन चुकी हैं। कृपया थोड़ी देर बाद कोशिश कीजिए, या ' + PHONE + ' पर संपर्क कीजिए।'
        : state === 'offline'
          ? 'PDF डाउनलोड अभी शुरू नहीं हुआ है। अपनी पूरी कुंडली के लिए ' + PHONE + ' पर संपर्क कीजिए।'
          : 'आपकी जानकारी सहेजी नहीं जा सकी। इंटरनेट जाँचकर पेज दोबारा खोलिए, या ' + PHONE + ' पर संपर्क कीजिए।';
      err.hidden = false;
    }
  }

  var fonts = null;
  function loadFonts() {
    if (fonts) return fonts;
    var names = ['Mukta-Regular.ttf', 'Mukta-SemiBold.ttf', 'TiroDevanagariHindi-Regular.ttf', 'YatraOne-Regular.ttf'];
    fonts = Promise.all(names.map(function (n) {
      return fetch('fonts/' + n).then(function (r) {
        if (!r.ok) throw new Error('font ' + n);
        return r.arrayBuffer();
      }).then(function (b) { return new Uint8Array(b); });
    }));
    fonts.catch(function () { fonts = null; });
    return fonts;
  }

  $('download').addEventListener('click', function () {
    if (!lead || !birthJson) return;
    var btn = $('download');
    btn.disabled = true;
    $('dl-progress').hidden = false;
    $('dl-error').hidden = true;
    loadFonts()
      .then(function (f) {
        return window.ksPdf(birthJson, lead.password, f[0], f[1], f[2], f[3]);
      })
      .then(function (bytes) {
        var blob = new Blob([bytes], { type: 'application/pdf' });
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        // The code alone: some Android browsers mangle Hindi file names.
        a.download = 'Kundli_' + lead.code + '.pdf';
        document.body.appendChild(a);
        a.click();
        setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 60000);
        showLocked();
        track('pdf_download');
      })
      .catch(function (e) {
        console.error(e);
        var err = $('dl-error');
        err.textContent = 'PDF नहीं बन पाई। कृपया दोबारा दबाइए, या ' + PHONE + ' पर संपर्क कीजिए।';
        err.hidden = false;
      })
      .then(function () {
        btn.disabled = false;
        $('dl-progress').hidden = true;
      });
  });

  function showLocked() {
    $('dl-progress').hidden = true;
    $('r-code').textContent = lead.code;
    var text = 'नमस्ते, मैंने कुंडलीसार पर अपनी कुंडली डाउनलोड की है। मेरा कुंडली कोड ' + lead.code + ' है। कृपया PDF का पासवर्ड बताइए।';
    $('wa-link').href = 'https://wa.me/' + WA + '?text=' + encodeURIComponent(text);
    $('locked').hidden = false;
    $('locked').scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  $('wa-link').addEventListener('click', function () { track('whatsapp_click'); });
  $('call-btn').addEventListener('click', function () { track('call_click'); });
  $('call-link').addEventListener('click', function () { track('call_click'); });

  function track(event) {
    if (!lead || !backendReady) return;
    api('track', { leadId: lead.leadId, code: lead.code, event: event }).catch(function () {});
  }
})();
