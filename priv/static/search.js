const searchForm = document.getElementById("search-form");
const resultsSummary = document.getElementById("results-summary");
let resultsBody = document.getElementById("results-body");
const clearLink = document.getElementById("clear-link");
const logTypeSelect = searchForm?.querySelector('select[name="log_type"]');

const filters = ["time_from", "time_to", "log_type", "host", "program", "message"];

function formParams() {
  const params = new URLSearchParams();

  for (const name of filters) {
    const value = searchForm.elements[name]?.value.trim() ?? "";

    if (value) {
      params.set(name, value);
    }
  }

  return params;
}

function paramsObject(params) {
  return Object.fromEntries(params.entries());
}

function fillFormFromParams(params) {
  for (const name of filters) {
    const field = searchForm.elements[name];

    if (field) {
      field.value = params.get(name) ?? "";
    }
  }
}

function setSummary(...items) {
  resultsSummary.replaceChildren(...items.map((item) => {
    const span = document.createElement("span");
    span.textContent = item;
    return span;
  }));
}

function emptyMessage(message, className = "empty") {
  const element = document.createElement("p");
  element.id = "results-body";
  element.className = className;
  element.textContent = message;
  return element;
}

function replaceResultsBody(element) {
  resultsBody.replaceWith(element);
  resultsBody = element;
}

function showLoading() {
  setSummary("検索中");
  replaceResultsBody(emptyMessage("検索中", "empty searching"));
}

function showError(message) {
  setSummary("検索エラー");
  replaceResultsBody(emptyMessage(message));
}

function renderLogs(logs) {
  setSummary(`${logs.length} 件`, "最新50件のみ表示");

  if (logs.length === 0) {
    replaceResultsBody(emptyMessage("該当するログはありません。"));
    return;
  }

  const wrapper = document.createElement("div");
  wrapper.id = "results-body";
  wrapper.className = "table-wrap";

  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headerRow = document.createElement("tr");
  ["Time", "Log", "Host", "Program", "Message"].forEach((label) => {
    const th = document.createElement("th");
    th.textContent = label;
    headerRow.append(th);
  });
  thead.append(headerRow);

  const tbody = document.createElement("tbody");
  logs.forEach((log) => {
    const row = document.createElement("tr");
    appendCell(row, log.display_time || "");
    appendLogTypeCell(row, log.log_type || "unknown");
    appendCell(row, log.host || "");
    appendCell(row, log.program || "");
    appendCell(row, log.msg || "");
    tbody.append(row);
  });

  table.append(thead, tbody);
  wrapper.append(table);
  replaceResultsBody(wrapper);
}

function appendCell(row, value) {
  const cell = document.createElement("td");
  cell.textContent = value;
  row.append(cell);
}

function appendLogTypeCell(row, value) {
  const cell = document.createElement("td");
  const badge = document.createElement("span");
  badge.className = `log-type log-type-${cssToken(value)}`;
  badge.textContent = value;
  cell.append(badge);
  row.append(cell);
}

function cssToken(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9_-]/g, "-") || "unknown";
}

async function loadLogTypes() {
  const response = await fetch("/api/log-types");

  if (!response.ok) {
    throw new Error("LOG の選択肢を取得できませんでした。");
  }

  const payload = await response.json();

  for (const logType of payload.log_types ?? []) {
    const option = document.createElement("option");
    option.value = logType;
    option.textContent = logType;
    logTypeSelect.appendChild(option);
  }
}

async function search(params) {
  showLoading();

  const response = await fetch("/api/logs", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(paramsObject(params)),
  });

  if (!response.ok) {
    throw new Error("検索に失敗しました。");
  }

  const payload = await response.json();
  renderLogs(payload.logs ?? []);
}

if (searchForm && resultsSummary && resultsBody && clearLink && logTypeSelect) {
  const initialParams = new URLSearchParams(window.location.search);

  loadLogTypes()
    .then(() => {
      fillFormFromParams(initialParams);

      if (initialParams.toString()) {
        history.replaceState(null, "", "/");
        return search(initialParams);
      }

      return undefined;
    })
    .catch((error) => showError(error.message));

  searchForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const params = formParams();
    history.replaceState(null, "", "/");

    search(params).catch((error) => showError(error.message));
  });

  clearLink.addEventListener("click", (event) => {
    event.preventDefault();
    searchForm.reset();
    history.replaceState(null, "", "/");
    setSummary("検索を実施してください");
    replaceResultsBody(emptyMessage("検索条件を入力して検索ボタンを押してください。"));
  });
}
