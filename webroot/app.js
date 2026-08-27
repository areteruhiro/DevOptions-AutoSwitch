(() => {
  "use strict";

  const DATA_DIR = "/data/adb/devmode-cloak";
  const PACKAGE_PATTERN = /^[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+$/;
  const translations = {
    ja: {
      heading: "対象アプリ",
      description: "開発者向けオプションを一時的に隠すアプリを選択します。",
      search: "アプリ名またはパッケージ名で検索",
      language: "表示言語",
      loading: "アプリ一覧を読み込んでいます…",
      empty: "該当するアプリがありません。",
      selected: "{count}件を選択",
      results: "{count}件",
      targetAria: "{label}を対象にする",
      unsaved: "未適用の変更があります",
      saving: "保存しています",
      applied: "{count}件を適用しました",
      saveFailed: "保存できませんでした: {detail}",
      loadFailed: "読み込みに失敗しました: {detail}",
      reopen: "WebUIを開き直してください",
      webuiUnavailable: "WebUI APIを利用できません",
      openInWebui: "SukiSU / KernelSUのWebUIから開いてください",
      exitCode: "終了コード {code}",
      apply: "Apply",
      applying: "適用中…"
    },
    en: {
      heading: "Target apps",
      description: "Select apps that should temporarily hide Developer Options.",
      search: "Search by app or package name",
      language: "Display language",
      loading: "Loading installed apps…",
      empty: "No matching apps.",
      selected: "{count} selected",
      results: "{count} apps",
      targetAria: "Enable for {label}",
      unsaved: "You have unapplied changes",
      saving: "Saving changes",
      applied: "Applied to {count} apps",
      saveFailed: "Could not save: {detail}",
      loadFailed: "Could not load apps: {detail}",
      reopen: "Close and reopen the WebUI",
      webuiUnavailable: "The WebUI API is unavailable",
      openInWebui: "Open this page from the SukiSU / KernelSU WebUI",
      exitCode: "Exit code {code}",
      apply: "Apply",
      applying: "Applying…"
    }
  };
  const elements = {
    language: document.getElementById("language"),
    search: document.getElementById("search"),
    selectionCount: document.getElementById("selectionCount"),
    resultCount: document.getElementById("resultCount"),
    loading: document.getElementById("loading"),
    empty: document.getElementById("empty"),
    appList: document.getElementById("appList"),
    status: document.getElementById("status"),
    apply: document.getElementById("apply")
  };

  let apps = [];
  let selected = new Set();
  let language = preferredLanguage();
  let statusState = null;
  let isApplying = false;

  function preferredLanguage() {
    try {
      const saved = localStorage.getItem("language");
      if (saved === "ja" || saved === "en") {
        return saved;
      }
    } catch (_) {
      // Continue with the device language when storage is unavailable.
    }
    return navigator.language.toLowerCase().startsWith("ja") ? "ja" : "en";
  }

  function text(key, values = {}) {
    let value = translations[language][key] || translations.ja[key] || key;
    for (const [name, replacement] of Object.entries(values)) {
      value = value.replaceAll(`{${name}}`, String(replacement));
    }
    return value;
  }

  function setStatus(key, values = {}) {
    statusState = key ? { key, values } : null;
    elements.status.textContent = key ? text(key, values) : "";
  }

  function applyLanguage() {
    document.documentElement.lang = language;
    elements.language.value = language;
    elements.language.setAttribute("aria-label", text("language"));
    elements.search.placeholder = text("search");
    document.querySelectorAll("[data-i18n]").forEach((element) => {
      element.textContent = text(element.dataset.i18n);
    });
    elements.apply.textContent = text(isApplying ? "applying" : "apply");
    updateSelectionCount();
    if (statusState) {
      elements.status.textContent = text(statusState.key, statusState.values);
    }
  }

  function exec(command) {
    return new Promise((resolve, reject) => {
      if (!window.ksu || typeof window.ksu.exec !== "function") {
        reject(new Error(text("webuiUnavailable")));
        return;
      }

      const callbackName = `devOptionsAutoSwitch_${Date.now()}_${Math.random().toString(36).slice(2)}`;
      window[callbackName] = (errno, stdout, stderr) => {
        delete window[callbackName];
        resolve({ errno, stdout: stdout || "", stderr: stderr || "" });
      };

      try {
        window.ksu.exec(command, JSON.stringify({}), callbackName);
      } catch (error) {
        delete window[callbackName];
        reject(error);
      }
    });
  }

  function bridgePackages(type) {
    try {
      return JSON.parse(window.ksu.listPackages(type))
        .filter((name) => PACKAGE_PATTERN.test(name));
    } catch (_) {
      return [];
    }
  }

  function bridgePackageInfo(packageNames) {
    try {
      return JSON.parse(window.ksu.getPackagesInfo(JSON.stringify(packageNames)));
    } catch (_) {
      return [];
    }
  }

  function notify(key, values = {}) {
    setStatus(key, values);
    try {
      window.ksu.toast(text(key, values));
    } catch (_) {
      // The visible status remains available when toast is unsupported.
    }
  }

  async function loadTargets() {
    const command = `sed 's/[[:space:]]*$//' '${DATA_DIR}/targets.txt' 2>/dev/null | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d'`;
    const result = await exec(command);
    if (result.errno !== 0 && result.stderr) {
      throw new Error(result.stderr);
    }
    return new Set(result.stdout.split(/\r?\n/).filter((name) => PACKAGE_PATTERN.test(name)));
  }

  async function loadPackageNames() {
    const fromBridge = bridgePackages("user");
    if (fromBridge.length) {
      return fromBridge;
    }
    const result = await exec("pm list packages -3 | sed 's/^package://' | sort");
    return result.stdout.split(/\r?\n/).filter((name) => PACKAGE_PATTERN.test(name));
  }

  function loadPackageInfo(packageNames) {
    const byPackage = new Map();
    const chunkSize = 80;
    for (let index = 0; index < packageNames.length; index += chunkSize) {
      const chunk = packageNames.slice(index, index + chunkSize);
      for (const info of bridgePackageInfo(chunk)) {
        if (info && PACKAGE_PATTERN.test(info.packageName || "")) {
          byPackage.set(info.packageName, info);
        }
      }
    }
    return packageNames.map((packageName) => {
      const info = byPackage.get(packageName) || {};
      return { packageName, label: String(info.appLabel || packageName) };
    });
  }

  function updateSelectionCount() {
    elements.selectionCount.textContent = text("selected", { count: selected.size });
  }

  function createAppRow(app) {
    const label = document.createElement("label");
    label.className = "app-row";
    label.setAttribute("role", "listitem");

    const icon = document.createElement("img");
    icon.className = "app-icon";
    icon.alt = "";
    icon.loading = "lazy";
    icon.src = `ksu://icon/${app.packageName}`;
    icon.addEventListener("error", () => {
      icon.style.visibility = "hidden";
    }, { once: true });

    const appText = document.createElement("div");
    const appName = document.createElement("div");
    appName.className = "app-name";
    appName.textContent = app.label;
    const packageName = document.createElement("div");
    packageName.className = "package-name";
    packageName.textContent = app.packageName;
    appText.append(appName, packageName);

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = selected.has(app.packageName);
    checkbox.setAttribute("aria-label", text("targetAria", { label: app.label }));
    checkbox.addEventListener("change", () => {
      if (checkbox.checked) {
        selected.add(app.packageName);
      } else {
        selected.delete(app.packageName);
      }
      updateSelectionCount();
      elements.apply.disabled = false;
      setStatus("unsaved");
    });

    label.append(icon, appText, checkbox);
    return label;
  }

  function render() {
    const locale = language === "ja" ? "ja" : "en";
    const query = elements.search.value.trim().toLocaleLowerCase(locale);
    const visibleApps = apps.filter((app) => {
      return !query
        || app.label.toLocaleLowerCase(locale).includes(query)
        || app.packageName.toLowerCase().includes(query);
    });

    elements.appList.replaceChildren(...visibleApps.map(createAppRow));
    elements.appList.classList.toggle("hidden", visibleApps.length === 0);
    elements.empty.classList.toggle("hidden", visibleApps.length !== 0);
    elements.resultCount.textContent = text("results", { count: visibleApps.length });
  }

  function saveCommand(packageNames) {
    const commands = [
      `data_dir='${DATA_DIR}'`,
      'target_tmp="$data_dir/targets.txt.tmp"',
      'umask 077',
      'mkdir -p "$data_dir"',
      ': > "$target_tmp"'
    ];
    for (const packageName of packageNames) {
      commands.push(`printf '%s\\n' '${packageName}' >> "$target_tmp"`);
    }
    commands.push(
      'chown 0:0 "$target_tmp"',
      'chmod 0600 "$target_tmp"',
      'mv -f "$target_tmp" "$data_dir/targets.txt"'
    );
    return commands.join("; ");
  }

  async function applySelection() {
    const packageNames = [...selected].filter((name) => PACKAGE_PATTERN.test(name)).sort();
    isApplying = true;
    elements.apply.disabled = true;
    elements.apply.textContent = text("applying");
    setStatus("saving");

    try {
      const result = await exec(saveCommand(packageNames));
      if (result.errno !== 0) {
        throw new Error(result.stderr || text("exitCode", { code: result.errno }));
      }
      notify("applied", { count: packageNames.length });
    } catch (error) {
      elements.apply.disabled = false;
      notify("saveFailed", { detail: error.message });
    } finally {
      isApplying = false;
      elements.apply.textContent = text("apply");
    }
  }

  async function initialize() {
    applyLanguage();
    try {
      if (!window.ksu) {
        throw new Error(text("openInWebui"));
      }
      selected = await loadTargets();
      const packageNames = await loadPackageNames();
      apps = loadPackageInfo(packageNames);
      for (const packageName of selected) {
        if (!apps.some((app) => app.packageName === packageName)) {
          apps.push({ packageName, label: packageName });
        }
      }
      apps.sort((left, right) => left.label.localeCompare(right.label, language));
      elements.loading.classList.add("hidden");
      updateSelectionCount();
      render();
    } catch (error) {
      elements.loading.removeAttribute("data-i18n");
      elements.loading.textContent = text("loadFailed", { detail: error.message });
      setStatus("reopen");
    }
  }

  elements.language.addEventListener("change", () => {
    language = elements.language.value === "en" ? "en" : "ja";
    try {
      localStorage.setItem("language", language);
    } catch (_) {
      // Language still applies for the current session.
    }
    apps.sort((left, right) => left.label.localeCompare(right.label, language));
    applyLanguage();
    if (apps.length) {
      render();
    }
  });
  elements.search.addEventListener("input", render);
  elements.apply.addEventListener("click", applySelection);
  initialize();
})();
