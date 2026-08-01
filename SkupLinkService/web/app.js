(() =>
{
  const TOKEN_KEY = 'skuplink_token';
  const UPS_CACHE_KEY = 'skuplink_ups_cache';
  const POLL_MS = 5000;
  const CHART_POLL_MS = 5000;

  const $ = (id) => document.getElementById(id);
  const t = (key, vars) => (window.SLLang ? SLLang.t(key, vars) : key);

  const state =
  {
    token: localStorage.getItem(TOKEN_KEY) || '',
    threshold: null,
    delaySeconds: null,
    lastUpsJson: '',
    lastPhasesHtml: '',
    lastCharge: null,
    lastChartAt: 0,
    lastSampleCount: '',
    ticking: false,
    serverOnline: false,
    inputPhaseCount: 0,
    outputPhaseCount: 0,
  };

  function fmt(n, digits = 0)
  {
    if ((n === null) || (n === undefined) || Number.isNaN(n))
      return t('dash');

    return Number(n).toFixed(digits);
  }

  function fmtWorkMode(sec)
  {
    const s = Number(sec) || 0;

    if (s <= 0)
      return t('work_mode_mains');

    const m = Math.floor(s / 60);
    const r = s % 60;

    return t('work_mode_battery',
    { min: m, sec: r });
  }

  function topologyLabel(v)
  {
    const map =
    {
      unknown: 'topology_unknown',
      single_phase: 'topology_single_phase',
      three_phase_in_out: 'topology_three_phase_in_out',
      three_phase_in_single_out: 'topology_three_phase_in_single_out',
    };

    return map[v] ? t(map[v]) : (v || t('dash'));
  }

  function batteryLabel(v)
  {
    const map =
    {
      unknown: 'battery_unknown',
      battery_normal: 'battery_normal',
      battery_low: 'battery_low',
      battery_depleted: 'battery_depleted',
    };

    return map[v] ? t(map[v]) : (v || t('dash'));
  }

  function setText(id, value)
  {
    const el = $(id);
    const next = value == null ? '' : String(value);

    if (el.textContent !== next)
      el.textContent = next;
  }

  function activeTab()
  {
    const active = document.querySelector('.tab.is-active');

    return active ? active.dataset.tab : 'overview';
  }

  function isNetworkError(err)
  {
    if (!err)
      return false;

    const name = String(err.name || '');
    const msg = String(err.message || '').toLowerCase();

    if (name === 'NetworkError')
      return true;

    if (msg.indexOf('failed to fetch') >= 0)
      return true;

    if (msg.indexOf('networkerror') >= 0)
      return true;

    if (msg.indexOf('network request failed') >= 0)
      return true;

    if (msg.indexOf('load failed') >= 0)
      return true;

    if ((msg.indexOf('fetch') >= 0) && (name === 'TypeError'))
      return true;

    return false;
  }

  function friendlyError(err)
  {
    if (isNetworkError(err))
      return t('error_network');

    const msg = err && err.message ? String(err.message) : '';

    if (!msg)
      return t('error_request');

    if (/^failed to fetch$/i.test(msg))
      return t('error_network');

    return msg;
  }

  async function api(path, options = {})
  {
    const headers = Object.assign(
    { 'Content-Type': 'application/json' }, options.headers || {});

    if (state.token)
      headers['X-Auth-Token'] = state.token;

    let res;

    try
    {
      res = await fetch(path, Object.assign({}, options,
      { headers }));
    }
    catch (err)
    {
      throw new Error(friendlyError(err));
    }

    const text = await res.text();
    let data = null;

    try
    {
      data = text ? JSON.parse(text) : null;
    }
    catch (_)
    {
      data =
      { raw: text };
    }

    if (res.status === 401)
    {
      logout(false);
      throw new Error(data && data.error ? data.error : t('login_auth_required'));
    }

    if (!res.ok)
    {
      throw new Error((data && data.error) || text || t('error_http',
      { code: res.status }));
    }

    return data;
  }

  function showLogin()
  {
    document.documentElement.classList.remove('sl-session');
    document.documentElement.classList.add('sl-guest');
    $('view-login').hidden = false;
    $('view-app').hidden = true;

    const pwdMsg = $('password-msg');
    const setMsg = $('settings-msg');

    if (pwdMsg)
    {
      pwdMsg.hidden = true;
      pwdMsg.textContent = '';
    }

    if (setMsg)
    {
      setMsg.hidden = true;
      setMsg.textContent = '';
    }
  }

  function showApp()
  {
    document.documentElement.classList.remove('sl-guest');
    document.documentElement.classList.add('sl-session');
    $('view-login').hidden = true;
    $('view-app').hidden = false;
  }

  function logout(callApi)
  {
    const token = state.token;

    state.token = '';
    state.lastUpsJson = '';
    localStorage.removeItem(TOKEN_KEY);
    document.documentElement.classList.remove('sl-data-ready');

    if (callApi && token)
    {
      fetch('/api/logout',
      {
        method: 'POST',
        headers:
        { 'X-Auth-Token': token, 'Content-Type': 'application/json' },
      }).catch(() => {});
    }

    showLogin();
  }

  function setCharge(percent)
  {
    if (state.lastCharge === percent)
      return;

    state.lastCharge = percent;

    const arc = $('charge-arc');
    const C = 2 * Math.PI * 52;

    if ((percent === null) || (percent === undefined) || (percent < 0))
    {
      setText('m-charge', t('dash'));
      arc.style.strokeDashoffset = String(C);
      arc.style.stroke = 'var(--muted)';

      return;
    }

    const p = Math.max(0, Math.min(100, Number(percent)));

    setText('m-charge', String(Math.round(p)));
    arc.style.strokeDashoffset = String(C * (1 - p / 100));

    arc.style.stroke = (p <= (state.threshold || 15)) ? 'var(--rose)' : ((p < 40) ? 'var(--amber)' : 'var(--teal)');
  }

  function phaseName(index, phaseCount)
  {
    if (phaseCount <= 1)
      return t('phase_voltage');

    const map =
    { 1: 'phase_r', 2: 'phase_s', 3: 'phase_t' };

    return map[index] ? t(map[index]) : `L${index}`;
  }

  function renderPhases(snap)
  {
    const inPhases = (snap.input && snap.input.phases) || [];
    const outPhases = (snap.output && snap.output.phases) || [];
    let htmlIn = '';
    let htmlOut = '';

    inPhases.forEach((p) =>
    {
      const val = t('phase_in_value',
      {
        v: fmt(p.voltage, 0),
        hz: fmt(p.frequency, 1),
      });

      htmlIn += `<div class="phase-item"><span>${phaseName(p.index, inPhases.length)}</span><strong>${val}</strong></div>`;
    });

    const outFreq = (snap.output && (snap.output.frequency != null)) ? fmt(snap.output.frequency, 1) : t('dash');
    const outFreqText = t('phase_freq_value',
    {
      hz: outFreq,
    });

    htmlOut += `<div class="phase-item"><span>${t('phase_frequency')}</span><strong>${outFreqText}</strong></div>`;

    outPhases.forEach((p) =>
    {
      const val = t('phase_out_value',
      {
        v: fmt(p.voltage, 0),
        load: fmt(p.percent_load, 0),
        w: fmt(p.power_watts, 0),
      });

      htmlOut += `<div class="phase-item"><span>${phaseName(p.index, outPhases.length)}</span><strong>${val}</strong></div>`;
    });

    const key = htmlIn + '\n' + htmlOut;

    if (key === state.lastPhasesHtml)
      return;

    state.lastPhasesHtml = key;
    
    $('phases-in').innerHTML = htmlIn;
    $('phases-out').innerHTML = htmlOut;
  }

  function formatPhaseVoltages(phases)
  {
    if (!phases || !phases.length)
      return t('dash');

    return phases.map((p) => fmt(p.voltage, 0)).join(' / ');
  }

  function setConnPill(kind)
  {
    const pill = $('conn-pill');
    const text = kind === 'ok' ? t('conn_ok') : (kind === 'snmp' ? t('conn_no_snmp') : t('conn_no_server'));
    const cls = kind === 'ok' ? 'pill pill-ok' : 'pill pill-warn';

    if (pill.textContent !== text)
      pill.textContent = text;

    if (pill.className !== cls)
      pill.className = cls;
  }

  function setDetailBlocksVisible(show)
  {
    ['block-charge', 'block-info', 'block-phases'].forEach((id) =>
    {
      const el = $(id);

      if (el)
        el.hidden = !show;
    });
  }

  function clearOverviewMetrics()
  {
    setText('m-vin', t('dash'));
    setText('m-vout', t('dash'));
    setText('m-load', t('dash'));
    setText('m-batv', t('dash'));
    setCharge(null);
    setDetailBlocksVisible(false);
    state.inputPhaseCount = 0;
    state.outputPhaseCount = 0;
    state.lastPhasesHtml = '';

    if ($('phases-in'))
      $('phases-in').innerHTML = '';

    if ($('phases-out'))
      $('phases-out').innerHTML = '';
  }

  function markServerOffline()
  {
    state.serverOnline = false;
    state.lastUpsJson = '';
    setConnPill('server');
    setText('ups-ident', t('server_unavailable'));
    clearOverviewMetrics();
  }

  function updateOverview(snap, options)
  {
    const live = !!(options && options.live);
    const snmpOk = !!(live && snap && snap.snmp_connected);

    state.serverOnline = live;

    setConnPill(!live ? 'server' : (snmpOk ? 'ok' : 'snmp'));

    const ident = (snap && snap.ident) || {};
    const title = [ident.manufacturer, ident.model, ident.name].filter(Boolean).join(' · ');

    setText('ups-ident', !live ? (title ? `${title} (${t('server_unavailable_suffix')})` : t('server_unavailable')) : (title || (snmpOk ? t('ups_generic') : t('ups_no_snmp_data'))));

    if (!snap || !snmpOk)
    {
      clearOverviewMetrics();

      return;
    }

    setDetailBlocksVisible(true);

    setText('m-vin', formatPhaseVoltages((snap.input || {}).phases));
    setText('m-vout', formatPhaseVoltages((snap.output || {}).phases));
    setText('m-load', fmt((snap.output || {}).total_percent_load, 0));
    setText('m-batv', fmt((snap.battery || {}).voltage, 1));

    setCharge((snap.battery || {}).charge_percent);

    setText('m-bat-status', batteryLabel((snap.battery || {}).status));
    setText('m-topology', topologyLabel(snap.topology));
    setText('m-onbat', fmtWorkMode((snap.battery || {}).seconds_on_battery));
    setText('m-remain', ((snap.battery || {}).estimated_minutes_remaining != null) ? t('remain_minutes', { min: (snap.battery || {}).estimated_minutes_remaining }) : t('dash'));
    setText('m-power', t('power_watts', { w: fmt((snap.output || {}).total_power_watts, 0) }));
    setText('m-threshold', state.threshold != null ? t('threshold_percent', { n: state.threshold }) : t('dash'));
    setText('m-delay', state.delaySeconds != null ? t('delay_seconds', { n: state.delaySeconds }) : t('dash'));

    state.inputPhaseCount = ((snap.input && snap.input.phases) || []).length;
    state.outputPhaseCount = ((snap.output && snap.output.phases) || []).length;

    renderPhases(snap);
  }

  const PHASE_COLORS = ['#0f766e', '#c47a14', '#2563eb'];

  function phaseLabel(i, len)
  {
    if (len <= 1)
      return '';

    const keys = ['phase_r', 'phase_s', 'phase_t'];

    return keys[i] ? t(keys[i]) : `L${i + 1}`;
  }

  function seriesFromArrayField(samples, field, phaseCount)
  {
    if (!samples.length)
      return [];

    const lastArr = Array.isArray(samples[samples.length - 1][field]) ? samples[samples.length - 1][field] : [];
    let len = Number(phaseCount) || 0;

    if (len < 1)
      len = lastArr.length;

    if (len < 1)
      return [];

    if (len > 3)
      len = 3;

    const series = [];

    for (let i = 0; i < len; i++)
    {
      series.push(
      {
        label: phaseLabel(i, len),
        color: PHASE_COLORS[i % PHASE_COLORS.length],
        values: samples.map((s) =>
        {
          const arr = Array.isArray(s[field]) ? s[field] : [];

          if (i >= arr.length)
            return null;

          const v = Number(arr[i]);

          return Number.isNaN(v) ? null : v;
        }),
      });
    }

    return series;
  }

  function seriesFromScalarField(samples, field, color)
  {
    return [
    {
      label: '',
      color,
      values: samples.map((s) =>
      {
        const v = Number(s[field]);
        return Number.isNaN(v) ? null : v;
      }),
    }];
  }

  function drawChart(canvas, series, unit)
  {
    const ctx = canvas.getContext('2d');
    const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    const cssW = canvas.clientWidth || 640;
    const cssH = 220;

    canvas.width = Math.floor(cssW * dpr);
    canvas.height = Math.floor(cssH * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const w = cssW;
    const h = cssH;
    const pad =
    {
      l: 44,
      r: 12,
      t: 22,
      b: 28,
    };

    const plotW = w - pad.l - pad.r;
    const plotH = h - pad.t - pad.b;

    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#f7fafb';
    ctx.fillRect(0, 0, w, h);

    const all = [];

    (series || []).forEach((s) =>
    {
      (s.values || []).forEach((v) =>
      {
        if ((v !== null) && (v !== undefined) && !Number.isNaN(v))
          all.push(v);
      });
    });

    if (!all.length)
    {
      ctx.fillStyle = '#5b6b76';
      ctx.font = '14px Manrope, sans-serif';
      ctx.fillText(t('chart_no_data'), pad.l, h / 2);

      return;
    }

    let min = Math.min(...all);
    let max = Math.max(...all);

    if (min === max)
    {
      min -= 1;
      max += 1;
    }

    const span = max - min;
    const n = Math.max.apply(null, series.map((s) => s.values.length));

    ctx.strokeStyle = 'rgba(19,33,43,0.08)';
    ctx.lineWidth = 1;
    ctx.font = '11px Manrope, sans-serif';
    ctx.fillStyle = '#5b6b76';

    for (let i = 0; i <= 4; i++)
    {
      const y = pad.t + (plotH * i) / 4;
      const val = max - (span * i) / 4;

      ctx.beginPath();
      ctx.moveTo(pad.l, y);
      ctx.lineTo(pad.l + plotW, y);
      ctx.stroke();
      ctx.fillText(val.toFixed(unit === '%' ? 1 : 0), 6, y + 4);
    }

    const point = (i, v) => (
    {
      x: pad.l + (plotW * i) / Math.max(n - 1, 1),
      y: pad.t + plotH * (1 - (v - min) / span),
    });

    series.forEach((s) =>
    {
      ctx.beginPath();
      let started = false;

      s.values.forEach((v, i) =>
      {
        if ((v === null) || (v === undefined) || Number.isNaN(v))
        {
          started = false;

          return;
        }

        const p = point(i, v);

        if (!started)
        {
          ctx.moveTo(p.x, p.y);
          started = true;
        }
        else
        {
          ctx.lineTo(p.x, p.y);
        }
      });

      ctx.strokeStyle = s.color;
      ctx.lineWidth = 2.2;
      ctx.lineJoin = 'round';
      ctx.stroke();
    });

    let legendX = pad.l;

    ctx.font = '600 11px Manrope, sans-serif';
    series.forEach((s) =>
    {
      let last = null;

      for (let i = s.values.length - 1; i >= 0; i--)
      {
        if ((s.values[i] !== null) && (s.values[i] !== undefined) && !Number.isNaN(s.values[i]))
        {
          last = s.values[i];
          break;
        }
      }

      if (last === null)
        return;

      const text = s.label ? `${s.label} ${last.toFixed(1)} ${unit}` : `${last.toFixed(1)} ${unit}`;

      ctx.fillStyle = s.color;
      ctx.fillText(text, legendX, pad.t - 6);
      legendX += ctx.measureText(text).width + 14;
    });
  }

  async function refreshHistory(force)
  {
    const data = await api('/api/history');
    const samples = data.samples || [];
    const sig = samples.length ? `${samples.length}:${samples[samples.length - 1].ts}` : '0';

    if (!force && (sig === state.lastSampleCount))
      return;

    state.lastSampleCount = sig;
    state.lastChartAt = Date.now();

    drawChart($('chart-vin'), seriesFromArrayField(samples, 'input_voltages', state.inputPhaseCount), t('unit_v'));
    drawChart($('chart-vout'), seriesFromArrayField(samples, 'output_voltages', state.outputPhaseCount), t('unit_v'));
    drawChart($('chart-load'), seriesFromArrayField(samples, 'load_percents', state.outputPhaseCount), t('unit_percent'));
    drawChart($('chart-batv'), seriesFromScalarField(samples, 'battery_voltage', '#b45309'), t('unit_v'));
  }

  async function refreshSettings()
  {
    const s = await api('/api/settings');

    if (document.activeElement !== $('set-host'))
      $('set-host').value = s.snmp_host || '';

    if (document.activeElement !== $('set-snmp-version'))
      $('set-snmp-version').value = (s.snmp_version === '2c') ? '2c' : '1';

    if (document.activeElement !== $('set-community'))
      $('set-community').value = s.snmp_community || '';

    if (document.activeElement !== $('set-threshold'))
      $('set-threshold').value = s.shutdown_battery_percent;

    if (document.activeElement !== $('set-delay'))
      $('set-delay').value = s.shutdown_delay_seconds;

    state.threshold = s.shutdown_battery_percent;
    state.delaySeconds = s.shutdown_delay_seconds;
    setText('m-threshold', t('threshold_percent', { n: s.shutdown_battery_percent }));
    setText('m-delay', t('delay_seconds', { n: s.shutdown_delay_seconds }));
  }

  async function refreshUps()
  {
    try
    {
      const snap = await api('/api/ups');
      const json = JSON.stringify(snap);

      try
      {
        localStorage.setItem(UPS_CACHE_KEY, json);
      }
      catch (_)
      {
      }

      if ((json === state.lastUpsJson) && state.serverOnline)
        return;

      state.lastUpsJson = json;
      updateOverview(snap,
      { live: true });
    }
    catch (e)
    {
      markServerOffline();
      throw e;
    }
  }

  function applyBootData()
  {
    const boot = window.__SL_BOOT || {};

    if (boot.settings)
    {
      state.threshold = boot.settings.shutdown_battery_percent;
      state.delaySeconds = boot.settings.shutdown_delay_seconds;

      if ($('set-host')) $('set-host').value = boot.settings.snmp_host || '';
      if ($('set-snmp-version')) $('set-snmp-version').value = (boot.settings.snmp_version === '2c') ? '2c' : '1';
      if ($('set-community')) $('set-community').value = boot.settings.snmp_community || '';
      if ($('set-threshold')) $('set-threshold').value = boot.settings.shutdown_battery_percent;
      if ($('set-delay')) $('set-delay').value = boot.settings.shutdown_delay_seconds;

      setText('m-threshold', t('threshold_percent', { n: boot.settings.shutdown_battery_percent }));
      setText('m-delay', t('delay_seconds', { n: boot.settings.shutdown_delay_seconds }));
    }

    if (boot.ups)
    {
      state.lastUpsJson = boot.live ? JSON.stringify(boot.ups) : '';
      updateOverview(boot.ups, { live: !!boot.live });
    }
    else
    {
      markServerOffline();
    }

    document.documentElement.classList.add('sl-data-ready');
  }

  async function tick()
  {
    if (state.ticking)
      return;

    if (!state.token || !document.documentElement.classList.contains('sl-session'))
      return;

    if (document.hidden)
      return;

    const tab = activeTab();

    state.ticking = true;

    try
    {
      if ((tab === 'overview') || (tab === 'settings'))
      {
        await refreshUps();
      }
      else
      {
        if (tab === 'charts')
        {
          const prevIn = state.inputPhaseCount;
          const prevOut = state.outputPhaseCount;

          await refreshUps();

          const phaseChanged = (prevIn !== state.inputPhaseCount) || (prevOut !== state.outputPhaseCount);
          const due = ((Date.now() - state.lastChartAt) >= CHART_POLL_MS);

          if (due || phaseChanged || !state.lastSampleCount)
            await refreshHistory(phaseChanged);
        }
      }
    }
    catch (e)
    {
      markServerOffline();
      console.warn(e);
    }
    finally
    {
      state.ticking = false;
    }
  }

  function bindUi()
  {
    $('login-form').addEventListener('submit', async (e) =>
    {
      e.preventDefault();

      const err = $('login-error');

      err.hidden = true;

      try
      {
        const data = await api('/api/login',
        {
          method: 'POST',
          body: JSON.stringify(
          { password: $('login-password').value }),
        });

        state.token = data.token;
        localStorage.setItem(TOKEN_KEY, state.token);
        $('login-password').value = '';
        showApp();
        await refreshSettings();
        state.lastUpsJson = '';
        await refreshUps();
        document.documentElement.classList.add('sl-data-ready');
      }
      catch (ex)
      {
        err.textContent = friendlyError(ex) || t('login_error_generic');
        err.hidden = false;
      }
    });

    $('btn-logout').addEventListener('click', () => logout(true));

    document.querySelectorAll('.tab').forEach((btn) =>
    {
      btn.addEventListener('click', async () =>
      {
        document.querySelectorAll('.tab').forEach((b) => b.classList.remove('is-active'));
        document.querySelectorAll('.panel').forEach((p) => p.classList.remove('is-active'));
        btn.classList.add('is-active');

        $(`panel-${btn.dataset.tab}`).classList.add('is-active');

        if (btn.dataset.tab === 'charts')
        {
          try
          {
            await refreshUps();
            await refreshHistory(true);
          }
          catch (_)
          {
          }
        }

        if (btn.dataset.tab === 'settings')
        {
          try
          {
            await refreshSettings();
            await refreshUps();
          }
          catch (_)
          {
          }
        }

        if (btn.dataset.tab === 'overview')
        {
          state.lastUpsJson = '';

          try
          {
            await refreshUps();
          }
          catch (_)
          {
          }
        }
      });
    });

    $('btn-discover').addEventListener('click', async () =>
    {
      const btn = $('btn-discover');
      const panel = $('discover-panel');
      const status = $('discover-status');
      const list = $('discover-list');

      btn.disabled = true;
      panel.hidden = false;
      list.innerHTML = '';
      status.textContent = t('settings_discover_scanning');

      try
      {
        const data = await api('/api/discover',
        { method: 'POST', body: '{}' });
        const devices = data.devices || [];

        if (!devices.length)
        {
          status.textContent = t('settings_discover_empty');

          return;
        }

        status.textContent = t('settings_discover_found',
        { n: devices.length });

        devices.forEach((d) =>
        {
          const item = document.createElement('button');
          const title = document.createElement('strong');
          const meta = document.createElement('span');

          item.type = 'button';
          item.className = 'discover-item';
          title.textContent = d.name || d.ip || '';

          const metaParts = [];

          if (d.uid)
            metaParts.push(`UID ${d.uid}`);

          if (d.mac)
            metaParts.push(d.mac);

          if (d.rev)
            metaParts.push(`Rev. ${d.rev}`);

          if (d.version)
            metaParts.push(d.version);

          meta.textContent = metaParts.join(' · ');
          item.appendChild(title);
          item.appendChild(meta);
          item.addEventListener('click', () =>
          {
            $('set-host').value = d.ip || '';
            $('set-host').focus();
            list.innerHTML = '';
            status.textContent = '';
            panel.hidden = true;
          });
          list.appendChild(item);
        });
      }
      catch (ex)
      {
        status.textContent = friendlyError(ex);
      }
      finally
      {
        btn.disabled = false;
      }
    });

    $('settings-form').addEventListener('submit', async (e) =>
    {
      e.preventDefault();

      const msg = $('settings-msg');

      msg.hidden = true;

      try
      {
        const body =
        {
          snmp_host: $('set-host').value.trim(),
          snmp_community: $('set-community').value.trim(),
          snmp_version: $('set-snmp-version').value,
          shutdown_battery_percent: Number($('set-threshold').value),
          shutdown_delay_seconds: Number($('set-delay').value),
        };

        const s = await api('/api/settings',
        { method: 'POST', body: JSON.stringify(body) });

        state.threshold = s.shutdown_battery_percent;
        state.delaySeconds = s.shutdown_delay_seconds;
        setText('m-threshold', t('threshold_percent', { n: s.shutdown_battery_percent }));
        setText('m-delay', t('delay_seconds', { n: s.shutdown_delay_seconds }));
        msg.textContent = t('settings_saved');
        msg.className = 'form-msg ok';
        msg.hidden = false;
      }
      catch (ex)
      {
        msg.textContent = friendlyError(ex);
        msg.className = 'form-msg err';
        msg.hidden = false;
      }
    });

    $('password-form').addEventListener('submit', async (e) =>
    {
      e.preventDefault();

      const msg = $('password-msg');
      const n1 = $('pwd-new').value;
      const n2 = $('pwd-new2').value;

      msg.hidden = true;

      if (n1 !== n2)
      {
        msg.textContent = t('password_mismatch');
        msg.className = 'form-msg err';
        msg.hidden = false;

        return;
      }

      try
      {
        await api('/api/password',
        {
          method: 'POST',
          body: JSON.stringify(
          {
            old_password: $('pwd-old').value,
            new_password: n1,
          }),
        });

        $('pwd-old').value = '';
        $('pwd-new').value = '';
        $('pwd-new2').value = '';

        msg.textContent = t('password_changed');
        msg.className = 'form-msg ok';
        msg.hidden = false;
      }
      catch (ex)
      {
        msg.textContent = friendlyError(ex);
        msg.className = 'form-msg err';
        msg.hidden = false;
      }
    });

    let resizeTimer = 0;

    window.addEventListener('resize', () =>
    {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() =>
      {
        if (activeTab() === 'charts')
          refreshHistory(true).catch(() => {});
      }, 300);
    });

    document.addEventListener('visibilitychange', () =>
    {
      if (!document.hidden)
        tick();
    });
  }

  async function loadAppVersion()
  {
    try
    {
      const res = await fetch('/health',
      { cache: 'no-store' });

      if (!res.ok)
        return;

      const data = await res.json();
      const ver = (data && data.version) ? String(data.version) : '';

      document.querySelectorAll('[data-app-version]').forEach((el) =>
      {
        if (!ver)
        {
          el.hidden = true;
          el.textContent = '';
          return;
        }

        el.textContent = t('version_label',
        { n: ver });
        el.hidden = false;
      });
    }
    catch (_)
    {
    }
  }

  async function boot()
  {
    if (window.SLLang)
      SLLang.apply();

    setText('ups-ident', t('overview_waiting'));
    setText('m-bat-status', t('battery_status_label'));

    await loadAppVersion();
    bindUi();

    if (!state.token)
    {
      showLogin();
      document.documentElement.classList.add('sl-data-ready');
    }
    else
    {
      showApp();
      applyBootData();

      try
      {
        await refreshSettings();
        await refreshUps();
      }
      catch (_)
      {
        logout(false);
      }
    }

    setInterval(tick, POLL_MS);
  }

  boot();
})();
