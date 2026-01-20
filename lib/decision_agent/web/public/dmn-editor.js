// DMN Editor JavaScript

// State
const state = {
    currentModel: null,
    currentDecision: null,
    models: [],
    baseUrl: window.location.origin
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initializeEventListeners();
    loadModels();
});

// Event Listeners
function initializeEventListeners() {
    // Header actions
    document.getElementById('new-model-btn').addEventListener('click', () => {
        openModal('new-model-modal');
    });

    document.getElementById('import-btn').addEventListener('click', () => {
        openModal('import-modal');
    });

    document.getElementById('export-btn').addEventListener('click', exportModel);
    document.getElementById('validate-btn').addEventListener('click', validateModel);

    // Forms
    document.getElementById('new-model-form').addEventListener('submit', createNewModel);
    document.getElementById('add-decision-form').addEventListener('submit', addDecision);
    document.getElementById('add-column-form').addEventListener('submit', addColumn);
    document.getElementById('import-form').addEventListener('submit', importModel);

    // Decision actions
    document.getElementById('add-decision-btn').addEventListener('click', () => {
        openModal('add-decision-modal');
    });

    document.getElementById('decision-select').addEventListener('change', (e) => {
        loadDecision(e.target.value);
    });

    // Table controls
    document.getElementById('add-input-btn').addEventListener('click', () => {
        if (!state.currentModel || !state.currentDecision) {
            showNotification('Please select or create a model and decision first', 'error');
            return;
        }
        document.getElementById('column-type').value = 'input';
        document.getElementById('column-modal-title').textContent = 'Add Input Column';
        document.getElementById('expression-group').style.display = 'block';
        openModal('add-column-modal');
    });

    document.getElementById('add-output-btn').addEventListener('click', () => {
        if (!state.currentModel || !state.currentDecision) {
            showNotification('Please select or create a model and decision first', 'error');
            return;
        }
        document.getElementById('column-type').value = 'output';
        document.getElementById('column-modal-title').textContent = 'Add Output Column';
        document.getElementById('expression-group').style.display = 'none';
        openModal('add-column-modal');
    });

    document.getElementById('add-rule-btn').addEventListener('click', addRule);
    document.getElementById('hit-policy-select').addEventListener('change', updateHitPolicy);

    // Tabs
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    // Visualization
    document.getElementById('visualize-graph-btn')?.addEventListener('click', visualizeGraph);
    document.getElementById('visualize-tree-btn')?.addEventListener('click', visualizeTree);

    // XML actions
    document.getElementById('copy-xml-btn')?.addEventListener('click', copyXml);
    document.getElementById('download-xml-btn')?.addEventListener('click', downloadXml);
}

// API Functions
async function apiCall(endpoint, method = 'GET', data = null) {
    const options = {
        method,
        headers: {
            'Content-Type': 'application/json'
        }
    };

    if (data) {
        options.body = JSON.stringify(data);
    }

    const response = await fetch(`${state.baseUrl}/api/dmn${endpoint}`, options);

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'API request failed');
    }

    return response.json();
}

// Model Management
async function loadModels() {
    try {
        const models = await apiCall('/models');
        state.models = models;
        renderModelList();
    } catch (error) {
        showNotification('Failed to load models: ' + error.message, 'error');
    }
}

function renderModelList() {
    const list = document.getElementById('model-list');

    if (state.models.length === 0) {
        list.innerHTML = '<p class="empty-state">No models yet. Create one to get started.</p>';
        return;
    }

    list.innerHTML = state.models.map(model => `
        <div class="model-item ${model.id === state.currentModel?.id ? 'active' : ''}"
             onclick="loadModel('${model.id}')">
            <h4>${escapeHtml(model.name)}</h4>
            <p>${model.decision_count} decision(s)</p>
        </div>
    `).join('');
}

async function loadModel(modelId) {
    try {
        const model = await apiCall(`/models/${modelId}`);
        state.currentModel = model;
        renderModelEditor();
        renderModelList();

        // Hide welcome screen, show editor
        document.getElementById('welcome-screen').style.display = 'none';
        document.getElementById('editor-container').style.display = 'block';

        // Load first decision if available
        if (model.decisions && model.decisions.length > 0) {
            loadDecision(model.decisions[0].id);
        }
    } catch (error) {
        showNotification('Failed to load model: ' + error.message, 'error');
    }
}

async function createNewModel(e) {
    e.preventDefault();

    const name = document.getElementById('model-name-input').value;
    const namespace = document.getElementById('model-namespace-input').value;

    try {
        const model = await apiCall('/models', 'POST', { name, namespace });
        state.models.push(model);
        await loadModel(model.id);
        closeModal('new-model-modal');
        document.getElementById('new-model-form').reset();
        showNotification('Model created successfully', 'success');
    } catch (error) {
        showNotification('Failed to create model: ' + error.message, 'error');
    }
}

function renderModelEditor() {
    if (!state.currentModel) return;

    document.getElementById('model-name').textContent = state.currentModel.name;
    document.getElementById('model-id').textContent = `ID: ${state.currentModel.id}`;

    // Populate decision selector
    const select = document.getElementById('decision-select');
    if (state.currentModel.decisions && state.currentModel.decisions.length > 0) {
        select.innerHTML = state.currentModel.decisions.map(d =>
            `<option value="${d.id}">${escapeHtml(d.name)}</option>`
        ).join('');
    } else {
        select.innerHTML = '<option value="">No decisions yet</option>';
    }
}

// Decision Management
async function addDecision(e) {
    e.preventDefault();

    const decisionId = document.getElementById('decision-id-input').value;
    const name = document.getElementById('decision-name-input').value;
    const type = document.getElementById('decision-type-select').value;

    try {
        const decision = await apiCall(`/models/${state.currentModel.id}/decisions`, 'POST', {
            decision_id: decisionId,
            name,
            type
        });

        state.currentModel.decisions.push(decision);
        renderModelEditor();
        loadDecision(decision.id);
        closeModal('add-decision-modal');
        document.getElementById('add-decision-form').reset();
        showNotification('Decision added successfully', 'success');
    } catch (error) {
        showNotification('Failed to add decision: ' + error.message, 'error');
    }
}

async function loadDecision(decisionId) {
    if (!state.currentModel || !state.currentModel.decisions) {
        console.error('Cannot load decision: No model selected');
        return;
    }

    const decision = state.currentModel.decisions.find(d => d.id === decisionId);
    if (!decision) return;

    state.currentDecision = decision;
    document.getElementById('decision-select').value = decisionId;

    if (decision.decision_table) {
        renderDecisionTable(decision.decision_table);
    }
}

// Decision Table
function renderDecisionTable(table) {
    const headers = document.getElementById('table-headers');
    const types = document.getElementById('table-types');
    const body = document.getElementById('table-body');

    // Set hit policy
    document.getElementById('hit-policy-select').value = table.hit_policy;

    // Render headers
    let headerHtml = '<th class="rule-number">#</th>';
    let typeHtml = '<th></th>';

    table.inputs.forEach(input => {
        headerHtml += `<th class="input-col">${escapeHtml(input.label)} <span class="col-type">(Input)</span></th>`;
        typeHtml += `<th class="type-annotation">${input.type_ref || 'string'}</th>`;
    });

    table.outputs.forEach(output => {
        headerHtml += `<th class="output-col">${escapeHtml(output.label)} <span class="col-type">(Output)</span></th>`;
        typeHtml += `<th class="type-annotation">${output.type_ref || 'string'}</th>`;
    });

    headerHtml += '<th class="actions-col">Actions</th>';
    typeHtml += '<th></th>';

    headers.innerHTML = headerHtml;
    types.innerHTML = typeHtml;

    // Render rules
    if (table.rules.length === 0) {
        body.innerHTML = `<tr class="empty-row"><td colspan="${table.inputs.length + table.outputs.length + 2}">
            No rules defined. Click "Add Rule" to create one.</td></tr>`;
        return;
    }

    body.innerHTML = table.rules.map((rule, index) => {
        let rowHtml = `<tr data-rule-id="${rule.id}">`;
        rowHtml += `<td class="rule-number">${index + 1}</td>`;

        rule.input_entries.forEach((entry, i) => {
            rowHtml += `<td><input type="text" value="${escapeHtml(entry)}"
                onchange="updateRuleEntry('${rule.id}', 'input', ${i}, this.value)"></td>`;
        });

        rule.output_entries.forEach((entry, i) => {
            rowHtml += `<td><input type="text" value="${escapeHtml(entry)}"
                onchange="updateRuleEntry('${rule.id}', 'output', ${i}, this.value)"></td>`;
        });

        rowHtml += `<td class="actions-col">
            <button class="btn btn-sm btn-danger" onclick="deleteRule('${rule.id}')">Delete</button>
        </td>`;
        rowHtml += '</tr>';

        return rowHtml;
    }).join('');
}

async function addColumn(e) {
    e.preventDefault();

    // Validate that model and decision are selected
    if (!state.currentModel || !state.currentDecision) {
        showNotification('Please select or create a model and decision first', 'error');
        return;
    }

    const columnType = document.getElementById('column-type').value;
    const id = document.getElementById('column-id-input').value;
    const label = document.getElementById('column-label-input').value;
    const typeRef = document.getElementById('column-type-input').value;
    const expression = document.getElementById('column-expression-input').value;

    try {
        const endpoint = `/models/${state.currentModel.id}/decisions/${state.currentDecision.id}/${columnType}s`;

        const data = {
            [`${columnType}_id`]: id,
            label,
            type_ref: typeRef
        };

        if (columnType === 'input' && expression) {
            data.expression = expression;
        } else if (columnType === 'output') {
            data.name = id;
        }

        await apiCall(endpoint, 'POST', data);

        // Reload model to get updated state
        await loadModel(state.currentModel.id);
        loadDecision(state.currentDecision.id);

        closeModal('add-column-modal');
        document.getElementById('add-column-form').reset();
        showNotification(`${columnType === 'input' ? 'Input' : 'Output'} column added successfully`, 'success');
    } catch (error) {
        showNotification('Failed to add column: ' + error.message, 'error');
    }
}

async function addRule() {
    if (!state.currentModel || !state.currentDecision || !state.currentDecision.decision_table) {
        showNotification('Please select or create a model and decision first', 'error');
        return;
    }

    const table = state.currentDecision.decision_table;
    const ruleId = `rule_${Date.now()}`;
    const inputEntries = table.inputs.map(() => '-');
    const outputEntries = table.outputs.map(() => '');

    try {
        await apiCall(`/models/${state.currentModel.id}/decisions/${state.currentDecision.id}/rules`, 'POST', {
            rule_id: ruleId,
            input_entries: inputEntries,
            output_entries: outputEntries
        });

        // Reload model
        await loadModel(state.currentModel.id);
        loadDecision(state.currentDecision.id);
        showNotification('Rule added successfully', 'success');
    } catch (error) {
        showNotification('Failed to add rule: ' + error.message, 'error');
    }
}

async function updateRuleEntry(ruleId, type, index, value) {
    if (!state.currentModel || !state.currentDecision || !state.currentDecision.decision_table) {
        showNotification('Please select or create a model and decision first', 'error');
        return;
    }

    try {
        const rule = state.currentDecision.decision_table.rules.find(r => r.id === ruleId);
        if (!rule) return;

        if (type === 'input') {
            rule.input_entries[index] = value;
        } else {
            rule.output_entries[index] = value;
        }

        await apiCall(`/models/${state.currentModel.id}/decisions/${state.currentDecision.id}/rules/${ruleId}`, 'PUT', {
            input_entries: rule.input_entries,
            output_entries: rule.output_entries
        });
    } catch (error) {
        showNotification('Failed to update rule: ' + error.message, 'error');
    }
}

async function deleteRule(ruleId) {
    if (!state.currentModel || !state.currentDecision) {
        showNotification('Please select or create a model and decision first', 'error');
        return;
    }

    if (!confirm('Are you sure you want to delete this rule?')) return;

    try {
        await apiCall(`/models/${state.currentModel.id}/decisions/${state.currentDecision.id}/rules/${ruleId}`, 'DELETE');

        // Reload model
        await loadModel(state.currentModel.id);
        loadDecision(state.currentDecision.id);
        showNotification('Rule deleted successfully', 'success');
    } catch (error) {
        showNotification('Failed to delete rule: ' + error.message, 'error');
    }
}

async function updateHitPolicy(e) {
    if (!state.currentModel || !state.currentDecision || !state.currentDecision.decision_table) {
        showNotification('Please select or create a model and decision first', 'error');
        return;
    }

    try {
        await apiCall(`/models/${state.currentModel.id}/decisions/${state.currentDecision.id}`, 'PUT', {
            logic: { hit_policy: e.target.value }
        });

        showNotification('Hit policy updated successfully', 'success');
    } catch (error) {
        showNotification('Failed to update hit policy: ' + error.message, 'error');
    }
}

// Import/Export
async function exportModel() {
    if (!state.currentModel) {
        showNotification('No model selected', 'warning');
        return;
    }

    try {
        const xml = await apiCall(`/models/${state.currentModel.id}/export`);

        // Update XML tab
        document.getElementById('xml-content').innerHTML = `<code>${escapeHtml(xml)}</code>`;

        showNotification('Model exported successfully', 'success');
    } catch (error) {
        showNotification('Failed to export model: ' + error.message, 'error');
    }
}

async function importModel(e) {
    e.preventDefault();

    const fileInput = document.getElementById('import-file-input');
    const file = fileInput.files[0];

    if (!file) {
        showNotification('Please select a file', 'warning');
        return;
    }

    try {
        const xmlContent = await file.text();
        const model = await apiCall('/models/import', 'POST', { xml: xmlContent });

        state.models.push(model);
        await loadModel(model.id);
        closeModal('import-modal');
        document.getElementById('import-form').reset();
        showNotification('Model imported successfully', 'success');
    } catch (error) {
        showNotification('Failed to import model: ' + error.message, 'error');
    }
}

async function validateModel() {
    if (!state.currentModel) {
        showNotification('No model selected', 'warning');
        return;
    }

    try {
        const result = await apiCall(`/models/${state.currentModel.id}/validate`);

        if (result.valid) {
            showNotification('Model is valid!', 'success');
        } else {
            showNotification(`Validation failed: ${result.errors.join(', ')}`, 'error');
        }
    } catch (error) {
        showNotification('Failed to validate model: ' + error.message, 'error');
    }
}

// Visualization
async function visualizeGraph() {
    if (!state.currentModel) return;

    const format = document.getElementById('graph-format-select').value;

    try {
        const visualization = await apiCall(`/models/${state.currentModel.id}/visualize/graph?format=${format}`);
        const container = document.getElementById('graph-visualization');

        if (format === 'svg') {
            container.innerHTML = visualization;
        } else {
            container.innerHTML = `<pre><code>${escapeHtml(visualization)}</code></pre>`;
        }
    } catch (error) {
        showNotification('Failed to generate visualization: ' + error.message, 'error');
    }
}

async function visualizeTree() {
    if (!state.currentModel || !state.currentDecision) {
        showNotification('Please select or create a model and decision first', 'error');
        return;
    }

    try {
        const svg = await apiCall(`/models/${state.currentModel.id}/decisions/${state.currentDecision.id}/visualize/tree`);
        document.getElementById('tree-visualization').innerHTML = svg;
    } catch (error) {
        showNotification('Failed to generate tree visualization: ' + error.message, 'error');
    }
}

function copyXml() {
    const xmlContent = document.getElementById('xml-content').textContent;
    navigator.clipboard.writeText(xmlContent);
    showNotification('XML copied to clipboard', 'success');
}

function downloadXml() {
    if (!state.currentModel) {
        showNotification('No model selected', 'warning');
        return;
    }

    const xmlContent = document.getElementById('xml-content').textContent;
    const blob = new Blob([xmlContent], { type: 'text/xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${state.currentModel.name}.dmn`;
    a.click();
    URL.revokeObjectURL(url);
    showNotification('DMN file downloaded', 'success');
}

// UI Helpers
function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    // Update tab panes
    document.querySelectorAll('.tab-pane').forEach(pane => {
        pane.classList.toggle('active', pane.id === `${tabName}-tab`);
    });

    // Load content based on tab
    if (tabName === 'xml') {
        exportModel();
    } else if (tabName === 'graph') {
        visualizeGraph();
    }
}

function openModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

function showNotification(message, type = 'info') {
    const notification = document.getElementById('notification');
    notification.textContent = message;
    notification.className = `notification ${type} show`;

    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Close modals when clicking outside
window.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal')) {
        e.target.classList.remove('active');
    }
});
