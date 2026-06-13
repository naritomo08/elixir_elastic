const searchForm = document.getElementById("search-form");
const resultsSummary = document.getElementById("results-summary");
const resultsBody = document.getElementById("results-body");
const clearLink = document.getElementById("clear-link");
const logTypeSelect = searchForm?.querySelector('select[name="log_type"]');

const filters = ["time_from", "time_to", "log_type", "host", "program", "message"];

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

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

function fillFormFromParams(params) {
  for (const name of filters) {
    const field = searchForm.elements[name];

    if (field) {
      field.value = params.get(name) ?? "";
    }
  }
}

function showLoading() {
  resultsSummary.innerHTML = "<span>検索中</span>";
  resultsBody.className = "empty searching";
  resultsBody.textContent = "検索中";
}

function showError(message) {
  resultsSummary.innerHTML = "<span>検索エラー</span>";
  resultsBody.className = "empty";
  resultsBody.textContent = message;
}

function renderLogs(logs) {
  if (logs.length === 0) {
    resultsSummary.innerHTML = "<span>0 件</span><span>最新50件のみ表示</span>";
    resultsBody.className = "empty";
    resultsBody.textContent = "該当するログはありません。";
    return;
  }

  resultsSummary.innerHTML = `<span>${logs.length} 件</span><span>最新50件のみ表示</span>`;
  resultsBody.className = "table-wrap";
  resultsBody.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Time</th>
          <th>Log</th>
          <th>Host</th>
          <th>Program</th>
          <th>Message</th>
        </tr>
      </thead>
      <tbody>
        ${logs.map((log) => `
          <tr>
            <td>${escapeHtml(log.display_time)}</td>
            <td><span class="log-type log-type-${escapeHtml(log.log_type || "unknown")}">${escapeHtml(log.log_type || "unknown")}</span></td>
            <td>${escapeHtml(log.host)}</td>
            <td>${escapeHtml(log.program)}</td>
            <td>${escapeHtml(log.msg)}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>
  `;
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

  const response = await fetch(`/api/logs?${params.toString()}`);

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
        return search(initialParams);
      }

      return undefined;
    })
    .catch((error) => showError(error.message));

  searchForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const params = formParams();
    history.replaceState(null, "", params.toString() ? `/?${params.toString()}` : "/");

    search(params).catch((error) => showError(error.message));
  });

  clearLink.addEventListener("click", (event) => {
    event.preventDefault();
    searchForm.reset();
    history.replaceState(null, "", "/");
    resultsSummary.innerHTML = "<span>検索を実施してください</span>";
    resultsBody.className = "empty";
    resultsBody.textContent = "検索条件を入力して検索ボタンを押してください。";
  });
}
