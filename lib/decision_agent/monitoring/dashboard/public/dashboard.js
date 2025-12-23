// Dashboard state
let ws = null;
let charts = {};
let previousStats = null;
let reconnectInterval = null;

// Initialize dashboard on load
document.addEventListener('DOMContentLoaded', () => {
    initializeCharts();
    connectWebSocket();
    loadInitialData();

    // Refresh data periodically if WebSocket fails
    setInterval(() => {
        if (!ws || ws.readyState !== WebSocket.OPEN) {
            loadInitialData();
        }
    }, 5000);
});

// WebSocket connection
function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;

    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
        console.log('WebSocket connected');
        updateConnectionStatus(true);

        // Subscribe to updates
        ws.send(JSON.stringify({ action: 'subscribe' }));
        ws.send(JSON.stringify({ action: 'get_alerts' }));

        // Clear reconnect interval
        if (reconnectInterval) {
            clearInterval(reconnectInterval);
            reconnectInterval = null;
        }
    };

    ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        handleWebSocketMessage(message);
    };

    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        updateConnectionStatus(false);
    };

    ws.onclose = () => {
        console.log('WebSocket disconnected');
        updateConnectionStatus(false);

        // Attempt reconnect
        if (!reconnectInterval) {
            reconnectInterval = setInterval(() => {
                console.log('Attempting to reconnect...');
                connectWebSocket();
            }, 5000);
        }
    };
}

function handleWebSocketMessage(message) {
    switch (message.type) {
        case 'connected':
            console.log('Connected:', message.message);
            break;
        case 'stats':
            updateDashboard(message.data);
            break;
        case 'metric_update':
            handleMetricUpdate(message.event, message.data);
            break;
        case 'alert':
            handleNewAlert(message.data);
            break;
        case 'alerts':
            updateAlertsTable(message.data);
            break;
        case 'error':
            console.error('Server error:', message.message);
            break;
    }
}

function handleMetricUpdate(eventType, metric) {
    // Real-time metric update - refresh stats
    loadInitialData();
}

function handleNewAlert(alert) {
    showAlertBanner(alert);
    loadAlerts();
}

// Load initial data via API
async function loadInitialData() {
    try {
        const response = await fetch('/api/stats');
        const stats = await response.json();
        updateDashboard(stats);
    } catch (error) {
        console.error('Failed to load stats:', error);
    }

    loadAlerts();
    loadHealth();
}

async function loadAlerts() {
    try {
        const response = await fetch('/api/alerts');
        const alerts = await response.json();
        updateAlertsTable(alerts);
    } catch (error) {
        console.error('Failed to load alerts:', error);
    }
}

async function loadHealth() {
    try {
        const response = await fetch('/health');
        const health = await response.json();

        document.getElementById('agent-version').textContent = health.version;
        document.getElementById('ws-clients').textContent = health.websocket_clients;

        const totalMetrics = Object.values(health.metrics_count || {}).reduce((a, b) => a + b, 0);
        document.getElementById('metrics-stored').textContent = totalMetrics;
    } catch (error) {
        console.error('Failed to load health:', error);
    }
}

// Update dashboard with stats
function updateDashboard(stats) {
    updateSummaryCards(stats);
    updateCharts(stats);

    document.getElementById('last-update').textContent = new Date().toLocaleTimeString();
    previousStats = stats;
}

function updateSummaryCards(stats) {
    // Total Decisions
    const totalDecisions = stats.decisions?.total || 0;
    document.getElementById('total-decisions').textContent = formatNumber(totalDecisions);

    // Average Confidence
    const avgConfidence = stats.decisions?.avg_confidence || 0;
    document.getElementById('avg-confidence').textContent = avgConfidence.toFixed(2);

    // Success Rate
    const successRate = stats.performance?.success_rate || 0;
    document.getElementById('success-rate').textContent = `${(successRate * 100).toFixed(1)}%`;

    // P95 Latency
    const p95Latency = stats.performance?.p95_duration_ms || 0;
    document.getElementById('p95-latency').textContent = `${p95Latency.toFixed(0)}ms`;

    // Total Errors
    const totalErrors = stats.errors?.total || 0;
    document.getElementById('total-errors').textContent = formatNumber(totalErrors);

    // Update evaluators count
    const evaluatorsCount = stats.decisions?.evaluators_used?.length || 0;
    document.getElementById('evaluators-count').textContent = evaluatorsCount;

    // Calculate changes if we have previous stats
    if (previousStats) {
        updateChange('decisions-change', totalDecisions, previousStats.decisions?.total || 0);
        updateChange('confidence-change', avgConfidence, previousStats.decisions?.avg_confidence || 0);
        updateChange('success-change', successRate, previousStats.performance?.success_rate || 0);
        updateChange('latency-change', p95Latency, previousStats.performance?.p95_duration_ms || 0, true);
        updateChange('errors-change', totalErrors, previousStats.errors?.total || 0, true);
    }
}

function updateChange(elementId, current, previous, inverse = false) {
    const element = document.getElementById(elementId);
    const change = current - previous;

    if (change === 0) {
        element.textContent = 'No change';
        element.className = 'metric-change';
        return;
    }

    const positive = inverse ? change < 0 : change > 0;
    const sign = change > 0 ? '+' : '';

    element.textContent = `${sign}${change.toFixed(2)}`;
    element.className = `metric-change ${positive ? 'positive' : 'negative'}`;
}

// Initialize charts
function initializeCharts() {
    const chartOptions = {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
            legend: {
                labels: {
                    color: '#e6edf3'
                }
            }
        },
        scales: {
            y: {
                ticks: { color: '#8b949e' },
                grid: { color: '#21262d' }
            },
            x: {
                ticks: { color: '#8b949e' },
                grid: { color: '#21262d' }
            }
        }
    };

    // Throughput chart
    charts.throughput = new Chart(document.getElementById('throughput-chart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Decisions/min',
                data: [],
                borderColor: '#58a6ff',
                backgroundColor: 'rgba(88, 166, 255, 0.1)',
                tension: 0.4
            }]
        },
        options: chartOptions
    });

    // Distribution chart
    charts.distribution = new Chart(document.getElementById('distribution-chart'), {
        type: 'doughnut',
        data: {
            labels: [],
            datasets: [{
                data: [],
                backgroundColor: ['#58a6ff', '#3fb950', '#d29922', '#da3633', '#bc8cff']
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    labels: { color: '#e6edf3' }
                }
            }
        }
    });

    // Performance chart
    charts.performance = new Chart(document.getElementById('performance-chart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'P95',
                    data: [],
                    borderColor: '#3fb950',
                    backgroundColor: 'rgba(63, 185, 80, 0.1)',
                    tension: 0.4
                },
                {
                    label: 'P99',
                    data: [],
                    borderColor: '#d29922',
                    backgroundColor: 'rgba(210, 153, 34, 0.1)',
                    tension: 0.4
                }
            ]
        },
        options: chartOptions
    });

    // Error chart
    charts.error = new Chart(document.getElementById('error-chart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [{
                label: 'Errors',
                data: [],
                backgroundColor: '#da3633'
            }]
        },
        options: chartOptions
    });
}

function updateCharts(stats) {
    // Update distribution chart
    if (stats.decisions?.decision_distribution) {
        const distribution = stats.decisions.decision_distribution;
        charts.distribution.data.labels = Object.keys(distribution);
        charts.distribution.data.datasets[0].data = Object.values(distribution);
        charts.distribution.update();
    }

    // For time-series charts, we'd fetch from the API
    updateTimeSeriesCharts();
}

async function updateTimeSeriesCharts() {
    try {
        // Fetch decisions time series
        const decisionsResp = await fetch('/api/timeseries/decisions?bucket_size=60&time_range=3600');
        const decisionsData = await decisionsResp.json();

        if (decisionsData.length > 0) {
            charts.throughput.data.labels = decisionsData.map(d => new Date(d.timestamp).toLocaleTimeString());
            charts.throughput.data.datasets[0].data = decisionsData.map(d => d.count);
            charts.throughput.update();
        }

        // Fetch performance time series
        const perfResp = await fetch('/api/timeseries/performance?bucket_size=60&time_range=3600');
        const perfData = await perfResp.json();

        if (perfData.length > 0) {
            const labels = perfData.map(d => new Date(d.timestamp).toLocaleTimeString());
            const p95Data = perfData.map(d => {
                const durations = d.metrics.map(m => m.duration_ms).sort((a, b) => a - b);
                return durations[Math.floor(durations.length * 0.95)] || 0;
            });
            const p99Data = perfData.map(d => {
                const durations = d.metrics.map(m => m.duration_ms).sort((a, b) => a - b);
                return durations[Math.floor(durations.length * 0.99)] || 0;
            });

            charts.performance.data.labels = labels;
            charts.performance.data.datasets[0].data = p95Data;
            charts.performance.data.datasets[1].data = p99Data;
            charts.performance.update();
        }

        // Fetch error time series
        const errorsResp = await fetch('/api/timeseries/errors?bucket_size=60&time_range=3600');
        const errorsData = await errorsResp.json();

        if (errorsData.length > 0) {
            charts.error.data.labels = errorsData.map(d => new Date(d.timestamp).toLocaleTimeString());
            charts.error.data.datasets[0].data = errorsData.map(d => d.count);
            charts.error.update();
        }
    } catch (error) {
        console.error('Failed to update time series charts:', error);
    }
}

// Update alerts table
function updateAlertsTable(alerts) {
    const tbody = document.getElementById('alerts-tbody');
    document.getElementById('active-alerts').textContent = alerts.length;

    if (alerts.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="no-data">No active alerts</td></tr>';
        return;
    }

    tbody.innerHTML = alerts.map(alert => `
        <tr>
            <td><span class="severity-badge severity-${alert.severity}">${alert.severity.toUpperCase()}</span></td>
            <td>${alert.rule_name}</td>
            <td>${alert.message}</td>
            <td>${new Date(alert.triggered_at).toLocaleString()}</td>
            <td class="alert-actions">
                <button onclick="acknowledgeAlert('${alert.id}')">Acknowledge</button>
                <button onclick="resolveAlert('${alert.id}')">Resolve</button>
            </td>
        </tr>
    `).join('');
}

// Alert actions
async function acknowledgeAlert(alertId) {
    try {
        await fetch(`/api/alerts/${alertId}/acknowledge`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ acknowledged_by: 'dashboard_user' })
        });
        loadAlerts();
    } catch (error) {
        console.error('Failed to acknowledge alert:', error);
    }
}

async function resolveAlert(alertId) {
    try {
        await fetch(`/api/alerts/${alertId}/resolve`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ resolved_by: 'dashboard_user' })
        });
        loadAlerts();
    } catch (error) {
        console.error('Failed to resolve alert:', error);
    }
}

// KPI registration
async function registerKPI(event) {
    event.preventDefault();

    const name = document.getElementById('kpi-name').value;
    const value = parseFloat(document.getElementById('kpi-value').value);

    try {
        await fetch('/api/kpi', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, value })
        });

        document.getElementById('kpi-form').reset();
        showAlertBanner({ message: `KPI "${name}" registered successfully`, severity: 'info' });
    } catch (error) {
        console.error('Failed to register KPI:', error);
        showAlertBanner({ message: 'Failed to register KPI', severity: 'critical' });
    }
}

// UI helpers
function updateConnectionStatus(connected) {
    const statusElement = document.getElementById('connection-status');
    if (connected) {
        statusElement.textContent = 'Connected';
        statusElement.className = 'status-badge connected';
    } else {
        statusElement.textContent = 'Disconnected';
        statusElement.className = 'status-badge disconnected';
    }
}

function showAlertBanner(alert) {
    const banner = document.getElementById('alert-bar');
    const message = document.getElementById('alert-message');

    message.textContent = alert.message;
    banner.style.display = 'block';
    banner.className = `alert-bar severity-${alert.severity || 'warning'}`;

    setTimeout(() => {
        banner.style.display = 'none';
    }, 5000);
}

function closeAlertBar() {
    document.getElementById('alert-bar').style.display = 'none';
}

function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toString();
}

async function refreshAlerts() {
    await loadAlerts();
}
