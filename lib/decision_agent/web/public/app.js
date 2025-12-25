// DecisionAgent Rule Builder - Main Application
class RuleBuilder {
    constructor() {
        this.rules = [];
        this.currentRule = null;
        this.currentRuleIndex = null;
        this.currentCondition = null;
        this.init();
    }

    init() {
        this.bindEvents();
        this.updateJSONPreview();
    }

    bindEvents() {
        // Rule management
        document.getElementById('addRuleBtn').addEventListener('click', () => this.openRuleModal());
        document.getElementById('saveRuleBtn').addEventListener('click', () => this.saveRule());
        document.getElementById('closeModalBtn').addEventListener('click', () => this.closeModal());
        document.getElementById('cancelModalBtn').addEventListener('click', () => this.closeModal());

        // Actions
        document.getElementById('validateBtn').addEventListener('click', () => this.validateRules());
        document.getElementById('clearBtn').addEventListener('click', () => this.clearAll());
        document.getElementById('loadExampleBtn').addEventListener('click', () => this.loadExample());

        // Export/Import
        document.getElementById('copyBtn').addEventListener('click', () => this.copyJSON());
        document.getElementById('downloadBtn').addEventListener('click', () => this.downloadJSON());
        document.getElementById('importFile').addEventListener('change', (e) => this.importJSON(e));

        // Versioning
        document.getElementById('saveVersionBtn').addEventListener('click', () => this.openSaveVersionModal());
        document.getElementById('refreshVersionsBtn').addEventListener('click', () => this.loadVersionHistory());
        document.getElementById('closeSaveVersionBtn').addEventListener('click', () => this.closeSaveVersionModal());
        document.getElementById('cancelSaveVersionBtn').addEventListener('click', () => this.closeSaveVersionModal());
        document.getElementById('confirmSaveVersionBtn').addEventListener('click', () => this.confirmSaveVersion());
        document.getElementById('closeCompareBtn').addEventListener('click', () => this.closeCompareModal());
        document.getElementById('closeCompareModalBtn').addEventListener('click', () => this.closeCompareModal());

        // Modal close on outside click
        document.getElementById('ruleModal').addEventListener('click', (e) => {
            if (e.target.id === 'ruleModal') {
                this.closeModal();
            }
        });

        document.getElementById('saveVersionModal').addEventListener('click', (e) => {
            if (e.target.id === 'saveVersionModal') {
                this.closeSaveVersionModal();
            }
        });

        document.getElementById('compareVersionsModal').addEventListener('click', (e) => {
            if (e.target.id === 'compareVersionsModal') {
                this.closeCompareModal();
            }
        });

        // Operator change - hide/show value input
        document.addEventListener('change', (e) => {
            if (e.target.classList.contains('operator-select')) {
                this.handleOperatorChange(e.target);
            }
        });
    }

    openRuleModal(index = null) {
        this.currentRuleIndex = index;
        const modal = document.getElementById('ruleModal');
        const modalTitle = document.getElementById('modalTitle');

        if (index !== null) {
            // Edit existing rule
            this.currentRule = { ...this.rules[index] };
            modalTitle.textContent = `Edit Rule: ${this.currentRule.id}`;
            this.populateRuleModal(this.currentRule);
        } else {
            // New rule
            this.currentRule = {
                id: '',
                if: { field: '', op: 'eq', value: '' },
                then: { decision: '', weight: 0.8, reason: '' }
            };
            modalTitle.textContent = 'Create New Rule';
            this.populateRuleModal(this.currentRule);
        }

        modal.classList.remove('hidden');
    }

    populateRuleModal(rule) {
        document.getElementById('ruleId').value = rule.id || '';
        document.getElementById('thenDecision').value = rule.then?.decision || '';
        document.getElementById('thenWeight').value = rule.then?.weight || 0.8;
        document.getElementById('thenReason').value = rule.then?.reason || '';

        // Build condition UI
        const conditionBuilder = document.getElementById('conditionBuilder');
        conditionBuilder.innerHTML = '';

        if (!rule.if) {
            this.addFieldCondition(conditionBuilder);
        } else {
            this.buildConditionUI(rule.if, conditionBuilder);
        }
    }

    buildConditionUI(condition, container) {
        if (condition.field !== undefined) {
            // Field condition
            const conditionEl = this.createFieldCondition(condition);
            container.appendChild(conditionEl);
        } else if (condition.all !== undefined) {
            // All (AND) condition
            const compositeEl = this.createCompositeCondition('all', condition.all);
            container.appendChild(compositeEl);
        } else if (condition.any !== undefined) {
            // Any (OR) condition
            const compositeEl = this.createCompositeCondition('any', condition.any);
            container.appendChild(compositeEl);
        } else {
            // Fallback
            this.addFieldCondition(container);
        }
    }

    createFieldCondition(data = {}) {
        const template = document.getElementById('fieldConditionTemplate');
        const clone = template.content.cloneNode(true);
        const conditionItem = clone.querySelector('.condition-item');

        // Populate data
        if (data.field) conditionItem.querySelector('.field-path').value = data.field;
        if (data.op) conditionItem.querySelector('.operator-select').value = data.op;
        if (data.value !== undefined) conditionItem.querySelector('.field-value').value = data.value;

        // Handle operator-specific visibility
        const operatorSelect = conditionItem.querySelector('.operator-select');
        this.handleOperatorChange(operatorSelect);

        // Remove button
        conditionItem.querySelector('.btn-remove').addEventListener('click', (e) => {
            conditionItem.remove();
        });

        // Type change
        conditionItem.querySelector('.condition-type-select').addEventListener('change', (e) => {
            this.convertConditionType(conditionItem, e.target.value);
        });

        return conditionItem;
    }

    createCompositeCondition(type = 'all', subconditions = []) {
        const template = document.getElementById('compositeConditionTemplate');
        const clone = template.content.cloneNode(true);
        const conditionItem = clone.querySelector('.condition-item');
        const typeSelect = conditionItem.querySelector('.condition-type-select');
        const subContainer = conditionItem.querySelector('.subconditions-container');

        // Set type
        typeSelect.value = type;

        // Add subconditions
        if (subconditions.length === 0) {
            // Add one empty field condition
            subContainer.appendChild(this.createFieldCondition());
        } else {
            subconditions.forEach(subcond => {
                this.buildConditionUI(subcond, subContainer);
            });
        }

        // Add subcondition button
        conditionItem.querySelector('.btn-add-subcondition').addEventListener('click', () => {
            subContainer.appendChild(this.createFieldCondition());
        });

        // Remove button
        conditionItem.querySelector('.btn-remove').addEventListener('click', () => {
            conditionItem.remove();
        });

        // Type change
        typeSelect.addEventListener('change', (e) => {
            this.convertConditionType(conditionItem, e.target.value);
        });

        return conditionItem;
    }

    convertConditionType(conditionItem, newType) {
        const parent = conditionItem.parentElement;
        if (!parent) return;

        if (newType === 'field') {
            // Convert to field condition
            const newCondition = this.createFieldCondition();
            parent.replaceChild(newCondition, conditionItem);
        } else {
            // Convert to composite (all/any)
            const newCondition = this.createCompositeCondition(newType);
            parent.replaceChild(newCondition, conditionItem);
        }
    }

    addFieldCondition(container) {
        const conditionEl = this.createFieldCondition();
        container.appendChild(conditionEl);
    }

    handleOperatorChange(selectElement) {
        const valueInput = selectElement.parentElement.querySelector('.field-value');
        const operator = selectElement.value;

        // Operators that don't need a value
        if (operator === 'present' || operator === 'blank') {
            valueInput.style.display = 'none';
            valueInput.value = '';
            return;
        }

        valueInput.style.display = 'block';

        // Set helpful placeholders based on operator
        const placeholders = {
            // Basic operators
            'eq': 'value',
            'neq': 'value',
            'gt': '100',
            'gte': '100',
            'lt': '100',
            'lte': '100',
            'in': '["value1", "value2"]',

            // String operators
            'contains': 'substring',
            'starts_with': 'prefix',
            'ends_with': 'suffix',
            'matches': '^pattern.*$',

            // Numeric operators
            'between': '[min, max] or {"min": 0, "max": 100}',
            'modulo': '[divisor, remainder] or {"divisor": 2, "remainder": 0}',

            // Date/time operators
            'before_date': '2025-12-31',
            'after_date': '2024-01-01',
            'within_days': '7',
            'day_of_week': 'monday or 1',

            // Collection operators
            'contains_all': '["item1", "item2"]',
            'contains_any': '["item1", "item2"]',
            'intersects': '["item1", "item2"]',
            'subset_of': '["valid1", "valid2", "valid3"]',

            // Geospatial operators
            'within_radius': '{"center": {"lat": 40.7128, "lon": -74.0060}, "radius": 10}',
            'in_polygon': '[{"lat": 40, "lon": -74}, {"lat": 41, "lon": -74}, ...]'
        };

        valueInput.placeholder = placeholders[operator] || 'value';

        // Add title attribute with helpful hint
        const hints = {
            'between': 'Range: [min, max] or {"min": 0, "max": 100}',
            'modulo': 'Modulo: [divisor, remainder] or {"divisor": 2, "remainder": 0}',
            'matches': 'Regular expression pattern (e.g., ^user@company\\.com$)',
            'within_days': 'Number of days from now (e.g., 7 for within a week)',
            'day_of_week': 'Day name (monday) or number (0=Sunday, 1=Monday, ...)',
            'within_radius': 'JSON: {"center": {"lat": y, "lon": x}, "radius": km}',
            'in_polygon': 'Array of coordinates: [{"lat": y, "lon": x}, ...]'
        };

        if (hints[operator]) {
            valueInput.title = hints[operator];
        } else {
            valueInput.title = '';
        }
    }

    parseConditionUI(conditionElement) {
        const typeSelect = conditionElement.querySelector('.condition-type-select');
        const type = typeSelect.value;

        if (type === 'field') {
            // Field condition
            const field = conditionElement.querySelector('.field-path').value.trim();
            const op = conditionElement.querySelector('.operator-select').value;
            const value = conditionElement.querySelector('.field-value').value;

            const condition = { field, op };

            // Add value only if needed
            if (op !== 'present' && op !== 'blank') {
                // Try to parse as JSON for arrays/objects
                try {
                    condition.value = JSON.parse(value);
                } catch {
                    condition.value = value;
                }
            }

            return condition;
        } else {
            // Composite condition (all/any)
            const subContainer = conditionElement.querySelector('.subconditions-container');
            const subconditions = Array.from(subContainer.children).map(child =>
                this.parseConditionUI(child)
            );

            return { [type]: subconditions };
        }
    }

    saveRule() {
        // Validate inputs
        const ruleId = document.getElementById('ruleId').value.trim();
        const thenDecision = document.getElementById('thenDecision').value.trim();

        if (!ruleId) {
            alert('Rule ID is required');
            return;
        }

        if (!thenDecision) {
            alert('Decision is required');
            return;
        }

        // Parse condition
        const conditionBuilder = document.getElementById('conditionBuilder');
        const conditionElements = Array.from(conditionBuilder.children);

        if (conditionElements.length === 0) {
            alert('At least one condition is required');
            return;
        }

        const ifCondition = this.parseConditionUI(conditionElements[0]);

        // Build then clause
        const thenClause = {
            decision: thenDecision
        };

        const weight = parseFloat(document.getElementById('thenWeight').value);
        if (weight >= 0 && weight <= 1) {
            thenClause.weight = weight;
        }

        const reason = document.getElementById('thenReason').value.trim();
        if (reason) {
            thenClause.reason = reason;
        }

        // Create rule object
        const rule = {
            id: ruleId,
            if: ifCondition,
            then: thenClause
        };

        // Save or update
        if (this.currentRuleIndex !== null) {
            this.rules[this.currentRuleIndex] = rule;
        } else {
            this.rules.push(rule);
        }

        this.closeModal();
        this.renderRules();
        this.updateJSONPreview();
    }

    closeModal() {
        document.getElementById('ruleModal').classList.add('hidden');
        this.currentRule = null;
        this.currentRuleIndex = null;
    }

    renderRules() {
        const container = document.getElementById('rulesContainer');

        if (this.rules.length === 0) {
            container.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 20px;">No rules yet. Click "Add Rule" to create one.</p>';
            return;
        }

        container.innerHTML = '';

        this.rules.forEach((rule, index) => {
            const ruleCard = document.createElement('div');
            ruleCard.className = 'rule-card';

            const conditionSummary = this.getConditionSummary(rule.if);

            ruleCard.innerHTML = `
                <div class="rule-header">
                    <span class="rule-id">${this.escapeHtml(rule.id)}</span>
                    <div class="rule-actions">
                        <button class="btn btn-sm btn-secondary edit-btn">Edit</button>
                        <button class="btn-remove delete-btn">×</button>
                    </div>
                </div>
                <div class="rule-summary">
                    IF: ${conditionSummary}<br>
                    THEN: ${this.escapeHtml(rule.then.decision)} (weight: ${rule.then.weight || 'default'})
                </div>
            `;

            ruleCard.querySelector('.edit-btn').addEventListener('click', () => this.openRuleModal(index));
            ruleCard.querySelector('.delete-btn').addEventListener('click', () => this.deleteRule(index));

            container.appendChild(ruleCard);
        });
    }

    getConditionSummary(condition) {
        if (condition.field) {
            const valueText = condition.value !== undefined ? ` "${this.escapeHtml(JSON.stringify(condition.value))}"` : '';
            return `${this.escapeHtml(condition.field)} ${condition.op}${valueText}`;
        } else if (condition.all) {
            return `ALL (${condition.all.length} conditions)`;
        } else if (condition.any) {
            return `ANY (${condition.any.length} conditions)`;
        }
        return 'unknown';
    }

    deleteRule(index) {
        if (confirm('Are you sure you want to delete this rule?')) {
            this.rules.splice(index, 1);
            this.renderRules();
            this.updateJSONPreview();
        }
    }

    updateJSONPreview() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';

        const output = {
            version: version,
            ruleset: ruleset,
            rules: this.rules
        };

        document.getElementById('jsonOutput').textContent = JSON.stringify(output, null, 2);
    }

    async validateRules() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';

        const payload = {
            version: version,
            ruleset: ruleset,
            rules: this.rules
        };

        try {
            const response = await fetch('/api/validate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            const result = await response.json();

            if (result.valid) {
                this.showValidationSuccess();
            } else {
                this.showValidationErrors(result.errors);
            }
        } catch (error) {
            console.error('Validation error:', error);
            this.showValidationErrors(['Network error: Could not connect to validation server']);
        }
    }

    showValidationSuccess() {
        const statusEl = document.getElementById('validationStatus');
        const errorsEl = document.getElementById('validationErrors');

        statusEl.className = 'validation-status success';
        statusEl.querySelector('.status-message').textContent = 'All rules are valid!';
        statusEl.classList.remove('hidden');

        errorsEl.classList.add('hidden');
    }

    showValidationErrors(errors) {
        const statusEl = document.getElementById('validationStatus');
        const errorsEl = document.getElementById('validationErrors');
        const errorList = document.getElementById('errorList');

        statusEl.className = 'validation-status error';
        statusEl.querySelector('.status-message').textContent = 'Validation failed. See errors below.';
        statusEl.classList.remove('hidden');

        errorList.innerHTML = '';
        errors.forEach(error => {
            const li = document.createElement('li');
            li.textContent = error;
            errorList.appendChild(li);
        });

        errorsEl.classList.remove('hidden');
    }

    clearAll() {
        if (confirm('Are you sure you want to clear all rules?')) {
            this.rules = [];
            this.renderRules();
            this.updateJSONPreview();
            document.getElementById('validationStatus').classList.add('hidden');
            document.getElementById('validationErrors').classList.add('hidden');
        }
    }

    copyJSON() {
        const jsonText = document.getElementById('jsonOutput').textContent;
        navigator.clipboard.writeText(jsonText).then(() => {
            const btn = document.getElementById('copyBtn');
            const originalText = btn.textContent;
            btn.textContent = '✓ Copied!';
            setTimeout(() => {
                btn.textContent = originalText;
            }, 2000);
        });
    }

    downloadJSON() {
        const jsonText = document.getElementById('jsonOutput').textContent;
        const blob = new Blob([jsonText], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `rules_${new Date().getTime()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }

    importJSON(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const data = JSON.parse(e.target.result);

                if (data.rules && Array.isArray(data.rules)) {
                    this.rules = data.rules;

                    if (data.version) {
                        document.getElementById('rulesetVersion').value = data.version;
                    }
                    if (data.ruleset) {
                        document.getElementById('rulesetName').value = data.ruleset;
                    }

                    this.renderRules();
                    this.updateJSONPreview();
                    alert('Rules imported successfully!');
                } else {
                    alert('Invalid JSON format. Expected "rules" array.');
                }
            } catch (error) {
                alert('Error parsing JSON: ' + error.message);
            }
        };
        reader.readAsText(file);

        // Reset input
        event.target.value = '';
    }

    loadExample() {
        const example = {
            version: '1.0',
            ruleset: 'example_advanced_rules',
            rules: [
                {
                    id: 'corporate_email_approval',
                    if: {
                        all: [
                            { field: 'email', op: 'ends_with', value: '@company.com' },
                            { field: 'age', op: 'between', value: [18, 65] }
                        ]
                    },
                    then: {
                        decision: 'approve',
                        weight: 0.95,
                        reason: 'Corporate email with valid age range'
                    }
                },
                {
                    id: 'weekend_special_offer',
                    if: {
                        all: [
                            { field: 'booking_date', op: 'day_of_week', value: 'saturday' },
                            { field: 'amount', op: 'between', value: [100, 500] }
                        ]
                    },
                    then: {
                        decision: 'apply_discount',
                        weight: 0.9,
                        reason: 'Weekend booking discount eligible'
                    }
                },
                {
                    id: 'local_delivery_zone',
                    if: {
                        field: 'delivery.location',
                        op: 'within_radius',
                        value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 25 }
                    },
                    then: {
                        decision: 'same_day_delivery',
                        weight: 0.85,
                        reason: 'Within local delivery zone'
                    }
                },
                {
                    id: 'permission_check',
                    if: {
                        all: [
                            { field: 'user.permissions', op: 'contains_all', value: ['read', 'write'] },
                            { field: 'user.roles', op: 'contains_any', value: ['admin', 'manager'] }
                        ]
                    },
                    then: {
                        decision: 'grant_access',
                        weight: 1.0,
                        reason: 'User has required permissions and role'
                    }
                },
                {
                    id: 'urgent_recent_account',
                    if: {
                        all: [
                            { field: 'message', op: 'contains', value: 'urgent' },
                            { field: 'created_at', op: 'within_days', value: 30 }
                        ]
                    },
                    then: {
                        decision: 'escalate',
                        weight: 0.9,
                        reason: 'Urgent message from recent account'
                    }
                }
            ]
        };

        this.rules = example.rules;
        document.getElementById('rulesetVersion').value = example.version;
        document.getElementById('rulesetName').value = example.ruleset;

        this.renderRules();
        this.updateJSONPreview();
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = String(text);
        return div.innerHTML;
    }

    // ===== VERSION MANAGEMENT METHODS =====

    getRuleData() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';

        return {
            version: version,
            ruleset: ruleset,
            rules: this.rules
        };
    }

    openSaveVersionModal() {
        const ruleset = document.getElementById('rulesetName').value;
        if (!ruleset) {
            alert('Please enter a ruleset name before saving a version');
            return;
        }

        document.getElementById('saveVersionModal').classList.remove('hidden');
    }

    closeSaveVersionModal() {
        document.getElementById('saveVersionModal').classList.add('hidden');
        document.getElementById('versionChangelog').value = '';
    }

    async confirmSaveVersion() {
        const ruleset = document.getElementById('rulesetName').value;
        const createdBy = document.getElementById('versionCreatedBy').value;
        const changelog = document.getElementById('versionChangelog').value;

        const ruleData = this.getRuleData();

        try {
            const response = await fetch('/api/versions', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    rule_id: ruleset,
                    content: ruleData,
                    created_by: createdBy,
                    changelog: changelog
                })
            });

            if (response.ok) {
                const version = await response.json();
                alert(`Version ${version.version_number} saved successfully!`);
                this.closeSaveVersionModal();
                this.loadVersionHistory();
            } else {
                const error = await response.json();
                alert(`Error saving version: ${error.error}`);
            }
        } catch (error) {
            alert(`Error saving version: ${error.message}`);
        }
    }

    async loadVersionHistory() {
        const ruleset = document.getElementById('rulesetName').value;
        if (!ruleset) {
            document.getElementById('versionHistoryContainer').innerHTML =
                '<p class="empty-state">Enter a ruleset name to view version history</p>';
            return;
        }

        try {
            const response = await fetch(`/api/rules/${encodeURIComponent(ruleset)}/history`);
            if (response.ok) {
                const history = await response.json();
                this.displayVersionHistory(history);
            } else {
                document.getElementById('versionHistoryContainer').innerHTML =
                    '<p class="empty-state">No versions found for this ruleset</p>';
            }
        } catch (error) {
            document.getElementById('versionHistoryContainer').innerHTML =
                `<p class="error-message">Error loading versions: ${error.message}</p>`;
        }
    }

    displayVersionHistory(history) {
        const container = document.getElementById('versionHistoryContainer');

        if (!history.versions || history.versions.length === 0) {
            container.innerHTML = '<p class="empty-state">No versions yet. Save a version to get started.</p>';
            return;
        }

        let html = `
            <div class="version-stats">
                <div class="stat">
                    <span class="stat-label">Total Versions:</span>
                    <span class="stat-value">${history.total_versions}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Active Version:</span>
                    <span class="stat-value">${history.active_version ? history.active_version.version_number : 'None'}</span>
                </div>
            </div>
            <table class="version-table">
                <thead>
                    <tr>
                        <th>Version</th>
                        <th>Created By</th>
                        <th>Created At</th>
                        <th>Status</th>
                        <th>Changelog</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
        `;

        history.versions.forEach((version, index) => {
            const createdAt = new Date(version.created_at).toLocaleString();
            const statusClass = version.status === 'active' ? 'status-active' :
                               version.status === 'draft' ? 'status-draft' : 'status-archived';

            html += `
                <tr class="${version.status === 'active' ? 'active-version' : ''}">
                    <td><strong>v${version.version_number}</strong></td>
                    <td>${this.escapeHtml(version.created_by)}</td>
                    <td>${createdAt}</td>
                    <td><span class="status-badge ${statusClass}">${version.status}</span></td>
                    <td>${this.escapeHtml(version.changelog || '')}</td>
                    <td class="action-buttons">
                        <button class="btn btn-xs btn-secondary" onclick="ruleBuilder.loadVersion('${version.id}')">Load</button>
                        ${version.status !== 'active' ?
                          `<button class="btn btn-xs btn-primary" onclick="ruleBuilder.rollbackToVersion('${version.id}')">Rollback</button>` :
                          '<span class="active-badge">Active</span>'}
                        ${index < history.versions.length - 1 ?
                          `<button class="btn btn-xs btn-secondary" onclick="ruleBuilder.compareVersions('${version.id}', '${history.versions[index + 1].id}')">Compare</button>` : ''}
                        ${version.status !== 'active' ?
                          `<button class="btn btn-xs btn-danger" onclick="ruleBuilder.deleteVersion('${version.id}')">Delete</button>` : ''}
                    </td>
                </tr>
            `;
        });

        html += `
                </tbody>
            </table>
        `;

        container.innerHTML = html;
    }

    async loadVersion(versionId) {
        try {
            const response = await fetch(`/api/versions/${encodeURIComponent(versionId)}`);
            if (response.ok) {
                const version = await response.json();
                this.loadRulesFromVersion(version.content);
                alert(`Loaded version ${version.version_number}`);
            } else {
                alert('Error loading version');
            }
        } catch (error) {
            alert(`Error loading version: ${error.message}`);
        }
    }

    loadRulesFromVersion(content) {
        if (content.version) {
            document.getElementById('rulesetVersion').value = content.version;
        }
        if (content.ruleset) {
            document.getElementById('rulesetName').value = content.ruleset;
        }
        if (content.rules) {
            this.rules = content.rules;
            this.renderRules();
            this.updateJSONPreview();
        }
    }

    async rollbackToVersion(versionId) {
        if (!confirm('Are you sure you want to rollback to this version? This will create a new version.')) {
            return;
        }

        try {
            const performedBy = prompt('Enter your name:', 'system');
            if (!performedBy) return;

            const response = await fetch(`/api/versions/${encodeURIComponent(versionId)}/activate`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ performed_by: performedBy })
            });

            if (response.ok) {
                const version = await response.json();
                alert(`Rolled back to version ${version.version_number}`);
                this.loadVersionHistory();
                this.loadVersion(versionId);
            } else {
                const error = await response.json();
                alert(`Error during rollback: ${error.error}`);
            }
        } catch (error) {
            alert(`Error during rollback: ${error.message}`);
        }
    }

    async compareVersions(versionId1, versionId2) {
        try {
            const response = await fetch(
                `/api/versions/${encodeURIComponent(versionId1)}/compare/${encodeURIComponent(versionId2)}`
            );

            if (response.ok) {
                const comparison = await response.json();
                this.displayComparison(comparison);
                document.getElementById('compareVersionsModal').classList.remove('hidden');
            } else {
                alert('Error comparing versions');
            }
        } catch (error) {
            alert(`Error comparing versions: ${error.message}`);
        }
    }

    displayComparison(comparison) {
        const container = document.getElementById('comparisonResult');
        const v1 = comparison.version_1;
        const v2 = comparison.version_2;
        const diff = comparison.differences;

        let html = `
            <div class="comparison-header">
                <div class="version-info">
                    <h3>Version ${v1.version_number}</h3>
                    <p>By ${this.escapeHtml(v1.created_by)} on ${new Date(v1.created_at).toLocaleString()}</p>
                </div>
                <div class="comparison-arrow">→</div>
                <div class="version-info">
                    <h3>Version ${v2.version_number}</h3>
                    <p>By ${this.escapeHtml(v2.created_by)} on ${new Date(v2.created_at).toLocaleString()}</p>
                </div>
            </div>

            <div class="comparison-content">
                <div class="comparison-section">
                    <h4>Version ${v1.version_number} Content:</h4>
                    <pre class="json-code">${JSON.stringify(v1.content, null, 2)}</pre>
                </div>
                <div class="comparison-section">
                    <h4>Version ${v2.version_number} Content:</h4>
                    <pre class="json-code">${JSON.stringify(v2.content, null, 2)}</pre>
                </div>
            </div>

            <div class="diff-summary">
                <h4>Changes Summary:</h4>
                <div class="diff-stats">
                    <span class="diff-added">+${diff.added.length} added</span>
                    <span class="diff-removed">-${diff.removed.length} removed</span>
                    <span class="diff-changed">${Object.keys(diff.changed).length} changed</span>
                </div>
            </div>
        `;

        container.innerHTML = html;
    }

    closeCompareModal() {
        document.getElementById('compareVersionsModal').classList.add('hidden');
    }

    async deleteVersion(versionId) {
        if (!confirm('Are you sure you want to delete this version? This action cannot be undone.')) {
            return;
        }

        try {
            const response = await fetch(`/api/versions/${encodeURIComponent(versionId)}`, {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' }
            });

            if (response.ok) {
                alert('Version deleted successfully');
                this.loadVersionHistory();
            } else {
                const error = await response.json();
                alert(`Error deleting version: ${error.error}`);
            }
        } catch (error) {
            alert(`Error deleting version: ${error.message}`);
        }
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.ruleBuilder = new RuleBuilder();

    // Update JSON on metadata changes
    ['rulesetVersion', 'rulesetName'].forEach(id => {
        document.getElementById(id).addEventListener('input', () => {
            window.ruleBuilder.updateJSONPreview();
        });
    });
});
