(function (global) {
  const STORAGE_KEY = "skuplink_lang";
  const DEFAULT_LANG = "ru";

  const dictionaries = {
    ru: {
      app_title: "SkupLink",
      brand: "SkupLink",
      version_label: "v. {n}",
      lang_aria: "Язык интерфейса",

      login_title: "Контроль ИБП",
      login_lead: "Мониторинг, графики и безопасное завершение работы",
      login_password: "Пароль",
      login_password_placeholder: "Введите пароль",
      login_submit: "Войти",
      login_hint_prefix: "По умолчанию:",
      login_error_generic: "Ошибка входа",
      login_auth_required: "Требуется авторизация",
      error_network: "Нет связи с сервером",
      error_request: "Ошибка запроса",
      error_http: "Ошибка HTTP {code}",

      nav_aria: "Разделы",
      tab_overview: "Обзор",
      tab_charts: "Графики",
      tab_settings: "Настройки",
      logout: "Выход",

      overview_title: "Состояние ИБП",
      overview_waiting: "Ожидание данных…",
      metric_input: "Вход",
      metric_output: "Выход",
      metric_load: "Нагрузка",
      metric_battery: "АКБ",
      unit_v: "В",
      unit_hz: "Гц",
      unit_w: "Вт",
      unit_percent: "%",
      unit_min: "мин",
      unit_sec: "с",

      charge_title: "Ёмкость АКБ",
      battery_status_label: "Статус АКБ",
      power_time_title: "Информация",
      label_topology: "Топология",
      label_work_mode: "Режим работы",
      label_remain_min: "Осталось минут",
      label_power: "Мощность",
      label_shutdown_threshold: "Порог выключения",
      label_shutdown_delay: "Задержка выключения",

      phases_input: "Вход",
      phases_output: "Выход",
      phase_voltage: "Напряжение",
      phase_frequency: "Частота",
      phase_r: "R",
      phase_s: "S",
      phase_t: "T",

      charts_title: "Графики",
      charts_sub: "История за последний час",
      chart_vin: "Входное напряжение",
      chart_vout: "Выходное напряжение",
      chart_load: "Нагрузка",
      chart_batv: "Напряжение АКБ",
      chart_no_data: "Нет данных — подождите несколько циклов опроса",

      settings_title: "Настройки",
      settings_sub: "SNMP-карта, порог выключения и пароль доступа",
      settings_snmp_title: "SNMP и выключение",
      settings_host: "IP-адрес SNMP-карты",
      settings_discover: "Найти",
      settings_discover_scanning: "Поиск устройств…",
      settings_discover_empty: "Устройства не найдены",
      settings_discover_found: "Найдено: {n}",
      settings_snmp_version: "Версия SNMP",
      settings_community: "Community (read)",
      settings_threshold: "Порог ёмкости АКБ для выключения ПК, {unit_percent}",
      settings_delay: "Задержка до выключения ПК, секунды",
      settings_help:
        "При работе от АКБ, когда ёмкость упадёт до порога, SkupLink запускает отложенное выключение. Если за это время питание вернётся в сеть — выключение отменяется. На Linux задержка округляется вверх до минут.",
      settings_save: "Сохранить",
      settings_saved: "Настройки сохранены",

      password_title: "Смена пароля",
      password_old: "Текущий пароль",
      password_new: "Новый пароль",
      password_new2: "Повтор нового пароля",
      password_submit: "Сменить пароль",
      password_mismatch: "Новые пароли не совпадают",
      password_changed: "Пароль изменён",

      conn_ok: "SNMP OK",
      conn_no_snmp: "ИБП без SNMP",
      conn_no_server: "нет сервера",
      server_unavailable: "Сервер SkupLink недоступен",
      server_unavailable_suffix: "Нет связи с сервером",
      ups_generic: "ИБП",
      ups_no_snmp_data: "Нет данных с SNMP-карты",

      work_mode_mains: "Сеть",
      work_mode_battery: "АКБ · {min} {unit_min} {sec} {unit_sec}",
      remain_minutes: "{min} {unit_min}",
      power_watts: "{w} {unit_w}",
      threshold_percent: "{n} {unit_percent}",
      delay_seconds: "{n} {unit_sec}",
      phase_in_value: "{v} {unit_v} · {hz} {unit_hz}",
      phase_out_value: "{v} {unit_v} · {load}{unit_percent} · {w} {unit_w}",
      phase_freq_value: "{hz} {unit_hz}",
      dash: "—",

      topology_unknown: "Неизвестно",
      topology_single_phase: "Однофазный",
      topology_three_phase_in_out: "3ф вход / 3ф выход",
      topology_three_phase_in_single_out: "3ф вход / 1ф выход",

      battery_unknown: "Неизвестно",
      battery_normal: "Норма",
      battery_low: "Низкий заряд",
      battery_depleted: "АКБ требует замены",
    },

    en: {
      app_title: "SkupLink",
      brand: "SkupLink",
      version_label: "v. {n}",
      lang_aria: "Interface language",

      login_title: "UPS control",
      login_lead: "Monitoring, charts, and safe computer shutdown",
      login_password: "Password",
      login_password_placeholder: "Enter password",
      login_submit: "Sign in",
      login_hint_prefix: "Default:",
      login_error_generic: "Sign-in failed",
      login_auth_required: "Authorization required",
      error_network: "Unable to reach the server",
      error_request: "Request failed",
      error_http: "HTTP error {code}",

      nav_aria: "Sections",
      tab_overview: "Overview",
      tab_charts: "Charts",
      tab_settings: "Settings",
      logout: "Sign out",

      overview_title: "UPS status",
      overview_waiting: "Waiting for data…",
      metric_input: "Input",
      metric_output: "Output",
      metric_load: "Load",
      metric_battery: "Battery",
      unit_v: "V",
      unit_hz: "Hz",
      unit_w: "W",
      unit_percent: "%",
      unit_min: "min",
      unit_sec: "s",

      charge_title: "Battery charge",
      battery_status_label: "Battery status",
      power_time_title: "Information",
      label_topology: "Topology",
      label_work_mode: "Operating mode",
      label_remain_min: "Minutes remaining",
      label_power: "Power",
      label_shutdown_threshold: "Shutdown threshold",
      label_shutdown_delay: "Shutdown delay",

      phases_input: "Input",
      phases_output: "Output",
      phase_voltage: "Voltage",
      phase_frequency: "Frequency",
      phase_r: "R",
      phase_s: "S",
      phase_t: "T",

      charts_title: "Charts",
      charts_sub: "History for the last hour",
      chart_vin: "Input voltage",
      chart_vout: "Output voltage",
      chart_load: "Load",
      chart_batv: "Battery voltage",
      chart_no_data: "No data yet — wait for a few poll cycles",

      settings_title: "Settings",
      settings_sub: "SNMP card, shutdown threshold, and access password",
      settings_snmp_title: "SNMP and shutdown",
      settings_host: "SNMP card IP address",
      settings_discover: "Find",
      settings_discover_scanning: "Searching for devices…",
      settings_discover_empty: "No devices found",
      settings_discover_found: "Found: {n}",
      settings_snmp_version: "SNMP version",
      settings_community: "Community (read)",
      settings_threshold: "Battery charge threshold to shut down the PC, {unit_percent}",
      settings_delay: "Delay before shutting down the PC, seconds",
      settings_help:
        "While running on battery, when charge falls to the threshold SkupLink schedules a delayed shutdown. If mains power returns during the delay, shutdown is cancelled. On Linux the delay is rounded up to whole minutes.",
      settings_save: "Save",
      settings_saved: "Settings saved",

      password_title: "Change password",
      password_old: "Current password",
      password_new: "New password",
      password_new2: "Confirm new password",
      password_submit: "Change password",
      password_mismatch: "New passwords do not match",
      password_changed: "Password changed",

      conn_ok: "SNMP OK",
      conn_no_snmp: "No UPS SNMP",
      conn_no_server: "No server",
      server_unavailable: "SkupLink server unavailable",
      server_unavailable_suffix: "Server offline",
      ups_generic: "UPS",
      ups_no_snmp_data: "No data from SNMP card",

      work_mode_mains: "Utility",
      work_mode_battery: "Battery · {min} {unit_min} {sec} {unit_sec}",
      remain_minutes: "{min} {unit_min}",
      power_watts: "{w} {unit_w}",
      threshold_percent: "{n} {unit_percent}",
      delay_seconds: "{n} {unit_sec}",
      phase_in_value: "{v} {unit_v} · {hz} {unit_hz}",
      phase_out_value: "{v} {unit_v} · {load}{unit_percent} · {w} {unit_w}",
      phase_freq_value: "{hz} {unit_hz}",
      dash: "—",

      topology_unknown: "Unknown",
      topology_single_phase: "Single-phase",
      topology_three_phase_in_out: "3ph in / 3ph out",
      topology_three_phase_in_single_out: "3ph in / 1ph out",

      battery_unknown: "Unknown",
      battery_normal: "Normal",
      battery_low: "Low charge",
      battery_depleted: "Battery needs replacement",
    },
  };

  let current = localStorage.getItem(STORAGE_KEY) || DEFAULT_LANG;

  if (!dictionaries[current]) current = DEFAULT_LANG;

  function dict() {
    return dictionaries[current] || dictionaries[DEFAULT_LANG];
  }

  function t(key, vars) {
    const d = dict();
    let s = d[key];

    if (s == null && current !== DEFAULT_LANG)
      s = dictionaries[DEFAULT_LANG][key];

    if (s == null) s = key;

    const merged = {
      unit_v: d.unit_v,
      unit_hz: d.unit_hz,
      unit_w: d.unit_w,
      unit_percent: d.unit_percent,
      unit_min: d.unit_min,
      unit_sec: d.unit_sec,
    };

    if (vars) {
      for (const name in vars) {
        if (Object.prototype.hasOwnProperty.call(vars, name))
          merged[name] = vars[name];
      }
    }

    s = String(s).replace(/\{(\w+)\}/g, function (_, name) {
      return merged[name] != null ? String(merged[name]) : "";
    });

    return s;
  }

  function syncLangSwitcher() {
    document.querySelectorAll(".lang-btn").forEach(function (btn) {
      const on = btn.getAttribute("data-lang") === current;

      btn.classList.toggle("is-active", on);
      btn.setAttribute("aria-pressed", on ? "true" : "false");
    });
  }

  function bindLangSwitcher() {
    document.querySelectorAll(".lang-btn").forEach(function (btn) {
      if (btn.dataset.slBound === "1") return;

      btn.dataset.slBound = "1";
      btn.addEventListener("click", function () {
        setLang(btn.getAttribute("data-lang"));
      });
    });
  }

  function apply() {
    document.documentElement.lang = current;
    document.title = t("app_title");

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      el.textContent = t(el.getAttribute("data-i18n"));
    });

    document.querySelectorAll("[data-i18n-placeholder]").forEach(function (el) {
      el.setAttribute(
        "placeholder",
        t(el.getAttribute("data-i18n-placeholder")),
      );
    });

    document.querySelectorAll("[data-i18n-aria]").forEach(function (el) {
      el.setAttribute("aria-label", t(el.getAttribute("data-i18n-aria")));
    });

    bindLangSwitcher();
    syncLangSwitcher();
  }

  function setLang(code) {
    if (!dictionaries[code]) return;

    current = code;

    try {
      localStorage.setItem(STORAGE_KEY, code);
    } catch (e) {}

    apply();
  }

  global.SLLang = {
    t: t,
    apply: apply,
    setLang: setLang,
  };
})(window);
